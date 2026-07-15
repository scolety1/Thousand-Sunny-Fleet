import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { request as httpRequest } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { startHqDispatchServerForTest } from "../tools/hq-dispatch/v1/server.mjs";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-m2-http");
rmSync(fixtureRoot, { recursive: true, force: true });
mkdirSync(fixtureRoot, { recursive: true });
let assertions = 0;
let executionCount = 0;

function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }
function hashFileText(value) { return createHash("sha256").update(value).digest("hex"); }

function request(port, { method = "GET", pathname = "/", token = null, origin = null, body = null, headers = {} } = {}) {
  return new Promise((resolve, reject) => {
    const req = httpRequest({
      host: "127.0.0.1",
      port,
      method,
      path: pathname,
      headers: {
        Accept: "application/json",
        Connection: "close",
        ...(origin ? { Origin: origin } : {}),
        ...(token ? { "X-TSF-HQ-Session": token } : {}),
        ...headers,
      },
    }, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        const text = Buffer.concat(chunks).toString("utf8");
        resolve({ status: res.statusCode, headers: res.headers, json: text ? JSON.parse(text) : null });
      });
    });
    req.on("error", reject);
    req.end(body);
  });
}

async function session(port, origin) {
  return request(port, { method: "POST", pathname: "/api/v1/session", origin, headers: { "Content-Type": "application/json" }, body: "{}" });
}

async function post(port, pathname, token, origin, value) {
  return request(port, { method: "POST", pathname, token, origin, headers: { "Content-Type": "application/json" }, body: typeof value === "string" ? value : JSON.stringify(value) });
}

function preparation(missionId, revision, evidencePath) {
  return {
    mission_id: missionId,
    mission_revision: revision,
    mission_path: evidencePath.mission,
    queue_record_path: evidencePath.queue,
    queue_result_path: evidencePath.queueResult,
    lifecycle_result_path: evidencePath.lifecycle,
    adapter_result_path: evidencePath.adapter,
    verifier_result_path: evidencePath.verifier,
    preservation_packet_path: evidencePath.packet,
    mission_sha256: hashFileText(readFileSync(evidencePath.mission)),
    queue_document_sha256: hashFileText(readFileSync(evidencePath.queue)),
    run_id: `canonical-result-${missionId}-${revision}`,
    route: { worker_role: "researcher_source_tracer_worker", model_alias: "BALANCED", resolved_model: "gpt-5.6-terra", effort: "MEDIUM", assurance: "RECOMMENDED_ONLY" },
    access: { permission_mode: "READ_ONLY", network_policy: "PROHIBITED", control_plane_service_network_policy: "CODEX_SERVICE_ONLY", worker_tool_network_policy: "DISABLED", allowed_reads: ["fleet/control/policy-manifest.v1.json"], allowed_writes: [] },
  };
}

