const form = document.querySelector("#preview-form");
const requestInput = document.querySelector("#natural-request");
const requestCount = document.querySelector("#request-count");
const previewButton = document.querySelector("#preview-button");
const requestStatus = document.querySelector("#request-status");
const previewResult = document.querySelector("#preview-result");
const intentConfirm = document.querySelector("#intent-confirm");
const missionSubmit = document.querySelector("#mission-submit");
const missionResult = document.querySelector("#mission-result");
const timConfirmation = document.querySelector("#tim-confirmation");
const timClarification = document.querySelector("#tim-clarification");
const timApprove = document.querySelector("#tim-approve");
const timDeny = document.querySelector("#tim-deny");
const timClarify = document.querySelector("#tim-clarify");
let operatorSessionToken = null;
let reviewedPreview = null;
let activeMissionStatus = null;
let reviewedPreviewCanSubmit = false;

function setText(selector, value) {
  const element = document.querySelector(selector);
  if (element) element.textContent = value;
}

function pretty(value) {
  return JSON.stringify(value, null, 2);
}

function renderDoctorStatus(report) {
  setText("#doctor-overall", report.overall_status);
  document.querySelector("#doctor-overall")?.classList.toggle("is-gated", ["UNSAFE_TO_START", "TIM_REQUIRED", "ACTION_REQUIRED"].includes(report.overall_status));
  setText("#doctor-repository", `${report.repository.head?.slice(0, 12) ?? "unknown commit"}`);
  setText("#doctor-branch", report.repository.branch ?? "detached / unavailable");
  setText("#doctor-listener", `${report.listener_state.host}:${report.listener_state.port} · ${report.listener_state.listeners.length ? "LISTENING" : "CLOSED"}`);
  setText("#doctor-owner", report.process_owner.disposition);
  setText("#doctor-child", report.active_child.length ? report.active_child.map((child) => `PID ${child.process_id}`).join(", ") : "No active owned child");
  setText("#doctor-path-budget", `${report.path_budget.maximum_path_length}/${report.path_budget.target_limit} characters`);
  setText("#doctor-queue", Object.entries(report.queue_consistency).map(([key, count]) => `${key}: ${count}`).join(" · ") || "No canonical mission records");
  setText("#doctor-recovery-counts", `TIM_REQUIRED ${report.pending_tim_required_requests} · interrupted ${report.interrupted_missions} · conflicts ${report.duplicate_replay_conflicts}`);
  setText("#doctor-next-action", report.exact_next_action);
  const unsafeChecks = report.checks.filter((item) => item.status === "UNSAFE_TO_START");
  const startupBlock = document.querySelector("#startup-block");
  startupBlock.hidden = unsafeChecks.length === 0;
  if (unsafeChecks.length) {
    setText("#startup-block-reason", unsafeChecks.map((item) => `${item.id}: ${item.next_action}`).join(" "));
    setText("#startup-block-evidence", pretty(unsafeChecks.map((item) => ({ id: item.id, status: item.status, evidence: item.evidence }))));
  }
}

async function sendRecoveryAction(item, action, button) {
  if (!operatorSessionToken) {
    setText("#recovery-message", "A fresh in-memory operator session is required.");
    return;
  }
  button.disabled = true;
  setText("#recovery-message", `Revalidating canonical evidence for ${action}…`);
  try {
    const response = await fetch("/api/v1/recovery", {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json", "X-TSF-HQ-Session": operatorSessionToken },
      body: JSON.stringify({ recovery_item_id: item.recovery_item_id, evidence_hash: item.evidence_hash, action, operator_confirmation: action }),
    });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error?.code ?? "Recovery action failed closed.");
    if (payload.mission_status) renderMission(payload.mission_status);
    if (payload.new_run) renderMission(payload.new_run);
    setText("#recovery-message", `${action}: ${payload.changed ? "receipt created" : "read-only or idempotent result"}. Canonical history remains immutable.`);
    await loadLifecycle();
  } catch (error) {
    setText("#recovery-message", error instanceof Error ? error.message : "Recovery action failed closed.");
  } finally {
    button.disabled = false;
  }
}

