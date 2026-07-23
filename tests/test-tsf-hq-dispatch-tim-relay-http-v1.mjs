import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { request as httpRequest } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { startHqDispatchServerForTest } from "../tools/hq-dispatch/v1/server.mjs";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const fixtureRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-m2b-http");
rmSync(fixtureRoot, { recursive: true, force: true });
mkdirSync(fixtureRoot, { recursive: true });
let assertions = 0;
let responseAdapterCalls = 0;

function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }
function hash(value) { return createHash("sha256").update(value).digest("hex"); }
function fileHash(file) { return hash(readFileSync(file)); }

function request(port, { method = "GET", pathname = "/", token = null, origin = null, body = null, headers = {} } = {}) {
  return new Promise((resolve, reject) => {
    const req = httpRequest({ host: "127.0.0.1", port, method, path: pathname, headers: { Accept: "application/json", Connection: "close", ...(origin ? { Origin: origin } : {}), ...(token ? { "X-TSF-HQ-Session": token } : {}), ...headers } }, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        const text = Buffer.concat(chunks).toString("utf8");
        resolve({ status: res.statusCode, json: text ? JSON.parse(text) : null });
      });
    });
    req.on("error", reject);
    req.end(body);
  });
}

const post = (port, pathname, token, origin, value, headers = {}) => request(port, { method: "POST", pathname, token, origin, headers: { "Content-Type": "application/json", ...headers }, body: typeof value === "string" ? value : JSON.stringify(value) });
const issueSession = (port, origin) => post(port, "/api/v1/session", null, origin, {});

function canonicalRequest(missionId, revision, kind, options = {}) {
  const runId = `canonical-result-${missionId}-${revision}`;
  const approval = kind === "APPROVAL_REQUIRED";
  const clarification = kind === "CLARIFICATION_REQUIRED";
  return {
    schema_version: "tsf_tim_required_request_v1",
    request_id: `timreq-${hash(`${missionId}|${kind}`).slice(0, 32)}`,
    request_kind: kind,
    mission_id: missionId,
    mission_revision: revision,
    run_id: runId,
    result_id: runId,
    repository: root,
    worktree: root,
    operation: approval ? "bounded_fixture_review" : clarification ? "provide_clarification" : "canonical_authority_decision",
    exact_paths: ["fleet/control/policy-manifest.v1.json"],
    access_level: "READ_ONLY",
    network_scope: { mission_policy: "PROHIBITED", control_plane: "CODEX_SERVICE_ONLY", worker_tool: "DISABLED" },
    surface: "CODEX",
    model: "gpt-5.6-terra",
    reason: clarification ? "One bounded clarification is required." : "One exact operator decision is required.",
    question: clarification ? "Confirm the exact TSF-local read-only fixture scope." : null,
    issued_at: "2026-07-15T00:00:00Z",
    expires_at: options.expired ? "2026-07-15T00:00:01Z" : "2099-01-01T00:00:00Z",
    usage_limit: { max_uses: 1, reuse_policy: "SINGLE_USE" },
    response_types: approval ? ["APPROVE_EXACT_REQUEST", "DENY_REQUEST"] : clarification ? ["PROVIDE_CLARIFICATION"] : ["DENY_REQUEST"],
    authority_not_included: ["merge", "push", "deploy", "production", "plugins", "credentials", "product_repository", "wildcard_paths", "wider_network", "wider_access"],
    original_run_terminal: true,
    worker_active: false,
    app_server_child_active: false,
    superseded: options.superseded ?? false,
    invalidated: false,
  };
}

