const statusUrl = "https://raw.githubusercontent.com/scolety1/Thousand-Sunny-Fleet/main/fleet/status/current.md";

const dashboardStatus = document.getElementById("dashboardStatus");
const fleetMode = document.getElementById("fleetMode");
const updatedAt = document.getElementById("updatedAt");
const captainSummary = document.getElementById("captainSummary");
const fetchNote = document.getElementById("fetchNote");

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

async function loadStatus() {
  try {
    const response = await fetch(statusUrl, { cache: "no-store" });
    if (!response.ok) {
      throw new Error("HTTP " + response.status);
    }
    const markdown = await response.text();
    dashboardStatus.textContent = "Online";
    dashboardStatus.className = "ok";
    fleetMode.textContent = matchLine(markdown, "Fleet mode") || "Unknown";
    updatedAt.textContent = matchLine(markdown, "Updated") || "Unknown";
    captainSummary.textContent = section(markdown, "Captain Summary") || markdown.slice(0, 1200);
    fetchNote.textContent = "Loaded from public GitHub raw status. This is view-only.";
  } catch (error) {
    dashboardStatus.textContent = "Status link only";
    dashboardStatus.className = "";
    fleetMode.textContent = "Unknown";
    updatedAt.textContent = "Unknown";
    captainSummary.textContent = "Live status fetch failed. Open the Latest Captain Status link instead. Do not use unsafe workarounds.";
    fetchNote.textContent = String(error && error.message ? error.message : error);
  }
}

loadStatus();
