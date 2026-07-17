import { createHash, randomBytes, timingSafeEqual } from "node:crypto";
import { existsSync, readFileSync, mkdirSync, statSync } from "node:fs";
import { createServer } from "node:http";
import { spawn } from "node:child_process";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { HqMissionRelay } from "./mission-relay.mjs";
import {
  CANONICAL_QUEUE_ROOT,
  CANONICAL_RUNTIME_ROOT,
  HQ_HOST,
  HQ_PORT,
  LOCAL_LIFECYCLE_ROOT,
  OWNER_PATH,
  POWERSHELL_EXE as RELIABILITY_POWERSHELL_EXE,
  ProcessOwnership,
  REPOSITORY_ROOT as RELIABILITY_REPOSITORY_ROOT,
  performRecoveryAction,
  reconcileCanonicalState,
  runDoctor,
  writeInterruptionEvidence,
} from "./reliability.mjs";

const LOOPBACK_HOST = HQ_HOST;
const PRODUCTION_PORT = HQ_PORT;
const MAX_REQUEST_BYTES = 8192;
const MAX_WRAPPER_OUTPUT_BYTES = 1024 * 1024;
const WRAPPER_TIMEOUT_MS = 15000;
const SESSION_TTL_MS = 30 * 60 * 1000;
const SESSION_RATE_WINDOW_MS = 60 * 1000;
const SESSION_RATE_LIMIT = 60;
const SESSION_HEADER = "x-tsf-hq-session";
const POWERSHELL_EXE = RELIABILITY_POWERSHELL_EXE;
const REPOSITORY_ROOT = path.resolve(fileURLToPath(new URL("../../../", import.meta.url)));
if (REPOSITORY_ROOT !== RELIABILITY_REPOSITORY_ROOT) throw new Error("HQ_DISPATCH_REPOSITORY_ROOT_DIVERGENCE");
const PUBLIC_ROOT = path.join(REPOSITORY_ROOT, "tools", "hq-dispatch", "v1", "public");
const PREVIEW_ROOT = path.join(REPOSITORY_ROOT, ".codex-local", "hq-dispatch", "preview");
const ROUTE_PREVIEW_WRAPPER = path.join(
  REPOSITORY_ROOT,
  "tools",
  "hq-dispatch",
  "v1",
  "Invoke-TsfHqDispatchRoutePreview.ps1",
);

const FIXED_FILES = Object.freeze({
  workerRoles: "fleet/control/worker-role-registry.v1.json",
  modelPolicy: "fleet/control/model-routing-alias-policy.v1.json",
  skillRegistry: "fleet/control/hq-dispatch/hq-dispatch-skill-registry.v1.json",
  actionRegistry: "fleet/control/hq-dispatch/hq-dispatch-setup-action-registry.v1.json",
});

const PROJECTABLE_SOURCE_PATHS = new Set([
  "docs/codex/FLEET_SKILL_MAP.md",
  "skills/code-review-and-quality.md",
  "skills/frontend-ui-engineering.md",
  "skills/incremental-implementation.md",
  "skills/planning-and-task-breakdown.md",
  "skills/shipping-and-launch.md",
  "docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md",
  "docs/fleet/ui/FLEET_CONSOLE_STATUS_AND_ACTION_MODEL.md",
  "docs/fleet/ui/FLEET_CONSOLE_BUTTON_ACTION_POLICY.md",
]);

const STATIC_FILES = new Map([
  ["/", ["index.html", "text/html; charset=utf-8"]],
  ["/index.html", ["index.html", "text/html; charset=utf-8"]],
  ["/styles.css", ["styles.css", "text/css; charset=utf-8"]],
  ["/app.js", ["app.js", "text/javascript; charset=utf-8"]],
]);

const COMMON_HEADERS = Object.freeze({
  "Cache-Control": "no-store",
  "Content-Security-Policy":
    "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
  "Cross-Origin-Resource-Policy": "same-origin",
  "Referrer-Policy": "no-referrer",
  "X-Content-Type-Options": "nosniff",
  "X-Frame-Options": "DENY",
});

function fixedPath(relativePath) {
  const known = Object.values(FIXED_FILES).includes(relativePath) ||
    PROJECTABLE_SOURCE_PATHS.has(relativePath);
  if (!known) {
    throw new Error("UNRECOGNIZED_FIXED_SOURCE");
  }
  const resolved = path.resolve(REPOSITORY_ROOT, ...relativePath.split("/"));
  const prefix = REPOSITORY_ROOT.endsWith(path.sep)
    ? REPOSITORY_ROOT
    : `${REPOSITORY_ROOT}${path.sep}`;
  if (!resolved.startsWith(prefix)) {
    throw new Error("FIXED_SOURCE_ESCAPES_REPOSITORY");
  }
  return resolved;
}

function parseFixedJson(relativePath) {
  const text = readFileSync(fixedPath(relativePath), "utf8").replace(/^\uFEFF/, "");
  return JSON.parse(text);
}

function sha256File(relativePath) {
  return createHash("sha256")
    .update(readFileSync(fixedPath(relativePath)))
    .digest("hex");
}