function initialOutcome(kind, options = {}) {
  return async ({ missionId, missionRevision }) => {
    const dir = path.join(fixtureRoot, missionId, `r${missionRevision}`);
    mkdirSync(dir, { recursive: true });
    const paths = Object.fromEntries(["mission", "queue", "queueResult", "lifecycle", "packet", "manifest", "adapter", "verifier", "worker", "result", "receipt"].map((name) => [name, path.join(dir, `${name}.json`)]));
    const runId = `canonical-result-${missionId}-${missionRevision}`;
    const requestValue = canonicalRequest(missionId, missionRevision, kind, options);
    const lifecycle = { schema_version: "tsf_lifecycle_terminal_result_v1", terminal_status: "TIM_REQUIRED", final_decision: "TIM_REQUIRED", mission_id: missionId, mission_revision: missionRevision, run_id: runId, result_id: runId, worker_launched: false, worker_status: "NOT_RUN", adapter_result_path: "", verifier_verdict: "", preservation_status: "PRESERVED", preservation_packet_file: paths.packet, preservation_manifest_path: paths.manifest, evidence_preserved: true, blocked_reasons: [requestValue.reason], tim_required_request: requestValue };
    writeFileSync(paths.mission, JSON.stringify({ expires_at: requestValue.expires_at }));
    writeFileSync(paths.queue, JSON.stringify({ mission_id: missionId }));
    writeFileSync(paths.packet, JSON.stringify({ final_decision: "TIM_REQUIRED" }));
    writeFileSync(paths.manifest, JSON.stringify({ evidence: "synthetic" }));
    writeFileSync(paths.lifecycle, JSON.stringify(lifecycle));
    writeFileSync(paths.queueResult, JSON.stringify({ final_decision: "TIM_REQUIRED_QUEUE_PREFLIGHT_BLOCKED", blocked_reasons: [] }));
    const preparation = { mission_id: missionId, mission_revision: missionRevision, mission_path: paths.mission, queue_record_path: paths.queue, queue_result_path: paths.queueResult, lifecycle_result_path: paths.lifecycle, adapter_result_path: paths.adapter, verifier_result_path: paths.verifier, preservation_packet_path: paths.packet, mission_sha256: fileHash(paths.mission), queue_document_sha256: fileHash(paths.queue), run_id: runId, route: { worker_role: "researcher_source_tracer_worker", resolved_model: "gpt-5.6-terra", effort: "MEDIUM" }, access: { permission_mode: "READ_ONLY", network_policy: "PROHIBITED", control_plane_service_network_policy: "CODEX_SERVICE_ONLY", worker_tool_network_policy: "DISABLED", allowed_reads: ["fleet/control/policy-manifest.v1.json"], allowed_writes: [] } };
    return { preparation, processResult: { code: 1, child_exited: true }, queueResult: { final_decision: "TIM_REQUIRED_QUEUE_PREFLIGHT_BLOCKED", blocked_reasons: [] }, lifecycle, adapter: null, verifier: null, workerResult: null, durableResult: null };
  };
}

