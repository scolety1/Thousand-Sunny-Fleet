import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { stopAuthenticationHash } from "../tools/hq-dispatch/v1/reliability.mjs";
import {
  EXACT_STOP_OWNER_EVIDENCE_REFRESHED,
  STOP_INTERRUPTION_IDENTITY_PRESERVED,
  classifyCompletedBeforeStop,
  validateFreshExactStopEvidence,
  verifyInterruptedStopContract,
} from "./support/tsf-stop-receipt-contract.mjs";

let assertions = 0;

function check(value, message) {
  assertions += 1;
  assert.ok(value, message);
}

function equal(actual, expected, message) {
  assertions += 1;
  assert.equal(actual, expected, message);
}

const hashObject = (value) => createHash("sha256").update(JSON.stringify(value)).digest("hex");
function sealSafety(fixture) {
  const { evidence_sha256: ignored, ...unsigned } = fixture.unattributedProcessSafety;
  fixture.unattributedProcessSafety = { ...unsigned, evidence_sha256: hashObject(unsigned) };
}

function fails(mutator, code, { rehash = true } = {}) {
  assertions += 1;
  const fixture = makeFixture();
  mutator(fixture);
  if (rehash && fixture.unattributedProcessSafety) sealSafety(fixture);
  assert.throws(() => verifyInterruptedStopContract(fixture), new RegExp(`STOP_RECEIPT_CONTRACT_${code}`));
}

function makeUnattributedSafety(disposition = "UNATTRIBUTED_PROCESS_OBSERVED_AND_NOT_TARGETED") {
  const process = {
    process_id: 51001,
    process_start_time: "2026-07-18T19:59:00.000Z",
    executable_identity: "C:\\Program Files\\nodejs\\node.exe",
    parent_identity: { process_id: 51000 },
    first_observed_at: "2026-07-18T20:00:00.000Z",
    final_observed_at: "2026-07-18T20:00:01.000Z",
    appeared_in_owned_process_registry: false,
    appeared_in_termination_target: false,
    tsf_process_control_action_targeted: false,
    owned_cleanup_disposition_assigned: false,
    final_liveness: disposition === "UNATTRIBUTED_PROCESS_OBSERVED_AND_NOT_TARGETED" ? "OBSERVED_ALIVE" : disposition === "UNATTRIBUTED_PROCESS_EXITED_WITHOUT_TSF_CAUSAL_TERMINATION_EVIDENCE" ? "NO_LONGER_OBSERVED" : "UNKNOWN",
    disposition,
  };
  const unsigned = {
    schema_version: "tsf_unattributed_process_safety_v2",
    status: "PASS",
    observed_count: 1,
    targeted_count: 0,
    non_targeted_count: 1,
    exited_without_tsf_causation_count: disposition === "UNATTRIBUTED_PROCESS_EXITED_WITHOUT_TSF_CAUSAL_TERMINATION_EVIDENCE" ? 1 : 0,
    unknown_final_liveness_count: disposition === "UNATTRIBUTED_PROCESS_FINAL_LIVENESS_UNKNOWN_BUT_NOT_TARGETED" ? 1 : 0,
    blocking_violations: [],
    processes: [process],
  };
  return { ...unsigned, evidence_sha256: hashObject(unsigned) };
}

