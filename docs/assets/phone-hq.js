const statusUrl = "https://raw.githubusercontent.com/scolety1/Thousand-Sunny-Fleet/main/fleet/status/current.md";
const projectsUrl = "https://raw.githubusercontent.com/scolety1/Thousand-Sunny-Fleet/main/fleet/status/projects.json";

const dashboardStatus = document.getElementById("dashboardStatus");
const fleetMode = document.getElementById("fleetMode");
const updatedAt = document.getElementById("updatedAt");
const statusCaution = document.getElementById("statusCaution");
const projectGrid = document.getElementById("projectGrid");
const projectCount = document.getElementById("projectCount");
const projectSnapshotState = document.getElementById("projectSnapshotState");
const controlLinks = document.querySelectorAll(".global-controls a");
const requestUrl = controlLinks[0].href;
const todayUrl = controlLinks[1].href;
const stopUrl = controlLinks[2].href;

const fallbackProjects = [
  {
    id: "privatelens",
    name: "PrivateLens",
    statusColor: "UNKNOWN",
    branch: "unknown",
    cleanState: "unknown",
    lastCheckpointVerdict: "UNKNOWN",
    lastBuildResult: "UNKNOWN",
    pendingTaskCount: null,
    nextRecommendedAction: "Open latest status, then request desktop review.",
    note: "Project snapshot did not load; phone actions remain requests.",
  },
];

const unsafeStatusPatterns = [
  /\bACTIVE\b/i,
  /push\s*=\s*true/i,
  /\ball-fleet\b/i,
  /\bovernight\b/i,
  /\bdeploy\b/i,
  /\bstage\b/i,
  /\bcommit\b/i,
  /\bpush\b/i,
  /\binstall\b/i,
  /\bmigration\b/i,
  /runtime command binding/i,
  /phone approval/i
];

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function matchLine(markdown, label) {
  const pattern = new RegExp("^- " + escapeRegExp(label) + ":\\s*(.+)$", "mi");
  const match = markdown.match(pattern);
  return match ? match[1].trim() : "";
}

function statusNeedsCaution(markdown) {
  return unsafeStatusPatterns.some((pattern) => pattern.test(markdown));
}

function showCaution(message) {
  statusCaution.hidden = false;
  statusCaution.textContent = message;
}

function setText(element, value) {
  element.textContent = value === null || value === undefined || value === "" ? "unknown" : String(value);
}

function makeFact(label, value) {
  const item = document.createElement("div");
  const term = document.createElement("dt");
  const detail = document.createElement("dd");
  term.textContent = label;
  setText(detail, value);
  item.append(term, detail);
  return item;
}

function getStatusClass(statusColor) {
  const normalized = String(statusColor || "UNKNOWN").toUpperCase();
  if (normalized === "GREEN") return "status-dot status-dot--green";
  if (normalized === "YELLOW") return "status-dot status-dot--yellow";
  if (normalized === "RED") return "status-dot status-dot--red";
  return "status-dot";
}

function controlHref(project, key, fallback) {
  return project.controls && project.controls[key] ? project.controls[key] : fallback;
}

function renderProjects(projects, snapshotLoaded) {
  const safeProjects = Array.isArray(projects) && projects.length > 0 ? projects : fallbackProjects;
  projectCount.textContent = String(safeProjects.length);
  projectSnapshotState.textContent = snapshotLoaded ? "Generated snapshot" : "Snapshot fallback";
  projectGrid.innerHTML = "";

  for (const project of safeProjects) {
    const card = document.createElement("article");
    card.className = "project-card";

    const header = document.createElement("div");
    header.className = "project-card__header";

    const titleWrap = document.createElement("div");
    const title = document.createElement("h3");
    title.textContent = project.name || "Unknown project";
    const meta = document.createElement("span");
    meta.className = "meta";
    meta.textContent = project.note || "Public-safe status snapshot.";
    titleWrap.append(title, meta);

    const status = document.createElement("span");
    status.className = getStatusClass(project.statusColor);
    status.textContent = project.statusColor || "UNKNOWN";

    header.append(titleWrap, status);

    const facts = document.createElement("dl");
    facts.className = "project-facts";
    facts.append(
      makeFact("Branch", project.branch),
      makeFact("Clean", project.cleanState),
      makeFact("Checkpoint", project.lastCheckpointVerdict),
      makeFact("Build", project.lastBuildResult),
      makeFact("Pending", project.pendingTaskCount === null ? "unknown" : project.pendingTaskCount),
    );

    const nextAction = document.createElement("p");
    nextAction.className = "next-action";
    nextAction.textContent = project.nextRecommendedAction || "Review status before requesting work.";

    const actions = document.createElement("div");
    actions.className = "project-actions";

    const request = document.createElement("a");
    request.className = "button button--primary";
    request.href = controlHref(project, "requestTask", requestUrl);
    request.textContent = "Request task";

    const stop = document.createElement("a");
    stop.className = "button button--danger";
    stop.href = controlHref(project, "stopRequest", stopUrl);
    stop.textContent = "Stop request";

    const log = document.createElement("a");
    log.className = "button";
    log.href = controlHref(project, "logsStatus", todayUrl);
    log.textContent = "Open log";

    actions.append(request, stop, log);
    card.append(header, facts, nextAction, actions);
    projectGrid.append(card);
  }
}

async function loadProjects() {
  try {
    const response = await fetch(projectsUrl, { cache: "no-store" });
    if (!response.ok) {
      throw new Error("HTTP " + response.status);
    }

    const snapshot = await response.json();
    renderProjects(snapshot.projects, true);
  } catch (error) {
    renderProjects(fallbackProjects, false);
    showCaution("Project snapshot did not load. Use the status links; phone actions remain request-only.");
  }
}

async function loadStatus() {
  try {
    const response = await fetch(statusUrl, { cache: "no-store" });
    if (!response.ok) {
      throw new Error("HTTP " + response.status);
    }
    const markdown = await response.text();
    const caution = statusNeedsCaution(markdown);
    dashboardStatus.textContent = caution ? "Caution" : "Online";
    dashboardStatus.className = caution ? "warn" : "ok";
    fleetMode.textContent = matchLine(markdown, "Fleet mode") || "Unknown";
    updatedAt.textContent = matchLine(markdown, "Updated") || "Unknown";
    if (caution) {
      showCaution("Loaded status contains active-looking or execution-looking language. Treat it as view-only caution, use request-only rules, and do not execute from phone.");
      // Caution-only; phone actions remain requests.
    } else if (statusCaution.textContent === "Status needs caution. Phone controls create requests only.") {
      statusCaution.hidden = true;
    }
  } catch (error) {
    dashboardStatus.textContent = "Status link only";
    dashboardStatus.className = "";
    fleetMode.textContent = "Unknown";
    updatedAt.textContent = "Unknown";
    showCaution("Live status did not load. Use the status link; phone actions remain requests.");
  }
}

renderProjects(fallbackProjects, false);
loadStatus();
loadProjects();