function revisedOutcome(missionId, revision, responseId) {
  const dir = path.join(fixtureRoot, missionId, `r${revision}`);
  mkdirSync(dir, { recursive: true });
  const paths = Object.fromEntries(["mission", "queue", "queueResult", "lifecycle", "packet", "manifest", "adapter", "verifier", "worker", "result", "receipt", "response", "ledger"].map((name) => [name, path.join(dir, `${name}.json`)]));
  const runId = `canonical-result-${missionId}-${revision}`;
  const threadId = `thread-${missionId}-r${revision}`;
  const turnId = `turn-${missionId}-r${revision}`;
  const adapter = { mission_id: missionId, mission_revision: revision, run_id: runId, result_id: runId, thread_id: threadId, turn_id: turnId, observed_model: "gpt-5.6-terra", canonical_resolved_effort: "MEDIUM", child_exited: true, no_orphan_process: true };
  const workerResult = { mission_id: missionId, files_touched: [], files_created: [], tests: [{ test_id: "hq-dispatch-read-only-exact-response", status: "PASS" }] };
  const verifier = { mission_id: missionId, verdict: "GREEN", verified: true };
  const durableResult = { mission_id: missionId, mission_revision: revision, result_id: runId, files_changed: [], tests: [{ test_id: "hq-dispatch-read-only-exact-response", status: "PASS" }] };
  const admission = { status: "ADMITTED_WITH_CAVEATS", result_id: runId, receipt_id: `receipt-${hash(runId).slice(0, 16)}`, admission_receipt_path: paths.receipt, reasons: ["Synthetic deterministic relay fixture admitted."], caveats: ["Synthetic adapter fixture."] };
  const lifecycle = { terminal_status: "COMPLETED_GREEN", final_decision: "GREEN", mission_id: missionId, mission_revision: revision, run_id: runId, result_id: runId, worker_launched: true, worker_status: "CODEX_APP_SERVER_WORKER_GREEN", worker_result_path: paths.worker, adapter_result_path: paths.adapter, verifier_verdict: "GREEN", preservation_status: "PRESERVED", preservation_packet_file: paths.packet, preservation_manifest_path: paths.manifest, evidence_preserved: true };
  for (const [file, value] of [[paths.mission, { mission_id: missionId }], [paths.queue, { mission_id: missionId }], [paths.adapter, adapter], [paths.worker, workerResult], [paths.verifier, verifier], [paths.result, durableResult], [paths.receipt, admission], [paths.packet, { final_decision: "GREEN" }], [paths.manifest, { evidence: "synthetic" }], [paths.lifecycle, lifecycle]]) writeFileSync(file, JSON.stringify(value));
  const queueResult = { final_queue_state: "complete_ready_for_gate", durable_result_path: paths.result, admission_receipt: admission };
  writeFileSync(paths.queueResult, JSON.stringify(queueResult));
  const preparation = { mission_id: missionId, mission_revision: revision, mission_path: paths.mission, queue_record_path: paths.queue, queue_result_path: paths.queueResult, lifecycle_result_path: paths.lifecycle, adapter_result_path: paths.adapter, verifier_result_path: paths.verifier, preservation_packet_path: paths.packet, mission_sha256: fileHash(paths.mission), queue_document_sha256: fileHash(paths.queue), run_id: runId, route: { worker_role: "researcher_source_tracer_worker", resolved_model: "gpt-5.6-terra", effort: "MEDIUM" }, access: { permission_mode: "READ_ONLY", network_policy: "PROHIBITED", control_plane_service_network_policy: "CODEX_SERVICE_ONLY", worker_tool_network_policy: "DISABLED", allowed_reads: ["fleet/control/policy-manifest.v1.json"], allowed_writes: [] } };
  return { preparation, processResult: { code: 0, child_exited: true }, queueResult, lifecycle, adapter, verifier, workerResult, durableResult, paths, responseId };
}

async function responseAdapter({ input }) {
  responseAdapterCalls += 1;
  const dir = path.join(fixtureRoot, input.mission_id, `response-r${input.mission_revision}`);
  mkdirSync(dir, { recursive: true });
  const responsePath = path.join(dir, `${input.response_id}.json`);
  const targetRevision = input.response_type === "DENY_REQUEST" ? null : input.mission_revision + 1;
  const ledgerPath = path.join(dir, "approval-ledger.json");
  const approval = input.response_type === "APPROVE_EXACT_REQUEST" ? { approval_id: `approval-${hash(input.response_id).slice(0, 32)}`, ledger_path: ledgerPath, ledger_sha256: "a".repeat(64), authority_source: "CANONICAL_TSF_APPROVAL_LEDGER" } : null;
  if (approval) writeFileSync(ledgerPath, JSON.stringify({ schema_version: 1, approvals: [{ approval_id: approval.approval_id }] }));
  const response = { schema_version: "tsf_hq_dispatch_tim_response_wrapper_result_v1", response_id: input.response_id, response_type: input.response_type, response_content_sha256: input.response_content_sha256, request_id: input.tim_required_request_id, response_record_path: responsePath, response_record_sha256: "b".repeat(64), terminal_disposition: input.response_type === "DENY_REQUEST" ? "TIM_REQUIRED_DENIED" : input.response_type === "APPROVE_EXACT_REQUEST" ? "EXACT_APPROVAL_RELAYED" : "CLARIFICATION_RECORDED", approval, revision: targetRevision ? { mission_id: input.mission_id, mission_revision: targetRevision, run_id: `canonical-result-${input.mission_id}-${targetRevision}`, mission_path: path.join(dir, "mission.json"), queue_record_path: path.join(dir, "queue.json") } : null, idempotent_replay: false, original_result_unchanged: true, worker_resumed: false };
  writeFileSync(responsePath, JSON.stringify(response));
  return { response, outcome: targetRevision ? revisedOutcome(input.mission_id, targetRevision, input.response_id) : null };
}

