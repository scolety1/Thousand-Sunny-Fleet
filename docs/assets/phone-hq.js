const statusUrl = "https://raw.githubusercontent.com/scolety1/Thousand-Sunny-Fleet/main/fleet/status/current.md";

const dashboardStatus = document.getElementById("dashboardStatus");
const fleetMode = document.getElementById("fleetMode");
const updatedAt = document.getElementById("updatedAt");
const captainSummary = document.getElementById("captainSummary");
const fetchNote = document.getElementById("fetchNote");
const statusCaution = document.getElementById("statusCaution");

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

function section(markdown, heading) {
  const escaped = escapeRegExp(heading);
  const pattern = new RegExp("^## " + escaped + "\\s*\\n([\\s\\S]*?)(?=^## |\\s*$)", "m");
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
    captainSummary.textContent = section(markdown, "Captain Summary") || markdown.slice(0, 1200);
    if (caution) {
      showCaution("Loaded status contains active-looking or execution-looking language. Treat it as view-only caution, use request-only rules, and do not execute from phone.");
      fetchNote.textContent = "Loaded from public GitHub raw status. Caution-only; phone actions remain requests.";
    } else {
      statusCaution.hidden = true;
      fetchNote.textContent = "Loaded from public GitHub raw status. This is view-only and grants no authority.";
    }
  } catch (error) {
    dashboardStatus.textContent = "Status link only";
    dashboardStatus.className = "";
    fleetMode.textContent = "Unknown";
    updatedAt.textContent = "Unknown";
    showCaution("Live status did not load. Use the Latest Captain Status link and keep all phone actions request-only.");
    captainSummary.textContent = "Live status fetch failed. Open the Latest Captain Status link instead. Do not use unsafe workarounds, remote-access changes, command execution, GitHub Actions, product-repo work, all-fleet, overnight, deploy, stage, commit, push, install, migration, or secret handling.";
    fetchNote.textContent = String(error && error.message ? error.message : error);
  }
}

loadStatus();
