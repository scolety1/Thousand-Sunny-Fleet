import { strict as assert } from "node:assert";
import { spawn, execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import {
  existsSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createDemoFixtureAdapters } from "../tools/hq-dispatch/v1/demo-fixtures.mjs";
import { startHqDispatchServerForTest } from "../tools/hq-dispatch/v1/server.mjs";

const root = path.resolve(fileURLToPath(new URL("../", import.meta.url)));
const publicRoot = path.join(root, "tools", "hq-dispatch", "v1", "public");
const stylesPath = path.join(publicRoot, "styles.css");
const htmlPath = path.join(publicRoot, "index.html");
const appPath = path.join(publicRoot, "app.js");
const styles = readFileSync(stylesPath, "utf8");
const html = readFileSync(htmlPath, "utf8");
const app = readFileSync(appPath, "utf8");
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-responsive-layout-v1");
const queueRoot = path.join(fixtureRoot, "queue");
const runtimeRoot = path.join(fixtureRoot, "runtime");
const browserProfileRoot = path.join(fixtureRoot, "edge-profile");
const evidenceArgumentIndex = process.argv.indexOf("--evidence-root");
const requestedEvidenceRoot = evidenceArgumentIndex >= 0 ? process.argv[evidenceArgumentIndex + 1] : null;
if (evidenceArgumentIndex >= 0 && !requestedEvidenceRoot) throw new Error("RESPONSIVE_EVIDENCE_ROOT_ARGUMENT_MISSING");
const defaultEvidenceRoot = path.join(
  root,
  ".codex-local",
  "evidence",
  "responsive-layout",
  `${new Date().toISOString().replace(/[:.]/g, "-")}-${process.pid}`,
);
const evidenceRoot = path.resolve(requestedEvidenceRoot || process.env.TSF_RESPONSIVE_EVIDENCE_ROOT || defaultEvidenceRoot);
const expectedEvidenceParent = path.resolve(root, ".codex-local", "evidence");
const viewports = [320, 375, 390, 768, 1180];
const scenarios = [
  "route_preview",
  "running_mission",
  "admitted_receipt",
  "tim_required_approval",
  "denial_clarification",
  "interrupted_recovery",
  "doctor",
  "stop",
];
const longPath = "C:/TSF_HOTFIX2/.codex-local/fixtures/hq-dispatch-responsive-layout-v1/mission/hq2-responsive-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/r1/preservation/receipt.json";
const longHash = "192168669db5ba0e1e6eb6877f2ce775defd0654a0fe4e124621aa7b9607c627";
const longBranch = "hotfix/tsf-response-contract-runtime-cleanliness-v1-20260718";
const exactLiteral = "TSF_V1_CANONICAL_FIRST_LAUNCH_GREEN";
let assertions = 0;

function check(value, message) {
  assertions += 1;
  assert.ok(value, message);
}

function equal(actual, expected, message) {
  assertions += 1;
  assert.equal(actual, expected, message);
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function fileSha256(filePath) {
  return sha256(readFileSync(filePath));
}

function git(...args) {
  return execFileSync("git.exe", ["-C", root, ...args], {
    encoding: "utf8",
    windowsHide: true,
    timeout: 15_000,
  }).trim();
}

function exactChildKill(processId) {
  if (!Number.isInteger(processId) || processId <= 0) return;
  try {
    execFileSync("taskkill.exe", ["/PID", String(processId), "/T", "/F"], {
      windowsHide: true,
      stdio: "ignore",
      timeout: 15_000,
    });
  } catch {
    // The exact proof-owned browser may already have exited.
  }
}

async function terminateExactChildTree(child) {
  if (!child?.pid || child.exitCode !== null) return;
  const exited = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`EXACT_BROWSER_TREE_DID_NOT_EXIT:${child.pid}`)), 10_000);
    child.once("close", () => { clearTimeout(timer); resolve(); });
  });
  exactChildKill(child.pid);
  await exited;
}