async function syntheticOutcome({ missionId, missionRevision }) {
  executionCount += 1;
  const dir = path.join(fixtureRoot, `${missionId}-r${missionRevision}`);
  mkdirSync(dir, { recursive: true });
  const paths = Object.fromEntries(["mission", "queue", "queueResult", "lifecycle", "adapter", "verifier", "worker", "result", "admission", "packet", "manifest"].map((name) => [name, path.join(dir, `${name}.json`)]));
  writeFileSync(paths.mission, JSON.stringify({ expires_at: "2099-01-01T00:00:00Z" }));
  writeFileSync(paths.queue, "{}");
  const prep = preparation(missionId, missionRevision, paths);
  if (executionCount === 1) {
    await new Promise((resolve) => setTimeout(resolve, 75));
    const workerResult = { files_touched: [], files_created: [], tests: [{ test_id: "hq-dispatch-read-only-exact-response", status: "PASS", evidence: "fixture-event-hash" }] };
    const durableResult = { files_changed: [], tests: [{ test_id: "hq-dispatch-read-only-exact-response", status: "PASS", evidence_classification: "KERNEL_OBSERVED" }] };
    const adapter = { thread_id: "thread-synthetic-1", turn_id: "turn-synthetic-1", observed_model: "gpt-5.6-terra", canonical_resolved_effort: "MEDIUM", child_exited: true, no_orphan_process: true };
    const verifier = { verdict: "GREEN", verified: true };
    const admission = { status: "ADMITTED_WITH_CAVEATS", result_id: prep.run_id, admission_receipt_path: paths.admission, reasons: ["Canonical fixture admitted."], caveats: ["Synthetic adapter fixture."] };
    const lifecycle = { worker_status: "CODEX_APP_SERVER_WORKER_GREEN", worker_result_path: paths.worker, verifier_verdict: "GREEN", preservation_status: "PRESERVED", preservation_packet_file: paths.packet, preservation_manifest_path: paths.manifest, evidence_preserved: true };
    writeFileSync(paths.worker, JSON.stringify(workerResult));
    writeFileSync(paths.result, JSON.stringify(durableResult));
    writeFileSync(paths.adapter, JSON.stringify(adapter));
    writeFileSync(paths.verifier, JSON.stringify(verifier));
    writeFileSync(paths.admission, JSON.stringify(admission));
    writeFileSync(paths.packet, JSON.stringify({ final_decision: "GREEN" }));
    writeFileSync(paths.manifest, JSON.stringify({ evidence: "fixture" }));
    writeFileSync(paths.lifecycle, JSON.stringify(lifecycle));
    writeFileSync(paths.queueResult, JSON.stringify({ final_queue_state: "completed", durable_result_path: paths.result, admission_receipt: admission }));
    return {
      preparation: prep,
      processResult: { code: 0, child_exited: true, no_orphan_process: true },
      queueResult: { final_queue_state: "completed", durable_result_path: paths.result, admission_receipt: admission },
      lifecycle,
      adapter,
      verifier,
      workerResult,
      durableResult,
    };
  }
  if (executionCount === 2) {
    const lifecycle = { terminal_status: "TIM_REQUIRED", approval_semantics: "APPROVAL_REQUIRED", worker_status: "NOT_RUN", verifier_verdict: "", preservation_status: "PRESERVED", preservation_packet_file: paths.packet, preservation_manifest_path: paths.manifest, evidence_preserved: true, blocked_reasons: ["Missing active approval for exact action: bounded_fixture_review"] };
    writeFileSync(paths.packet, JSON.stringify({ final_decision: "TIM_REQUIRED" }));
    writeFileSync(paths.manifest, JSON.stringify({ evidence: "fixture" }));
    writeFileSync(paths.lifecycle, JSON.stringify(lifecycle));
    writeFileSync(paths.queueResult, JSON.stringify({ final_decision: "TIM_REQUIRED_QUEUE_PREFLIGHT_BLOCKED" }));
    return { preparation: prep, processResult: { code: 1, child_exited: true, no_orphan_process: true }, queueResult: { final_decision: "TIM_REQUIRED_QUEUE_PREFLIGHT_BLOCKED", blocked_reasons: [] }, lifecycle, adapter: null, verifier: null };
  }
  const lifecycle = { terminal_status: "COMPLETED_WITH_CAVEATS", worker_status: "CODEX_APP_SERVER_WORKER_GREEN", preservation_status: "PRESERVED", preservation_packet_file: paths.packet, preservation_manifest_path: paths.manifest, evidence_preserved: true };
  writeFileSync(paths.packet, JSON.stringify({ final_decision: "GREEN" }));
  writeFileSync(paths.manifest, JSON.stringify({ evidence: "fixture" }));
  writeFileSync(paths.lifecycle, JSON.stringify(lifecycle));
  writeFileSync(paths.queueResult, JSON.stringify({ final_queue_state: "completed", final_decision: "WORKER_GREEN_WITHOUT_ADMISSION" }));
  return { preparation: prep, processResult: { code: 0, child_exited: true, no_orphan_process: true }, queueResult: { final_queue_state: "completed", final_decision: "WORKER_GREEN_WITHOUT_ADMISSION" }, lifecycle, adapter: { child_exited: true, no_orphan_process: true }, verifier: null };
}

