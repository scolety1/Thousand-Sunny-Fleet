const fallbackStatus = {
  schema_version: "operator_console_sample_status_v1",
  status: {
    verdict: "GREEN",
    summary: "TSF mainline is published through controlled multi-lane foreground execution.",
    origin_main_head: "19ed02f60b897495d328b59072adcd5260d19d0a",
    current_branch: "main",
    next_recommended_milestone: "Operator Console Read-Only Skeleton V1"
  },
  merged_prs: [
    { number: 4, summary: "Kernel / role-aware lifecycle" },
    { number: 5, summary: "Pack-and-go foundations and first GREEN governed Codex worker execution" },
    { number: 6, summary: "Bounded Project Main Bot self-continuation" },
    { number: 7, summary: "Local mission queue foreground executor" },
    { number: 8, summary: "True parallel lane isolated worktree pilot" },
    { number: 9, summary: "Controlled multi-lane foreground execution" }
  ],
  cards: [
    { id: "mainline", label: "Mainline", status: "GREEN", summary: "origin/main verified", detail: "Published through PR #9." },
    { id: "queue", label: "Mission Queue", status: "GREEN", summary: "Foreground executor merged", detail: "Queue execution remains foreground-only." },
    { id: "roles", label: "Worker Roles", status: "GREEN", summary: "18 TSF roles preserved", detail: "Role permissions fail closed." },
    { id: "branches", label: "Branches", status: "GREEN", summary: "Cleanup completed", detail: "Only repo-onboarding worktree branch remains." },
    { id: "api", label: "API/HQ", status: "TIM_REQUIRED", summary: "No API transport enabled", detail: "Compressed packet builder only is a future local phase." }
  ],
  mission_queue: {
    states: ["inbox", "drafted", "preflight_pending", "approved_for_worker", "worker_running", "postrun_pending", "complete_review_only", "complete_ready_for_gate", "stopped", "archived"],
    execution_mode: "foreground_only"
  },
  worker_roles: {
    role_count: 18,
    permission_profile_count: 18
  },
  hard_gates: ["push", "merge", "deploy", "install", "migration", "secrets", "api_call", "background_runner", "product_repo_mutation", "canonical_nwr_mutation"],
  review_packets: ["source_branch_cleanup_archive_gate_20260709", "controlled_multi_lane_foreground_execution_v1", "true_parallel_lane_isolated_worktree_pilot_v1"]
};

async function loadStatus() {
  const candidates = ["data/status-summary.json", "sample-status.json"];
  for (const candidate of candidates) {
    try {
      const response = await fetch(candidate, { cache: "no-store" });
      if (response.ok) {
        return await response.json();
      }
    } catch (_error) {
      // Direct file loads may block fetch; the embedded fallback keeps the console usable.
    }
  }
  return fallbackStatus;
}

function text(id, value) {
  const element = document.getElementById(id);
  if (element) {
    element.textContent = value ?? "";
  }
}

function renderTags(id, values) {
  const element = document.getElementById(id);
  if (!element) return;
  element.replaceChildren(...(values || []).map((value) => {
    const tag = document.createElement("span");
    tag.textContent = value;
    return tag;
  }));
}

function renderCards(cards) {
  const container = document.getElementById("status-cards");
  if (!container) return;
  const nodes = (cards || []).map((card) => {
    const article = document.createElement("article");
    article.className = "status-card";
    article.dataset.status = card.status || "INFO";
    article.innerHTML = `
      <span class="badge ${card.status || "INFO"}">${card.status || "INFO"}</span>
      <strong>${card.label || card.id}</strong>
      <p>${card.summary || ""}</p>
      <p>${card.detail || ""}</p>
    `;
    return article;
  });
  container.replaceChildren(...nodes);
  text("card-count", `${nodes.length} cards`);
}

function renderList(id, values) {
  const element = document.getElementById(id);
  if (!element) return;
  const nodes = (values || []).map((value) => {
    const item = document.createElement("li");
    item.textContent = typeof value === "string" ? value : value.summary || JSON.stringify(value);
    return item;
  });
  element.replaceChildren(...nodes);
}

function renderPrs(prs) {
  const element = document.getElementById("merged-prs");
  if (!element) return;
  const nodes = (prs || []).map((pr) => {
    const item = document.createElement("div");
    item.className = "timeline-item";
    item.innerHTML = `<strong>PR #${pr.number}</strong><span>${pr.summary}</span>`;
    return item;
  });
  element.replaceChildren(...nodes);
}

function render(status) {
  const root = status.status || {};
  text("status-summary", root.summary);
  text("status-detail", `Overall verdict: ${root.verdict || "INFO"}`);
  text("origin-main", root.origin_main_head);
  text("current-branch", root.current_branch);
  text("next-milestone", root.next_recommended_milestone);
  text("queue-mode", `Execution mode: ${status.mission_queue?.execution_mode || "read_only"}`);
  text("role-count", status.worker_roles?.role_count || 0);
  text("profile-count", status.worker_roles?.permission_profile_count || 0);
  renderCards(status.cards);
  renderTags("queue-states", status.mission_queue?.states);
  renderTags("hard-gates", status.hard_gates);
  renderList("review-packets", status.review_packets);
  renderPrs(status.merged_prs);
}

loadStatus().then(render);