async function reserveLoopbackPort() {
  const server = http.createServer();
  await new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(0, "127.0.0.1", resolve);
  });
  const { port } = server.address();
  await new Promise((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  return port;
}

async function waitFor(fn, classification, timeoutMs = 15_000, intervalMs = 50) {
  const deadline = Date.now() + timeoutMs;
  let lastError = null;
  while (Date.now() < deadline) {
    try {
      const value = await fn();
      if (value) return value;
    } catch (error) {
      lastError = error;
    }
    await new Promise((resolve) => setTimeout(resolve, intervalMs));
  }
  throw new Error(`${classification}:${lastError instanceof Error ? lastError.message : "CONDITION_NOT_REACHED"}`);
}

class CdpSession {
  constructor(url) {
    this.url = url;
    this.socket = null;
    this.nextId = 1;
    this.pending = new Map();
    this.eventWaiters = new Map();
  }

  async open() {
    this.socket = new WebSocket(this.url);
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error("CDP_OPEN_TIMEOUT")), 10_000);
      this.socket.addEventListener("open", () => { clearTimeout(timer); resolve(); }, { once: true });
      this.socket.addEventListener("error", (event) => { clearTimeout(timer); reject(new Error(`CDP_OPEN_FAILED:${event.type}`)); }, { once: true });
    });
    this.socket.addEventListener("message", (event) => {
      const message = JSON.parse(String(event.data));
      if (message.id && this.pending.has(message.id)) {
        const pending = this.pending.get(message.id);
        this.pending.delete(message.id);
        if (message.error) pending.reject(new Error(`CDP_${pending.method}_FAILED:${message.error.message}`));
        else pending.resolve(message.result ?? {});
        return;
      }
      if (!message.method || !this.eventWaiters.has(message.method)) return;
      const waiters = this.eventWaiters.get(message.method);
      this.eventWaiters.delete(message.method);
      for (const waiter of waiters) waiter(message.params ?? {});
    });
  }

  call(method, params = {}) {
    const id = this.nextId;
    this.nextId += 1;
    return new Promise((resolve, reject) => {
      this.pending.set(id, { resolve, reject, method });
      this.socket.send(JSON.stringify({ id, method, params }));
    });
  }

  waitForEvent(method, timeoutMs = 10_000) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`CDP_EVENT_TIMEOUT:${method}`)), timeoutMs);
      const wrapped = (value) => { clearTimeout(timer); resolve(value); };
      const waiters = this.eventWaiters.get(method) ?? [];
      waiters.push(wrapped);
      this.eventWaiters.set(method, waiters);
    });
  }

  close() {
    if (this.socket?.readyState === WebSocket.OPEN) this.socket.close();
  }
}

async function evaluate(cdp, expression) {
  const result = await cdp.call("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
    userGesture: false,
  });
  if (result.exceptionDetails) {
    throw new Error(`BROWSER_EVALUATION_FAILED:${JSON.stringify(result.exceptionDetails)}`);
  }
  return result.result?.value;
}

