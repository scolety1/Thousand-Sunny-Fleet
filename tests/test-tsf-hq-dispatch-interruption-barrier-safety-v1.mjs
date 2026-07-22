import assert from "node:assert/strict";
import { spawn, spawnSync, execFileSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { mkdirSync, readFileSync, rmSync } from "node:fs";
import path from "node:path";
import { createInterface } from "node:readline";
import { fileURLToPath } from "node:url";
import {
  HqMissionRelay,
  createM3RealInterruptionBarrier,
} from "../tools/hq-dispatch/v1/mission-relay.mjs";
import {
  ProcessOwnership,
  inspectProcess,
  inspectProcessWithParent,
} from "../tools/hq-dispatch/v1/reliability.mjs";
import {
  selectAuthoritativeSpawnEvent,
  validateAuthoritativeSpawnEvidence,
  waitForAuthoritativeSpawnEvent,
} from "./support/tsf-hq-dispatch-m3-real-interruption-barrier.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-m3-real-interruption-v1");
const fixtureType = "TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1";
const powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
const access = Object.freeze({
  permission_mode: "READ_ONLY",
  worker_tool_network_policy: "DISABLED",
  control_plane_service_network_policy: "CODEX_SERVICE_ONLY",
  allowed_writes: [],
  repository: root,
  product_repository_targeted: false,
});
let assertions = 0;

function check(value, message) {
  assertions += 1;
  assert.ok(value, message);
}

