import { request as httpRequest } from "node:http";
import { randomUUID } from "node:crypto";
import { readdirSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { startHqDispatchServerForTest } from "../tools/hq-dispatch/v1/server.mjs";

const root = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const proofId = `proof-${randomUUID()}`;
const queueRoot = path.join(root, ".codex-local", "fixtures", "hq-dispatch-m2-real", proofId, "queue");

function request(port, { method = "GET", pathname = "/", token = null, origin = null, body = null } = {}) {
  return new Promise((resolve, reject) => {
    const req = httpRequest({
      host: "127.0.0.1", port, method, path: pathname,
      headers: {
        Accept: "application/json", Connection: "close",
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

const server = await startHqDispatchServerForTest({ testOnlyQueueRoot: queueRoot, workerTimeoutSeconds: 180 });
let serverClosed = false;
try {
  const port = server.address().port;
  const origin = `http://127.0.0.1:${port}`;
  const session = await request(port, { method: "POST", pathname: "/api/v1/session", origin, body: "{}" });
  if (session.status !== 200) throw new Error(`SESSION_FAILED_${session.status}`);
  const token = session.json.session_token;
  const naturalRequest = "Run the bounded TSF-local read-only HQ Dispatch vertical slice.";
  const preview = await request(port, { method: "POST", pathname: "/api/v1/route-preview", token, origin, body: JSON.stringify({ natural_request: naturalRequest }) });
  if (preview.status !== 200) throw new Error(`PREVIEW_FAILED_${preview.status}`);
  const mission = await request(port, {
    method: "POST", pathname: "/api/v1/missions", token, origin,
    body: JSON.stringify({
      natural_request: naturalRequest,
      preview_id: preview.json.preview_id,
      preview_sha256: preview.json.preview_sha256,
      request_hash: preview.json.request_hash,
      intent: "CREATE_GOVERNED_MISSION",
      submission_id: preview.json.submission_id,
    }),
  });
  const events = mission.json.mission_id
    ? await request(port, { pathname: `/api/v1/missions/${mission.json.mission_id}/events` })
    : { status: 0, json: null };
  const cleanup = await server.hqDispatchShutdown();
  await new Promise((resolve) => server.close(resolve));
  serverClosed = true;
  const queueFiles = readdirSync(queueRoot, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(entry.parentPath, entry.name));
  const runId = mission.json.run_id;
  const runtimeClaims = mission.json.worker?.observation_claims ?? {};
  for (const [name, claim] of Object.entries(runtimeClaims)) {
    if (claim.run_id !== runId) throw new Error(`CROSS_RUN_OBSERVATION_CLAIM_${name}`);
  }
  const observationClaims = {
    product_repository_policy: { classification: "POLICY_PROHIBITED", value: false, source: "terminal authority explicitly denies product repository access", run_id: runId },
    product_repository_access: runtimeClaims.product_repository_access ?? { classification: "NOT_OBSERVED", value: null, source: "no authoritative runtime read audit", run_id: runId },
    plugin_policy: { classification: "POLICY_PROHIBITED", value: false, source: "terminal authority explicitly denies plugins", run_id: runId },
    plugin_use: runtimeClaims.plugin_use ?? { classification: "NOT_OBSERVED", value: null, source: "no authoritative runtime plugin audit", run_id: runId },
    credential_policy: { classification: "POLICY_PROHIBITED", value: false, source: "terminal authority explicitly denies credentials", run_id: runId },
    credential_access: runtimeClaims.credential_access ?? { classification: "NOT_OBSERVED", value: null, source: "no authoritative runtime credential audit", run_id: runId },
    worker_tool_network: runtimeClaims.worker_tool_network ?? { classification: "UNKNOWN", value: null, source: "missing canonical worker network observation", run_id: runId },
    external_network_access: runtimeClaims.external_network_access ?? { classification: "NOT_OBSERVED", value: null, source: "no authoritative runtime network-use audit", run_id: runId },
    filesystem_writes: runtimeClaims.filesystem_writes ?? { classification: "UNKNOWN", value: null, source: "missing lifecycle filesystem observation", run_id: runId },
    detached_or_unowned_child: { classification: cleanup.child_exited ? "OBSERVED_NOT_USED" : "UNKNOWN", value: cleanup.child_exited ? false : null, source: "HQ Dispatch foreground cleanup result", run_id: runId },
    listener_remaining: { classification: server.listening ? "UNKNOWN" : "OBSERVED_NOT_USED", value: server.listening ? null : false, source: "Node server listening state after close callback", run_id: runId },
  };
  process.stdout.write(JSON.stringify({
    schema_version: "tsf_hq_dispatch_real_readonly_http_proof_v1",
    submission_id: preview.json.submission_id,
    http_status: mission.status,
    final_status: mission.json,
    events: events.json,
    queue_fixture_root: queueRoot,
    queue_file_count: queueFiles.length,
    queue_files: queueFiles,
    foreground_cleanup: cleanup,
    exact_response: {
      expected_response_sha256: mission.json.worker?.exact_response?.expected_response_sha256 ?? null,
      observed_response_sha256: mission.json.worker?.exact_response?.observed_response_sha256 ?? null,
      worker_exact_match: mission.json.worker?.exact_response?.exact_match ?? null,
      verifier_exact_match: mission.json.verifier?.exact_response?.exact_match ?? null,
      verifier_independently_recomputed: mission.json.verifier?.exact_response?.independently_recomputed ?? null,
    },
    observation_claims: observationClaims,
  }, null, 2));
  process.stdout.write("\n");
  if (mission.status !== 200 || !["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(mission.json.state)) process.exitCode = 1;
} finally {
  if (!serverClosed) await new Promise((resolve) => server.close(resolve));
}