function observeSource(relativePath, expectedSha256 = null) {
  const fullPath = fixedPath(relativePath);
  const observedSha256 = sha256File(relativePath);
  const stat = statSync(fullPath);
  return {
    path: relativePath,
    expected_sha256: expectedSha256,
    observed_sha256: observedSha256,
    freshness:
      expectedSha256 === null
        ? "DIRECT_READ_AT_REQUEST_TIME"
        : observedSha256 === expectedSha256
          ? "SOURCE_HASH_MATCH"
          : "SOURCE_HASH_MISMATCH",
    modified_at: stat.mtime.toISOString(),
  };
}

function buildRegistryProjection() {
  const workerRoles = parseFixedJson(FIXED_FILES.workerRoles);
  const modelPolicy = parseFixedJson(FIXED_FILES.modelPolicy);
  const skillRegistry = parseFixedJson(FIXED_FILES.skillRegistry);
  const actionRegistry = parseFixedJson(FIXED_FILES.actionRegistry);

  const observed = new Map();
  const addObservation = (relativePath, expectedSha256 = null) => {
    const key = `${relativePath}:${expectedSha256 ?? "direct"}`;
    if (!observed.has(key)) {
      observed.set(key, observeSource(relativePath, expectedSha256));
    }
  };

  for (const relativePath of Object.values(FIXED_FILES)) {
    addObservation(relativePath);
  }
  for (const source of skillRegistry.sources) {
    if (!PROJECTABLE_SOURCE_PATHS.has(source.path)) {
      throw new Error("SKILL_REGISTRY_SOURCE_NOT_ALLOWLISTED");
    }
    addObservation(source.path, source.sha256);
  }
  for (const source of actionRegistry.sources) {
    if (!PROJECTABLE_SOURCE_PATHS.has(source.path)) {
      throw new Error("ACTION_REGISTRY_SOURCE_NOT_ALLOWLISTED");
    }
    addObservation(source.path, source.sha256);
  }

  return {
    schema_version: "tsf_hq_dispatch_registry_projection_response_v1",
    generated_at: new Date().toISOString(),
    banner: "PREVIEW_ONLY_NOT_AUTHORITY",
    registry_sources: [...observed.values()],
    worker_roles: {
      source_path: FIXED_FILES.workerRoles,
      registry: workerRoles,
    },
    model_routing_policy: {
      source_path: FIXED_FILES.modelPolicy,
      policy: modelPolicy,
    },
    skills: {
      source_path: FIXED_FILES.skillRegistry,
      registry: skillRegistry,
    },
    setup_actions: {
      source_path: FIXED_FILES.actionRegistry,
      registry: actionRegistry,
    },
    milestone_restrictions: {
      posture: "MILESTONE_2_BOUNDED_GOVERNED_OPERATOR_BRIDGE",
      plugin_access_enabled: false,
      plugin_registry_projected: false,
      credential_access_enabled: false,
      environment_enumeration_enabled: false,
      live_ai_service_access_enabled: false,
      external_repository_access_enabled: false,
      mission_submission_enabled: true,
      mission_execution_enabled: true,
      arbitrary_repository_execution_enabled: false,
      one_active_mission_per_process: true,
      worker_tool_network_enabled: false,
    },
  };
}

function errorPayload(code, message) {
  return {
    schema_version: "tsf_hq_dispatch_error_v1",
    banner: "PREVIEW_ONLY_NOT_AUTHORITY",
    error: { code, message },
  };
}

function send(res, statusCode, body, contentType, extraHeaders = {}) {
  const payload = Buffer.isBuffer(body) ? body : Buffer.from(body, "utf8");
  res.writeHead(statusCode, {
    ...COMMON_HEADERS,
    "Content-Length": payload.byteLength,
    "Content-Type": contentType,
    ...extraHeaders,
  });
  res.end(payload);
}

function sendJson(res, statusCode, body, extraHeaders = {}) {
  send(
    res,
    statusCode,
    JSON.stringify(body),
    "application/json; charset=utf-8",
    extraHeaders,
  );
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let totalBytes = 0;
    let rejected = false;

    req.on("data", (chunk) => {
      const buffer = Buffer.isBuffer(chunk) ? chunk : Buffer.from(chunk);
      totalBytes += buffer.byteLength;
      if (totalBytes > MAX_REQUEST_BYTES) {
        rejected = true;
      } else {
        chunks.push(buffer);
      }
    });
    req.on("end", () => {
      if (rejected) {
        reject(new Error("REQUEST_TOO_LARGE"));
        return;
      }
      resolve(Buffer.concat(chunks));
    });
    req.on("aborted", () => reject(new Error("REQUEST_ABORTED")));
    req.on("error", reject);
  });
}

function parseRoutePreviewInput(body) {
  let value;
  try {
    value = JSON.parse(body.toString("utf8"));
  } catch {
    return { error: errorPayload("MALFORMED_JSON", "Request body must be valid JSON.") };
  }

  if (value === null || Array.isArray(value) || typeof value !== "object") {
    return {
      error: errorPayload(
        "INVALID_REQUEST_SHAPE",
        "Request body must be a JSON object.",
      ),
    };
  }

  const keys = Object.keys(value);
  const unknown = keys.filter((key) => key !== "natural_request");
  if (unknown.length > 0) {
    return {
      error: errorPayload(
        "UNKNOWN_FIELD",
        "Only natural_request is accepted by route preview.",
      ),
    };
  }
  if (keys.length !== 1 || typeof value.natural_request !== "string") {
    return {
      error: errorPayload(
        "INVALID_NATURAL_REQUEST",
        "natural_request is required and must be a string.",
      ),
    };
  }

  const naturalRequest = value.natural_request.trim();
  if (
    naturalRequest.length === 0 ||
    naturalRequest.length > 4000 ||
    naturalRequest.includes("\u0000")
  ) {
    return {
      error: errorPayload(
        "INVALID_NATURAL_REQUEST",
        "natural_request must contain 1 to 4000 non-null characters.",
      ),
    };
  }

  return { value: { natural_request: naturalRequest } };
}