function renderRecoveryCenter(reconciliation) {
  const list = document.querySelector("#recovery-list");
  const fragment = document.createDocumentFragment();
  const items = reconciliation.items.filter((item) => Array.isArray(item.safe_operator_options) && item.safe_operator_options.length > 0);
  if (!items.length) {
    const empty = document.createElement("p");
    empty.textContent = "No canonical recovery decision is currently pending.";
    fragment.append(empty);
  }
  for (const item of items) {
    const card = document.createElement("article");
    const header = document.createElement("div");
    const title = document.createElement("strong");
    const status = document.createElement("code");
    const detail = document.createElement("pre");
    const warning = document.createElement("p");
    const actions = document.createElement("div");
    card.className = "recovery-card";
    header.className = "recovery-card-header";
    actions.className = "recovery-actions";
    title.textContent = `${item.mission_id} · revision ${item.mission_revision}`;
    status.textContent = item.classification;
    header.append(title, status);
    detail.textContent = pretty({ run_id: item.run_id, result_id: item.result_id, last_queue_state: item.last_known_queue_state, last_canonical_event: item.last_canonical_event, admission: item.admission_state, verifier: item.verifier_state, process: item.process_evidence, duplicate_replay: item.duplicate_replay_state, source_evidence_hash: item.evidence_hash, recommended_action: item.recommended_action, authority_required: item.authority_required });
    warning.textContent = item.immutable_history_warning;
    for (const action of item.safe_operator_options) {
      const button = document.createElement("button");
      button.type = "button";
      button.textContent = `Confirm ${action.replaceAll("_", " ")}`;
      button.addEventListener("click", () => sendRecoveryAction(item, action, button));
      actions.append(button);
    }
    card.append(header, detail, warning, actions);
    fragment.append(card);
  }
  list.replaceChildren(fragment);
}

async function loadLifecycle() {
  try {
    const [doctorResponse, recoveryResponse, stopResponse, healthResponse] = await Promise.all([
      fetch("/api/v1/doctor", { headers: { Accept: "application/json" } }),
      fetch("/api/v1/recovery", { headers: { Accept: "application/json" } }),
      fetch("/api/v1/stop-status", { headers: { Accept: "application/json" } }),
      fetch("/health", { headers: { Accept: "application/json" } }),
    ]);
    if (![doctorResponse, recoveryResponse, stopResponse, healthResponse].every((response) => response.ok)) throw new Error("Lifecycle projection failed closed.");
    const [doctor, reconciliation, stopView, health] = await Promise.all([doctorResponse.json(), recoveryResponse.json(), stopResponse.json(), healthResponse.json()]);
    renderDoctorStatus(doctor);
    renderRecoveryCenter(reconciliation);
    setText("#stop-view-output", pretty(stopView));
    document.querySelector("#demo-fixture-banner").hidden = health.lifecycle_mode !== "DEMO_FIXTURE_ONLY";
  } catch (error) {
    setText("#doctor-overall", "UNSAFE_TO_START");
    setText("#doctor-next-action", error instanceof Error ? error.message : "Lifecycle projection failed closed.");
  }
}

document.querySelector("#recovery-refresh")?.addEventListener("click", loadLifecycle);

function replaceList(selector, values, formatter = (value) => value) {
  const list = document.querySelector(selector);
  const fragment = document.createDocumentFragment();
  for (const value of values) {
    const item = document.createElement("li");
    item.textContent = formatter(value);
    fragment.append(item);
  }
  list.replaceChildren(fragment);
}

function renderStops(stops) {
  const list = document.querySelector("#stop-list");
  const fragment = document.createDocumentFragment();
  for (const stop of stops) {
    const item = document.createElement("li");
    const id = document.createElement("strong");
    const description = document.createElement("span");
    id.textContent = `${stop.id} · ${stop.check_type}`;
    description.textContent = stop.description;
    item.append(id, description);
    fragment.append(item);
  }
  list.replaceChildren(fragment);
}

