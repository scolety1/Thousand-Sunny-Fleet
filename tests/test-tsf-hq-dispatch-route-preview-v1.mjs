import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { request as httpRequest } from "node:http";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { startHqDispatchServerForTest } from "../tools/hq-dispatch/v1/server.mjs";

const REPOSITORY_ROOT = path.resolve(fileURLToPath(new URL("..", import.meta.url)));
const SERVER_PATH = path.join(REPOSITORY_ROOT, "tools", "hq-dispatch", "v1", "server.mjs");
const APP_PATH = path.join(
  REPOSITORY_ROOT,
  "tools",
  "hq-dispatch",
  "v1",
  "public",
  "app.js",
);
const WRAPPER_PATH = path.join(
  REPOSITORY_ROOT,
  "tools",
  "hq-dispatch",
  "v1",
  "Invoke-TsfHqDispatchRoutePreview.ps1",
);
const POWERSHELL_EXE =
  "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
let assertions = 0;
let operatorOrigin = null;
let operatorSessionToken = null;

function check(condition, message) {
  assertions += 1;
  assert.ok(condition, message);
}

function equal(actual, expected, message) {
  assertions += 1;
  assert.equal(actual, expected, message);
}

function parseJsonFile(relativePath) {
  return JSON.parse(
    readFileSync(path.join(REPOSITORY_ROOT, ...relativePath.split("/")), "utf8")
      .replace(/^\uFEFF/, ""),
  );
}

function hashFile(fullPath) {
  return createHash("sha256").update(readFileSync(fullPath)).digest("hex");
}

function snapshotTree(fullPath, ignoredPrefix = null) {
  const snapshot = new Map();
  if (!existsSync(fullPath)) return snapshot;

  const walk = (currentPath) => {
    if (
      ignoredPrefix &&
      (currentPath === ignoredPrefix ||
        currentPath.startsWith(`${ignoredPrefix}${path.sep}`))
    ) {
      return;
    }
    const stat = statSync(currentPath);
    if (stat.isDirectory()) {
      for (const name of readdirSync(currentPath).sort()) {
        walk(path.join(currentPath, name));
      }
      return;
    }
    snapshot.set(path.relative(REPOSITORY_ROOT, currentPath), hashFile(currentPath));
  };
  walk(fullPath);
  return snapshot;
}

function mapEntries(map) {
  return [...map.entries()].sort(([left], [right]) => left.localeCompare(right));
}

function request(port, options = {}) {
  const {
    method = "GET",
    pathname = "/",
    headers = {},
    body = null,
  } = options;
  return new Promise((resolve, reject) => {
    const req = httpRequest(
      {
        host: "127.0.0.1",
        port,
        method,
        path: pathname,
        headers: {
          Accept: "application/json",
          Connection: "close",
          ...(pathname === "/api/v1/route-preview" && operatorSessionToken
            ? { Origin: operatorOrigin, "X-TSF-HQ-Session": operatorSessionToken }
            : {}),
          ...headers,
        },
      },
      (res) => {
        const chunks = [];
        res.on("data", (chunk) => chunks.push(chunk));
        res.on("end", () => {
          const text = Buffer.concat(chunks).toString("utf8");
          let json = null;
          if (String(res.headers["content-type"] ?? "").startsWith("application/json")) {
            json = JSON.parse(text);
          }
          resolve({ status: res.statusCode, headers: res.headers, text, json });
        });
      },
    );
    req.on("error", reject);
    req.end(body);
  });
}

function jsonRequest(port, value) {
  return request(port, {
    method: "POST",
    pathname: "/api/v1/route-preview",
    headers: { "Content-Type": "application/json" },
    body: typeof value === "string" ? value : JSON.stringify(value),
  });
}

