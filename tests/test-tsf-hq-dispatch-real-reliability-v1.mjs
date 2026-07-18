import assert from "node:assert/strict";
import { spawn, spawnSync, execFileSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import {
  CANONICAL_RUNTIME_ROOT,
  HQ_PORT,
  LOCAL_LIFECYCLE_ROOT,
  OWNER_PATH,
  POWERSHELL_EXE,
  ProcessOwnership,
  REPOSITORY_ROOT,
  inspectListeners,
  inspectProcess,
  readOwnership,
  reconcileCanonicalState,
  runDoctor,
  writeInterruptionEvidence,
} from "../tools/hq-dispatch/v1/reliability.mjs";
import {
  createHqDispatchServer,
  listenHqDispatchServer,
} from "../tools/hq-dispatch/v1/server.mjs";
import {
  BARRIER_HOOK_POINT,
  FIXTURE_RELATIVE_ROOT,
  FIXTURE_TYPE,
  createFixtureOnlyInterruptionBarrier,
} from "./support/tsf-hq-dispatch-m3-real-interruption-barrier.mjs";

const TEST_PATH = fileURLToPath(import.meta.url);
const STOP_PATH = path.join(REPOSITORY_ROOT, "tools", "hq-dispatch", "v1", "Stop-TsfHqDispatchV1.ps1");
const EMPTY_SHA256 = createHash("sha256").update("").digest("hex");
let assertions = 0;

function check(value, message) {
  assertions += 1;
  assert.ok(value, message);
}

function equal(actual, expected, message) {
  assertions += 1;
  assert.equal(actual, expected, message);
}

function sha256File(filePath) {
  return createHash("sha256").update(readFileSync(filePath)).digest("hex");
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8").replace(/^\uFEFF/, ""));
}

function stableTrackedStatus() {
  const result = spawnSync("git.exe", ["-C", REPOSITORY_ROOT, "status", "--porcelain=v1", "--untracked-files=all"], {
    encoding: "utf8",
    windowsHide: true,
  });
  if (result.status !== 0) throw new Error("GIT_STATUS_UNAVAILABLE");
  return result.stdout;
}

function flattenCanonicalPaths(item) {
  return [...new Set(Object.values(item.canonical_paths ?? {}).flatMap((value) => Array.isArray(value) ? value : [value]).filter((value) => typeof value === "string" && existsSync(value)))].sort();
}

function hashCanonicalPaths(item) {
  return new Map(flattenCanonicalPaths(item).map((filePath) => [filePath, sha256File(filePath)]));
}

function sameHashes(before, after) {
  return before.size === after.size && [...before].every(([filePath, hash]) => after.get(filePath) === hash);
}

function descendants(rootProcessId) {
  const script = [
    `$frontier = @(${Number(rootProcessId)})`,
    "$rows = @()",
    "while ($frontier.Count -gt 0) {",
    "  $next = @()",
    "  foreach ($parent in $frontier) {",
    "    $children = @(Get-CimInstance Win32_Process -Filter (\"ParentProcessId=$parent\") -ErrorAction SilentlyContinue)",
    "    foreach ($child in $children) {",
    "      $rows += [pscustomobject]@{ process_id=[int]$child.ProcessId; parent_process_id=[int]$child.ParentProcessId; name=[string]$child.Name; executable=[string]$child.ExecutablePath }",
    "      $next += [int]$child.ProcessId",
    "    }",
    "  }",
    "  $frontier = $next",
    "}",
    "$rows | ConvertTo-Json -Compress",
  ].join("; ");
  const output = execFileSync(POWERSHELL_EXE, ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script], {
    encoding: "utf8",
    windowsHide: true,
    timeout: 10_000,
  }).trim();
  if (!output) return [];
  const parsed = JSON.parse(output);
  return Array.isArray(parsed) ? parsed : [parsed];
}

