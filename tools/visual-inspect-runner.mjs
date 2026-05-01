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
  routes,
  paths = ["/"],
  viewports: configuredViewports,
  informationStaging,
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

const routeConfigs = (Array.isArray(routes) && routes.length ? routes : paths).map((entry) => {
  if (typeof entry === "string") {
    return { path: entry, label: entry };
  }
  const routePath = entry?.path ?? entry?.url ?? "/";
  return {
    ...entry,
    path: routePath,
    label: entry?.label ?? routePath,
  };
});

function joinUrl(base, route) {
  const url = new URL(base);
  const cleanRoute = String(route || "/");
  const routeUrl = new URL(cleanRoute.startsWith("/") ? `http://fleet.local${cleanRoute}` : `http://fleet.local/${cleanRoute}`);
  url.pathname = routeUrl.pathname;
  url.search = routeUrl.search;
  url.hash = routeUrl.hash;
  return url.toString();
}

function severityRank(severity) {
  return { high: 0, medium: 1, low: 2 }[severity] ?? 3;
}

function normalizeText(value) {
  return String(value ?? "").replace(/\s+/g, " ").trim();
}

function extractSignalTerms(value) {
  const stop = new Set([
    "the", "and", "with", "from", "that", "this", "into", "behind", "clear", "first",
    "screen", "surface", "content", "action", "actions", "details", "internal", "primary",
    "secondary", "user", "users", "guest", "guests", "staff", "tool", "demo", "page",
  ]);
  return normalizeText(value)
    .split(/[,.;:/|]|\band\b|\bor\b/i)
    .map((part) => normalizeText(part).toLowerCase())
    .filter((part) => part.length >= 4)
    .filter((part) => !stop.has(part))
    .slice(0, 10);
}

function addInformationStagingFindings(result) {
  if (!informationStaging) return;
  const audit = result.audit ?? {};
  audit.findings = Array.isArray(audit.findings) ? audit.findings : [];
  const metrics = audit.firstScreenMetrics ?? {};
  const firstScreenText = normalizeText(metrics.text).toLowerCase();
  const wordCount = Number(metrics.wordCount ?? 0);
  const interactiveCount = Number(metrics.interactiveCount ?? 0);
  const headingCount = Number(metrics.headingCount ?? 0);
  const isMobile = result.viewport.toLowerCase().includes("mobile");
  const maxWords = isMobile ? 130 : 190;
  const maxActions = isMobile ? 9 : 14;

  if (wordCount > maxWords && interactiveCount > Math.max(4, Math.floor(maxActions / 2))) {
    audit.findings.push({
      severity: "medium",
      type: "information-staging-overload",
      selector: "first-screen",
      message: "First screen looks overloaded for the documented information-staging contract.",
      evidence: `${wordCount} words and ${interactiveCount} interactive controls above the fold`,
    });
  }

  if (interactiveCount > maxActions) {
    audit.findings.push({
      severity: "medium",
      type: "information-staging-too-many-actions",
      selector: "first-screen",
      message: "First screen exposes too many actions before the user reaches the primary job.",
      evidence: `${interactiveCount} interactive controls above the fold`,
    });
  }

  if (headingCount > 5) {
    audit.findings.push({
      severity: "low",
      type: "information-staging-too-many-headings",
      selector: "first-screen",
      message: "First screen has too many competing headings for a calm staged layout.",
      evidence: `${headingCount} headings above the fold`,
    });
  }

  const hiddenTerms = [
    ...extractSignalTerms(informationStaging.notVisibleAtFirst),
    ...extractSignalTerms(informationStaging.detailContent),
  ].filter((term, index, list) => list.indexOf(term) === index);

  const matchedHidden = hiddenTerms.filter((term) => firstScreenText.includes(term)).slice(0, 5);
  if (matchedHidden.length > 0) {
    audit.findings.push({
      severity: "medium",
      type: "information-staging-detail-visible",
      selector: "first-screen",
      message: "Detail or internal content appears on the first screen instead of behind a clear action.",
      evidence: matchedHidden.join(", "),
    });
  }
}

