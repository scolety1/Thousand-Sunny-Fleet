import { createHash } from "node:crypto";
import { stopAuthenticationHash } from "../../tools/hq-dispatch/v1/reliability.mjs";

export const STOP_INTERRUPTION_IDENTITY_PRESERVED = "ACTIVE_MISSION_CLEARED_INTERRUPTION_IDENTITY_PRESERVED";
export const EXACT_STOP_OWNER_EVIDENCE_REFRESHED = "EXACT_STOP_OWNER_EVIDENCE_REFRESHED_WITH_IMMUTABLE_IDENTITY_PRESERVED";
const NONBLOCKING_UNATTRIBUTED_DISPOSITIONS = new Set([
  "UNATTRIBUTED_PROCESS_OBSERVED_AND_NOT_TARGETED",
  "UNATTRIBUTED_PROCESS_EXITED_WITHOUT_TSF_CAUSAL_TERMINATION_EVIDENCE",
  "UNATTRIBUTED_PROCESS_FINAL_LIVENESS_UNKNOWN_BUT_NOT_TARGETED",
]);
const hashObject = (value) => createHash("sha256").update(JSON.stringify(value)).digest("hex");

function fail(code, detail = null) {
  const suffix = detail === null ? "" : `:${JSON.stringify(detail)}`;
  throw new Error(`STOP_RECEIPT_CONTRACT_${code}${suffix}`);
}

function identity(value, label) {
  if (!value || typeof value !== "object") fail(`${label}_IDENTITY_REQUIRED`);
  const missionId = String(value.mission_id ?? "");
  const missionRevision = Number(value.mission_revision);
  const runId = String(value.run_id ?? "");
  const resultId = String(value.result_id ?? value.run_id ?? "");
  if (!missionId || !Number.isInteger(missionRevision) || missionRevision < 1 || !runId || !resultId) {
    fail(`${label}_IDENTITY_INVALID`, { mission_id: missionId, mission_revision: missionRevision, run_id: runId, result_id: resultId });
  }
  return { mission_id: missionId, mission_revision: missionRevision, run_id: runId, result_id: resultId };
}

function requireIdentity(actualValue, expectedValue, label) {
  const actual = identity(actualValue, label);
  const expected = identity(expectedValue, "EXPECTED");
  for (const field of ["mission_id", "mission_revision", "run_id", "result_id"]) {
    if (actual[field] !== expected[field]) fail(`${label}_${field.toUpperCase()}_MISMATCH`, { expected: expected[field], actual: actual[field] });
  }
  return actual;
}

function require(value, code, detail = null) {
  if (!value) fail(code, detail);
}

