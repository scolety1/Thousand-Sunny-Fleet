import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  HqMissionRelay,
  createM3RealInterruptionBarrier,
} from "../tools/hq-dispatch/v1/mission-relay.mjs";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-m3-real-interruption-v1");
const fixtureType = "TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1";
const access = Object.freeze({
  permission_mode: "READ_ONLY",
  worker_tool_network_policy: "DISABLED",
  control_plane_service_network_policy: "CODEX_SERVICE_ONLY",
  allowed_writes: [],
  repository: root,
  product_repository_targeted: false,
});
let assertions = 0;

function check(value, message) {
  assertions += 1;
  assert.ok(value, message);
}

function throws(code, overrides = {}) {
  assertions += 1;
  assert.throws(() => createM3RealInterruptionBarrier({
    repositoryRoot: root,
    fixtureType,
    fixtureRoot,
    testRunIdentity: "run-safety-0001",
    access,
    inMemoryCapability: Object.freeze(Object.create(null)),
    onOwnedExecutor: async () => {},
    ...overrides,
  }), new RegExp(code));
}

function validBarrier(onOwnedExecutor = async () => {}) {
  return createM3RealInterruptionBarrier({
    repositoryRoot: root,
    fixtureType,
    fixtureRoot,
    testRunIdentity: "run-safety-0001",
    access,
    inMemoryCapability: Object.freeze(Object.create(null)),
    onOwnedExecutor,
  });
}

const productionRelay = new HqMissionRelay({
  repositoryRoot: root,
  powershellExe: "powershell.exe",
  invokePreview: async () => { throw new Error("NOT_USED"); },
});
check(productionRelay.testOnlyInterruptionBarrier === null, "production relay has no interruption barrier");

let directInjectionObserved = false;
const injected = validBarrier(async (context) => { directInjectionObserved = context.proof === true; return "READY"; });
const testRelay = new HqMissionRelay({
  repositoryRoot: root,
  powershellExe: "powershell.exe",
  invokePreview: async () => { throw new Error("NOT_USED"); },
  testOnlyInterruptionBarrier: injected,
});
check(testRelay.testOnlyInterruptionBarrier === injected, "branded direct in-memory injection is accepted");
check(await injected.onOwnedExecutor({ proof: true }) === "READY" && directInjectionObserved, "direct test injection invokes only its committed callback");

assertions += 1;
await assert.rejects(validBarrier(async () => { throw new Error("M3_REAL_APP_SERVER_BARRIER_MONITOR_FAILED:124"); }).onOwnedExecutor({}), /MONITOR_FAILED:124/);

throws("FIXTURE_IDENTITY_REJECTED", { fixtureType: "CHANGED_FIXTURE" });
throws("FIXTURE_ROOT_REJECTED", { fixtureRoot: path.join(root, ".codex-local", "fixtures", "another-root") });
throws("TEST_RUN_IDENTITY_REJECTED", { testRunIdentity: "bad" });
throws("IN_MEMORY_CAPABILITY_REQUIRED", { inMemoryCapability: null });
throws("FIXTURE_ACCESS_REJECTED", { access: { ...access, permission_mode: "WORKSPACE_WRITE" } });
throws("FIXTURE_ACCESS_REJECTED", { access: { ...access, worker_tool_network_policy: "ENABLED" } });
throws("FIXTURE_ACCESS_REJECTED", { access: { ...access, control_plane_service_network_policy: "PUBLIC" } });
throws("FIXTURE_ACCESS_REJECTED", { access: { ...access, allowed_writes: ["output.txt"] } });
throws("FIXTURE_ACCESS_REJECTED", { access: { ...access, repository: "C:\\Product", product_repository_targeted: true } });
throws("OWNED_EXECUTOR_HOOK_REQUIRED", { onOwnedExecutor: null });

assertions += 1;
assert.throws(() => new HqMissionRelay({
  repositoryRoot: root,
  powershellExe: "powershell.exe",
  invokePreview: async () => {},
  testOnlyInterruptionBarrier: Object.freeze({ fixture_type: fixtureType }),
}), /IN_MEMORY_CAPABILITY_REJECTED/);

const priorEnvironment = process.env.TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1;
process.env.TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1 = "enabled";
const environmentRelay = new HqMissionRelay({ repositoryRoot: root, powershellExe: "powershell.exe", invokePreview: async () => {} });
check(environmentRelay.testOnlyInterruptionBarrier === null, "environment variables cannot activate the barrier");
if (priorEnvironment === undefined) delete process.env.TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1;
else process.env.TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1 = priorEnvironment;

const forbiddenSurfaceFiles = [
  "tools/hq-dispatch/v1/Start-TsfHqDispatchV1.ps1",
  "tools/hq-dispatch/v1/Test-TsfHqDispatchDoctorV1.ps1",
  "tools/hq-dispatch/v1/Stop-TsfHqDispatchV1.ps1",
  "tools/hq-dispatch/v1/Start-TsfHqDispatchDemoV1.ps1",
  "tools/hq-dispatch/v1/public/app.js",
  "tools/hq-dispatch/v1/public/index.html",
];
for (const relative of forbiddenSurfaceFiles) {
  const source = readFileSync(path.join(root, relative), "utf8");
  check(!/InterruptionBarrier|REAL_INTERRUPTION_FIXTURE|BARRIER_READY/i.test(source), `${relative} cannot expose the barrier`);
}

const serverSource = readFileSync(path.join(root, "tools", "hq-dispatch", "v1", "server.mjs"), "utf8");
check(/server = createHqDispatchServer\(\{ lifecycle \}\)/.test(serverSource), "production main constructs the server without a test barrier");
check(!/process\.env[^\n]*InterruptionBarrier|url\.searchParams[^\n]*InterruptionBarrier|req\.headers[^\n]*InterruptionBarrier/i.test(serverSource), "HTTP, query, header, and environment paths cannot activate the barrier");
const relaySource = readFileSync(path.join(root, "tools", "hq-dispatch", "v1", "mission-relay.mjs"), "utf8");
check(!/naturalRequest[^\n]*testOnlyInterruptionBarrier|queue[^\n]*testOnlyInterruptionBarrier|response[^\n]*testOnlyInterruptionBarrier/i.test(relaySource), "mission, queue, approval, and clarification content cannot activate the barrier");

process.stdout.write(`${JSON.stringify({
  schema_version: "tsf_hq_dispatch_m3_interruption_barrier_safety_test_v1",
  status: "PASS",
  assertions,
  fixture_type: fixtureType,
  production_activation_surfaces: [],
})}\n`);
