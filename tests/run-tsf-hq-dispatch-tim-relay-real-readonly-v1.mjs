import { createHash, randomUUID } from "node:crypto";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { request as httpRequest } from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { startHqDispatchServerForTest } from "../tools/hq-dispatch/v1/server.mjs";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const proofId = `proof-${randomUUID()}`;
const queueRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-m2b-real", proofId, "queue");

function hashFile(filePath) {
  return createHash("sha256").update(readFileSync(filePath)).digest("hex");
}

function request(port, { method = "GET", pathname = "/", token = null, origin = null, body = null } = {}) {
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
        ...(body !== null ? { "Content-Type": "application/json" } : {}),
      },
    }, (res) => {
      const chunks = [];
      res.on("data", (chunk) => chunks.push(chunk));
      res.on("end", () => {
        const text = Buffer.concat(chunks).toString("utf8");
        resolve({ status: res.statusCode, json: JSON.parse(text) });
      });
    });
    req.on("error", reject);
    req.end(body);
  });
}

function post(port, pathname, token, origin, value) {
  return request(port, {
    method: "POST",
    pathname,
    token,
    origin,
    body: JSON.stringify(value),
  });
}

function assert(condition, message) {
  if (!condition) throw new Error(`REAL_PROOF_ASSERTION_FAILED:${message}`);
}

