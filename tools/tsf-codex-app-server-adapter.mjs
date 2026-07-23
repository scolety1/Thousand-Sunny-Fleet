import { spawn, spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { createWriteStream, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { createInterface } from "node:readline";
import { inspectAuthoritativeSpawnIdentity } from "./hq-dispatch/v1/reliability.mjs";

function parseArgs(argv) {
  const values = {};
  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i]?.replace(/^--/, "");
    if (!key || i + 1 >= argv.length) throw new Error(`Invalid argument list near ${argv[i]}`);
    values[key] = argv[i + 1];
  }
  return values;
}

const args = parseArgs(process.argv.slice(2));
const required = ["codex-executable", "mission-id", "mission-revision", "policy-fingerprint", "queue-document-sha256", "cwd", "model", "mission-requested-effort", "canonical-resolved-effort", "required-effort-assurance", "effort", "sandbox", "prompt-file", "output-dir", "result-file", "event-file", "stderr-file", "timeout-seconds", "expires-at"];
for (const key of required) if (!args[key]) throw new Error(`Missing --${key}`);
const expectedResponseSha256 = args["expected-response-sha256"] ?? "";
if (expectedResponseSha256 && !/^[a-f0-9]{64}$/.test(expectedResponseSha256)) throw new Error("Invalid --expected-response-sha256");
const canonicalResultId = `canonical-result-${args["mission-id"]}-${Number(args["mission-revision"])}`;
const runId = args["run-id"] ?? canonicalResultId;
const resultId = args["result-id"] ?? canonicalResultId;
if (runId !== canonicalResultId || resultId !== canonicalResultId) throw new Error("Noncanonical app-server result identity");

const outputDir = resolve(args["output-dir"]);
mkdirSync(outputDir, { recursive: true });
const eventPath = resolve(args["event-file"]);
const stderrPath = resolve(args["stderr-file"]);
const resultPath = resolve(args["result-file"]);
for (const path of [eventPath, stderrPath, resultPath]) {
  if (!path.startsWith(`${outputDir}\\`) && path !== outputDir) throw new Error(`Runtime artifact escapes output directory: ${path}`);
}
const journal = createWriteStream(eventPath, { flags: "w", encoding: "utf8" });
const stderrLog = createWriteStream(stderrPath, { flags: "w", encoding: "utf8" });
const childInstanceId = randomUUID();
const startedAt = new Date().toISOString();
const timeoutMs = Number(args["timeout-seconds"]) * 1000;
const prompt = readFileSync(resolve(args["prompt-file"]), "utf8");
let sequence = 0;
let requestId = 0;
let threadId = "";
let turnId = "";
let observedModel = "";
let threadDefaultEffort = null;
let effectiveEffortRaw = null;
let effectiveEffortSource = "NOT_EXPOSED";
let turnRequestAcknowledged = false;
let turnStartResponseSequence = null;
let capabilityHash = "";
let finalResponse = "";
let finalResponseObserved = false;
let completedTurn = null;
let initialized = false;
let turnStarted = false;
let malformedProtocolCount = 0;
let nativeApprovalRequests = 0;
let nativeQuestionRequests = 0;
let protocolError = "";
let childExited = false;
let childExitCode = null;
let timedOut = false;
const pending = new Map();
const seenEventKeys = new Set();
const nativeRerouteOrOverrideEvents = [];
const nativeUsageEvents = [];