function parseJsonObject(body) {
  try {
    const value = JSON.parse(body.toString("utf8"));
    if (value === null || Array.isArray(value) || typeof value !== "object") {
      return { error: errorPayload("INVALID_REQUEST_SHAPE", "Request body must be a JSON object.") };
    }
    return { value };
  } catch {
    return { error: errorPayload("MALFORMED_JSON", "Request body must be valid JSON.") };
  }
}

function exactOrigin(req) {
  const port = req.socket.localPort;
  return `http://${LOOPBACK_HOST}:${port}`;
}

function validateOrigin(req) {
  const expected = exactOrigin(req);
  return req.headers.origin === expected && req.headers.host === `${LOOPBACK_HOST}:${req.socket.localPort}`;
}

function secureTokenEqual(left, right) {
  if (typeof left !== "string" || typeof right !== "string") return false;
  const a = Buffer.from(left, "utf8");
  const b = Buffer.from(right, "utf8");
  return a.byteLength === b.byteLength && timingSafeEqual(a, b);
}

function createSessionBoundary({
  ttlMs = SESSION_TTL_MS,
  rateWindowMs = SESSION_RATE_WINDOW_MS,
  rateLimit = SESSION_RATE_LIMIT,
  now = () => Date.now(),
} = {}) {
  const sessions = new Map();
  let closed = false;
  return {
    issue() {
      if (closed) throw new Error("SESSION_BOUNDARY_CLOSED");
      const token = randomBytes(32).toString("base64url");
      const sessionKey = randomBytes(16).toString("hex");
      sessions.set(sessionKey, { token, expiresAt: now() + ttlMs, requests: [] });
      return { token, sessionKey, expiresAt: sessions.get(sessionKey).expiresAt };
    },
    validate(req) {
      if (closed) return { error: "SESSION_TOKEN_INVALID_OR_EXPIRED" };
      if (!validateOrigin(req)) return { error: "ORIGIN_REJECTED" };
      const supplied = req.headers[SESSION_HEADER];
      if (typeof supplied !== "string" || supplied.length < 32 || supplied.length > 128) return { error: "SESSION_TOKEN_MISSING_OR_MALFORMED" };
      let matchedKey = null;
      let matched = null;
      for (const [key, session] of sessions) {
        if (secureTokenEqual(supplied, session.token)) {
          matchedKey = key;
          matched = session;
          break;
        }
      }
      if (!matched || matched.expiresAt <= now()) {
        if (matchedKey) sessions.delete(matchedKey);
        return { error: "SESSION_TOKEN_INVALID_OR_EXPIRED" };
      }
      const cutoff = now() - rateWindowMs;
      matched.requests = matched.requests.filter((value) => value >= cutoff);
      if (matched.requests.length >= rateLimit) return { error: "SESSION_RATE_LIMITED" };
      matched.requests.push(now());
      return { sessionKey: matchedKey };
    },
    invalidate() { closed = true; sessions.clear(); },
  };
}

function requireJson(req, res) {
  const mediaType = String(req.headers["content-type"] ?? "").split(";", 1)[0].trim().toLowerCase();
  if (mediaType === "application/json") return true;
  sendJson(res, 415, errorPayload("UNSUPPORTED_MEDIA_TYPE", "Content-Type must be application/json."));
  return false;
}

function relayError(res, error) {
  const code = error instanceof Error ? error.message.split(":", 1)[0] : "MISSION_RELAY_FAILED_CLOSED";
  const conflict = ["ONE_ACTIVE_MISSION_LIMIT", "SUBMISSION_REPLAY_CONTENT_MISMATCH", "RESPONSE_REPLAY_CONTENT_MISMATCH"].includes(code);
  const missing = code === "MISSION_NOT_FOUND";
  sendJson(res, missing ? 404 : conflict ? 409 : 422, errorPayload(code, "HQ Dispatch rejected the operation through a closed governed contract."));
}