function submission(natural, preview) {
  return { natural_request: natural, preview_id: preview.preview_id, preview_sha256: preview.preview_sha256, request_hash: preview.request_hash, intent: "CREATE_GOVERNED_MISSION", submission_id: preview.submission_id };
}

async function createTim(server, natural) {
  const port = server.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const issued = await issueSession(port, origin);
  equal(issued.status, 200, "operator session acquired");
  const token = issued.json.session_token;
  const preview = await post(port, "/api/v1/route-preview", token, origin, { natural_request: natural });
  equal(preview.status, 200, "route preview succeeds");
  const tim = await post(port, "/api/v1/missions", token, origin, submission(natural, preview.json));
  equal(tim.status, 200, "governed mission reaches TIM_REQUIRED");
  equal(tim.json.state, "TIM_REQUIRED", "canonical TIM_REQUIRED is visible");
  return { port, origin, token, tim: tim.json };
}

function responseBody(tim, type, payload = null, override = {}) {
  return { mission_id: tim.mission_id, mission_revision: tim.mission_revision, run_id: tim.run_id, result_id: tim.result_id, tim_required_request_id: tim.tim_request.request_id, request_evidence_sha256: tim.tim_request.evidence_sha256, response_id: tim.tim_request.response_id, response_type: type, operator_confirmation: { APPROVE_EXACT_REQUEST: "APPROVE EXACT REQUEST", DENY_REQUEST: "DENY REQUEST", PROVIDE_CLARIFICATION: "PROVIDE CLARIFICATION" }[type], response_payload: payload, ...override };
}

async function close(server) { await server.hqDispatchShutdown(); await new Promise((resolve) => server.close(resolve)); }

