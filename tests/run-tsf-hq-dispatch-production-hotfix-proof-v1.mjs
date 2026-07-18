import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { request as httpRequest } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const powershell = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
const doctorScript = path.join(root, "tools", "hq-dispatch", "v1", "Test-TsfHqDispatchDoctorV1.ps1");
const startScript = path.join(root, "tools", "hq-dispatch", "v1", "Start-TsfHqDispatchV1.ps1");
const stopScript = path.join(root, "tools", "hq-dispatch", "v1", "Stop-TsfHqDispatchV1.ps1");
const sentinel = path.join(root, "tests", `.tsf-hotfix-production-proof-${process.pid}.tmp`);
const expectedLiteral = "TSF_V1_CANONICAL_FIRST_LAUNCH_GREEN";
const expectedHash = "192168669db5ba0e1e6eb6877f2ce775defd0654a0fe4e124621aa7b9607c627";
const naturalRequest = `Run the bounded TSF-local read-only HQ Dispatch vertical slice and return exactly ${expectedLiteral}.`;
const startedUtc = new Date().toISOString();
let assertions = 0;

function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }
function sha256(value) { return createHash("sha256").update(value).digest("hex"); }
function git(...args) {
  return spawnSync("git.exe", ["-C", root, ...args], { cwd: root, encoding: "utf8", windowsHide: true, maxBuffer: 8 * 1024 * 1024 });
}
function runPowerShell(script, args = []) {
  return spawnSync(powershell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", script, ...args], {
    cwd: root,
    encoding: "utf8",
    windowsHide: true,
    maxBuffer: 32 * 1024 * 1024,
  });
}
function lastJson(text, label) {
  const trimmed = String(text ?? "").trim();
  try { return JSON.parse(trimmed); } catch { /* PowerShell may precede JSON with warnings. */ }
  const start = trimmed.indexOf("{");
  if (start >= 0) {
    try { return JSON.parse(trimmed.slice(start)); } catch { /* fall through */ }
  }
  throw new Error(`${label}_JSON_UNAVAILABLE`);
}
function doctor(json = true) {
  const result = runPowerShell(doctorScript, json ? ["-Json"] : []);
  return { exit_code: result.status, stdout: result.stdout, stderr: result.stderr, value: json ? lastJson(result.stdout, "DOCTOR") : null };
}
function request({ method = "GET", pathname = "/", token = null, origin = null, body = null }) {
  return new Promise((resolve, reject) => {
    const req = httpRequest({
      host: "127.0.0.1",
      port: 4317,
      method,
      path: pathname,
      headers: {
        Accept: "application/json",
        Connection: "close",
        ...(origin ? { Origin: origin } : {}),
        ...(token ? { "X-TSF-HQ-Session": token } : {}),
        ...(body !== null ? { "Content-Type": "application/json" } : {}),
      },
    }, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        const text = Buffer.concat(chunks).toString("utf8");
        try { resolve({ status: res.statusCode, json: JSON.parse(text) }); }
        catch { reject(new Error(`HTTP_JSON_INVALID_${res.statusCode}`)); }
      });
    });
    req.on("error", reject);
    req.end(body);
  });
}
async function waitForServer(child, timeoutMs = 60_000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) throw new Error(`START_EXITED_EARLY_${child.exitCode}`);
    try {
      const response = await request({ pathname: "/health" });
      if (response.status === 200) return;
    } catch { /* bounded retry while the exact owned Start child initializes */ }
    await new Promise((resolve) => setTimeout(resolve, 100));
  }
  throw new Error("START_LISTENER_TIMEOUT");
}
function waitForExit(child, timeoutMs = 30_000) {
  if (child.exitCode !== null) return Promise.resolve(child.exitCode);
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("START_CHILD_EXIT_TIMEOUT")), timeoutMs);
    child.once("exit", (code) => { clearTimeout(timer); resolve(code); });
  });
}

const candidateHead = git("rev-parse", "HEAD").stdout.trim();
const candidateTree = git("rev-parse", "HEAD^{tree}").stdout.trim();
const candidateBranch = git("branch", "--show-current").stdout.trim();
const initialStatus = git("status", "--short", "--untracked-files=all").stdout.trim();
const doctorBeforeHuman = doctor(false);
const doctorBefore = doctor(true);
let startChild = null;
let startStdout = "";
let startStderr = "";
let stopResult = null;
let mission = null;
let preview = null;
let serverDoctor = null;

