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
  const queueFiles = readdirSync(queueRoot, { recursive: true, withFileTypes: true })
    .filter((entry) => entry.isFile())
    .map((entry) => path.join(entry.parentPath, entry.name));
  process.stdout.write(JSON.stringify({
    schema_version: "tsf_hq_dispatch_real_readonly_http_proof_v1",
    http_status: mission.status,
    final_status: mission.json,
    events: events.json,
    queue_fixture_root: queueRoot,
    queue_file_count: queueFiles.length,
    queue_files: queueFiles,
    foreground_cleanup: cleanup,
    product_repository_used: false,
    plugin_used: false,
    worker_tool_network_enabled: false,
  }, null, 2));
  process.stdout.write("\n");
  if (mission.status !== 200 || !["ADMITTED", "ADMITTED_WITH_CAVEATS"].includes(mission.json.state)) process.exitCode = 1;
} finally {
  await new Promise((resolve) => server.close(resolve));
}