function renderExplanations(explanation) {
  const sections = [
    ["Project and lane", explanation.project_lane],
    ["Classification", explanation.classification],
    ["Worker role and fit", explanation.worker_role],
    ["Model and effort", explanation.model_routing],
    ["Access proposal", explanation.access_proposal],
    ["Allowed reads", explanation.allowed_reads],
    ["Allowed writes", explanation.allowed_writes],
    ["Forbidden operations", explanation.forbidden_operations],
    ["Approvals required", explanation.approvals_required],
    ["Clarifications required", explanation.clarifications_required],
    ["Stop conditions", explanation.stop_conditions],
    ["Authority not granted", explanation.authority_not_granted],
  ];
  const list = document.querySelector("#route-explanation-list");
  const fragment = document.createDocumentFragment();

  for (const [label, detail] of sections) {
    const item = document.createElement("li");
    const heading = document.createElement("div");
    const title = document.createElement("strong");
    const reason = document.createElement("code");
    const summary = document.createElement("p");
    const bindings = document.createElement("ul");

    heading.className = "explanation-heading";
    title.textContent = label;
    reason.textContent = detail.reason_code;
    heading.append(title, reason);
    summary.className = "explanation-summary";
    summary.textContent = detail.summary;
    bindings.className = "binding-list";

    for (const binding of detail.canonical_source_bindings) {
      const bindingItem = document.createElement("li");
      const source = document.createElement("code");
      const observed =
        binding.observed_value ?? `sha256:${binding.observed_value_sha256}`;
      source.textContent = `${binding.source_path} | ${binding.source_field} | ${observed} | ${binding.assurance}`;
      bindingItem.append(source);
      bindings.append(bindingItem);
    }

    item.append(heading, summary, bindings);
    fragment.append(item);
  }
  list.replaceChildren(fragment);
}

function previewIsSubmittable(preview) {
  return preview?.classification === "SAFE_LOCAL_MISSION"
    && preview?.submission_gate === "SUBMITTABLE_AFTER_REVALIDATION"
    && preview?.scope_transformation?.queue_allowed === true
    && preview?.scope_transformation?.operator_confirmation_required === false;
}