async function waitFor(predicate, timeoutMs, message, intervalMs = 50) {
  const deadline = Date.now() + timeoutMs;
  let value;
  while (Date.now() < deadline) {
    value = await predicate();
    if (value) return value;
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  throw new Error(`${message}:${JSON.stringify(value ?? null)}`);
}

function recoveryProjection(queueRoot) {
  return reconcileCanonicalState({
    runtimeRoot: CANONICAL_RUNTIME_ROOT,
    queueRoot,
    ownership: readOwnership(),
  });
}

function buildLifecycle(owner, queueRoot) {
  const reconcile = () => recoveryProjection(queueRoot);
  const lifecycle = {
    mode: "REAL_TSF_LOCAL_PROOF",
    owner,
    localRoot: LOCAL_LIFECYCLE_ROOT,
    sessionGeneration: owner.sessionGeneration,
    serverInstanceId: owner.serverInstanceId,
    doctor: () => runDoctor({ runtimeRoot: CANONICAL_RUNTIME_ROOT, queueRoot, allowDirtyForTest: true }),
    reconcile,
    stopView: () => ({
      schema_version: "tsf_hq_dispatch_stop_view_v1",
      server_instance: owner.serverInstanceId,
      active_mission: owner.owner?.active_mission ?? null,
      owned_child: owner.owner?.owned_children ?? [],
      behavior: "STOP_ACCEPTING_THEN_COOPERATIVE_DRAIN_OR_EXACT_OWNED_TREE_TERMINATION",
      session_invalidation: "ALL_IN_MEMORY_OPERATOR_SESSIONS_INVALIDATED_ON_STOP",
      remaining_canonical_work: reconcile().items.filter((item) => !item.classification.startsWith("COMPLETED_")),
    }),
    authenticateStop: (token, body) => owner.authenticateStop(token, body),
    recordInterruption: (record) => {
      const reconciliation = reconcile();
      let item = reconciliation.items.find((candidate) => candidate.mission_id === record.missionId && candidate.mission_revision === record.revision && candidate.run_id === record.preparation?.run_id);
      if (!item) {
        const runtimeQueue = record.preparation?.queue_result_path ? path.join(path.dirname(record.preparation.queue_result_path), "qd.json") : null;
        const queuePaths = [record.preparation?.queue_record_path, runtimeQueue].filter((candidate) => candidate && existsSync(candidate));
        const evidenceHash = createHash("sha256").update(JSON.stringify({
          mission_id: record.missionId,
          mission_revision: record.revision,
          run_id: record.preparation?.run_id,
          queue_hashes: queuePaths.map((candidate) => sha256File(candidate)),
        })).digest("hex");
        item = {
          recovery_item_id: `recovery-${evidenceHash.slice(0, 32)}`,
          evidence_hash: evidenceHash,
          mission_id: record.missionId,
          mission_revision: record.revision,
          run_id: record.preparation?.run_id,
          result_id: record.preparation?.run_id,
          classification: "INTERRUPTED_PROCESS_GONE",
          canonical_paths: { queue_documents: queuePaths, runtime_queue_document: runtimeQueue ? [runtimeQueue] : [] },
          last_canonical_event: queuePaths[0] ? { path: queuePaths[0] } : null,
        };
      }
      return writeInterruptionEvidence({
        item,
        reason: "HQ_DISPATCH_SERVER_SHUTDOWN_DURING_EXECUTION",
        serverInstanceId: owner.serverInstanceId,
        operatorInitiated: true,
      });
    },
    requestStop: null,
  };
  return lifecycle;
}

async function runServerChild(fixtureRoot, phase) {
  const queueRoot = path.join(fixtureRoot, "queue");
  const initialDoctorRuntime = phase === "RECOVERY" ? CANONICAL_RUNTIME_ROOT : path.join(fixtureRoot, "doctor-runtime");
  mkdirSync(queueRoot, { recursive: true });
  mkdirSync(initialDoctorRuntime, { recursive: true });
  const doctor = runDoctor({ runtimeRoot: initialDoctorRuntime, queueRoot, allowDirtyForTest: true });
  if (!doctor.safe_to_start) {
    process.stderr.write(`${JSON.stringify({ schema_version: "tsf_real_proof_start_block_v1", phase, doctor })}\n`);
    process.exitCode = 4;
    return;
  }

  const owner = new ProcessOwnership({ mode: "REAL_TSF_LOCAL_PROOF" });
  owner.claim();
  let server;
  let closing = null;
  try {
    const lifecycle = buildLifecycle(owner, queueRoot);
    const barrierHarness = phase === "INTERRUPTION" ? createFixtureOnlyInterruptionBarrier({
      repositoryRoot: REPOSITORY_ROOT,
      powershellExe: POWERSHELL_EXE,
      owner,
      serverInstanceId: owner.serverInstanceId,
      testRunIdentity: path.basename(fixtureRoot),
      inspectProcess,
    }) : null;
    server = createHqDispatchServer({
      lifecycle,
      testOnlyQueueRoot: queueRoot,
      workerTimeoutSeconds: 180,
      testOnlyInterruptionBarrier: barrierHarness?.barrier ?? null,
    });
    const close = (reason) => {
      if (!closing) {
        closing = (async () => {
          await server.hqDispatchShutdown(reason);
          await new Promise((resolve) => {
            if (!server.listening) resolve();
            else server.close(resolve);
          });
          if (server.hqDispatchRelay.activeChild) throw new Error("OWNED_CHILD_REMAINS_AFTER_SHUTDOWN");
          owner.release();
        })();
      }
      return closing;
    };
    lifecycle.requestStop = close;
    if (barrierHarness) {
      barrierHarness.ready.catch((error) => {
        process.stderr.write(`M3 interruption barrier failed closed: ${error instanceof Error ? error.message : "UNKNOWN"}\n`);
        setImmediate(() => { void close("M3_INTERRUPTION_BARRIER_FAILED_CLOSED"); });
      });
    }
    await listenHqDispatchServer(server, HQ_PORT);
    owner.activate();
    process.stdout.write(`${JSON.stringify({
      schema_version: "tsf_real_proof_server_ready_v1",
      phase,
      process_id: process.pid,
      server_instance_id: owner.serverInstanceId,
      operator_session_generation: owner.sessionGeneration,
      host: "127.0.0.1",
      port: HQ_PORT,
      queue_root: queueRoot,
      runtime_root: CANONICAL_RUNTIME_ROOT,
      start_doctor_status: doctor.overall_status,
      start_doctor_safe: doctor.safe_to_start,
      dirty_test_caveat: doctor.repository.clean === false,
      test_interruption_barrier_injected: Boolean(barrierHarness),
      test_interruption_barrier_root: barrierHarness?.testRunRoot ?? null,
    })}\n`);
    process.once("SIGINT", () => { void close("SIGINT"); });
    process.once("SIGTERM", () => { void close("SIGTERM"); });
  } catch (error) {
    if (server?.listening) await new Promise((resolve) => server.close(resolve));
    owner.release();
    throw error;
  }
}

function startAttachedServer(fixtureRoot, phase) {
  const child = spawn(process.execPath, [TEST_PATH, "--server", fixtureRoot, phase], {
    cwd: REPOSITORY_ROOT,
    detached: false,
    windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"],
  });
  let stderr = "";
  child.stderr.on("data", (chunk) => { stderr += chunk.toString("utf8"); });
  const ready = new Promise((resolve, reject) => {
    const lines = createInterface({ input: child.stdout, crlfDelay: Infinity });
    const timer = setTimeout(() => reject(new Error(`SERVER_READY_TIMEOUT:${phase}:${stderr}`)), 20_000);
    lines.on("line", (line) => {
      try {
        const value = JSON.parse(line);
        if (value.schema_version === "tsf_real_proof_server_ready_v1") {
          clearTimeout(timer);
          resolve(value);
        }
      } catch { /* Ignore non-JSON child diagnostics. */ }
    });
    child.once("exit", (code) => {
      clearTimeout(timer);
      reject(new Error(`SERVER_EXITED_BEFORE_READY:${phase}:${code}:${stderr}`));
    });
  });
  return { child, ready, stderr: () => stderr };
}

async function waitForExit(child, timeoutMs = 20_000) {
  if (child.exitCode !== null) return child.exitCode;
  return Promise.race([
    new Promise((resolve) => child.once("exit", resolve)),
    new Promise((_, reject) => setTimeout(() => reject(new Error("ATTACHED_SERVER_EXIT_TIMEOUT")), timeoutMs)),
  ]);
}

function invokeExactStop() {
  return new Promise((resolve, reject) => {
    const child = spawn(POWERSHELL_EXE, ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", STOP_PATH], {
      cwd: REPOSITORY_ROOT,
      detached: false,
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => { stdout += chunk.toString("utf8"); });
    child.stderr.on("data", (chunk) => { stderr += chunk.toString("utf8"); });
    const timer = setTimeout(() => {
      child.kill();
      reject(new Error(`EXACT_STOP_TIMEOUT:${stdout}:${stderr}`));
    }, 35_000);
    child.once("error", (error) => {
      clearTimeout(timer);
      reject(error);
    });
    child.once("close", (code) => {
      clearTimeout(timer);
      if (code !== 0) {
        reject(new Error(`EXACT_STOP_FAILED:${code}:${stdout}:${stderr}`));
        return;
      }
      try { resolve(JSON.parse(stdout.trim())); }
      catch (error) { reject(new Error(`EXACT_STOP_OUTPUT_INVALID:${error.message}:${stdout}:${stderr}`)); }
    });
  });
}

async function httpJson(pathname, { method = "GET", token = null, origin = null, body = null } = {}) {
  const headers = { Accept: "application/json" };
  if (origin) headers.Origin = origin;
  if (token) headers["X-TSF-HQ-Session"] = token;
  if (body !== null) headers["Content-Type"] = "application/json";
  const response = await fetch(`http://127.0.0.1:${HQ_PORT}${pathname}`, {
    method,
    headers,
    body: body === null ? undefined : JSON.stringify(body),
  });
  const text = await response.text();
  return { status: response.status, json: text ? JSON.parse(text) : null };
}

async function issueSession() {
  const origin = `http://127.0.0.1:${HQ_PORT}`;
  const response = await httpJson("/api/v1/session", { method: "POST", origin, body: {} });
  if (response.status !== 200) throw new Error(`SESSION_ISSUE_FAILED:${response.status}`);
  return { origin, token: response.json.session_token, generation: response.json.operator_session_generation };
}

async function runProof() {
  const trackedBefore = stableTrackedStatus();
  const testRunIdentity = `run-${Date.now().toString(36)}-${process.pid}`;
  const fixtureRoot = path.join(REPOSITORY_ROOT, FIXTURE_RELATIVE_ROOT, testRunIdentity);
  const queueRoot = path.join(fixtureRoot, "queue");
  const doctorRuntime = path.join(fixtureRoot, "doctor-runtime");
  mkdirSync(queueRoot, { recursive: true });
  mkdirSync(doctorRuntime, { recursive: true });

  const initialDoctor = runDoctor({ runtimeRoot: doctorRuntime, queueRoot, allowDirtyForTest: true });
  check(["GREEN", "GREEN_WITH_CAVEATS"].includes(initialDoctor.overall_status), "initial Doctor is GREEN or GREEN_WITH_CAVEATS");
  equal(initialDoctor.safe_to_start, true, "initial Doctor permits the isolated foreground proof");
  equal(initialDoctor.read_only, true, "Doctor remains read-only");

  const idle = startAttachedServer(fixtureRoot, "IDLE");
  const idleReady = await idle.ready;
  equal(idleReady.host, "127.0.0.1", "Start binds only to fixed loopback");
  equal(idleReady.port, HQ_PORT, "Start uses fixed port 4317");
  check(inspectListeners(HQ_PORT).some((listener) => listener.process_id === idleReady.process_id && listener.host === "127.0.0.1"), "exact Start process owns the loopback listener");
  const activeDoctor = runDoctor({ runtimeRoot: doctorRuntime, queueRoot, allowDirtyForTest: true });
  equal(activeDoctor.process_owner.disposition, "ACTIVE_OWNER_CONFIRMED", "Doctor recognizes the exact active owner");
  equal(activeDoctor.safe_to_start, false, "Doctor rejects a second active instance");
  const secondStart = spawnSync(process.execPath, [TEST_PATH, "--server", fixtureRoot, "SECOND_INSTANCE"], { cwd: REPOSITORY_ROOT, encoding: "utf8", windowsHide: true, timeout: 20_000 });
  check(secondStart.status !== 0, "second Start is rejected");
  const idleSession = await issueSession();
  equal(idleSession.generation, idleReady.operator_session_generation, "fresh operator session is bound to the owner generation");
  const idleStop = await invokeExactStop();
  equal(idleStop.status, "GREEN", "public Stop completes exact idle-owner cleanup");
  equal(idleStop.operator_session_invalidated, true, "Stop invalidates the operator session");
  equal(await waitForExit(idle.child), 0, "idle foreground Start exits after cooperative Stop");
  equal(readOwnership().disposition, "ABSENT", "idle owner evidence is removed only by its exact owner");
  equal(inspectListeners(HQ_PORT).length, 0, "idle Stop closes the loopback listener");

  const interruptedServer = startAttachedServer(fixtureRoot, "INTERRUPTION");
  const interruptedReady = await interruptedServer.ready;
  equal(interruptedReady.test_interruption_barrier_injected, true, "only the dedicated interruption server receives the in-memory barrier");
  equal(path.resolve(interruptedReady.test_interruption_barrier_root), path.resolve(fixtureRoot), "barrier is confined to the exact committed fixture root");
  const session = await issueSession();
  const naturalRequest = `Read only fleet/control/policy-manifest.v1.json and return the exact bounded TSF fixture response. Proof ${randomUUID()}.`;
  const preview = await httpJson("/api/v1/route-preview", { method: "POST", token: session.token, origin: session.origin, body: { natural_request: naturalRequest } });
  equal(preview.status, 200, "real proof route preview succeeds");
  const submission = {
    natural_request: naturalRequest,
    preview_id: preview.json.preview_id,
    preview_sha256: preview.json.preview_sha256,
    request_hash: preview.json.request_hash,
    intent: "CREATE_GOVERNED_MISSION",
    submission_id: preview.json.submission_id,
  };
  let missionTransport = null;
  const missionPromise = httpJson("/api/v1/missions", { method: "POST", token: session.token, origin: session.origin, body: submission })
    .then((value) => { missionTransport = value; return value; })
    .catch((error) => { missionTransport = { transport_error: String(error.message) }; return missionTransport; });

  const barrierPath = path.join(fixtureRoot, "BARRIER_READY.json");
  const barrierReady = await waitFor(() => existsSync(barrierPath) ? readJson(barrierPath) : null, 240_000, "M3_REAL_INTERRUPTION_BARRIER_NOT_READY", 25);
  equal(barrierReady.fixture_type, FIXTURE_TYPE, "barrier evidence is bound to the exact committed fixture identity");
  equal(barrierReady.test_run_identity, testRunIdentity, "barrier evidence is bound to the exact test-run identity");
  equal(barrierReady.hook_point, BARRIER_HOOK_POINT, "barrier activates only at the real app-server pre-terminal hook point");
  equal(barrierReady.terminal_result_present, false, "barrier observes no terminal result");
  equal(barrierReady.verifier_result_present, false, "barrier observes no verifier result");
  equal(barrierReady.admission_receipt_present, false, "barrier observes no admission receipt");
  const runningOwner = await waitFor(() => {
    const ownership = readOwnership();
    return ownership.owner?.active_mission?.run_id && ownership.owner?.owned_children?.length ? ownership.owner : null;
  }, 60_000, "MISSION_DID_NOT_REACH_RUNNING");
  const originalMissionId = runningOwner.active_mission.mission_id;
  const originalRunId = runningOwner.active_mission.run_id;
  const ownedExecutor = runningOwner.owned_children[0];
  check(inspectProcess(ownedExecutor.process_id), "HQ Dispatch owns the exact foreground executor process");
  equal(barrierReady.owned_executor_process_id, ownedExecutor.process_id, "barrier evidence binds the exact recorded executor PID");
  equal(barrierReady.owned_executor_start_time, ownedExecutor.process_start_time, "barrier evidence binds the exact executor start time");
  const suspendedAppServer = inspectProcess(barrierReady.app_server_process_id);
  check(suspendedAppServer, "real app-server child remains alive at the barrier");
  equal(Date.parse(suspendedAppServer.process_start_time), Date.parse(barrierReady.app_server_process_start_time), "barrier binds the app-server PID against start-time reuse");
  const interruptedTree = descendants(interruptedReady.process_id);
  check(interruptedTree.some((entry) => entry.process_id === ownedExecutor.process_id), "recorded executor is inside the server-owned process tree");
  check(interruptedTree.some((entry) => entry.process_id === barrierReady.app_server_process_id), "real app-server is a descendant of the exact owned execution tree");
  const runningProjection = recoveryProjection(queueRoot).items.find((item) => item.mission_id === originalMissionId && item.run_id === originalRunId);
  equal(runningProjection.classification, "RUNNING_PROCESS_CONFIRMED", "canonical reconciliation sees a running owned process at the barrier");
  equal(runningProjection.admission_state.status, "ABSENT", "no admission exists at the barrier");
  equal(runningProjection.verifier_state.verdict, "ABSENT", "no verifier exists at the barrier");
  const unrelatedHarnessIdentity = inspectProcess(process.pid);
  check(unrelatedHarnessIdentity, "unrelated harness process identity is captured before Stop");
  const stopRequestedAt = new Date().toISOString();
  const interruptedStop = await invokeExactStop();
  equal(interruptedStop.status, "GREEN", "public Stop terminates only the exact owned execution tree");
  equal(interruptedStop.accepted.active_mission.mission_id, originalMissionId, "Stop reports the exact interrupted mission");
  equal(interruptedStop.operator_session_invalidated, true, "interruption Stop invalidates the operator session");
  equal(await waitForExit(interruptedServer.child), 0, "interrupted foreground Start exits cleanly");
  await missionPromise;
  equal(inspectProcess(ownedExecutor.process_id), null, "owned foreground executor exits after controlled Stop");
  equal(inspectProcess(barrierReady.app_server_process_id), null, "suspended real app-server child exits through exact tree termination");
  equal(inspectProcess(process.pid)?.process_start_time, unrelatedHarnessIdentity.process_start_time, "unrelated harness process remains untouched by Stop");
  equal(inspectListeners(HQ_PORT).length, 0, "interruption Stop closes the listener");
  equal(readOwnership().disposition, "ABSENT", "interruption Stop leaves no owner record");

  const interruptedProjection = recoveryProjection(queueRoot);
  const interruptedItem = interruptedProjection.items.find((item) => item.mission_id === originalMissionId && item.run_id === originalRunId);
  check(interruptedItem, "restart reconciliation retains the interrupted canonical mission");
  equal(interruptedItem.classification, "INTERRUPTED_PROCESS_GONE", "restart reconciliation classifies the gone process as interrupted");
  check(interruptedItem.interruption_evidence?.path && existsSync(interruptedItem.interruption_evidence.path), "canonical interruption evidence is preserved");
  equal(interruptedItem.operator_message, "NEW_RUN_REQUIRED", "interrupted mission presents NEW_RUN_REQUIRED");
  const originalHashes = hashCanonicalPaths(interruptedItem);
  check(originalHashes.size > 0, "original canonical paths are hash-bound before recovery");
  const restartDoctor = runDoctor({ runtimeRoot: CANONICAL_RUNTIME_ROOT, queueRoot, allowDirtyForTest: true });
  check(restartDoctor.interrupted_missions > 0, "restart Doctor detects the interrupted mission");
  equal(restartDoctor.mission_resumed, false, "restart Doctor does not resume the old mission");
  equal(readOwnership().disposition, "ABSENT", "no automatic rerun process exists before operator recovery");

  const recoveryServer = startAttachedServer(fixtureRoot, "RECOVERY");
  const recoveryReady = await recoveryServer.ready;
  const recoveryOwnerBefore = readOwnership().owner;
  equal(recoveryOwnerBefore.active_mission, null, "recovery Start does not silently resume the interrupted mission");
  equal(recoveryOwnerBefore.owned_children.length, 0, "recovery Start launches no worker before operator consent");
  const recoverySession = await issueSession();
  const recoveryList = await httpJson("/api/v1/recovery");
  equal(recoveryList.status, 200, "Recovery Center reads canonical evidence");
  const freshItem = recoveryList.json.items.find((item) => item.mission_id === originalMissionId && item.run_id === originalRunId);
  equal(freshItem.classification, "INTERRUPTED_PROCESS_GONE", "Recovery Center shows the exact interrupted item");
  const recoveryInput = {
    recovery_item_id: freshItem.recovery_item_id,
    evidence_hash: freshItem.evidence_hash,
    action: "RETRY_AS_NEW_RUN",
    operator_confirmation: "RETRY_AS_NEW_RUN",
  };
  const recoveryResult = await httpJson("/api/v1/recovery", { method: "POST", token: recoverySession.token, origin: recoverySession.origin, body: recoveryInput });
  equal(recoveryResult.status, 200, `explicit operator recovery completes through the canonical action endpoint:${JSON.stringify(recoveryResult.json)}`);
  const newRun = recoveryResult.json.new_run;
  check(newRun.mission_id !== originalMissionId, "recovery creates a new mission identity");
  check(newRun.run_id !== originalRunId, "recovery creates a new run identity");
  equal(newRun.old_thread_or_turn_resumed, false, "recovery never resumes the old thread or turn");
  check(["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(newRun.state), "new run independently reaches canonical admission");
  equal(newRun.verifier.verified, true, "new run independently verifies");
  check(newRun.verifier.result_path && existsSync(newRun.verifier.result_path), "new run verifier artifact is preserved");
  equal(newRun.verifier.result_sha256, sha256File(newRun.verifier.result_path), "new run verifier hash is independently reproduced");
  const recoveryVerifier = readJson(newRun.verifier.result_path);
  equal(recoveryVerifier.mission_id, newRun.mission_id, "verifier top-level mission identity binds the new mission");
  equal(recoveryVerifier.mission_revision, newRun.mission_revision, "verifier top-level revision binds the governed new revision");
  equal(recoveryVerifier.run_id, newRun.run_id, "verifier top-level run identity binds the new run");
  equal(recoveryVerifier.result_id, newRun.result_id, "verifier top-level result identity binds the admitted result");
  equal(recoveryVerifier.exact_response_evidence.mission_revision, newRun.mission_revision, "verifier nested exact-response revision agrees with its top-level identity");
  check(newRun.preservation.packet_path && existsSync(newRun.preservation.packet_path), "new run preservation packet is retained");
  equal(newRun.preservation.packet_sha256, sha256File(newRun.preservation.packet_path), "new run preservation packet hash is independently reproduced");
  check(newRun.preservation.manifest_path && existsSync(newRun.preservation.manifest_path), "new run preservation manifest is retained");
  equal(newRun.preservation.manifest_sha256, sha256File(newRun.preservation.manifest_path), "new run preservation manifest hash is independently reproduced");
  equal(newRun.access.control_plane_service_network_policy, "CODEX_SERVICE_ONLY", "new run uses CODEX_SERVICE_ONLY control-plane policy");
  equal(newRun.access.worker_tool_network_policy, "DISABLED", "new run keeps worker-tool network disabled");
  equal(newRun.worker.observation_claims.worker_tool_network.value, false, "new run observes worker-tool network disabled");
  check(newRun.worker.thread_id && newRun.worker.turn_id, "new run records distinct real app-server thread and turn identities");
  check(recoveryResult.json.receipt?.receipt_path && existsSync(recoveryResult.json.receipt.receipt_path), "canonical recovery receipt is preserved");
  const recoveryReceiptHash = sha256File(recoveryResult.json.receipt.receipt_path);
  const originalHashesAfter = hashCanonicalPaths(interruptedItem);
  check(sameHashes(originalHashes, originalHashesAfter), "original run canonical files remain byte-immutable after new-run recovery");
  const idempotent = await httpJson("/api/v1/recovery", { method: "POST", token: recoverySession.token, origin: recoverySession.origin, body: recoveryInput });
  equal(idempotent.status, 200, "exact recovery replay returns a canonical response");
  equal(idempotent.json.idempotent_replay, true, "exact recovery replay is idempotent");
  equal(idempotent.json.receipt.receipt_id, recoveryResult.json.receipt.receipt_id, "recovery replay returns the same receipt identity");
  const changedReplay = await httpJson("/api/v1/recovery", { method: "POST", token: recoverySession.token, origin: recoverySession.origin, body: { ...recoveryInput, operator_confirmation: "DECLINE_RECOVERY" } });
  equal(changedReplay.status, 422, "changed recovery replay fails closed");
  const finalProjection = recoveryProjection(queueRoot);
  const preservedOriginal = finalProjection.items.find((item) => item.mission_id === originalMissionId && item.run_id === originalRunId);
  const admittedNew = finalProjection.items.find((item) => item.mission_id === newRun.mission_id && item.run_id === newRun.run_id);
  equal(preservedOriginal.classification, "INTERRUPTED_PROCESS_GONE", "original run remains interrupted after successful recovery");
  check(["COMPLETED_ADMITTED", "COMPLETED_ADMITTED_WITH_CAVEATS"].includes(admittedNew.classification), "new run reconciles as independently admitted");
  const recoveryAdapterPath = admittedNew.canonical_paths.adapter?.[0];
  const recoveryAdapter = recoveryAdapterPath ? readJson(recoveryAdapterPath) : null;
  check(recoveryAdapter?.transport_success && recoveryAdapter?.child_exited && recoveryAdapter?.no_orphan_process, "new run preserves a successful bounded real app-server adapter receipt");
  equal(recoveryAdapter.thread_id, newRun.worker.thread_id, "new-run thread identity is canonical");
  equal(recoveryAdapter.turn_id, newRun.worker.turn_id, "new-run turn identity is canonical");
  check(recoveryAdapter.child_process_id > 0, "new run records the real app-server child PID");

  const recoveryStop = await invokeExactStop();
  equal(recoveryStop.status, "GREEN", "recovery server stops through exact ownership evidence");
  equal(await waitForExit(recoveryServer.child), 0, "recovery foreground Start exits cleanly");
  equal(inspectListeners(HQ_PORT).length, 0, "final listener cleanup is exact");
  equal(readOwnership().disposition, "ABSENT", "final owner cleanup is exact");
  equal(stableTrackedStatus(), trackedBefore, "Git tracked and untracked candidate state is unchanged by real proofs");

  const result = {
    schema_version: "tsf_hq_dispatch_real_reliability_proof_v1",
    status: "PASS",
    assertions,
    fixture_root: fixtureRoot,
    initial_doctor_status: initialDoctor.overall_status,
    idle_server: { process_id: idleReady.process_id, server_instance_id: idleReady.server_instance_id, stop_status: idleStop.status },
    interrupted_server: {
      process_id: interruptedReady.process_id,
      server_instance_id: interruptedReady.server_instance_id,
      mission_id: originalMissionId,
      run_id: originalRunId,
      executor_process_id: ownedExecutor.process_id,
      executor_process_start_time: ownedExecutor.process_start_time,
      app_server_process_id: barrierReady.app_server_process_id,
      app_server_process_start_time: barrierReady.app_server_process_start_time,
      barrier_hook_point: barrierReady.hook_point,
      barrier_ready_path: barrierPath,
      barrier_ready_sha256: sha256File(barrierPath),
      stop_requested_at: stopRequestedAt,
      final_queue_state: interruptedItem.last_known_queue_state,
      interruption_evidence_path: interruptedItem.interruption_evidence.path,
      interruption_evidence_sha256: interruptedItem.interruption_evidence.sha256,
      submission_transport_after_stop: missionTransport,
    },
    recovery_server: {
      process_id: recoveryReady.process_id,
      server_instance_id: recoveryReady.server_instance_id,
      new_mission_id: newRun.mission_id,
      new_run_id: newRun.run_id,
      new_result_id: newRun.result_id,
      final_state: newRun.state,
      thread_id: newRun.worker.thread_id,
      turn_id: newRun.worker.turn_id,
      app_server_process_id: recoveryAdapter.child_process_id,
      app_server_process_start_time: recoveryAdapter.started_at,
      verifier_identity: newRun.verifier.identity,
      verifier_result_path: newRun.verifier.result_path,
      verifier_result_sha256: newRun.verifier.result_sha256,
      preservation_packet_path: newRun.preservation.packet_path,
      preservation_packet_sha256: newRun.preservation.packet_sha256,
      preservation_manifest_path: newRun.preservation.manifest_path,
      preservation_manifest_sha256: newRun.preservation.manifest_sha256,
      admission_receipt_id: newRun.admission.receipt_id,
      admission_receipt_path: newRun.admission.receipt_path,
      admission_receipt_sha256: newRun.admission.receipt_sha256,
      recovery_receipt_id: recoveryResult.json.receipt.receipt_id,
      recovery_receipt_path: recoveryResult.json.receipt.receipt_path,
      recovery_receipt_sha256: recoveryReceiptHash,
    },
    loopback_host: "127.0.0.1",
    loopback_port: HQ_PORT,
    operator_session_invalidated: true,
    original_run_immutable: true,
    automatic_rerun_performed: false,
    old_thread_or_turn_resumed: false,
    control_plane_service_network_policy: "CODEX_SERVICE_ONLY",
    worker_tool_network_policy: "DISABLED",
    product_repository_used: false,
    plugin_used: false,
    credential_value_accessed: false,
    background_or_detached_process_created: false,
    empty_sha256: EMPTY_SHA256,
  };
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

if (process.argv[2] === "--server") {
  runServerChild(path.resolve(process.argv[3]), process.argv[4] ?? "UNKNOWN").catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.stack : String(error)}\n`);
    process.exitCode = 1;
  });
} else {
  runProof().catch(async (error) => {
    process.stderr.write(`${error instanceof Error ? error.stack : String(error)}\n`);
    if (readOwnership().disposition === "ACTIVE_OWNER_CONFIRMED") {
      try { await invokeExactStop(); }
      catch (cleanupError) { process.stderr.write(`REAL_PROOF_FAILURE_CLEANUP_FAILED:${cleanupError instanceof Error ? cleanupError.message : "UNKNOWN"}\n`); }
    }
    process.exitCode = 1;
  });
}