function hashText(text) { return createHash("sha256").update(text, "utf8").digest("hex"); }
function encodedPowerShell(source) { return Buffer.from(source, "utf16le").toString("base64"); }
function gitText(cwd, gitArgs) {
  const result = spawnSync("git.exe", ["-C", cwd, ...gitArgs], { encoding: "utf8", windowsHide: true, timeout: 10_000 });
  if (result.status !== 0 || !String(result.stdout ?? "").trim()) throw new Error(`APP_SERVER_SPAWN_GIT_IDENTITY_UNAVAILABLE:${gitArgs.join("_")}`);
  return String(result.stdout).trim();
}
function normalizeEffort(value) {
  if (value === null || value === undefined || String(value).trim() === "") return "UNKNOWN";
  const normalized = String(value).trim().toUpperCase().replaceAll("-", "_");
  const map = { LOW: "LIGHT", LIGHT: "LIGHT", MEDIUM: "MEDIUM", HIGH: "HIGH", XHIGH: "EXTRA_HIGH", EXTRA_HIGH: "EXTRA_HIGH", MAX: "MAX", ULTRA: "ULTRA", UNKNOWN: "UNKNOWN" };
  if (!Object.prototype.hasOwnProperty.call(map, normalized)) throw new Error(`Unrecognized effort value: ${value}`);
  return map[normalized];
}
function recordNativeEffortEvent(method, params) {
  const rawPayloadJson = JSON.stringify(params);
  nativeRerouteOrOverrideEvents.push({
    method,
    sequence,
    thread_id: params?.threadId ?? null,
    turn_id: params?.turnId ?? null,
    raw_payload_json: rawPayloadJson,
    raw_payload_sha256: hashText(rawPayloadJson),
  });
}
function normalizeUsageSnapshot(params) {
  const usage = params?.tokenUsage;
  const total = usage?.total;
  if (!usage || !total) throw new Error("Malformed native token usage payload");
  const fields = {
    total_tokens: total.totalTokens,
    input_tokens: total.inputTokens,
    cached_input_tokens: total.cachedInputTokens,
    output_tokens: total.outputTokens,
    reasoning_output_tokens: total.reasoningOutputTokens,
    model_context_window: usage.modelContextWindow,
  };
  for (const [name, value] of Object.entries(fields)) {
    if (value !== null && value !== undefined && (!Number.isSafeInteger(value) || value < 0)) throw new Error(`Malformed native token usage field: ${name}`);
  }
  if (!Number.isSafeInteger(fields.total_tokens)) throw new Error("Malformed native token usage total");
  return fields;
}
function recordNativeUsageEvent(params) {
  const rawPayloadJson = JSON.stringify(params);
  const snapshot = normalizeUsageSnapshot(params);
  const rawPayloadSha256 = hashText(rawPayloadJson);
  nativeUsageEvents.push({
    method: "thread/tokenUsage/updated",
    sequence,
    thread_id: params.threadId,
    turn_id: params.turnId,
    raw_payload_json: rawPayloadJson,
    raw_payload_sha256: rawPayloadSha256,
    duplicate: nativeUsageEvents.some((event) => event.raw_payload_sha256 === rawPayloadSha256),
    snapshot,
  });
}
function journalMessage(direction, message) {
  sequence += 1;
  journal.write(`${JSON.stringify({ sequence, observed_at: new Date().toISOString(), direction, message })}\n`);
}
function journalMessageFlushed(direction, message) {
  sequence += 1;
  const line = `${JSON.stringify({ sequence, observed_at: new Date().toISOString(), direction, message })}\n`;
  return new Promise((resolveWrite, rejectWrite) => {
    journal.write(line, "utf8", (error) => { if (error) rejectWrite(error); else resolveWrite(); });
  });
}
function send(message) {
  journalMessage("client_to_server", message);
  child.stdin.write(`${JSON.stringify(message)}\n`);
}
function request(method, params, timeout = 15000) {
  const id = ++requestId;
  return new Promise((resolvePromise, rejectPromise) => {
    const timer = setTimeout(() => { pending.delete(id); rejectPromise(new Error(`${method} response timeout`)); }, timeout);
    pending.set(id, { method, resolve: resolvePromise, reject: rejectPromise, timer });
    send({ method, id, params });
  });
}
function extractText(item) {
  if (!item) return "";
  if (typeof item.text === "string") return item.text;
  if (Array.isArray(item.content)) return item.content.map((entry) => entry?.text ?? "").join("");
  return "";
}
function bindNativeIds(message) {
  const params = message?.params ?? {};
  const observedThread = params.threadId ?? params.thread?.id ?? "";
  const observedTurn = params.turnId ?? params.turn?.id ?? "";
  if (threadId && observedThread && observedThread !== threadId) throw new Error(`Spoofed thread id: ${observedThread}`);
  if (turnId && observedTurn && observedTurn !== turnId) throw new Error(`Spoofed turn id: ${observedTurn}`);
}
function handleNotification(message) {
  bindNativeIds(message);
  const method = String(message.method ?? "");
  const params = message.params ?? {};
  const key = `${method}|${params.threadId ?? ""}|${params.turnId ?? params.turn?.id ?? ""}|${params.item?.id ?? ""}|${params.item?.type ?? ""}`;
  if (seenEventKeys.has(key) && ["turn/started", "turn/completed", "item/started", "item/completed"].includes(method)) throw new Error(`Duplicate native event: ${key}`);
  seenEventKeys.add(key);
  if (method === "turn/started") turnStarted = true;
  if (method.startsWith("item/") && !turnStarted) throw new Error(`Out-of-order native event: ${method}`);
  if (method === "thread/settings/updated") {
    recordNativeEffortEvent(method, params);
    const rawEffort = params.threadSettings?.effort;
    if (turnRequestAcknowledged && rawEffort !== null && rawEffort !== undefined) {
      effectiveEffortRaw = String(rawEffort);
      effectiveEffortSource = "THREAD_SETTINGS_UPDATED";
    }
  }
  if (method === "model/rerouted") recordNativeEffortEvent(method, params);
  if (method === "thread/tokenUsage/updated") recordNativeUsageEvent(params);
  if (method === "item/completed" && params.item?.type === "agentMessage") {
    finalResponse = extractText(params.item);
    finalResponseObserved = true;
  }
  if (method === "turn/completed") completedTurn = params.turn;
}