function makeFixture() {
  const mission = {
    mission_id: "hq2-stop-contract-fixture-0001",
    mission_revision: 3,
    run_id: "canonical-result-hq2-stop-contract-fixture-0001-3",
    result_id: "canonical-result-hq2-stop-contract-fixture-0001-3",
  };
  const serverInstance = "hq-instance-stop-contract-fixture-0001";
  const owner = {
    process_id: 41001,
    process_start_time: "2026-07-18T19:59:30.000Z",
    executable: "C:\\Program Files\\nodejs\\node.exe",
    server_instance_id: serverInstance,
    operator_session_generation: "hq-session-generation-stop-contract-fixture-0001",
    host: "127.0.0.1",
    port: 4317,
    evidence_hash: "a".repeat(64),
    control_token_sha256: "c".repeat(64),
    created_at: "2026-07-18T19:59:30.000Z",
    active_mission: { ...mission },
    owned_children: [{ process_id: 41002, process_start_time: "2026-07-18T20:00:00.000Z", executable: "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe" }],
  };
  const accepted = {
    schema_version: "tsf_hq_dispatch_stop_accepted_v1",
    server_instance_id: serverInstance,
    active_mission: null,
    owned_child_process_ids: [41002],
    canonical_records_preserved: true,
    operator_session_invalidated: true,
  };
  return {
    expected: { ...mission, server_instance_id: serverInstance, owned_child_process_id: 41002 },
    preStopOwner: owner,
    stopRequest: { server_instance_id: serverInstance, evidence_hash: stopAuthenticationHash(owner), process_id: owner.process_id },
    accepted,
    interruption: {
      schema_version: "tsf_hq_dispatch_interruption_evidence_v1",
      ...mission,
      server_instance_id: serverInstance,
      operator_initiated: true,
      original_attempt_completed: false,
      original_attempt_resumable: false,
      automatic_retry_performed: false,
      old_thread_or_turn_resumed: false,
    },
    directShutdown: { child_exited: true, interrupted_mission_id: mission.mission_id },
    wrapperResult: { status: "GREEN", server_instance_id: serverInstance, accepted: structuredClone(accepted) },
    uiBeforeStop: { server_instance: serverInstance, active_mission: { ...mission } },
    recoveryItem: { ...mission, classification: "INTERRUPTED_PROCESS_GONE", interruption_evidence: { path: "C:\\fixture\\STOP_RECORD.json" } },
    postCleanup: { active_mission: null, owner_absent: true, listener_absent: true, owned_child_absent: true, operator_session_invalidated: true },
    unrelatedProcesses: [{ process_id: 51001, untouched: false }],
    unattributedProcessSafety: makeUnattributedSafety(),
  };
}

function refreshFails(mutator, code) {
  assertions += 1;
  const fixture = makeFixture();
  const cachedOwner = structuredClone(fixture.preStopOwner);
  const freshOwner = structuredClone(fixture.preStopOwner);
  freshOwner.evidence_hash = "b".repeat(64);
  const tokenSha256 = freshOwner.control_token_sha256;
  mutator({ fixture, cachedOwner, freshOwner });
  assert.throws(() => validateFreshExactStopEvidence({
    cachedOwner,
    freshOwner,
    expected: fixture.expected,
    tokenSha256,
    requiredOwnedProcessIds: [fixture.expected.owned_child_process_id],
  }), new RegExp(`STOP_RECEIPT_CONTRACT_${code}`));
}

const refreshFixture = makeFixture();
const refreshedOwner = structuredClone(refreshFixture.preStopOwner);
refreshedOwner.evidence_hash = "b".repeat(64);
const refreshedStopEvidence = validateFreshExactStopEvidence({
  cachedOwner: refreshFixture.preStopOwner,
  freshOwner: refreshedOwner,
  expected: refreshFixture.expected,
  tokenSha256: refreshedOwner.control_token_sha256,
  requiredOwnedProcessIds: [refreshFixture.expected.owned_child_process_id],
});
equal(refreshedStopEvidence.classification, EXACT_STOP_OWNER_EVIDENCE_REFRESHED, "fresh exact Stop owner evidence preserves immutable identity after owner evidence changes");
equal(refreshedStopEvidence.evidence_hash_changed, true, "owner evidence-hash refresh is explicit rather than treated as immutable identity drift");
refreshFails(({ freshOwner }) => { freshOwner.server_instance_id = "hq-instance-cross-server"; }, "OWNER_REFRESH_SERVER_INSTANCE_MISMATCH");
refreshFails(({ freshOwner }) => { freshOwner.process_id += 1; }, "OWNER_REFRESH_PROCESS_ID_MISMATCH");
refreshFails(({ freshOwner }) => { freshOwner.process_start_time = "2026-07-18T20:01:00.000Z"; }, "OWNER_REFRESH_PROCESS_START_TIME_MISMATCH");
refreshFails(({ freshOwner }) => { freshOwner.port = 4318; }, "OWNER_REFRESH_LISTENER_IDENTITY_MISMATCH");
refreshFails(({ freshOwner }) => { freshOwner.evidence_hash = "invalid"; }, "OWNER_REFRESH_EVIDENCE_HASH_INVALID");
refreshFails(({ freshOwner }) => { freshOwner.control_token_sha256 = "d".repeat(64); }, "OWNER_REFRESH_TOKEN_BINDING_MISMATCH");
refreshFails(({ freshOwner }) => { freshOwner.active_mission.mission_revision += 1; }, "OWNER_REFRESH_ACTIVE_MISSION_MISSION_REVISION_MISMATCH");
refreshFails(({ freshOwner }) => { freshOwner.active_mission.run_id = "canonical-result-cross-run"; }, "OWNER_REFRESH_ACTIVE_MISSION_RUN_ID_MISMATCH");
refreshFails(({ freshOwner }) => { freshOwner.owned_children = []; }, "OWNER_REFRESH_REQUIRED_OWNED_PROCESS_MISSING");

