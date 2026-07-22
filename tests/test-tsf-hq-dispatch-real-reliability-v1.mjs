import assert from "node:assert/strict";
import { spawn, spawnSync, execFileSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import {
  CANONICAL_RUNTIME_ROOT,
  HQ_PORT,
  POWERSHELL_EXE,
  ProcessOwnership,
  REPOSITORY_ROOT,
  inspectListeners,
  inspectProcess,
  inspectProcessWithParent,
  readOwnership,
  reconcileCanonicalState,
  runDoctor,
  stopRequestEvidence,
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
import { verifyRecoveryResultContractEvidence } from "./support/tsf-hq-dispatch-recovery-result-contract-proof.mjs";
import {
  allocateInitialDoctorIsolation,
  runInitialDoctorPair,
} from "./support/tsf-hq-dispatch-initial-doctor-isolation.mjs";
import {
  EXACT_STOP_OWNER_EVIDENCE_REFRESHED,
  validateFreshExactStopEvidence,
  verifyInterruptedStopContract,
} from "./support/tsf-stop-receipt-contract.mjs";
import { ProofTraceRecorder } from "./support/tsf-proof-fetch-trace.mjs";
import { ProcessActionLedger, readProcessActionLedger, validateCausalProcessSafety, validateProcessActionLedgerIntegrity, validateRegistryLedgerSynchronization } from "./support/tsf-process-action-ledger.mjs";

const TEST_PATH = fileURLToPath(import.meta.url);
const EMPTY_SHA256 = createHash("sha256").update("").digest("hex");
const REAL_RECOVERY_ACTION_HTTP_TIMEOUT_MS = 240_000;
let assertions = 0;
let activeProofContext = null;
let activeProofTrace = null;
const activeProofState = {
  known_identities: {},
  proof_process_ids: new Set(),
  cleanup_error: null,
};

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

function sha256Text(value) {
  return createHash("sha256").update(String(value), "utf8").digest("hex");
}

function hashObject(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
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

async function waitForBarrierReady({ barrierPath, diagnosticPath, serverStderr, timeoutMs = 240_000 }) {
  const deadline = Date.now() + timeoutMs;
  let diagnostic = existsSync(diagnosticPath) ? readJson(diagnosticPath) : { barrier_state: "DIAGNOSTIC_NOT_YET_CREATED" };
  while (Date.now() < deadline) {
    if (existsSync(barrierPath)) return readJson(barrierPath);
    if (existsSync(diagnosticPath)) {
      diagnostic = readJson(diagnosticPath);
      if (["FAILED", "FAILED_CLEANED"].includes(diagnostic.barrier_state)) {
        throw new Error(`M3_REAL_INTERRUPTION_BARRIER_NOT_READY:${JSON.stringify({ diagnostic, server_stderr: serverStderr() })}`);
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 25));
  }
  throw new Error(`M3_REAL_INTERRUPTION_BARRIER_NOT_READY:${JSON.stringify({ diagnostic, server_stderr: serverStderr(), timeout_ms: timeoutMs })}`);
}

// This inventory is safety-only. It is never used to select or own the proof child.
function inventoryUnattributedAppServers() {
  const script = [
    "$rows=@(Get-CimInstance Win32_Process -ErrorAction Stop|Where-Object{[string]$_.CommandLine -match '(?i)(^|\\s)app-server(\\s|$)'}|ForEach-Object{",
    "  $p=Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue",
    "  if($null-ne$p){[pscustomobject]@{process_id=[int]$_.ProcessId;parent_process_id=[int]$_.ParentProcessId;process_start_time=$p.StartTime.ToUniversalTime().ToString('o');executable=[string]$p.Path}}",
    "});ConvertTo-Json -Compress -InputObject @($rows)",
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

function recoveryProjection(queueRoot, ownerPath) {
  return reconcileCanonicalState({
    runtimeRoot: CANONICAL_RUNTIME_ROOT,
    queueRoot,
    ownership: readOwnership(ownerPath),
    testOnlyAllowAlternateQueueRoot: true,
  });
}

function buildLifecycle(owner, queueRoot, context) {
  const reconcile = () => recoveryProjection(queueRoot, context.owner_path);
  const lifecycle = {
    mode: "REAL_TSF_LOCAL_PROOF",
    owner,
    localRoot: context.evidence_root,
    sessionGeneration: owner.sessionGeneration,
    serverInstanceId: owner.serverInstanceId,
    doctor: () => runDoctor({ runtimeRoot: CANONICAL_RUNTIME_ROOT, queueRoot, ownerPath: context.owner_path, allowDirtyForTest: true, testOnlyAllowAlternateQueueRoot: true }),
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
      const ledgerEvents = readProcessActionLedger(context.process_action_ledger_path);
      const registrySnapshot = owner.ownedProcessRegistrySnapshot();
      validateRegistryLedgerSynchronization(registrySnapshot.entries, ledgerEvents);
      const chainRegistryEntries = registrySnapshot.entries.filter((entry) => {
        const missionIdentity = entry.proof_mission_identity ?? entry.mission_identity;
        return missionIdentity?.mission_id === record.missionId
          && Number(missionIdentity?.mission_revision) === Number(record.revision);
      });
      const chainRegistrationIds = new Set(chainRegistryEntries.map((entry) => entry.process_registration_id));
      const chainRegistrations = ledgerEvents.filter((event) => event.action_type === "REGISTER_PROOF_OWNERSHIP"
        && chainRegistrationIds.has(event.process_registration_id));
      const registrationKeys = new Set(chainRegistrations.map((event) => `${event.target_process_id}|${Date.parse(event.target_process_start_time)}`));
      const terminalEvents = ledgerEvents.filter((event) => event.action_type === "CONFIRM_PROCESS_EXIT"
        && registrationKeys.has(`${event.target_process_id}|${Date.parse(event.target_process_start_time)}`));
      const terminalKeys = new Set(terminalEvents.map((event) => `${event.target_process_id}|${Date.parse(event.target_process_start_time)}`));
      if (chainRegistrations.length === 0 || terminalEvents.length !== chainRegistrations.length || terminalKeys.size !== registrationKeys.size
          || terminalEvents.some((event) => !["COOPERATIVE_EXIT_CONFIRMED", "FORCED_TERMINATION_CONFIRMED", "ALREADY_GONE_WITH_IDENTITY_CONFIRMED"].includes(event.terminal_disposition)
            || event.post_action_observation?.alive !== false)) {
        throw new Error("EXACT_OWNED_TERMINAL_CLEANUP_SUMMARY_UNCONFIRMED");
      }
      const archivedOwnerPath = path.join(context.evidence_root, "ARCHIVED_OWNER_BEFORE_RELEASE.json");
      writeFileSync(archivedOwnerPath, `${JSON.stringify(owner.owner, null, 2)}\n`, { encoding: "utf8", flag: "wx" });
      const ledgerSnapshotPath = path.join(context.evidence_root, "PROCESS_ACTION_LEDGER_AT_STOP.jsonl");
      writeFileSync(ledgerSnapshotPath, readFileSync(context.process_action_ledger_path), { flag: "wx" });
      const unsignedCleanupSummary = {
        schema_version: "tsf_hq_dispatch_exact_cleanup_summary_v1",
        status: "CLEANUP_CONFIRMED",
        server_instance_id: owner.serverInstanceId,
        mission_id: item.mission_id,
        mission_revision: item.mission_revision,
        run_id: item.run_id,
        result_id: item.result_id,
        process_action_ledger_path: path.resolve(ledgerSnapshotPath),
        process_action_ledger_sha256: sha256File(ledgerSnapshotPath),
        terminal_dispositions: terminalEvents.map((event) => ({
          process_id: event.target_process_id,
          process_start_time: event.target_process_start_time,
          executable_identity_sha256: event.target_executable_identity_sha256,
          ownership_evidence_sha256: event.ownership_evidence_sha256,
          terminal_disposition: event.terminal_disposition,
          terminal_evidence_sha256: event.evidence_sha256,
        })).sort((left, right) => left.process_id - right.process_id),
        archived_owner_path: path.resolve(archivedOwnerPath),
        archived_owner_sha256: sha256File(archivedOwnerPath),
        generated_at: new Date().toISOString(),
      };
      const cleanupSummary = { ...unsignedCleanupSummary, cleanup_summary_sha256: hashObject(unsignedCleanupSummary) };
      const interruption = writeInterruptionEvidence({
        item,
        reason: "HQ_DISPATCH_SERVER_SHUTDOWN_DURING_EXECUTION",
        serverInstanceId: owner.serverInstanceId,
        operatorInitiated: true,
        cleanupSummary,
      });
      context.last_interruption_evidence = interruption;
      context.last_cleanup_summary = cleanupSummary;
      return interruption;
    },
    requestStop: null,
  };
  return lifecycle;
}

async function runServerChild(context, phase) {
  const fixtureRoot = context.fixture_root;
  const queueRoot = context.queue_root;
  const initialDoctorRuntime = phase === "RECOVERY" ? CANONICAL_RUNTIME_ROOT : context.runtime_root;
  mkdirSync(queueRoot, { recursive: true });
  mkdirSync(initialDoctorRuntime, { recursive: true });
  const doctor = runDoctor({ runtimeRoot: initialDoctorRuntime, queueRoot, ownerPath: context.owner_path, allowDirtyForTest: true, testOnlyAllowAlternateQueueRoot: true });
  if (!doctor.safe_to_start) {
    process.stderr.write(`${JSON.stringify({ schema_version: "tsf_real_proof_start_block_v1", phase, doctor })}\n`);
    process.exitCode = 4;
    return;
  }

  const owner = new ProcessOwnership({ ownerPath: context.owner_path, tokenPath: context.token_path, mode: "REAL_TSF_LOCAL_PROOF" });
  owner.claim();
  const processLedger = new ProcessActionLedger({ filePath: context.process_action_ledger_path, writerIdentity: `${phase}-server-${process.pid}` });
  owner.setProcessActionRecorder((action) => processLedger.record({
    ...action,
    proof_identity: context.test_run_identity,
    candidate_worktree: context.candidate_worktree,
    candidate_commit: context.candidate_commit,
  }), { ledgerPath: context.process_action_ledger_path });
  const ownerProcess = inspectProcessWithParent(process.pid);
  processLedger.record({
    proof_stage: `${phase}_SERVER_OWNERSHIP_REGISTRATION`, action_type: "REGISTER_PROOF_OWNERSHIP",
    target_process_id: ownerProcess.process_id, target_process_start_time: ownerProcess.process_start_time,
    target_executable_identity: ownerProcess.executable, ownership_classification: "PROOF_OWNED",
    ownership_evidence_sha256: owner.owner.evidence_hash, parent_identity: { process_id: ownerProcess.parent_process_id, process_start_time: ownerProcess.parent_process_start_time ?? null, executable: ownerProcess.parent_executable ?? null },
    server_instance_id: owner.serverInstanceId, proof_identity: context.test_run_identity,
    candidate_worktree: context.candidate_worktree, candidate_commit: context.candidate_commit,
    launch_identity_sha256: context.server_launch_identity_sha256, reason: "FOREGROUND_PROOF_SERVER_SPAWN",
    requested_operation: "REGISTER_EXACT_OWNER", os_api_result: { status: "REGISTERED" },
  });
  let server;
  let closing = null;
  try {
    const lifecycle = buildLifecycle(owner, queueRoot, context);
    const barrierHarness = phase === "INTERRUPTION" ? createFixtureOnlyInterruptionBarrier({
      repositoryRoot: REPOSITORY_ROOT,
      powershellExe: POWERSHELL_EXE,
      owner,
      serverInstanceId: owner.serverInstanceId,
      testRunIdentity: path.basename(fixtureRoot),
      inspectProcess,
    }) : null;
    lifecycle.shutdownEvidence = () => ({
      cleanup_summary: context.last_cleanup_summary ?? null,
      interruption: context.last_interruption_evidence ?? null,
    });
    lifecycle.finalizeOwnedCleanup = async () => {
      if (!barrierHarness) return { disposition: "NOT_APPLICABLE_NO_TEST_BARRIER" };
      return barrierHarness.finalizeServerCleanup({
        listenerAbsent: false,
        ownerAbsent: false,
        sessionInvalidated: false,
        stopRecordPath: context.last_interruption_evidence?.stop_record_path ?? null,
        cleanupSummary: context.last_cleanup_summary ?? null,
      });
    };
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
          if (server.hqDispatchRelay.activeChild) throw new Error("OWNED_CHILD_REMAINS_AFTER_SHUTDOWN");
          server.hqDispatchFinalizeResponse("FOREGROUND_SIGNAL_OR_INTERNAL_SHUTDOWN");
        })();
      }
      return closing;
    };
    lifecycle.requestStop = (reason) => {
      const current = inspectProcessWithParent(process.pid) ?? ownerProcess;
      processLedger.record({
        proof_stage: `${phase}_SERVER_OWNERSHIP_REFRESH`, action_type: "REGISTER_PROOF_OWNERSHIP",
        target_process_id: ownerProcess.process_id, target_process_start_time: ownerProcess.process_start_time,
        target_executable_identity: ownerProcess.executable, ownership_classification: "PROOF_OWNED",
        ownership_evidence_sha256: owner.owner.evidence_hash,
        parent_identity: { process_id: current.parent_process_id ?? null, process_start_time: current.parent_process_start_time ?? null, executable: current.parent_executable ?? null },
        server_instance_id: owner.serverInstanceId, proof_identity: context.test_run_identity,
        mission_identity: owner.owner.active_mission ?? null, candidate_worktree: context.candidate_worktree,
        candidate_commit: context.candidate_commit, launch_identity_sha256: context.server_launch_identity_sha256,
        reason: "REFRESH_IMMUTABLE_OWNER_HASH_BEFORE_STOP", requested_operation: "REGISTER_EXACT_OWNER",
        os_api_result: { status: "REGISTERED" },
      });
      processLedger.record({
        proof_stage: `${phase}_COOPERATIVE_STOP`, action_type: "REQUEST_COOPERATIVE_STOP",
        target_process_id: ownerProcess.process_id, target_process_start_time: ownerProcess.process_start_time,
        target_executable_identity: ownerProcess.executable, ownership_classification: "PROOF_OWNED",
        ownership_evidence_sha256: owner.owner.evidence_hash, parent_identity: { process_id: current.parent_process_id ?? null, process_start_time: current.parent_process_start_time ?? null, executable: current.parent_executable ?? null },
        server_instance_id: owner.serverInstanceId, proof_identity: context.test_run_identity,
        mission_identity: owner.owner.active_mission ?? null, candidate_worktree: context.candidate_worktree,
        candidate_commit: context.candidate_commit, launch_identity_sha256: context.server_launch_identity_sha256,
        reason, requested_operation: "IN_PROCESS_COOPERATIVE_SERVER_STOP", os_api_result: { status: "REQUEST_ACCEPTED" },
      });
      return close(reason);
    };
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
      owner_path: context.owner_path,
      start_doctor_status: doctor.overall_status,
      start_doctor_safe: doctor.safe_to_start,
      dirty_test_caveat: doctor.repository.clean === false,
      test_interruption_barrier_injected: Boolean(barrierHarness),
      test_interruption_barrier_root: barrierHarness?.testRunRoot ?? null,
      test_interruption_barrier_diagnostic_path: barrierHarness?.diagnosticPath ?? null,
    })}\n`);
    process.once("SIGINT", () => { void close("SIGINT"); });
    process.once("SIGTERM", () => { void close("SIGTERM"); });
  } catch (error) {
    if (server?.listening) await new Promise((resolve) => server.close(resolve));
    owner.release();
    throw error;
  }
}

function encodedContext(context) {
  return Buffer.from(JSON.stringify(context), "utf8").toString("base64url");
}

function startAttachedServer(context, phase) {
  const childContext = { ...context, server_launch_identity_sha256: sha256Text(JSON.stringify({ phase, proof_identity: context.test_run_identity, candidate_commit: context.candidate_commit, worktree: context.candidate_worktree })) };
  const child = spawn(process.execPath, [TEST_PATH, "--server", phase, encodedContext(childContext)], {
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

async function invokeExactStop(context, boundEvidence = null, {
  stageId = "EXACT_STOP",
  expectedSessionGeneration = null,
  identities = {},
} = {}) {
  const { owner, token, listeners, stop_authentication_hash } = boundEvidence ?? stopRequestEvidence({ ownerPath: context.owner_path, tokenPath: context.token_path });
  const stopRequest = { server_instance_id: owner.server_instance_id, evidence_hash: stop_authentication_hash, process_id: owner.process_id };
  if (!activeProofTrace) throw new Error("PROOF_FETCH_TRACE_NOT_INITIALIZED");
  const response = await activeProofTrace.httpJson({
    stageId,
    caller: "invokeExactStop",
    method: "POST",
    host: owner.host,
    port: owner.port,
    pathname: "/api/v1/admin/stop",
    expectedServerInstance: owner.server_instance_id,
    expectedSessionGeneration,
    headers: { Accept: "application/json", "Content-Type": "application/json", "X-TSF-HQ-Stop": token, Host: `${owner.host}:${owner.port}` },
    body: stopRequest,
    identities,
  });
  const accepted = response.json;
  if (response.status !== 202) throw new Error(`EXACT_OWNER_STOP_REJECTED:${response.status}:${accepted?.error?.code ?? "UNKNOWN"}`);
  const cleanup = await waitFor(() => {
    const value = {
      process_gone: !inspectProcess(owner.process_id),
      owned_children_gone: (owner.owned_children ?? []).every((child) => !inspectProcess(child.process_id)),
      exact_listener_gone: !inspectListeners(owner.port).some((listener) => Number(listener.process_id) === owner.process_id),
      ownership_record_gone: readOwnership(context.owner_path).disposition === "ABSENT",
    };
    return Object.values(value).every(Boolean) ? value : null;
  }, 30_000, "EXACT_STOP_CLEANUP_NOT_CONFIRMED", 100);
  const confirmationLedger = new ProcessActionLedger({ filePath: context.process_action_ledger_path, writerIdentity: `proof-harness-${process.pid}` });
  confirmationLedger.record({
    proof_stage: `${stageId}_SERVER_EXIT_CONFIRMATION`, action_type: "CONFIRM_PROCESS_EXIT",
    target_process_id: owner.process_id, target_process_start_time: owner.process_start_time,
    target_executable_identity: owner.executable, ownership_classification: "PROOF_OWNED",
    ownership_evidence_sha256: owner.evidence_hash,
    parent_identity: { process_id: owner.parent_process_id ?? null, process_start_time: owner.parent_process_start_time ?? null, executable: owner.parent_executable ?? null },
    server_instance_id: owner.server_instance_id, proof_identity: context.test_run_identity,
    mission_identity: identities, candidate_worktree: context.candidate_worktree,
    candidate_commit: context.candidate_commit, reason: "POST_STOP_EXACT_SERVER_IDENTITY_OBSERVATION",
    requested_operation: "OBSERVE_EXACT_IDENTITY", os_api_result: { status: "OBSERVED_ABSENT" },
    post_action_observation: { alive: false }, terminal_disposition: "COOPERATIVE_EXIT_CONFIRMED",
    cooperative_request_identity: `${owner.server_instance_id}:${stageId}`, observed_exit_or_close_at: new Date().toISOString(),
    exit_code_disposition: "EXIT_CODE_NOT_EXPOSED_BY_PARENT_INVENTORY", pid_reuse_check: "PID_ABSENT_NO_REUSE_OBSERVED",
  });
  return {
    schema_version: "tsf_hq_dispatch_stop_result_v1",
    status: "GREEN",
    server_instance_id: owner.server_instance_id,
    targeted_process_id: owner.process_id,
    stop_request: stopRequest,
    accepted,
    cleanup,
    listeners_observed_before_stop: listeners,
    operator_session_invalidated: Boolean(accepted?.operator_session_invalidated),
    canonical_records_preserved: Boolean(accepted?.canonical_records_preserved),
    unrelated_processes_terminated: false,
  };
}

async function httpJson(pathname, {
  stageId,
  caller = "httpJson",
  method = "GET",
  token = null,
  origin = null,
  body = null,
  server,
  expectedSessionGeneration = null,
  identities = {},
  timeoutMs = 15_000,
} = {}) {
  if (!activeProofTrace) throw new Error("PROOF_FETCH_TRACE_NOT_INITIALIZED");
  if (!stageId || !server?.server_instance_id) throw new Error("PROOF_FETCH_STAGE_AND_SERVER_BINDING_REQUIRED");
  const headers = { Accept: "application/json" };
  if (origin) headers.Origin = origin;
  if (token) headers["X-TSF-HQ-Session"] = token;
  if (body !== null) headers["Content-Type"] = "application/json";
  return activeProofTrace.httpJson({
    stageId,
    caller,
    method,
    host: "127.0.0.1",
    port: HQ_PORT,
    pathname,
    expectedServerInstance: server.server_instance_id,
    expectedSessionGeneration,
    headers,
    body,
    identities,
    timeoutMs,
  });
}

async function issueSession(server, stageId) {
  const origin = `http://127.0.0.1:${HQ_PORT}`;
  const response = await httpJson("/api/v1/session", { stageId, caller: "issueSession", method: "POST", origin, body: {}, server });
  if (response.status !== 200) throw new Error(`SESSION_ISSUE_FAILED:${response.status}`);
  return { origin, token: response.json.session_token, generation: response.json.operator_session_generation };
}