const executableIsNodeScript = args["codex-executable"].toLowerCase().endsWith(".mjs");
const childExecutable = executableIsNodeScript ? process.execPath : args["codex-executable"];
const childArguments = executableIsNodeScript
  ? [args["codex-executable"], "app-server", "--listen", "stdio://"]
  : ["app-server", "--listen", "stdio://", "-c", "analytics.enabled=false"];
const child = spawn(childExecutable, childArguments, {
  cwd: resolve(args.cwd),
  windowsHide: true,
  stdio: ["pipe", "pipe", "pipe"],
  env: { ...process.env },
});
const authoritativeSpawn = new Promise((resolveSpawn, rejectSpawn) => {
  child.once("spawn", resolveSpawn);
  child.once("error", rejectSpawn);
});
child.stderr.pipe(stderrLog);
child.on("exit", (code) => {
  childExited = true; childExitCode = code;
  if (!completedTurn) {
    for (const entry of pending.values()) { clearTimeout(entry.timer); entry.reject(new Error(`Unexpected app-server exit: ${code}`)); }
    pending.clear();
  }
});
let authoritativeSpawnEvidence = null;
let failure = "";
let failureClassification = null;
let failureStage = null;
try {
  await authoritativeSpawn;
  const inspectedSpawn = inspectAuthoritativeSpawnIdentity(child.pid, process.pid, childExecutable);
  if (!inspectedSpawn.valid) {
    throw new Error(`APP_SERVER_SPAWN_IDENTITY_INVALID:${JSON.stringify(inspectedSpawn)}`);
  }
  const processIdentity = inspectedSpawn.observed;
  const repositoryWorktree = gitText(resolve(args.cwd), ["rev-parse", "--show-toplevel"]);
  const candidateCommit = gitText(resolve(args.cwd), ["rev-parse", "HEAD"]);
  const candidateTree = gitText(resolve(args.cwd), ["rev-parse", "HEAD^{tree}"]);
  const creationEventTimestamp = new Date().toISOString();
  const launchIdentitySha256 = hashText(JSON.stringify({
    executable: resolve(childExecutable),
    arguments: childArguments,
    cwd: resolve(args.cwd),
  }));
  const spawnBody = {
    schema_version: "tsf_codex_app_server_authoritative_spawn_v1",
    event_type: "AUTHORITATIVE_APP_SERVER_SPAWN",
    mission_id: args["mission-id"],
    mission_revision: Number(args["mission-revision"]),
    run_id: runId,
    result_id: resultId,
    child_process_instance_id: childInstanceId,
    app_server_process_id: processIdentity.process_id,
    app_server_process_start_time: processIdentity.process_start_time,
    app_server_executable: processIdentity.executable,
    app_server_parent_process_id: processIdentity.parent_process_id,
    app_server_parent_process_start_time: processIdentity.parent_process_start_time,
    app_server_parent_executable: processIdentity.parent_executable,
    repository_worktree: repositoryWorktree,
    candidate_commit: candidateCommit,
    candidate_tree: candidateTree,
    creation_event_timestamp: creationEventTimestamp,
    launch_identity_sha256: launchIdentitySha256,
  };
  authoritativeSpawnEvidence = { ...spawnBody, ownership_source_sha256: hashText(JSON.stringify(spawnBody)) };
  await journalMessageFlushed("adapter_internal", authoritativeSpawnEvidence);
} catch (error) {
  if (!child.killed) child.kill();
  failure = error instanceof Error ? error.message : String(error);
  failureClassification = "AUTHORITATIVE_APP_SERVER_SPAWN_OR_INSPECTION_FAILED";
  failureStage = "AUTHORITATIVE_APP_SERVER_SPAWN_INSPECTION";
  await journalMessageFlushed("adapter_internal", {
    schema_version: "tsf_codex_app_server_early_failure_v1",
    event_type: "AUTHORITATIVE_APP_SERVER_SPAWN_FAILURE",
    mission_id: args["mission-id"],
    mission_revision: Number(args["mission-revision"]),
    run_id: runId,
    result_id: resultId,
    child_process_id: child.pid ?? null,
    child_exited: childExited,
    child_exit_code: childExitCode,
    failure_classification: failureClassification,
    failure_stage: failureStage,
    error_class: error?.constructor?.name ?? typeof error,
    error_code: error?.code ?? null,
    error_message: failure,
    recorded_at: new Date().toISOString(),
  });
}
const lines = createInterface({ input: child.stdout, crlfDelay: Infinity });
lines.on("line", (line) => {
  let message;
  try { message = JSON.parse(line); }
  catch {
    malformedProtocolCount += 1; protocolError = "Malformed JSON line from app-server";
    for (const entry of pending.values()) { clearTimeout(entry.timer); entry.reject(new Error(protocolError)); }
    pending.clear();
    return;
  }
  journalMessage("server_to_client", message);
  try {
    if (Object.prototype.hasOwnProperty.call(message, "id") && (Object.prototype.hasOwnProperty.call(message, "result") || Object.prototype.hasOwnProperty.call(message, "error"))) {
      const entry = pending.get(message.id);
      if (!entry) throw new Error(`Unexpected response id ${message.id}`);
      clearTimeout(entry.timer); pending.delete(message.id);
      if (entry.method === "turn/start" && !message.error) { turnRequestAcknowledged = true; turnStartResponseSequence = sequence; }
      if (message.error) entry.reject(new Error(`${entry.method}: ${JSON.stringify(message.error)}`)); else entry.resolve(message.result);
      return;
    }
    if (Object.prototype.hasOwnProperty.call(message, "id") && message.method) {
      const method = String(message.method);
      if (/approval/i.test(method)) nativeApprovalRequests += 1;
      if (/userInput|question/i.test(method)) nativeQuestionRequests += 1;
      send({ id: message.id, error: { code: -32001, message: "TSF automatic mission refuses interactive requests." } });
      protocolError = `Unexpected interactive request: ${method}`;
      return;
    }
    if (message.method) handleNotification(message);
  } catch (error) { protocolError = error.message; }
});