function scenarioExpression(name) {
  return `(() => {
    const scenario = ${JSON.stringify(name)};
    const longPath = ${JSON.stringify(longPath)};
    const longHash = ${JSON.stringify(longHash)};
    const longBranch = ${JSON.stringify(longBranch)};
    const exactLiteral = ${JSON.stringify(exactLiteral)};
    const set = (selector, value) => { const node = document.querySelector(selector); if (node) node.textContent = value; };
    const show = (selector, visible) => { const node = document.querySelector(selector); if (node) node.hidden = !visible; };
    const preview = document.querySelector('#preview-result');
    const mission = document.querySelector('#mission-result');
    const tim = document.querySelector('#tim-required');
    const recovery = document.querySelector('#recovery-list');
    if (preview) preview.hidden = true;
    if (mission) mission.hidden = true;
    if (tim) tim.hidden = true;
    show('#tim-approval-controls', false);
    show('#tim-clarification-controls', false);
    if (recovery) recovery.replaceChildren();
    set('#doctor-branch', longBranch);
    set('#doctor-queue', 'INTERRUPTED_REQUIRES_NEW_RUN: 1 · TIM_REQUIRED_PENDING_RESPONSE: 1');
    set('#doctor-recovery-counts', 'TIM_REQUIRED 1 · interrupted 1 · conflicts 0 · ' + longHash);
    set('#stop-view-output', JSON.stringify({ server_instance: 'hq-instance-responsive-' + longHash, active_mission: null, owner: 'EXACT_OWNER_ONLY', listener: '127.0.0.1:4317', child_processes: [], path: longPath }, null, 2));
    const populateMission = (state) => {
      if (mission) mission.hidden = false;
      set('#mission-state', state);
      set('#mission-identity', JSON.stringify({ mission_id: 'hq2-responsive-' + longHash, mission_revision: 1, run_id: 'canonical-result-' + longHash, result_id: 'canonical-result-' + longHash, source_path: longPath }, null, 2));
      set('#mission-route', JSON.stringify({ route: { worker_role: 'researcher_source_tracer_worker', resolved_model: 'gpt-5.6-terra' }, access: { permission_mode: 'READ_ONLY', allowed_reads: [longPath] } }, null, 2));
      set('#mission-worker', JSON.stringify({ worker: { status: state, process_id: 429496729, thread_id: 'thread-' + longHash }, verifier: { verdict: state.includes('ADMITTED') ? 'GREEN' : 'PENDING' } }, null, 2));
      set('#mission-admission', JSON.stringify({ preservation: { status: 'PRESERVED', packet_path: longPath, packet_sha256: longHash }, admission: state.includes('ADMITTED') ? { verdict: 'ADMITTED_WITH_CAVEATS', receipt_id: 'receipt-' + longHash, path: longPath } : null }, null, 2));
      set('#mission-response-contract', JSON.stringify({ requested: exactLiteral, expected: exactLiteral, observed: state.includes('ADMITTED') ? exactLiteral : null, sha256: longHash }, null, 2));
      set('#mission-authority', JSON.stringify({ granted: [], denied: ['merge', 'push', 'deployment', 'plugins', 'credentials'], exact_next_action: 'TIM_APPROVED_HOTFIX_MERGE_GATE_ONLY', evidence: longPath }, null, 2));
    };
    const populatePreview = () => {
      if (preview) preview.hidden = false;
      set('#classification', 'SAFE_LOCAL_MISSION_WITH_LONG_IDENTIFIER_' + longHash);
      set('#project-id', 'thousand-sunny-fleet-' + longHash);
      set('#lane-id', 'MASTER_TSF_CONTROL_PLANE_' + longHash);
      set('#worker-role', 'Researcher / Source Tracer Worker ' + longHash);
      set('#worker-purpose', 'Read only ' + longPath);
      set('#model-alias', 'BALANCED_' + longHash);
      set('#model-effort', 'MEDIUM · gpt-5.6-terra · RECOMMENDED_ONLY · ' + longHash);
      set('#access-level', 'TSF_LOCAL_SCOPED_PREVIEW_RECOMMENDATION_' + longHash);
      set('#access-scope', 'NO_NETWORK | ROUTE_PREVIEW_ONLY_NO_EXECUTION | ' + longPath);
      set('#artifact-path', longPath);
      set('#response-contract-preview', JSON.stringify({ expected_literal: exactLiteral, expected_literal_sha256: longHash, source_path: longPath }, null, 2));
    };
    const populateTim = (includeApproval, includeClarification) => {
      populateMission('TIM_REQUIRED');
      if (tim) tim.hidden = false;
      set('#tim-request', JSON.stringify({ request_id: 'timreq-' + longHash, response_id: 'hq-response-' + longHash, response_types: ['APPROVE_EXACT_REQUEST', 'DENY_REQUEST', 'PROVIDE_CLARIFICATION'], exact_paths: [longPath], evidence_sha256: longHash, authority_not_included: ['merge', 'deployment', 'production', 'plugin', 'credential'] }, null, 2));
      show('#tim-approval-controls', includeApproval);
      show('#tim-clarification-controls', includeClarification);
    };
    const populateRecovery = () => {
      if (!recovery) return;
      const card = document.createElement('article');
      card.className = 'recovery-card';
      const header = document.createElement('div');
      header.className = 'recovery-card-header';
      const title = document.createElement('strong');
      title.textContent = 'hq2-responsive-' + longHash + ' · revision 1';
      const status = document.createElement('code');
      status.textContent = 'INTERRUPTED_REQUIRES_NEW_RUN_' + longHash;
      header.append(title, status);
      const detail = document.createElement('pre');
      detail.textContent = JSON.stringify({ run_id: 'run-' + longHash, source_path: longPath, interruption_evidence_sha256: longHash, owner_disposition: 'ABSENT_AFTER_EXACT_CHILD_STOP', recommended_action: 'START_NEW_RUN_WITH_NEW_IDENTITIES' }, null, 2);
      const warning = document.createElement('p');
      warning.textContent = 'Immutable history remains preserved at ' + longPath;
      const actions = document.createElement('div');
      actions.className = 'recovery-actions';
      for (const label of ['Confirm START NEW RUN WITH NEW IDENTITIES', 'Confirm DECLINE RECOVERY', 'Confirm TIM REQUIRED']) {
        const button = document.createElement('button');
        button.type = 'button';
        button.textContent = label + ' ' + longHash;
        actions.append(button);
      }
      card.append(header, detail, warning, actions);
      recovery.append(card);
    };
    if (scenario === 'route_preview') populatePreview();
    if (scenario === 'running_mission') populateMission('RUNNING_FOREGROUND_OWNED_CHILD_' + longHash);
    if (scenario === 'admitted_receipt') populateMission('ADMITTED_WITH_CAVEATS_' + longHash);
    if (scenario === 'tim_required_approval') populateTim(true, false);
    if (scenario === 'denial_clarification') populateTim(true, true);
    if (scenario === 'interrupted_recovery') populateRecovery();
    if (scenario === 'all_surfaces') { populatePreview(); populateTim(true, true); populateRecovery(); }
    window.scrollTo(0, 0);
    return scenario;
  })()`;
}

