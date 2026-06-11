const statusUrl = "https://raw.githubusercontent.com/scolety1/Thousand-Sunny-Fleet/main/fleet/status/current.md";

const dashboardStatus = document.getElementById("dashboardStatus");
const fleetMode = document.getElementById("fleetMode");
const updatedAt = document.getElementById("updatedAt");
const statusCaution = document.getElementById("statusCaution");
const projectGrid = document.getElementById("projectGrid");
const projectCount = document.getElementById("projectCount");
const controlLinks = document.querySelectorAll(".global-controls a");
const requestUrl = controlLinks[0].href;
const todayUrl = controlLinks[1].href;
const stopUrl = controlLinks[2].href;

const projects = [
  { name: "Bottlelight", type: "marketing-site", risk: "local-only", repo: "C:\\Dev\\cellar-beverage-list" },
  { name: "CursorPets", type: "sandbox-prototype", risk: "sandbox", repo: "C:\\Dev\\cursor-pets" },
  { name: "EasyLife", type: "full-stack-web", risk: "production-adjacent", repo: "C:\\Dev\\easylifehq.github.io" },
  { name: "EventBook", type: "marketing-site", risk: "local-only", repo: "C:\\Dev\\cellar-private-events" },
  { name: "FinanceDecisionLab", type: "ai-workflow", risk: "sandbox", repo: "C:\\Dev\\personal-finance-decision-lab" },
  { name: "ForecastLab", type: "ai-workflow", risk: "sandbox", repo: "C:\\Dev\\forecast-lab" },
  { name: "LifeCapacity", type: "ai-workflow", risk: "sandbox", repo: "C:\\Dev\\life-capacity-optimizer" },
  { name: "LineupLab", type: "marketing-site", risk: "local-only", repo: "C:\\Dev\\cellar-training-hub" },
  { name: "NinersWarRoom", type: "full-stack-web", risk: "production-adjacent", repo: "C:\\Dev\\niners-war-room" },
  { name: "OrderPilot", type: "marketing-site", risk: "local-only", repo: "C:\\Dev\\cellar-orderpilot-lite" },
  { name: "RestaurantDemo", type: "marketing-site", risk: "local-only", repo: "C:\\Dev\\restaurant-automation-demo" },
  { name: "RestaurantProfitLab", type: "ai-workflow", risk: "sandbox", repo: "C:\\Dev\\restaurant-profit-simulator" },
  { name: "ShiftLedger", type: "marketing-site", risk: "local-only", repo: "C:\\Dev\\cellar-manager-brief" },
  { name: "ShiftPlate", type: "sandbox-prototype", risk: "sandbox", repo: "C:\\Dev\\special-sauce" },
  { name: "Tree", type: "full-stack-web", risk: "production-adjacent", repo: "C:\\Dev\\Tree" },
  { name: "UrbanKitchenSite", type: "marketing-site", risk: "local-only", repo: "C:\\Dev\\cellar-urban-kitchen-site" }
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

function renderProjects() {
  projectCount.textContent = String(projects.length);
  projectGrid.innerHTML = "";

  for (const project of projects) {
    const card = document.createElement("article");
    card.className = "project-card";

    const title = document.createElement("h3");
    title.textContent = project.name;

    const meta = document.createElement("span");
    meta.className = "meta";
    meta.textContent = `${project.type} / ${project.risk}`;

    const repo = document.createElement("span");
    repo.className = "repo";
    repo.textContent = project.repo;

    const actions = document.createElement("div");
    actions.className = "project-actions";

    const request = document.createElement("a");
    request.className = "button button--primary";
    request.href = requestUrl;
    request.textContent = "Request";

    const log = document.createElement("a");
    log.className = "button";
    log.href = todayUrl;
    log.textContent = "Log";

    const stop = document.createElement("a");
    stop.className = "button button--danger";
    stop.href = stopUrl;
    stop.textContent = "Stop";

    actions.append(request, log, stop);
    card.append(title, meta, repo, actions);
    projectGrid.append(card);
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
    } else {
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

renderProjects();
loadStatus();
