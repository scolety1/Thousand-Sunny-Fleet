const researchHardGates = [
  "automatic_deep_research_submission",
  "ChatGPT/OpenAI_API_call",
  "paid_external_API",
  "secrets_or_credentials",
  "product_repo_scope",
  "canonical_NWR_scope",
  "normal_NWR_packet_read",
  "background_runner",
  "research_treated_as_approval"
];

const defaultResearchPlan = {
  schema_version: "operator_console_research_plan_preview_v1",
  research_project_id: "agent-of-agents-architecture-research-v1",
  classification: "MULTI_ANGLE_DEEP_RESEARCH",
  prompt_count: 3,
  advisory_only: true,
  api_called: false,
  auto_submission_enabled: false,
  prompts: [
    "architecture-supervisor-hierarchy",
    "research-intake-import-export",
    "operator-console-supervision-and-risk"
  ],
  next_safe_action: "Create local packet only. Tim separately submits external Deep Research if desired."
};

const defaultCards = [
  {
    id: "idea-inbox",
    label: "Idea Inbox",
    status: "GREEN",
    summary: "Local idea capture is draft-only.",
    detail: "Original wording is preserved and classified before any export."
  },
  {
    id: "deep-research-export",
    label: "Deep Research Export",
    status: "TIM_REQUIRED",
    summary: "Packets can be prepared, not submitted.",
    detail: "External submission remains a Tim/HQ gate."
  },
  {
    id: "research-import",
    label: "Report Import",
    status: "GREEN",
    summary: "Reports are hashed, preserved, and mapped to prompt IDs.",
    detail: "Unmatched or unsafe reports are quarantined by local tooling."
  },
  {
    id: "synthesis",
    label: "Synthesis",
    status: "GREEN",
    summary: "Recommendations are advisory only.",
    detail: "Synthesis cannot approve push, merge, API, background, or source-truth changes."
  }
];

let currentResearchPlan = { ...defaultResearchPlan };

function classifyIdea(text) {
  if (/\b(secret|credential|api key|normal nwr|canonical nwr|product repo|privatelens)\b/i.test(text)) {
    return "BLOCKED_UNSAFE";
  }
  if (text.trim().length < 24 || /\b(research stuff|make it better)\b/i.test(text)) {
    return "NEEDS_TIM_DESIGN_INPUT_FIRST";
  }
  if (/\b(agent|architecture|deep research|import|export|operator console)\b/i.test(text)) {
    return "MULTI_ANGLE_DEEP_RESEARCH";
  }
  return "SINGLE_DEEP_RESEARCH_RUN";
}

function makeResearchPlan(text) {
  const classification = classifyIdea(text);
  const promptCount = classification === "MULTI_ANGLE_DEEP_RESEARCH" ? 3 : classification === "SINGLE_DEEP_RESEARCH_RUN" ? 1 : 0;
  return {
    ...defaultResearchPlan,
    classification,
    prompt_count: promptCount,
    original_wording: text,
    advisory_only: true,
    api_called: false,
    auto_submission_enabled: false,
    next_safe_action: promptCount > 0
      ? "Prepare a local export package. Do not submit externally from the console."
      : "Stop for Tim clarification before export."
  };
}

function renderResearchCards(cards) {
  const container = document.getElementById("research-cards");
  const nodes = (cards || []).map((card) => {
    const item = document.createElement("article");
    item.className = "research-card";
    item.dataset.status = card.status || "INFO";
    item.innerHTML = `
      <span class="badge ${card.status || "INFO"}">${card.status || "INFO"}</span>
      <strong>${card.label || card.id}</strong>
      <p>${card.summary || ""}</p>
      <p>${card.detail || ""}</p>
      <code>${card.id || ""}</code>
    `;
    return item;
  });
  container.replaceChildren(...nodes);
}

function renderHardGates() {
  const gates = document.getElementById("research-hard-gates");
  gates.replaceChildren(...researchHardGates.map((gate) => {
    const item = document.createElement("span");
    item.textContent = gate;
    return item;
  }));
}

function renderResearchPlan(plan) {
  currentResearchPlan = plan;
  document.getElementById("research-preview").textContent = JSON.stringify(plan, null, 2);
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

document.getElementById("idea-form").addEventListener("submit", (event) => {
  event.preventDefault();
  const text = document.getElementById("idea-text").value.trim();
  if (!text) return;
  renderResearchPlan(makeResearchPlan(text));
});

document.getElementById("load-idea-sample").addEventListener("click", async () => {
  const sample = await loadJson("idea-capture.sample.json", { idea_text: "" });
  document.getElementById("idea-text").value = sample.idea_text || "";
  renderResearchPlan(makeResearchPlan(sample.idea_text || ""));
});

document.getElementById("copy-research-plan").addEventListener("click", () => {
  copyText(JSON.stringify(currentResearchPlan, null, 2));
});

document.getElementById("copy-deep-research-prompt").addEventListener("click", () => {
  const prompt = [
    "TSF Deep Research packet preview",
    `Research project: ${currentResearchPlan.research_project_id}`,
    `Classification: ${currentResearchPlan.classification}`,
    `Prompt count: ${currentResearchPlan.prompt_count}`,
    "No API call has been made. External submission requires Tim."
  ].join("\n");
  copyText(prompt);
});

loadJson("research-plan.sample.json", defaultResearchPlan).then(renderResearchPlan);
loadJson("research-inbox.sample.json", { cards: defaultCards }).then((data) => renderResearchCards(data.cards || defaultCards));
renderHardGates();