function hashObject(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function barrierFixture({ onOwnedExecutor = async () => {}, onOwnedCleanup = async () => {}, timeoutMs = 180_000 } = {}) {
  const capability = Object.freeze(Object.create(null));
  const barrier = createM3RealInterruptionBarrier({
    repositoryRoot: root,
    fixtureType,
    fixtureRoot,
    testRunIdentity: "run-safety-0001",
    access,
    inMemoryCapability: capability,
    onOwnedExecutor,
    onOwnedCleanup,
    timeoutMs,
  });
  return { barrier, capability };
}

function throws(code, overrides = {}) {
  assertions += 1;
  assert.throws(() => createM3RealInterruptionBarrier({
    repositoryRoot: root,
    fixtureType,
    fixtureRoot,
    testRunIdentity: "run-safety-0001",
    access,
    inMemoryCapability: Object.freeze(Object.create(null)),
    onOwnedExecutor: async () => {},
    onOwnedCleanup: async () => {},
    ...overrides,
  }), new RegExp(code));
}

const productionRelay = new HqMissionRelay({
  repositoryRoot: root,
  powershellExe: "powershell.exe",
  invokePreview: async () => { throw new Error("NOT_USED"); },
});
check(productionRelay.testOnlyInterruptionBarrier === null, "production relay has no interruption barrier");

let directInjectionObserved = false;
let cleanupObserved = false;
const injected = barrierFixture({
  onOwnedExecutor: async (context) => { directInjectionObserved = context.proof === true; return "READY"; },
  onOwnedCleanup: async () => { cleanupObserved = true; return "CLEAN"; },
});
const testRelay = new HqMissionRelay({
  repositoryRoot: root,
  powershellExe: "powershell.exe",
  invokePreview: async () => { throw new Error("NOT_USED"); },
  testOnlyInterruptionBarrier: injected.barrier,
});
check(testRelay.testOnlyInterruptionBarrier === injected.barrier, "branded direct in-memory injection is accepted");
check(await injected.barrier.activate(injected.capability, { proof: true }) === "READY" && directInjectionObserved, "exact direct test capability activates its committed callback");
check(await injected.barrier.cleanup(injected.capability) === "CLEAN" && cleanupObserved, "exact direct test capability activates its cleanup callback");
assertions += 1;
assert.throws(() => injected.barrier.activate(Object.freeze(Object.create(null)), {}), /IN_MEMORY_CAPABILITY_REJECTED/);
assertions += 1;
assert.throws(() => injected.barrier.cleanup(Object.freeze(Object.create(null))), /IN_MEMORY_CAPABILITY_REJECTED/);

throws("FIXTURE_IDENTITY_REJECTED", { fixtureType: "CHANGED_FIXTURE" });
throws("FIXTURE_ROOT_REJECTED", { fixtureRoot: path.join(root, ".codex-local", "fixtures", "another-root") });
throws("TEST_RUN_IDENTITY_REJECTED", { testRunIdentity: "bad" });
throws("IN_MEMORY_CAPABILITY_REQUIRED", { inMemoryCapability: null });
throws("FIXTURE_ACCESS_REJECTED", { access: { ...access, permission_mode: "WORKSPACE_WRITE" } });
throws("FIXTURE_ACCESS_REJECTED", { access: { ...access, worker_tool_network_policy: "ENABLED" } });
throws("FIXTURE_ACCESS_REJECTED", { access: { ...access, control_plane_service_network_policy: "PUBLIC" } });
throws("FIXTURE_ACCESS_REJECTED", { access: { ...access, allowed_writes: ["output.txt"] } });
throws("FIXTURE_ACCESS_REJECTED", { access: { ...access, repository: "C:\\Product", product_repository_targeted: true } });
throws("OWNED_EXECUTOR_HOOK_REQUIRED", { onOwnedExecutor: null });
throws("OWNED_CLEANUP_HOOK_REQUIRED", { onOwnedCleanup: null });
throws("TIMEOUT_REJECTED", { timeoutMs: 0 });

assertions += 1;
assert.throws(() => new HqMissionRelay({
  repositoryRoot: root,
  powershellExe: "powershell.exe",
  invokePreview: async () => {},
  testOnlyInterruptionBarrier: Object.freeze({ fixture_type: fixtureType }),
}), /IN_MEMORY_CAPABILITY_REJECTED/);

const commit = execFileSync("git.exe", ["-C", root, "rev-parse", "HEAD"], { encoding: "utf8", windowsHide: true }).trim();
const tree = execFileSync("git.exe", ["-C", root, "rev-parse", "HEAD^{tree}"], { encoding: "utf8", windowsHide: true }).trim();
const expectedSpawn = {
  mission_id: "hq2-safety-exact",
  mission_revision: 1,
  run_id: "canonical-result-hq2-safety-exact-1",
  result_id: "canonical-result-hq2-safety-exact-1",
  worktree: root,
  commit,
  tree,
  not_before_utc: "2026-01-01T00:00:00.000Z",
};
function spawnEvidence(overrides = {}) {
  const body = {
    schema_version: "tsf_codex_app_server_authoritative_spawn_v1",
    event_type: "AUTHORITATIVE_APP_SERVER_SPAWN",
    mission_id: expectedSpawn.mission_id,
    mission_revision: expectedSpawn.mission_revision,
    run_id: expectedSpawn.run_id,
    result_id: expectedSpawn.result_id,
    child_process_instance_id: randomUUID(),
    app_server_process_id: 41001,
    app_server_process_start_time: "2026-07-18T07:00:00.0000000Z",
    app_server_executable: "C:\\Codex\\codex.exe",
    app_server_parent_process_id: 41000,
    app_server_parent_process_start_time: "2026-07-18T06:59:59.0000000Z",
    app_server_parent_executable: "C:\\Node\\node.exe",
    repository_worktree: root,
    candidate_commit: commit,
    candidate_tree: tree,
    creation_event_timestamp: "2026-07-18T07:00:00.000Z",
    launch_identity_sha256: "a".repeat(64),
    ...overrides,
  };
  return { ...body, ownership_source_sha256: hashObject(body) };
}
function entry(value) { return { sequence: 1, direction: "adapter_internal", message: value }; }

const exactSpawn = spawnEvidence();
check(validateAuthoritativeSpawnEvidence(exactSpawn, expectedSpawn) === exactSpawn, "authoritative spawn evidence validates exact run/candidate/process identity");
const preexisting = spawnEvidence({ mission_id: "hq2-preexisting", run_id: "canonical-result-hq2-preexisting-1", result_id: "canonical-result-hq2-preexisting-1", app_server_process_id: 40001 });
const simultaneous = spawnEvidence({ mission_id: "hq2-simultaneous", run_id: "canonical-result-hq2-simultaneous-1", result_id: "canonical-result-hq2-simultaneous-1", app_server_process_id: 42001 });
check(selectAuthoritativeSpawnEvent([entry(preexisting), entry(exactSpawn), entry(simultaneous)], expectedSpawn).app_server_process_id === exactSpawn.app_server_process_id, "pre-existing and simultaneous app servers are ignored in favor of the run-bound authoritative event");
check(selectAuthoritativeSpawnEvent([entry(preexisting), entry(simultaneous)], expectedSpawn) === null, "missing exact run never selects another app server");
assertions += 1;
assert.throws(() => validateAuthoritativeSpawnEvidence(spawnEvidence({ candidate_commit: "f".repeat(40) }), expectedSpawn), /TEST_CAPABILITY_IDENTITY_MISMATCH/);
assertions += 1;
assert.throws(() => validateAuthoritativeSpawnEvidence(spawnEvidence({ creation_event_timestamp: "2025-01-01T00:00:00.000Z" }), expectedSpawn), /PREEXISTING_PROCESS_FALSE_MATCH/);
assertions += 1;
assert.throws(() => validateAuthoritativeSpawnEvidence({ ...exactSpawn, ownership_source_sha256: "0".repeat(64) }, expectedSpawn), /APP_SERVER_CHILD_NOT_OWNED/);

let missingSpawnError;
try {
  await waitForAuthoritativeSpawnEvent({
    eventPath: "unused",
    expected: expectedSpawn,
    terminalPaths: [],
    executorChild: { exitCode: null, signalCode: null },
    timeoutMs: 30,
    intervalMs: 5,
    readEntries: () => [],
  });
} catch (error) { missingSpawnError = error; }
check(missingSpawnError?.classification === "APP_SERVER_CHILD_NOT_SPAWNED" && !missingSpawnError.message.endsWith(":null"), "missing spawn produces a closed non-null diagnostic classification");
assertions += 1;
await assert.rejects(waitForAuthoritativeSpawnEvent({
  eventPath: "unused",
  expected: expectedSpawn,
  terminalPaths: [],
  executorChild: { exitCode: 0, signalCode: null },
  timeoutMs: 30,
  intervalMs: 5,
  readEntries: () => [],
}), /CHILD_COMPLETED_BEFORE_BARRIER/);

const ownershipRoot = path.join(fixtureRoot, `run-process-owner-${process.pid}-${Date.now()}`);
mkdirSync(ownershipRoot, { recursive: true });
const owner = new ProcessOwnership({
  repositoryRoot: root,
  ownerPath: path.join(ownershipRoot, "owner.json"),
  tokenPath: path.join(ownershipRoot, "stop-token"),
  mode: "M3_PROCESS_OWNERSHIP_TEST",
});
let ownedRoot;
let ownedNestedProcessId = null;
let unrelated;
try {
  owner.claim();
  unrelated = spawn(powershell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", "Start-Sleep -Seconds 60"], { windowsHide: true, stdio: "ignore" });
  ownedRoot = spawn(powershell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", [
    `$child=Start-Process -FilePath '${powershell}' -ArgumentList @('-NoLogo','-NoProfile','-NonInteractive','-Command','Start-Sleep -Seconds 60') -PassThru -WindowStyle Hidden`,
    "[pscustomobject]@{child_process_id=$child.Id}|ConvertTo-Json -Compress",
    "$child.WaitForExit()",
  ].join("; ")], { windowsHide: true, stdio: ["ignore", "pipe", "pipe"] });
  const nested = await new Promise((resolveNested, rejectNested) => {
    const lines = createInterface({ input: ownedRoot.stdout, crlfDelay: Infinity });
    const timer = setTimeout(() => rejectNested(new Error("OWNERSHIP_TEST_NESTED_READY_TIMEOUT")), 10_000);
    lines.once("line", (line) => { clearTimeout(timer); resolveNested(JSON.parse(line)); });
    ownedRoot.once("error", (error) => { clearTimeout(timer); rejectNested(error); });
  });
  ownedNestedProcessId = Number(nested.child_process_id);
  owner.childStarted(ownedRoot);
  const rootIdentity = inspectProcess(ownedRoot.pid);
  const nestedIdentity = inspectProcessWithParent(ownedNestedProcessId);
  const unrelatedIdentity = inspectProcess(unrelated.pid);
  check(rootIdentity && nestedIdentity && unrelatedIdentity, "process-ownership test captures exact owned and unrelated identities");
  const registration = {
    rootProcessId: ownedRoot.pid,
    processes: [{
      ...nestedIdentity,
      parent_process_start_time: rootIdentity.process_start_time,
      parent_executable: rootIdentity.executable,
    }],
    capabilityIdentitySha256: "c".repeat(64),
    ownershipEvidenceSha256: "d".repeat(64),
  };
  owner.childrenStartedFromEvidence({ ...registration, serverInstanceId: owner.serverInstanceId });
  check(owner.ownsChild(ownedNestedProcessId), "exact descendant becomes owned only after identity-chain registration");
  const registryCleanup = await owner.cleanupRegisteredOwnedProcesses({ liveRootChild: ownedRoot, reason: "SYNTHETIC_EXACT_STOP" });
  check(registryCleanup.status === "CLEANUP_CONFIRMED" && registryCleanup.root_handle_required === false, "root-independent registry cleanup reaches a stable terminal generation");
  const cleanup = owner.childrenExitedFromEvidence(registration);
  check(cleanup.length === 1 && inspectProcess(ownedNestedProcessId) === null, "Stop terminates and closes only the exact registered owned chain");
  const unrelatedAfter = inspectProcess(unrelated.pid);
  check(unrelatedAfter && Date.parse(unrelatedAfter.process_start_time) === Date.parse(unrelatedIdentity.process_start_time), "unrelated simultaneous process remains untouched by exact owned-tree Stop");
} finally {
  if (ownedRoot && inspectProcess(ownedRoot.pid)) spawnSync("C:\\Windows\\System32\\taskkill.exe", ["/PID", String(ownedRoot.pid), "/F"], { windowsHide: true });
  if (ownedNestedProcessId && inspectProcess(ownedNestedProcessId)) spawnSync("C:\\Windows\\System32\\taskkill.exe", ["/PID", String(ownedNestedProcessId), "/F"], { windowsHide: true });
  if (unrelated && inspectProcess(unrelated.pid)) unrelated.kill();
  owner.release();
  rmSync(ownershipRoot, { recursive: true, force: true });
}

