import { strict as assert } from "node:assert";
import { spawn, spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { OWNER_PATH, inspectListeners, inspectProcess, readOwnership, runDoctor } from "../tools/hq-dispatch/v1/reliability.mjs";

const root = path.resolve(fileURLToPath(new URL("../", import.meta.url)));
const demo = path.join(root, "tools", "hq-dispatch", "v1", "demo.mjs");
const cli = path.join(root, "tools", "hq-dispatch", "v1", "reliability-cli.mjs");
const runtimeRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-demo-v1", "runtime");
const queueRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-demo-v1", "queue");
const beforeStatus = spawnSync("git.exe", ["-C", root, "status", "--porcelain=v1", "--untracked-files=all"], { encoding: "utf8", windowsHide: true }).stdout;
let assertions = 0;
function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }
async function waitFor(predicate, timeout = 15000) { const deadline = Date.now() + timeout; while (Date.now() < deadline) { if (await predicate()) return true; await new Promise((resolve) => setTimeout(resolve, 100)); } return false; }

const child = spawn(process.execPath, [demo, "--reset"], { cwd: root, windowsHide: true, detached: false, stdio: ["ignore", "pipe", "pipe"] });
let stdout = "";
let stderr = "";
child.stdout.on("data", (chunk) => { stdout += chunk; });
child.stderr.on("data", (chunk) => { stderr += chunk; });

try {
  check(await waitFor(() => existsSync(OWNER_PATH) && readOwnership().disposition === "ACTIVE_OWNER_CONFIRMED"), `demo owner became active: ${stderr}`);
  const ownership = readOwnership();
  const owner = ownership.owner;
  equal(owner.mode, "DEMO_FIXTURE_ONLY", "demo owner is explicitly labeled");
  equal(owner.host, "127.0.0.1", "listener host is fixed loopback");
  check(inspectListeners(owner.port).some((listener) => Number(listener.process_id) === owner.process_id && String(listener.host) === "127.0.0.1"), "exact owner owns the loopback listener");
  check(stdout.includes("FIXTURE BEHAVIOR"), "demo labels fixture behavior");
  check(stdout.includes("Canonical production-style mission roots are not used"), "demo discloses isolated roots");

  const health = await fetch(`http://${owner.host}:${owner.port}/health`).then((response) => response.json());
  equal(health.lifecycle_mode, "DEMO_FIXTURE_ONLY", "health labels demo mode");
  equal(health.server_instance_id, owner.server_instance_id, "health is bound to ownership instance");
  const origin = `http://${owner.host}:${owner.port}`;
  const sessionResponse = await fetch(`${origin}/api/v1/session`, { method: "POST", headers: { "Content-Type": "application/json", Origin: origin }, body: "{}" });
  equal(sessionResponse.status, 200, "fresh operator session is issued");
  const session = await sessionResponse.json();
  equal(session.operator_session_generation, owner.operator_session_generation, "session generation is owner-bound");

  const doctor = runDoctor({ runtimeRoot, queueRoot, ownerPath: OWNER_PATH, port: owner.port, allowDirtyForTest: true, demoMode: true });
  equal(doctor.process_owner.disposition, "ACTIVE_OWNER_CONFIRMED", "Doctor detects active owner");
  equal(doctor.safe_to_start, false, "Doctor rejects second Start");
  const second = spawnSync(process.execPath, [demo], { cwd: root, encoding: "utf8", windowsHide: true, timeout: 15000 });
  check(second.status !== 0, "second demo instance is rejected");
  equal(readOwnership().owner.server_instance_id, owner.server_instance_id, "second start does not replace owner evidence");

  const stop = spawnSync(process.execPath, [cli, "stop"], { cwd: root, encoding: "utf8", windowsHide: true, timeout: 30000 });
  equal(stop.status, 0, `bounded Stop succeeds: ${stop.stderr}`);
  const stopResult = JSON.parse(stop.stdout);
  equal(stopResult.status, "GREEN", "Stop reports exact cleanup GREEN");
  equal(stopResult.server_instance_id, owner.server_instance_id, "Stop targets exact instance");
  equal(stopResult.unrelated_processes_terminated, false, "Stop terminates no unrelated process");
  equal(stopResult.operator_session_invalidated, true, "Stop invalidates in-memory sessions");
  check(await waitFor(() => child.exitCode !== null), "foreground demo process exits");
  check(!inspectProcess(owner.process_id), "owned server process is gone");
  check(!inspectListeners(owner.port).some((listener) => Number(listener.process_id) === owner.process_id), "exact listener is closed");
  check(!existsSync(OWNER_PATH), "exact owner record is removed by owner");
  const afterStatus = spawnSync("git.exe", ["-C", root, "status", "--porcelain=v1", "--untracked-files=all"], { encoding: "utf8", windowsHide: true }).stdout;
  equal(afterStatus, beforeStatus, "Git state is unchanged by Start/Doctor/Stop proof");
} finally {
  if (child.exitCode === null) child.kill();
  await waitFor(() => child.exitCode !== null, 5000);
}

console.log(JSON.stringify({ schema_version: "tsf_hq_dispatch_start_doctor_stop_proof_v1", status: "PASS", assertions, fixture_behavior: true, real_app_server_behavior: false }, null, 2));