function invokeRoutePreview(requestBody) {
  mkdirSync(PREVIEW_ROOT, { recursive: true });
  const fixedEnvironment = Object.freeze({
    SystemRoot: "C:\\Windows",
    WINDIR: "C:\\Windows",
    ComSpec: "C:\\Windows\\System32\\cmd.exe",
    PATH:
      "C:\\Windows\\System32;C:\\Windows\\System32\\WindowsPowerShell\\v1.0",
    TEMP: PREVIEW_ROOT,
    TMP: PREVIEW_ROOT,
    TSF_HQ_DISPATCH_MODE: "PREVIEW_ONLY",
  });
  const fixedArguments = Object.freeze([
    "-NoLogo",
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    ROUTE_PREVIEW_WRAPPER,
  ]);

  return new Promise((resolve, reject) => {
    const child = spawn(POWERSHELL_EXE, fixedArguments, {
      cwd: REPOSITORY_ROOT,
      detached: false,
      env: fixedEnvironment,
      shell: false,
      stdio: ["pipe", "pipe", "pipe"],
      windowsHide: true,
    });
    const stdout = [];
    let stdoutBytes = 0;
    let stderrBytes = 0;
    let settled = false;

    const rejectOnce = (code) => {
      if (settled) return;
      settled = true;
      reject(new Error(code));
    };
    const timer = setTimeout(() => {
      child.kill();
      rejectOnce("ROUTE_PREVIEW_TIMEOUT");
    }, WRAPPER_TIMEOUT_MS);

    child.stdout.on("data", (chunk) => {
      stdoutBytes += chunk.byteLength;
      if (stdoutBytes > MAX_WRAPPER_OUTPUT_BYTES) {
        child.kill();
        rejectOnce("ROUTE_PREVIEW_OUTPUT_LIMIT");
        return;
      }
      stdout.push(chunk);
    });
    child.stderr.on("data", (chunk) => {
      stderrBytes += chunk.byteLength;
      if (stderrBytes > MAX_WRAPPER_OUTPUT_BYTES) {
        child.kill();
        rejectOnce("ROUTE_PREVIEW_ERROR_LIMIT");
      }
    });
    child.on("error", () => {
      clearTimeout(timer);
      rejectOnce("ROUTE_PREVIEW_WRAPPER_UNAVAILABLE");
    });
    child.on("close", (code) => {
      clearTimeout(timer);
      if (settled) return;
      if (code !== 0) {
        rejectOnce("ROUTE_PREVIEW_WRAPPER_REJECTED");
        return;
      }
      try {
        const response = JSON.parse(Buffer.concat(stdout).toString("utf8"));
        if (
          response.schema_version !==
            "tsf_hq_dispatch_route_preview_response_v1" ||
          response.banner !== "PREVIEW_ONLY_NOT_AUTHORITY" ||
          response.route_explanation?.schema_version !==
            "tsf_hq_dispatch_route_explanation_v1" ||
          response.access_proposal?.access_level !==
            "TSF_LOCAL_SCOPED_PREVIEW_RECOMMENDATION" ||
          response.access_proposal?.network_scope !== "NO_NETWORK" ||
          response.access_proposal?.execution_scope !==
            "ROUTE_PREVIEW_ONLY_NO_EXECUTION" ||
          response.authority?.preview_only !== true ||
          response.authority?.mission_execution_enabled !== false ||
          response.authority?.mission_submission_enabled !== false ||
          response.authority?.queue_mutation_enabled !== false ||
          response.authority?.approval_mutation_enabled !== false ||
          response.authority?.credential_access_enabled !== false ||
          response.authority?.live_ai_service_access_enabled !== false ||
          response.authority?.plugin_access_enabled !== false ||
          response.authority?.external_repository_access_enabled !== false ||
          response.authority?.request_text_persisted !== false
        ) {
          rejectOnce("ROUTE_PREVIEW_RESPONSE_BOUNDARY_INVALID");
          return;
        }
        settled = true;
        resolve(response);
      } catch {
        rejectOnce("ROUTE_PREVIEW_RESPONSE_INVALID");
      }
    });
    child.stdin.on("error", () => rejectOnce("ROUTE_PREVIEW_INPUT_REJECTED"));
    child.stdin.end(JSON.stringify(requestBody), "utf8");
  });
}