export function validateFreshExactStopEvidence({
  cachedOwner,
  freshOwner,
  expected,
  tokenSha256,
  requiredOwnedProcessIds = [],
}) {
  const expectedIdentity = identity(expected, "EXPECTED");
  require(cachedOwner && freshOwner, "OWNER_REFRESH_EVIDENCE_REQUIRED");
  require(freshOwner.server_instance_id === cachedOwner.server_instance_id && freshOwner.server_instance_id === expected.server_instance_id, "OWNER_REFRESH_SERVER_INSTANCE_MISMATCH");
  require(Number(freshOwner.process_id) === Number(cachedOwner.process_id), "OWNER_REFRESH_PROCESS_ID_MISMATCH");
  require(freshOwner.process_start_time === cachedOwner.process_start_time, "OWNER_REFRESH_PROCESS_START_TIME_MISMATCH");
  require(freshOwner.host === cachedOwner.host && Number(freshOwner.port) === Number(cachedOwner.port), "OWNER_REFRESH_LISTENER_IDENTITY_MISMATCH");
  require(/^[a-f0-9]{64}$/.test(String(freshOwner.evidence_hash ?? "")), "OWNER_REFRESH_EVIDENCE_HASH_INVALID");
  require(/^[a-f0-9]{64}$/.test(String(tokenSha256 ?? "")) && tokenSha256 === freshOwner.control_token_sha256, "OWNER_REFRESH_TOKEN_BINDING_MISMATCH");
  const cachedStopAuthenticationHash = stopAuthenticationHash(cachedOwner);
  const freshStopAuthenticationHash = stopAuthenticationHash(freshOwner);
  require(cachedStopAuthenticationHash === freshStopAuthenticationHash, "OWNER_REFRESH_STOP_AUTHENTICATION_IDENTITY_MISMATCH");
  requireIdentity(freshOwner.active_mission, expectedIdentity, "OWNER_REFRESH_ACTIVE_MISSION");
  require(Array.isArray(freshOwner.owned_children), "OWNER_REFRESH_OWNED_CHILDREN_INVALID");
  const freshOwnedProcessIds = new Set(freshOwner.owned_children.map((child) => Number(child.process_id)));
  for (const processId of requiredOwnedProcessIds) {
    require(Number.isInteger(Number(processId)) && freshOwnedProcessIds.has(Number(processId)), "OWNER_REFRESH_REQUIRED_OWNED_PROCESS_MISSING", { process_id: processId });
  }
  return {
    classification: EXACT_STOP_OWNER_EVIDENCE_REFRESHED,
    evidence_hash_changed: freshOwner.evidence_hash !== cachedOwner.evidence_hash,
    stop_authentication_hash: freshStopAuthenticationHash,
    server_instance_id: freshOwner.server_instance_id,
    process_id: freshOwner.process_id,
    process_start_time: freshOwner.process_start_time,
    mission_identity: expectedIdentity,
    required_owned_process_ids: requiredOwnedProcessIds.map(Number),
  };
}

