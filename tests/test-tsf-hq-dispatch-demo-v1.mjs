import { strict as assert } from "node:assert";
import { mkdirSync, rmSync } from "node:fs";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { createDemoFixtureAdapters } from "../tools/hq-dispatch/v1/demo-fixtures.mjs";
import { startHqDispatchServerForTest } from "../tools/hq-dispatch/v1/server.mjs";

const root = path.resolve(fileURLToPath(new URL("../", import.meta.url)));
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-demo-http-v1");
const runtimeRoot = path.join(fixtureRoot, "runtime");
const queueRoot = path.join(fixtureRoot, "queue");
rmSync(fixtureRoot, { recursive: true, force: true });
mkdirSync(runtimeRoot, { recursive: true });
mkdirSync(queueRoot, { recursive: true });
const adapters = createDemoFixtureAdapters({ fixtureRoot, repositoryRoot: root, queueRoot, runtimeRoot });
let assertions = 0;
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }
function check(value, message) { assertions += 1; assert.ok(value, message); }

function request(port, { method = "GET", pathname = "/", token = null, origin = null, body = null } = {}) {
  return new Promise((resolve, reject) => {
    const headers = { Host: `127.0.0.1:${port}`, Accept: "application/json" };
    if (origin) headers.Origin = origin;
    if (token) headers["X-TSF-HQ-Session"] = token;
    if (body !== null) headers["Content-Type"] = "application/json";
    const req = http.request({ host: "127.0.0.1", port, method, path: pathname, headers }, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => { const text = Buffer.concat(chunks).toString("utf8"); resolve({ status: res.statusCode, json: text ? JSON.parse(text) : null }); });
    });
    req.on("error", reject);
    if (body !== null) req.end(JSON.stringify(body)); else req.end();
  });
}

async function preview(port, origin, token, naturalRequest) {
  const response = await request(port, { method: "POST", pathname: "/api/v1/route-preview", token, origin, body: { natural_request: naturalRequest } });
  equal(response.status, 200, "Milestone 1 route preview succeeds");
  equal(response.json.banner, "PREVIEW_ONLY_NOT_AUTHORITY", "preview remains non-authoritative");
  return response.json;
}

function submission(naturalRequest, route) {
  return { natural_request: naturalRequest, preview_id: route.preview_id, preview_sha256: route.preview_sha256, request_hash: route.request_hash, intent: "CREATE_GOVERNED_MISSION", submission_id: route.submission_id };
}

const server = await startHqDispatchServerForTest({ executionAdapter: adapters.executionAdapter, responseAdapter: adapters.responseAdapter });
try {
  const port = server.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const issued = await request(port, { method: "POST", pathname: "/api/v1/session", origin, body: {} });
  equal(issued.status, 200, "demo operator session issued without credential");
  const token = issued.json.session_token;

  const executionRequest = "Demonstrate deterministic fixture execution without plugins, credentials, or external network.";
  const executionPreview = await preview(port, origin, token, executionRequest);
  const executed = await request(port, { method: "POST", pathname: "/api/v1/missions", token, origin, body: submission(executionRequest, executionPreview) });
  equal(executed.status, 200, "Milestone 2A fixture submission succeeds");
  equal(executed.json.state, "ADMITTED_WITH_CAVEATS", "fixture reaches a labeled admission projection");
  equal(executed.json.worker.model, "DETERMINISTIC_FIXTURE_NO_MODEL", "real model/app-server behavior is not claimed");
  equal(executed.json.admission.caveats[0].includes("Fixture behavior"), true, "admission labels fixture behavior");

  const timRequest = "TIM REQUIRED deterministic response fixture.";
  const timPreview = await preview(port, origin, token, timRequest);
  const tim = await request(port, { method: "POST", pathname: "/api/v1/missions", token, origin, body: submission(timRequest, timPreview) });
  equal(tim.status, 200, "Milestone 2B fixture reaches canonical request projection");
  equal(tim.json.state, "TIM_REQUIRED", "TIM_REQUIRED is explicit");
  equal(tim.json.tim_request.response_types.join("|"), "PROVIDE_CLARIFICATION", "only compatible response is offered");
  const responseBody = { mission_id: tim.json.mission_id, mission_revision: tim.json.mission_revision, run_id: tim.json.run_id, result_id: tim.json.result_id, tim_required_request_id: tim.json.tim_request.request_id, request_evidence_sha256: tim.json.tim_request.evidence_sha256, response_id: tim.json.tim_request.response_id, response_type: "PROVIDE_CLARIFICATION", operator_confirmation: "PROVIDE CLARIFICATION", response_payload: "Proceed with only the deterministic TSF-local fixture." };
  const answered = await request(port, { method: "POST", pathname: `/api/v1/missions/${tim.json.mission_id}/tim-response`, token, origin, body: responseBody });
  equal(answered.status, 200, "bounded clarification response succeeds");
  equal(answered.json.mission_revision, 2, "response creates a new revision");
  check(answered.json.run_id !== tim.json.run_id, "response creates a new run identity");
  equal(answered.json.prior_terminal.state, "TIM_REQUIRED", "original terminal run remains linked");
  equal(answered.json.worker.thread_id.includes("-r2"), true, "new fixture thread identity is distinct");
  const replay = await request(port, { method: "POST", pathname: `/api/v1/missions/${tim.json.mission_id}/tim-response`, token, origin, body: responseBody });
  equal(replay.status, 200, "exact duplicate response is idempotent");
  equal(replay.json.duplicate_replay.exact_response_replay_returned, true, "canonical existing response is returned");
  equal(server.hqDispatchRelay.activeChild, null, "demo leaves no child process");
} finally {
  await server.hqDispatchShutdown();
  await new Promise((resolve) => server.close(resolve));
}

console.log(JSON.stringify({ schema_version: "tsf_hq_dispatch_demo_proof_v1", status: "PASS", assertions, fixture_root: fixtureRoot, product_repository_used: false, plugin_used: false, credential_used: false, external_network_used: false, real_app_server_behavior: false }, null, 2));