async function handleRequest(req, res, context) {
  let url;
  try {
    url = new URL(req.url ?? "/", "http://127.0.0.1");
  } catch {
    sendJson(res, 400, errorPayload("INVALID_URL", "Request URL is invalid."));
    return;
  }

  if (url.search.length > 0) {
    await readBody(req);
    sendJson(
      res,
      400,
      errorPayload("QUERY_NOT_ALLOWED", "Query parameters are not accepted."),
    );
    return;
  }

  if (req.method === "GET" && STATIC_FILES.has(url.pathname)) {
    const body = await readBody(req);
    if (body.byteLength !== 0) {
      sendJson(
        res,
        400,
        errorPayload("BODY_NOT_ALLOWED", "GET requests must not include a body."),
      );
      return;
    }
    const [fileName, contentType] = STATIC_FILES.get(url.pathname);
    send(res, 200, readFileSync(path.join(PUBLIC_ROOT, fileName)), contentType);
    return;
  }

  if (req.method === "GET" && (url.pathname === "/api/v1/doctor" || url.pathname === "/api/v1/recovery" || url.pathname === "/api/v1/stop-status")) {
    const body = await readBody(req);
    if (body.byteLength !== 0) {
      sendJson(res, 400, errorPayload("BODY_NOT_ALLOWED", "GET requests must not include a body."));
      return;
    }
    if (!context.lifecycle) {
      sendJson(res, 404, errorPayload("LIFECYCLE_PROJECTION_UNAVAILABLE", "Lifecycle projection is not enabled for this server."));
      return;
    }
    if (url.pathname === "/api/v1/doctor") {
      sendJson(res, 200, context.lifecycle.doctor());
      return;
    }
    if (url.pathname === "/api/v1/recovery") {
      sendJson(res, 200, context.lifecycle.reconcile());
      return;
    }
    sendJson(res, 200, context.lifecycle.stopView());
    return;
  }

  if (url.pathname === "/api/v1/recovery") {
    if (req.method !== "POST") {
      await readBody(req);
      sendJson(res, 405, errorPayload("METHOD_NOT_ALLOWED", "Only POST is allowed for recovery decisions."), { Allow: "POST" });
      return;
    }
    if (!context.lifecycle) {
      await readBody(req);
      sendJson(res, 404, errorPayload("LIFECYCLE_PROJECTION_UNAVAILABLE", "Lifecycle recovery is not enabled for this server."));
      return;
    }
    if (!requireJson(req, res)) { await readBody(req); return; }
    const auth = context.sessions.validate(req);
    if (auth.error) { await readBody(req); sendJson(res, 403, errorPayload(auth.error, "Exact local operator session validation failed.")); return; }
    const parsed = parseJsonObject(await readBody(req));
    if (parsed.error) { sendJson(res, 400, parsed.error); return; }
    const input = parsed.value;
    const allowed = ["recovery_item_id", "evidence_hash", "action", "operator_confirmation"];
    if (Object.keys(input).length !== allowed.length || Object.keys(input).some((key) => !allowed.includes(key)) || allowed.some((key) => typeof input[key] !== "string" || !input[key])) {
      sendJson(res, 422, errorPayload("RECOVERY_INPUT_CONTRACT_INVALID", "Recovery requires only the exact evidence identity, action, and confirmation."));
      return;
    }
    const reconciliation = context.lifecycle.reconcile();
    const item = reconciliation.items.find((candidate) => candidate.recovery_item_id === input.recovery_item_id);
    if (!item || item.evidence_hash !== input.evidence_hash) {
      sendJson(res, 409, errorPayload("RECOVERY_SOURCE_EVIDENCE_CHANGED", "Canonical evidence changed; refresh Doctor and make a new decision."));
      return;
    }
    try {
      const result = await performRecoveryAction({
        item,
        action: input.action,
        operatorConfirmation: input.operator_confirmation,
        sessionGeneration: context.lifecycle.sessionGeneration,
        sessionKey: auth.sessionKey,
        relay: context.relay,
        localRoot: context.lifecycle.localRoot,
        serverInstanceId: context.lifecycle.serverInstanceId,
      });
      sendJson(res, 200, result);
    } catch (error) {
      relayError(res, error);
    }
    return;
  }

  if (url.pathname === "/api/v1/admin/stop") {
    if (req.method !== "POST") {
      await readBody(req);
      sendJson(res, 405, errorPayload("METHOD_NOT_ALLOWED", "Only POST is allowed for exact owned shutdown."), { Allow: "POST" });
      return;
    }
    if (!context.lifecycle || !requireJson(req, res)) { await readBody(req); if (!context.lifecycle) sendJson(res, 404, errorPayload("LIFECYCLE_PROJECTION_UNAVAILABLE", "Owned shutdown is unavailable.")); return; }
    const parsed = parseJsonObject(await readBody(req));
    if (parsed.error) { sendJson(res, 400, parsed.error); return; }
    const keys = Object.keys(parsed.value);
    if (keys.length !== 3 || keys.some((key) => !["server_instance_id", "evidence_hash", "process_id"].includes(key)) || !context.lifecycle.authenticateStop(req.headers["x-tsf-hq-stop"], parsed.value)) {
      sendJson(res, 403, errorPayload("EXACT_OWNER_STOP_AUTHENTICATION_FAILED", "Stop rejected because process, instance, evidence, or local capability identity did not match."));
      return;
    }
    context.acceptingMissions = false;
    context.sessions.invalidate();
    sendJson(res, 202, {
      schema_version: "tsf_hq_dispatch_stop_accepted_v1",
      server_instance_id: context.lifecycle.serverInstanceId,
      active_mission: context.lifecycle.owner.owner?.active_mission ?? null,
      owned_child_process_ids: context.lifecycle.owner.owner?.owned_child_process_ids ?? [],
      behavior: "STOP_ACCEPTING_THEN_COOPERATIVE_DRAIN_OR_EXACT_OWNED_TREE_TERMINATION",
      canonical_records_preserved: true,
      operator_session_invalidated: true,
    });
    setImmediate(() => { void context.lifecycle.requestStop("EXACT_OPERATOR_STOP"); });
    return;
  }

  if (url.pathname === "/api/v1/session") {
    if (req.method !== "POST") {
      await readBody(req);
      sendJson(res, 405, errorPayload("METHOD_NOT_ALLOWED", "Only POST is allowed for session acquisition."), { Allow: "POST" });
      return;
    }
    if (!validateOrigin(req)) {
      await readBody(req);
      sendJson(res, 403, errorPayload("ORIGIN_REJECTED", "Session acquisition requires the exact loopback origin."));
      return;
    }
    if (!requireJson(req, res)) { await readBody(req); return; }
    const body = await readBody(req);
    const parsed = parseJsonObject(body);
    if (parsed.error || Object.keys(parsed.value).length !== 0) {
      sendJson(res, 400, parsed.error ?? errorPayload("UNKNOWN_FIELD", "Session acquisition accepts only an empty JSON object."));
      return;
    }
    let issued;
    try {
      issued = context.sessions.issue();
    } catch {
      sendJson(res, 503, errorPayload("SESSION_BOUNDARY_CLOSED", "HQ Dispatch is shutting down and cannot issue a session."));
      return;
    }
    sendJson(res, 200, {
      schema_version: "tsf_hq_dispatch_operator_session_v1",
      session_token: issued.token,
      expires_at: new Date(issued.expiresAt).toISOString(),
      operator_session_generation: context.lifecycle?.sessionGeneration ?? "TEST_PROCESS_LOCAL_GENERATION",
      origin: exactOrigin(req),
      local_browser_session_only: true,
      grants_tsf_authority: false,
    });
    return;
  }

  if (url.pathname === "/health") {
    if (req.method !== "GET") {
      await readBody(req);
      sendJson(
        res,
        405,
        errorPayload("METHOD_NOT_ALLOWED", "Only GET is allowed for /health."),
        { Allow: "GET" },
      );
      return;
    }
    const body = await readBody(req);
    if (body.byteLength !== 0) {
      sendJson(
        res,
        400,
        errorPayload("BODY_NOT_ALLOWED", "GET requests must not include a body."),
      );
      return;
    }
    sendJson(res, 200, {
      schema_version: "tsf_hq_dispatch_health_v1",
      status: "ok",
      banner: "PREVIEW_ONLY_NOT_AUTHORITY",
      listener: { host: LOOPBACK_HOST, port: req.socket.localPort, loopback_only: true },
      server_instance_id: context.lifecycle?.serverInstanceId ?? null,
      operator_session_generation: context.lifecycle?.sessionGeneration ?? null,
      lifecycle_mode: context.lifecycle?.mode ?? "TEST",
      operations: [
        "GET /health",
        "GET /api/v1/registries",
        "POST /api/v1/session",
        "POST /api/v1/route-preview",
        "POST /api/v1/missions",
        "GET /api/v1/missions/:missionId",
        "GET /api/v1/missions/:missionId/events",
        "POST /api/v1/missions/:missionId/tim-response",
      ],
      mission_execution_enabled: true,
      queue_mutation_enabled: true,
      credential_access_enabled: false,
      live_ai_service_access_enabled: false,
      plugin_access_enabled: false,
      external_repository_access_enabled: false,
      request_text_persisted: false,
    });
    return;
  }

  if (url.pathname === "/api/v1/registries") {
    if (req.method !== "GET") {
      await readBody(req);
      sendJson(
        res,
        405,
        errorPayload(
          "METHOD_NOT_ALLOWED",
          "Only GET is allowed for /api/v1/registries.",
        ),
        { Allow: "GET" },
      );
      return;
    }
    const body = await readBody(req);
    if (body.byteLength !== 0) {
      sendJson(
        res,
        400,
        errorPayload("BODY_NOT_ALLOWED", "GET requests must not include a body."),
      );
      return;
    }
    sendJson(res, 200, buildRegistryProjection());
    return;
  }

  if (url.pathname === "/api/v1/route-preview") {
    if (req.method !== "POST") {
      await readBody(req);
      sendJson(
        res,
        405,
        errorPayload(
          "METHOD_NOT_ALLOWED",
          "Only POST is allowed for /api/v1/route-preview.",
        ),
        { Allow: "POST" },
      );
      return;
    }
    if (!requireJson(req, res)) { await readBody(req); return; }
    const auth = context.sessions.validate(req);
    if (auth.error) { await readBody(req); sendJson(res, 403, errorPayload(auth.error, "Exact local operator session validation failed.")); return; }
    const body = await readBody(req);
    const parsed = parseRoutePreviewInput(body);
    if (parsed.error) {
      sendJson(res, 400, parsed.error);
      return;
    }
    try {
      const preview = await invokeRoutePreview(parsed.value);
      sendJson(res, 200, context.relay.decoratePreview(preview, parsed.value.natural_request, auth.sessionKey));
    } catch {
      sendJson(
        res,
        422,
        errorPayload(
          "ROUTE_PREVIEW_REJECTED",
          "Canonical route preview rejected the request or failed closed.",
        ),
      );
    }
    return;
  }

  if (url.pathname === "/api/v1/missions") {
    if (req.method !== "POST") {
      await readBody(req);
      sendJson(res, 405, errorPayload("METHOD_NOT_ALLOWED", "Only POST is allowed for mission submission."), { Allow: "POST" });
      return;
    }
    if (!requireJson(req, res)) { await readBody(req); return; }
    if (!context.acceptingMissions) { await readBody(req); sendJson(res, 503, errorPayload("SERVER_SHUTTING_DOWN", "HQ Dispatch is not accepting new mission submissions.")); return; }
    const auth = context.sessions.validate(req);
    if (auth.error) { await readBody(req); sendJson(res, 403, errorPayload(auth.error, "Exact local operator session validation failed.")); return; }
    const parsed = parseJsonObject(await readBody(req));
    if (parsed.error) { sendJson(res, 400, parsed.error); return; }
    try { sendJson(res, 200, await context.relay.submit(parsed.value, auth.sessionKey)); } catch (error) { relayError(res, error); }
    return;
  }

  const missionMatch = url.pathname.match(/^\/api\/v1\/missions\/([A-Za-z0-9._:-]{8,160})(\/events|\/tim-response)?$/);
  if (missionMatch) {
    const missionId = missionMatch[1];
    const operation = missionMatch[2] ?? "";
    if ((operation === "" || operation === "/events") && req.method === "GET") {
      const body = await readBody(req);
      if (body.byteLength) { sendJson(res, 400, errorPayload("BODY_NOT_ALLOWED", "GET requests must not include a body.")); return; }
      try { sendJson(res, 200, operation === "/events" ? context.relay.getEvents(missionId) : context.relay.getMission(missionId)); } catch (error) { relayError(res, error); }
      return;
    }
    if (operation === "/tim-response" && req.method === "POST") {
      if (!requireJson(req, res)) { await readBody(req); return; }
      const auth = context.sessions.validate(req);
      if (auth.error) { await readBody(req); sendJson(res, 403, errorPayload(auth.error, "Exact local operator session validation failed.")); return; }
      const parsed = parseJsonObject(await readBody(req));
      if (parsed.error) { sendJson(res, 400, parsed.error); return; }
      if (parsed.value.mission_id !== missionId) {
        sendJson(res, 422, errorPayload("TIM_RESPONSE_PATH_IDENTITY_MISMATCH", "The path and body mission identities must match exactly."));
        return;
      }
      try { sendJson(res, 200, await context.relay.respond(parsed.value, auth.sessionKey)); } catch (error) { relayError(res, error); }
      return;
    }
    await readBody(req);
    sendJson(res, 405, errorPayload("METHOD_NOT_ALLOWED", "The mission operation does not allow this method."));
    return;
  }

  await readBody(req);
  sendJson(
    res,
    404,
    errorPayload("NOT_FOUND", "The requested operation does not exist."),
  );
}

