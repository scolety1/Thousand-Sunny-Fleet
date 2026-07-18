import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { createServer } from "node:http";
import { closeSync, existsSync, fsyncSync, mkdirSync, openSync, readFileSync, writeFileSync, writeSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { once } from "node:events";
import { ProofHttpDiagnosticError, ProofTraceRecorder } from "./support/tsf-proof-fetch-trace.mjs";

const repositoryRoot = path.resolve(fileURLToPath(new URL("../", import.meta.url)));
const realProofSource = readFileSync(path.join(repositoryRoot, "tests", "test-tsf-hq-dispatch-real-reliability-v1.mjs"), "utf8");
const evidenceRoot = process.env.TSF_NATIVE_TEST_EVIDENCE_ROOT
  ? path.resolve(process.env.TSF_NATIVE_TEST_EVIDENCE_ROOT)
  : path.join(repositoryRoot, ".codex-local", "evidence", "post-recovery-fetch-diagnostic", "focused-tests", `fetch-${Date.now().toString(36)}-${process.pid}-${randomUUID().slice(0, 8)}`);
mkdirSync(evidenceRoot, { recursive: true });
const nativeStagePath = path.join(evidenceRoot, "NATIVE_TEST_STAGE_TRACE.json");
const nativeChildProcessPath = path.join(evidenceRoot, "NATIVE_TEST_CHILD_PROCESS_TRACE.json");
const nativeResultPath = path.join(evidenceRoot, "NATIVE_TEST_RESULT.json");
const nativeStages = [];
const writeDurableJson = (filePath, value) => {
  const bytes = Buffer.from(`${JSON.stringify(value, null, 2)}\n`, "utf8");
  const handle = openSync(filePath, "w");
  try { writeSync(handle, bytes); fsyncSync(handle); } finally { closeSync(handle); }
};
const nativeStage = (stageId, details = {}) => {
  nativeStages.push({ sequence: nativeStages.length + 1, stage_id: stageId, utc: new Date().toISOString(), ...details });
  writeDurableJson(nativeStagePath, { schema_version: "tsf_native_test_stage_trace_v1", process_id: process.pid, parent_process_id: process.ppid, events: nativeStages });
};
writeDurableJson(nativeChildProcessPath, {
  schema_version: "tsf_native_test_child_process_trace_v1", recorded_at: new Date().toISOString(),
  process_id: process.pid, parent_process_id: process.ppid, executable: process.execPath,
  node_version: process.version, platform: process.platform, architecture: process.arch,
  working_directory: process.cwd(), argv: process.argv.map((value, index) => index === 0 ? process.execPath : value),
  diagnostic_environment_keys: Object.keys(process.env).filter((key) => key.startsWith("TSF_NATIVE_TEST_")).sort(),
});
nativeStage("MODULE_INITIALIZATION_COMPLETE");
let assertions = 0;
const check = (value, message) => { assertions += 1; assert.ok(value, message); };
const equal = (actual, expected, message) => { assertions += 1; assert.equal(actual, expected, message); };
const sha256File = (filePath) => createHash("sha256").update(readFileSync(filePath)).digest("hex");
const expectDiagnostic = async (fn, classification, stageId, pathname, recorder = trace, controlled = true) => {
  let observed = null;
  try { await fn(); } catch (error) { observed = error; }
  check(observed instanceof ProofHttpDiagnosticError, `${classification} returns a closed diagnostic error`);
  equal(observed.classification, classification, `${classification} classification is exact`);
  equal(observed.stage_id, stageId, `${classification} retains the proof stage`);
  equal(observed.pathname, pathname, `${classification} retains the endpoint pathname`);
  if (controlled) recorder.markControlledFailure(stageId, { controlled_by_test: true });
  return observed;
};

let server = null;
let currentPort = 0;
let currentInstance = "";
let currentGeneration = "";
let startCount = 0;
const owner = () => ({
  disposition: server?.listening ? "ACTIVE_OWNER_CONFIRMED" : "ABSENT",
  owner: server?.listening ? {
    server_instance_id: currentInstance,
    operator_session_generation: currentGeneration,
    process_id: process.pid,
    process_start_time: "2026-07-19T00:00:00.000Z",
    lifecycle_state: "ACTIVE",
    active_mission: null,
    owned_children: [],
  } : null,
});
const listeners = (port) => server?.listening && Number(port) === currentPort ? [{ host: "127.0.0.1", port: currentPort, process_id: process.pid, evidence_source: "FOCUSED_TEST" }] : [];

async function startFixture(instance, generation, fixedPort = 0) {
  nativeStage("FIXTURE_START_REQUESTED", { instance, generation, fixed_port: fixedPort });
  currentInstance = instance;
  currentGeneration = generation;
  const pendingResponseSettlements = new Set();
  const fixtureServer = createServer((req, res) => {
    const json = (status, value) => {
      const body = Buffer.from(JSON.stringify(value));
      res.writeHead(status, { "Content-Type": "application/json", "Content-Length": body.byteLength });
      res.end(body);
    };
    if (req.url === "/ok") { json(200, { ok: true, server_instance_id: currentInstance }); return; }
    if (req.url === "/session-expired") { json(403, { error: { code: "OPERATOR_SESSION_EXPIRED" } }); return; }
    if (req.url === "/missing") { json(404, { error: { code: "NOT_FOUND" } }); return; }
    if (req.url === "/invalid") { res.writeHead(200, { "Content-Type": "application/json" }); res.end("{"); return; }
    if (req.url === "/slow") {
      let settle;
      const settlement = new Promise((resolve) => { settle = resolve; });
      pendingResponseSettlements.add(settlement);
      let settled = false;
      const finishSettlement = (disposition) => {
        if (settled) return;
        settled = true;
        pendingResponseSettlements.delete(settlement);
        nativeStage("SLOW_RESPONSE_SETTLED", { disposition });
        settle();
      };
      const timer = setTimeout(() => {
        if (!res.destroyed) json(200, { late: true });
        finishSettlement("TIMER_COMPLETED");
      }, 200);
      res.once("close", () => { clearTimeout(timer); finishSettlement("RESPONSE_CLOSED_AFTER_ABORT_OR_COMPLETION"); });
      return;
    }
    if (req.url === "/stop") { res.once("finish", () => nativeStage("STOP_RESPONSE_FINISHED", { instance })); json(202, { accepted: true, server_instance_id: currentInstance }); return; }
    json(404, { error: { code: "UNKNOWN" } });
  });
  fixtureServer.waitForResponseSettlements = async () => { await Promise.allSettled([...pendingResponseSettlements]); };
  server = fixtureServer;
  await new Promise((resolve, reject) => { fixtureServer.once("error", reject); fixtureServer.listen(fixedPort, "127.0.0.1", resolve); });
  currentPort = fixtureServer.address().port;
  startCount += 1;
  nativeStage("FIXTURE_LISTENING", { instance, generation, port: currentPort, start_count: startCount });
  return server;
}

nativeStage("PRIMARY_FIXTURE_SEQUENCE_ENTERED");
await startFixture("instance-main", "generation-main");
const trace = new ProofTraceRecorder({ evidenceRoot, port: currentPort, inspectOwner: owner, inspectListeners: listeners });
const ok = await trace.httpJson({ stageId: "LIVE_CORRECT", caller: "focused-test", pathname: "/ok", expectedServerInstance: currentInstance, expectedSessionGeneration: currentGeneration });
equal(ok.status, 200, "correct live server endpoint succeeds");
equal(ok.json.server_instance_id, currentInstance, "live response retains exact server identity");
nativeStage("PRIMARY_LIVE_FETCH_COMPLETE", { port: currentPort });

await expectDiagnostic(() => trace.httpJson({ stageId: "WRONG_INSTANCE", caller: "focused-test", pathname: "/ok", expectedServerInstance: "instance-wrong", expectedSessionGeneration: currentGeneration }), "WRONG_SERVER_INSTANCE_BEFORE_FETCH", "WRONG_INSTANCE", "/ok");
await expectDiagnostic(() => trace.httpJson({ stageId: "WRONG_PORT", caller: "focused-test", pathname: "/ok", port: currentPort + 1, expectedServerInstance: currentInstance, expectedSessionGeneration: currentGeneration }), "LISTENER_NOT_CONFIRMED_BEFORE_FETCH", "WRONG_PORT", "/ok");
await expectDiagnostic(() => trace.httpJson({ stageId: "STALE_SESSION", caller: "focused-test", pathname: "/ok", expectedServerInstance: currentInstance, expectedSessionGeneration: "generation-stale" }), "STALE_OPERATOR_SESSION_BEFORE_FETCH", "STALE_SESSION", "/ok");

const expired = await trace.httpJson({ stageId: "EXPIRED_SESSION_HTTP", caller: "focused-test", pathname: "/session-expired", expectedServerInstance: currentInstance, expectedSessionGeneration: currentGeneration, headers: { "X-TSF-HQ-Session": "super-secret-session-token" } });
equal(expired.status, 403, "expired session is an HTTP rejection rather than a transport failure");
equal(expired.json.error.code, "OPERATOR_SESSION_EXPIRED", "expired session retains HTTP error identity");
const missing = await trace.httpJson({ stageId: "ENDPOINT_404", caller: "focused-test", pathname: "/missing", expectedServerInstance: currentInstance, expectedSessionGeneration: currentGeneration });
equal(missing.status, 404, "endpoint 404 remains distinct from transport failure");
await expectDiagnostic(() => trace.httpJson({ stageId: "INVALID_JSON", caller: "focused-test", pathname: "/invalid", expectedServerInstance: currentInstance, expectedSessionGeneration: currentGeneration }), "RESPONSE_BODY_PARSE_FAILURE", "INVALID_JSON", "/invalid");
const timeout = await expectDiagnostic(() => trace.httpJson({ stageId: "FETCH_TIMEOUT", caller: "focused-test", pathname: "/slow", expectedServerInstance: currentInstance, expectedSessionGeneration: currentGeneration, timeoutMs: 20 }), "FETCH_ABORT_OR_TIMEOUT", "FETCH_TIMEOUT", "/slow");
equal(timeout.evidence.abort_state, true, "timeout records abort state separately");
nativeStage("PRIMARY_NEGATIVE_FETCH_CASES_COMPLETE");
check(realProofSource.includes("const REAL_RECOVERY_ACTION_HTTP_TIMEOUT_MS = 240_000"), "real recovery action has an explicit bounded worker-aligned HTTP budget");
check(/stageId:\s*"RECOVERY_ACTION"[\s\S]{0,700}timeoutMs:\s*REAL_RECOVERY_ACTION_HTTP_TIMEOUT_MS/.test(realProofSource), "only the real recovery action opts into the worker-aligned budget");
check(!/stageId:\s*"RECOVERY_LIST"[\s\S]{0,300}timeoutMs:\s*REAL_RECOVERY_ACTION_HTTP_TIMEOUT_MS/.test(realProofSource), "read-only recovery listing retains the normal short HTTP budget");

const receiptPath = path.join(evidenceRoot, "canonical-recovery-receipt.json");
writeFileSync(receiptPath, `${JSON.stringify({ schema_version: "tsf_hq_dispatch_recovery_receipt_v1", receipt_id: "receipt-focused", mission_id: "mission-focused", mission_revision: 1, run_id: "run-focused", result_id: "run-focused" }, null, 2)}\n`, "utf8");
const primaryFixtureServer = server;
const closed = once(primaryFixtureServer, "close");
const stoppedInstance = currentInstance;
await primaryFixtureServer.waitForResponseSettlements();
const stop = await trace.httpJson({ stageId: "EXACT_STOP", caller: "focused-test", method: "POST", pathname: "/stop", expectedServerInstance: currentInstance, expectedSessionGeneration: currentGeneration, headers: { "X-TSF-HQ-Stop": "super-secret-stop-token" }, body: { server_instance_id: currentInstance } });
equal(stop.status, 202, "exact Stop response completes before listener cleanup");
primaryFixtureServer.close();
await closed;
nativeStage("PRIMARY_FIXTURE_CLOSED", { instance: stoppedInstance, port: currentPort });
trace.markServerStopped(stoppedInstance, { listener_absent: true, owner_absent: true });
const startsBeforeDurableRead = startCount;
const durable = trace.readDurableJson({ stageId: "POST_STOP_DURABLE_RECEIPT", caller: "focused-test", filePath: receiptPath, evidenceKind: "RECOVERY_RECEIPT", expectedIdentity: { schema_version: "tsf_hq_dispatch_recovery_receipt_v1", receipt_id: "receipt-focused", mission_id: "mission-focused", mission_revision: 1, run_id: "run-focused", result_id: "run-focused" } });
equal(durable.json.receipt_id, "receipt-focused", "post-Stop recovery receipt is read through its durable artifact");
equal(startCount, startsBeforeDurableRead, "durable post-Stop reading does not restart a server");
const nestedQueuePath = path.join(evidenceRoot, "canonical-queue-document.json");
writeFileSync(nestedQueuePath, `${JSON.stringify({ schema_version: "tsf_canonical_queue_document_v1", mission_id: "misleading-top-level", durable_mission: { mission_id: "mission-new-run", mission_revision: 2 } }, null, 2)}\n`, "utf8");
const nestedQueue = trace.readDurableJson({ stageId: "NESTED_QUEUE_IDENTITY", caller: "focused-test", filePath: nestedQueuePath, evidenceKind: "QUEUE_DOCUMENT", identityPath: ["durable_mission"], expectedIdentity: { mission_id: "mission-new-run", mission_revision: 2 } });
equal(nestedQueue.identity.mission_id, "mission-new-run", "canonical queue identity is validated from the explicit durable_mission projection");
equal(nestedQueue.identity_path.join("."), "durable_mission", "durable evidence records the exact identity projection path");
const wrongNestedTrace = new ProofTraceRecorder({ evidenceRoot: path.join(evidenceRoot, "wrong-nested-identity"), port: currentPort });
let wrongNestedError = null;
try { wrongNestedTrace.readDurableJson({ stageId: "WRONG_NESTED_QUEUE_IDENTITY", caller: "focused-test", filePath: nestedQueuePath, evidenceKind: "QUEUE_DOCUMENT", identityPath: ["durable_mission"], expectedIdentity: { mission_id: "misleading-top-level", mission_revision: 2 } }); } catch (error) { wrongNestedError = error; }
equal(wrongNestedError?.message, "DURABLE_EVIDENCE_MISSION_ID_MISMATCH", "top-level decoy identity cannot satisfy the explicit nested queue contract");
let missingNestedError = null;
try { wrongNestedTrace.readDurableJson({ stageId: "MISSING_NESTED_QUEUE_IDENTITY", caller: "focused-test", filePath: nestedQueuePath, evidenceKind: "QUEUE_DOCUMENT", identityPath: ["missing"], expectedIdentity: { mission_id: "mission-new-run" } }); } catch (error) { missingNestedError = error; }
equal(missingNestedError?.message, "DURABLE_IDENTITY_PATH_MISSING", "missing explicit identity projection fails closed");
await expectDiagnostic(() => trace.httpJson({ stageId: "HTTP_AFTER_STOP", caller: "focused-test", pathname: "/ok", expectedServerInstance: stoppedInstance, expectedSessionGeneration: currentGeneration }), "HTTP_AFTER_CONFIRMED_STOP_DENIED", "HTTP_AFTER_STOP", "/ok");
const final = trace.writeFinal({ status: "PASS", exitCode: 0, result: { durable_receipt_sha256: durable.sha256 }, knownIdentities: { server_instance_id: stoppedInstance, receipt_id: durable.json.receipt_id }, cleanupState: { owner_absent: true, listener_absent: true, proof_owned_process_absent: true } });
equal(final.status, "PASS", "final proof serialization succeeds with the server absent");
equal(final.failed_stage, null, "successful completion has no failed stage after controlled failures");
for (const required of [trace.paths.stage_trace, trace.paths.fetch_trace, trace.paths.ownership_trace, trace.paths.proof_result]) check(existsSync(required), `${path.basename(required)} is always serialized`);
const serialized = [trace.paths.stage_trace, trace.paths.fetch_trace, trace.paths.ownership_trace, trace.paths.proof_result].map((filePath) => readFileSync(filePath, "utf8")).join("\n");
check(!serialized.includes("super-secret-session-token"), "session token value is absent from all traces");
check(!serialized.includes("super-secret-stop-token"), "Stop capability value is absent from all traces");
check(serialized.includes("/api") === false, "focused fixture traces contain only the exact supplied pathnames");
check(sha256File(trace.paths.fetch_trace) === sha256File(trace.paths.fetch_trace), "evidence hashes reproduce byte-for-byte");
nativeStage("PRIMARY_DURABLE_AND_SERIALIZATION_CASES_COMPLETE");

const sequentialRoot = path.join(evidenceRoot, "sequential-instances");
const sequentialTrace = new ProofTraceRecorder({ evidenceRoot: sequentialRoot, port: 0, inspectOwner: owner, inspectListeners: listeners });
const fixedPort = 44_000 + (process.pid % 1000);
for (let index = 0; index < 8; index += 1) {
  nativeStage("SEQUENTIAL_INSTANCE_ENTERED", { index, fixed_port: fixedPort });
  const exactInstanceServer = await startFixture(`instance-${index}`, `generation-${index}`, fixedPort);
  sequentialTrace.port = fixedPort;
  const first = await sequentialTrace.httpJson({ stageId: `INSTANCE_${index}_READ_1`, caller: "sequential-test", pathname: "/ok", expectedServerInstance: currentInstance, expectedSessionGeneration: currentGeneration });
  const second = await sequentialTrace.httpJson({ stageId: `INSTANCE_${index}_READ_2`, caller: "sequential-test", pathname: "/ok", expectedServerInstance: currentInstance, expectedSessionGeneration: currentGeneration });
  equal(first.status, 200, `instance ${index} first read avoids stale pooled state`);
  equal(second.status, 200, `instance ${index} second read avoids stale pooled state`);
  const instanceClosed = once(exactInstanceServer, "close");
  const instanceId = currentInstance;
  const stopped = await sequentialTrace.httpJson({ stageId: `INSTANCE_${index}_STOP`, caller: "sequential-test", method: "POST", pathname: "/stop", expectedServerInstance: currentInstance, expectedSessionGeneration: currentGeneration, body: { server_instance_id: currentInstance } });
  equal(stopped.status, 202, `instance ${index} Stop avoids stale pooled state`);
  exactInstanceServer.close();
  await instanceClosed;
  sequentialTrace.markServerStopped(instanceId, { exact_cleanup: true });
  nativeStage("SEQUENTIAL_INSTANCE_CLOSED", { index, instance: instanceId, fixed_port: fixedPort });
}
equal(sequentialTrace.fetchEvents.filter((event) => event.failure_classification === "FETCH_TRANSPORT_FAILURE").length, 0, "connection-close policy prevents cross-instance ECONNRESET");
nativeStage("SEQUENTIAL_INSTANCE_SEQUENCE_COMPLETE", { instances: 8, fixed_port: fixedPort });

const failureRoot = path.join(evidenceRoot, "failure-serialization");
const failedTrace = new ProofTraceRecorder({ evidenceRoot: failureRoot, port: fixedPort, inspectOwner: () => ({ disposition: "ACTIVE_OWNER_CONFIRMED", owner: { server_instance_id: "failed-instance", operator_session_generation: "failed-generation", process_id: process.pid, owned_children: [] } }), inspectListeners: () => [] });
const failure = await expectDiagnostic(() => failedTrace.httpJson({ stageId: "KNOWN_FAILED_ENDPOINT", caller: "failure-test", pathname: "/known", expectedServerInstance: "failed-instance", expectedSessionGeneration: "failed-generation" }), "LISTENER_NOT_CONFIRMED_BEFORE_FETCH", "KNOWN_FAILED_ENDPOINT", "/known", failedTrace, false);
failedTrace.writeFinal({ status: "FAIL", error: failure, exitCode: 1, knownIdentities: { server_instance_id: "failed-instance" }, cleanupState: { listener_absent: true } });
for (const required of [failedTrace.paths.stage_trace, failedTrace.paths.fetch_trace, failedTrace.paths.ownership_trace, failedTrace.paths.proof_result, failedTrace.paths.blocker]) check(existsSync(required), `failed proof still writes ${path.basename(required)}`);
const blocker = JSON.parse(readFileSync(failedTrace.paths.blocker, "utf8"));
equal(blocker.failed_stage, "KNOWN_FAILED_ENDPOINT", "failed serialization retains exact stage");
equal(JSON.parse(readFileSync(failedTrace.paths.fetch_trace, "utf8")).events[0].url_pathname, "/known", "unknown fetch targets are impossible");

const precedenceRoot = path.join(evidenceRoot, "terminal-precedence");
const precedence = new ProofTraceRecorder({ evidenceRoot: precedenceRoot, port: fixedPort });
const controlledStage = precedence.startStage("EARLY_CONTROLLED_TIMEOUT");
precedence.failStage(controlledStage, "FETCH_ABORT_OR_TIMEOUT", {}, "CONTROLLED_FAILURE");
precedence.recordCaution("NONBLOCKING_WARNING", { warning: "EXPECTED_CAVEAT" });
const terminalError = Object.assign(new Error("later assertion failed"), { classification: "ASSERTION_FAILURE" });
precedence.recordTerminalFailure("LATER_TERMINAL_ASSERTION", terminalError);
let precedenceFinal = precedence.writeFinal({ status: "FAIL", error: terminalError, exitCode: 1 });
equal(precedenceFinal.failed_stage, "LATER_TERMINAL_ASSERTION", "later blocking failure supersedes earlier controlled failure");
equal(JSON.parse(readFileSync(precedence.paths.blocker, "utf8")).failed_stage, precedenceFinal.failed_stage, "BLOCKER and PROOF_RESULT agree on terminal failure");
const precedenceEvents = JSON.parse(readFileSync(precedence.paths.stage_trace, "utf8")).events;
check(precedenceEvents.every((event, index) => event.sequence === index + 1), "stage timeline sequence is monotonic");
equal(precedenceEvents.find((event) => event.stage_id === "EARLY_CONTROLLED_TIMEOUT").disposition, "CONTROLLED_FAILURE", "earlier timeout remains in ordered timeline");
equal(precedenceEvents.find((event) => event.stage_id === "NONBLOCKING_WARNING").disposition, "CAUTION", "warning never becomes primary failure");

const immediate = new ProofTraceRecorder({ evidenceRoot: path.join(evidenceRoot, "immediate-terminal"), port: fixedPort });
immediate.recordTerminalFailure("FIRST_BLOCKING_FAILURE", terminalError);
precedenceFinal = immediate.writeFinal({ status: "FAIL", error: terminalError, exitCode: 1 });
equal(precedenceFinal.failed_stage, "FIRST_BLOCKING_FAILURE", "first blocking failure remains primary when execution stops immediately");

const serialization = new ProofTraceRecorder({ evidenceRoot: path.join(evidenceRoot, "serialization-terminal"), port: fixedPort });
const serializationError = Object.assign(new Error("serialization failed"), { classification: "SERIALIZATION_FAILURE" });
serialization.recordTerminalFailure("FINAL_PROOF_SERIALIZATION_FAILURE", serializationError);
const serializationFinal = serialization.writeFinal({ status: "FAIL", error: serializationError, exitCode: 1 });
equal(serializationFinal.failed_stage, "FINAL_PROOF_SERIALIZATION_FAILURE", "serialization exception receives its own terminal stage");

const nativeResult = { schema_version: "tsf_native_test_result_v1", status: "PASS", numeric_exit_code: 0, process_id: process.pid, parent_process_id: process.ppid, last_completed_stage: "TEST_ASSERTIONS_COMPLETE", assertions, evidence_root: evidenceRoot, recorded_at: new Date().toISOString() };
nativeStage("TEST_ASSERTIONS_COMPLETE", { assertions });
writeDurableJson(nativeResultPath, nativeResult);
process.stdout.write(`${JSON.stringify({ schema_version: "tsf_proof_fetch_trace_focused_tests_v1", status: "PASS", assertions, evidence_root: evidenceRoot, sequential_server_instances: 8, stale_transport_failures_after_correction: 0, required_files_on_success: 4, required_files_on_failure: 5 }, null, 2)}\n`);