const protectedBefore = {
  missions: snapshotTree(path.join(REPOSITORY_ROOT, "fleet", "missions")),
  state: snapshotTree(path.join(REPOSITORY_ROOT, "fleet", "state")),
  localOutsidePreview: snapshotTree(
    path.join(REPOSITORY_ROOT, ".codex-local"),
    path.join(REPOSITORY_ROOT, ".codex-local", "hq-dispatch", "preview"),
  ),
};

const serverSource = readFileSync(SERVER_PATH, "utf8");
const appSource = readFileSync(APP_PATH, "utf8");
const wrapperSource = readFileSync(WRAPPER_PATH, "utf8");
check(!serverSource.includes("0.0.0.0"), "server source excludes wildcard IPv4 binding");
check(!serverSource.includes("process.env"), "server source excludes caller environment overrides");
check(
  !serverSource.includes("plugin-catalog-risk-v1") &&
    serverSource.includes("plugin_registry_projected: false"),
  "server reads and projects no plugin registry",
);
check(
  !appSource.includes("innerHTML") &&
    !appSource.includes("insertAdjacentHTML") &&
    !appSource.includes("document.write"),
  "browser renderer uses no HTML injection sink for request-derived preview data",
);
check(
  appSource.includes('fetch("/api/v1/registries"') &&
    appSource.includes('fetch("/api/v1/route-preview"') &&
    !appSource.includes("http://") &&
    !appSource.includes("https://"),
  "browser requests remain fixed to same-origin Milestone 1 endpoints",
);
check(
  !serverSource.includes("tsf-codex-app-server-adapter") &&
    !serverSource.includes("Invoke-TsfMissionLifecycle") &&
    !serverSource.includes("Get-TsfAdmissionDecision") &&
    !serverSource.includes("Invoke-TsfMissionQueueForegroundExecutor"),
  "server source contains no app-server, lifecycle, admission, or queue executable",
);
check(
  wrapperSource.includes("tools\\New-TsfProjectMainBotMissionDraft.ps1") &&
    wrapperSource.includes("tools\\TsfDurableContract.Canonical.ps1") &&
    wrapperSource.includes("fleet\\control\\worker-role-registry.v1.json") &&
    wrapperSource.includes("fleet\\control\\model-routing-alias-policy.v1.json"),
  "wrapper names all four canonical route sources",
);
check(
  !wrapperSource.includes("Invoke-TsfMissionLifecycle") &&
    !wrapperSource.includes("Get-TsfAdmissionDecision") &&
    !wrapperSource.includes("approval-ledger") &&
    !wrapperSource.includes("tsf-codex-app-server-adapter"),
  "wrapper contains no lifecycle, admission, approval-ledger, or app-server operation",
);

const rejectedServerArgs = spawnSync(process.execPath, [SERVER_PATH, "--port", "9000"], {
  cwd: REPOSITORY_ROOT,
  encoding: "utf8",
  windowsHide: true,
});
equal(rejectedServerArgs.status, 64, "foreground server rejects runtime arguments");
check(
  rejectedServerArgs.stderr.includes("accepts no runtime arguments"),
  "runtime-argument rejection is explicit",
);

const rejectedWrapperArgs = spawnSync(
  POWERSHELL_EXE,
  [
    "-NoLogo",
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    WRAPPER_PATH,
    "caller-command",
  ],
  {
    cwd: REPOSITORY_ROOT,
    encoding: "utf8",
    input: JSON.stringify({ natural_request: "Read local status." }),
    windowsHide: true,
  },
);
check(rejectedWrapperArgs.status !== 0, "wrapper rejects every runtime argument");