const baseline = verifyInterruptedStopContract(makeFixture());
equal(baseline.classification, STOP_INTERRUPTION_IDENTITY_PRESERVED, "null request-time active mission is accepted only with immutable canonical interruption identity");
equal(baseline.accepted_active_mission_disposition, "NULL_CANONICAL_INTERRUPTION_REQUIRED_AND_PRESENT", "null accepted snapshot is explicitly classified");
equal(baseline.authoritative_identity_source, "IMMUTABLE_CANONICAL_STOP_RECORD", "STOP_RECORD is the immutable interrupted identity source");
equal(baseline.unattributed_process_safety.targeted_count, 0, "causal Stop proof requires zero unattributed targets, not continued liveness");

for (const disposition of [
  "UNATTRIBUTED_PROCESS_OBSERVED_AND_NOT_TARGETED",
  "UNATTRIBUTED_PROCESS_EXITED_WITHOUT_TSF_CAUSAL_TERMINATION_EVIDENCE",
  "UNATTRIBUTED_PROCESS_FINAL_LIVENESS_UNKNOWN_BUT_NOT_TARGETED",
]) {
  const fixture = makeFixture();
  fixture.unattributedProcessSafety = makeUnattributedSafety(disposition);
  equal(verifyInterruptedStopContract(fixture).unattributed_process_safety.processes[0].disposition, disposition, `${disposition} is nonblocking when causal target evidence is clean`);
}

const activeSnapshotFixture = makeFixture();
activeSnapshotFixture.accepted.active_mission = { ...activeSnapshotFixture.expected };
activeSnapshotFixture.wrapperResult.accepted.active_mission = { ...activeSnapshotFixture.expected };
const activeSnapshot = verifyInterruptedStopContract(activeSnapshotFixture);
equal(activeSnapshot.accepted_active_mission_disposition, "REQUEST_TIME_ACTIVE_SNAPSHOT_MATCHED", "non-null accepted active snapshot must bind the same mission");