const overallTimer = setTimeout(() => {
  timedOut = true; protocolError = "Bounded app-server timeout";
  for (const entry of pending.values()) { clearTimeout(entry.timer); entry.reject(new Error(protocolError)); }
  pending.clear();
  child.kill();
}, timeoutMs);
try {
  if (failure) throw new Error(failure);
  const initialize = await request("initialize", { clientInfo: { name: "tsf-canonical-adapter", title: "TSF Canonical Adapter", version: "1.0.0" }, capabilities: { experimentalApi: false } });
  initialized = Boolean(initialize?.userAgent);
  if (!initialized) throw new Error("Stable initialize response missing userAgent");
  send({ method: "initialized", params: {} });
  const models = await request("model/list", {});
  capabilityHash = hashText(JSON.stringify(models));
  const selected = models?.data?.find((entry) => entry.id === args.model);
  if (!selected) throw new Error(`Requested model unavailable: ${args.model}`);
  const supportedEfforts = selected.supportedReasoningEfforts?.map((entry) => entry.reasoningEffort) ?? [];
  if (!supportedEfforts.includes(args.effort)) throw new Error(`Requested effort unavailable: ${args.effort}`);
  const thread = await request("thread/start", {
    model: args.model,
    cwd: resolve(args.cwd),
    approvalPolicy: "never",
    sandbox: args.sandbox,
    ephemeral: false,
    experimentalRawEvents: false,
    persistExtendedHistory: true,
    developerInstructions: "Execute only the bound TSF synthetic mission. Worker tools must not use network. Never access secrets, NWR, PrivateLens, product repositories, or unrelated repositories.",
  });
  threadId = String(thread?.thread?.id ?? "");
  observedModel = String(thread?.model ?? "");
  threadDefaultEffort = thread?.reasoningEffort ?? null;
  if (!threadId || observedModel !== args.model) throw new Error("Thread identity or model binding failed");
  if (resolve(thread.cwd) !== resolve(args.cwd)) throw new Error("Thread cwd binding failed");
  if (thread.approvalPolicy !== "never" || thread.sandbox?.networkAccess !== false) throw new Error("Thread approval or network sandbox binding failed");
  const turn = await request("turn/start", {
    threadId,
    input: [{ type: "text", text: prompt }],
    cwd: resolve(args.cwd),
    approvalPolicy: "never",
    sandboxPolicy: args.sandbox === "read-only"
      ? { type: "readOnly", networkAccess: false }
      : { type: "workspaceWrite", writableRoots: [resolve(args.cwd)], networkAccess: false, excludeTmpdirEnvVar: false, excludeSlashTmp: false },
    model: args.model,
    effort: args.effort,
    summary: "none",
  }, 30000);
  turnId = String(turn?.turn?.id ?? "");
  if (!turnId) throw new Error("Turn identity binding failed");
  const missionRequested = normalizeEffort(args["mission-requested-effort"]);
  const canonicalResolved = normalizeEffort(args["canonical-resolved-effort"]);
  const turnRequested = normalizeEffort(args.effort);
  if (missionRequested !== canonicalResolved || turnRequested !== canonicalResolved) throw new Error("Mission, canonical, and turn-request effort binding failed");
  while (!completedTurn && !protocolError && !timedOut) await new Promise((resolveWait) => setTimeout(resolveWait, 25));
  if (protocolError) throw new Error(protocolError);
  if (!completedTurn || completedTurn.status !== "completed") throw new Error(`Turn did not complete: ${completedTurn?.status ?? "missing"}`);
  if (!expectedResponseSha256 && !finalResponse.trim()) throw new Error("Final response was not observed");
} catch (error) {
  if (!failure) {
    failure = error.message;
    failureClassification = "APP_SERVER_PROTOCOL_OR_TURN_FAILED";
    failureStage = initialized ? "APP_SERVER_TURN" : "APP_SERVER_INITIALIZATION";
  }
} finally {
  clearTimeout(overallTimer);
  for (const entry of pending.values()) { clearTimeout(entry.timer); entry.reject(new Error("adapter stopping")); }
  pending.clear();
  child.stdin.end();
  if (!childExited) child.kill();
  const deadline = Date.now() + 5000;
  while (!childExited && Date.now() < deadline) await new Promise((resolveWait) => setTimeout(resolveWait, 25));
  const journalFinished = journal.writableFinished ? Promise.resolve() : new Promise((resolveWait) => journal.once("finish", resolveWait));
  const stderrFinished = stderrLog.writableFinished ? Promise.resolve() : new Promise((resolveWait) => stderrLog.once("finish", resolveWait));
  journal.end(); stderrLog.end();
  await Promise.all([journalFinished, stderrFinished]);
}