const measurementExpression = `(() => {
  const root = document.documentElement;
  const body = document.body;
  const viewportWidth = root.clientWidth;
  const documentWidth = Math.max(root.scrollWidth, body.scrollWidth);
  const visible = (node) => {
    const style = getComputedStyle(node);
    const rect = node.getBoundingClientRect();
    return !node.hidden && style.display !== 'none' && style.visibility !== 'hidden' && rect.width > 0 && rect.height > 0;
  };
  const offenders = Array.from(document.querySelectorAll('*')).map((node) => {
    const rect = node.getBoundingClientRect();
    const name = node.id ? '#' + node.id : node.tagName.toLowerCase() + (typeof node.className === 'string' && node.className.trim() ? '.' + node.className.trim().split(/\\s+/).join('.') : '');
    return { selector: name, left: Number(rect.left.toFixed(2)), right: Number(rect.right.toFixed(2)), width: Number(rect.width.toFixed(2)), scroll_width: node.scrollWidth, client_width: node.clientWidth };
  }).filter((row) => row.left < -1 || row.right > viewportWidth + 1).slice(0, 25);
  const controls = Array.from(document.querySelectorAll('button,input,textarea,select')).filter(visible);
  const clippedControls = controls.map((node) => {
    const rect = node.getBoundingClientRect();
    return { id: node.id || node.textContent.trim().slice(0, 80), tag: node.tagName, type: node.getAttribute('type'), left: rect.left, right: rect.right, width: rect.width, height: rect.height };
  }).filter((row) => row.left < -1 || row.right > viewportWidth + 1 || row.width <= 0 || row.height <= 0 || (row.tag === 'BUTTON' && (row.width < 44 || row.height < 32)));
  const unlabeledControls = controls.filter((node) => {
    if (node.tagName === 'BUTTON') return !String(node.textContent || '').trim() && !node.getAttribute('aria-label');
    if (node.getAttribute('aria-label') || node.getAttribute('aria-labelledby')) return false;
    if (node.id && document.querySelector('label[for="' + node.id + '"]')) return false;
    return !node.closest('label');
  }).map((node) => node.id || node.tagName.toLowerCase());
  const levelOverflow = Object.fromEntries(['html','body','main'].map((selector) => [selector, getComputedStyle(document.querySelector(selector)).overflowX]));
  return {
    inner_width: window.innerWidth,
    viewport_width: viewportWidth,
    document_width: documentWidth,
    page_overflow_pixels: Number((documentWidth - viewportWidth).toFixed(2)),
    offenders,
    clipped_controls: clippedControls,
    unlabeled_controls: unlabeledControls,
    visible_controls: controls.length,
    live_regions: document.querySelectorAll('[aria-live]').length,
    page_level_overflow_x: levelOverflow,
    test_only_barrier_controls: Array.from(document.querySelectorAll('button,input,textarea,select')).filter((node) => /interruption barrier|test[-_ ]only barrier/i.test(String(node.textContent || node.getAttribute('aria-label') || ''))).length,
  };
})()`;

