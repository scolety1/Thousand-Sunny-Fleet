import { createHash, randomUUID } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";

const MAX_ERROR_TEXT = 512;
const nowIso = () => new Date().toISOString();
const sha256Bytes = (value) => createHash("sha256").update(value).digest("hex");
const bounded = (value, limit = MAX_ERROR_TEXT) => value === undefined || value === null ? null : String(value).slice(0, limit);
function errorEvidence(error) {
  const cause = error?.cause;
  return {
    error_class: error?.constructor?.name ?? typeof error,
    error_name: bounded(error?.name), error_message: bounded(error?.message), error_code: bounded(error?.code),
    nested_cause: cause ? { error_class: cause?.constructor?.name ?? typeof cause, error_name: bounded(cause?.name), error_message: bounded(cause?.message), error_code: bounded(cause?.code) } : null,
  };
}
function jsonWrite(filePath, value) {
  mkdirSync(path.dirname(filePath), { recursive: true });
  writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`, "utf8");
}
function sanitizeOwner(ownership) {
  const owner = ownership?.owner ?? null;
  return {
    disposition: ownership?.disposition ?? "UNKNOWN", server_instance_id: owner?.server_instance_id ?? null,
    operator_session_generation: owner?.operator_session_generation ?? null, process_id: owner?.process_id ?? null,
    process_start_time: owner?.process_start_time ?? null, lifecycle_state: owner?.lifecycle_state ?? null,
    active_mission: owner?.active_mission ? { mission_id: owner.active_mission.mission_id ?? null, mission_revision: owner.active_mission.mission_revision ?? null, run_id: owner.active_mission.run_id ?? null, result_id: owner.active_mission.result_id ?? null } : null,
    owned_children: (owner?.owned_children ?? []).map((child) => ({ process_id: child.process_id ?? null, parent_process_id: child.parent_process_id ?? null, process_start_time: child.process_start_time ?? null, executable: child.executable ?? null })),
  };
}
function sanitizeListeners(listeners) {
  return (listeners ?? []).map((listener) => ({ host: listener.host ?? listener.local_address ?? null, port: Number(listener.port ?? listener.local_port ?? 0), process_id: Number(listener.process_id ?? listener.owning_process ?? 0), evidence_source: listener.evidence_source ?? null }));
}
function exactIdentity(actual, expected, prefix) {
  for (const [key, value] of Object.entries(expected ?? {})) {
    if (value !== undefined && value !== null && actual?.[key] !== value) {
      const error = new Error(`${prefix}_${key.toUpperCase()}_MISMATCH`);
      error.classification = "DURABLE_IDENTITY_MISMATCH";
      throw error;
    }
  }
}

export class ProofHttpDiagnosticError extends Error {
  constructor(classification, stageId, method, pathname, evidence, cause = null) {
    super(`${classification}:${stageId}:${method}:${pathname}`, cause ? { cause } : undefined);
    this.name = "ProofHttpDiagnosticError";
    Object.assign(this, { classification, stage_id: stageId, method, pathname, evidence });
  }
}

export class ProofTraceRecorder {
  constructor({ evidenceRoot, host = "127.0.0.1", port, inspectOwner, inspectListeners }) {
    this.evidenceRoot = path.resolve(evidenceRoot);
    this.host = host;
    this.port = Number(port);
    this.inspectOwner = inspectOwner ?? (() => ({ disposition: "UNKNOWN", owner: null }));
    this.inspectListeners = inspectListeners ?? (() => []);
    this.fetchEvents = [];
    this.stageEvents = [];
    this.ownershipEvents = [];
    this.stoppedServerInstances = new Set();
    this.lastCompletedStage = null;
    this.failedStage = null;
    this.counter = 0;
    this.stageSequence = 0;
    this.paths = {
      stage_trace: path.join(this.evidenceRoot, "PROOF_STAGE_TRACE.json"), fetch_trace: path.join(this.evidenceRoot, "FETCH_TRACE.json"),
      ownership_trace: path.join(this.evidenceRoot, "PROCESS_OWNERSHIP_TRACE.json"), proof_result: path.join(this.evidenceRoot, "PROOF_RESULT.json"), blocker: path.join(this.evidenceRoot, "BLOCKER.json"),
    };
  }
  flush() {
    jsonWrite(this.paths.stage_trace, { schema_version: "tsf_proof_stage_trace_v2", recorded_at: nowIso(), last_completed_stage: this.lastCompletedStage, failed_stage: this.failedStage, events: this.stageEvents });
    jsonWrite(this.paths.fetch_trace, { schema_version: "tsf_proof_fetch_trace_v1", recorded_at: nowIso(), connection_policy: "CONNECTION_CLOSE_PER_REQUEST_NO_CROSS_INSTANCE_REUSE", token_or_capability_values_recorded: false, events: this.fetchEvents });
    jsonWrite(this.paths.ownership_trace, { schema_version: "tsf_proof_process_ownership_trace_v1", recorded_at: nowIso(), events: this.ownershipEvents });
  }
  startStage(stageId, details = {}) {
    const event = { sequence: ++this.stageSequence, stage_id: stageId, disposition: "ENTERED", state: "STARTED", started_at: nowIso(), completed_at: null, ...details };
    this.stageEvents.push(event); this.flush(); return event;
  }
  completeStage(event, details = {}) {
    const { disposition: resultDisposition, ...rest } = details;
    event.state = "COMPLETED"; event.disposition = "PASSED"; event.completed_at = nowIso(); Object.assign(event, rest);
    if (resultDisposition) event.result_disposition = resultDisposition;
    this.lastCompletedStage = event.stage_id; this.recalculatePrimaryFailure(); this.flush();
  }
  failStage(event, classification, details = {}, disposition = "BLOCKING_FAILURE") {
    if (!["CONTROLLED_FAILURE", "BLOCKING_FAILURE"].includes(disposition)) throw new Error("INVALID_STAGE_FAILURE_DISPOSITION");
    event.state = "FAILED"; event.disposition = disposition; event.completed_at = nowIso(); event.failure_classification = classification; Object.assign(event, details);
    this.recalculatePrimaryFailure(); this.flush();
  }
  markControlledFailure(stageId, details = {}) {
    const event = [...this.stageEvents].reverse().find((candidate) => candidate.stage_id === stageId && candidate.state === "FAILED");
    if (!event) throw new Error(`CONTROLLED_FAILURE_STAGE_NOT_FOUND:${stageId}`);
    event.disposition = "CONTROLLED_FAILURE"; Object.assign(event, details); this.recalculatePrimaryFailure(); this.flush(); return event;
  }
  recordCaution(stageId, details = {}) {
    const event = this.startStage(stageId, details); event.state = "COMPLETED"; event.disposition = "CAUTION"; event.completed_at = nowIso(); this.flush(); return event;
  }
  recordTerminalFailure(stageId, error, details = {}) {
    const event = this.startStage(stageId, { operation: "TERMINAL_FAILURE_CAPTURE" });
    this.failStage(event, error?.classification ?? "UNCAUGHT_PROOF_FAILURE", { ...details, error: errorEvidence(error) }, "BLOCKING_FAILURE");
    return event;
  }
  recalculatePrimaryFailure() {
    this.failedStage = [...this.stageEvents].reverse().find((event) => event.disposition === "BLOCKING_FAILURE")?.stage_id ?? null;
  }
  captureOwnership(label, expectedServerInstance = null, port = this.port) {
    let ownership; let listeners;
    try { ownership = this.inspectOwner(); } catch (error) { ownership = { disposition: "OWNER_INSPECTION_FAILED", owner: null, error: errorEvidence(error) }; }
    try { listeners = this.inspectListeners(port); } catch (error) { listeners = [{ inspection_error: errorEvidence(error) }]; }
    const event = { captured_at: nowIso(), label, expected_server_instance: expectedServerInstance, owner: sanitizeOwner(ownership), listeners: sanitizeListeners(listeners) };
    this.ownershipEvents.push(event); return event;
  }
  markServerStopped(serverInstanceId, details = {}) {
    this.stoppedServerInstances.add(serverInstanceId);
    const event = this.startStage(`SERVER_STOPPED_${serverInstanceId}`, { operation: "SERVER_STATE", server_instance_id: serverInstanceId });
    this.completeStage(event, { disposition: "STOPPED_LISTENER_AND_SESSION_INVALIDATED", ...details });
  }
  async httpJson({ stageId, caller, method = "GET", host = this.host, port = this.port, pathname, expectedServerInstance, expectedSessionGeneration = null, headers = {}, body = null, timeoutMs = 15_000, identities = {} }) {
    const fetchId = `fetch-${String(++this.counter).padStart(3, "0")}-${randomUUID().slice(0, 8)}`;
    const normalizedMethod = String(method).toUpperCase();
    const stage = this.startStage(stageId, { operation: "HTTP", fetch_id: fetchId, caller, method: normalizedMethod, pathname });
    const before = this.captureOwnership(`BEFORE_${stageId}`, expectedServerInstance, port);
    const event = {
      fetch_id: fetchId, proof_stage_id: stageId, caller_label: caller, method: normalizedMethod, loopback_host: host, port: Number(port), url_pathname: pathname,
      expected_server_instance: expectedServerInstance, expected_session_generation: expectedSessionGeneration,
      mission_identity: { mission_id: identities.mission_id ?? null, mission_revision: identities.mission_revision ?? null, run_id: identities.run_id ?? null, result_id: identities.result_id ?? null },
      request_body_sha256: body === null ? null : sha256Bytes(Buffer.from(JSON.stringify(body), "utf8")), timeout_ms: timeoutMs,
      started_at: nowIso(), completed_at: null, owner_state_before: before.owner, listener_state_before: before.listeners,
      http_status: null, response_content_type: null, response_body_bytes: null, response_body_sha256: null,
      outcome: "STARTED", error: null, abort_state: false, owner_state_after_failure: null, listener_state_after_failure: null,
    };
    this.fetchEvents.push(event); this.flush();
    const fail = (classification, error) => {
      const after = this.captureOwnership(`AFTER_FAILURE_${stageId}`, expectedServerInstance, port);
      Object.assign(event, { completed_at: nowIso(), outcome: "FAILED", failure_classification: classification, error: errorEvidence(error), abort_state: Boolean(classification === "FETCH_ABORT_OR_TIMEOUT" || error?.name === "AbortError" || error?.cause?.name === "AbortError"), owner_state_after_failure: after.owner, listener_state_after_failure: after.listeners });
      this.failStage(stage, classification, { fetch_id: fetchId, error: event.error });
      throw new ProofHttpDiagnosticError(classification, stageId, normalizedMethod, pathname, event, error);
    };
    if (host !== "127.0.0.1") fail("NON_LOOPBACK_HOST_DENIED", new Error("NON_LOOPBACK_HOST_DENIED"));
    if (!Number.isInteger(Number(port)) || Number(port) <= 0) fail("INVALID_PORT_DENIED", new Error("INVALID_PORT_DENIED"));
    if (typeof pathname !== "string" || !pathname.startsWith("/") || pathname.includes("#")) fail("INVALID_PATHNAME_DENIED", new Error("INVALID_PATHNAME_DENIED"));
    if (this.stoppedServerInstances.has(expectedServerInstance)) fail("HTTP_AFTER_CONFIRMED_STOP_DENIED", new Error("HTTP_AFTER_CONFIRMED_STOP_DENIED"));
    if (before.owner.disposition !== "ACTIVE_OWNER_CONFIRMED") fail("OWNER_NOT_ACTIVE_BEFORE_FETCH", new Error("OWNER_NOT_ACTIVE_BEFORE_FETCH"));
    if (before.owner.server_instance_id !== expectedServerInstance) fail("WRONG_SERVER_INSTANCE_BEFORE_FETCH", new Error("WRONG_SERVER_INSTANCE_BEFORE_FETCH"));
    if (expectedSessionGeneration && before.owner.operator_session_generation !== expectedSessionGeneration) fail("STALE_OPERATOR_SESSION_BEFORE_FETCH", new Error("STALE_OPERATOR_SESSION_BEFORE_FETCH"));
    const exactListener = before.listeners.some((listener) => listener.host === host && listener.port === Number(port) && listener.process_id === before.owner.process_id);
    if (!exactListener) fail("LISTENER_NOT_CONFIRMED_BEFORE_FETCH", new Error("LISTENER_NOT_CONFIRMED_BEFORE_FETCH"));
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(new Error("PROOF_FETCH_TIMEOUT")), timeoutMs);
    try {
      let response;
      try {
        response = await fetch(`http://${host}:${Number(port)}${pathname}`, { method: normalizedMethod, headers: { Accept: "application/json", Connection: "close", ...(body === null ? {} : { "Content-Type": "application/json" }), ...headers }, body: body === null ? undefined : JSON.stringify(body), signal: controller.signal });
      } catch (error) { fail(controller.signal.aborted ? "FETCH_ABORT_OR_TIMEOUT" : "FETCH_TRANSPORT_FAILURE", error); }
      const bytes = Buffer.from(await response.arrayBuffer());
      Object.assign(event, { http_status: response.status, response_content_type: response.headers.get("content-type"), response_body_bytes: bytes.byteLength, response_body_sha256: sha256Bytes(bytes) });
      let json = null;
      if (bytes.byteLength > 0) { try { json = JSON.parse(bytes.toString("utf8")); } catch (error) { fail("RESPONSE_BODY_PARSE_FAILURE", error); } }
      event.completed_at = nowIso(); event.outcome = "COMPLETED";
      this.completeStage(stage, { fetch_id: fetchId, http_status: response.status, response_body_sha256: event.response_body_sha256 });
      return { status: response.status, json, fetch_id: fetchId, response_body_sha256: event.response_body_sha256 };
    } finally { clearTimeout(timer); }
  }
  readDurableJson({ stageId, caller, filePath, expectedIdentity = {}, identityPath = [], evidenceKind = "CANONICAL_JSON" }) {
    if (!Array.isArray(identityPath) || identityPath.some((segment) => typeof segment !== "string" || !/^[A-Za-z0-9_]+$/.test(segment))) {
      throw new Error("DURABLE_IDENTITY_PATH_INVALID");
    }
    const stage = this.startStage(stageId, { operation: "DURABLE_READ", caller, evidence_kind: evidenceKind, path: filePath, identity_path: identityPath });
    try {
      if (!existsSync(filePath)) throw new Error("DURABLE_EVIDENCE_MISSING");
      const bytes = readFileSync(filePath); const json = JSON.parse(bytes.toString("utf8").replace(/^\uFEFF/, ""));
      const identitySource = identityPath.reduce((value, segment) => value && typeof value === "object" ? value[segment] : null, json);
      if (!identitySource || typeof identitySource !== "object" || Array.isArray(identitySource)) throw new Error("DURABLE_IDENTITY_PATH_MISSING");
      exactIdentity(identitySource, expectedIdentity, "DURABLE_EVIDENCE");
      const evidence = { path: filePath, size: bytes.byteLength, sha256: sha256Bytes(bytes), identity_path: identityPath, identity: Object.fromEntries(Object.keys(expectedIdentity).map((key) => [key, identitySource[key] ?? null])) };
      this.completeStage(stage, evidence); return { json, ...evidence };
    } catch (error) { const classification = error.classification ?? "DURABLE_READ_FAILURE"; this.failStage(stage, classification, { error: errorEvidence(error) }); throw error; }
  }
  writeFinal({ status, result = null, error = null, exitCode, knownIdentities = {}, cleanupState = {} }) {
    this.flush();
    const payload = {
      schema_version: "tsf_proof_result_v2", recorded_at: nowIso(), status, numeric_exit_code: Number.isInteger(exitCode) ? exitCode : null,
      exit_disposition: Number.isInteger(exitCode) ? "RELIABLY_OBSERVED_OR_PREDECLARED" : "EXIT_NOT_RELIABLY_OBSERVED",
      last_completed_stage: this.lastCompletedStage, failed_stage: this.failedStage, error: error ? errorEvidence(error) : null,
      known_identities: knownIdentities, cleanup_state: cleanupState, trace_paths: this.paths, proof: result,
    };
    jsonWrite(this.paths.proof_result, payload);
    if (status !== "PASS") jsonWrite(this.paths.blocker, { schema_version: "tsf_proof_blocker_v1", recorded_at: nowIso(), status: "BLOCKED", classification: error?.classification ?? "PROOF_FAILURE", last_completed_stage: this.lastCompletedStage, failed_stage: this.failedStage, error: error ? errorEvidence(error) : null, known_identities: knownIdentities, cleanup_state: cleanupState, trace_paths: this.paths });
    return payload;
  }
}