async function runRouteViewport(routeConfig, viewportName, viewport) {
  const route = routeConfig.path ?? "/";
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
  await new Promise((resolve) => setTimeout(resolve, routeConfig.waitMs ?? 850));

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

      const firstScreenElements = elements.filter((element) => {
        const rect = element.getBoundingClientRect();
        return rect.bottom > 0 && rect.top < viewportHeight * 0.95;
      });
      const firstScreenText = firstScreenElements
        .filter((element) => element.matches('h1, h2, h3, h4, p, li, label, button, a, input, textarea, select, [role="button"]'))
        .map((element) => textOf(element))
        .filter(Boolean)
        .join(" ");
      const firstScreenInteractive = firstScreenElements.filter((element) =>
        element.matches('button, a, input, select, textarea, [role="button"], [tabindex]:not([tabindex="-1"])')
      );
      const firstScreenHeadings = firstScreenElements.filter((element) =>
        element.matches('h1, h2, h3, h4, [role="heading"]')
      );

      return {
        title: document.title || "",
        bodyTextLength: document.body ? document.body.innerText.length : 0,
        viewportWidth,
        viewportHeight,
        scrollWidth: maxScrollWidth,
        scrollHeight: document.documentElement.scrollHeight,
        firstScreenMetrics: {
          text: firstScreenText.slice(0, 2500),
          wordCount: firstScreenText.split(/\\s+/).filter(Boolean).length,
          interactiveCount: firstScreenInteractive.length,
          headingCount: firstScreenHeadings.length,
        },
        findings,
        fixed
      };
    })()`,
    returnByValue: true,
  });

  const requiredText = Array.isArray(routeConfig.requiredText) ? routeConfig.requiredText : [];
  if (requiredText.length > 0) {
    const requiredResult = await client.send("Runtime.evaluate", {
      expression: `(() => {
        const text = document.body ? document.body.innerText : "";
        return ${JSON.stringify(requiredText)}.map((item) => ({
          text: item,
          present: text.toLowerCase().includes(String(item).toLowerCase())
        }));
      })()`,
      returnByValue: true,
    });
    for (const check of requiredResult.result.value ?? []) {
      if (!check.present) {
        auditResult.result.value.findings.push({
          severity: "high",
          type: "missing-required-text",
          selector: "document",
          message: "Required route text was not found.",
          evidence: check.text,
        });
      }
    }
  }

  const initialScreenshot = await client.send("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
  const safeRoute = String(route || "/").replace(/[^a-z0-9]+/gi, "-").replace(/^-|-$/g, "") || "root";
  const screenshotPath = path.join(outDir, `${safeRoute}-${viewportName}.png`);
  await writeFile(screenshotPath, Buffer.from(initialScreenshot.data, "base64"));

  await client.send("Page.close").catch(() => {});
  client.close();

  const result = {
    route,
    label: routeConfig.label ?? route,
    viewport: viewportName,
    screenshotPath,
    consoleIssues: consoleIssues.filter((issue) =>
      !/Failed to load resource: the server responded with a status of 404/i.test(issue) &&
      !/React Router Future Flag Warning/i.test(issue)
    ),
    audit: auditResult.result.value,
  };
  addInformationStagingFindings(result);
  return result;
}

const defaultViewports = [
  ["desktop", { width: 1440, height: 1000, deviceScaleFactor: 1, mobile: false }],
  ["mobile", { width: 390, height: 844, deviceScaleFactor: 2, mobile: true }],
];

const viewports = Array.isArray(configuredViewports) && configuredViewports.length
  ? configuredViewports.map((viewport) => [
      viewport.name ?? `${viewport.width}x${viewport.height}`,
      {
        width: viewport.width ?? 1440,
        height: viewport.height ?? 1000,
        deviceScaleFactor: viewport.deviceScaleFactor ?? 1,
        mobile: Boolean(viewport.mobile),
      },
    ])
  : defaultViewports;

const results = [];
for (const route of routeConfigs.length ? routeConfigs : [{ path: "/", label: "/" }]) {
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
  routes: routeConfigs,
  viewports: viewports.map(([name, viewport]) => ({ name, ...viewport })),
  results,
  findings: allFindings,
  informationStaging: informationStaging ?? null,
  passed: !allFindings.some((finding) => finding.severity === "high"),
};

await writeFile(path.join(outDir, "visual-inspect-summary.json"), JSON.stringify(summary, null, 2));
console.log(JSON.stringify(summary, null, 2));

if (!summary.passed) {
  process.exit(1);
}