const server = await startHqDispatchServerForTest({
  testOnlyQueueRoot: queueRoot,
  testOnlyInitialTimKind: "CLARIFICATION",
  workerTimeoutSeconds: 180,
});
let serverClosed = false;
let cleanup = null;
try {
  const port = server.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const session = await post(port, "/api/v1/session", null, origin, {});
  assert(session.status === 200, "operator session acquired");
  const token = session.json.session_token;
  const naturalRequest = "Run the bounded TSF-local read-only HQ Dispatch clarification revision proof.";
  const preview = await post(port, "/api/v1/route-preview", token, origin, { natural_request: naturalRequest });
  assert(preview.status === 200, "route preview accepted");
  const initial = await post(port, "/api/v1/missions", token, origin, {
    natural_request: naturalRequest,
    preview_id: preview.json.preview_id,
    preview_sha256: preview.json.preview_sha256,
    request_hash: preview.json.request_hash,
    intent: "CREATE_GOVERNED_MISSION",
    submission_id: preview.json.submission_id,
  });
  assert(
    initial.status === 200 && initial.json.state === "TIM_REQUIRED",
    `initial revision terminal TIM_REQUIRED:${initial.status}:${JSON.stringify(initial.json)}`,
  );
  assert(initial.json.tim_request?.request_kind === "CLARIFICATION_REQUIRED", "canonical clarification request projected");
  assert(initial.json.tim_request?.original_run_terminal === true, "original run terminal");
  const originalEvidencePath = initial.json.tim_request.evidence_path;
  assert(existsSync(originalEvidencePath), "original terminal evidence exists");
  const originalBeforeSha256 = hashFile(originalEvidencePath);
  assert(originalBeforeSha256 === initial.json.tim_request.evidence_sha256, "request evidence hash exact");
  const originalTerminal = JSON.parse(readFileSync(originalEvidencePath, "utf8").replace(/^\uFEFF/, ""));
  assert(originalTerminal.tim_required_request?.worker_active === false, "original worker inactive");
  assert(originalTerminal.tim_required_request?.app_server_child_active === false, "original child inactive");

  const response = await post(
    port,
    `/api/v1/missions/${initial.json.mission_id}/tim-response`,
    token,
    origin,
    {
      mission_id: initial.json.mission_id,
      mission_revision: initial.json.mission_revision,
      run_id: initial.json.run_id,
      result_id: initial.json.result_id,
      tim_required_request_id: initial.json.tim_request.request_id,
      request_evidence_sha256: initial.json.tim_request.evidence_sha256,
      response_id: initial.json.tim_request.response_id,
      response_type: "PROVIDE_CLARIFICATION",
      operator_confirmation: "PROVIDE CLARIFICATION",
      response_payload: "Proceed only with the exact TSF-local read-only fixture and make no repository changes.",
    },
  );
  assert(response.status === 200, "clarification response accepted");
  assert(["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(response.json.state), "new revision admitted");
  assert(response.json.mission_revision === initial.json.mission_revision + 1, "new mission revision identity");
  assert(response.json.run_id !== initial.json.run_id, "new run identity");
  assert(response.json.result_id !== initial.json.result_id, "new result identity");
  assert(response.json.worker?.thread_id && response.json.worker.thread_id !== initial.json.worker?.thread_id, "new thread identity");
  assert(response.json.worker?.turn_id && response.json.worker.turn_id !== initial.json.worker?.turn_id, "new turn identity");
  assert(response.json.worker?.child_exited === true, "foreground child exited");
  assert(response.json.worker?.no_orphan_process === true, "no orphan process");
  assert(response.json.worker?.observation_claims?.worker_tool_network?.value === false, "worker-tool network disabled");
  assert(response.json.verifier?.verdict === "GREEN", "independent verifier green");
  assert(response.json.verifier?.verified === true, "independent verification complete");
  assert(["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(response.json.admission?.verdict), "canonical admission receipt visible");
  assert(response.json.response?.terminal_disposition === "CLARIFICATION_RECORDED", "canonical clarification response linked");
  assert(response.json.prior_terminal?.result_id === initial.json.result_id, "original terminal result linked");
  assert(hashFile(originalEvidencePath) === originalBeforeSha256, "original terminal evidence immutable");

  const events = await request(port, { pathname: `/api/v1/missions/${initial.json.mission_id}/events` });
  assert(events.status === 200, "linked event stream readable");
  cleanup = await server.hqDispatchShutdown();
  await new Promise((resolve) => server.close(resolve));
  serverClosed = true;
  assert(cleanup.child_exited === true, "server shutdown confirms child exited");
  assert(server.listening === false, "server listener closed");

  const queueFiles = readdirSync(queueRoot, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(entry.parentPath, entry.name));
  process.stdout.write(`${JSON.stringify({
    schema_version: "tsf_hq_dispatch_tim_relay_real_readonly_proof_v1",
    status: "PASS",
    proof_id: proofId,
    submission_id: preview.json.submission_id,
    mission_id: initial.json.mission_id,
    original: {
      mission_revision: initial.json.mission_revision,
      run_id: initial.json.run_id,
      result_id: initial.json.result_id,
      request_id: initial.json.tim_request.request_id,
      request_evidence_sha256: initial.json.tim_request.evidence_sha256,
      terminal_evidence_path: originalEvidencePath,
      terminal_evidence_sha256_before: originalBeforeSha256,
      terminal_evidence_sha256_after: hashFile(originalEvidencePath),
      state: initial.json.state,
    },
    response: {
      response_id: initial.json.tim_request.response_id,
      response_record_path: response.json.response.response_record_path,
      response_record_sha256: response.json.response.response_record_sha256,
      response_content_sha256: response.json.response.response_content_sha256,
      disposition: response.json.response.terminal_disposition,
    },
    revised: {
      mission_revision: response.json.mission_revision,
      run_id: response.json.run_id,
      result_id: response.json.result_id,
      thread_id: response.json.worker.thread_id,
      turn_id: response.json.worker.turn_id,
      queue_document_sha256: response.json.result.queue_document_sha256,
      durable_result_path: response.json.result.durable_result_path,
      durable_result_sha256: response.json.result.durable_result_sha256,
      verifier_verdict: response.json.verifier.verdict,
      verifier_result_path: response.json.verifier.result_path,
      verifier_result_sha256: response.json.verifier.result_sha256,
      admission_verdict: response.json.admission.verdict,
      admission_receipt_id: response.json.admission.receipt_id,
      admission_receipt_path: response.json.admission.receipt_path,
      admission_receipt_sha256: response.json.admission.receipt_sha256,
      exact_response: response.json.worker.exact_response,
    },
    route: response.json.route,
    access: response.json.access,
    authority: response.json.authority,
    observation_claims: response.json.worker.observation_claims,
    event_count: events.json.events.length,
    queue_fixture_root: queueRoot,
    queue_file_count: queueFiles.length,
    queue_files: queueFiles,
    foreground_cleanup: cleanup,
    listener_remaining: server.listening,
  }, null, 2)}\n`);
} finally {
  if (!serverClosed) {
    cleanup ??= await server.hqDispatchShutdown();
    await new Promise((resolve) => server.close(resolve));
  }
}