fails((f) => { f.interruption = null; }, "CANONICAL_INTERRUPTION_REQUIRED");
fails((f) => { f.preStopOwner.active_mission.mission_id = "hq2-wrong-mission-0002"; }, "PRE_STOP_ACTIVE_MISSION_MISSION_ID_MISMATCH");
fails((f) => { f.interruption.mission_id = "hq2-wrong-mission-0002"; }, "CANONICAL_INTERRUPTION_MISSION_ID_MISMATCH");
fails((f) => { f.interruption.mission_revision += 1; }, "CANONICAL_INTERRUPTION_MISSION_REVISION_MISMATCH");
fails((f) => { f.interruption.run_id = "canonical-result-cross-run-0002"; }, "CANONICAL_INTERRUPTION_RUN_ID_MISMATCH");
fails((f) => { f.interruption.result_id = "canonical-result-cross-result-0002"; }, "CANONICAL_INTERRUPTION_RESULT_ID_MISMATCH");
fails((f) => { f.interruption.server_instance_id = "hq-instance-wrong-0002"; }, "CANONICAL_INTERRUPTION_SERVER_INSTANCE_MISMATCH");
fails((f) => { f.accepted.server_instance_id = "hq-instance-stale-0002"; }, "HTTP_STOP_SERVER_INSTANCE_MISMATCH");
fails((f) => { f.accepted.active_mission = { ...f.expected, run_id: "canonical-result-stale-0002", result_id: "canonical-result-stale-0002" }; }, "HTTP_ACTIVE_MISSION_RUN_ID_MISMATCH");
fails((f) => { f.stopRequest.evidence_hash = "b".repeat(64); }, "STOP_REQUEST_EVIDENCE_HASH_MISMATCH");
fails((f) => { f.stopRequest.server_instance_id = "hq-instance-wrong-request-0002"; }, "STOP_REQUEST_SERVER_INSTANCE_MISMATCH");
fails((f) => { f.preStopOwner.owned_children = []; }, "PRE_STOP_OWNED_CHILD_REQUIRED");
fails((f) => { f.directShutdown.interrupted_mission_id = "hq2-direct-cross-run-0002"; }, "DIRECT_SHUTDOWN_MISSION_MISMATCH");
fails((f) => { f.wrapperResult.accepted.active_mission = { ...f.expected }; }, "WRAPPER_HTTP_ACTIVE_MISSION_MISMATCH");
fails((f) => { f.uiBeforeStop.active_mission = { ...f.expected, mission_revision: 4 }; }, "UI_ACTIVE_MISSION_MISSION_REVISION_MISMATCH");
fails((f) => { f.recoveryItem.run_id = "canonical-result-recovery-cross-run-0002"; }, "RECOVERY_ITEM_RUN_ID_MISMATCH");
fails((f) => { f.recoveryItem.classification = "RESULT_WITHOUT_ADMISSION"; }, "RECOVERY_ITEM_CLASSIFICATION_INVALID");
fails((f) => { f.postCleanup.active_mission = { ...f.expected }; }, "POST_CLEANUP_ACTIVE_MISSION_REMAINS");
fails((f) => { f.postCleanup.owner_absent = false; }, "POST_CLEANUP_OWNER_REMAINS");
fails((f) => { f.postCleanup.listener_absent = false; }, "POST_CLEANUP_LISTENER_REMAINS");
fails((f) => { f.postCleanup.owned_child_absent = false; }, "POST_CLEANUP_OWNED_CHILD_REMAINS");
fails((f) => { f.postCleanup.operator_session_invalidated = false; }, "POST_CLEANUP_SESSION_REMAINS_VALID");
fails((f) => { f.unattributedProcessSafety = null; }, "UNATTRIBUTED_PROCESS_SAFETY_V2_REQUIRED", { rehash: false });
fails((f) => { f.unattributedProcessSafety.targeted_count = 1; f.unattributedProcessSafety.non_targeted_count = 0; }, "UNATTRIBUTED_PROCESS_TARGETED_BY_TSF");
fails((f) => { f.unattributedProcessSafety.processes[0].appeared_in_owned_process_registry = true; }, "UNATTRIBUTED_PROCESS_BECAME_OWNED");
fails((f) => { f.unattributedProcessSafety.processes[0].owned_cleanup_disposition_assigned = true; }, "UNATTRIBUTED_PROCESS_RECEIVED_OWNED_DISPOSITION");
fails((f) => { f.unattributedProcessSafety.processes[0].disposition = "UNATTRIBUTED_PROCESS_TARGETED_BY_TSF"; }, "UNATTRIBUTED_PROCESS_DISPOSITION_BLOCKING");
fails((f) => { f.unattributedProcessSafety.evidence_sha256 = "0".repeat(64); }, "UNATTRIBUTED_PROCESS_SAFETY_EVIDENCE_HASH_INVALID", { rehash: false });
fails((f) => { f.interruption.original_attempt_completed = true; }, "CANONICAL_INTERRUPTION_COMPLETION_CONTRADICTION");

const completionFixture = makeFixture();
const completion = classifyCompletedBeforeStop({
  expected: completionFixture.expected,
  accepted: completionFixture.accepted,
  lifecycleTerminal: { ...completionFixture.expected, terminal_status: "INTERNAL_ERROR" },
  interruption: null,
});
equal(completion.classification, "COMPLETED_BEFORE_STOP_IDENTITY_PRESERVED_NOT_INTERRUPTED", "completion race remains canonical completion/failure and is not relabeled interrupted");

assertions += 1;
assert.throws(() => classifyCompletedBeforeStop({
  expected: completionFixture.expected,
  accepted: completionFixture.accepted,
  lifecycleTerminal: { ...completionFixture.expected, terminal_status: "INTERNAL_ERROR" },
  interruption: completionFixture.interruption,
}), /STOP_RECEIPT_CONTRACT_COMPLETION_RACE_FALSE_INTERRUPTION_PRESENT/);

check(assertions >= 29, "adversarial Stop contract coverage count is explicit");
process.stdout.write(`${JSON.stringify({ schema_version: "tsf_stop_receipt_contract_adversarial_test_v1", status: "PASS", assertions })}\n`);