async function mismatchedIdentityOutcome({ missionId, missionRevision }, { crossRunClaim = false } = {}) {
  const dir = path.join(fixtureRoot, `mismatch-${missionId}-r${missionRevision}`);
  mkdirSync(dir, { recursive: true });
  const paths = Object.fromEntries(["mission", "queue", "queueResult", "lifecycle", "adapter", "verifier", "worker", "result", "admission", "packet", "manifest"].map((name) => [name, path.join(dir, `${name}.json`)]));
  writeFileSync(paths.mission, JSON.stringify({ expires_at: "2099-01-01T00:00:00Z" }));
  writeFileSync(paths.queue, "{}");
  const prep = preparation(missionId, missionRevision, paths);
  const suppliedResultId = crossRunClaim ? prep.run_id : "canonical-result-another-mission-1";
  const claims = crossRunClaim ? { filesystem_writes: { classification: "OBSERVED_NOT_USED", value: false, source: "synthetic", run_id: "canonical-result-another-mission-1" } } : null;
  const admission = { status: "ADMITTED", result_id: suppliedResultId, admission_receipt_path: paths.admission, reasons: [], caveats: [] };
  return {
    preparation: prep,
    processResult: { code: 0, child_exited: true },
    queueResult: { final_queue_state: "complete_ready_for_gate", admission_receipt: admission },
    lifecycle: { worker_status: "CODEX_APP_SERVER_WORKER_GREEN", preservation_status: "PRESERVED" },
    adapter: claims ? { observation_claims: claims } : null,
    verifier: { verdict: "GREEN", verified: true },
    workerResult: null,
    durableResult: null,
  };
}

async function closeServer(server) {
  await server.hqDispatchShutdown();
  await new Promise((resolve) => server.close(resolve));
}

function submissionFor(naturalRequest, preview) {
  return {
    natural_request: naturalRequest,
    preview_id: preview.json.preview_id,
    preview_sha256: preview.json.preview_sha256,
    request_hash: preview.json.request_hash,
    intent: "CREATE_GOVERNED_MISSION",
    submission_id: preview.json.submission_id,
  };
}

