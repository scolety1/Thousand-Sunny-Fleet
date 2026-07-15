const form = document.querySelector("#preview-form");
const requestInput = document.querySelector("#natural-request");
const requestCount = document.querySelector("#request-count");
const previewButton = document.querySelector("#preview-button");
const requestStatus = document.querySelector("#request-status");
const previewResult = document.querySelector("#preview-result");
const intentConfirm = document.querySelector("#intent-confirm");
const missionSubmit = document.querySelector("#mission-submit");
const missionResult = document.querySelector("#mission-result");
let operatorSessionToken = null;
let reviewedPreview = null;
let activeMissionStatus = null;

function setText(selector, value) {
  const element = document.querySelector(selector);
  if (element) element.textContent = value;
}

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
          "No exact approval is identified by this preview. Future mission execution remains disabled and separately gated.",
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
  setText("#mission-admission", JSON.stringify({ preservation: status.preservation, admission: status.admission, caveats: status.caveats }, null, 2));
  setText("#mission-authority", JSON.stringify({ authority: status.authority, duplicate_replay: status.duplicate_replay, next_action: status.next_action }, null, 2));
  const tim = document.querySelector("#tim-required");
  tim.hidden = !status.tim_request;
  if (status.tim_request) setText("#tim-request", JSON.stringify(status.tim_request, null, 2));
  missionResult.hidden = false;
  missionResult.scrollIntoView({ behavior: "smooth", block: "start" });
}

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
    "Plugins, credentials, environment enumeration, live AI services, external repositories, mission submission, and mission execution are unavailable.",
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

Promise.all([loadRegistries(), acquireSession()]).catch(() => {
  requestStatus.classList.add("is-error");
  requestStatus.textContent = "Local operator session initialization failed closed.";
  previewButton.disabled = true;
});