async function runProof() {
  const testRunIdentity = `run-${Date.now().toString(36)}-${process.pid}-${randomUUID().slice(0, 8)}`;
  const context = allocateInitialDoctorIsolation({ repositoryRoot: REPOSITORY_ROOT, fixtureRelativeRoot: FIXTURE_RELATIVE_ROOT, testRunIdentity });
  Object.assign(context, {
    test_run_identity: testRunIdentity,
    candidate_worktree: REPOSITORY_ROOT,
    candidate_commit: execFileSync("git.exe", ["-C", REPOSITORY_ROOT, "rev-parse", "HEAD"], { encoding: "utf8", windowsHide: true }).trim(),
    process_action_ledger_path: path.join(context.evidence_root, "PROCESS_ACTION_LEDGER.jsonl"),
  });
  activeProofContext = context;
  activeProofState.known_identities.test_run_identity = testRunIdentity;
  activeProofState.known_identities.candidate_head = execFileSync("git.exe", ["-C", REPOSITORY_ROOT, "rev-parse", "HEAD"], { encoding: "utf8", windowsHide: true }).trim();
  activeProofState.known_identities.candidate_tree = execFileSync("git.exe", ["-C", REPOSITORY_ROOT, "rev-parse", "HEAD^{tree}"], { encoding: "utf8", windowsHide: true }).trim();
  const fixtureRoot = context.fixture_root;
  const queueRoot = context.queue_root;
  const doctorRuntime = context.runtime_root;
  const { report: initialDoctor, diagnostic: initialDoctorDiagnostic } = runInitialDoctorPair(context, {
    environmentBefore: {
      TSF_HQ_RUNTIME_ROOT: process.env.TSF_HQ_RUNTIME_ROOT ?? null,
      TSF_HQ_QUEUE_ROOT: process.env.TSF_HQ_QUEUE_ROOT ?? null,
      TSF_HQ_OWNER_ROOT: process.env.TSF_HQ_OWNER_ROOT ?? null,
    },
  });
  activeProofTrace = new ProofTraceRecorder({
    evidenceRoot: context.evidence_root,
    port: HQ_PORT,
    inspectOwner: () => readOwnership(context.owner_path),
    inspectListeners,
  });
  const initialDoctorStage = activeProofTrace.startStage("INITIAL_ISOLATED_DOCTOR", {
    operation: "FIRST_STATE_OBSERVATION_RESULT",
    invocation_order: initialDoctorDiagnostic.invocation_order,
  });
  activeProofTrace.completeStage(initialDoctorStage, {
    overall_status: initialDoctor.overall_status,
    safe_to_start: initialDoctor.safe_to_start,
    diagnostic_path: initialDoctorDiagnostic.diagnostic_path,
    diagnostic_sha256: initialDoctorDiagnostic.diagnostic_sha256,
  });
  const trackedBefore = stableTrackedStatus();
  check(["GREEN", "GREEN_WITH_CAVEATS"].includes(initialDoctor.overall_status), "initial Doctor is GREEN or GREEN_WITH_CAVEATS");
  equal(initialDoctor.safe_to_start, true, "initial Doctor permits the isolated foreground proof");
  equal(initialDoctor.read_only, true, "Doctor remains read-only");
  equal(initialDoctorDiagnostic.classification_agreement, true, "initial Doctor human and JSON classifications agree");
  equal(initialDoctorDiagnostic.invocation_order[0], "JSON_FIRST_STATE_OBSERVATION", "initial Doctor JSON is the first state observation after isolated root allocation");

  const idle = startAttachedServer(context, "IDLE");
  const idleReady = await idle.ready;
  activeProofState.proof_process_ids.add(idleReady.process_id);
  equal(idleReady.host, "127.0.0.1", "Start binds only to fixed loopback");
  equal(idleReady.port, HQ_PORT, "Start uses fixed port 4317");
  check(inspectListeners(HQ_PORT).some((listener) => listener.process_id === idleReady.process_id && listener.host === "127.0.0.1"), "exact Start process owns the loopback listener");
  const activeDoctor = runDoctor({ runtimeRoot: doctorRuntime, queueRoot, ownerPath: context.owner_path, allowDirtyForTest: true, testOnlyAllowAlternateQueueRoot: true });
  equal(activeDoctor.process_owner.disposition, "ACTIVE_OWNER_CONFIRMED", "Doctor recognizes the exact active owner");
  equal(activeDoctor.safe_to_start, false, "Doctor rejects a second active instance");
  const secondStart = spawnSync(process.execPath, [TEST_PATH, "--server", "SECOND_INSTANCE", encodedContext(context)], { cwd: REPOSITORY_ROOT, encoding: "utf8", windowsHide: true, timeout: 20_000 });
  check(secondStart.status !== 0, "second Start is rejected");
  const idleSession = await issueSession(idleReady, "IDLE_SESSION_ISSUE");
  equal(idleSession.generation, idleReady.operator_session_generation, "fresh operator session is bound to the owner generation");
  const idleStop = await invokeExactStop(context, null, {
    stageId: "IDLE_SERVER_EXACT_STOP",
    expectedSessionGeneration: idleReady.operator_session_generation,
  });
  equal(idleStop.status, "GREEN", "exact stop contract completes isolated idle-owner cleanup");
  equal(idleStop.operator_session_invalidated, true, "Stop invalidates the operator session");
  equal(await waitForExit(idle.child), 0, "idle foreground Start exits after cooperative Stop");
  activeProofTrace.markServerStopped(idleReady.server_instance_id, { owner_absent: true, listener_absent: true });
  equal(readOwnership(context.owner_path).disposition, "ABSENT", "idle owner evidence is removed only by its exact owner");
  equal(inspectListeners(HQ_PORT).length, 0, "idle Stop closes the loopback listener");

  const unattributedBeforeStop = inventoryUnattributedAppServers();
  const parentLedger = new ProcessActionLedger({ filePath: context.process_action_ledger_path, writerIdentity: `proof-harness-${process.pid}` });
  for (const unattributed of unattributedBeforeStop) parentLedger.record({
    proof_stage: "UNATTRIBUTED_BASELINE_INVENTORY", action_type: "OBSERVE_PROCESS",
    target_process_id: unattributed.process_id, target_process_start_time: unattributed.process_start_time,
    target_executable_identity: unattributed.executable, ownership_classification: "UNATTRIBUTED",
    parent_identity: { process_id: unattributed.parent_process_id }, reason: "SAFETY_INVENTORY_ONLY",
    requested_operation: "OBSERVE_ONLY", os_api_result: { status: "OBSERVED" }, post_action_observation: { alive: true },
  });

  const interruptedServer = startAttachedServer(context, "INTERRUPTION");
  const interruptedReady = await interruptedServer.ready;
  activeProofState.proof_process_ids.add(interruptedReady.process_id);
  activeProofState.known_identities.interrupted_server_instance_id = interruptedReady.server_instance_id;
  equal(interruptedReady.test_interruption_barrier_injected, true, "only the dedicated interruption server receives the in-memory barrier");
  equal(path.resolve(interruptedReady.test_interruption_barrier_root), path.resolve(fixtureRoot), "barrier is confined to the exact committed fixture root");
  const session = await issueSession(interruptedReady, "INTERRUPTION_SESSION_ISSUE");
  equal(session.generation, interruptedReady.operator_session_generation, "interruption session is bound to the exact server generation");
  const naturalRequest = `Read only fleet/control/policy-manifest.v1.json and return the exact bounded TSF fixture response. Proof ${randomUUID()}.`;
  const preview = await httpJson("/api/v1/route-preview", { stageId: "INTERRUPTION_ROUTE_PREVIEW", method: "POST", token: session.token, origin: session.origin, body: { natural_request: naturalRequest }, server: interruptedReady, expectedSessionGeneration: session.generation });
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
  const missionPromise = httpJson("/api/v1/missions", { stageId: "INTERRUPTION_MISSION_SUBMISSION", method: "POST", token: session.token, origin: session.origin, body: submission, server: interruptedReady, expectedSessionGeneration: session.generation })
    .then((value) => { missionTransport = value; return value; })
    .catch((error) => {
      activeProofTrace.markControlledFailure(error.stage_id ?? "INTERRUPTION_MISSION_SUBMISSION", { controlled_reason: "REQUEST_REMAINS_IN_FLIGHT_UNTIL_EXACT_STOP" });
      missionTransport = { transport_error: String(error.message), disposition: "CONTROLLED_FAILURE" }; return missionTransport;
    });

  const barrierPath = path.join(fixtureRoot, "BARRIER_READY.json");
  const barrierDiagnosticPath = path.join(fixtureRoot, "BARRIER_DIAGNOSTIC.json");
  const barrierReady = await waitForBarrierReady({
    barrierPath,
    diagnosticPath: barrierDiagnosticPath,
    serverStderr: interruptedServer.stderr,
  });
  equal(barrierReady.fixture_type, FIXTURE_TYPE, "barrier evidence is bound to the exact committed fixture identity");
  equal(barrierReady.test_run_identity, testRunIdentity, "barrier evidence is bound to the exact test-run identity");
  equal(barrierReady.hook_point, BARRIER_HOOK_POINT, "barrier activates only at the real app-server pre-terminal hook point");
  equal(barrierReady.terminal_result_present, false, "barrier observes no terminal result");
  equal(barrierReady.verifier_result_present, false, "barrier observes no verifier result");
  equal(barrierReady.admission_receipt_present, false, "barrier observes no admission receipt");
  equal(barrierReady.candidate_commit, execFileSync("git.exe", ["-C", REPOSITORY_ROOT, "rev-parse", "HEAD"], { encoding: "utf8", windowsHide: true }).trim(), "barrier binds the exact candidate commit");
  equal(barrierReady.candidate_tree, execFileSync("git.exe", ["-C", REPOSITORY_ROOT, "rev-parse", "HEAD^{tree}"], { encoding: "utf8", windowsHide: true }).trim(), "barrier binds the exact candidate tree");
  check(/^[a-f0-9]{64}$/.test(barrierReady.capability_identity_sha256), "barrier evidence binds the direct in-memory capability identity hash");
  check(/^[a-f0-9]{64}$/.test(barrierReady.authoritative_spawn_sha256), "barrier evidence binds the authoritative adapter spawn event");
  check(/^[a-f0-9]{64}$/.test(barrierReady.ownership_evidence_sha256), "barrier evidence binds exact process ownership");
  check(Array.isArray(barrierReady.owned_process_chain) && barrierReady.owned_process_chain.length >= 2, "barrier preserves the exact executor-to-app-server ownership chain");
  const runningOwner = readJson(context.owner_path);
  check(runningOwner.active_mission?.run_id && runningOwner.owned_children?.length, "barrier-ready owner record binds one active mission and exact owned execution tree");
  const originalMissionId = runningOwner.active_mission.mission_id;
  const originalRunId = runningOwner.active_mission.run_id;
  const originalResultId = runningOwner.active_mission.result_id;
  Object.assign(activeProofState.known_identities, {
    interrupted_mission_id: originalMissionId,
    interrupted_mission_revision: runningOwner.active_mission.mission_revision,
    interrupted_run_id: originalRunId,
    interrupted_result_id: originalResultId,
  });
  const ownedExecutor = runningOwner.owned_children.find((child) => child.process_id === barrierReady.owned_executor_process_id);
  activeProofState.proof_process_ids.add(barrierReady.owned_executor_process_id);
  activeProofState.proof_process_ids.add(barrierReady.app_server_process_id);
  check(ownedExecutor, "owner record contains the exact barrier-bound foreground executor");
  equal(barrierReady.owned_executor_process_id, ownedExecutor.process_id, "barrier evidence binds the exact recorded executor PID");
  equal(barrierReady.owned_executor_start_time, ownedExecutor.process_start_time, "barrier evidence binds the exact executor start time");
  equal(runningOwner.server_instance_id, barrierReady.server_instance_id, "owner record and barrier bind the same server instance");
  equal(originalMissionId, barrierReady.mission_id, "owner record and barrier bind the same mission");
  equal(runningOwner.active_mission.mission_revision, barrierReady.mission_revision, "owner record and barrier bind the same mission revision");
  equal(originalRunId, barrierReady.run_id, "owner record and barrier bind the same run");
  equal(originalResultId, barrierReady.result_id, "owner record and barrier bind the same result allocation");
  const stopToken = readFileSync(context.token_path, "utf8").trim();
  equal(sha256Text(stopToken), runningOwner.control_token_sha256, "immediate Stop capability is hash-bound to the exact barrier-ready owner");
  const stopViewResponse = await httpJson("/api/v1/stop-status", { stageId: "INTERRUPTION_STOP_VIEW", server: interruptedReady, expectedSessionGeneration: session.generation, identities: { mission_id: originalMissionId, mission_revision: barrierReady.mission_revision, run_id: originalRunId, result_id: originalResultId } });
  equal(stopViewResponse.status, 200, "UI Stop projection is captured before the exact Stop request");
  equal(stopViewResponse.json.server_instance, barrierReady.server_instance_id, "UI Stop projection binds the barrier-ready server instance");
  const freshStopEvidence = stopRequestEvidence({ ownerPath: context.owner_path, tokenPath: context.token_path });
  const refreshedStopEvidence = validateFreshExactStopEvidence({
    cachedOwner: runningOwner,
    freshOwner: freshStopEvidence.owner,
    expected: { mission_id: originalMissionId, mission_revision: barrierReady.mission_revision, run_id: originalRunId, result_id: originalResultId, server_instance_id: barrierReady.server_instance_id },
    tokenSha256: sha256Text(freshStopEvidence.token),
    requiredOwnedProcessIds: [barrierReady.owned_executor_process_id, barrierReady.app_server_process_id],
  });
  equal(refreshedStopEvidence.classification, EXACT_STOP_OWNER_EVIDENCE_REFRESHED, "exact Stop refreshes mutable owner evidence without changing immutable process or mission identity");
  const stopRequestedAt = new Date().toISOString();
  const interruptedStop = await invokeExactStop(context, freshStopEvidence, {
    stageId: "INTERRUPTION_SERVER_EXACT_STOP",
    expectedSessionGeneration: session.generation,
    identities: { mission_id: originalMissionId, mission_revision: barrierReady.mission_revision, run_id: originalRunId, result_id: originalResultId },
  });
  equal(interruptedStop.status, "GREEN", "exact stop contract terminates only the isolated exact-owned execution tree");
  equal(interruptedStop.operator_session_invalidated, true, "interruption Stop invalidates the operator session");
  equal(await waitForExit(interruptedServer.child), 0, "interrupted foreground Start exits cleanly");
  activeProofTrace.markServerStopped(interruptedReady.server_instance_id, { owner_absent: true, listener_absent: true, interrupted: true });
  await missionPromise;
  equal(inspectProcess(ownedExecutor.process_id), null, "owned foreground executor exits after controlled Stop");
  equal(inspectProcess(barrierReady.app_server_process_id), null, "suspended real app-server child exits through exact tree termination");
  const unrelatedProcessProofs = [];
  for (const unattributed of unattributedBeforeStop) {
    const observed = inspectProcess(unattributed.process_id);
    const sameIdentityAlive = Boolean(observed && Date.parse(observed.process_start_time) === Date.parse(unattributed.process_start_time)
      && path.resolve(observed.executable).toLowerCase() === path.resolve(unattributed.executable).toLowerCase());
    const pidReused = Boolean(observed && !sameIdentityAlive);
    const disposition = sameIdentityAlive
      ? "UNATTRIBUTED_PROCESS_OBSERVED_AND_NOT_TARGETED"
      : pidReused
        ? "UNATTRIBUTED_PROCESS_FINAL_LIVENESS_UNKNOWN_BUT_NOT_TARGETED"
        : "UNATTRIBUTED_PROCESS_EXITED_WITHOUT_TSF_CAUSAL_TERMINATION_EVIDENCE";
    parentLedger.record({
      proof_stage: "POST_INTERRUPTION_STOP_UNATTRIBUTED_DISPOSITION", action_type: "LEAVE_UNATTRIBUTED_PROCESS_UNTOUCHED",
      target_process_id: unattributed.process_id, target_process_start_time: unattributed.process_start_time,
      target_executable_identity: unattributed.executable, ownership_classification: "UNATTRIBUTED",
      parent_identity: { process_id: unattributed.parent_process_id }, reason: "NO_TSF_PROCESS_CONTROL_ACTION_TARGETED_THIS_IDENTITY",
      requested_operation: "NO_ACTION", os_api_result: { status: "NO_TSF_ACTION_ISSUED" },
      post_action_observation: { alive: pidReused ? null : sameIdentityAlive, pid_reused: pidReused }, disposition,
    });
    unrelatedProcessProofs.push({
      process_id: unattributed.process_id,
      process_start_time: unattributed.process_start_time,
      executable: unattributed.executable,
      parent_process_id: unattributed.parent_process_id,
      first_observed_at: unattributed.observed_at ?? null,
      final_observed_at: new Date().toISOString(),
      appeared_in_owned_process_registry: false,
      appeared_in_termination_target: false,
      tsf_process_control_action_targeted: false,
      owned_cleanup_disposition_assigned: false,
      disposition,
    });
  }
  let causalProcessSafety;
  try {
    const processLedgerEvents = readProcessActionLedger(context.process_action_ledger_path);
    validateProcessActionLedgerIntegrity(processLedgerEvents);
    causalProcessSafety = validateCausalProcessSafety(processLedgerEvents);
  }
  catch (error) { error.proof_stage_id = "CAUSAL_PROCESS_SAFETY_ASSERTION_AFTER_INTERRUPTION_STOP"; throw error; }
  check(causalProcessSafety.no_unattributed_termination_target, "process-action ledger proves no unattributed termination target");
  equal(inspectListeners(HQ_PORT).length, 0, "interruption Stop closes the listener");
  equal(readOwnership(context.owner_path).disposition, "ABSENT", "interruption Stop leaves no isolated owner record");
  const cleanupDiagnostic = readJson(barrierDiagnosticPath);
  equal(cleanupDiagnostic.barrier_state, "READY_CLEANED", "barrier diagnostic closes with exact owned cleanup confirmed");
  equal(cleanupDiagnostic.failure_classification, "NONE", "successful cleanup retains a non-failure classification");

  const interruptedProjection = recoveryProjection(queueRoot, context.owner_path);
  const interruptedItem = interruptedProjection.items.find((item) => item.mission_id === originalMissionId && item.run_id === originalRunId);
  check(interruptedItem, "restart reconciliation retains the interrupted canonical mission");
  equal(interruptedItem.classification, "INTERRUPTED_PROCESS_GONE", "restart reconciliation classifies the gone process as interrupted");
  check(interruptedItem.interruption_evidence?.path && existsSync(interruptedItem.interruption_evidence.path), "canonical interruption evidence is preserved");
  equal(interruptedItem.operator_message, "NEW_RUN_REQUIRED", "interrupted mission presents NEW_RUN_REQUIRED");
  const interruptionRecord = readJson(interruptedItem.interruption_evidence.path);
  const stopContractProof = verifyInterruptedStopContract({
    expected: {
      mission_id: originalMissionId,
      mission_revision: barrierReady.mission_revision,
      run_id: originalRunId,
      result_id: originalResultId,
      server_instance_id: barrierReady.server_instance_id,
      owned_child_process_id: ownedExecutor.process_id,
    },
    preStopOwner: runningOwner,
    stopRequest: interruptedStop.stop_request,
    accepted: interruptedStop.accepted,
    interruption: interruptionRecord,
    wrapperResult: interruptedStop,
    uiBeforeStop: stopViewResponse.json,
    recoveryItem: interruptedItem,
    postCleanup: {
      active_mission: null,
      owner_absent: true,
      listener_absent: true,
      owned_child_absent: true,
      operator_session_invalidated: interruptedStop.operator_session_invalidated,
    },
    unrelatedProcesses: unrelatedProcessProofs,
    unattributedProcessSafety: causalProcessSafety.unattributed_process_safety_v2,
  });
  equal(stopContractProof.classification, "ACTIVE_MISSION_CLEARED_INTERRUPTION_IDENTITY_PRESERVED", "post-cleanup active mission is cleared while immutable interrupted identity remains exact");
  equal(stopContractProof.authoritative_identity_source, "IMMUTABLE_CANONICAL_STOP_RECORD", "canonical STOP_RECORD is the authoritative interrupted identity source");
  const originalHashes = hashCanonicalPaths(interruptedItem);
  check(originalHashes.size > 0, "original canonical paths are hash-bound before recovery");
  const restartDoctor = runDoctor({ runtimeRoot: CANONICAL_RUNTIME_ROOT, queueRoot, ownerPath: context.owner_path, allowDirtyForTest: true, testOnlyAllowAlternateQueueRoot: true });
  check(restartDoctor.interrupted_missions > 0, "restart Doctor detects the interrupted mission");
  equal(restartDoctor.mission_resumed, false, "restart Doctor does not resume the old mission");
  equal(readOwnership(context.owner_path).disposition, "ABSENT", "no automatic rerun process exists before operator recovery");

  const recoveryServer = startAttachedServer(context, "RECOVERY");
  const recoveryReady = await recoveryServer.ready;
  activeProofState.proof_process_ids.add(recoveryReady.process_id);
  activeProofState.known_identities.recovery_server_instance_id = recoveryReady.server_instance_id;
  const recoveryOwnerBefore = readOwnership(context.owner_path).owner;
  equal(recoveryOwnerBefore.active_mission, null, "recovery Start does not silently resume the interrupted mission");
  equal(recoveryOwnerBefore.owned_children.length, 0, "recovery Start launches no worker before operator consent");
  const recoverySession = await issueSession(recoveryReady, "RECOVERY_SESSION_ISSUE");
  equal(recoverySession.generation, recoveryReady.operator_session_generation, "recovery session is bound to the exact server generation");
  const recoveryList = await httpJson("/api/v1/recovery", { stageId: "RECOVERY_LIST", server: recoveryReady, expectedSessionGeneration: recoverySession.generation });
  equal(recoveryList.status, 200, "Recovery Center reads canonical evidence");
  const freshItem = recoveryList.json.items.find((item) => item.mission_id === originalMissionId && item.run_id === originalRunId);
  equal(freshItem.classification, "INTERRUPTED_PROCESS_GONE", "Recovery Center shows the exact interrupted item");
  const recoveryInput = {
    recovery_item_id: freshItem.recovery_item_id,
    evidence_hash: freshItem.evidence_hash,
    action: "RETRY_AS_NEW_RUN",
    operator_confirmation: "RETRY_AS_NEW_RUN",
  };
  const recoveryResult = await httpJson("/api/v1/recovery", { stageId: "RECOVERY_ACTION", method: "POST", token: recoverySession.token, origin: recoverySession.origin, body: recoveryInput, server: recoveryReady, expectedSessionGeneration: recoverySession.generation, timeoutMs: REAL_RECOVERY_ACTION_HTTP_TIMEOUT_MS, identities: { mission_id: originalMissionId, mission_revision: barrierReady.mission_revision, run_id: originalRunId, result_id: originalResultId } });
  equal(recoveryResult.status, 200, `explicit operator recovery completes through the canonical action endpoint:${JSON.stringify(recoveryResult.json)}`);
  const newRun = recoveryResult.json.new_run;
  Object.assign(activeProofState.known_identities, {
    recovery_mission_id: newRun.mission_id,
    recovery_mission_revision: newRun.mission_revision,
    recovery_run_id: newRun.run_id,
    recovery_result_id: newRun.result_id,
    recovery_receipt_id: recoveryResult.json.receipt?.receipt_id ?? null,
  });
  if (Number.isInteger(newRun.worker?.process_id)) activeProofState.proof_process_ids.add(newRun.worker.process_id);
  check(newRun.mission_id !== originalMissionId, "recovery creates a new mission identity");
  check(newRun.run_id !== originalRunId, "recovery creates a new run identity");
  equal(newRun.old_thread_or_turn_resumed, false, "recovery never resumes the old thread or turn");
  check(["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(newRun.state), "new run independently reaches canonical admission");
  equal(newRun.verifier.verified, true, "new run independently verifies");
  equal(newRun.access.control_plane_service_network_policy, "CODEX_SERVICE_ONLY", "new run uses CODEX_SERVICE_ONLY control-plane policy");
  equal(newRun.access.worker_tool_network_policy, "DISABLED", "new run keeps worker-tool network disabled");
  equal(newRun.worker.observation_claims.worker_tool_network.value, false, "new run observes worker-tool network disabled");
  check(newRun.worker.thread_id && newRun.worker.turn_id, "new run records distinct real app-server thread and turn identities");
  check(recoveryResult.json.receipt?.receipt_path && existsSync(recoveryResult.json.receipt.receipt_path), "canonical recovery receipt is preserved");
  const idempotent = await httpJson("/api/v1/recovery", { stageId: "RECOVERY_IDEMPOTENT_REPLAY", method: "POST", token: recoverySession.token, origin: recoverySession.origin, body: recoveryInput, server: recoveryReady, expectedSessionGeneration: recoverySession.generation, identities: { mission_id: originalMissionId, mission_revision: barrierReady.mission_revision, run_id: originalRunId, result_id: originalResultId } });
  equal(idempotent.status, 200, "exact recovery replay returns a canonical response");
  equal(idempotent.json.idempotent_replay, true, "exact recovery replay is idempotent");
  equal(idempotent.json.receipt.receipt_id, recoveryResult.json.receipt.receipt_id, "recovery replay returns the same receipt identity");
  const changedReplay = await httpJson("/api/v1/recovery", { stageId: "RECOVERY_CHANGED_REPLAY_REJECTION", method: "POST", token: recoverySession.token, origin: recoverySession.origin, body: { ...recoveryInput, operator_confirmation: "DECLINE_RECOVERY" }, server: recoveryReady, expectedSessionGeneration: recoverySession.generation, identities: { mission_id: originalMissionId, mission_revision: barrierReady.mission_revision, run_id: originalRunId, result_id: originalResultId } });
  equal(changedReplay.status, 422, "changed recovery replay fails closed");

  const recoveryStop = await invokeExactStop(context, null, {
    stageId: "RECOVERY_SERVER_EXACT_STOP",
    expectedSessionGeneration: recoverySession.generation,
    identities: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision, run_id: newRun.run_id, result_id: newRun.result_id },
  });
  equal(recoveryStop.status, "GREEN", "recovery server stops through exact ownership evidence");
  equal(await waitForExit(recoveryServer.child), 0, "recovery foreground Start exits cleanly");
  activeProofTrace.markServerStopped(recoveryReady.server_instance_id, { owner_absent: true, listener_absent: true, recovery_receipt_preserved: true });
  equal(inspectListeners(HQ_PORT).length, 0, "final listener cleanup is exact");
  equal(readOwnership(context.owner_path).disposition, "ABSENT", "final isolated owner cleanup is exact");

  const durableReceipt = activeProofTrace.readDurableJson({
    stageId: "POST_STOP_RECOVERY_RECEIPT_READ",
    caller: "runProof",
    filePath: recoveryResult.json.receipt.receipt_path,
    evidenceKind: "RECOVERY_RECEIPT",
    expectedIdentity: {
      schema_version: "tsf_hq_dispatch_recovery_receipt_v1",
      receipt_id: recoveryResult.json.receipt.receipt_id,
      mission_id: originalMissionId,
      mission_revision: barrierReady.mission_revision,
      run_id: originalRunId,
      result_id: originalResultId,
    },
  });
  const recoveryReceiptHash = durableReceipt.sha256;
  const originalHashesAfter = hashCanonicalPaths(interruptedItem);
  check(sameHashes(originalHashes, originalHashesAfter), "original run canonical files remain byte-immutable after new-run recovery");

  const projectionStage = activeProofTrace.startStage("POST_STOP_FINAL_CANONICAL_RECONCILIATION", { operation: "DURABLE_PROJECTION", caller: "recoveryProjection" });
  let finalProjection;
  try {
    finalProjection = recoveryProjection(queueRoot, context.owner_path);
    activeProofTrace.completeStage(projectionStage, { item_count: finalProjection.items.length, owner_disposition: readOwnership(context.owner_path).disposition });
  } catch (error) {
    activeProofTrace.failStage(projectionStage, "DURABLE_PROJECTION_FAILURE", { error_message: error.message });
    throw error;
  }
  const preservedOriginal = finalProjection.items.find((item) => item.mission_id === originalMissionId && item.run_id === originalRunId);
  const admittedNew = finalProjection.items.find((item) => item.mission_id === newRun.mission_id && item.run_id === newRun.run_id);
  equal(preservedOriginal.classification, "INTERRUPTED_PROCESS_GONE", "original run remains interrupted after successful recovery");
  check(["COMPLETED_ADMITTED", "COMPLETED_ADMITTED_WITH_CAVEATS"].includes(admittedNew.classification), "new run reconciles as independently admitted");
  const recoveryMissionPath = admittedNew.canonical_paths.mission?.[0];
  const recoveryQueuePath = admittedNew.canonical_paths.queue_documents?.[0];
  const recoveryLifecyclePath = admittedNew.canonical_paths.lifecycle?.[0];
  const recoveryAdmissionPath = admittedNew.canonical_paths.admission?.[0];
  const interruptedMissionPath = interruptedItem.canonical_paths.mission?.[0];
  for (const [label, evidencePath] of [
    ["recovery mission", recoveryMissionPath],
    ["recovery queue", recoveryQueuePath],
    ["recovery lifecycle", recoveryLifecyclePath],
    ["recovery admission", recoveryAdmissionPath],
    ["interrupted source mission", interruptedMissionPath],
  ]) check(evidencePath && existsSync(evidencePath), `${label} evidence exists for result-contract derivation`);
  const recoveryMission = activeProofTrace.readDurableJson({ stageId: "POST_STOP_RECOVERY_MISSION_READ", caller: "runProof", filePath: recoveryMissionPath, evidenceKind: "MISSION", expectedIdentity: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision } }).json;
  const recoveryQueue = activeProofTrace.readDurableJson({ stageId: "POST_STOP_RECOVERY_QUEUE_READ", caller: "runProof", filePath: recoveryQueuePath, evidenceKind: "QUEUE_DOCUMENT", identityPath: ["durable_mission"], expectedIdentity: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision } }).json;
  const recoveryLifecycle = activeProofTrace.readDurableJson({ stageId: "POST_STOP_RECOVERY_LIFECYCLE_READ", caller: "runProof", filePath: recoveryLifecyclePath, evidenceKind: "LIFECYCLE_RESULT", expectedIdentity: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision, run_id: newRun.run_id, result_id: newRun.result_id } }).json;
  check(recoveryLifecycle.worker_result_path && existsSync(recoveryLifecycle.worker_result_path), "recovery worker result exists for result-contract derivation");
  const recoveryWorkerResultEvidence = activeProofTrace.readDurableJson({ stageId: "POST_STOP_RECOVERY_WORKER_RESULT_READ", caller: "runProof", filePath: recoveryLifecycle.worker_result_path, evidenceKind: "WORKER_RESULT_V1_NONAUTHORITATIVE_PAYLOAD", expectedIdentity: { mission_id: newRun.mission_id } });
  const recoveryWorkerResult = recoveryWorkerResultEvidence.json;
  const recoveryVerifierEvidence = activeProofTrace.readDurableJson({ stageId: "POST_STOP_RECOVERY_VERIFIER_READ", caller: "runProof", filePath: newRun.verifier.result_path, evidenceKind: "VERIFIER_RESULT", expectedIdentity: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision, run_id: newRun.run_id, result_id: newRun.result_id } });
  const recoveryVerifier = recoveryVerifierEvidence.json;
  equal(newRun.verifier.result_sha256, recoveryVerifierEvidence.sha256, "new run verifier hash is independently reproduced after Stop");
  const recoveryAdmission = activeProofTrace.readDurableJson({ stageId: "POST_STOP_RECOVERY_ADMISSION_READ", caller: "runProof", filePath: recoveryAdmissionPath, evidenceKind: "ADMISSION_RECEIPT", expectedIdentity: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision, result_id: newRun.result_id } }).json;
  const interruptedSourceMission = activeProofTrace.readDurableJson({ stageId: "POST_STOP_INTERRUPTED_SOURCE_MISSION_READ", caller: "runProof", filePath: interruptedMissionPath, evidenceKind: "INTERRUPTED_SOURCE_MISSION", expectedIdentity: { mission_id: originalMissionId, mission_revision: barrierReady.mission_revision } }).json;
  const preservationPacket = activeProofTrace.readDurableJson({ stageId: "POST_STOP_PRESERVATION_PACKET_READ", caller: "runProof", filePath: newRun.preservation.packet_path, evidenceKind: "PRESERVATION_PACKET" });
  equal(newRun.preservation.packet_sha256, preservationPacket.sha256, "new run preservation packet hash is independently reproduced after Stop");
  const preservationManifest = activeProofTrace.readDurableJson({ stageId: "POST_STOP_PRESERVATION_MANIFEST_READ", caller: "runProof", filePath: newRun.preservation.manifest_path, evidenceKind: "PRESERVATION_MANIFEST", expectedIdentity: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision, run_id: newRun.run_id } });
  equal(newRun.preservation.manifest_sha256, preservationManifest.sha256, "new run preservation manifest hash is independently reproduced after Stop");
  const recoveryAdapterPath = recoveryWorkerResult.adapter_result_path;
  const canonicalRecoveryAdapterPath = admittedNew.canonical_paths.adapter?.[0];
  check(recoveryAdapterPath && existsSync(recoveryAdapterPath), "worker-bound recovery adapter evidence exists");
  check(canonicalRecoveryAdapterPath && existsSync(canonicalRecoveryAdapterPath), "canonical preserved recovery adapter copy exists");
  const recoveryAdapterEvidence = activeProofTrace.readDurableJson({ stageId: "POST_STOP_RECOVERY_WORKER_BOUND_ADAPTER_READ", caller: "runProof", filePath: recoveryAdapterPath, evidenceKind: "APP_SERVER_ADAPTER_AUTHORITATIVE_RUNTIME", expectedIdentity: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision, run_id: newRun.run_id, result_id: newRun.result_id } });
  const canonicalRecoveryAdapterEvidence = activeProofTrace.readDurableJson({ stageId: "POST_STOP_RECOVERY_CANONICAL_ADAPTER_COPY_READ", caller: "runProof", filePath: canonicalRecoveryAdapterPath, evidenceKind: "APP_SERVER_ADAPTER_PRESERVATION_COPY", expectedIdentity: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision, run_id: newRun.run_id, result_id: newRun.result_id } });
  equal(canonicalRecoveryAdapterEvidence.sha256, recoveryAdapterEvidence.sha256, "canonical adapter preservation copy matches the worker-bound adapter bytes");
  const recoveryAdapter = recoveryAdapterEvidence.json;
  const recoveryProducerRegistryEvidence = activeProofTrace.readDurableJson({ stageId: "POST_STOP_RECOVERY_PRODUCER_REGISTRY_READ", caller: "runProof", filePath: recoveryLifecycle.producer_registry_path, evidenceKind: "PRODUCER_REGISTRY", identityPath: ["binding"], expectedIdentity: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision, run_id: newRun.run_id } });
  const recoveryCanonicalResultPath = admittedNew.canonical_paths.result?.[0];
  check(recoveryCanonicalResultPath && existsSync(recoveryCanonicalResultPath), "canonical durable result exists for revision binding");
  const recoveryCanonicalResult = activeProofTrace.readDurableJson({ stageId: "POST_STOP_RECOVERY_CANONICAL_RESULT_READ", caller: "runProof", filePath: recoveryCanonicalResultPath, evidenceKind: "CANONICAL_RESULT", expectedIdentity: { mission_id: newRun.mission_id, mission_revision: newRun.mission_revision, result_id: newRun.result_id } }).json;
  const recoveryResultContractProof = verifyRecoveryResultContractEvidence({
    mission: recoveryMission,
    queueDocument: recoveryQueue,
    workerResult: recoveryWorkerResult,
    verifier: recoveryVerifier,
    admission: recoveryAdmission,
    recoveryRun: newRun,
    lifecycle: recoveryLifecycle,
    adapter: recoveryAdapter,
    canonicalResult: recoveryCanonicalResult,
    producerRegistry: recoveryProducerRegistryEvidence.json,
    preservationManifest: preservationManifest.json,
    workerResultArtifact: { path: recoveryWorkerResultEvidence.path, sha256: recoveryWorkerResultEvidence.sha256 },
    adapterArtifact: { path: recoveryAdapterEvidence.path, sha256: recoveryAdapterEvidence.sha256 },
    canonicalAdapterArtifact: { path: canonicalRecoveryAdapterEvidence.path, sha256: canonicalRecoveryAdapterEvidence.sha256 },
    producerRegistryArtifact: { path: recoveryProducerRegistryEvidence.path, sha256: recoveryProducerRegistryEvidence.sha256 },
    interruptedSourceContract: interruptedSourceMission.exact_response_contract ?? null,
  });
  assertions += recoveryResultContractProof.assertion_count;
  check(recoveryAdapter?.transport_success && recoveryAdapter?.child_exited && recoveryAdapter?.no_orphan_process, "new run preserves a successful bounded real app-server adapter receipt");
  equal(recoveryAdapter.thread_id, newRun.worker.thread_id, "new-run thread identity is canonical");
  equal(recoveryAdapter.turn_id, newRun.worker.turn_id, "new-run turn identity is canonical");
  check(recoveryAdapter.child_process_id > 0, "new run records the real app-server child PID");
  activeProofState.proof_process_ids.add(recoveryAdapter.child_process_id);
  equal(stableTrackedStatus(), trackedBefore, "Git tracked and untracked candidate state is unchanged by real proofs");
  equal(activeProofTrace.fetchEvents.at(-1)?.proof_stage_id, "RECOVERY_SERVER_EXACT_STOP", "no HTTP operation occurs after the final confirmed Stop");
  const finalProcessLedgerEvents = readProcessActionLedger(context.process_action_ledger_path);
  validateProcessActionLedgerIntegrity(finalProcessLedgerEvents);
  causalProcessSafety = validateCausalProcessSafety(finalProcessLedgerEvents);
  check(causalProcessSafety.no_unattributed_termination_target, "final process-action ledger remains causally clean after recovery Stop");
  equal(activeProofTrace.failedStage, null, "successful proof retains no terminal failed stage");

  const result = {
    schema_version: "tsf_hq_dispatch_real_reliability_proof_v1",
    status: "PASS",
    assertions,
    fixture_root: fixtureRoot,
    initial_doctor_status: initialDoctor.overall_status,
    initial_doctor: {
      first_attempt: true,
      retry_performed: false,
      human_json_agreement: initialDoctorDiagnostic.classification_agreement,
      diagnostic_path: initialDoctorDiagnostic.diagnostic_path,
      diagnostic_sha256: initialDoctorDiagnostic.diagnostic_sha256,
      json_exit_code: initialDoctorDiagnostic.json.exit_code,
      human_exit_code: initialDoctorDiagnostic.human.exit_code,
      blocking_check_ids: initialDoctorDiagnostic.blocking_findings.map((item) => item.id),
      isolated_runtime_root: context.runtime_root,
      isolated_queue_root: context.queue_root,
      isolated_owner_root: context.owner_root,
      isolated_evidence_root: context.evidence_root,
    },
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
      barrier_diagnostic_path: barrierDiagnosticPath,
      barrier_diagnostic_sha256: sha256File(barrierDiagnosticPath),
      authoritative_spawn_sha256: barrierReady.authoritative_spawn_sha256,
      ownership_evidence_sha256: barrierReady.ownership_evidence_sha256,
      capability_identity_sha256: barrierReady.capability_identity_sha256,
      process_action_ledger_path: context.process_action_ledger_path,
      process_action_ledger_sha256: sha256File(context.process_action_ledger_path),
      causal_process_safety: causalProcessSafety,
      unattributed_app_server_processes: unrelatedProcessProofs,
      stop_requested_at: stopRequestedAt,
      final_queue_state: interruptedItem.last_known_queue_state,
      interruption_evidence_path: interruptedItem.interruption_evidence.path,
      interruption_evidence_sha256: interruptedItem.interruption_evidence.sha256,
      stop_receipt_root_cause_classification: "OTHER_EXACTLY_PROVEN_CAUSE",
      stop_receipt_root_cause: "HARNESS_POST_BARRIER_PRE_STOP_PROBES_ALLOWED_COMPLETION_RACE",
      stop_contract_classification: stopContractProof.classification,
      accepted_active_mission_disposition: stopContractProof.accepted_active_mission_disposition,
      authoritative_interrupted_identity_source: stopContractProof.authoritative_identity_source,
      accepted_stop_schema: interruptedStop.accepted?.schema_version ?? null,
      stop_request_identity: interruptedStop.stop_request,
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
      result_contract_mode: recoveryResultContractProof.validation_mode,
      exact_response_evidence_disposition: recoveryResultContractProof.exact_response_evidence_disposition,
      result_contract_assertions: recoveryResultContractProof.assertion_count,
      result_contract_evidence: {
        mission_path: recoveryMissionPath,
        queue_path: recoveryQueuePath,
        worker_result_path: recoveryLifecycle.worker_result_path,
        verifier_path: newRun.verifier.result_path,
        admission_path: recoveryAdmissionPath,
      },
    },
    fetch_diagnostics: {
      root_cause_classification: "SHARED_OR_STALE_FETCH_HELPER_STATE",
      historical_failed_stage: "RECOVERY_SERVER_EXACT_STOP",
      historical_failed_endpoint: { method: "POST", host: "127.0.0.1", port: HQ_PORT, pathname: "/api/v1/admin/stop" },
      connection_policy: "CONNECTION_CLOSE_PER_REQUEST_NO_CROSS_INSTANCE_REUSE",
      every_http_call_traced: true,
      final_http_stage: activeProofTrace.fetchEvents.at(-1)?.proof_stage_id ?? null,
      http_after_final_stop: false,
      stage_trace_path: activeProofTrace.paths.stage_trace,
      fetch_trace_path: activeProofTrace.paths.fetch_trace,
      process_ownership_trace_path: activeProofTrace.paths.ownership_trace,
    },
    durable_result_projection: {
      authority_after_stop: "CANONICAL_DURABLE_ARTIFACTS",
      recovery_receipt_path: durableReceipt.path,
      recovery_receipt_sha256: durableReceipt.sha256,
      server_restart_for_reading: false,
      session_token_required_after_stop: false,
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
  return result;
}

