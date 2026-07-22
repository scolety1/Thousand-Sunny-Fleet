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

function renderPreview(preview) {
  reviewedPreview = preview;
  setText("#classification", preview.classification);
  const classification = document.querySelector("#classification");
  classification.classList.toggle(
    "is-gated",
    preview.classification !== "SAFE_LOCAL_MISSION",
  );
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
  setText("#artifact-path", preview.artifact.relative_path);
  setText("#response-contract-preview", pretty({
    validation_mode: preview.result_validation_mode,
    contract: preview.exact_response_contract,
    worker_success_is_sufficient: false,
    verifier_requires_same_contract: preview.result_validation_mode === "EXACT_LITERAL_V1",
    admission_requires_same_contract: preview.result_validation_mode === "EXACT_LITERAL_V1",
    sensitivity: "Case and every byte of whitespace are significant; no normalization is performed.",
  }));

  previewResult.hidden = false;
  previewResult.scrollIntoView({ behavior: "smooth", block: "start" });
}

function renderMission(status) {
  activeMissionStatus = status;
  setText("#mission-state", status.state);
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
  setText("#mission-worker", JSON.stringify({ worker: status.worker, verifier: status.verifier, result: status.result }, null, 2));
  setText("#mission-admission", JSON.stringify({ response: status.response, prior_terminal: status.prior_terminal ? { mission_id: status.prior_terminal.mission_id, mission_revision: status.prior_terminal.mission_revision, run_id: status.prior_terminal.run_id, result_id: status.prior_terminal.result_id, state: status.prior_terminal.state, source_path: status.prior_terminal.source_path } : null, preservation: status.preservation, admission: status.admission, caveats: status.caveats }, null, 2));
  setText("#mission-response-contract", JSON.stringify({
    requested: status.requested_response,
    expected_contract: status.response_contract,
    observed: status.worker?.exact_response ?? null,
    verifier: status.verifier?.exact_response ?? null,
    admission: status.admission ? { verdict: status.admission.verdict, receipt_id: status.admission.receipt_id, decision_sha256: status.admission.admission_decision_sha256 } : null,
  }, null, 2));
  setText("#mission-authority", JSON.stringify({ authority: status.authority, duplicate_replay: status.duplicate_replay, next_action: status.next_action }, null, 2));
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
  missionSubmit.disabled = !intentConfirm.checked || !reviewedPreview;
});

missionSubmit.addEventListener("click", async () => {
  if (!reviewedPreview || !operatorSessionToken || !intentConfirm.checked) return;
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
    missionSubmit.disabled = !intentConfirm.checked || !reviewedPreview || !operatorSessionToken;
  }
});

requestInput.addEventListener("input", () => {
  requestCount.textContent = String(requestInput.value.length);
});

form.addEventListener("submit", async (event) => {
  event.preventDefault();
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