function originalRequestFulfillmentLabel(status, disposition, validationMode) {
  if (["FULFILLED", "FULFILLED_WITH_CAVEATS"].includes(disposition)) return disposition;
  if (disposition === "PARTIAL") return "PARTIALLY_FULFILLED";
  if (disposition) return "UNFULFILLED";
  if (validationMode === "EXACT_LITERAL_V1" && ["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(status.admission?.verdict)) {
    return "FULFILLED_BY_EXACT_LITERAL_ADMISSION";
  }
  if (["REJECTED", "FAILED", "TIM_REQUIRED", "INTERRUPTED"].includes(status.state)) return "UNFULFILLED";
  return "NOT_YET_PROVEN";
}

function outcomePresentation(status) {
  const disposition = status.result?.outcome_disposition ?? status.admission?.outcome_disposition ?? null;
  const validationMode = status.result?.result_validation_mode
    ?? status.admission?.result_validation_mode
    ?? status.response_contract?.validation_mode
    ?? null;
  const exactAdmitted = validationMode === "EXACT_LITERAL_V1"
    && ["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(status.admission?.verdict);
  const label = disposition ?? (exactAdmitted ? "FULFILLED (EXACT_LITERAL_V1)" : "UNCLASSIFIED_RESULT");
  let className = "outcome-pending";
  if (label === "FULFILLED") className = "outcome-success";
  else if (label === "FULFILLED_WITH_CAVEATS" || exactAdmitted) className = "outcome-caveat";
  else if (label === "PARTIAL") className = "outcome-partial";
  else if (["BLOCKED_BY_POLICY", "NEEDS_CLARIFICATION"].includes(label) || status.state === "TIM_REQUIRED") className = "outcome-blocked";
  else if (disposition || ["REJECTED", "FAILED", "INTERRUPTED"].includes(status.state)) className = "outcome-failed";
  return {
    disposition,
    validationMode,
    label,
    className,
    originalRequest: originalRequestFulfillmentLabel(status, disposition, validationMode),
  };
}

function applyOutcomeClass(node, className) {
  if (!node) return;
  node.classList.remove("outcome-success", "outcome-caveat", "outcome-partial", "outcome-blocked", "outcome-failed", "outcome-pending");
  node.classList.add(className);
}

function renderPreview(preview) {
  reviewedPreview = preview;
  reviewedPreviewCanSubmit = previewIsSubmittable(preview);
  setText("#classification", preview.classification);
  const classification = document.querySelector("#classification");
  classification.classList.toggle(
    "is-gated",
    !reviewedPreviewCanSubmit,
  );
  setText("#preview-submission-gate", `Submission gate: ${preview.submission_gate ?? "NOT_OBSERVED"}`);
  document.querySelector("#preview-submission-gate")?.classList.toggle("is-gated", !reviewedPreviewCanSubmit);
  setText("#project-id", preview.proposed_project.project_id);
  setText("#lane-id", preview.proposed_project.lane);
  setText("#worker-role", preview.proposed_worker_role.role_name);
  setText("#worker-purpose", preview.proposed_worker_role.purpose);
  setText("#model-alias", preview.model_routing.stable_alias);
  setText(
    "#model-effort",
    `${preview.model_routing.reasoning_effort} · ${preview.model_routing.resolved_model} · ${preview.model_routing.assurance}`,
  );

  setText("#access-level", preview.access_proposal.access_level);
  setText(
    "#access-scope",
    `${preview.access_proposal.network_scope} | ${preview.access_proposal.execution_scope}`,
  );
  setText("#access-rationale", preview.access_proposal.rationale);

  const approvals =
    preview.required_approvals.length > 0
      ? preview.required_approvals.map(
          (approval) => `${approval.gate}: ${approval.status}`,
        )
      : [
          "No exact approval is identified by this preview. A reviewed preview may be submitted as a bounded governed read-only mission; submission is not approval and worker completion is not admission.",
        ];
  replaceList("#approval-list", approvals);
  replaceList(
    "#clarification-list",
    preview.clarifications.length > 0
      ? preview.clarifications
      : ["No clarification is identified by this preview."],
  );
  replaceList("#read-list", preview.allowed_reads);
  replaceList("#write-list", preview.allowed_writes);
  replaceList("#forbidden-list", preview.forbidden_actions);
  renderStops(preview.stop_conditions);
  renderExplanations(preview.route_explanation);
  setText("#preview-original-intent", pretty({
    requested_goal: preview.original_operator_intent?.requested_goal ?? null,
    requested_output_or_deliverable: preview.original_operator_intent?.requested_output_or_deliverable ?? null,
    explicitly_requested_operations: preview.original_operator_intent?.explicitly_requested_operations ?? [],
    authority_bearing_operations: preview.original_operator_intent?.authority_bearing_operations ?? [],
    requested_access: preview.original_operator_intent?.requested_access ?? null,
    repository_target: preview.original_operator_intent?.repository_target ?? null,
    worktree_target: preview.original_operator_intent?.worktree_target ?? null,
    ambiguity_status: preview.original_operator_intent?.ambiguity_status ?? null,
    original_intent_identity_sha256: preview.original_operator_intent?.original_intent_identity_sha256 ?? null,
  }));
  setText("#preview-scope-transformation", pretty({
    original_requested_goal: preview.scope_transformation?.original_requested_goal ?? null,
    original_requested_operations: preview.scope_transformation?.original_requested_operations ?? [],
    authorized_mission_goal: preview.scope_transformation?.actual_mission_goal ?? preview.proposed_mission_goal ?? null,
    authorized_operations: preview.scope_transformation?.actual_operations ?? preview.proposed_operations ?? [],
    proposed_reduced_alternative: preview.scope_transformation?.proposed_mission_goal ?? null,
    classification: preview.scope_transformation?.classification ?? null,
    material_scope_change: preview.scope_transformation?.material_scope_change ?? null,
    denied_authority: preview.scope_transformation?.denied_authority ?? [],
    what_will_not_be_performed: preview.scope_transformation?.what_will_not_be_performed ?? [],
    operator_confirmation_required: preview.scope_transformation?.operator_confirmation_required ?? null,
    operator_confirmation_observed: preview.scope_transformation?.operator_confirmation_observed ?? null,
    accepting_alternative_creates_different_mission: preview.scope_transformation?.accepting_alternative_creates_different_mission ?? null,
    queue_allowed: preview.scope_transformation?.queue_allowed ?? null,
    detached_head: preview.scope_transformation?.detached_head ?? null,
    exact_next_action: preview.scope_transformation?.exact_next_action ?? null,
    scope_transformation_identity_sha256: preview.scope_transformation?.scope_transformation_identity_sha256 ?? null,
  }));
  setText("#preview-execution-boundary", pretty({
    artifact_kind: preview.artifact?.record_kind ?? "hq_dispatch_route_preview",
    submission_gate: preview.submission_gate ?? null,
    preview_only: preview.authority?.preview_only ?? null,
    mission_created: false,
    queue_created: false,
    worker_created: false,
    verifier_created: false,
    admission_created: false,
    submission_is_operator_confirmation: false,
  }));
  setText("#artifact-path", preview.artifact.relative_path);
  setText("#response-contract-preview", pretty({
    validation_mode: preview.result_validation_mode,
    contract: preview.exact_response_contract,
    task_completion_contract: preview.task_completion_contract,
    worker_success_is_sufficient: false,
    verifier_requires_canonical_contract: true,
    admission_requires_canonical_contract: true,
    exact_literal_sensitivity: preview.result_validation_mode === "EXACT_LITERAL_V1"
      ? "Case and every byte of whitespace are significant; no normalization is performed."
      : "Not applicable to GENERAL_RESULT_V2.",
  }));
  intentConfirm.checked = false;
  intentConfirm.disabled = !reviewedPreviewCanSubmit;
  missionSubmit.disabled = true;
  setText(
    "#governed-submit-status",
    reviewedPreviewCanSubmit
      ? "Eligible for submission revalidation. Submission grants no approval."
      : `Blocked before execution. No queue, worker, verifier, or admission exists. ${preview.scope_transformation?.exact_next_action ?? "Operator authority decision required."}`,
  );
  document.querySelector(".governed-submit")?.classList.toggle("is-gated", !reviewedPreviewCanSubmit);

  previewResult.hidden = false;
  previewResult.scrollIntoView({ behavior: "smooth", block: "start" });
}

function renderMission(status) {
  activeMissionStatus = status;
  const presentation = outcomePresentation(status);
  setText("#mission-state", `Mission state: ${status.state}`);
  document.querySelector("#mission-state")?.classList.toggle("is-gated", ["REJECTED", "FAILED", "TIM_REQUIRED", "INTERRUPTED"].includes(status.state));
  setText("#mission-outcome", `Outcome: ${presentation.label}`);
  applyOutcomeClass(document.querySelector("#mission-outcome"), presentation.className);
  applyOutcomeClass(missionResult, presentation.className);
  missionResult.dataset.outcome = presentation.label;
  setText("#mission-identity", JSON.stringify({
    mission_id: status.mission_id,
    mission_revision: status.mission_revision,
    run_id: status.run_id,
    result_id: status.result_id,
    canonical_source_record: status.canonical_source_record,
    source_path: status.source_path,
    assurance: status.assurance,
  }, null, 2));
  setText("#mission-route", JSON.stringify({ route: status.route, access: status.access, queue_state: status.queue_state }, null, 2));
  setText("#mission-original-intent", pretty({
    requested_goal: status.original_operator_intent?.requested_goal ?? status.requested_response?.natural_request ?? null,
    requested_output_or_deliverable: status.original_operator_intent?.requested_output_or_deliverable ?? null,
    requested_operations: status.original_operator_intent?.explicitly_requested_operations ?? [],
    authority_bearing_operations: status.original_operator_intent?.authority_bearing_operations ?? [],
    requested_access: status.original_operator_intent?.requested_access ?? null,
    repository_target: status.original_operator_intent?.repository_target ?? null,
    worktree_target: status.original_operator_intent?.worktree_target ?? null,
    original_intent_identity_sha256: status.original_operator_intent?.original_intent_identity_sha256 ?? status.result?.original_intent_identity_sha256 ?? null,
  }));
  setText("#mission-scope-transformation", pretty({
    original_requested_goal: status.scope_transformation?.original_requested_goal ?? null,
    original_requested_operations: status.scope_transformation?.original_requested_operations ?? [],
    authorized_mission_goal: status.scope_transformation?.actual_mission_goal ?? status.scope_transformation?.proposed_mission_goal ?? null,
    authorized_operations: status.scope_transformation?.actual_operations ?? status.scope_transformation?.proposed_operations ?? [],
    material_scope_change: status.scope_transformation?.material_scope_change ?? null,
    transformation_classification: status.scope_transformation?.classification ?? null,
    denied_authority: status.scope_transformation?.denied_authority ?? [],
    what_will_not_be_performed: status.scope_transformation?.what_will_not_be_performed ?? [],
    operator_confirmation_required: status.scope_transformation?.operator_confirmation_required ?? null,
    operator_confirmation_observed: status.scope_transformation?.operator_confirmation_observed ?? null,
    exact_next_action: status.scope_transformation?.exact_next_action ?? status.next_action,
    scope_transformation_identity_sha256: status.scope_transformation?.scope_transformation_identity_sha256 ?? status.result?.scope_transformation_identity_sha256 ?? null,
  }));
  setText("#mission-worker", pretty({
    worker_transport_status: status.result?.transport_status ?? status.worker?.transport_status ?? null,
    lifecycle_worker_status: status.worker?.status ?? null,
    transport_completed_is_not_fulfillment: true,
    child_exited: status.worker?.child_exited ?? null,
    worker_claim: status.result?.worker_claim ?? status.worker?.claim ?? null,
    worker_identity: status.worker ? {
      thread_id: status.worker.thread_id,
      turn_id: status.worker.turn_id,
      process_id: status.worker.process_id,
      model: status.worker.model,
      effort: status.worker.effort,
    } : null,
  }));
  setText("#mission-fulfillment", pretty({
    canonical_validation_mode: presentation.validationMode,
    canonical_outcome_disposition: presentation.disposition,
    canonical_semantic_status: status.result?.semantic_status ?? null,
    original_request_fulfillment: presentation.originalRequest,
    observed_deliverables: status.result?.observed_deliverables ?? [],
    missing_deliverables: status.result?.missing_deliverables ?? [],
    outcome_evidence: status.result?.outcome_evidence ?? [],
    worker_message_alone_is_fulfillment: false,
    nonempty_response_alone_is_fulfillment: false,
    source: status.result?.durable_result_path ?? null,
  }));
  setText("#mission-verifier", pretty({
    verifier: status.verifier,
    canonical_verifier_result: status.verifier?.verdict ?? "NOT_OBSERVED",
    verifier_general_result: status.verifier?.general_result_evidence ?? null,
  }));
  setText("#mission-admission", pretty({
    admission_status: status.admission?.verdict ?? "NOT_ADMITTED",
    admission: status.admission,
    not_admitted_reason: status.admission ? null : (status.result?.outcome_evidence?.length ? status.result.outcome_evidence : [status.explanation]),
    preservation: status.preservation,
    response: status.response,
    prior_terminal: status.prior_terminal ? { mission_id: status.prior_terminal.mission_id, mission_revision: status.prior_terminal.mission_revision, run_id: status.prior_terminal.run_id, result_id: status.prior_terminal.result_id, state: status.prior_terminal.state, source_path: status.prior_terminal.source_path } : null,
    caveats: status.caveats,
  }));
  setText("#mission-deliverables", pretty({
    required_task: status.task_completion_contract?.required_task ?? null,
    required_deliverables: status.task_completion_contract?.required_deliverables ?? [],
    observed_deliverables: status.result?.observed_deliverables ?? [],
    missing_deliverables: status.result?.missing_deliverables ?? [],
    partial_completion_allowed: status.task_completion_contract?.partial_completion_allowed ?? null,
    accepted_dispositions: status.task_completion_contract?.accepted_dispositions ?? [],
    exact_next_action: status.next_action,
  }));
  setText("#mission-response-contract", JSON.stringify({
    requested: status.requested_response,
    expected_contract: status.response_contract,
    task_completion_contract: status.task_completion_contract,
    observed: status.worker?.exact_response ?? null,
    verifier: status.verifier?.exact_response ?? null,
    admission: status.admission ? { verdict: status.admission.verdict, receipt_id: status.admission.receipt_id, decision_sha256: status.admission.admission_decision_sha256 } : null,
  }, null, 2));
  setText("#mission-authority", pretty({
    originally_requested_authority: status.original_operator_intent?.authority_bearing_operations ?? [],
    denied_authority: status.scope_transformation?.denied_authority ?? [],
    authority: status.authority,
    duplicate_replay: status.duplicate_replay,
    exact_next_action: status.next_action,
  }));
  const tim = document.querySelector("#tim-required");
  tim.hidden = !status.tim_request;
  const responseTypes = status.tim_request?.response_types ?? [];
  document.querySelector("#tim-approval-controls").hidden = !responseTypes.some((value) => ["APPROVE_EXACT_REQUEST", "DENY_REQUEST"].includes(value));
  document.querySelector("#tim-clarification-controls").hidden = !responseTypes.includes("PROVIDE_CLARIFICATION");
  timApprove.hidden = !responseTypes.includes("APPROVE_EXACT_REQUEST");
  timDeny.hidden = !responseTypes.includes("DENY_REQUEST");
  if (status.tim_request) setText("#tim-request", JSON.stringify(status.tim_request, null, 2));
  missionResult.hidden = false;
  missionResult.scrollIntoView({ behavior: "smooth", block: "start" });
}

async function sendTimResponse(responseType) {
  const request = activeMissionStatus?.tim_request;
  if (!request || !operatorSessionToken) return;
  for (const control of [timApprove, timDeny, timClarify]) control.disabled = true;
  setText("#tim-response-status", "Revalidating the canonical terminal request…");
  try {
    const responsePayload = responseType === "PROVIDE_CLARIFICATION" ? timClarification.value : null;
    const response = await fetch(`/api/v1/missions/${encodeURIComponent(request.mission_id)}/tim-response`, {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json", "X-TSF-HQ-Session": operatorSessionToken },
      body: JSON.stringify({
        mission_id: request.mission_id,
        mission_revision: request.mission_revision,
        run_id: request.run_id,
        result_id: request.result_id,
        tim_required_request_id: request.request_id,
        request_evidence_sha256: request.evidence_sha256,
        response_id: request.response_id,
        response_type: responseType,
        operator_confirmation: timConfirmation.value,
        response_payload: responsePayload,
      }),
    });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error?.code ?? "TIM response failed closed.");
    renderMission(payload);
    setText("#tim-response-status", payload.explanation);
  } catch (error) {
    setText("#tim-response-status", error instanceof Error ? error.message : "TIM response failed closed.");
  } finally {
    for (const control of [timApprove, timDeny, timClarify]) control.disabled = false;
  }
}

timApprove.addEventListener("click", () => sendTimResponse("APPROVE_EXACT_REQUEST"));
timDeny.addEventListener("click", () => sendTimResponse("DENY_REQUEST"));
timClarify.addEventListener("click", () => sendTimResponse("PROVIDE_CLARIFICATION"));

async function acquireSession() {
  const response = await fetch("/api/v1/session", {
    method: "POST",
    headers: { Accept: "application/json", "Content-Type": "application/json" },
    body: "{}",
  });
  if (!response.ok) throw new Error("Local operator session acquisition failed closed.");
  const payload = await response.json();
  operatorSessionToken = payload.session_token;
}

function renderRegistryProjection(projection) {
  const sources = projection.registry_sources;
  const staleSources = sources.filter(
    (source) => source.freshness === "SOURCE_HASH_MISMATCH",
  );
  setText("#source-count", `${sources.length} fixed sources`);
  setText(
    "#registry-status",
    staleSources.length === 0 ? "Sources current" : "Source mismatch",
  );
  document
    .querySelector("#registry-status")
    .classList.toggle("is-gated", staleSources.length > 0);

  const sourceList = document.querySelector("#source-list");
  const fragment = document.createDocumentFragment();
  for (const source of sources) {
    const item = document.createElement("li");
    const path = document.createElement("code");
    const freshness = document.createElement("span");
    path.textContent = source.path;
    freshness.textContent = source.freshness.replaceAll("_", " ");
    freshness.classList.toggle(
      "is-stale",
      source.freshness === "SOURCE_HASH_MISMATCH",
    );
    item.append(path, freshness);
    fragment.append(item);
  }
  sourceList.replaceChildren(fragment);

  const skills = projection.skills.registry.skills;
  const localSkills = skills.filter(
    (skill) => skill.locally_present_definition,
  );
  setText("#skill-count", String(skills.length));
  setText(
    "#skill-detail",
    `${skills.length} documented · ${localSkills.length} locally present definitions`,
  );

  const actions = projection.setup_actions.registry.actions;
  const enabledActions = actions.filter((action) => action.execution_enabled);
  setText("#action-count", String(actions.length));
  setText(
    "#action-detail",
    `${enabledActions.length} enabled: ${enabledActions.map((action) => action.label).join(", ")}`,
  );

  const restrictions = projection.milestone_restrictions;
  setText("#boundary-state", restrictions.posture);
  setText(
    "#boundary-detail",
    "Reviewed route previews may be submitted as bounded governed TSF-local read-only missions through canonical mission, queue, lifecycle, verifier, preservation, and admission controls. Canonical TIM_REQUIRED requests accept only exact approval, denial, or bounded clarification responses. A response may create a new governed revision; the prior worker is never resumed. Arbitrary repositories and general commands; plugins, credentials, deployment, push, merge, production access, and expanded authority remain unavailable. Submission is not approval; the canonical approval ledger controls approval and the canonical admission receipt is terminal truth.",
  );
}

async function loadRegistries() {
  try {
    const response = await fetch("/api/v1/registries", {
      headers: { Accept: "application/json" },
    });
    if (!response.ok) throw new Error("registry request failed");
    renderRegistryProjection(await response.json());
  } catch {
    setText("#registry-status", "Registry read failed closed");
    document.querySelector("#registry-status").classList.add("is-gated");
  }
}

intentConfirm.addEventListener("change", () => {
  missionSubmit.disabled = !intentConfirm.checked || !reviewedPreview || !reviewedPreviewCanSubmit;
});

missionSubmit.addEventListener("click", async () => {
  if (!reviewedPreview || !operatorSessionToken || !intentConfirm.checked || !reviewedPreviewCanSubmit) return;
  missionSubmit.disabled = true;
  setText("#mission-message", "Canonical mission preparation and foreground execution are running…");
  try {
    const response = await fetch("/api/v1/missions", {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json", "X-TSF-HQ-Session": operatorSessionToken },
      body: JSON.stringify({
        natural_request: requestInput.value,
        preview_id: reviewedPreview.preview_id,
        preview_sha256: reviewedPreview.preview_sha256,
        request_hash: reviewedPreview.request_hash,
        intent: "CREATE_GOVERNED_MISSION",
        submission_id: reviewedPreview.submission_id,
      }),
    });
    const payload = await response.json();
    if (!response.ok) throw new Error(payload.error?.code ?? "Mission submission failed closed.");
    renderMission(payload);
    setText("#mission-message", payload.explanation);
  } catch (error) {
    setText("#mission-message", error instanceof Error ? error.message : "Mission submission failed closed.");
  } finally {
    missionSubmit.disabled = !intentConfirm.checked || !reviewedPreview || !operatorSessionToken || !reviewedPreviewCanSubmit;
  }
});

requestInput.addEventListener("input", () => {
  requestCount.textContent = String(requestInput.value.length);
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  reviewedPreview = null;
  reviewedPreviewCanSubmit = false;
  intentConfirm.checked = false;
  intentConfirm.disabled = true;
  missionSubmit.disabled = true;
  requestStatus.classList.remove("is-error");
  requestStatus.textContent = "Reading canonical route sources…";
  previewButton.disabled = true;

  try {
    const response = await fetch("/api/v1/route-preview", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-TSF-HQ-Session": operatorSessionToken,
      },
      body: JSON.stringify({ natural_request: requestInput.value }),
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(payload.error?.message ?? "Route preview failed closed.");
    }
    renderPreview(payload);
    requestStatus.textContent =
      "Preview created. No mission, queue, approval, or worker action occurred.";
  } catch (error) {
    requestStatus.classList.add("is-error");
    requestStatus.textContent =
      error instanceof Error ? error.message : "Route preview failed closed.";
  } finally {
    previewButton.disabled = false;
  }
});

Promise.all([loadRegistries(), acquireSession(), loadLifecycle()]).catch(() => {
  requestStatus.classList.add("is-error");
  requestStatus.textContent = "Local operator session initialization failed closed.";
  previewButton.disabled = true;
});