export function createHqDispatchServer(options = {}) {
  const sessions = createSessionBoundary(options.sessionOptions);
  const lifecycle = options.lifecycle ?? null;
  const relay = options.relay ?? new HqMissionRelay({
    repositoryRoot: REPOSITORY_ROOT,
    powershellExe: POWERSHELL_EXE,
    invokePreview: invokeRoutePreview,
    previewRoot: PREVIEW_ROOT,
    testOnlyQueueRoot: options.testOnlyQueueRoot ?? "",
    testOnlyInitialTimKind: options.testOnlyInitialTimKind ?? "NONE",
    executionAdapter: options.executionAdapter ?? null,
    responseAdapter: options.responseAdapter ?? null,
    workerTimeoutSeconds: options.workerTimeoutSeconds ?? 180,
    onChildStart: lifecycle ? (child) => lifecycle.owner.childStarted(child) : null,
    onChildExit: lifecycle ? (processId) => lifecycle.owner.childExited(processId) : null,
    onMissionChange: lifecycle ? (mission) => lifecycle.owner.missionChanged(mission) : null,
    onInterrupted: lifecycle ? (record) => lifecycle.recordInterruption(record) : null,
    terminateOwnedChild: lifecycle ? (child) => lifecycle.owner.terminateOwnedChildTree(child) : null,
    testOnlyInterruptionBarrier: options.testOnlyInterruptionBarrier ?? null,
  });
  const context = { sessions, relay, lifecycle, acceptingMissions: true };
  const server = createServer((req, res) => {
    handleRequest(req, res, context).catch((error) => {
      const code =
        error instanceof Error && error.message === "REQUEST_TOO_LARGE"
          ? "REQUEST_TOO_LARGE"
          : "INTERNAL_PREVIEW_FAILURE";
      const statusCode = code === "REQUEST_TOO_LARGE" ? 413 : 500;
      if (!res.headersSent) {
        sendJson(
          res,
          statusCode,
          errorPayload(
            code,
            code === "REQUEST_TOO_LARGE"
              ? "Request body exceeds the fixed 8192-byte limit."
              : "HQ Dispatch failed closed.",
          ),
        );
      } else {
        res.destroy();
      }
    });
  });
  server.hqDispatchRelay = relay;
  let shutdownPromise = null;
  server.hqDispatchShutdown = (reason = "SERVER_CLOSE") => {
    if (!shutdownPromise) {
      context.acceptingMissions = false;
      sessions.invalidate();
      if (lifecycle?.owner?.owner) {
        try { lifecycle.owner.stopping(); } catch { /* Preserve mismatched owner evidence for Doctor. */ }
      }
      shutdownPromise = relay.shutdown(reason);
    }
    return shutdownPromise;
  };
  server.hqDispatchContext = context;
  server.once("close", () => { void server.hqDispatchShutdown(); });
  return server;
}

