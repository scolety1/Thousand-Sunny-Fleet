import { mkdir, readFile, writeFile } from "node:fs/promises";
import http from "node:http";
import path from "node:path";

const arg = process.argv[2] ?? "{}";
const options = arg.startsWith("@")
  ? JSON.parse(await readFile(arg.slice(1), "utf8"))
  : JSON.parse(arg);

const {
  baseUrl,
  outDir,
  chromePort = 9222,
  project = "Project",
  paths = ["/"],
} = options;

if (!baseUrl || !outDir) {
  throw new Error("baseUrl and outDir are required.");
}

await mkdir(outDir, { recursive: true });

function requestJson(url, method = "GET") {
  return new Promise((resolve, reject) => {
    const request = http.request(url, { method }, (res) => {
      let body = "";
      res.setEncoding("utf8");
      res.on("data", (chunk) => {
        body += chunk;
      });
      res.on("end", () => {
        try {
          resolve(JSON.parse(body));
        } catch (error) {
          reject(error);
        }
      });
    });
    request.on("error", reject);
    request.end();
  });
}

class CdpClient {
  constructor(wsUrl) {
    this.nextId = 1;
    this.pending = new Map();
    this.events = [];
    this.socket = new WebSocket(wsUrl);
  }

  async open() {
    await new Promise((resolve, reject) => {
      this.socket.addEventListener("open", resolve, { once: true });
      this.socket.addEventListener("error", reject, { once: true });
    });
    this.socket.addEventListener("message", (event) => {
      const message = JSON.parse(event.data);
      if (message.id && this.pending.has(message.id)) {
        const { resolve, reject } = this.pending.get(message.id);
        this.pending.delete(message.id);
        if (message.error) reject(new Error(message.error.message));
        else resolve(message.result);
      } else if (message.method) {
        this.events.push(message);
      }
    });
  }

  send(method, params = {}) {
    const id = this.nextId++;
    const payload = JSON.stringify({ id, method, params });
    const promise = new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
    });
    this.socket.send(payload);
    return promise;
  }

  close() {
    this.socket.close();
  }
}

async function waitFor(check, timeoutMs = 20000, intervalMs = 250) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    if (await check()) return;
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  throw new Error("Timed out waiting for condition.");
}

function joinUrl(base, route) {
  const url = new URL(base);
  const cleanRoute = String(route || "/");
  url.pathname = cleanRoute.startsWith("/") ? cleanRoute : `/${cleanRoute}`;
  return url.toString();
}

function severityRank(severity) {
  return { high: 0, medium: 1, low: 2 }[severity] ?? 3;
}