async function executeProofWithGuaranteedSerialization() {
  let result = null;
  let failure = null;
  try {
    result = await runProof();
  } catch (error) {
    failure = error;
    if (!activeProofTrace && activeProofContext) {
      activeProofTrace = new ProofTraceRecorder({
        evidenceRoot: activeProofContext.evidence_root,
        port: HQ_PORT,
        inspectOwner: () => readOwnership(activeProofContext.owner_path),
        inspectListeners,
      });
    }
    if (activeProofTrace) {
      const terminalStage = error.proof_stage_id ?? error.stage_id ?? `UNCAUGHT_BLOCKING_FAILURE_AFTER_${activeProofTrace.lastCompletedStage ?? "INITIALIZATION"}`;
      if (activeProofTrace.failedStage !== terminalStage) activeProofTrace.recordTerminalFailure(terminalStage, error, { terminal: true });
    }
    if (activeProofContext && readOwnership(activeProofContext.owner_path).disposition === "ACTIVE_OWNER_CONFIRMED") {
      const liveOwner = readOwnership(activeProofContext.owner_path).owner;
      try {
        await invokeExactStop(activeProofContext, null, {
          stageId: "FAILURE_CLEANUP_EXACT_STOP",
          expectedSessionGeneration: liveOwner.operator_session_generation,
          identities: liveOwner.active_mission ?? {},
        });
      } catch (cleanupError) {
        activeProofState.cleanup_error = cleanupError;
      }
    }
  } finally {
    if (!activeProofTrace && activeProofContext) {
      activeProofTrace = new ProofTraceRecorder({
        evidenceRoot: activeProofContext.evidence_root,
        port: HQ_PORT,
        inspectOwner: () => readOwnership(activeProofContext.owner_path),
        inspectListeners,
      });
    }
    if (activeProofTrace) {
      const ownership = activeProofContext ? readOwnership(activeProofContext.owner_path) : { disposition: "NO_CONTEXT" };
      const processStates = [...activeProofState.proof_process_ids]
        .filter((processId) => Number.isInteger(processId) && processId > 0)
        .map((processId) => ({ process_id: processId, alive: Boolean(inspectProcess(processId)) }));
      const cleanupState = {
        owner_disposition: ownership.disposition,
        owner_absent: ownership.disposition === "ABSENT",
        listener_count: inspectListeners(HQ_PORT).length,
        proof_processes: processStates,
        proof_owned_processes_absent: processStates.every((entry) => !entry.alive),
        cleanup_error: activeProofState.cleanup_error?.message ?? null,
      };
      activeProofTrace.writeFinal({
        status: failure ? "FAIL" : "PASS",
        result,
        error: failure,
        exitCode: failure ? 1 : 0,
        knownIdentities: activeProofState.known_identities,
        cleanupState,
      });
    }
  }
  if (failure) throw failure;
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
}