export function verifyInterruptedStopContract({
  expected,
  preStopOwner,
  stopRequest,
  accepted,
  interruption,
  directShutdown = null,
  wrapperResult = null,
  uiBeforeStop = null,
  recoveryItem = null,
  postCleanup,
  unrelatedProcesses = [],
  unattributedProcessSafety = null,
}) {
  const expectedIdentity = identity(expected, "EXPECTED");
  require(preStopOwner?.server_instance_id === expected.server_instance_id, "PRE_STOP_SERVER_INSTANCE_MISMATCH");
  requireIdentity(preStopOwner?.active_mission, expectedIdentity, "PRE_STOP_ACTIVE_MISSION");
  require(Array.isArray(preStopOwner?.owned_children) && preStopOwner.owned_children.length > 0, "PRE_STOP_OWNED_CHILD_REQUIRED");
  require(preStopOwner.owned_children.some((child) => Number(child.process_id) === Number(expected.owned_child_process_id)), "PRE_STOP_EXACT_OWNED_CHILD_MISSING");

  require(stopRequest?.server_instance_id === expected.server_instance_id, "STOP_REQUEST_SERVER_INSTANCE_MISMATCH");
  require(Number(stopRequest?.process_id) === Number(preStopOwner.process_id), "STOP_REQUEST_PROCESS_MISMATCH");
  require(stopRequest?.evidence_hash === stopAuthenticationHash(preStopOwner), "STOP_REQUEST_EVIDENCE_HASH_MISMATCH");

  require(accepted?.schema_version === "tsf_hq_dispatch_stop_accepted_v1", "HTTP_STOP_ACCEPTED_SCHEMA_INVALID");
  require(accepted.server_instance_id === expected.server_instance_id, "HTTP_STOP_SERVER_INSTANCE_MISMATCH");
  require(accepted.operator_session_invalidated === true, "HTTP_STOP_SESSION_NOT_INVALIDATED");
  require(accepted.canonical_records_preserved === true, "HTTP_STOP_CANONICAL_PRESERVATION_MISSING");
  if (accepted.active_mission !== null && accepted.active_mission !== undefined) {
    requireIdentity(accepted.active_mission, expectedIdentity, "HTTP_ACTIVE_MISSION");
  }

  require(interruption?.schema_version === "tsf_hq_dispatch_interruption_evidence_v1", "CANONICAL_INTERRUPTION_REQUIRED");
  requireIdentity(interruption, expectedIdentity, "CANONICAL_INTERRUPTION");
  require(interruption.server_instance_id === expected.server_instance_id, "CANONICAL_INTERRUPTION_SERVER_INSTANCE_MISMATCH");
  require(interruption.operator_initiated === true, "CANONICAL_INTERRUPTION_NOT_OPERATOR_INITIATED");
  require(interruption.original_attempt_completed === false, "CANONICAL_INTERRUPTION_COMPLETION_CONTRADICTION");
  require(interruption.original_attempt_resumable === false, "CANONICAL_INTERRUPTION_RESUMABLE_CONTRADICTION");
  require(interruption.automatic_retry_performed === false, "CANONICAL_INTERRUPTION_AUTOMATIC_RETRY_CONTRADICTION");
  require(interruption.old_thread_or_turn_resumed === false, "CANONICAL_INTERRUPTION_OLD_RUN_RESUMED");

  if (directShutdown !== null) {
    require(directShutdown.child_exited === true, "DIRECT_SHUTDOWN_CHILD_NOT_EXITED");
    require(directShutdown.interrupted_mission_id === expectedIdentity.mission_id, "DIRECT_SHUTDOWN_MISSION_MISMATCH");
  }
  if (wrapperResult !== null) {
    require(wrapperResult.status === "GREEN", "WRAPPER_STOP_NOT_GREEN");
    require(wrapperResult.server_instance_id === expected.server_instance_id, "WRAPPER_SERVER_INSTANCE_MISMATCH");
    require(wrapperResult.accepted?.server_instance_id === accepted.server_instance_id, "WRAPPER_HTTP_PROJECTION_MISMATCH");
    const wrapperActive = wrapperResult.accepted?.active_mission ?? null;
    const httpActive = accepted.active_mission ?? null;
    require(JSON.stringify(wrapperActive) === JSON.stringify(httpActive), "WRAPPER_HTTP_ACTIVE_MISSION_MISMATCH");
  }
  if (uiBeforeStop !== null) {
    require(uiBeforeStop.server_instance === expected.server_instance_id, "UI_STOP_SERVER_INSTANCE_MISMATCH");
    if (uiBeforeStop.active_mission !== null && uiBeforeStop.active_mission !== undefined) {
      requireIdentity(uiBeforeStop.active_mission, expectedIdentity, "UI_ACTIVE_MISSION");
    }
  }
  if (recoveryItem !== null) {
    requireIdentity(recoveryItem, expectedIdentity, "RECOVERY_ITEM");
    require(recoveryItem.classification === "INTERRUPTED_PROCESS_GONE", "RECOVERY_ITEM_CLASSIFICATION_INVALID");
    require(Boolean(recoveryItem.interruption_evidence?.path), "RECOVERY_ITEM_INTERRUPTION_PATH_MISSING");
  }

  require(postCleanup?.active_mission === null, "POST_CLEANUP_ACTIVE_MISSION_REMAINS");
  require(postCleanup.owner_absent === true, "POST_CLEANUP_OWNER_REMAINS");
  require(postCleanup.listener_absent === true, "POST_CLEANUP_LISTENER_REMAINS");
  require(postCleanup.owned_child_absent === true, "POST_CLEANUP_OWNED_CHILD_REMAINS");
  require(postCleanup.operator_session_invalidated === true, "POST_CLEANUP_SESSION_REMAINS_VALID");
  require(unattributedProcessSafety?.schema_version === "tsf_unattributed_process_safety_v2", "UNATTRIBUTED_PROCESS_SAFETY_V2_REQUIRED");
  const { evidence_sha256: safetyEvidenceSha256, ...unsignedSafety } = unattributedProcessSafety;
  require(/^[a-f0-9]{64}$/.test(String(safetyEvidenceSha256 ?? "")) && hashObject(unsignedSafety) === safetyEvidenceSha256, "UNATTRIBUTED_PROCESS_SAFETY_EVIDENCE_HASH_INVALID");
  require(unattributedProcessSafety.status === "PASS", "UNATTRIBUTED_PROCESS_SAFETY_NOT_GREEN");
  require(Number(unattributedProcessSafety.targeted_count) === 0, "UNATTRIBUTED_PROCESS_TARGETED_BY_TSF");
  require(Array.isArray(unattributedProcessSafety.blocking_violations) && unattributedProcessSafety.blocking_violations.length === 0, "UNATTRIBUTED_PROCESS_BLOCKING_VIOLATION");
  require(Number(unattributedProcessSafety.observed_count) === Number(unattributedProcessSafety.non_targeted_count), "UNATTRIBUTED_PROCESS_NON_TARGETED_COUNT_MISMATCH");
  require(Array.isArray(unattributedProcessSafety.processes) && unattributedProcessSafety.processes.length === Number(unattributedProcessSafety.observed_count), "UNATTRIBUTED_PROCESS_DETAIL_COUNT_MISMATCH");
  for (const process of unattributedProcessSafety.processes) {
    require(NONBLOCKING_UNATTRIBUTED_DISPOSITIONS.has(process?.disposition), "UNATTRIBUTED_PROCESS_DISPOSITION_BLOCKING", { process_id: process?.process_id ?? null, disposition: process?.disposition ?? null });
    require(process.appeared_in_owned_process_registry === false, "UNATTRIBUTED_PROCESS_BECAME_OWNED", { process_id: process.process_id });
    require(process.appeared_in_termination_target === false && process.tsf_process_control_action_targeted === false, "UNATTRIBUTED_PROCESS_TARGETED_BY_TSF", { process_id: process.process_id });
    require(process.owned_cleanup_disposition_assigned === false, "UNATTRIBUTED_PROCESS_RECEIVED_OWNED_DISPOSITION", { process_id: process.process_id });
  }
  // `unrelatedProcesses` is retained only as a backward-compatible diagnostic input.
  // Its historical `untouched` wording cannot override the v2 causal result.
  require(Array.isArray(unrelatedProcesses), "UNRELATED_PROCESS_DIAGNOSTIC_INVALID");

  return {
    classification: STOP_INTERRUPTION_IDENTITY_PRESERVED,
    accepted_active_mission_disposition: accepted.active_mission == null ? "NULL_CANONICAL_INTERRUPTION_REQUIRED_AND_PRESENT" : "REQUEST_TIME_ACTIVE_SNAPSHOT_MATCHED",
    authoritative_identity_source: "IMMUTABLE_CANONICAL_STOP_RECORD",
    mission_identity: expectedIdentity,
    unattributed_process_safety: unattributedProcessSafety,
  };
}

