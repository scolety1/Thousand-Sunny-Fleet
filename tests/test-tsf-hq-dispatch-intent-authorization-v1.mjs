import assert from "node:assert/strict";
import { request as httpRequest } from "node:http";
import { startHqDispatchServerForTest } from "../tools/hq-dispatch/v1/server.mjs";

let assertions = 0;
function check(value, message) { assertions += 1; assert.ok(value, message); }
function equal(actual, expected, message) { assertions += 1; assert.equal(actual, expected, message); }

function request(port, { method = "GET", pathname = "/", token = null, origin = null, value = null } = {}) {
  return new Promise((resolve, reject) => {
    const body = value === null ? null : JSON.stringify(value);
    const req = httpRequest({
      host: "127.0.0.1", port, method, path: pathname,
      headers: {
        Accept: "application/json", Connection: "close",
        ...(origin ? { Origin: origin } : {}),
        ...(token ? { "X-TSF-HQ-Session": token } : {}),
        ...(body !== null ? { "Content-Type": "application/json", "Content-Length": Buffer.byteLength(body) } : {}),
      },
    }, (res) => {
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

const server = await startHqDispatchServerForTest();
try {
  const port = server.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const issued = await request(port, { method: "POST", pathname: "/api/v1/session", origin, value: {} });
  equal(issued.status, 200, "same-origin session issued");
  const token = issued.json.session_token;

  const blockedMatrix = [
    ["Edit this file.", ["FILE_EDIT", "WORKSPACE_WRITE"]],
    ["Add a source file, commit the changes, and push the branch.", ["FILE_CREATE", "COMMIT", "GIT_WRITE", "PUSH"]],
    ["Delete the generated file and commit the change.", ["FILE_DELETE", "COMMIT", "GIT_WRITE"]],
    ["Move and rename the file.", ["PATH_RENAME_MOVE", "WORKSPACE_WRITE"]],
    ["Modify code.", ["FILE_EDIT", "WORKSPACE_WRITE"]],
    ["Merge the PR.", ["MERGE", "GIT_WRITE"]],
    ["Install a package.", ["INSTALLATION"]],
    ["Deploy the application.", ["DEPLOYMENT"]],
    ["Fix this but only inspect it if you cannot write.", ["FILE_EDIT", "WORKSPACE_WRITE"]],
    ["Make the change.", ["WORKSPACE_WRITE"]],
    ["Prepare and commit.", ["COMMIT", "GIT_WRITE"]],
    ["Update this repository.", ["WORKSPACE_WRITE"]],
    ["Review the source and then edit it.", ["FILE_EDIT", "WORKSPACE_WRITE", "READ_ANALYSIS"]],
    ["Use the plugin to inspect status.", ["PLUGIN_OPERATION"]],
    ["Read and use the API key credential.", ["CREDENTIAL_ACCESS"]],
    ["Read the local source file and explain it.", ["READ_FILE"]],
  ];
  for (const [naturalRequest, requiredOperations] of blockedMatrix) {
    const preview = await request(port, { method: "POST", pathname: "/api/v1/route-preview", token, origin, value: { natural_request: naturalRequest } });
    equal(preview.status, 200, `preview is returned for governed decision: ${naturalRequest}`);
    equal(preview.json.submission_gate, "TIM_REQUIRED_NO_QUEUE", `submission gate blocks: ${naturalRequest}`);
    equal(preview.json.scope_transformation.queue_allowed, false, `scope contract denies queue: ${naturalRequest}`);
    equal(preview.json.scope_transformation.operator_confirmation_required, true, `explicit decision required: ${naturalRequest}`);
    equal(preview.json.task_completion_contract, null, `no completion contract is minted for blocked scope: ${naturalRequest}`);
    equal(preview.json.artifact.queue_record, false, `preview artifact is not a queue record: ${naturalRequest}`);
    for (const operation of requiredOperations) {
      check(preview.json.original_operator_intent.explicitly_requested_operations.includes(operation), `original operation ${operation} retained: ${naturalRequest}`);
    }
    const submission = await request(port, {
      method: "POST", pathname: "/api/v1/missions", token, origin,
      value: {
        natural_request: naturalRequest,
        preview_id: preview.json.preview_id,
        preview_sha256: preview.json.preview_sha256,
        request_hash: preview.json.request_hash,
        intent: "CREATE_GOVERNED_MISSION",
        submission_id: preview.json.submission_id,
      },
    });
    equal(submission.status, 422, `blocked preview cannot create a mission or queue record: ${naturalRequest}`);
  }

  const exact = await request(port, { method: "POST", pathname: "/api/v1/route-preview", token, origin, value: { natural_request: "Return exactly TSF_GREEN." } });
  equal(exact.status, 200, "exact-literal preview succeeds");
  equal(exact.json.result_validation_mode, "EXACT_LITERAL_V1", "exact-literal contract remains unchanged");
  equal(exact.json.submission_gate, "SUBMITTABLE_AFTER_REVALIDATION", "exact-literal request remains queueable");

  const selfContained = await request(port, { method: "POST", pathname: "/api/v1/route-preview", token, origin, value: { natural_request: "Analyze this self-contained statement and return a summary." } });
  equal(selfContained.status, 200, "self-contained analysis preview succeeds");
  equal(selfContained.json.result_validation_mode, "GENERAL_RESULT_V2", "self-contained analysis receives V2 completion contract");
  equal(selfContained.json.scope_transformation.queue_allowed, true, "self-contained analysis is queueable");
  check(/^[a-f0-9]{64}$/.test(selfContained.json.task_completion_contract.task_completion_contract_identity_sha256), "task completion identity is visible");

  process.stdout.write(`TSF_HQ_DISPATCH_INTENT_AUTHORIZATION_PASS assertions=${assertions}\n`);
} finally {
  await server.hqDispatchShutdown();
  await new Promise((resolve) => server.close(resolve));
}