const approvalServer = await startHqDispatchServerForTest({ executionAdapter: initialOutcome("APPROVAL_REQUIRED"), responseAdapter });
try {
  const context = await createTim(approvalServer, "Return the bounded HTTP approval-relay fixture result.");
  const { port, origin, token, tim } = context;
  const endpoint = `/api/v1/missions/${tim.mission_id}/tim-response`;
  equal(tim.tim_request.request_kind, "APPROVAL_REQUIRED", "approval kind rendered exactly");
  equal(tim.tim_request.response_types.join("|"), "APPROVE_EXACT_REQUEST|DENY_REQUEST", "approval controls are compatibility-bound");
  check(/^hq-response-/.test(tim.tim_request.response_id), "response id is server generated");
  equal(tim.tim_request.original_run_terminal, true, "UI projection marks original run terminal");
  equal(fileHash(tim.tim_request.evidence_path), tim.tim_request.evidence_sha256, "request evidence hash binds exact terminal bytes");
  const exact = responseBody(tim, "APPROVE_EXACT_REQUEST");
  equal((await post(port, endpoint, null, origin, exact)).status, 403, "missing session token rejected");
  equal((await post(port, endpoint, "wrong-token-that-is-long-enough-000000000000", origin, exact)).status, 403, "wrong session token rejected");
  equal((await post(port, endpoint, token, "http://evil.invalid", exact)).status, 403, "wrong Origin rejected");
  equal((await request(port, { method: "POST", pathname: endpoint, token, origin, headers: { Host: `localhost:${port}`, "Content-Type": "application/json" }, body: JSON.stringify(exact) })).status, 403, "wrong Host rejected");
  equal((await request(port, { method: "POST", pathname: endpoint, token, origin, body: JSON.stringify(exact) })).status, 415, "non-JSON response rejected");
  equal((await post(port, endpoint, token, origin, "{")).status, 400, "malformed response JSON rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, command: "whoami" })).status, 422, "caller command field rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, exact_paths: [".."] })).status, 422, "caller path broadening field rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, access_level: "WORKSPACE_WRITE" })).status, 422, "caller access broadening field rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, network_scope: "OPEN" })).status, 422, "caller network broadening field rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, expires_at: "2099-12-31T00:00:00Z" })).status, 422, "caller expiry extension field rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, mission_revision: 2 })).status, 422, "wrong revision rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, run_id: "wrong-run" })).status, 422, "wrong run rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, result_id: "wrong-result" })).status, 422, "wrong result rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, tim_required_request_id: "timreq-00000000000000000000000000000000" })).status, 422, "wrong request id rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, request_evidence_sha256: "0".repeat(64) })).status, 422, "changed evidence hash rejected");
  equal((await post(port, endpoint, token, origin, responseBody(tim, "PROVIDE_CLARIFICATION", "x"))).status, 422, "incompatible response type rejected");
  equal((await post(port, endpoint, token, origin, { ...exact, operator_confirmation: "approve" })).status, 422, "exact approval phrase required");
  const before = responseAdapterCalls;
  const [accepted, doubleClick] = await Promise.all([post(port, endpoint, token, origin, exact), post(port, endpoint, token, origin, exact)]);
  equal(accepted.status, 200, "exact approval response accepted");
  equal(doubleClick.status, 200, "concurrent exact response is idempotent");
  equal(responseAdapterCalls, before + 1, "concurrent double-click invokes one response relay");
  equal(accepted.json.state, "ADMITTED_WITH_CAVEATS", "new governed revision reaches canonical admission projection");
  equal(accepted.json.mission_revision, 2, "approval produces revision two");
  equal(accepted.json.prior_terminal.state, "TIM_REQUIRED", "old terminal result remains linked and visible");
  equal(accepted.json.response.terminal_disposition, "EXACT_APPROVAL_RELAYED", "canonical approval response remains linked");
  check(accepted.json.worker.thread_id.includes("-r2"), "new revision uses a new thread identity");
  check(accepted.json.worker.turn_id.includes("-r2"), "new revision uses a new turn identity");
  equal(accepted.json.verifier.verdict, "GREEN", "independent verifier is visible");
  equal(accepted.json.admission.verdict, "ADMITTED_WITH_CAVEATS", "admission receipt controls final state");
  equal((await post(port, endpoint, token, origin, exact)).json.duplicate_replay.exact_response_replay_returned, true, "answered exact response returns canonical existing outcome");
  equal((await post(port, endpoint, token, origin, { ...exact, response_type: "DENY_REQUEST", operator_confirmation: "DENY REQUEST" })).status, 409, "changed replay under one response id rejects");
  equal((await post(port, `/api/v1/missions/other-mission-0001/tim-response`, token, origin, exact)).status, 422, "cross-mission path response rejects");
} finally { await close(approvalServer); }

const denialServer = await startHqDispatchServerForTest({ executionAdapter: initialOutcome("APPROVAL_REQUIRED"), responseAdapter });
try {
  const { port, origin, token, tim } = await createTim(denialServer, "Return the bounded HTTP denial fixture result.");
  const endpoint = `/api/v1/missions/${tim.mission_id}/tim-response`;
  const body = responseBody(tim, "DENY_REQUEST", "Bounded operator reason.");
  const before = responseAdapterCalls;
  const denied = await post(port, endpoint, token, origin, body);
  equal(denied.status, 200, "denial accepted");
  equal(denied.json.state, "TIM_REQUIRED_DENIED", "denial status is explicit");
  equal(denied.json.response.approval, null, "denial creates no approval");
  equal(denied.json.response.revision, null, "denial creates no revision");
  equal(responseAdapterCalls, before + 1, "denial writes one response record");
  equal((await post(port, endpoint, token, origin, body)).json.duplicate_replay.exact_response_replay_returned, true, "exact denial replay is idempotent");
} finally { await close(denialServer); }