export function classifyCompletedBeforeStop({ expected, accepted, lifecycleTerminal, interruption = null }) {
  const expectedIdentity = identity(expected, "EXPECTED");
  require(accepted?.schema_version === "tsf_hq_dispatch_stop_accepted_v1", "HTTP_STOP_ACCEPTED_SCHEMA_INVALID");
  require(accepted.server_instance_id === expected.server_instance_id, "HTTP_STOP_SERVER_INSTANCE_MISMATCH");
  require(accepted.active_mission == null, "COMPLETION_RACE_ACTIVE_MISSION_NOT_CLEARED");
  require(interruption == null, "COMPLETION_RACE_FALSE_INTERRUPTION_PRESENT");
  requireIdentity(lifecycleTerminal, expectedIdentity, "COMPLETION_RACE_LIFECYCLE");
  require(!["", "INTERRUPTED"].includes(String(lifecycleTerminal.terminal_status ?? "")), "COMPLETION_RACE_TERMINAL_STATUS_INVALID");
  return {
    classification: "COMPLETED_BEFORE_STOP_IDENTITY_PRESERVED_NOT_INTERRUPTED",
    authoritative_identity_source: "CANONICAL_LIFECYCLE_TERMINAL_RESULT",
    mission_identity: expectedIdentity,
  };
}