const priorEnvironment = process.env.TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1;
process.env.TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1 = "enabled";
const environmentRelay = new HqMissionRelay({ repositoryRoot: root, powershellExe: "powershell.exe", invokePreview: async () => {} });
check(environmentRelay.testOnlyInterruptionBarrier === null, "environment variables cannot activate the barrier");
if (priorEnvironment === undefined) delete process.env.TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1;
else process.env.TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1 = priorEnvironment;

const forbiddenSurfaceFiles = [
  "tools/hq-dispatch/v1/Start-TsfHqDispatchV1.ps1",
  "tools/hq-dispatch/v1/Test-TsfHqDispatchDoctorV1.ps1",
  "tools/hq-dispatch/v1/Stop-TsfHqDispatchV1.ps1",
  "tools/hq-dispatch/v1/Start-TsfHqDispatchDemoV1.ps1",
  "tools/hq-dispatch/v1/public/app.js",
  "tools/hq-dispatch/v1/public/index.html",
];
for (const relative of forbiddenSurfaceFiles) {
  const source = readFileSync(path.join(root, relative), "utf8");
  check(!/InterruptionBarrier|REAL_INTERRUPTION_FIXTURE|BARRIER_READY/i.test(source), `${relative} cannot expose the barrier`);
}

const serverSource = readFileSync(path.join(root, "tools", "hq-dispatch", "v1", "server.mjs"), "utf8");
check(/server = createHqDispatchServer\(\{ lifecycle \}\)/.test(serverSource), "production main constructs the server without a test barrier");
check(!/process\.env[^\n]*InterruptionBarrier|url\.searchParams[^\n]*InterruptionBarrier|req\.headers[^\n]*InterruptionBarrier/i.test(serverSource), "HTTP, query, header, and environment paths cannot activate the barrier");
const relaySource = readFileSync(path.join(root, "tools", "hq-dispatch", "v1", "mission-relay.mjs"), "utf8");
check(!/naturalRequest[^\n]*testOnlyInterruptionBarrier|queue[^\n]*testOnlyInterruptionBarrier|response[^\n]*testOnlyInterruptionBarrier/i.test(relaySource), "mission, queue, approval, and clarification content cannot activate the barrier");

process.stdout.write(`${JSON.stringify({
  schema_version: "tsf_hq_dispatch_m3_interruption_barrier_safety_test_v2",
  status: "PASS",
  assertions,
  fixture_type: fixtureType,
  ownership_test: "EXACT_ROOT_AND_DESCENDANT_TERMINATED_UNRELATED_PROCESS_UNTOUCHED",
  production_activation_surfaces: [],
})}\n`);
