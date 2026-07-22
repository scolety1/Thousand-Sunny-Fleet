import { createHash, randomUUID } from "node:crypto";
import { closeSync, existsSync, fsyncSync, mkdirSync, openSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const TERMINATING_ACTIONS = new Set([
  "REQUEST_COOPERATIVE_STOP",
  "SIGNAL_OWNED_PROCESS",
  "TERMINATE_OWNED_PROCESS",
]);
const ACTION_TYPES = new Set([
  "OBSERVE_PROCESS",
  "REGISTER_PROOF_OWNERSHIP",
  ...TERMINATING_ACTIONS,
  "CONFIRM_PROCESS_EXIT",
  "LEAVE_UNATTRIBUTED_PROCESS_UNTOUCHED",
]);
const TERMINAL_DISPOSITIONS = new Set(["COOPERATIVE_EXIT_CONFIRMED", "FORCED_TERMINATION_CONFIRMED", "ALREADY_GONE_WITH_IDENTITY_CONFIRMED", "CLEANUP_UNCONFIRMED"]);
const NONBLOCKING_UNATTRIBUTED_DISPOSITIONS = new Set([
  "UNATTRIBUTED_PROCESS_OBSERVED_AND_NOT_TARGETED",
  "UNATTRIBUTED_PROCESS_EXITED_WITHOUT_TSF_CAUSAL_TERMINATION_EVIDENCE",
  "UNATTRIBUTED_PROCESS_FINAL_LIVENESS_UNKNOWN_BUT_NOT_TARGETED",
]);
const sha256Text = (value) => createHash("sha256").update(String(value), "utf8").digest("hex");
const identityKey = (value) => `${Number(value?.process_id ?? value?.target_process_id)}|${Date.parse(value?.process_start_time ?? value?.target_process_start_time)}`;
const requireValue = (condition, classification) => {
  if (!condition) {
    const error = new Error(classification);
    error.classification = classification;
    throw error;
  }
};

export function readProcessActionLedger(filePath) {
  requireValue(existsSync(filePath), "PROCESS_ACTION_LEDGER_MISSING");
  const lines = readFileSync(filePath, "utf8").split(/\r?\n/).filter(Boolean);
  requireValue(lines.length > 0, "PROCESS_ACTION_LEDGER_EMPTY");
  return lines.map((line, index) => {
    try { return JSON.parse(line); }
    catch { throw Object.assign(new Error(`PROCESS_ACTION_LEDGER_INVALID_JSON:${index + 1}`), { classification: "PROCESS_ACTION_LEDGER_INVALID_JSON" }); }
  });
}

export function validateProcessActionLedgerIntegrity(events) {
  requireValue(Array.isArray(events) && events.length > 0, "PROCESS_ACTION_LEDGER_MISSING_OR_EMPTY");
  const actionIds = new Set();
  for (const event of events) {
    requireValue(event && typeof event === "object", "PROCESS_ACTION_LEDGER_EVENT_INVALID");
    requireValue(typeof event.action_id === "string" && event.action_id.length > 0 && !actionIds.has(event.action_id), "PROCESS_ACTION_LEDGER_ACTION_ID_DUPLICATE_OR_MISSING");
    actionIds.add(event.action_id);
    requireValue(/^[a-f0-9]{64}$/.test(String(event.evidence_sha256 ?? "")), "PROCESS_ACTION_LEDGER_EVIDENCE_HASH_MISSING");
    const { evidence_sha256: ignored, ...body } = event;
    requireValue(sha256Text(JSON.stringify(body)) === event.evidence_sha256, "PROCESS_ACTION_LEDGER_EVIDENCE_HASH_MISMATCH");
  }
  return { status: "PASS", event_count: events.length, unique_action_ids: actionIds.size };
}

export class ProcessActionLedger {
  constructor({ filePath, writerIdentity }) {
    this.filePath = path.resolve(filePath);
    this.writerIdentity = writerIdentity;
    mkdirSync(path.dirname(this.filePath), { recursive: true });
  }
  record(action) {
    requireValue(ACTION_TYPES.has(action?.action_type), "PROCESS_ACTION_TYPE_INVALID");
    requireValue(typeof action?.proof_stage === "string" && action.proof_stage.length > 0, "PROCESS_ACTION_STAGE_REQUIRED");
    requireValue(Number.isInteger(Number(action?.target_process_id)) && Number(action.target_process_id) > 0, "PROCESS_ACTION_PID_REQUIRED");
    requireValue(Number.isFinite(Date.parse(action?.target_process_start_time)), "PROCESS_ACTION_START_TIME_REQUIRED");
    requireValue(["PROOF_OWNED", "UNATTRIBUTED"].includes(action?.ownership_classification), "PROCESS_ACTION_OWNERSHIP_CLASSIFICATION_REQUIRED");
    const event = {
      schema_version: "tsf_process_action_v1",
      action_id: action.action_id ?? `process-action-${Date.now().toString(36)}-${randomUUID()}`,
      writer_identity: this.writerIdentity,
      proof_stage: action.proof_stage,
      utc_timestamp: new Date().toISOString(),
      action_type: action.action_type,
      process_registration_id: action.process_registration_id ?? null,
      registration_sequence: Number.isInteger(Number(action.registration_sequence)) ? Number(action.registration_sequence) : null,
      root_process_registration_id: action.root_process_registration_id ?? null,
      parent_process_registration_id: action.parent_process_registration_id ?? null,
      registration_status: action.registration_status ?? null,
      immutable_registry_event_sha256: action.immutable_registry_event_sha256 ?? null,
      target_process_id: Number(action.target_process_id),
      target_process_start_time: action.target_process_start_time,
      target_executable_identity: action.target_executable_identity ?? null,
      target_executable_identity_sha256: sha256Text(action.target_executable_identity ?? ""),
      ownership_classification: action.ownership_classification,
      ownership_evidence_sha256: action.ownership_evidence_sha256 ?? null,
      parent_identity: action.parent_identity ?? null,
      server_instance_id: action.server_instance_id ?? null,
      proof_identity: action.proof_identity ?? null,
      mission_identity: action.mission_identity ?? null,
      candidate_worktree: action.candidate_worktree ?? null,
      candidate_commit: action.candidate_commit ?? null,
      launch_identity_sha256: action.launch_identity_sha256 ?? null,
      reason: action.reason ?? null,
      requested_operation: action.requested_operation ?? null,
      selection_method: action.selection_method ?? "EXACT_PID_START_TIME_AND_OWNERSHIP_EVIDENCE",
      affected_processes: action.affected_processes ?? [],
      os_api_result: action.os_api_result ?? null,
      post_action_observation: action.post_action_observation ?? null,
      disposition: action.disposition ?? null,
      terminal_disposition: action.terminal_disposition ?? null,
      cooperative_request_identity: action.cooperative_request_identity ?? null,
      forced_termination_identity: action.forced_termination_identity ?? null,
      observed_exit_or_close_at: action.observed_exit_or_close_at ?? null,
      exit_code: Number.isInteger(action.exit_code) ? action.exit_code : null,
      exit_code_disposition: Number.isInteger(action.exit_code) ? "NUMERIC_EXIT_OBSERVED" : (action.exit_code_disposition ?? null),
      pid_reuse_check: action.pid_reuse_check ?? null,
    };
    if (event.terminal_disposition) requireValue(TERMINAL_DISPOSITIONS.has(event.terminal_disposition), "TERMINAL_CLEANUP_DISPOSITION_INVALID");
    event.evidence_sha256 = sha256Text(JSON.stringify(event));
    const descriptor = openSync(this.filePath, "a", 0o600);
    try {
      writeFileSync(descriptor, `${JSON.stringify(event)}\n`, "utf8");
      fsyncSync(descriptor);
    } finally {
      closeSync(descriptor);
    }
    return event;
  }
}

export function validateRegistryLedgerSynchronization(registryEntries, events) {
  requireValue(Array.isArray(registryEntries), "OWNED_PROCESS_REGISTRY_ENTRIES_REQUIRED");
  requireValue(Array.isArray(events), "PROCESS_ACTION_LEDGER_EVENTS_REQUIRED");
  const registryById = new Map();
  for (const entry of registryEntries) {
    requireValue(entry?.process_registration_id && !registryById.has(entry.process_registration_id), "OWNED_PROCESS_DUPLICATE_REGISTRY_REGISTRATION");
    requireValue(entry.registration_status === "COMMITTED", "OWNED_PROCESS_REGISTRY_LEDGER_REGISTRATION_INCOMPLETE");
    registryById.set(entry.process_registration_id, entry);
  }
  const ownershipEvents = events.filter((event) => event.action_type === "REGISTER_PROOF_OWNERSHIP" && event.process_registration_id);
  const ledgerById = new Map();
  for (const event of ownershipEvents) {
    requireValue(registryById.has(event.process_registration_id), "OWNED_PROCESS_LEDGER_WITHOUT_REGISTRY_REGISTRATION");
    requireValue(!ledgerById.has(event.process_registration_id), "OWNED_PROCESS_DUPLICATE_LEDGER_REGISTRATION");
    ledgerById.set(event.process_registration_id, event);
  }
  for (const [registrationId, entry] of registryById) {
    const event = ledgerById.get(registrationId);
    requireValue(event, "OWNED_PROCESS_REGISTRY_WITHOUT_LEDGER_REGISTRATION");
    requireValue(Number(event.registration_sequence) === Number(entry.registration_sequence), "OWNED_PROCESS_REGISTRY_LEDGER_SEQUENCE_MISMATCH");
    requireValue(Number(event.target_process_id) === Number(entry.process_id), "OWNED_PROCESS_REGISTRY_LEDGER_PID_MISMATCH");
    requireValue(Date.parse(event.target_process_start_time) === Date.parse(entry.process_start_time), "OWNED_PROCESS_REGISTRY_LEDGER_START_TIME_MISMATCH");
    requireValue(event.ownership_evidence_sha256 === entry.ownership_evidence_sha256, "OWNED_PROCESS_REGISTRY_LEDGER_OWNERSHIP_HASH_MISMATCH");
    requireValue(event.server_instance_id === entry.server_instance_id, "OWNED_PROCESS_REGISTRY_LEDGER_SERVER_INSTANCE_MISMATCH");
    requireValue(event.root_process_registration_id === entry.root_process_registration_id, "OWNED_PROCESS_REGISTRY_LEDGER_ROOT_MISMATCH");
    requireValue(JSON.stringify(event.mission_identity ?? null) === JSON.stringify(entry.mission_identity ?? null), "OWNED_PROCESS_REGISTRY_LEDGER_MISSION_MISMATCH");
    const registrationIndex = events.indexOf(event);
    const exitObservations = events.filter((candidate) => candidate.action_type === "OBSERVE_PROCESS" && candidate.process_registration_id === registrationId);
    const terminals = events.filter((candidate) => candidate.action_type === "CONFIRM_PROCESS_EXIT" && candidate.process_registration_id === registrationId);
    requireValue(terminals.length <= 1, "DUPLICATE_OR_CONFLICTING_TERMINAL_CLEANUP_DISPOSITION");
    if (terminals.length === 1) {
      requireValue(exitObservations.length === 1, "OWNED_PROCESS_EXIT_OBSERVATION_MISSING");
      requireValue(events.indexOf(exitObservations[0]) > registrationIndex, "OWNED_PROCESS_EXIT_OBSERVATION_BEFORE_REGISTRATION");
      requireValue(events.indexOf(terminals[0]) > events.indexOf(exitObservations[0]), "OWNED_PROCESS_TERMINAL_BEFORE_EXIT_OBSERVATION");
    }
  }
  return { status: "PASS", registry_entries: registryById.size, ownership_ledger_events: ledgerById.size };
}

export function validateCausalProcessSafety(events) {
  requireValue(Array.isArray(events) && events.length > 0, "PROCESS_ACTION_LEDGER_MISSING_OR_EMPTY");
  const registrations = new Map();
  const unattributed = new Map();
  const terminationTargets = new Set();
  const confirmedExits = new Set();
  const terminalByIdentity = new Map();
  let terminatingActions = 0;
  for (const event of events) {
    requireValue(ACTION_TYPES.has(event.action_type), "PROCESS_ACTION_TYPE_INVALID");
    requireValue(event.selection_method !== "EXECUTABLE_NAME_ONLY" && event.selection_method !== "PROCESS_NAME_ONLY", "BROAD_PROCESS_NAME_TERMINATION_FORBIDDEN");
    const key = identityKey({ process_id: event.target_process_id, process_start_time: event.target_process_start_time });
    if (event.action_type === "REGISTER_PROOF_OWNERSHIP") {
      requireValue(event.ownership_classification === "PROOF_OWNED", "OWNERSHIP_REGISTRATION_CLASSIFICATION_INVALID");
      requireValue(/^[a-f0-9]{64}$/.test(String(event.ownership_evidence_sha256 ?? "")), "OWNERSHIP_EVIDENCE_MISSING");
      requireValue(event.server_instance_id && event.proof_identity && event.candidate_worktree && /^[a-f0-9]{40}$/.test(String(event.candidate_commit ?? "")), "OWNERSHIP_BINDING_INCOMPLETE");
      registrations.set(key, event);
    }
    if (event.ownership_classification === "UNATTRIBUTED") {
      requireValue(!event.terminal_disposition, "UNATTRIBUTED_PROCESS_RECEIVED_OWNED_TERMINAL_DISPOSITION");
      const history = unattributed.get(key) ?? [];
      history.push(event);
      unattributed.set(key, history);
    }
    if (event.action_type === "CONFIRM_PROCESS_EXIT" && event.ownership_classification === "PROOF_OWNED") {
      requireValue(TERMINAL_DISPOSITIONS.has(event.terminal_disposition), "TERMINAL_CLEANUP_DISPOSITION_MISSING");
      const prior = terminalByIdentity.get(key) ?? [];
      prior.push(event); terminalByIdentity.set(key, prior);
      requireValue(prior.length === 1, "DUPLICATE_OR_CONFLICTING_TERMINAL_CLEANUP_DISPOSITION");
      requireValue(event.terminal_disposition !== "CLEANUP_UNCONFIRMED", "CLEANUP_UNCONFIRMED");
      requireValue(event.post_action_observation?.alive === false, "OWNED_PROCESS_EXIT_NOT_CONFIRMED");
      confirmedExits.add(key);
    }
    if (!TERMINATING_ACTIONS.has(event.action_type)) continue;
    terminatingActions += 1;
    terminationTargets.add(key);
    requireValue(event.ownership_classification === "PROOF_OWNED", "UNATTRIBUTED_PROCESS_TARGETED");
    const registration = registrations.get(key);
    requireValue(registration, "TERMINATION_TARGET_OWNERSHIP_REGISTRATION_MISSING");
    requireValue(registration.ownership_evidence_sha256 === event.ownership_evidence_sha256, "TERMINATION_TARGET_OWNERSHIP_HASH_MISMATCH");
    requireValue(event.requested_operation && event.os_api_result, "TERMINATION_TARGET_RESULT_MISSING");
    const contained = new Set([key]);
    const pending = [];
    for (const affected of event.affected_processes ?? []) {
      terminationTargets.add(identityKey(affected));
      const affectedRegistration = registrations.get(identityKey(affected));
      requireValue(affectedRegistration, "PROCESS_TREE_CONTAINS_UNREGISTERED_TARGET");
      requireValue(affectedRegistration.ownership_evidence_sha256 === event.ownership_evidence_sha256, "PROCESS_TREE_OWNERSHIP_HASH_MISMATCH");
      pending.push(affectedRegistration);
    }
    for (let pass = 0; pending.length && pass <= pending.length; pass += 1) {
      for (let index = pending.length - 1; index >= 0; index -= 1) {
        const parent = pending[index].parent_identity;
        if (contained.has(identityKey(parent))) {
          contained.add(identityKey(pending[index])); pending.splice(index, 1);
        }
      }
    }
    requireValue(pending.length === 0, "PROCESS_TREE_ESCAPES_PROVEN_OWNED_ROOT");
  }
  requireValue(terminatingActions > 0, "PROCESS_ACTION_TERMINATION_TARGET_LEDGER_MISSING");
  for (const event of events.filter((candidate) => candidate.action_type === "CONFIRM_PROCESS_EXIT" && candidate.ownership_classification === "PROOF_OWNED")) {
    requireValue(registrations.has(identityKey(event)), "PROCESS_EXIT_CONFIRMATION_WITHOUT_OWNERSHIP");
    requireValue(event.post_action_observation?.alive === false, "OWNED_PROCESS_EXIT_NOT_CONFIRMED");
  }
  for (const key of terminationTargets) requireValue(confirmedExits.has(key), "TERMINATION_TARGET_EXIT_CONFIRMATION_MISSING");
  const unattributedDispositions = [];
  for (const [key, history] of unattributed) {
    requireValue(!registrations.has(key), "UNATTRIBUTED_PROCESS_REGISTERED_AS_OWNED");
    requireValue(!terminationTargets.has(key), "UNATTRIBUTED_PROCESS_TARGETED");
    const first = history[0];
    const last = history.at(-1);
    const finalAlive = last.post_action_observation?.alive;
    const disposition = finalAlive === true
      ? "UNATTRIBUTED_PROCESS_OBSERVED_AND_NOT_TARGETED"
      : finalAlive === false
        ? "UNATTRIBUTED_PROCESS_EXITED_WITHOUT_TSF_CAUSAL_TERMINATION_EVIDENCE"
        : "UNATTRIBUTED_PROCESS_FINAL_LIVENESS_UNKNOWN_BUT_NOT_TARGETED";
    requireValue(NONBLOCKING_UNATTRIBUTED_DISPOSITIONS.has(disposition), "UNATTRIBUTED_PROCESS_TARGETED_BY_TSF");
    unattributedDispositions.push({
      process_id: first.target_process_id,
      process_start_time: first.target_process_start_time,
      executable_identity: first.target_executable_identity ?? null,
      parent_identity: first.parent_identity ?? null,
      first_observed_at: first.utc_timestamp ?? null,
      final_observed_at: last.utc_timestamp ?? null,
      appeared_in_owned_process_registry: false,
      appeared_in_termination_target: false,
      tsf_process_control_action_targeted: false,
      owned_cleanup_disposition_assigned: false,
      final_liveness: finalAlive === true ? "OBSERVED_ALIVE" : finalAlive === false ? "NO_LONGER_OBSERVED" : "UNKNOWN",
      disposition,
    });
  }
  const unsignedUnattributedSafety = {
    schema_version: "tsf_unattributed_process_safety_v2",
    status: "PASS",
    observed_count: unattributedDispositions.length,
    targeted_count: 0,
    non_targeted_count: unattributedDispositions.length,
    exited_without_tsf_causation_count: unattributedDispositions.filter((entry) => entry.disposition === "UNATTRIBUTED_PROCESS_EXITED_WITHOUT_TSF_CAUSAL_TERMINATION_EVIDENCE").length,
    unknown_final_liveness_count: unattributedDispositions.filter((entry) => entry.disposition === "UNATTRIBUTED_PROCESS_FINAL_LIVENESS_UNKNOWN_BUT_NOT_TARGETED").length,
    blocking_violations: [],
    processes: unattributedDispositions,
  };
  const unattributedProcessSafety = {
    ...unsignedUnattributedSafety,
    evidence_sha256: sha256Text(JSON.stringify(unsignedUnattributedSafety)),
  };
  return {
    status: "PASS",
    proof_owned_registrations: registrations.size,
    terminating_actions: terminatingActions,
    unattributed_processes: unattributedDispositions,
    unattributed_process_safety_v2: unattributedProcessSafety,
    no_unattributed_termination_target: true,
    no_name_only_termination: true,
    exact_pid_start_time_required: true,
  };
}