check(path.resolve(evidenceRoot).startsWith(expectedEvidenceParent + path.sep), "responsive evidence root is confined to .codex-local/evidence");
check(!existsSync(evidenceRoot), "responsive evidence run does not overwrite prior evidence");
check(!/overflow-x\s*:\s*hidden/i.test(styles), "stylesheet contains no page-level or blanket horizontal overflow hiding");
check(/html\s*\{[\s\S]*?min-width:\s*0;/m.test(styles), "html removes the fixed 320px page minimum");
check(styles.includes(".lifecycle-grid > *") && styles.includes(".route-strip > *") && styles.includes(".detail-grid > *"), "grid children receive explicit shrinkability");
check(styles.includes(".recovery-actions > *") && styles.includes(".response-actions > *"), "action-group children receive explicit shrinkability");
check(styles.includes("overflow-wrap: anywhere"), "identifier-bearing surfaces wrap without normalization or truncation");
check(styles.includes("grid-template-columns: minmax(0, 1fr)"), "single-column responsive tracks use a zero minimum");
check(styles.includes("repeat(2, minmax(0, 1fr))"), "two-column responsive tracks use zero-minimum fractions");
check(styles.includes("button:focus-visible"), "visible keyboard focus styling remains present");
check(!app.includes(".innerHTML"), "operator UI continues to render evidence through textContent/DOM nodes rather than HTML injection");
check(!/M3_REAL_INTERRUPTION|testOnlyInterruptionBarrier/.test(html + app), "public UI exposes no interruption-test barrier control");
for (const id of ["preview-result", "mission-result", "mission-response-contract", "tim-required", "tim-approval-controls", "tim-deny", "tim-clarification-controls", "recovery-list", "doctor-overall", "stop-view-output"]) {
  check(html.includes(`id="${id}"`), `responsive surface exists: ${id}`);
}
check((html.match(/aria-live=/g) ?? []).length >= 3, "approval, denial, recovery, and mission status retain live regions");
check(html.includes("<summary>Stop view</summary>"), "Stop projection retains its native details/summary label");

if (existsSync(fixtureRoot)) rmSync(fixtureRoot, { recursive: true, force: true, maxRetries: 20, retryDelay: 100 });
mkdirSync(queueRoot, { recursive: true });
mkdirSync(runtimeRoot, { recursive: true });
mkdirSync(evidenceRoot, { recursive: true });

const edgeCandidates = [
  "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
  "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
];
const edgePath = edgeCandidates.find(existsSync);
check(Boolean(edgePath), "Microsoft Edge is available for deterministic runtime layout assertions");

const adapters = createDemoFixtureAdapters({ fixtureRoot, repositoryRoot: root, queueRoot, runtimeRoot });
const server = await startHqDispatchServerForTest({
  executionAdapter: adapters.executionAdapter,
  responseAdapter: adapters.responseAdapter,
});
const appPort = server.address().port;
const appUrl = `http://127.0.0.1:${appPort}/`;
const debugPort = await reserveLoopbackPort();
let edge = null;
let cdp = null;
let edgeStdout = "";
let edgeStderr = "";
let browserProfileCleanupDeferred = false;
const measurements = [];
const screenshots = [];

try {
  edge = spawn(edgePath, [
    "--headless=new",
    "--disable-gpu",
    "--disable-extensions",
    "--disable-background-networking",
    "--disable-component-update",
    "--disable-default-apps",
    "--disable-sync",
    "--metrics-recording-only",
    "--no-first-run",
    "--no-default-browser-check",
    "--no-proxy-server",
    `--remote-debugging-port=${debugPort}`,
    `--user-data-dir=${browserProfileRoot}`,
    appUrl,
  ], { windowsHide: true, stdio: ["ignore", "pipe", "pipe"] });
  edge.stdout.on("data", (chunk) => { edgeStdout += chunk.toString("utf8"); });
  edge.stderr.on("data", (chunk) => { edgeStderr += chunk.toString("utf8"); });

  const target = await waitFor(async () => {
    const response = await fetch(`http://127.0.0.1:${debugPort}/json/list`);
    if (!response.ok) return null;
    const targets = await response.json();
    return targets.find((entry) => entry.type === "page" && entry.url.startsWith(appUrl)) ?? null;
  }, "RESPONSIVE_BROWSER_TARGET_NOT_READY", 20_000);
  cdp = new CdpSession(target.webSocketDebuggerUrl);
  await cdp.open();
  await cdp.call("Page.enable");
  await cdp.call("Runtime.enable");
  await cdp.call("Emulation.setFocusEmulationEnabled", { enabled: true });
  await waitFor(async () => evaluate(cdp, "document.readyState === 'complete' && document.querySelector('#doctor-overall')?.textContent !== 'Loading Doctor'"), "RESPONSIVE_APP_NOT_READY");

  for (const width of viewports) {
    await cdp.call("Emulation.setDeviceMetricsOverride", {
      width,
      height: 900,
      deviceScaleFactor: 1,
      mobile: false,
      screenWidth: width,
      screenHeight: 900,
    });
    await evaluate(cdp, "window.scrollTo(0, 0); true");
    for (const scenario of scenarios) {
      await evaluate(cdp, scenarioExpression(scenario));
      let measurement;
      try {
        measurement = await evaluate(cdp, measurementExpression);
      } catch (error) {
        throw new Error(`RESPONSIVE_MEASUREMENT_FAILED:${width}:${scenario}:${error instanceof Error ? error.message : "UNKNOWN"}`);
      }
      measurements.push({ width, scenario, ...measurement });
      check(measurement.document_width <= measurement.viewport_width + 1, `${scenario} document fits ${width}px viewport`);
      equal(measurement.offenders.length, 0, `${scenario} has no off-viewport element at ${width}px`);
      equal(measurement.clipped_controls.length, 0, `${scenario} controls remain reachable at ${width}px`);
      equal(measurement.unlabeled_controls.length, 0, `${scenario} controls retain semantic labels at ${width}px`);
      check(measurement.live_regions >= 3, `${scenario} live regions remain present at ${width}px`);
      check(Object.values(measurement.page_level_overflow_x).every((value) => value !== "hidden"), `${scenario} uses no page-level overflow hiding at ${width}px`);
      equal(measurement.test_only_barrier_controls, 0, `${scenario} exposes no test-only barrier control at ${width}px`);

      if (width === 375) {
        const screenshotResult = await cdp.call("Page.captureScreenshot", { format: "png", fromSurface: true });
        const screenshotPath = path.join(evidenceRoot, `responsive-${width}-${scenario}.png`);
        writeFileSync(screenshotPath, Buffer.from(screenshotResult.data, "base64"));
        screenshots.push({ width, scenario, path: screenshotPath, sha256: fileSha256(screenshotPath) });
      }
    }

    await evaluate(cdp, scenarioExpression("all_surfaces"));
    const combined = await evaluate(cdp, measurementExpression);
    measurements.push({ width, scenario: "all_surfaces", ...combined });
    check(combined.document_width <= combined.viewport_width + 1, `combined operator surfaces fit ${width}px viewport`);
    equal(combined.offenders.length, 0, `combined operator surfaces have no off-viewport elements at ${width}px`);
    equal(combined.clipped_controls.length, 0, `combined operator controls remain reachable at ${width}px`);
    const screenshotResult = await cdp.call("Page.captureScreenshot", { format: "png", fromSurface: true });
    const screenshotPath = path.join(evidenceRoot, `responsive-${width}-all-surfaces.png`);
    writeFileSync(screenshotPath, Buffer.from(screenshotResult.data, "base64"));
    screenshots.push({ width, scenario: "all_surfaces", path: screenshotPath, sha256: fileSha256(screenshotPath) });

    await evaluate(cdp, "document.activeElement?.blur(); true");
    await cdp.call("Input.dispatchKeyEvent", { type: "keyDown", key: "Tab", code: "Tab", windowsVirtualKeyCode: 9, nativeVirtualKeyCode: 9 });
    await cdp.call("Input.dispatchKeyEvent", { type: "keyUp", key: "Tab", code: "Tab", windowsVirtualKeyCode: 9, nativeVirtualKeyCode: 9 });
    const focus = await evaluate(cdp, `(() => { const node=document.activeElement; const style=getComputedStyle(node); return { tag: node?.tagName, id: node?.id, outline_style: style.outlineStyle, outline_width: style.outlineWidth, outline_color: style.outlineColor }; })()`);
    check(["BUTTON", "INPUT", "TEXTAREA"].includes(focus.tag), `keyboard Tab reaches an operator control at ${width}px`);
    check(focus.outline_style !== "none" && focus.outline_width !== "0px", `keyboard focus is visibly outlined at ${width}px`);
  }
} finally {
  cdp?.close();
  if (edge?.pid) await terminateExactChildTree(edge);
  await server.hqDispatchShutdown();
  if (server.listening) await new Promise((resolve) => server.close(resolve));
  if (existsSync(browserProfileRoot)) {
    try {
      rmSync(browserProfileRoot, { recursive: true, force: true, maxRetries: 20, retryDelay: 100 });
    } catch (error) {
      if (error?.code !== "EPERM") throw error;
      browserProfileCleanupDeferred = true;
    }
  }
}

const finalDocumentFailures = measurements.filter((row) => row.document_width > row.viewport_width + 1);
const finalOffenderFailures = measurements.filter((row) => row.offenders.length > 0);
equal(finalDocumentFailures.length, 0, "all viewport/scenario document widths fit");
equal(finalOffenderFailures.length, 0, "all viewport/scenario offender diagnostics are empty");
check(screenshots.length === scenarios.length + viewports.length, "responsive screenshots cover every 375px scenario and every required width");

const result = {
  schema_version: "tsf_hq_dispatch_responsive_layout_browser_proof_v1",
  status: "PASS",
  assertions,
  candidate: {
    head: git("rev-parse", "HEAD"),
    tree: git("rev-parse", "HEAD^{tree}"),
    working_tree_dirty: Boolean(git("status", "--porcelain")),
    styles_sha256: fileSha256(stylesPath),
    html_sha256: fileSha256(htmlPath),
    app_sha256: fileSha256(appPath),
  },
  runtime: {
    browser: edgePath,
    browser_process_id: edge?.pid ?? null,
    exact_owned_browser_tree_terminated: true,
    browser_profile_cleanup_deferred: browserProfileCleanupDeferred,
    browser_profile_path: browserProfileCleanupDeferred ? browserProfileRoot : null,
    local_app_url: appUrl,
    external_network_used: false,
    product_repository_used: false,
    plugin_used: false,
    credential_used: false,
    package_installed: false,
    page_level_overflow_hiding_used: false,
    hidden_content_used_to_pass: false,
  },
  required_viewports: viewports,
  required_scenarios: scenarios,
  long_identifier_fixtures: { exact_literal: exactLiteral, sha256: longHash, path: longPath, branch: longBranch },
  measurements,
  screenshots,
  diagnostics: {
    edge_stdout_sha256: sha256(edgeStdout),
    edge_stderr_sha256: sha256(edgeStderr),
    document_width_failures: finalDocumentFailures,
    offender_failures: finalOffenderFailures,
  },
};
const resultPath = path.join(evidenceRoot, "responsive-layout-result.json");
writeFileSync(resultPath, `${JSON.stringify(result, null, 2)}\n`, "utf8");
result.result_path = resultPath;
result.result_sha256 = fileSha256(resultPath);
console.log(JSON.stringify(result, null, 2));
