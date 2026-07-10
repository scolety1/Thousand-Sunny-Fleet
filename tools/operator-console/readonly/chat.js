const hardApprovalActions = [
  "push",
  "merge",
  "deploy",
  "install_packages",
  "migration",
  "secrets",
  "api_call",
  "codex_worker_execution",
  "background_runner",
  "product_repo_mutation",
  "canonical_nwr_mutation"
];

const defaultDraft = {
  schema_version: "operator_console_mission_draft_preview_v1",
  classification: "SAFE_DRAFT_ONLY",
  requested_by: "tim",
  project_id: "tsf-operator-console",
  worker_role: "documentation_worker",
  natural_request: "",
  allowed_reads: ["docs/hq", "fleet/control", "tools/operator-console/readonly"],
  allowed_writes: ["tests/fixtures/fleet/operator-console/draft-missions"],
  forbidden_actions: hardApprovalActions,
  execution_enabled: false,
  next_safe_action: "Copy draft for local review. Execution remains disabled in the browser."
};

let currentDraft = { ...defaultDraft };

function classifyMessage(text) {
  const unsafePattern = /\b(force|bypass|disable checks|ignore guardrails|delete safety)\b/i;
  const approvalPattern = /\b(push|merge|deploy|install|migration|secret|api|codex exec|worker execution|background|daemon|scheduler|product repo|canonical nwr)\b/i;
  const hqPattern = /\b(architecture switch|conflicting reports|source truth|ranking|formula|model promotion|app wiring|hidden sort)\b/i;
  if (unsafePattern.test(text)) return "BLOCKED_UNSAFE";
  if (approvalPattern.test(text)) return "NEEDS_TIM_APPROVAL";
  if (hqPattern.test(text)) return "NEEDS_CHATGPT_HQ";
  return "SAFE_DRAFT_ONLY";
}

function roleForMessage(text) {
  if (/\btest|verify|validation\b/i.test(text)) return "tester_worker";
  if (/\baudit|review|risk\b/i.test(text)) return "auditor_worker";
  if (/\bbuild|create|implement\b/i.test(text)) return "builder_worker";
  return "documentation_worker";
}

function makeDraft(text) {
  const classification = classifyMessage(text);
  return {
    ...defaultDraft,
    classification,
    worker_role: roleForMessage(text),
    natural_request: text,
    approval_required: classification !== "SAFE_DRAFT_ONLY",
    next_safe_action: classification === "SAFE_DRAFT_ONLY"
      ? "Copy the draft or generate it with the local dry-run helper. Do not execute from the browser."
      : "Stop and request Tim approval or an HQ packet before any execution."
  };
}

function addMessage(speaker, text) {
  const list = document.getElementById("message-list");
  const item = document.createElement("div");
  item.className = `message ${speaker}`;
  item.innerHTML = `<strong>${speaker === "tim" ? "Tim" : "Project Main Bot"}</strong><p>${text}</p>`;
  list.appendChild(item);
  list.scrollTop = list.scrollHeight;
}

function renderDraft(draft) {
  currentDraft = draft;
  const verdict = document.getElementById("chat-verdict");
  verdict.textContent = draft.classification;
  verdict.className = `badge ${draft.classification === "SAFE_DRAFT_ONLY" ? "GREEN" : draft.classification === "BLOCKED_UNSAFE" ? "RED" : "TIM_REQUIRED"}`;
  document.getElementById("draft-preview").textContent = JSON.stringify(draft, null, 2);
  document.getElementById("next-safe-action").textContent = draft.next_safe_action;
  const approvalList = document.getElementById("approval-list");
  approvalList.replaceChildren(...hardApprovalActions.map((action) => {
    const item = document.createElement("li");
    item.textContent = action;
    return item;
  }));
}

function botReply(draft) {
  if (draft.classification === "SAFE_DRAFT_ONLY") {
    return `I can prepare a ${draft.worker_role} draft preview. Execution stays disabled here.`;
  }
  if (draft.classification === "NEEDS_CHATGPT_HQ") {
    return "This needs a compressed HQ packet before any strategic decision. No API call is made here.";
  }
  if (draft.classification === "NEEDS_TIM_APPROVAL") {
    return "This crosses a Tim approval gate. I will preserve the draft and stop before execution.";
  }
  return "This request is unsafe for the console. I will block it and preserve the reason.";
}

async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
  } catch (_error) {
    const holder = document.createElement("textarea");
    holder.value = text;
    document.body.appendChild(holder);
    holder.select();
    document.execCommand("copy");
    holder.remove();
  }
}

async function loadJson(path, fallback) {
  try {
    const response = await fetch(path, { cache: "no-store" });
    if (response.ok) return await response.json();
  } catch (_error) {
    return fallback;
  }
  return fallback;
}

document.getElementById("chat-form").addEventListener("submit", (event) => {
  event.preventDefault();
  const message = document.getElementById("tim-message").value.trim();
  if (!message) return;
  addMessage("tim", message);
  const draft = makeDraft(message);
  renderDraft(draft);
  addMessage("project_main_bot", botReply(draft));
});

document.getElementById("copy-draft").addEventListener("click", () => {
  copyText(JSON.stringify(currentDraft, null, 2));
});

document.getElementById("copy-hq").addEventListener("click", () => {
  const prompt = [
    "TSF compressed HQ prompt preview.",
    `Classification: ${currentDraft.classification}`,
    `Requested role: ${currentDraft.worker_role}`,
    `Decision requested: confirm safe next action for draft-only mission.`,
    "No API call has been made."
  ].join("\\n");
  copyText(prompt);
});

document.getElementById("play-sample").addEventListener("click", async () => {
  const sample = await loadJson("chat-sample-conversation.json", { conversation: [] });
  document.getElementById("message-list").replaceChildren();
  for (const turn of sample.conversation || []) {
    addMessage(turn.speaker === "tim" ? "tim" : "project_main_bot", turn.text);
  }
});

loadJson("mission-draft-preview.sample.json", defaultDraft).then(renderDraft);