if (process.argv[2] === "--server") {
  const phase = process.argv[3] ?? "UNKNOWN";
  const context = JSON.parse(Buffer.from(process.argv[4] ?? "", "base64url").toString("utf8"));
  runServerChild(context, phase).catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.stack : String(error)}\n`);
    process.exitCode = 1;
  });
} else if (process.argv[2] === "--initial-doctor-only") {
  try {
    const testRunIdentity = `run-${Date.now().toString(36)}-${process.pid}-${randomUUID().slice(0, 8)}`;
    const context = allocateInitialDoctorIsolation({ repositoryRoot: REPOSITORY_ROOT, fixtureRelativeRoot: FIXTURE_RELATIVE_ROOT, testRunIdentity });
    const result = runInitialDoctorPair(context);
    process.stdout.write(`${JSON.stringify({
      schema_version: "tsf_hq_dispatch_initial_doctor_first_attempt_proof_v1",
      status: "PASS",
      first_attempt: true,
      retry_performed: false,
      test_run_identity: testRunIdentity,
      diagnostic: result.diagnostic,
    }, null, 2)}\n`);
  } catch (error) {
    process.stderr.write(`${error instanceof Error ? error.stack : String(error)}\n`);
    process.exitCode = 1;
  }
} else {
  executeProofWithGuaranteedSerialization().catch((error) => {
    process.stderr.write(`${error instanceof Error ? error.stack : String(error)}\n`);
    if (activeProofState.cleanup_error) process.stderr.write(`REAL_PROOF_FAILURE_CLEANUP_FAILED:${activeProofState.cleanup_error.message}\n`);
    process.exitCode = 1;
  });
}