const server = await startHqDispatchServerForTest({ executionAdapter: syntheticOutcome });
try {
  const port = server.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const natural = "Review bounded TSF local documentation.";
  const getPreview = (requestText) => post(port, "/api/v1/route-preview", token, origin, { natural_request: requestText });

  equal((await session(port, "http://evil.invalid")).status, 403, "cross-origin session acquisition rejected");
  equal((await request(port, { method: "POST", pathname: "/api/v1/session", origin, headers: { Host: `localhost:${port}`, "Content-Type": "application/json" }, body: "{}" })).status, 403, "wrong Host rejected");
  equal((await request(port, { method: "POST", pathname: "/api/v1/session", origin, headers: { "Content-Type": "application/json" }, body: JSON.stringify({ token: "caller" }) })).status, 400, "session acquisition rejects unknown fields");
  const issued = await session(port, origin);
  equal(issued.status, 200, "same-origin session acquired");
  const token = issued.json.session_token;
  check(token.length >= 32, "session token is cryptographically sized");
  equal(issued.headers["access-control-allow-origin"], undefined, "permissive CORS absent");
  equal((await post(port, "/api/v1/route-preview", null, origin, { natural_request: natural })).status, 403, "missing token rejected");
  equal((await post(port, "/api/v1/route-preview", "short", origin, { natural_request: natural })).status, 403, "malformed token rejected");
  equal((await post(port, "/api/v1/route-preview", "wrong-token-value-that-is-long-enough-000000", origin, { natural_request: natural })).status, 403, "wrong token rejected");
  equal((await post(port, "/api/v1/route-preview", token, "http://evil.invalid", { natural_request: natural })).status, 403, "wrong Origin rejected");
  equal((await request(port, { method: "POST", pathname: "/api/v1/route-preview", token, origin, body: "{}" })).status, 415, "non-JSON state change rejected");
  equal((await post(port, "/api/v1/route-preview", token, origin, "{")).status, 400, "malformed JSON rejected");
  equal((await post(port, "/api/v1/route-preview", token, origin, { natural_request: "x", command: "whoami" })).status, 400, "route preview closed schema rejects caller command");
  equal((await post(port, "/api/v1/route-preview", token, origin, { natural_request: "x".repeat(9000) })).status, 413, "oversized request rejected");

  const forbiddenFields = {
    executable: "cmd.exe", script: "echo unsafe", arguments: ["x"], environment: { A: "B" },
    queue_root: "elsewhere", output_path: "elsewhere", mission_envelope: {}, verifier_result: { verdict: "GREEN" },
    approval_state: "APPROVED", admission_state: "ADMITTED", thread_id: "caller", repository_path: "C:/product",
  };
  const preview = await getPreview(natural);
  equal(preview.status, 200, "reviewed preview succeeds");
  check(/^[a-f0-9]{64}$/.test(preview.json.preview_sha256), "preview artifact hash returned");
  check(/^[a-f0-9]{64}$/.test(preview.json.request_hash), "request hash returned");
  check(preview.json.submission_id.startsWith("hq-submission-"), "submission id is server generated");
  const submission = submissionFor(natural, preview);
  for (const [field, value] of Object.entries(forbiddenFields)) {
    equal((await post(port, "/api/v1/missions", token, origin, { ...submission, [field]: value })).status, 422, `caller field ${field} rejected`);
  }

  async function rejectedBoundSubmission(label, mutate) {
    const requestText = `${natural} ${label}`;
    const candidate = await getPreview(requestText);
    const body = submissionFor(requestText, candidate);
    mutate(body, candidate);
    return post(port, "/api/v1/missions", token, origin, body);
  }
  equal((await rejectedBoundSubmission("request mismatch", (body) => { body.request_hash = "0".repeat(64); })).status, 422, "request hash mismatch rejected");
  equal((await rejectedBoundSubmission("preview mismatch", (body) => { body.preview_sha256 = "0".repeat(64); })).status, 422, "preview hash mismatch rejected");
  equal((await rejectedBoundSubmission("intent mismatch", (body) => { body.intent = "PREVIEW_ONLY"; })).status, 422, "wrong intent rejected");

  async function tamperPreview(label, mutate, remove = false) {
    const requestText = `${natural} tamper ${label}`;
    const candidate = await getPreview(requestText);
    const artifactPath = path.resolve(root, ...candidate.json.artifact.relative_path.split("/"));
    const original = readFileSync(artifactPath);
    try {
      if (remove) rmSync(artifactPath);
      else {
        const value = JSON.parse(original.toString("utf8"));
        mutate(value);
        writeFileSync(artifactPath, JSON.stringify(value));
      }
      return await post(port, "/api/v1/missions", token, origin, submissionFor(requestText, candidate));
    } finally {
      writeFileSync(artifactPath, original);
    }
  }
  equal((await tamperPreview("missing", () => {}, true)).status, 422, "missing preview artifact rejected");
  equal((await tamperPreview("role", (value) => { value.proposed_worker_role.role_id = "auditor_worker"; })).status, 422, "altered role preview rejected");
  equal((await tamperPreview("model", (value) => { value.model_routing.resolved_model = "caller-model"; })).status, 422, "altered model preview rejected");
  equal((await tamperPreview("authority", (value) => { value.authority.preview_only = false; })).status, 422, "promoted preview classification rejected");

  const [admitted, doubleClick] = await Promise.all([
    post(port, "/api/v1/missions", token, origin, submission),
    post(port, "/api/v1/missions", token, origin, submission),
  ]);
  equal(admitted.status, 200, "bounded governed mission completes");
  equal(doubleClick.json.mission_id, admitted.json.mission_id, "concurrent double-click returns one mission");
  equal(executionCount, 1, "concurrent double-click invokes one executor");
  equal(admitted.json.state, "ADMITTED_WITH_CAVEATS", "admission receipt controls final state");
  equal(admitted.json.worker.thread_id, "thread-synthetic-1", "thread identity projected");
  equal(admitted.json.worker.no_orphan_process, true, "canonical adapter cleanup projected");
  equal(admitted.json.worker.changed_paths.length, 0, "read-only changed paths projected exactly");
  equal(admitted.json.worker.created_paths.length, 0, "read-only created paths projected exactly");
  equal(admitted.json.worker.tests[0].status, "PASS", "worker test evidence projected");
  check(/^[a-f0-9]{64}$/.test(admitted.json.result.durable_result_sha256), "durable result hash projected");
  check(/^[a-f0-9]{64}$/.test(admitted.json.verifier.result_sha256), "verifier result hash projected");
  check(/^[a-f0-9]{64}$/.test(admitted.json.preservation.packet_sha256), "preservation hash projected");
  check(existsSync(admitted.json.admission.receipt_path), "canonical admission receipt path projected");
  equal(hashFileText(readFileSync(admitted.json.admission.receipt_path)), admitted.json.admission.receipt_sha256, "canonical admission receipt bytes independently hashed");
  equal(admitted.json.admission.caveats[0], "Synthetic adapter fixture.", "admission caveat visible");
  equal(admitted.json.authority.granted.length, 0, "submission grants no authority");
  check(admitted.json.authority.explicitly_denied.includes("product repository access"), "product repository authority explicitly denied");
  equal(JSON.stringify(admitted.json).includes(token), false, "session token absent from result projection");
  equal((await post(port, "/api/v1/missions", token, origin, submission)).json.mission_id, admitted.json.mission_id, "identical submission is idempotent");
  equal((await post(port, "/api/v1/missions", token, origin, { ...submission, natural_request: "Changed" })).status, 409, "changed replay under submission id rejected");

  const repeatedPreview = await getPreview(natural);
  const completedReplay = await post(port, "/api/v1/missions", token, origin, submissionFor(natural, repeatedPreview));
  equal(completedReplay.json.mission_id, admitted.json.mission_id, "completed identical submission reuses canonical terminal mission");
  equal(completedReplay.json.result_id, admitted.json.result_id, "completed replay preserves the same terminal result identity");
  equal(completedReplay.json.duplicate_replay.completed_identical_submission_returned, true, "completed replay is explicit");
  equal(executionCount, 1, "completed replay creates no second execution");
  equal((await request(port, { pathname: `/api/v1/missions/${admitted.json.mission_id}` })).json.state, "ADMITTED_WITH_CAVEATS", "mission status projection readable");
  const events = (await request(port, { pathname: `/api/v1/missions/${admitted.json.mission_id}/events` })).json.events;
  for (const state of ["PREPARING", "VERIFYING", "PRESERVING", "ADMITTED_WITH_CAVEATS"]) check(events.some((event) => event.state === state), `${state} event projected`);
  check(events.every((event) => Object.hasOwn(event, "canonical_source_record") && Object.hasOwn(event, "source_path") && Object.hasOwn(event, "result_id") && event.timestamp && event.assurance && event.explanation), "event contract retains source, time, result identity field, assurance, and explanation");
  check(events.filter((event) => event.state !== "ADMITTED_WITH_CAVEATS").every((event) => event.result_id === null), "pre-result events do not invent result identity");
  equal(events.find((event) => event.state === "ADMITTED_WITH_CAVEATS").result_id, admitted.json.result_id, "terminal event retains exact canonical result identity");

  const crossSessionPreview = await getPreview(`${natural} cross session`);
  const secondSession = await session(port, origin);
  equal((await post(port, "/api/v1/missions", secondSession.json.session_token, origin, submissionFor(`${natural} cross session`, crossSessionPreview))).status, 422, "preview cannot cross operator sessions");

  const timNatural = `${natural} TIM projection`;
  const timPreview = await getPreview(timNatural);
  const tim = await post(port, "/api/v1/missions", token, origin, submissionFor(timNatural, timPreview));
  equal(tim.json.state, "TIM_REQUIRED", "canonical TIM_REQUIRED projected without alternate response state");
  equal(tim.json.tim_request.original_run_stopped, true, "original TIM run stopped");
  equal(createHash("sha256").update(readFileSync(tim.json.tim_request.evidence_path)).digest("hex"), tim.json.tim_request.evidence_sha256, "TIM evidence hash binds exact preserved request");
  equal((await post(port, `/api/v1/missions/${tim.json.mission_id}/responses`, token, origin, {})).status, 404, "typed response endpoint is deferred rather than partially authoritative");

  const unacceptedNatural = `${natural} worker-only result`;
  const unacceptedPreview = await getPreview(unacceptedNatural);
  const unaccepted = await post(port, "/api/v1/missions", token, origin, submissionFor(unacceptedNatural, unacceptedPreview));
  equal(unaccepted.json.state, "REJECTED", "worker success without admission remains unaccepted");
  equal(unaccepted.json.admission, null, "missing admission receipt is visible and never fabricated");
  equal(unaccepted.json.result_id, null, "rejected status does not invent terminal result identity");
  equal(unaccepted.json.result.result_id, null, "rejected nested result does not inherit run identity");
} finally {
  await closeServer(server);
}