const eventJournalSha256 = hashText(readFileSync(eventPath, "utf8"));
const normalizedThreadDefault = normalizeEffort(threadDefaultEffort);
const normalizedTurnRequested = normalizeEffort(args.effort);
const normalizedEffectiveEffort = effectiveEffortSource === "NOT_EXPOSED" ? "UNKNOWN" : normalizeEffort(effectiveEffortRaw);
const uniqueUsageEvents = nativeUsageEvents.filter((event, index, events) => events.findIndex((candidate) => candidate.raw_payload_sha256 === event.raw_payload_sha256) === index);
const selectedUsageEvent = uniqueUsageEvents.slice().sort((left, right) => {
  const totalDifference = right.snapshot.total_tokens - left.snapshot.total_tokens;
  return totalDifference || right.sequence - left.sequence;
})[0] ?? null;
const turnUsage = selectedUsageEvent ? {
  status: "OBSERVED",
  evidence_classification: "NATIVE_OBSERVED",
  source_method: selectedUsageEvent.method,
  selected_sequence: selectedUsageEvent.sequence,
  raw_payload_sha256: selectedUsageEvent.raw_payload_sha256,
  event_count: nativeUsageEvents.length,
  unique_event_count: uniqueUsageEvents.length,
  ...selectedUsageEvent.snapshot,
} : {
  status: "NOT_EXPOSED",
  evidence_classification: "UNVERIFIED",
  source_method: "NOT_EXPOSED",
  selected_sequence: null,
  raw_payload_sha256: null,
  event_count: 0,
  unique_event_count: 0,
  total_tokens: null,
  input_tokens: null,
  cached_input_tokens: null,
  output_tokens: null,
  reasoning_output_tokens: null,
  model_context_window: null,
};
const effortConflicts = [];
if (normalizedThreadDefault !== "UNKNOWN" && normalizedThreadDefault !== normalizedTurnRequested) effortConflicts.push("THREAD_DEFAULT_DIFFERS_FROM_TURN_REQUEST");
if (normalizedEffectiveEffort !== "UNKNOWN" && normalizedEffectiveEffort !== normalizeEffort(args["canonical-resolved-effort"])) effortConflicts.push("EFFECTIVE_EFFORT_DIFFERS_FROM_CANONICAL_RESOLUTION");
if (nativeRerouteOrOverrideEvents.some((event) => event.method === "model/rerouted")) effortConflicts.push("NATIVE_MODEL_REROUTE_OBSERVED");
const observedResponseSha256 = finalResponseObserved ? hashText(finalResponse) : null;
const responseExactMatch = Boolean(expectedResponseSha256)
  && finalResponseObserved
  && observedResponseSha256 === expectedResponseSha256;