const server = await startHqDispatchServerForTest();
try {
  const address = server.address();
  check(address && typeof address === "object", "test listener exposes an address");
  equal(address.address, "127.0.0.1", "listener binds only to IPv4 loopback");
  const port = address.port;
  operatorOrigin = `http://127.0.0.1:${port}`;
  const issuedSession = await request(port, {
    method: "POST",
    pathname: "/api/v1/session",
    headers: { Origin: operatorOrigin, "Content-Type": "application/json" },
    body: "{}",
  });
  equal(issuedSession.status, 200, "merged baseline issues a same-origin operator session");
  operatorSessionToken = issuedSession.json.session_token;
  check(operatorSessionToken.length >= 32, "operator session token is cryptographically sized");

  const health = await request(port, { pathname: "/health" });
  equal(health.status, 200, "GET /health succeeds");
  equal(health.json.status, "ok", "health status is ok");
  equal(
    health.json.banner,
    "PREVIEW_ONLY_NOT_AUTHORITY",
    "health preserves preview-only banner",
  );
  equal(
    health.json.mission_execution_enabled,
    true,
    "health reports governed mission execution added by Milestone 2A",
  );
  equal(health.json.plugin_access_enabled, false, "health denies plugin access");
  equal(
    health.json.credential_access_enabled,
    false,
    "health denies credential access",
  );
  equal(
    health.json.live_ai_service_access_enabled,
    false,
    "health denies live AI service access",
  );
  equal(
    health.json.external_repository_access_enabled,
    false,
    "health denies external repository access",
  );
  equal(
    health.json.request_text_persisted,
    false,
    "health declares that request text is not persisted",
  );
  equal(
    health.headers["access-control-allow-origin"],
    undefined,
    "server emits no cross-origin grant",
  );

  const registries = await request(port, { pathname: "/api/v1/registries" });
  equal(registries.status, 200, "GET /api/v1/registries succeeds");
  equal(
    registries.json.milestone_restrictions.posture,
    "MILESTONE_2_BOUNDED_GOVERNED_OPERATOR_BRIDGE",
    "registry projection preserves the merged Milestone 2 governed posture",
  );
  equal(
    registries.json.milestone_restrictions.plugin_access_enabled,
    false,
    "registry projection denies plugin access",
  );
  equal(
    registries.json.milestone_restrictions.plugin_registry_projected,
    false,
    "registry projection excludes every plugin registry",
  );
  equal(
    registries.json.milestone_restrictions.credential_access_enabled,
    false,
    "registry projection denies credential access",
  );
  equal(
    registries.json.milestone_restrictions.live_ai_service_access_enabled,
    false,
    "registry projection denies live AI service access",
  );
  equal(
    registries.json.milestone_restrictions.external_repository_access_enabled,
    false,
    "registry projection denies external repository access",
  );
  equal(
    registries.json.milestone_restrictions.mission_submission_enabled,
    true,
    "registry projection reports governed mission submission added by Milestone 2A",
  );
  equal(
    registries.json.milestone_restrictions.mission_execution_enabled,
    true,
    "registry projection reports governed mission execution added by Milestone 2A",
  );
  check(
    registries.json.registry_sources.every(
      (source) => !source.path.includes("plugin-catalog-risk-v1/"),
    ) && !Object.hasOwn(registries.json, "plugins"),
    "registry response contains no plugin source or plugin projection",
  );
  check(
    registries.json.registry_sources.every(
      (source) => source.freshness !== "SOURCE_HASH_MISMATCH",
    ),
    "every projected registry source hash is current",
  );

  const skills = registries.json.skills.registry.skills;
  check(skills.length >= 18, "skill registry includes the documented skill map");
  check(
    skills.every((skill) => skill.documented_in_skill_map === true),
    "every projected skill preserves documented presence",
  );
  const localSkills = skills.filter((skill) => skill.locally_present_definition);
  equal(localSkills.length, 5, "skill registry distinguishes five local definitions");
  check(
    localSkills.every((skill) =>
      skill.source_paths.some((source) => source.startsWith("skills/")),
    ),
    "locally present skills preserve their definition paths",
  );

  const actions = registries.json.setup_actions.registry.actions;
  const enabledActions = actions.filter((action) => action.execution_enabled);
  equal(actions.length, 71, "setup/action projection includes all scoped operations");
  equal(enabledActions.length, 1, "only one action is execution-enabled");
  equal(enabledActions[0].action_id, "route-preview", "route preview is the sole enabled action");
  check(
    actions.every(
      (action) =>
        typeof action.class === "string" &&
        typeof action.source_path === "string" &&
        typeof action.availability === "string" &&
        typeof action.required_human_gate?.required === "boolean" &&
        typeof action.authority_boundary === "string",
    ),
    "every action declares class, source, availability, human gate, and authority boundary",
  );

  const index = await request(port, { pathname: "/" });
  equal(index.status, 200, "browser UI shell loads");
  check(
    index.text.includes("PREVIEW_ONLY_NOT_AUTHORITY"),
    "browser UI displays the exact authority banner",
  );
  check(
    index.text.includes("Operator lifecycle") &&
      index.text.includes("Doctor, recovery, and exact owned stop"),
    "browser UI displays the bounded operator lifecycle boundary",
  );
  check(
    index.text.includes("Access proposal") &&
      index.text.includes("Source-bound route explanation"),
    "browser UI visibly includes access and source-bound explanation sections",
  );
  check(
    index.text.includes("Raw request text is not persisted") &&
      index.text.includes("never become canonical evidence"),
    "browser UI discloses preview persistence and retention behavior",
  );
  check(
    appSource.includes("explanation.project_lane") &&
      appSource.includes("explanation.worker_role") &&
      appSource.includes("explanation.model_routing") &&
      appSource.includes("explanation.access_proposal") &&
      appSource.includes("explanation.authority_not_granted"),
    "browser renderer covers every high-level explanation category",
  );
  check(
    index.text.includes("Do not enter credentials or secrets"),
    "browser UI warns operators not to place credentials in request text",
  );
  check(
    !index.text.includes("Static plugin reference") &&
      !index.text.includes("plugin-state"),
    "browser UI exposes no plugin-reference projection",
  );
  const buttonText = [...index.text.matchAll(/<button\b[^>]*>([\s\S]*?)<\/button>/gi)]
    .map((match) => match[1].replace(/<[^>]+>/g, " ").replace(/\s+/g, " ").trim());
  equal(buttonText.length, 6, "browser UI exposes only the six bounded operator controls");
  check(
    buttonText.some((text) => text.startsWith("Preview route")) &&
      buttonText.includes("Create governed mission") &&
      buttonText.includes("APPROVE EXACT REQUEST") &&
      buttonText.includes("DENY REQUEST") &&
      buttonText.includes("PROVIDE CLARIFICATION") &&
      buttonText.includes("Refresh canonical evidence"),
    "browser UI labels every bounded governed control explicitly",
  );
  equal(
    index.headers["x-frame-options"],
    "DENY",
    "browser UI denies framing",
  );
  check(
    String(index.headers["content-security-policy"]).includes("connect-src 'self'"),
    "browser UI uses a same-origin content security policy",
  );
  equal((await request(port, { pathname: "/styles.css" })).status, 200, "UI CSS loads");
  equal((await request(port, { pathname: "/app.js" })).status, 200, "UI JavaScript loads");

  equal(
    (await request(port, { method: "POST", pathname: "/health" })).status,
    405,
    "health rejects unknown methods",
  );
  equal(
    (
      await request(port, {
        method: "POST",
        pathname: "/api/v1/registries",
        headers: { "Content-Type": "application/json" },
        body: "{}",
      })
    ).status,
    405,
    "registries reject unknown methods",
  );
  equal(
    (await request(port, { pathname: "/api/v1/route-preview" })).status,
    405,
    "route preview rejects GET",
  );
  equal(
    (await request(port, { pathname: "/health?command=run" })).status,
    400,
    "endpoints reject query fields",
  );
  equal(
    (
      await request(port, {
        pathname: "/health",
        headers: { "Content-Type": "application/json" },
        body: "{}",
      })
    ).status,
    400,
    "GET endpoints reject request bodies",
  );
  equal(
    (await request(port, { pathname: "/not-an-operation" })).status,
    404,
    "unknown operations fail closed",
  );
  equal(
    (await request(port, { pathname: "/..%2f..%2ffleet%2fmissions" })).status,
    404,
    "encoded path traversal fails closed",
  );

  equal((await jsonRequest(port, "{")).status, 400, "malformed JSON is rejected");
  equal((await jsonRequest(port, [])).status, 400, "array input is rejected");
  equal((await jsonRequest(port, {})).status, 400, "missing natural_request is rejected");
  equal(
    (await jsonRequest(port, { natural_request: "   " })).status,
    400,
    "whitespace-only natural_request is rejected",
  );
  equal(
    (
      await request(port, {
        method: "POST",
        pathname: "/api/v1/route-preview",
        headers: { "Content-Type": "text/plain" },
        body: "{}",
      })
    ).status,
    415,
    "route preview rejects non-JSON media types",
  );
  equal(
    (
      await request(port, {
        method: "POST",
        pathname: "/api/v1/route-preview",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ natural_request: "x".repeat(9000) }),
      })
    ).status,
    413,
    "route preview rejects bodies above the fixed byte limit",
  );

  const forbiddenFields = [
    "command",
    "executable",
    "script",
    "path",
    "environment",
    "queue_root",
    "output_root",
    "runtime_arguments",
    "host",
    "port",
    "artifact_name",
    "preview_id",
  ];
  for (const field of forbiddenFields) {
    const rejected = await jsonRequest(port, {
      natural_request: "Read local status.",
      [field]: "caller-controlled",
    });
    equal(rejected.status, 400, `unknown field ${field} is rejected`);
    equal(rejected.json.error.code, "UNKNOWN_FIELD", `${field} fails as unknown`);
  }

  const workerRegistry = parseJsonFile("fleet/control/worker-role-registry.v1.json");
  const modelPolicy = parseJsonFile("fleet/control/model-routing-alias-policy.v1.json");
  const safePreview = await jsonRequest(port, {
    natural_request: "Review a bounded TSF-local documentation change.",
  });
  equal(safePreview.status, 200, "safe canonical route preview succeeds");
  equal(
    safePreview.json.classification,
    "SAFE_LOCAL_MISSION",
    "safe request preserves canonical mission-draft classification",
  );
  const canonicalRole = workerRegistry.roles.find(
    (role) => role.role_id === safePreview.json.proposed_worker_role.role_id,
  );
  check(canonicalRole, "proposed role exists in canonical worker registry");
  equal(
    safePreview.json.proposed_worker_role.role_name,
    canonicalRole.role_name,
    "role name matches canonical worker registry",
  );
  equal(
    safePreview.json.model_routing.resolved_model,
    modelPolicy.surface_resolutions.CODEX.BALANCED,
    "resolved model matches canonical model policy",
  );
  equal(
    safePreview.json.model_routing.reasoning_effort,
    modelPolicy.aliases.BALANCED.default_reasoning_effort,
    "resolved effort matches canonical model policy",
  );
  equal(
    safePreview.json.model_routing.assurance,
    "RECOMMENDED_ONLY",
    "model projection preserves canonical assurance",
  );
  equal(
    safePreview.json.authority.mission_submission_enabled,
    false,
    "route preview cannot submit a mission",
  );
  equal(
    safePreview.json.authority.queue_mutation_enabled,
    false,
    "route preview cannot mutate a queue",
  );
  equal(
    safePreview.json.authority.plugin_access_enabled,
    false,
    "route preview cannot access plugins",
  );
  equal(
    safePreview.json.authority.credential_access_enabled,
    false,
    "route preview cannot access credentials",
  );
  equal(
    safePreview.json.authority.live_ai_service_access_enabled,
    false,
    "route preview cannot contact live AI services",
  );
  equal(
    safePreview.json.authority.external_repository_access_enabled,
    false,
    "route preview cannot access external repositories",
  );
  equal(
    safePreview.json.authority.request_text_persisted,
    false,
    "route preview declares that request text is not persisted",
  );
  equal(
    safePreview.json.access_proposal.access_level,
    "TSF_LOCAL_SCOPED_PREVIEW_RECOMMENDATION",
    "route preview exposes the explicit recommendation-only access level",
  );
  equal(
    safePreview.json.access_proposal.network_scope,
    "NO_NETWORK",
    "access proposal denies network scope",
  );
  equal(
    safePreview.json.access_proposal.execution_scope,
    "ROUTE_PREVIEW_ONLY_NO_EXECUTION",
    "access proposal denies execution scope",
  );
  assert.deepEqual(
    safePreview.json.access_proposal.read_scope,
    safePreview.json.allowed_reads,
    "access read scope matches the canonical draft projection",
  );
  assertions += 1;
  assert.deepEqual(
    safePreview.json.access_proposal.write_scope,
    safePreview.json.allowed_writes,
    "access write scope matches the canonical draft projection",
  );
  assertions += 1;
  equal(
    Object.hasOwn(safePreview.json, "natural_request"),
    false,
    "route response and artifact do not echo or persist natural request text",
  );
  equal(
    safePreview.json.route_explanation.schema_version,
    "tsf_hq_dispatch_route_explanation_v1",
    "route explanation has an explicit version",
  );
  const explanationSections = [
    "project_lane",
    "classification",
    "worker_role",
    "model_routing",
    "access_proposal",
    "allowed_reads",
    "allowed_writes",
    "forbidden_operations",
    "approvals_required",
    "clarifications_required",
    "stop_conditions",
    "authority_not_granted",
  ];
  for (const sectionName of explanationSections) {
    const section = safePreview.json.route_explanation[sectionName];
    check(
      /^[A-Z][A-Z0-9_]{2,63}$/.test(section.reason_code),
      `${sectionName} explanation has a bounded reason code`,
    );
    check(section.summary.length > 0, `${sectionName} explanation has a summary`);
    check(
      section.canonical_source_bindings.length > 0,
      `${sectionName} explanation has canonical source bindings`,
    );
    check(
      section.canonical_source_bindings.every(
        (binding) =>
          typeof binding.source_path === "string" &&
          typeof binding.source_field === "string" &&
          typeof binding.assurance === "string" &&
          (typeof binding.observed_value === "string" ||
            /^[a-f0-9]{64}$/.test(binding.observed_value_sha256)),
      ),
      `${sectionName} source bindings retain source, field, observation, and assurance`,
    );
  }
  check(
    safePreview.json.route_explanation.project_lane.canonical_source_bindings.some(
      (binding) =>
        binding.source_field === "draft.mission_packet.project_id" &&
        binding.observed_value === safePreview.json.proposed_project.project_id,
    ) &&
      safePreview.json.route_explanation.project_lane.canonical_source_bindings.some(
        (binding) =>
          binding.source_field === "draft.mission_packet.lane" &&
          binding.observed_value === safePreview.json.proposed_project.lane,
      ),
    "project and lane rationale binds the selected canonical values",
  );
  check(
    safePreview.json.route_explanation.worker_role.canonical_source_bindings.some(
      (binding) =>
        binding.source_field === "draft.normalized_intent.proposed_worker_role" &&
        binding.observed_value === safePreview.json.proposed_worker_role.role_id,
    ),
    "role rationale binds the canonical selected role",
  );
  check(
    safePreview.json.route_explanation.model_routing.canonical_source_bindings.some(
      (binding) => binding.observed_value === safePreview.json.model_routing.stable_alias,
    ) &&
      safePreview.json.route_explanation.model_routing.canonical_source_bindings.some(
        (binding) => binding.observed_value === safePreview.json.model_routing.resolved_model,
      ) &&
      safePreview.json.route_explanation.model_routing.canonical_source_bindings.some(
        (binding) => binding.observed_value === safePreview.json.model_routing.reasoning_effort,
      ),
    "model rationale binds alias, resolution, and effort without changing them",
  );
  check(
    safePreview.json.route_explanation.access_proposal.canonical_source_bindings.some(
      (binding) => binding.assurance === "UNKNOWN_OR_RECOMMENDATION_ONLY" ||
        binding.assurance === "FIXED_MILESTONE_BOUNDARY",
    ),
    "access rationale is fixed or recommendation-only rather than authority",
  );
  check(
    JSON.stringify(safePreview.json.route_explanation).includes(
      safePreview.json.proposed_worker_role.role_id,
    ) &&
      JSON.stringify(safePreview.json.route_explanation).includes(
        safePreview.json.model_routing.resolved_model,
      ),
    "wrapper-authored prose cannot substitute different role or model values",
  );
  check(
    safePreview.json.artifact.relative_path.startsWith(
      ".codex-local/hq-dispatch/preview/",
    ),
    "preview artifact remains under the fixed preview root",
  );
  equal(safePreview.json.artifact.mission_record, false, "artifact is not a mission record");
  equal(safePreview.json.artifact.queue_record, false, "artifact is not a queue record");
  check(
    existsSync(
      path.join(
        REPOSITORY_ROOT,
        ...safePreview.json.artifact.relative_path.split("/"),
      ),
    ),
    "declared preview artifact exists",
  );

  const markerPath = path.join(
    REPOSITORY_ROOT,
    ".codex-local",
    "hq-dispatch",
    "preview",
    "command-injection-marker.txt",
  );
  check(!existsSync(markerPath), "command-injection marker is absent before test");
  const injectedRequest =
    `Push this; New-Item -ItemType File -Path '${markerPath}' ; ..\\..\\fleet\\missions`;
  const injectedPreview = await jsonRequest(port, {
    natural_request: injectedRequest,
  });
  equal(injectedPreview.status, 200, "command-like natural language remains inert data");
  equal(
    injectedPreview.json.classification,
    "NEEDS_TIM_APPROVAL",
    "canonical classifier gates command-like request",
  );
  check(!existsSync(markerPath), "command-like natural language does not execute");

  const inertRequestVariants = [
    `Review local status.\nNew-Item -ItemType File -Path '${markerPath}'`,
    `Review local status.\r\nPATH=C:\\Windows\\System32; & whoami`,
    `Review \"quoted\" status; $(New-Item '${markerPath}') | ..\\..\\fleet\\missions`,
  ];
  for (const naturalRequest of inertRequestVariants) {
    const inertPreview = await jsonRequest(port, { natural_request: naturalRequest });
    equal(inertPreview.status, 200, "newline, CRLF, quoting, and shell text remains inert data");
    equal(
      Object.hasOwn(inertPreview.json, "natural_request"),
      false,
      "inert request variants are not echoed or persisted in the response",
    );
    check(!existsSync(markerPath), "inert request variant cannot create the marker");
  }

  const protectedAfter = {
    missions: snapshotTree(path.join(REPOSITORY_ROOT, "fleet", "missions")),
    state: snapshotTree(path.join(REPOSITORY_ROOT, "fleet", "state")),
    localOutsidePreview: snapshotTree(
      path.join(REPOSITORY_ROOT, ".codex-local"),
      path.join(REPOSITORY_ROOT, ".codex-local", "hq-dispatch", "preview"),
    ),
  };
  assert.deepEqual(
    mapEntries(protectedAfter.missions),
    mapEntries(protectedBefore.missions),
    "route previews create no mission records",
  );
  assertions += 1;
  assert.deepEqual(
    mapEntries(protectedAfter.state),
    mapEntries(protectedBefore.state),
    "route previews mutate no canonical state records",
  );
  assertions += 1;
  assert.deepEqual(
    mapEntries(protectedAfter.localOutsidePreview),
    mapEntries(protectedBefore.localOutsidePreview),
    "route previews write nowhere outside the fixed preview root",
  );
  assertions += 1;
} finally {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
}

process.stdout.write(`NODE_INTEGRATION_PASS assertions=${assertions}\n`);