const clarificationServer = await startHqDispatchServerForTest({ executionAdapter: initialOutcome("CLARIFICATION_REQUIRED"), responseAdapter });
try {
  const { port, origin, token, tim } = await createTim(clarificationServer, "Return the bounded HTTP clarification fixture result.");
  const endpoint = `/api/v1/missions/${tim.mission_id}/tim-response`;
  equal(tim.tim_request.request_kind, "CLARIFICATION_REQUIRED", "clarification kind rendered exactly");
  equal(tim.tim_request.response_types.join("|"), "PROVIDE_CLARIFICATION", "only clarification control is compatible");
  equal((await post(port, endpoint, token, origin, responseBody(tim, "PROVIDE_CLARIFICATION", "api_key=abcdefghijklmnopqrstuvwxyz"))).status, 422, "secret-like clarification rejected");
  equal((await post(port, endpoint, token, origin, responseBody(tim, "PROVIDE_CLARIFICATION", "powershell.exe -Command whoami"))).status, 422, "executable clarification rejected");
  equal((await post(port, endpoint, token, origin, responseBody(tim, "PROVIDE_CLARIFICATION", "x".repeat(2001)))).status, 422, "oversized clarification rejected");
  const clarified = await post(port, endpoint, token, origin, responseBody(tim, "PROVIDE_CLARIFICATION", "Proceed with only the exact TSF-local read-only fixture."));
  equal(clarified.status, 200, "bounded clarification accepted");
  equal(clarified.json.mission_revision, 2, "clarification creates a new governed revision");
  equal(clarified.json.response.terminal_disposition, "CLARIFICATION_RECORDED", "clarification record remains linked");
  equal(clarified.json.prior_terminal.result_id, tim.result_id, "original terminal result identity remains linked");
  check(clarified.json.run_id !== tim.run_id, "clarification run identity is new");
  equal(clarified.json.verifier.verdict, "GREEN", "clarified revision is independently verified");
  equal(clarified.json.admission.verdict, "ADMITTED_WITH_CAVEATS", "clarified revision is canonically admitted");
} finally { await close(clarificationServer); }

const expiredServer = await startHqDispatchServerForTest({ executionAdapter: initialOutcome("CLARIFICATION_REQUIRED", { expired: true }), responseAdapter });
try {
  const { port, origin, token, tim } = await createTim(expiredServer, "Return the bounded expired-request fixture result.");
  equal((await post(port, `/api/v1/missions/${tim.mission_id}/tim-response`, token, origin, responseBody(tim, "PROVIDE_CLARIFICATION", "Bounded response."))).status, 422, "response after request expiry rejects");
} finally { await close(expiredServer); }

const supersededServer = await startHqDispatchServerForTest({ executionAdapter: initialOutcome("CLARIFICATION_REQUIRED", { superseded: true }), responseAdapter });
try {
  const { port, origin, token, tim } = await createTim(supersededServer, "Return the bounded superseded-request fixture result.");
  equal((await post(port, `/api/v1/missions/${tim.mission_id}/tim-response`, token, origin, responseBody(tim, "PROVIDE_CLARIFICATION", "Bounded response."))).status, 422, "response after supersession rejects");
} finally { await close(supersededServer); }

const html = readFileSync(path.join(root, "tools", "hq-dispatch", "v1", "public", "index.html"), "utf8");
const browser = readFileSync(path.join(root, "tools", "hq-dispatch", "v1", "public", "app.js"), "utf8");
for (const phrase of ["APPROVE EXACT REQUEST", "DENY REQUEST", "PROVIDE CLARIFICATION", "original run is terminal", "prior worker is never resumed", "Submission is not approval"]) check(`${html}\n${browser}`.includes(phrase), `UI renders required phrase: ${phrase}`);
for (const forbiddenControl of ["approval_ledger_path", "queue_root", "verifier_result", "admission_result", "allowed_writes", "network_policy_override"]) check(!html.includes(`name=\"${forbiddenControl}\"`), `UI has no editable ${forbiddenControl} control`);

console.log(JSON.stringify({ schema_version: "tsf_hq_dispatch_tim_relay_http_test_v1", assertions, status: "PASS", response_adapter_calls: responseAdapterCalls }));