const transportSuccess = !failure && childExited && malformedProtocolCount === 0;
// The adapter proves transport and exact-literal equality only. General-task
// fulfillment is a lifecycle/verifier decision bound to GENERAL_RESULT_V2.
const semanticResponseSuccess = expectedResponseSha256 ? responseExactMatch : false;
const result = {
  schema_version: "tsf_codex_app_server_adapter_result_v1",
  mission_id: args["mission-id"],
  mission_revision: Number(args["mission-revision"]),
  policy_fingerprint: args["policy-fingerprint"],
  queue_document_sha256: args["queue-document-sha256"],
  run_id: runId,
  result_id: resultId,
  child_process_instance_id: childInstanceId,
  child_process_id: child.pid,
  child_process_start_time: authoritativeSpawnEvidence?.app_server_process_start_time ?? null,
  child_process_executable: authoritativeSpawnEvidence?.app_server_executable ?? null,
  child_parent_process_id: authoritativeSpawnEvidence?.app_server_parent_process_id ?? null,
  child_parent_process_start_time: authoritativeSpawnEvidence?.app_server_parent_process_start_time ?? null,
  child_parent_executable: authoritativeSpawnEvidence?.app_server_parent_executable ?? null,
  child_launch_identity_sha256: authoritativeSpawnEvidence?.launch_identity_sha256 ?? null,
  child_ownership_source_sha256: authoritativeSpawnEvidence?.ownership_source_sha256 ?? null,
  cwd: resolve(args.cwd),
  expected_repository: resolve(args.cwd),
  capability_hash: capabilityHash,
  initialized,
  experimental_api: false,
  thread_id: threadId,
  turn_id: turnId,
  observed_model: observedModel,
  observed_reasoning_effort: normalizedEffectiveEffort,
  mission_requested_effort: args["mission-requested-effort"],
  canonical_resolved_effort: normalizeEffort(args["canonical-resolved-effort"]),
  thread_default_effort: threadDefaultEffort,
  turn_requested_effort: args.effort,
  effective_effort: normalizedEffectiveEffort,
  effective_effort_raw: effectiveEffortRaw,
  effective_effort_source: effectiveEffortSource,
  effort_assurance: normalizedEffectiveEffort === "UNKNOWN" ? "RECOMMENDED_ONLY" : "ADAPTER_VERIFIED",
  required_effort_assurance: args["required-effort-assurance"],
  turn_request_acknowledged: turnRequestAcknowledged,
  turn_start_response_sequence: turnStartResponseSequence,
  native_reroute_or_override_events: nativeRerouteOrOverrideEvents,
  effort_conflicts: effortConflicts,
  approval_policy: "never",
  sandbox: args.sandbox,
  control_plane_service_network_policy: "CODEX_SERVICE_ONLY",
  worker_tool_network_policy: "DISABLED",
  codex_service_connection_used: Boolean(turnId),
  direct_openai_api_called_by_tsf: null,
  external_api_called: null,
  worker_network_used: null,
  observation_claims: {
    product_repository_access: { classification: "NOT_OBSERVED", value: null, source: "app-server protocol exposes no filesystem-read audit", run_id: runId },
    plugin_use: { classification: "NOT_OBSERVED", value: null, source: "app-server protocol exposes no plugin-use audit", run_id: runId },
    credential_access: { classification: "NOT_OBSERVED", value: null, source: "app-server protocol exposes no credential-read audit", run_id: runId },
    worker_tool_network: { classification: "CONFIGURED_DISABLED", value: false, source: "thread and turn sandbox networkAccess=false", run_id: runId },
    external_network_access: { classification: "NOT_OBSERVED", value: null, source: "sandbox is configured disabled but no runtime network-use audit is exposed", run_id: runId },
    filesystem_writes: { classification: "NOT_OBSERVED", value: null, source: "adapter delegates before/after filesystem observation to lifecycle", run_id: runId },
    detached_or_unowned_child: { classification: childExited ? "OBSERVED_NOT_USED" : "UNKNOWN", value: childExited ? false : null, source: "adapter-owned foreground child exit observation", run_id: runId },
  },
  native_approval_request_count: nativeApprovalRequests,
  native_question_request_count: nativeQuestionRequests,
  question_relay_status: "QUESTION_RELAY_DEFERRED_AFTER_AUTOMATIC_ROUND_TRIP",
  event_count: sequence,
  event_journal_path: eventPath,
  event_journal_sha256: eventJournalSha256,
  final_response: finalResponse,
  final_response_observed: finalResponseObserved,
  expected_response_sha256: expectedResponseSha256 || null,
  observed_response_sha256: observedResponseSha256,
  response_exact_match: responseExactMatch,
  semantic_response_success: semanticResponseSuccess,
  native_usage_events: nativeUsageEvents,
  turn_usage: turnUsage,
  timeout_seconds: Number(args["timeout-seconds"]),
  timed_out: timedOut,
  bounded_expiration: args["expires-at"],
  child_exit_code: childExitCode,
  child_exited: childExited,
  no_orphan_process: childExited,
  malformed_protocol_count: malformedProtocolCount,
  transport_success: transportSuccess,
  success: transportSuccess,
  failure,
  failure_classification: failureClassification,
  failure_stage: failureStage,
  started_at: startedAt,
  completed_at: new Date().toISOString(),
};
writeFileSync(resultPath, `${JSON.stringify(result, null, 2)}\n`, "utf8");
process.stdout.write(`${JSON.stringify(result)}\n`);
process.exit(result.transport_success ? 0 : 1);
