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
  requiredText = [],
  anchors = [],
  chromePort = 9222,
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
        if (message.error) {
          reject(new Error(message.error.message));
        } else {
          resolve(message.result);
        }
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

async function waitFor(check, timeoutMs = 15000, intervalMs = 250) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    if (await check()) {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  throw new Error("Timed out waiting for condition.");
}

async function runViewport(name, viewport) {
  const target = await requestJson(`http://127.0.0.1:${chromePort}/json/new?${encodeURIComponent(baseUrl)}`, "PUT");
  const client = new CdpClient(target.webSocketDebuggerUrl);
  await client.open();

  const consoleIssues = [];
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
  await client.send("Page.navigate", { url: baseUrl });
  await waitFor(() => client.events.some((event) => event.method === "Page.loadEventFired"), 20000);
  await new Promise((resolve) => setTimeout(resolve, 600));

  for (const event of client.events) {
    if (event.method === "Runtime.consoleAPICalled" && ["error", "warning"].includes(event.params.type)) {
      consoleIssues.push(`${event.params.type}: ${event.params.args?.map((arg) => arg.value ?? arg.description ?? "").join(" ")}`);
    }
    if (event.method === "Log.entryAdded" && ["error", "warning"].includes(event.params.entry.level)) {
      consoleIssues.push(`${event.params.entry.level}: ${event.params.entry.text}`);
    }
  }

  const bodyTextResult = await client.send("Runtime.evaluate", {
    expression: "document.body ? document.body.innerText : ''",
    returnByValue: true,
  });
  const bodyText = bodyTextResult.result.value ?? "";
  const missingText = requiredText.filter((text) => !bodyText.toLowerCase().includes(String(text).toLowerCase()));

  const layoutResult = await client.send("Runtime.evaluate", {
    expression: `(() => ({
      innerWidth: window.innerWidth,
      scrollWidth: document.documentElement.scrollWidth,
      bodyScrollWidth: document.body ? document.body.scrollWidth : 0,
      innerHeight: window.innerHeight,
      scrollHeight: document.documentElement.scrollHeight
    }))()`,
    returnByValue: true,
  });
  const layout = layoutResult.result.value ?? {};
  const clippingResult = await client.send("Runtime.evaluate", {
    expression: `(() => {
      const selectors = ['.hero h1', '.hero-copy > p:not(.eyebrow)', '.hero-actions', '.hero-contact-actions', '.phone-shell'];
      return selectors.flatMap((selector) => Array.from(document.querySelectorAll(selector)).map((element, index) => {
        const rect = element.getBoundingClientRect();
        return {
          selector,
          index,
          left: Math.round(rect.left),
          right: Math.round(rect.right),
          top: Math.round(rect.top),
          bottom: Math.round(rect.bottom),
          width: Math.round(rect.width),
          viewportWidth: window.innerWidth,
          clipped: rect.left < -2 || rect.right > window.innerWidth + 2
        };
      }));
    })()`,
    returnByValue: true,
  });
  const clipping = clippingResult.result.value ?? [];

  const linkResult = await client.send("Runtime.evaluate", {
    expression: `(() => {
      const anchors = ${JSON.stringify(anchors)};
      return anchors.map((href) => ({ href, exists: Boolean(document.querySelector('a[href="' + href + '"], [id="' + href.replace(/^#/, '') + '"]')) }));
    })()`,
    returnByValue: true,
  });
  const missingAnchors = (linkResult.result.value ?? []).filter((item) => !item.exists).map((item) => item.href);

  const initialScreenshot = await client.send("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
  const initialScreenshotPath = path.join(outDir, `${name}-initial.png`);
  await writeFile(initialScreenshotPath, Buffer.from(initialScreenshot.data, "base64"));

  for (const anchor of anchors.slice(0, 5)) {
    await client.send("Runtime.evaluate", {
      expression: `(() => {
        const target = document.querySelector('a[href="${anchor}"]') || document.querySelector('${anchor}');
        if (target) target.scrollIntoView({ block: 'start' });
      })()`,
      returnByValue: true,
    });
    await new Promise((resolve) => setTimeout(resolve, 150));
  }

  const screenshot = await client.send("Page.captureScreenshot", { format: "png", captureBeyondViewport: false });
  const screenshotPath = path.join(outDir, `${name}-after-anchors.png`);
  await writeFile(screenshotPath, Buffer.from(screenshot.data, "base64"));

  await client.send("Page.close").catch(() => {});
  client.close();

  return {
    viewport: name,
    initialScreenshotPath,
    screenshotPath,
    missingText,
    missingAnchors,
    consoleIssues,
    layout,
    clipping,
    bodyTextLength: bodyText.length,
  };
}

const results = [];
results.push(await runViewport("desktop", { width: 1440, height: 1000, deviceScaleFactor: 1, mobile: false }));
results.push(await runViewport("mobile", { width: 390, height: 844, deviceScaleFactor: 2, mobile: true }));

const failures = [];
for (const result of results) {
  if (result.bodyTextLength < 200) {
    failures.push(`${result.viewport}: page text looked too small or blank.`);
  }
  for (const text of result.missingText) {
    failures.push(`${result.viewport}: missing required text "${text}".`);
  }
  for (const anchor of result.missingAnchors) {
    failures.push(`${result.viewport}: missing anchor/link "${anchor}".`);
  }
  const maxScrollWidth = Math.max(result.layout.scrollWidth ?? 0, result.layout.bodyScrollWidth ?? 0);
  if (maxScrollWidth > (result.layout.innerWidth ?? 0) + 12) {
    failures.push(`${result.viewport}: horizontal overflow detected (${maxScrollWidth}px content inside ${result.layout.innerWidth}px viewport).`);
  }
  for (const clipped of result.clipping ?? []) {
    if (clipped.clipped) {
      failures.push(`${result.viewport}: key element ${clipped.selector} is clipped (${clipped.left}-${clipped.right}px inside ${clipped.viewportWidth}px viewport).`);
    }
  }
  for (const issue of result.consoleIssues) {
    if (/Failed to load resource: the server responded with a status of 404/i.test(issue)) {
      continue;
    }
    failures.push(`${result.viewport}: console/log issue: ${issue}`);
  }
}

const summary = {
  baseUrl,
  outDir,
  results,
  failures,
  passed: failures.length === 0,
};

await writeFile(path.join(outDir, "summary.json"), JSON.stringify(summary, null, 2));
console.log(JSON.stringify(summary, null, 2));

if (!summary.passed) {
  process.exit(1);
}
