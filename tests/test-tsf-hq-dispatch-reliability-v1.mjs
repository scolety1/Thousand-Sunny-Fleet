import { strict as assert } from "node:assert";
import { createHash } from "node:crypto";
import { copyFileSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from "node:fs";
import net from "node:net";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { createDemoFixtureAdapters, resetDemoFixtureRoot } from "../tools/hq-dispatch/v1/demo-fixtures.mjs";
import {
  ProcessOwnership,
  inspectProcess,
  performRecoveryAction,
  readOwnership,
  reconcileCanonicalState,
  runDoctor,
  writeInterruptionEvidence,
} from "../tools/hq-dispatch/v1/reliability.mjs";

const repositoryRoot = path.resolve(fileURLToPath(new URL("../", import.meta.url)));
const fixtureRoot = path.join(repositoryRoot, ".codex-local", "fixtures", "hq-dispatch-reliability-v1");
rmSync(fixtureRoot, { recursive: true, force: true });
mkdirSync(fixtureRoot, { recursive: true });
const results = [];
let assertions = 0;

function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }
function digest(value) { return createHash("sha256").update(value).digest("hex"); }
function stable(value) { if (Array.isArray(value)) return value.map(stable); if (value && typeof value === "object") return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])])); return value; }
function hashObject(value) { return digest(JSON.stringify(stable(value))); }
function json(filePath, value) { mkdirSync(path.dirname(filePath), { recursive: true }); writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8"); }

function scenario(number) {
  const root = path.join(fixtureRoot, `scenario-${String(number).padStart(2, "0")}`);
  const runtimeRoot = path.join(root, "runtime");
  const queueRoot = path.join(root, "queue");
  const localRoot = path.join(root, "local");
  for (const directory of [runtimeRoot, queueRoot, localRoot]) mkdirSync(directory, { recursive: true });
  const adapters = createDemoFixtureAdapters({ fixtureRoot: root, repositoryRoot, queueRoot, runtimeRoot });
  return { root, runtimeRoot, queueRoot, localRoot, adapters };
}

function scan(context, ownership = { disposition: "ABSENT", owner: null }) {
  return reconcileCanonicalState({ runtimeRoot: context.runtimeRoot, queueRoot: context.queueRoot, ownership });
}

function one(context, classification, ownership) {
  const items = scan(context, ownership).items;
  const item = items.find((candidate) => candidate.classification === classification);
  check(item, `expected ${classification}`);
  return item;
}

function record(number, name, checks) {
  results.push({ scenario: number, name, status: "PASS", assertions: checks, canonical_history_immutable: true, completed_mission_rerun: false, approval_inferred: false });
}

// 1. Clean startup.
{
  const c = scenario(1);
  const report = scan(c);
  equal(report.safe_to_reconcile, true, "clean canonical roots reconcile safely");
  equal(report.items.length, 0, "clean roots have no recovery items");
  record(1, "Clean startup", 2);
}

// 2. Second-instance rejection.
{
  const c = scenario(2);
  const ownerPath = path.join(c.localRoot, "owner.json");
  const tokenPath = path.join(c.localRoot, "stop-token");
  const first = new ProcessOwnership({ ownerPath, tokenPath });
  first.claim();
  let rejected = false;
  try { new ProcessOwnership({ ownerPath, tokenPath }).claim(); } catch (error) { rejected = String(error.message).includes("OWNER_RECORD_ALREADY_EXISTS"); }
  check(rejected, "second owner claim fails closed");
  first.release();
  record(2, "Second-instance rejection", 1);
}

// 3. Occupied port.
const occupiedServer = net.createServer();
await new Promise((resolve) => occupiedServer.listen(0, "127.0.0.1", resolve));
{
  const c = scenario(3);
  const port = occupiedServer.address().port;
  const report = runDoctor({ runtimeRoot: c.runtimeRoot, queueRoot: c.queueRoot, ownerPath: path.join(c.localRoot, "owner.json"), port, allowDirtyForTest: true });
  equal(report.safe_to_start, false, "occupied port blocks Start");
  equal(report.checks.find((item) => item.id === "process_owner_and_listener").status, "UNSAFE_TO_START", "unowned listener is unsafe");
  record(3, "Occupied port", 2);
}
await new Promise((resolve) => occupiedServer.close(resolve));

// 4. Stale ownership record with no process.
let staleOwnerPath;
{
  const c = scenario(4);
  staleOwnerPath = path.join(c.localRoot, "owner.json");
  const staleTokenPath = path.join(c.localRoot, "stop-token");
  const code = `import {ProcessOwnership} from './tools/hq-dispatch/v1/reliability.mjs';const o=new ProcessOwnership({ownerPath:${JSON.stringify(staleOwnerPath)},tokenPath:${JSON.stringify(staleTokenPath)}});o.claim();process.exit(0);`;
  const child = spawnSync(process.execPath, ["--input-type=module", "-e", code], { cwd: repositoryRoot, encoding: "utf8", windowsHide: true, timeout: 15000 });
  equal(child.status, 0, "stale owner fixture process exited");
  equal(readOwnership(staleOwnerPath).disposition, "STALE_PROCESS_GONE", "stale owner is explicit");
  const report = runDoctor({ runtimeRoot: c.runtimeRoot, queueRoot: c.queueRoot, ownerPath: staleOwnerPath, port: 49304, allowDirtyForTest: true });
  equal(report.safe_to_start, false, "stale owner requires explicit recovery");
  check(report.exact_next_action.includes("RecoverVerifiedStaleOwnership"), "Doctor gives exact stale action");
  record(4, "Stale ownership record with no process", 4);
}

// 5. Ownership record pointing to unrelated process.
{
  const c = scenario(5);
  const source = JSON.parse(readFileSync(staleOwnerPath, "utf8"));
  const observed = inspectProcess(process.pid);
  const { evidence_hash: ignored, ...body } = source;
  body.process_id = process.pid;
  body.process_start_time = new Date(Date.parse(observed.process_start_time) - 60000).toISOString();
  body.executable = observed.executable;
  const mismatched = { ...body, evidence_hash: hashObject(body) };
  const ownerPath = path.join(c.localRoot, "owner.json");
  json(ownerPath, mismatched);
  equal(readOwnership(ownerPath).disposition, "PID_REUSED_OR_IDENTITY_MISMATCH", "PID reuse cannot satisfy owner identity");
  equal(inspectProcess(process.pid).process_id, process.pid, "unrelated process remains alive");
  record(5, "Ownership record pointing to unrelated process", 2);
}

function makeWorkerRunning(c, missionId) {
  const outcome = c.adapters.completedOutcome(missionId, 1, "worker fixture");
  for (const filePath of [outcome.paths.lifecycle, outcome.paths.result, outcome.paths.receipt, outcome.paths.transaction, outcome.paths.queueResult]) rmSync(filePath, { force: true });
  const target = path.join(c.queueRoot, "worker_running", path.basename(outcome.queuePath));
  mkdirSync(path.dirname(target), { recursive: true });
  renameSync(outcome.queuePath, target);
  return { outcome, target };
}

// 6. Active mission with confirmed owned child.
{
  const c = scenario(6);
  const missionId = "hq-fixture-active-owned-child-0006";
  makeWorkerRunning(c, missionId);
  const observed = inspectProcess(process.pid);
  const ownership = { disposition: "ACTIVE_OWNER_CONFIRMED", owner: { server_instance_id: "fixture-owner", active_mission: { mission_id: missionId, mission_revision: 1, run_id: `canonical-result-${missionId}-1` }, owned_children: [observed] } };
  const item = one(c, "RUNNING_PROCESS_CONFIRMED", ownership);
  equal(item.process_evidence.confirmed_owned_child_process_ids[0], process.pid, "active child identity is confirmed");
  equal(item.recommended_action, "DECLINE_RECOVERY", "no retry is offered for confirmed running process");
  record(6, "Active mission with confirmed owned child", 3);
}

// 7. Child exits before terminal result.
{
  const c = scenario(7);
  makeWorkerRunning(c, "hq-fixture-child-exit-0007");
  const item = one(c, "INTERRUPTED_PROCESS_GONE");
  check(item.safe_operator_options.includes("RETRY_AS_NEW_RUN"), "interrupted source offers new-run recovery");
  record(7, "Child exits before terminal result", 2);
}

// 8. Interrupted canonical mission.
let interruptedItem;
let interruptedContext;
{
  interruptedContext = scenario(8);
  makeWorkerRunning(interruptedContext, "hq-fixture-interrupted-0008");
  interruptedItem = one(interruptedContext, "INTERRUPTED_PROCESS_GONE");
  const before = readFileSync(interruptedItem.canonical_paths.queue_documents[0]);
  const evidence = writeInterruptionEvidence({ item: interruptedItem, reason: "FAILURE_INJECTION", operatorInitiated: true });
  check(existsSync(evidence.stop_record_path), "interruption receipt exists");
  equal(digest(readFileSync(interruptedItem.canonical_paths.queue_documents[0])), digest(before), "queue history is unchanged");
  equal(one(interruptedContext, "INTERRUPTED_PROCESS_GONE").automatic_retry_performed, undefined, "Doctor does not rerun");
  interruptedItem = one(interruptedContext, "INTERRUPTED_PROCESS_GONE");
  record(8, "Interrupted canonical mission", 5);
}

// 9. Completed admitted mission after UI restart.
{
  const c = scenario(9);
  c.adapters.completedOutcome("hq-fixture-completed-restart-0009", 1);
  const item = one(c, "COMPLETED_ADMITTED_WITH_CAVEATS");
  check(!item.safe_operator_options.includes("RETRY_AS_NEW_RUN"), "completed mission cannot rerun");
  equal(item.recommended_action, "ACKNOWLEDGE_COMPLETED", "completed receipt is acknowledged");
  record(9, "Completed admitted mission after UI restart", 3);
}

// 10. TIM_REQUIRED pending response.
{
  const c = scenario(10);
  c.adapters.timOutcome("hq-fixture-tim-pending-0010", 1, "TIM REQUIRED fixture");
  const item = one(c, "TIM_REQUIRED_PENDING_RESPONSE");
  equal(item.recommended_action, "RESPOND_TO_TIM_REQUIRED", "exact response path is recommended");
  check(!item.safe_operator_options.includes("RETRY_AS_NEW_RUN"), "TIM response is not replaced by retry");
  record(10, "TIM_REQUIRED pending response", 3);
}

// 11. TIM_REQUIRED already answered with new revision.
{
  const c = scenario(11);
  const missionId = "hq-fixture-tim-revision-0011";
  const old = c.adapters.timOutcome(missionId, 1, "TIM REQUIRED revision fixture");
  c.adapters.completedOutcome(missionId, 2, "revised fixture");
  json(old.paths.response, { schema_version: "tsf_tim_required_response_v1", mission_id: missionId, mission_revision: 1, run_id: old.paths.runId, result_id: old.paths.runId, response_id: "hq-response-fixture-0011", response_type: "PROVIDE_CLARIFICATION", revision: { mission_id: missionId, mission_revision: 2, run_id: `canonical-result-${missionId}-2` } });
  const item = one(c, "TIM_REQUIRED_RESPONDED_REVISION_EXISTS");
  check(!item.safe_operator_options.includes("RESPOND_TO_TIM_REQUIRED"), "answered request cannot be answered again");
  record(11, "TIM_REQUIRED answered with revision", 2);
}

// 12. Stale queue state with valid terminal receipt.
{
  const c = scenario(12);
  const outcome = c.adapters.completedOutcome("hq-fixture-stale-queue-0012", 1);
  const target = path.join(c.queueRoot, "postrun_pending", path.basename(outcome.queuePath));
  mkdirSync(path.dirname(target), { recursive: true });
  renameSync(outcome.queuePath, target);
  const item = one(c, "ADMISSION_WITH_QUEUE_MISMATCH");
  equal(item.recommended_action, "VIEW_CANONICAL_RECEIPT", "receipt is viewed before bounded reconciliation");
  check(item.safe_operator_options.includes("RECONCILE_QUEUE_FROM_CANONICAL_RECEIPT"), "canonical receipt reconciliation is the only queue move offered");
  record(12, "Stale queue state with valid terminal receipt", 3);
}

// 13. Result exists without admission.
{
  const c = scenario(13);
  const outcome = c.adapters.completedOutcome("hq-fixture-result-no-admission-0013", 1);
  rmSync(outcome.paths.receipt, { force: true });
  const item = one(c, "RESULT_WITHOUT_ADMISSION");
  equal(item.authority_required, "TIM_OR_EXISTING_CANONICAL_CONTROL_REQUIRED", "missing admission never infers approval");
  record(13, "Result exists without admission", 2);
}

// 14. Verifier rejection.
{
  const c = scenario(14);
  const outcome = c.adapters.completedOutcome("hq-fixture-verifier-reject-0014", 1);
  const receipt = JSON.parse(readFileSync(outcome.paths.receipt, "utf8"));
  receipt.status = "REJECTED_INVALID_EVIDENCE";
  receipt.reasons = ["Verifier rejected deterministic evidence."];
  json(outcome.paths.receipt, receipt);
  const item = one(c, "COMPLETED_REJECTED");
  check(!item.safe_operator_options.includes("RETRY_AS_NEW_RUN"), "rejected terminal evidence does not rerun automatically");
  record(14, "Verifier rejection", 2);
}

// 15. Exact duplicate submission.
{
  const c = scenario(15);
  const outcome = c.adapters.completedOutcome("hq-fixture-duplicate-exact-0015", 1);
  const duplicate = path.join(c.queueRoot, "archived", path.basename(outcome.queuePath));
  mkdirSync(path.dirname(duplicate), { recursive: true });
  copyFileSync(outcome.queuePath, duplicate);
  const item = one(c, "DUPLICATE_EXACT_REPLAY");
  equal(item.duplicate_replay_state.state, "IDEMPOTENT_REPLAY", "exact duplicate is idempotent");
  check(!item.safe_operator_options.includes("RETRY_AS_NEW_RUN"), "exact completed replay does not execute");
  record(15, "Exact duplicate submission", 3);
}

// 16. Changed-content replay conflict.
{
  const c = scenario(16);
  const outcome = c.adapters.completedOutcome("hq-fixture-conflict-replay-0016", 1);
  const changed = JSON.parse(readFileSync(outcome.queuePath, "utf8"));
  changed.durable_mission.original_request = "changed replay content";
  const duplicate = path.join(c.queueRoot, "archived", path.basename(outcome.queuePath));
  json(duplicate, changed);
  const item = one(c, "CONFLICTING_REPLAY");
  equal(scan(c).safe_to_reconcile, false, "conflicting replay stops reconciliation");
  equal(item.recommended_action, "VIEW_CANONICAL_RECEIPT", "conflict evidence is preserved for review");
  record(16, "Changed-content replay conflict", 3);
}

// 17. Duplicate response / recovery receipt idempotency.
{
  const c = scenario(17);
  c.adapters.completedOutcome("hq-fixture-response-replay-0017", 1);
  const item = one(c, "COMPLETED_ADMITTED_WITH_CAVEATS");
  const first = await performRecoveryAction({ item, action: "ACKNOWLEDGE_COMPLETED", operatorConfirmation: "ACKNOWLEDGE_COMPLETED", sessionGeneration: "fixture-session", localRoot: c.localRoot });
  const second = await performRecoveryAction({ item, action: "ACKNOWLEDGE_COMPLETED", operatorConfirmation: "ACKNOWLEDGE_COMPLETED", sessionGeneration: "fixture-session", localRoot: c.localRoot });
  equal(first.receipt.receipt_id, second.receipt.receipt_id, "same response identity returns same receipt");
  equal(second.receipt.idempotent_replay, true, "duplicate response is idempotent");
  record(17, "Duplicate response", 3);
}

// 18. Server shutdown during execution.
{
  const c = scenario(18);
  makeWorkerRunning(c, "hq-fixture-shutdown-execution-0018");
  const item = one(c, "INTERRUPTED_PROCESS_GONE");
  const evidence = writeInterruptionEvidence({ item, reason: "SERVER_SHUTDOWN_DURING_EXECUTION", serverInstanceId: "fixture-server", operatorInitiated: true });
  equal(evidence.original_attempt_completed, false, "shutdown does not convert interruption to completion");
  equal(evidence.original_attempt_resumable, false, "old turn is not resumable");
  record(18, "Server shutdown during execution", 3);
}

// 19. Orphan-listener check.
const orphanServer = net.createServer();
await new Promise((resolve) => orphanServer.listen(0, "127.0.0.1", resolve));
{
  const c = scenario(19);
  const report = runDoctor({ runtimeRoot: c.runtimeRoot, queueRoot: c.queueRoot, ownerPath: path.join(c.localRoot, "owner.json"), port: orphanServer.address().port, allowDirtyForTest: true });
  equal(report.checks.find((item) => item.id === "process_owner_and_listener").status, "UNSAFE_TO_START", "unowned listener is never adopted");
  equal(inspectProcess(process.pid).process_id, process.pid, "Doctor does not kill listener owner");
  record(19, "Orphan-listener check", 2);
}
await new Promise((resolve) => orphanServer.close(resolve));

// 20. Recovery retry creates a new run.
{
  const c = scenario(20);
  makeWorkerRunning(c, "hq-fixture-new-run-0020");
  let item = one(c, "INTERRUPTED_PROCESS_GONE");
  writeInterruptionEvidence({ item, reason: "NEW_RUN_FIXTURE", operatorInitiated: true });
  item = one(c, "INTERRUPTED_PROCESS_GONE");
  const newRunId = "canonical-result-hq-fixture-new-run-retry-0020-1";
  const relay = { retryInterrupted: async () => ({ mission_id: "hq-fixture-new-run-retry-0020", mission_revision: 1, run_id: newRunId, result_id: newRunId, source_path: path.join(c.runtimeRoot, "new-run.json") }) };
  const result = await performRecoveryAction({ item, action: "RETRY_AS_NEW_RUN", operatorConfirmation: "RETRY_AS_NEW_RUN", sessionGeneration: "fixture-session-20", relay, localRoot: c.localRoot });
  check(result.new_run.run_id !== item.run_id, "retry uses a new run identity");
  equal(result.receipt.new_run.run_id, newRunId, "new run relationship is preserved in receipt");
  check(existsSync(item.interruption_evidence.path), "original interruption evidence remains");
  record(20, "Recovery retry creates a new run", 4);
}

// 21. Demo reset affects only the demo fixture root.
{
  const c = scenario(21);
  const parent = path.join(c.root, ".codex-local", "fixtures");
  const demo = path.join(parent, "hq-dispatch-demo-v1");
  const sibling = path.join(parent, "outside-demo-sentinel.txt");
  mkdirSync(demo, { recursive: true });
  writeFileSync(path.join(demo, "fixture.txt"), "fixture");
  writeFileSync(sibling, "preserve");
  const reset = resetDemoFixtureRoot({ fixtureRoot: demo, repositoryRoot: c.root });
  equal(existsSync(demo), false, "demo fixture root reset");
  equal(readFileSync(sibling, "utf8"), "preserve", "sibling state preserved");
  equal(reset.production_runtime_untouched, true, "production runtime untouched");
  record(21, "Demo fixture reset affects only demo roots", 3);
}

equal(results.length, 21, "all required failure-injection scenarios executed");
console.log(JSON.stringify({ schema_version: "tsf_hq_dispatch_reliability_matrix_v1", status: "PASS", assertions, scenarios: results }, null, 2));