const mismatchServer = await startHqDispatchServerForTest({ executionAdapter: (input) => mismatchedIdentityOutcome(input) });
try {
  const port = mismatchServer.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const issued = await session(port, origin);
  const preview = await post(port, "/api/v1/route-preview", issued.json.session_token, origin, { natural_request: "Reject a cross-run result identity." });
  const result = await post(port, "/api/v1/missions", issued.json.session_token, origin, submissionFor("Reject a cross-run result identity.", preview));
  check(!["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(result.json.state), "result identity from another mission/run fails closed before projection");
} finally {
  await closeServer(mismatchServer);
}

const claimServer = await startHqDispatchServerForTest({ executionAdapter: (input) => mismatchedIdentityOutcome(input, { crossRunClaim: true }) });
try {
  const port = claimServer.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const issued = await session(port, origin);
  const preview = await post(port, "/api/v1/route-preview", issued.json.session_token, origin, { natural_request: "Reject a cross-run observation claim." });
  const result = await post(port, "/api/v1/missions", issued.json.session_token, origin, submissionFor("Reject a cross-run observation claim.", preview));
  check(!["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(result.json.state), "cross-run observation substitution fails closed");
} finally {
  await closeServer(claimServer);
}

const browserSource = readFileSync(path.join(root, "tools", "hq-dispatch", "v1", "public", "app.js"), "utf8");
const browserHtml = readFileSync(path.join(root, "tools", "hq-dispatch", "v1", "public", "index.html"), "utf8");
const browserText = `${browserSource}\n${browserHtml}`;
check(browserSource.includes("result_id: status.result_id"), "browser projection retains the API result identity");
check(browserText.includes("bounded governed TSF-local read-only missions"), "UI truthfully describes governed bounded submission as available");
check(browserText.includes("Arbitrary repositories and general commands") && browserText.includes("remain unavailable"), "UI keeps arbitrary/general execution unavailable");
check(browserText.includes("deferred to Milestone 2B"), "UI keeps approval, denial, and clarification responses deferred");
check(browserText.includes("Submission is not approval") && browserText.includes("worker completion is not admission"), "UI separates submission, worker completion, and admission");
check(browserText.includes("canonical admission receipt is terminal truth"), "UI names the canonical admission receipt as terminal truth");
check(!browserText.includes("mission submission, and mission execution are unavailable"), "obsolete Milestone 1-only wording is absent");

let testNow = 1000;
const expiryServer = await startHqDispatchServerForTest({ executionAdapter: syntheticOutcome, sessionOptions: { ttlMs: 10, now: () => testNow } });
try {
  const port = expiryServer.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const issued = await session(port, origin);
  testNow += 11;
  equal((await post(port, "/api/v1/route-preview", issued.json.session_token, origin, { natural_request: "Expired session must fail." })).status, 403, "expired token rejected");
} finally {
  await closeServer(expiryServer);
}

const rateServer = await startHqDispatchServerForTest({ executionAdapter: syntheticOutcome, sessionOptions: { rateLimit: 1 } });
try {
  const port = rateServer.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const issued = await session(port, origin);
  equal((await post(port, "/api/v1/route-preview", issued.json.session_token, origin, { natural_request: "First bounded request." })).status, 200, "first request within rate bound succeeds");
  equal((await post(port, "/api/v1/route-preview", issued.json.session_token, origin, { natural_request: "Second bounded request." })).status, 403, "bounded session rate enforced");
} finally {
  await closeServer(rateServer);
}

const shutdownServer = await startHqDispatchServerForTest({ executionAdapter: syntheticOutcome });
try {
  const port = shutdownServer.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const issued = await session(port, origin);
  const cleanup = await shutdownServer.hqDispatchShutdown();
  equal(cleanup.child_exited, true, "shutdown reports no owned foreground child remains");
  equal((await post(port, "/api/v1/route-preview", issued.json.session_token, origin, { natural_request: "Old session must fail." })).status, 403, "shutdown invalidates session token");
  equal((await session(port, origin)).status, 503, "shutdown refuses new sessions");
} finally {
  await new Promise((resolve) => shutdownServer.close(resolve));
}

rmSync(fixtureRoot, { recursive: true, force: true });
process.stdout.write(`HQ_DISPATCH_M2_NODE_PASS assertions=${assertions}\n`);