async function runRouteViewport(route, viewportName, viewport) {
  const url = joinUrl(baseUrl, route);
  const target = await requestJson(`http://127.0.0.1:${chromePort}/json/new?${encodeURIComponent(url)}`, "PUT");
  const client = new CdpClient(target.webSocketDebuggerUrl);
  await client.open();

  await client.send("Runtime.enable");
  await client.send("Page.enable");
  await client.send("Log.enable");
  await client.send("Emulation.setDeviceMetricsOverride", {
    width: viewport.width,
    height: viewport.height,
    deviceScaleFactor: viewport.deviceScaleFactor ?? 1,
    mobile: Boolean(viewport.mobile),
  });

  client.events.length = 0;
  await client.send("Page.navigate", { url });
  await waitFor(() => client.events.some((event) => event.method === "Page.loadEventFired"));
  await new Promise((resolve) => setTimeout(resolve, 850));

  const consoleIssues = [];
  for (const event of client.events) {
    if (event.method === "Runtime.consoleAPICalled" && ["error", "warning"].includes(event.params.type)) {
      const text = event.params.args?.map((arg) => arg.value ?? arg.description ?? "").join(" ") ?? "";
      consoleIssues.push(`${event.params.type}: ${text}`);
    }
    if (event.method === "Log.entryAdded" && ["error", "warning"].includes(event.params.entry.level)) {
      consoleIssues.push(`${event.params.entry.level}: ${event.params.entry.text}`);
    }
  }

  const auditResult = await client.send("Runtime.evaluate", {
    expression: `(() => {
      const findings = [];
      const viewportWidth = window.innerWidth;
      const viewportHeight = window.innerHeight;
      const selectorFor = (element) => {
        if (!element || !element.tagName) return "unknown";
        if (element.id) return "#" + element.id;
        const testId = element.getAttribute("data-testid");
        if (testId) return '[data-testid="' + testId + '"]';
        const cls = Array.from(element.classList || []).slice(0, 3).join(".");
        const base = element.tagName.toLowerCase() + (cls ? "." + cls : "");
        const parent = element.parentElement;
        if (!parent) return base;
        const siblings = Array.from(parent.children).filter((child) => child.tagName === element.tagName);
        const index = siblings.indexOf(element);
        return siblings.length > 1 ? base + ":nth-of-type(" + (index + 1) + ")" : base;
      };
      const textOf = (element) => (element.innerText || element.getAttribute("aria-label") || element.textContent || "").replace(/\\s+/g, " ").trim().slice(0, 90);
      const visible = (element) => {
        const style = getComputedStyle(element);
        const rect = element.getBoundingClientRect();
        return style.display !== "none" && style.visibility !== "hidden" && Number(style.opacity) !== 0 && rect.width > 0 && rect.height > 0;
      };
      const insideHorizontalScroller = (element) => {
        let current = element.parentElement;
        while (current && current !== document.body) {
          const style = getComputedStyle(current);
          const canScroll = ["auto", "scroll"].includes(style.overflowX);
          if (canScroll && current.scrollWidth > current.clientWidth + 8) return true;
          current = current.parentElement;
        }
        return false;
      };
      const elements = Array.from(document.body ? document.body.querySelectorAll("*") : []).filter(visible);
      const maxScrollWidth = Math.max(document.documentElement.scrollWidth, document.body ? document.body.scrollWidth : 0);

      if (maxScrollWidth > viewportWidth + 12) {
        findings.push({
          severity: "high",
          type: "horizontal-overflow",
          selector: "document",
          message: "Page is wider than the viewport.",
          evidence: maxScrollWidth + "px content inside " + viewportWidth + "px viewport"
        });
      }

      for (const element of elements) {
        const rect = element.getBoundingClientRect();
        if (insideHorizontalScroller(element)) continue;
        if (rect.right > viewportWidth + 8 || rect.left < -8) {
          findings.push({
            severity: "high",
            type: "element-overflow",
            selector: selectorFor(element),
            message: "Visible element extends outside the viewport.",
            evidence: textOf(element) || Math.round(rect.left) + "-" + Math.round(rect.right) + "px"
          });
        }
      }

      const touchTargets = elements.filter((element) =>
        element.matches('button, a, input, select, textarea, [role="button"], [tabindex]:not([tabindex="-1"])')
      );
      for (const element of touchTargets) {
        const rect = element.getBoundingClientRect();
        if (rect.top > viewportHeight || rect.bottom < 0) continue;
        if (rect.width > 0 && rect.height > 0 && (rect.width < 36 || rect.height < 36)) {
          findings.push({
            severity: "medium",
            type: "small-tap-target",
            selector: selectorFor(element),
            message: "Interactive target may be hard to tap.",
            evidence: Math.round(rect.width) + "x" + Math.round(rect.height) + "px " + (textOf(element) || "")
          });
        }
      }

      const importantText = elements.filter((element) =>
        element.matches('h1, h2, h3, p, label, button, a, input, textarea, select, [role="button"]')
      );
      for (const element of importantText) {
        const rect = element.getBoundingClientRect();
        if (rect.top > viewportHeight || rect.bottom < 0) continue;
        const style = getComputedStyle(element);
        const clipsX = element.scrollWidth > element.clientWidth + 3 && ["hidden", "clip", "auto", "scroll"].includes(style.overflowX);
        const clipsY = element.scrollHeight > element.clientHeight + 3 && ["hidden", "clip", "auto", "scroll"].includes(style.overflowY);
        if (clipsX || clipsY) {
          findings.push({
            severity: "medium",
            type: "text-clipping",
            selector: selectorFor(element),
            message: "Text or control content may be clipped.",
            evidence: textOf(element) || element.tagName.toLowerCase()
          });
        }
      }

      const headings = elements.filter((element) => element.matches('h1, h2, h3, .hero h1, .mobile-welcome h1'));
      for (const element of headings) {
        const rect = element.getBoundingClientRect();
        if (rect.bottom < 0 || rect.top > viewportHeight) continue;
        const x = Math.min(viewportWidth - 2, Math.max(2, rect.left + rect.width / 2));
        const y = Math.min(viewportHeight - 2, Math.max(2, rect.top + Math.min(rect.height / 2, 24)));
        const top = document.elementFromPoint(x, y);
        if (top && top !== element && !element.contains(top) && !top.contains(element)) {
          findings.push({
            severity: "high",
            type: "covered-heading",
            selector: selectorFor(element),
            message: "Important heading appears covered by another element.",
            evidence: textOf(element) + " covered by " + selectorFor(top)
          });
        }
      }

      const fixed = elements.filter((element) => {
        const style = getComputedStyle(element);
        return style.position === "fixed" || style.position === "sticky";
      }).map((element) => {
        const rect = element.getBoundingClientRect();
        return {
          selector: selectorFor(element),
          position: getComputedStyle(element).position,
          text: textOf(element),
          top: Math.round(rect.top),
          bottom: Math.round(rect.bottom),
          height: Math.round(rect.height)
        };
      }).slice(0, 12);

      return {
        title: document.title || "",
        bodyTextLength: document.body ? document.body.innerText.length : 0,
        viewportWidth,
        viewportHeight,
        scrollWidth: maxScrollWidth,
        scrollHeight: document.documentElement.scrollHeight,
        findings,
        fixed
      };
    })()`,
    returnByValue: true,
  });

  const initialScreenshot = await client.send("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
  const safeRoute = String(route || "/").replace(/[^a-z0-9]+/gi, "-").replace(/^-|-$/g, "") || "root";
  const screenshotPath = path.join(outDir, `${safeRoute}-${viewportName}.png`);
  await writeFile(screenshotPath, Buffer.from(initialScreenshot.data, "base64"));

  await client.send("Page.close").catch(() => {});
  client.close();

  return {
    route,
    viewport: viewportName,
    screenshotPath,
    consoleIssues: consoleIssues.filter((issue) =>
      !/Failed to load resource: the server responded with a status of 404/i.test(issue) &&
      !/React Router Future Flag Warning/i.test(issue)
    ),
    audit: auditResult.result.value,
  };
}

const viewports = [
  ["desktop", { width: 1440, height: 1000, deviceScaleFactor: 1, mobile: false }],
  ["mobile", { width: 390, height: 844, deviceScaleFactor: 2, mobile: true }],
];

const results = [];
for (const route of paths.length ? paths : ["/"]) {
  for (const [name, viewport] of viewports) {
    results.push(await runRouteViewport(route, name, viewport));
  }
}

const allFindings = [];
for (const result of results) {
  for (const issue of result.consoleIssues) {
    allFindings.push({
      severity: "medium",
      route: result.route,
      viewport: result.viewport,
      type: "console",
      selector: "console",
      message: "Console warning or error was emitted.",
      evidence: issue,
      screenshotPath: result.screenshotPath,
    });
  }
  for (const finding of result.audit.findings ?? []) {
    allFindings.push({
      ...finding,
      route: result.route,
      viewport: result.viewport,
      screenshotPath: result.screenshotPath,
    });
  }
}

allFindings.sort((a, b) => severityRank(a.severity) - severityRank(b.severity));

const summary = {
  project,
  baseUrl,
  outDir,
  checkedAt: new Date().toISOString(),
  routes: paths,
  results,
  findings: allFindings,
  passed: !allFindings.some((finding) => finding.severity === "high"),
};

await writeFile(path.join(outDir, "visual-inspect-summary.json"), JSON.stringify(summary, null, 2));
console.log(JSON.stringify(summary, null, 2));

if (!summary.passed) {
  process.exit(1);
}