try {
  equal(initialStatus, "", "candidate worktree starts clean under canonical Git policy");
  check(doctorBefore.value.safe_to_start, "pre-Start Doctor is safe");
  equal(doctorBefore.value.process_owner.disposition, "ABSENT", "pre-Start owner is absent");
  equal(doctorBefore.value.listener_state.listeners.length, 0, "pre-Start listener is absent");
  equal(doctorBefore.value.active_child.length, 0, "pre-Start owned child is absent");

  startChild = spawn(powershell, ["-NoLogo", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", startScript], {
    cwd: root,
    windowsHide: true,
    stdio: ["ignore", "pipe", "pipe"],
  });
  startChild.stdout.on("data", (chunk) => { if (startStdout.length < 2 * 1024 * 1024) startStdout += chunk.toString("utf8"); });
  startChild.stderr.on("data", (chunk) => { if (startStderr.length < 2 * 1024 * 1024) startStderr += chunk.toString("utf8"); });
  await waitForServer(startChild);
  serverDoctor = doctor(true);
  equal(serverDoctor.value.process_owner.disposition, "ACTIVE_OWNER_CONFIRMED", "Start creates one exact active owner");
  equal(serverDoctor.value.listener_state.listeners.length, 1, "Start creates one loopback listener");

  const origin = "http://127.0.0.1:4317";
  const session = await request({ method: "POST", pathname: "/api/v1/session", origin, body: "{}" });
  equal(session.status, 200, "operator session is created through the fixed local boundary");
  const token = session.json.session_token;
  preview = await request({ method: "POST", pathname: "/api/v1/route-preview", token, origin, body: JSON.stringify({ natural_request: naturalRequest }) });
  equal(preview.status, 200, "reviewed exact preview succeeds");
  equal(preview.json.result_validation_mode, "EXACT_LITERAL_V1", "preview uses exact validation mode");
  equal(preview.json.exact_response_contract.expected_literal, expectedLiteral, "preview preserves the requested literal");
  equal(preview.json.exact_response_contract.expected_literal_sha256, expectedHash, "preview preserves the required SHA-256");
  mission = await request({
    method: "POST",
    pathname: "/api/v1/missions",
    token,
    origin,
    body: JSON.stringify({
      natural_request: naturalRequest,
      preview_id: preview.json.preview_id,
      preview_sha256: preview.json.preview_sha256,
      request_hash: preview.json.request_hash,
      intent: "CREATE_GOVERNED_MISSION",
      submission_id: preview.json.submission_id,
    }),
  });
  equal(mission.status, 200, "governed production submission completes");
  check(["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(mission.json.state), "admission is the terminal authority");
  equal(mission.json.response_contract.expected_literal, expectedLiteral, "terminal UI projection preserves the requested literal");
  equal(mission.json.worker.exact_response.expected_response_sha256, expectedHash, "worker evidence preserves the expected hash");
  equal(mission.json.worker.exact_response.observed_response_sha256, expectedHash, "worker observed hash exactly matches");
  equal(mission.json.verifier.verdict, "GREEN", "independent verifier is GREEN");
  equal(mission.json.verifier.exact_response.expected_response_sha256, expectedHash, "verifier recomputes the same expected hash");
  equal(mission.json.verifier.exact_response.observed_response_sha256, expectedHash, "verifier recomputes the same observed hash");
  equal(mission.json.verifier.exact_response.independently_recomputed, true, "verifier records independent recomputation");
  equal(mission.json.preservation.status, "PRESERVED", "preservation completes before admission");
  check(Boolean(mission.json.admission.receipt_id), "admission receipt identity exists");
  const queuePath = path.join(root, "fleet", "missions", mission.json.queue_state, `${mission.json.mission_id}.r${mission.json.mission_revision}.json`);
  check(existsSync(queuePath), "final canonical queue record remains readable");
  const queueSha256 = sha256(readFileSync(queuePath));
  equal(git("status", "--short", "--untracked-files=all").stdout.trim(), "", "generated queue evidence does not dirty the source worktree");

  stopResult = runPowerShell(stopScript);
  equal(stopResult.status, 0, "Stop succeeds for the exact owner");
  await waitForExit(startChild);
  const doctorAfterStop = doctor(true);
  equal(doctorAfterStop.value.process_owner.disposition, "ABSENT", "post-Stop owner is absent");
  equal(doctorAfterStop.value.listener_state.listeners.length, 0, "post-Stop listener is absent");
  equal(doctorAfterStop.value.active_child.length, 0, "post-Stop owned child is absent");
  check(existsSync(queuePath), "Stop preserves canonical queue evidence");
  equal(sha256(readFileSync(queuePath)), queueSha256, "Stop leaves canonical queue bytes unchanged");
  equal(git("status", "--short", "--untracked-files=all").stdout.trim(), "", "post-Stop Git status remains clean");

  writeFileSync(sentinel, "bounded unrelated source sentinel\n", "utf8");
  const sentinelStatus = git("status", "--short", "--untracked-files=all", "--", path.relative(root, sentinel)).stdout.trim();
  check(sentinelStatus.startsWith("??"), "unrelated untracked sentinel remains visible to Git");
  const doctorWithSentinel = doctor(true);
  equal(doctorWithSentinel.value.safe_to_start, false, "Doctor becomes unsafe for genuine unrelated source dirtiness");
  rmSync(sentinel, { force: true });
  const doctorFinal = doctor(true);
  check(doctorFinal.value.safe_to_start, "Doctor returns to the prior safe disposition after removing only the sentinel");
  check(existsSync(queuePath), "sentinel cleanup preserves canonical runtime evidence");
  equal(sha256(readFileSync(queuePath)), queueSha256, "runtime evidence remains byte-identical after cleanliness proof");

  const output = {
    schema_version: "tsf_hq_dispatch_production_hotfix_proof_v1",
    status: "PASS",
    assertions,
    started_utc: startedUtc,
    finished_utc: new Date().toISOString(),
    candidate: { head: candidateHead, tree: candidateTree, branch: candidateBranch || null, worktree: root, detached: candidateBranch === "" },
    doctor_before: { exit_code: doctorBefore.exit_code, status: doctorBefore.value.overall_status, safe_to_start: doctorBefore.value.safe_to_start, stdout_sha256: sha256(doctorBefore.stdout), human_exit_code: doctorBeforeHuman.exit_code, human_stdout_sha256: sha256(doctorBeforeHuman.stdout) },
    start: { foreground_process_id: startChild.pid, server_instance: serverDoctor.value.process_owner.owner?.server_instance_id ?? null, server_process_id: serverDoctor.value.process_owner.owner?.process_id ?? null, listener: "127.0.0.1:4317", stdout_sha256: sha256(startStdout), stderr_sha256: sha256(startStderr) },
    submission: { submission_id: preview.json.submission_id, preview_id: preview.json.preview_id, preview_sha256: preview.json.preview_sha256, request_sha256: preview.json.request_hash, expected_literal: expectedLiteral, expected_literal_sha256: expectedHash },
    mission: { mission_id: mission.json.mission_id, mission_revision: mission.json.mission_revision, run_id: mission.json.run_id, result_id: mission.json.result_id, state: mission.json.state, queue_state: mission.json.queue_state, queue_path: queuePath, queue_sha256: queueSha256, terminal_source_path: mission.json.source_path },
    worker: { app_server_process_id: mission.json.worker?.process_id ?? null, thread_id: mission.json.worker?.thread_id ?? null, turn_id: mission.json.worker?.turn_id ?? null, expected_response_sha256: mission.json.worker?.exact_response?.expected_response_sha256 ?? null, observed_response_sha256: mission.json.worker?.exact_response?.observed_response_sha256 ?? null },
    verifier: mission.json.verifier,
    preservation: mission.json.preservation,
    admission: mission.json.admission,
    stop: { exit_code: stopResult.status, stdout_sha256: sha256(stopResult.stdout), stderr_sha256: sha256(stopResult.stderr) },
    doctor_final: { status: doctorFinal.value.overall_status, safe_to_start: doctorFinal.value.safe_to_start, owner: doctorFinal.value.process_owner.disposition, listeners: doctorFinal.value.listener_state.listeners.length, owned_children: doctorFinal.value.active_child.length, queue_root: doctorFinal.value.canonical_queue_root, queue_inventory: doctorFinal.value.checks.find((item) => item.id === "runtime_queue_evidence_policy")?.evidence ?? null },
    git: { before: initialStatus, after: git("status", "--short", "--untracked-files=all").stdout.trim(), sentinel_detected: true },
    authority: { permission_mode: "READ_ONLY", control_plane_network: "CODEX_SERVICE_ONLY", worker_tool_network: "DISABLED", product_repository_used: false, plugin_used: false, credential_used: false, deployment_used: false },
  };
  process.stdout.write(`${JSON.stringify(output, null, 2)}\n`);
} finally {
  rmSync(sentinel, { force: true });
  if (startChild?.exitCode === null) {
    runPowerShell(stopScript);
    try { await waitForExit(startChild, 15_000); } catch { startChild.kill(); }
  }
}