export function listenHqDispatchServer(server, port) {
  return new Promise((resolve, reject) => {
    server.once("error", reject);
    server.listen(port, LOOPBACK_HOST, () => {
      server.removeListener("error", reject);
      resolve(server);
    });
  });
}

export async function startHqDispatchServerForTest(options = {}) {
  return listenHqDispatchServer(createHqDispatchServer(options), 0);
}

async function main() {
  if (process.argv.length !== 2) {
    process.stderr.write(
      "HQ Dispatch accepts no runtime arguments or environment overrides.\n",
    );
    process.exitCode = 64;
    return;
  }
  const doctor = runDoctor();
  if (!doctor.safe_to_start) {
    process.stderr.write(`${JSON.stringify({ status: doctor.overall_status, safe_to_start: false, exact_next_action: doctor.exact_next_action })}\n`);
    process.exitCode = 78;
    return;
  }

  const owner = new ProcessOwnership();
  owner.claim();
  let server;
  let closing = null;
  try {
    const lifecycle = {
      mode: "PRODUCTION",
      owner,
      localRoot: LOCAL_LIFECYCLE_ROOT,
      sessionGeneration: owner.sessionGeneration,
      serverInstanceId: owner.serverInstanceId,
      doctor: () => runDoctor(),
      reconcile: () => reconcileCanonicalState(),
      stopView: () => {
        const reconciliation = reconcileCanonicalState();
        return {
          schema_version: "tsf_hq_dispatch_stop_view_v1",
          server_instance: owner.serverInstanceId,
          lifecycle_state: owner.owner?.lifecycle_state ?? "UNKNOWN",
          active_mission: owner.owner?.active_mission ?? null,
          owned_child: owner.owner?.owned_children ?? [],
          behavior: "Stop accepting submissions, request cooperative child exit, then terminate only the exact verified owned child tree if the grace bound expires.",
          session_invalidation: "ALL_IN_MEMORY_OPERATOR_SESSIONS_INVALIDATED_ON_STOP",
          remaining_canonical_work: reconciliation.items.filter((item) => !item.classification.startsWith("COMPLETED_")).map((item) => ({ recovery_item_id: item.recovery_item_id, mission_id: item.mission_id, mission_revision: item.mission_revision, status: item.classification, recommended_action: item.recommended_action })),
        };
      },
      authenticateStop: (token, body) => owner.authenticateStop(token, body),
      recordInterruption: (record) => {
        const reconciliation = reconcileCanonicalState();
        let item = reconciliation.items.find((candidate) => candidate.mission_id === record.missionId && candidate.mission_revision === record.revision && candidate.run_id === record.preparation?.run_id);
        if (!item) {
          const runtimeQueue = record.preparation?.queue_result_path ? path.join(path.dirname(record.preparation.queue_result_path), "qd.json") : null;
          const queuePaths = [record.preparation?.queue_record_path, runtimeQueue].filter((candidate) => candidate && existsSync(candidate));
          const evidenceHash = createHash("sha256").update(JSON.stringify({ mission_id: record.missionId, mission_revision: record.revision, run_id: record.preparation?.run_id, queue_hashes: queuePaths.map((candidate) => createHash("sha256").update(readFileSync(candidate)).digest("hex")) })).digest("hex");
          item = {
            recovery_item_id: `recovery-${evidenceHash.slice(0, 32)}`,
            evidence_hash: evidenceHash,
            mission_id: record.missionId,
            mission_revision: record.revision,
            run_id: record.preparation?.run_id,
            result_id: record.preparation?.run_id,
            classification: "INTERRUPTED_PROCESS_GONE",
            canonical_paths: { queue_documents: queuePaths, runtime_queue_document: runtimeQueue ? [runtimeQueue] : [] },
            last_canonical_event: queuePaths[0] ? { path: queuePaths[0] } : null,
          };
        }
        return writeInterruptionEvidence({ item, reason: "HQ_DISPATCH_SERVER_SHUTDOWN_DURING_EXECUTION", serverInstanceId: owner.serverInstanceId, operatorInitiated: true });
      },
      requestStop: null,
    };
    server = createHqDispatchServer({ lifecycle });
    const close = (reason) => {
      if (!closing) {
        closing = (async () => {
          await server.hqDispatchShutdown(reason);
          await new Promise((resolve) => {
            if (!server.listening) { resolve(); return; }
            server.close(resolve);
          });
          if (server.hqDispatchRelay.activeChild) throw new Error("OWNED_CHILD_REMAINS_AFTER_SHUTDOWN");
          owner.release();
        })().catch((error) => {
          process.stderr.write(`HQ Dispatch cleanup failed closed: ${error instanceof Error ? error.message : "UNKNOWN"}\n`);
          process.exitCode = 1;
        });
      }
      return closing;
    };
    lifecycle.requestStop = close;
    await listenHqDispatchServer(server, PRODUCTION_PORT);
    owner.activate();
    process.stdout.write(
      `TSF HQ Dispatch V1 listening at http://${LOOPBACK_HOST}:${PRODUCTION_PORT} PREVIEW_ONLY_NOT_AUTHORITY\nCanonical runtime root: ${CANONICAL_RUNTIME_ROOT}\nCanonical queue root: ${CANONICAL_QUEUE_ROOT}\nLocal lifecycle root: ${LOCAL_LIFECYCLE_ROOT}\nServer instance: ${owner.serverInstanceId}\n`,
    );
    process.once("SIGINT", () => { void close("SIGINT"); });
    process.once("SIGTERM", () => { void close("SIGTERM"); });
  } catch (error) {
    if (server?.listening) await new Promise((resolve) => server.close(resolve));
    owner.release();
    throw error;
  }
}

const invokedPath = process.argv[1] ? pathToFileURL(path.resolve(process.argv[1])).href : "";
if (invokedPath === import.meta.url) {
  main().catch(() => {
    process.stderr.write("HQ Dispatch failed closed during foreground startup.\n");
    process.exitCode = 1;
  });
}
