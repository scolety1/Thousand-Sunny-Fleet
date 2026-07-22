import { createHash, randomBytes, randomUUID, timingSafeEqual } from "node:crypto";
import {
  accessSync,
  constants as fsConstants,
  copyFileSync,
  existsSync,
  fsyncSync,
  lstatSync,
  mkdirSync,
  openSync,
  closeSync,
  readFileSync,
  readdirSync,
  renameSync,
  rmSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { execFileSync, spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

export const HQ_HOST = "127.0.0.1";
export const HQ_PORT = 4317;
export const HQ_DEMO_PORT = 4318;
export const REQUIRED_BASELINE = "6f0fc0a481f2832a60073e872854f56ac6207516";
export const POWERSHELL_EXE = "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe";
export const REPOSITORY_ROOT = path.resolve(fileURLToPath(new URL("../../../", import.meta.url)));
export const CANONICAL_RUNTIME_ROOT = path.join(REPOSITORY_ROOT, ".codex-local", "rt");
export const CANONICAL_QUEUE_ROOT = path.join(REPOSITORY_ROOT, "fleet", "missions");
export const LOCAL_LIFECYCLE_ROOT = path.join(REPOSITORY_ROOT, ".codex-local", "hq-dispatch", "v1");
export const OWNER_PATH = path.join(LOCAL_LIFECYCLE_ROOT, "owner.json");
const CANONICAL_QUEUE_VALIDATOR = path.join(REPOSITORY_ROOT, "tools", "hq-dispatch", "v1", "Test-TsfHqDispatchCanonicalQueueRecordsV1.ps1");
export const STOP_TOKEN_PATH = path.join(LOCAL_LIFECYCLE_ROOT, "stop-token");

const OWNER_SCHEMA = "tsf_hq_dispatch_process_owner_v1";
const DOCTOR_SCHEMA = "tsf_hq_dispatch_doctor_v1";
const RECONCILIATION_SCHEMA = "tsf_hq_dispatch_restart_reconciliation_v1";
const RECOVERY_RECEIPT_SCHEMA = "tsf_hq_dispatch_recovery_receipt_v1";
const INTERRUPTION_SCHEMA = "tsf_hq_dispatch_interruption_evidence_v1";
const OWNED_PROCESS_REGISTRY_SCHEMA = "tsf_hq_dispatch_owned_process_registry_event_v1";
const OWNED_PROCESS_TERMINAL_DISPOSITIONS = new Set([
  "COOPERATIVE_EXIT_CONFIRMED",
  "FORCED_TERMINATION_CONFIRMED",
  "ALREADY_GONE_WITH_IDENTITY_CONFIRMED",
  "CLEANUP_UNCONFIRMED",
]);
const MAX_JSON_BYTES = 2 * 1024 * 1024;
const MAX_SCAN_FILES = 10000;

const QUEUE_STATES = new Set([
  "inbox",
  "drafted",
  "preflight_pending",
  "blocked_needs_tim",
  "approved_for_worker",
  "worker_running",
  "postrun_pending",
  "complete_review_only",
  "complete_ready_for_gate",
  "stopped",
  "archived",
]);

const COMPLETED_ADMISSIONS = new Set(["ADMITTED", "ADMITTED_WITH_CAVEATS"]);
const REJECTED_ADMISSIONS = new Set([
  "REVIEW_REQUIRED",
  "REJECTED_OUT_OF_SCOPE",
  "REJECTED_POLICY_MISMATCH",
  "REJECTED_INVALID_EVIDENCE",
  "UNTRUSTED_NOT_TSF_GOVERNED",
]);

const ACTIONS = Object.freeze({
  COMPLETED_ADMITTED: ["ACKNOWLEDGE_COMPLETED", "VIEW_CANONICAL_RECEIPT"],
  COMPLETED_ADMITTED_WITH_CAVEATS: ["ACKNOWLEDGE_COMPLETED", "VIEW_CANONICAL_RECEIPT"],
  COMPLETED_REJECTED: ["ACKNOWLEDGE_COMPLETED", "VIEW_CANONICAL_RECEIPT", "DECLINE_RECOVERY"],
  TIM_REQUIRED_PENDING_RESPONSE: ["RESPOND_TO_TIM_REQUIRED", "DECLINE_RECOVERY", "TIM_REQUIRED"],
  TIM_REQUIRED_RESPONDED_REVISION_EXISTS: ["VIEW_CANONICAL_RECEIPT", "ACKNOWLEDGE_COMPLETED"],
  RUNNING_PROCESS_CONFIRMED: ["DECLINE_RECOVERY"],
  INTERRUPTED_PROCESS_GONE: ["MARK_PROCESS_INTERRUPTED", "RETRY_AS_NEW_RUN", "DECLINE_RECOVERY"],
  QUEUED_NOT_STARTED: ["DECLINE_RECOVERY"],
  DISPATCHING_WITHOUT_OWNER: ["MARK_PROCESS_INTERRUPTED", "RETRY_AS_NEW_RUN", "TIM_REQUIRED"],
  RESULT_WITHOUT_ADMISSION: ["VIEW_CANONICAL_RECEIPT", "TIM_REQUIRED"],
  ADMISSION_WITH_QUEUE_MISMATCH: ["VIEW_CANONICAL_RECEIPT", "RECONCILE_QUEUE_FROM_CANONICAL_RECEIPT", "TIM_REQUIRED"],
  DUPLICATE_EXACT_REPLAY: ["VIEW_CANONICAL_RECEIPT", "ACKNOWLEDGE_COMPLETED"],
  CONFLICTING_REPLAY: ["VIEW_CANONICAL_RECEIPT", "TIM_REQUIRED"],
  STALE_OR_UNKNOWN: ["DECLINE_RECOVERY", "TIM_REQUIRED"],
});

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function stableValue(value) {
  if (Array.isArray(value)) return value.map(stableValue);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stableValue(value[key])]));
  }
  return value;
}

function stableJson(value) {
  return JSON.stringify(stableValue(value));
}

function hashObject(value) {
  return sha256(stableJson(value));
}

function nowIso() {
  return new Date().toISOString();
}

function samePath(left, right) {
  return path.resolve(String(left ?? "")).toLowerCase() === path.resolve(String(right ?? "")).toLowerCase();
}

function pathInside(candidate, root) {
  const relative = path.relative(path.resolve(root), path.resolve(candidate));
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function readJson(filePath) {
  const stat = statSync(filePath);
  if (!stat.isFile() || stat.size > MAX_JSON_BYTES) throw new Error("JSON_FILE_SIZE_OR_TYPE_REJECTED");
  return JSON.parse(readFileSync(filePath, "utf8").replace(/^\uFEFF/, ""));
}

function atomicWriteJson(filePath, value, { noReplace = false } = {}) {
  const parent = path.dirname(filePath);
  mkdirSync(parent, { recursive: true });
  const payload = `${JSON.stringify(value, null, 2)}\n`;
  if (noReplace && existsSync(filePath)) {
    const existing = readFileSync(filePath, "utf8");
    if (sha256(existing) !== sha256(payload)) throw new Error("IMMUTABLE_EVIDENCE_CONFLICT");
    return { path: filePath, sha256: sha256(existing), idempotent: true };
  }
  const temp = path.join(parent, `.${path.basename(filePath)}.${process.pid}.${randomBytes(6).toString("hex")}.tmp`);
  let descriptor;
  try {
    descriptor = openSync(temp, "wx", 0o600);
    writeFileSync(descriptor, payload, "utf8");
    closeSync(descriptor);
    descriptor = undefined;
    if (noReplace && existsSync(filePath)) throw new Error("IMMUTABLE_EVIDENCE_CONFLICT");
    renameSync(temp, filePath);
  } finally {
    if (descriptor !== undefined) closeSync(descriptor);
    if (existsSync(temp)) rmSync(temp, { force: true });
  }
  return { path: filePath, sha256: sha256(payload), idempotent: false };
}

function ownerBody(owner) {
  const { evidence_hash: ignored, ...body } = owner;
  return body;
}

function withOwnerHash(body) {
  return { ...body, evidence_hash: hashObject(body) };
}

export function stopAuthenticationHash(owner) {
  const identity = {
    schema_version: "tsf_hq_dispatch_stop_authentication_identity_v1",
    process_id: Number(owner?.process_id),
    process_start_time: String(owner?.process_start_time ?? ""),
    executable: String(owner?.executable ?? ""),
    host: String(owner?.host ?? ""),
    port: Number(owner?.port),
    server_instance_id: String(owner?.server_instance_id ?? ""),
    operator_session_generation: String(owner?.operator_session_generation ?? ""),
    control_token_sha256: String(owner?.control_token_sha256 ?? ""),
    created_at: String(owner?.created_at ?? ""),
  };
  if (!Number.isInteger(identity.process_id) || identity.process_id <= 0
      || !Number.isInteger(identity.port) || identity.port <= 0 || identity.port > 65535
      || !identity.process_start_time || !identity.executable || !identity.host
      || !identity.server_instance_id || !identity.operator_session_generation
      || !/^[a-f0-9]{64}$/.test(identity.control_token_sha256) || !identity.created_at) {
    throw new Error("STOP_AUTHENTICATION_IDENTITY_INVALID");
  }
  return hashObject(identity);
}

function validateOwnerShape(owner) {
  const errors = [];
  if (!owner || owner.schema_version !== OWNER_SCHEMA) errors.push("OWNER_SCHEMA_INVALID");
  if (!Number.isInteger(owner?.process_id) || owner.process_id <= 0) errors.push("OWNER_PID_INVALID");
  for (const field of ["process_start_time", "executable", "repository", "worktree", "host", "server_instance_id", "operator_session_generation", "created_at", "control_token_sha256", "evidence_hash"]) {
    if (typeof owner?.[field] !== "string" || !owner[field]) errors.push(`OWNER_${field.toUpperCase()}_INVALID`);
  }
  if (!Number.isInteger(owner?.port) || owner.port <= 0 || owner.port > 65535) errors.push("OWNER_PORT_INVALID");
  if (!Array.isArray(owner?.owned_child_process_ids) || !Array.isArray(owner?.owned_children)) errors.push("OWNER_CHILD_EVIDENCE_INVALID");
  if (owner?.evidence_hash && owner.evidence_hash !== hashObject(ownerBody(owner))) errors.push("OWNER_EVIDENCE_HASH_MISMATCH");
  return { valid: errors.length === 0, errors };
}

function powerShellJson(command) {
  const result = spawnSync(POWERSHELL_EXE, ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command", command], {
    encoding: "utf8",
    windowsHide: true,
    timeout: 10000,
    maxBuffer: 1024 * 1024,
  });
  if (result.error || result.status !== 0 || !String(result.stdout ?? "").trim()) return null;
  try { return JSON.parse(String(result.stdout).trim()); } catch { return null; }
}

export function inspectProcess(processId) {
  if (!Number.isInteger(Number(processId)) || Number(processId) <= 0) return null;
  const pid = Number(processId);
  const command = `$p=Get-Process -Id ${pid} -ErrorAction SilentlyContinue;if($null-ne$p){[pscustomobject]@{process_id=$p.Id;process_start_time=$p.StartTime.ToUniversalTime().ToString('o');executable=$p.Path;process_name=$p.ProcessName}|ConvertTo-Json -Compress}`;
  const observed = powerShellJson(command);
  return observed && Number(observed.process_id) === pid ? observed : null;
}

export function inspectProcessWithParent(processId) {
  if (!Number.isInteger(Number(processId)) || Number(processId) <= 0) return null;
  const pid = Number(processId);
  const command = `$p=Get-Process -Id ${pid} -ErrorAction SilentlyContinue;if($null-ne$p){$c=Get-CimInstance Win32_Process -Filter "ProcessId=${pid}" -ErrorAction SilentlyContinue;[pscustomobject]@{process_id=$p.Id;process_start_time=$p.StartTime.ToUniversalTime().ToString('o');executable=$p.Path;process_name=$p.ProcessName;parent_process_id=if($null-ne$c){[int]$c.ParentProcessId}else{$null}}|ConvertTo-Json -Compress}`;
  const observed = powerShellJson(command);
  return observed && Number(observed.process_id) === pid ? observed : null;
}

export function validateAuthoritativeSpawnIdentity(observed, {
  processId,
  expectedParentProcessId,
  expectedExecutable = null,
} = {}) {
  const errors = [];
  const expectedPid = Number(processId);
  const expectedParentPid = Number(expectedParentProcessId);
  if (!observed || typeof observed !== "object") errors.push("SPAWN_IDENTITY_OBSERVATION_MISSING");
  else {
    if (!Number.isInteger(expectedPid) || expectedPid <= 0 || Number(observed.process_id) !== expectedPid) errors.push("SPAWN_PROCESS_ID_MISMATCH");
    if (!Number.isInteger(expectedParentPid) || expectedParentPid <= 0 || Number(observed.parent_process_id) !== expectedParentPid) errors.push("SPAWN_PARENT_PROCESS_ID_MISMATCH");
    if (!Number.isFinite(Date.parse(observed.process_start_time))) errors.push("SPAWN_PROCESS_START_TIME_MISSING_OR_INVALID");
    if (!Number.isFinite(Date.parse(observed.parent_process_start_time))) errors.push("SPAWN_PARENT_START_TIME_MISSING_OR_INVALID");
    if (!observed.executable) errors.push("SPAWN_PROCESS_EXECUTABLE_MISSING");
    if (!observed.parent_executable) errors.push("SPAWN_PARENT_EXECUTABLE_MISSING");
    if (expectedExecutable && observed.executable
        && path.resolve(observed.executable).toLowerCase() !== path.resolve(expectedExecutable).toLowerCase()) {
      errors.push("SPAWN_PROCESS_EXECUTABLE_MISMATCH");
    }
    if (observed.cim_executable && observed.executable
        && path.resolve(observed.cim_executable).toLowerCase() !== path.resolve(observed.executable).toLowerCase()) {
      errors.push("SPAWN_PROCESS_EXECUTABLE_SOURCE_MISMATCH");
    }
    if (observed.parent_cim_executable && observed.parent_executable
        && path.resolve(observed.parent_cim_executable).toLowerCase() !== path.resolve(observed.parent_executable).toLowerCase()) {
      errors.push("SPAWN_PARENT_EXECUTABLE_SOURCE_MISMATCH");
    }
  }
  return {
    valid: errors.length === 0,
    errors,
    expected: {
      process_id: Number.isInteger(expectedPid) && expectedPid > 0 ? expectedPid : null,
      parent_process_id: Number.isInteger(expectedParentPid) && expectedParentPid > 0 ? expectedParentPid : null,
      executable: expectedExecutable ? path.resolve(expectedExecutable) : null,
    },
    observed: observed ?? null,
  };
}

export function inspectAuthoritativeSpawnIdentity(processId, expectedParentProcessId, expectedExecutable = null) {
  const pid = Number(processId);
  const parentPid = Number(expectedParentProcessId);
  if (!Number.isInteger(pid) || pid <= 0 || !Number.isInteger(parentPid) || parentPid <= 0) {
    return validateAuthoritativeSpawnIdentity(null, { processId, expectedParentProcessId, expectedExecutable });
  }
  const command = `
$ErrorActionPreference='Stop'
$childProcess=Get-Process -Id ${pid} -ErrorAction Stop
$childCim=Get-CimInstance Win32_Process -Filter "ProcessId=${pid}" -ErrorAction Stop
$parentProcess=Get-Process -Id ${parentPid} -ErrorAction Stop
$parentCim=Get-CimInstance Win32_Process -Filter "ProcessId=${parentPid}" -ErrorAction Stop
[pscustomobject]@{
  process_id=[int]$childProcess.Id
  process_start_time=$childProcess.StartTime.ToUniversalTime().ToString('o')
  executable=[string]$childProcess.Path
  cim_executable=[string]$childCim.ExecutablePath
  parent_process_id=[int]$childCim.ParentProcessId
  parent_process_start_time=$parentProcess.StartTime.ToUniversalTime().ToString('o')
  parent_executable=[string]$parentProcess.Path
  parent_cim_executable=[string]$parentCim.ExecutablePath
}|ConvertTo-Json -Compress
`;
  const result = spawnSync(POWERSHELL_EXE, [
    "-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand",
    Buffer.from(command, "utf16le").toString("base64"),
  ], { encoding: "utf8", windowsHide: true, timeout: 10_000, maxBuffer: 1024 * 1024 });
  let observed = null;
  let inspectionError = null;
  try {
    const text = String(result.stdout ?? "").trim();
    if (!result.error && result.status === 0 && text) observed = JSON.parse(text.split(/\r?\n/).at(-1));
    else inspectionError = result.error?.message ?? `SPAWN_IDENTITY_INSPECTION_EXIT_${result.status ?? "UNKNOWN"}`;
  } catch (error) {
    inspectionError = `SPAWN_IDENTITY_OUTPUT_PARSE_FAILED:${error instanceof Error ? error.message : String(error)}`;
  }
  const validation = validateAuthoritativeSpawnIdentity(observed, { processId: pid, expectedParentProcessId: parentPid, expectedExecutable });
  if (inspectionError) validation.errors.unshift(inspectionError);
  validation.valid = validation.errors.length === 0;
  validation.inspection = {
    exit_code: Number.isInteger(result.status) ? result.status : null,
    error_classification: inspectionError,
  };
  return validation;
}

export function inspectListeners(port = HQ_PORT) {
  const numericPort = Number(port);
  if (!Number.isInteger(numericPort) || numericPort <= 0 || numericPort > 65535) return [];
  const command = `$rows=@(Get-NetTCPConnection -State Listen -LocalPort ${numericPort} -ErrorAction SilentlyContinue|ForEach-Object{[pscustomobject]@{host=$_.LocalAddress;port=$_.LocalPort;process_id=$_.OwningProcess}});ConvertTo-Json -Compress -InputObject @($rows)`;
  const result = powerShellJson(command);
  if (Array.isArray(result)) return result;
  if (result && typeof result === "object") return [result];
  const fallback = spawnSync("C:\\Windows\\System32\\netstat.exe", ["-ano", "-p", "tcp"], { encoding: "utf8", windowsHide: true, timeout: 10000 });
  if (fallback.status !== 0) return [];
  const rows = [];
  for (const line of String(fallback.stdout).split(/\r?\n/)) {
    const match = line.match(/^\s*TCP\s+(\S+):(\d+)\s+\S+\s+LISTENING\s+(\d+)\s*$/i);
    if (match && Number(match[2]) === numericPort) rows.push({ host: match[1], port: numericPort, process_id: Number(match[3]) });
  }
  return rows;
}

function processMatchesOwner(owner, observed) {
  if (!owner || !observed) return false;
  const startMatch = Date.parse(owner.process_start_time) === Date.parse(observed.process_start_time);
  return Number(owner.process_id) === Number(observed.process_id) && startMatch && samePath(owner.executable, observed.executable);
}

export function readOwnership(ownerPath = OWNER_PATH) {
  if (!existsSync(ownerPath)) return { disposition: "ABSENT", owner: null, observed_process: null, errors: [] };
  let owner;
  try { owner = readJson(ownerPath); } catch (error) {
    return { disposition: "MALFORMED", owner: null, observed_process: null, errors: [String(error.message)] };
  }
  const shape = validateOwnerShape(owner);
  const observed = shape.valid ? inspectProcess(owner.process_id) : null;
  if (!shape.valid) return { disposition: "INVALID_EVIDENCE", owner, observed_process: observed, errors: shape.errors };
  if (!observed) return { disposition: "STALE_PROCESS_GONE", owner, observed_process: null, errors: [] };
  if (!processMatchesOwner(owner, observed)) return { disposition: "PID_REUSED_OR_IDENTITY_MISMATCH", owner, observed_process: observed, errors: [] };
  if (!samePath(owner.repository, REPOSITORY_ROOT) || !samePath(owner.worktree, REPOSITORY_ROOT)) {
    return { disposition: "DIFFERENT_REPOSITORY_OWNER", owner, observed_process: observed, errors: [] };
  }
  return { disposition: "ACTIVE_OWNER_CONFIRMED", owner, observed_process: observed, errors: [] };
}

function gitText(repositoryRoot, args) {
  return execFileSync("git.exe", ["-C", repositoryRoot, ...args], { encoding: "utf8", windowsHide: true, timeout: 10000 }).trim();
}

function gitExit(repositoryRoot, args) {
  const result = spawnSync("git.exe", ["-C", repositoryRoot, ...args], { encoding: "utf8", windowsHide: true, timeout: 10000 });
  return { status: result.status, stdout: String(result.stdout ?? "").trim(), stderr: String(result.stderr ?? "").trim() };
}

function repositoryEvidence(repositoryRoot, expectedBaseline = REQUIRED_BASELINE) {
  try {
    const top = gitText(repositoryRoot, ["rev-parse", "--show-toplevel"]);
    const head = gitText(repositoryRoot, ["rev-parse", "HEAD"]);
    const branch = gitText(repositoryRoot, ["branch", "--show-current"]);
    const originMain = gitText(repositoryRoot, ["rev-parse", "refs/remotes/origin/main"]);
    const status = gitText(repositoryRoot, ["status", "--porcelain=v1", "--untracked-files=all"]);
    const headDescends = gitExit(repositoryRoot, ["merge-base", "--is-ancestor", expectedBaseline, head]).status === 0;
    const originDescends = gitExit(repositoryRoot, ["merge-base", "--is-ancestor", expectedBaseline, originMain]).status === 0;
    return { available: true, top, head, branch: branch || null, detached_head: branch === "", origin_main: originMain, clean: status === "", status_lines: status ? status.split(/\r?\n/) : [], head_descends_from_required_baseline: headDescends, origin_main_descends_from_required_baseline: originDescends };
  } catch (error) {
    return { available: false, error: String(error.message), clean: false, status_lines: [] };
  }
}

function walkFiles(root, predicate = () => true) {
  if (!existsSync(root)) return [];
  const files = [];
  const pending = [path.resolve(root)];
  while (pending.length) {
    const current = pending.pop();
    for (const entry of readdirSync(current, { withFileTypes: true })) {
      const full = path.join(current, entry.name);
      let stats;
      try { stats = lstatSync(full); } catch { continue; }
      if (stats.isSymbolicLink()) continue;
      if (stats.isDirectory()) pending.push(full);
      else if (stats.isFile() && predicate(full)) files.push(full);
      if (files.length > MAX_SCAN_FILES) throw new Error("CANONICAL_SCAN_FILE_LIMIT_EXCEEDED");
    }
  }
  return files;
}

function validateCanonicalQueueRecords(queueRoot, descriptors, { testOnlyAllowAlternateQueueRoot = false } = {}) {
  if (descriptors.length === 0) return [];
  const result = spawnSync(POWERSHELL_EXE, [
    "-NoLogo",
    "-NoProfile",
    "-NonInteractive",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    CANONICAL_QUEUE_VALIDATOR,
    "-RepositoryRoot",
    REPOSITORY_ROOT,
    "-QueueRoot",
    path.resolve(queueRoot),
    ...(testOnlyAllowAlternateQueueRoot ? ["-TestOnlyAllowAlternateQueueRoot"] : []),
  ], {
    cwd: REPOSITORY_ROOT,
    encoding: "utf8",
    windowsHide: true,
    timeout: 120000,
    maxBuffer: 16 * 1024 * 1024,
    input: JSON.stringify(descriptors),
  });
  if (result.error || result.status !== 0) {
    throw new Error(`CANONICAL_QUEUE_VALIDATOR_FAILED:${result.error?.message ?? String(result.stderr ?? "").trim() ?? result.status}`);
  }
  const output = String(result.stdout ?? "").trim().replace(/^\uFEFF/, "");
  const parsed = JSON.parse(output);
  return Array.isArray(parsed) ? parsed : [parsed];
}

function queueInventory(queueRoot, { testOnlyAllowAlternateQueueRoot = false } = {}) {
  const root = path.resolve(queueRoot);
  const errors = [];
  const records = [];
  const placeholders = [];
  const identities = new Map();
  const candidates = [];
  const fixtureRoot = path.resolve(REPOSITORY_ROOT, ".codex-local", "fixtures");
  const productionRoot = samePath(root, CANONICAL_QUEUE_ROOT);
  const isolatedTestRoot = testOnlyAllowAlternateQueueRoot && pathInside(root, fixtureRoot);
  if (!productionRoot && !isolatedTestRoot) {
    errors.push({ path: root, error: testOnlyAllowAlternateQueueRoot ? "TEST_QUEUE_ROOT_OUTSIDE_ISOLATED_FIXTURES" : "NONCANONICAL_QUEUE_ROOT_REJECTED" });
    return { root, generated_record_count: 0, placeholder_count: 0, unknown_or_invalid_count: 1, records, errors };
  }
  if (!existsSync(root)) return { root, generated_record_count: 0, placeholder_count: 0, unknown_or_invalid_count: 0, records, errors };
  let rootStats;
  try { rootStats = lstatSync(root); }
  catch (error) { return { root, generated_record_count: 0, placeholder_count: 0, unknown_or_invalid_count: 1, records, errors: [{ path: root, error: `CANONICAL_QUEUE_ROOT_UNREADABLE:${String(error.message)}` }] }; }
  if (rootStats.isSymbolicLink() || !rootStats.isDirectory()) {
    return { root, generated_record_count: 0, placeholder_count: 0, unknown_or_invalid_count: 1, records, errors: [{ path: root, error: "CANONICAL_QUEUE_ROOT_REPARSE_OR_TYPE_REJECTED" }] };
  }

  let stateEntries;
  try { stateEntries = readdirSync(root, { withFileTypes: true }); }
  catch (error) { return { root, generated_record_count: 0, placeholder_count: 0, unknown_or_invalid_count: 1, records, errors: [{ path: root, error: `CANONICAL_QUEUE_ROOT_ENUMERATION_FAILED:${String(error.message)}` }] }; }
  for (const stateEntry of stateEntries) {
    const statePath = path.join(root, stateEntry.name);
    let stateStats;
    try { stateStats = lstatSync(statePath); }
    catch (error) { errors.push({ path: statePath, error: `QUEUE_STATE_ENTRY_UNREADABLE:${String(error.message)}` }); continue; }
    if (stateStats.isSymbolicLink()) { errors.push({ path: statePath, error: "QUEUE_STATE_REPARSE_POINT_REJECTED" }); continue; }
    if (!stateStats.isDirectory()) { errors.push({ path: statePath, error: "UNKNOWN_QUEUE_ROOT_ENTRY" }); continue; }

    let entries;
    try { entries = readdirSync(statePath, { withFileTypes: true }); }
    catch (error) { errors.push({ path: statePath, error: `QUEUE_STATE_ENUMERATION_FAILED:${String(error.message)}` }); continue; }
    for (const entry of entries) {
      const filePath = path.join(statePath, entry.name);
      let stats;
      try { stats = lstatSync(filePath); }
      catch (error) { errors.push({ path: filePath, error: `QUEUE_ENTRY_UNREADABLE:${String(error.message)}` }); continue; }
      if (stats.isSymbolicLink()) { errors.push({ path: filePath, error: "QUEUE_RECORD_REPARSE_POINT_REJECTED" }); continue; }
      if (entry.name === ".gitkeep" && stats.isFile()) { placeholders.push(filePath); continue; }
      if (!QUEUE_STATES.has(stateEntry.name)) { errors.push({ path: filePath, error: "UNKNOWN_OR_LEGACY_QUEUE_STATE_FILE" }); continue; }
      if (!stats.isFile()) { errors.push({ path: filePath, error: "UNKNOWN_OR_NESTED_QUEUE_ENTRY" }); continue; }
      const match = entry.name.match(/^([A-Za-z0-9_-][A-Za-z0-9._-]{6,158})\.r([1-9][0-9]*)\.json$/);
      if (!match) { errors.push({ path: filePath, error: "UNKNOWN_GENERATED_QUEUE_FILENAME" }); continue; }
      candidates.push({ path: filePath, state: stateEntry.name, mission_id: match[1], mission_revision: Number(match[2]) });
    }
  }

  let validations = [];
  try { validations = validateCanonicalQueueRecords(root, candidates, { testOnlyAllowAlternateQueueRoot }); }
  catch (error) {
    for (const candidate of candidates) errors.push({ path: candidate.path, error: String(error.message) });
  }
  const validationByPath = new Map(validations.map((validation) => [path.resolve(String(validation.path ?? "")).toLowerCase(), validation]));
  for (const candidate of candidates) {
    const validation = validationByPath.get(path.resolve(candidate.path).toLowerCase());
    if (!validation?.valid) {
      errors.push({ path: candidate.path, error: "CANONICAL_QUEUE_DOCUMENT_REJECTED", validation_errors: Array.isArray(validation?.errors) ? validation.errors : ["CANONICAL_QUEUE_VALIDATION_RESULT_MISSING"] });
      continue;
    }
    let value;
    try { value = readJson(candidate.path); }
    catch (error) { errors.push({ path: candidate.path, error: `VALIDATED_QUEUE_RECORD_BECAME_UNREADABLE:${String(error.message)}` }); continue; }
    const identity = queueIdentity(value);
    if (!identity || identity.mission_id !== candidate.mission_id || identity.mission_revision !== candidate.mission_revision) {
      errors.push({ path: candidate.path, error: "QUEUE_FILENAME_DOCUMENT_IDENTITY_MISMATCH" });
      continue;
    }
    const key = `${identity.mission_id}:${identity.mission_revision}`;
    const prior = identities.get(key);
    if (prior) errors.push({ path: candidate.path, error: `DUPLICATE_QUEUE_MISSION_REVISION:${prior}` });
    else identities.set(key, candidate.path);
    records.push({ path: candidate.path, state: candidate.state, value, identity, validation: { canonical_validator: validation.canonical_validator, queue_document_sha256: validation.queue_document_sha256, queue_state_authority: validation.queue_state_authority } });
  }
  return {
    root,
    generated_record_count: records.length,
    placeholder_count: placeholders.length,
    unknown_or_invalid_count: errors.length,
    records,
    errors,
  };
}

function canonicalIdentity(value) {
  const mission = value?.durable_mission ?? value?.mission ?? value;
  const missionId = value?.mission_id ?? mission?.mission_id ?? value?.source_binding?.durable_mission_id ?? value?.source_request?.mission_id ?? null;
  const revision = value?.mission_revision ?? mission?.mission_revision ?? value?.source_binding?.durable_mission_revision ?? value?.source_request?.mission_revision ?? null;
  const runId = value?.run_id ?? value?.result_id ?? value?.source_request?.run_id ?? (missionId && revision ? `canonical-result-${missionId}-${revision}` : null);
  if (!missionId || !Number.isInteger(Number(revision)) || Number(revision) < 1) return null;
  return { mission_id: String(missionId), mission_revision: Number(revision), run_id: runId ? String(runId) : `canonical-result-${missionId}-${revision}` };
}

function roleForFile(filePath, value, runtimeRoot) {
  const leaf = path.basename(filePath).toLowerCase();
  const schema = String(value?.schema_version ?? "");
  if (leaf === "gm.json" || schema === "tsf_mission_envelope_v1") return "mission";
  if (leaf === "queue-record-preflight-pending.json" && path.basename(path.dirname(filePath)).toLowerCase() === "recovery") return "recovery_marker";
  if (leaf === "qd.json" || schema === "tsf_canonical_queue_document_v1") return "runtime_queue_document";
  if (leaf === "qe.json") return "queue_result";
  if (leaf === "lc.json" || schema === "tsf_lifecycle_terminal_result_v1") return "lifecycle";
  if (leaf === "ar.json") return "adapter";
  if (leaf === "vr.json") return "verifier";
  if (leaf === "dr.json" || schema === "tsf_result_envelope_v1") return "result";
  if (leaf === "cc.json" || schema === "tsf_tim_required_response_v1") return "response";
  if (leaf === "stop_record.json" || schema === INTERRUPTION_SCHEMA) return "interruption";
  if (leaf === "rc.json") return "recovery_marker";
  if (leaf === "mp.json") return "preparation";
  if (/^a-[a-z2-7]{32}\.json$/.test(leaf) || schema === "tsf_admission_decision_v1") return "admission";
  if (/^t-[a-z2-7]{32}\.json$/.test(leaf) || schema === "tsf_admission_transaction_v1") return "transaction";
  if (pathInside(filePath, runtimeRoot) && leaf === "manifest.json") return "manifest";
  return null;
}

function groupKey(identity) {
  return `${identity.mission_id}\u0000${identity.mission_revision}\u0000${identity.run_id}`;
}

function queueIdentity(value) {
  return canonicalIdentity(value) ?? canonicalIdentity(value?.durable_mission) ?? canonicalIdentity({
    mission_id: value?.source_binding?.durable_mission_id,
    mission_revision: value?.source_binding?.durable_mission_revision,
  });
}

function addArtifact(group, role, filePath, value, stats) {
  if (!group.artifacts[role]) group.artifacts[role] = [];
  group.artifacts[role].push({ path: filePath, sha256: sha256(readFileSync(filePath)), value, modified_at: stats.mtime.toISOString() });
}

function latestArtifact(group) {
  return Object.entries(group.artifacts)
    .flatMap(([role, values]) => values.map((entry) => ({ role, ...entry })))
    .sort((a, b) => Date.parse(b.modified_at) - Date.parse(a.modified_at))[0] ?? null;
}

function artifactOne(group, role) {
  const values = group.artifacts[role] ?? [];
  return values.length ? values[values.length - 1] : null;
}

function currentQueueState(group) {
  const documents = group.queue_documents ?? [];
  if (!documents.length) return null;
  const sorted = [...documents].sort((a, b) => Date.parse(b.modified_at) - Date.parse(a.modified_at));
  return sorted[0].state;
}

function duplicateDisposition(group) {
  const documents = group.queue_documents ?? [];
  if (documents.length <= 1) return { state: "NONE", paths: documents.map((item) => item.path) };
  const hashes = new Set(documents.map((item) => item.sha256));
  return { state: hashes.size === 1 ? "EXACT_DUPLICATE" : "CONFLICT", paths: documents.map((item) => item.path), hashes: [...hashes] };
}

function processEvidenceFor(identity, ownership) {
  const owner = ownership?.disposition === "ACTIVE_OWNER_CONFIRMED" ? ownership.owner : null;
  const active = owner?.active_mission;
  const identityMatches = active && active.mission_id === identity.mission_id && Number(active.mission_revision) === identity.mission_revision && active.run_id === identity.run_id;
  const children = identityMatches ? owner.owned_children ?? [] : [];
  const confirmedChildren = children.filter((child) => processMatchesOwner(child, inspectProcess(child.process_id)));
  return {
    owner_disposition: ownership?.disposition ?? "ABSENT",
    server_instance_id: owner?.server_instance_id ?? null,
    active_mission_identity_matches: Boolean(identityMatches),
    owned_child_process_ids: children.map((item) => item.process_id),
    confirmed_owned_child_process_ids: confirmedChildren.map((item) => item.process_id),
    process_confirmed: Boolean(identityMatches && confirmedChildren.length),
  };
}

function recoveryMetadata(classification) {
  const safe = ACTIONS[classification] ?? ACTIONS.STALE_OR_UNKNOWN;
  const recommended = safe[0];
  const authority = classification.includes("TIM_REQUIRED") || classification === "CONFLICTING_REPLAY" || classification === "RESULT_WITHOUT_ADMISSION" || classification === "ADMISSION_WITH_QUEUE_MISMATCH"
    ? "TIM_OR_EXISTING_CANONICAL_CONTROL_REQUIRED"
    : recommended === "RETRY_AS_NEW_RUN" ? "EXPLICIT_OPERATOR_CONFIRMATION_AND_CANONICAL_REVALIDATION" : "EXPLICIT_LOCAL_OPERATOR_CONFIRMATION";
  return { safe_operator_options: safe, recommended_action: recommended, authority_required: authority };
}

function classifyGroup(group, ownership, allGroups = null) {
  const queueState = currentQueueState(group);
  const duplicate = duplicateDisposition(group);
  const admissionEntry = artifactOne(group, "admission");
  const admission = admissionEntry?.value ?? null;
  const lifecycleEntry = artifactOne(group, "lifecycle");
  const lifecycle = lifecycleEntry?.value ?? null;
  const responseEntry = artifactOne(group, "response");
  const resultEntry = artifactOne(group, "result");
  const verifierEntry = artifactOne(group, "verifier");
  const interruptionEntry = artifactOne(group, "interruption");
  const processEvidence = processEvidenceFor(group.identity, ownership);
  let classification;

  const roleConflict = Object.values(group.artifacts).some((entries) => entries.length > 1 && new Set(entries.map((item) => item.sha256)).size > 1);
  if (duplicate.state === "CONFLICT" || roleConflict) classification = "CONFLICTING_REPLAY";
  else if (duplicate.state === "EXACT_DUPLICATE") classification = "DUPLICATE_EXACT_REPLAY";
  else if (admission && queueState && admission.queue_state_to && admission.queue_state_to !== queueState) classification = "ADMISSION_WITH_QUEUE_MISMATCH";
  else if (admission && admission.status === "ADMITTED_WITH_CAVEATS") classification = "COMPLETED_ADMITTED_WITH_CAVEATS";
  else if (admission && admission.status === "ADMITTED") classification = "COMPLETED_ADMITTED";
  else if (admission && REJECTED_ADMISSIONS.has(admission.status)) classification = "COMPLETED_REJECTED";
  else if (lifecycle?.terminal_status === "TIM_REQUIRED" && responseEntry?.value?.response_type === "DENY_REQUEST") classification = "COMPLETED_REJECTED";
  else if (lifecycle?.terminal_status === "TIM_REQUIRED" && responseEntry?.value?.revision) {
    const revision = responseEntry.value.revision;
    const targetIdentity = canonicalIdentity(revision);
    classification = targetIdentity && allGroups?.has(groupKey(targetIdentity)) ? "TIM_REQUIRED_RESPONDED_REVISION_EXISTS" : "STALE_OR_UNKNOWN";
  }
  else if (lifecycle?.terminal_status === "TIM_REQUIRED") classification = "TIM_REQUIRED_PENDING_RESPONSE";
  else if ((resultEntry || String(lifecycle?.terminal_status ?? "").startsWith("COMPLETED")) && !admission) classification = "RESULT_WITHOUT_ADMISSION";
  else if (processEvidence.process_confirmed) classification = "RUNNING_PROCESS_CONFIRMED";
  else if (interruptionEntry || ["worker_running", "postrun_pending"].includes(queueState)) classification = "INTERRUPTED_PROCESS_GONE";
  else if (["inbox", "drafted"].includes(queueState)) classification = "QUEUED_NOT_STARTED";
  else if (["preflight_pending", "approved_for_worker"].includes(queueState)) classification = "DISPATCHING_WITHOUT_OWNER";
  else if (queueState === "blocked_needs_tim") classification = "TIM_REQUIRED_PENDING_RESPONSE";
  else classification = "STALE_OR_UNKNOWN";

  const latest = latestArtifact(group);
  const canonicalPaths = Object.fromEntries(Object.entries(group.artifacts).map(([role, entries]) => [role, entries.map((item) => item.path)]));
  canonicalPaths.queue_documents = (group.queue_documents ?? []).map((item) => item.path);
  const replayState = classification === "CONFLICTING_REPLAY" ? "CONFLICTING_REPLAY" : duplicate.state === "EXACT_DUPLICATE" ? "IDEMPOTENT_REPLAY" : "NONE";
  const recovery = recoveryMetadata(classification);
  const authoritativeArtifacts = Object.fromEntries(Object.entries(group.artifacts).filter(([role]) => !["interruption", "recovery_marker"].includes(role)));
  const immutable = {
    identity: group.identity,
    canonical_paths: Object.fromEntries(Object.entries(authoritativeArtifacts).map(([role, entries]) => [role, entries.map((item) => item.path)])),
    canonical_hashes: Object.fromEntries(Object.entries(authoritativeArtifacts).map(([role, entries]) => [role, entries.map((item) => item.sha256)])),
    queue_hashes: (group.queue_documents ?? []).map((item) => item.sha256),
  };
  const evidenceHash = hashObject(immutable);
  const operatorMessage = classification === "RUNNING_PROCESS_CONFIRMED" ? "EXISTING_ACTIVE_MISSION"
    : ["COMPLETED_ADMITTED", "COMPLETED_ADMITTED_WITH_CAVEATS", "COMPLETED_REJECTED"].includes(classification) ? "EXISTING_COMPLETED_MISSION"
      : classification === "DUPLICATE_EXACT_REPLAY" ? "IDEMPOTENT_REPLAY"
        : classification === "CONFLICTING_REPLAY" ? "CONFLICTING_REPLAY"
          : ["INTERRUPTED_PROCESS_GONE", "DISPATCHING_WITHOUT_OWNER"].includes(classification) ? "NEW_RUN_REQUIRED" : classification;
  return {
    recovery_item_id: `recovery-${evidenceHash.slice(0, 32)}`,
    evidence_hash: evidenceHash,
    mission_id: group.identity.mission_id,
    mission_revision: group.identity.mission_revision,
    run_id: group.identity.run_id,
    result_id: admission?.result_id ?? resultEntry?.value?.result_id ?? lifecycle?.result_id ?? group.identity.run_id,
    classification,
    status: classification,
    operator_message: operatorMessage,
    canonical_paths: canonicalPaths,
    last_canonical_event: latest ? { role: latest.role, path: latest.path, sha256: latest.sha256, modified_at: latest.modified_at } : null,
    last_known_queue_state: queueState,
    process_evidence: processEvidence,
    admission_state: admission ? { status: admission.status, receipt_id: admission.receipt_id ?? null, path: admissionEntry.path, queue_state_to: admission.queue_state_to ?? null } : { status: "ABSENT" },
    verifier_state: verifierEntry ? { verdict: verifierEntry.value?.verdict ?? "UNKNOWN", path: verifierEntry.path } : { verdict: "ABSENT" },
    duplicate_replay_state: { ...duplicate, queue_document_duplicate_state: duplicate.state, state: replayState },
    interruption_evidence: interruptionEntry ? { path: interruptionEntry.path, sha256: interruptionEntry.sha256 } : null,
    ...recovery,
    immutable_history_warning: "Canonical mission, queue, lifecycle, result, verifier, preservation, admission, and response history is immutable and is never rewritten by HQ Dispatch recovery.",
  };
}

export function reconcileCanonicalState({ runtimeRoot = CANONICAL_RUNTIME_ROOT, queueRoot = CANONICAL_QUEUE_ROOT, ownership = readOwnership(), includeAll = true, testOnlyAllowAlternateQueueRoot = false } = {}) {
  const groups = new Map();
  const inventory = queueInventory(queueRoot, { testOnlyAllowAlternateQueueRoot });
  const parseErrors = [...inventory.errors];
  const ensure = (identity) => {
    const key = groupKey(identity);
    if (!groups.has(key)) groups.set(key, { identity, artifacts: {}, queue_documents: [] });
    return groups.get(key);
  };

  try {
    for (const filePath of walkFiles(runtimeRoot, (candidate) => candidate.toLowerCase().endsWith(".json"))) {
      let value;
      try { value = readJson(filePath); } catch (error) { parseErrors.push({ path: filePath, error: String(error.message) }); continue; }
      const identity = canonicalIdentity(value) ?? canonicalIdentity(value?.source_request) ?? canonicalIdentity(value?.binding);
      const role = roleForFile(filePath, value, runtimeRoot);
      if (!identity || !role) continue;
      addArtifact(ensure(identity), role, filePath, value, statSync(filePath));
    }
    for (const record of inventory.records) {
      ensure(record.identity).queue_documents.push({ path: record.path, state: record.state, sha256: sha256(readFileSync(record.path)), modified_at: statSync(record.path).mtime.toISOString(), value: record.value });
    }
  } catch (error) {
    parseErrors.push({ path: runtimeRoot, error: String(error.message) });
  }

  const items = [...groups.values()].map((group) => classifyGroup(group, ownership, groups)).sort((a, b) => `${a.mission_id}:${a.mission_revision}`.localeCompare(`${b.mission_id}:${b.mission_revision}`));
  const visible = includeAll ? items : items.filter((item) => !["COMPLETED_ADMITTED", "COMPLETED_ADMITTED_WITH_CAVEATS", "COMPLETED_REJECTED"].includes(item.classification));
  const counts = Object.fromEntries([...new Set(items.map((item) => item.classification))].sort().map((classification) => [classification, items.filter((item) => item.classification === classification).length]));
  const unsafe = parseErrors.length > 0 || items.some((item) => item.classification === "CONFLICTING_REPLAY");
  return {
    schema_version: RECONCILIATION_SCHEMA,
    generated_at: nowIso(),
    runtime_root: path.resolve(runtimeRoot),
    queue_root: path.resolve(queueRoot),
    read_only: true,
    canonical_authority_unchanged: true,
    automatic_resume_performed: false,
    old_thread_or_turn_resumed: false,
    safe_to_reconcile: !unsafe,
    parse_errors: parseErrors,
    queue_inventory: {
      root: inventory.root,
      generated_record_count: inventory.generated_record_count,
      placeholder_count: inventory.placeholder_count,
      unknown_or_invalid_count: inventory.unknown_or_invalid_count,
    },
    counts,
    items: visible,
  };
}

function check(id, status, evidence, nextAction) {
  return { id, status, evidence, next_action: nextAction };
}

function canWriteDirectory(directory) {
  let current = path.resolve(directory);
  while (!existsSync(current)) {
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
  try { accessSync(current, fsConstants.R_OK | fsConstants.W_OK); return { writable: true, checked_path: current }; }
  catch (error) { return { writable: false, checked_path: current, error: String(error.message) }; }
}

function commandAvailable(command) {
  const result = spawnSync("C:\\Windows\\System32\\where.exe", [command], { encoding: "utf8", windowsHide: true, timeout: 10000 });
  return { available: result.status === 0, paths: String(result.stdout ?? "").trim().split(/\r?\n/).filter(Boolean) };
}

function schemaEvidence(repositoryRoot) {
  const relative = [
    "fleet/control/mission-envelope.schema.v1.json",
    "fleet/control/canonical-queue-document.schema.v1.json",
    "fleet/control/lifecycle-terminal-result.schema.v1.json",
    "fleet/control/result-envelope.schema.v1.json",
    "fleet/control/admission-decision.schema.v1.json",
    "fleet/control/tim-required-request.schema.v1.json",
    "fleet/control/tim-required-response.schema.v1.json",
    "fleet/control/hq-dispatch/hq-dispatch-skill-registry.v1.json",
    "fleet/control/hq-dispatch/hq-dispatch-setup-action-registry.v1.json",
    "fleet/control/hq-dispatch/hq-dispatch-process-owner.schema.v1.json",
    "fleet/control/hq-dispatch/hq-dispatch-interruption-evidence.schema.v1.json",
    "fleet/control/hq-dispatch/hq-dispatch-recovery-receipt.schema.v1.json",
  ];
  const errors = [];
  const hashes = [];
  for (const item of relative) {
    const full = path.join(repositoryRoot, ...item.split("/"));
    try { readJson(full); hashes.push({ path: item, sha256: sha256(readFileSync(full)) }); }
    catch (error) { errors.push({ path: item, error: String(error.message) }); }
  }
  return { valid: errors.length === 0, files: hashes, errors };
}

function pathBudget(repositoryRoot, runtimeRoot) {
  const maximum = 225;
  const templates = [
    path.join(runtimeRoot, "q", "a".repeat(32), "b".repeat(32), "STOP_RECORD.json"),
    path.join(runtimeRoot, "q", "a".repeat(32), "b".repeat(32), "recovery", "queue-record-preflight-pending.json"),
    path.join(runtimeRoot, "p", "a".repeat(32), "b".repeat(32), "r", `a-${"c".repeat(32)}.json`),
    path.join(repositoryRoot, ".codex-local", "hq-dispatch", "v1", "recovery-receipts", `hr-${"d".repeat(32)}.json`),
  ];
  const rows = templates.map((item) => ({ path: item, length: item.length, within_target: item.length <= maximum }));
  return { valid: rows.every((row) => row.within_target), target_limit: maximum, maximum_path_length: Math.max(...rows.map((row) => row.length)), paths: rows };
}

export function runDoctor({
  repositoryRoot = REPOSITORY_ROOT,
  runtimeRoot = CANONICAL_RUNTIME_ROOT,
  queueRoot = CANONICAL_QUEUE_ROOT,
  ownerPath = OWNER_PATH,
  host = HQ_HOST,
  port = HQ_PORT,
  expectedBaseline = REQUIRED_BASELINE,
  allowDirtyForTest = false,
  demoMode = false,
  testOnlyAllowAlternateQueueRoot = false,
} = {}) {
  const checks = [];
  const repo = repositoryEvidence(repositoryRoot, expectedBaseline);
  const repoValid = repo.available && samePath(repo.top, repositoryRoot) && repo.head_descends_from_required_baseline && repo.origin_main_descends_from_required_baseline;
  checks.push(check("repository", repoValid ? "GREEN" : "UNSAFE_TO_START", repo, repoValid ? "Continue with this exact worktree and commit ancestry." : "Restore the exact TSF repository/worktree and required ancestry; do not start HQ Dispatch."));
  const cleanEnough = repo.clean || allowDirtyForTest || demoMode;
  checks.push(check("worktree_cleanliness", cleanEnough ? (repo.clean ? "GREEN" : "GREEN_WITH_CAVEATS") : "UNSAFE_TO_START", { clean: repo.clean, status_lines: repo.status_lines, test_or_demo_override: allowDirtyForTest || demoMode, policy: "Git status excludes only canonical ignored generated queue records; tracked changes and unrelated untracked files remain visible." }, cleanEnough ? "No source cleanup is required by Doctor." : "Review and intentionally commit or remove only genuine source changes; Doctor will not reset the worktree or delete runtime evidence."));

  const node = { available: existsSync(process.execPath), executable: process.execPath, version: process.version };
  const powerShell = { available: existsSync(POWERSHELL_EXE), executable: POWERSHELL_EXE };
  const codex = commandAvailable("codex");
  checks.push(check("runtime_tools", node.available && powerShell.available && codex.available ? "GREEN" : "UNSAFE_TO_START", { node, powershell: powerShell, codex_cli_or_app_server: codex, availability_check_launched_app_server: false }, node.available && powerShell.available && codex.available ? "Use the detected fixed executables." : "Install or expose Node, Windows PowerShell, and Codex CLI/app-server before Start."));

  const listeners = inspectListeners(port);
  const ownership = readOwnership(ownerPath);
  const owner = ownership.owner;
  const matchingListener = owner && listeners.some((entry) => Number(entry.process_id) === Number(owner.process_id) && [host, `::ffff:${host}`].includes(String(entry.host).toLowerCase()));
  let ownerStatus = "GREEN";
  let ownerAction = "Start may claim a fresh exact ownership record.";
  if (ownership.disposition === "ACTIVE_OWNER_CONFIRMED" && matchingListener) {
    ownerStatus = "GREEN_WITH_CAVEATS";
    ownerAction = "Use the existing HQ Dispatch instance or run Stop-TsfHqDispatchV1; a second Start is rejected.";
  } else if (ownership.disposition !== "ABSENT") {
    ownerStatus = ownership.disposition === "STALE_PROCESS_GONE" ? "ACTION_REQUIRED" : "UNSAFE_TO_START";
    ownerAction = "Inspect this evidence, then run Stop-TsfHqDispatchV1 -RecoverVerifiedStaleOwnership only if Doctor confirms stale identity; no process will be killed.";
  } else if (listeners.length) {
    ownerStatus = "UNSAFE_TO_START";
    ownerAction = "Identify and stop the unrelated listener yourself or choose no action; HQ Dispatch will not terminate it.";
  }
  checks.push(check("process_owner_and_listener", ownerStatus, { host, port, ownership, listeners, matching_listener: Boolean(matchingListener) }, ownerAction));

  const roots = {
    queue_root: { path: path.resolve(queueRoot), exists: existsSync(queueRoot), permission: canWriteDirectory(queueRoot) },
    runtime_root: { path: path.resolve(runtimeRoot), exists: existsSync(runtimeRoot), permission: canWriteDirectory(runtimeRoot) },
    lifecycle_root: { path: path.dirname(ownerPath), exists: existsSync(path.dirname(ownerPath)), permission: canWriteDirectory(path.dirname(ownerPath)) },
  };
  const rootsSafe = Object.values(roots).every((item) => pathInside(item.path, repositoryRoot) && item.permission.writable);
  checks.push(check("canonical_and_local_roots", rootsSafe ? (Object.values(roots).every((item) => item.exists) ? "GREEN" : "GREEN_WITH_CAVEATS") : "UNSAFE_TO_START", roots, rootsSafe ? "Missing ignored runtime directories will be created only by Start or canonical mission controls." : "Correct root containment or permissions; Doctor will not create or repair directories."));

  const schemas = schemaEvidence(repositoryRoot);
  checks.push(check("schemas_and_static_plugin_baseline", schemas.valid ? "GREEN" : "UNSAFE_TO_START", { ...schemas, plugin_baseline: "REFERENCE_ONLY_NOT_RUNTIME_DISCOVERY", credentials_required_for_demo_or_offline: false }, schemas.valid ? "Keep static plugin records reference-only; no plugin or credential action is needed." : "Restore parseable committed schemas and static registries."));

  const budget = pathBudget(repositoryRoot, runtimeRoot);
  checks.push(check("windows_path_budget", budget.valid ? "GREEN" : "UNSAFE_TO_START", budget, budget.valid ? "Use compact canonical and lifecycle paths shown in evidence." : "Move the worktree to the required short path before creating runtime artifacts."));

  const reconciliation = reconcileCanonicalState({ runtimeRoot, queueRoot, ownership, testOnlyAllowAlternateQueueRoot: testOnlyAllowAlternateQueueRoot || demoMode });
  const queueInventoryStatus = reconciliation.queue_inventory.unknown_or_invalid_count === 0 ? "GREEN" : "UNSAFE_TO_START";
  checks.push(check("runtime_queue_evidence_policy", queueInventoryStatus, reconciliation.queue_inventory, queueInventoryStatus === "GREEN" ? "Preserve the canonical generated queue records; they are durable local evidence and are not source dirtiness." : "Inspect the unknown, invalid, nested, or duplicate protected queue file; Doctor will not hide or delete it."));
  const conflictCount = reconciliation.items.filter((item) => item.classification === "CONFLICTING_REPLAY").length;
  const timCount = reconciliation.items.filter((item) => item.classification === "TIM_REQUIRED_PENDING_RESPONSE").length;
  const interruptedCount = reconciliation.items.filter((item) => ["INTERRUPTED_PROCESS_GONE", "DISPATCHING_WITHOUT_OWNER"].includes(item.classification)).length;
  let reconciliationStatus = "GREEN";
  if (!reconciliation.safe_to_reconcile || conflictCount) reconciliationStatus = "UNSAFE_TO_START";
  else if (timCount) reconciliationStatus = "TIM_REQUIRED";
  else if (interruptedCount || reconciliation.items.some((item) => ["RESULT_WITHOUT_ADMISSION", "ADMISSION_WITH_QUEUE_MISMATCH", "STALE_OR_UNKNOWN"].includes(item.classification))) reconciliationStatus = "ACTION_REQUIRED";
  checks.push(check("canonical_reconciliation", reconciliationStatus, { counts: reconciliation.counts, parse_errors: reconciliation.parse_errors, safe_to_reconcile: reconciliation.safe_to_reconcile, pending_tim_required: timCount, interrupted: interruptedCount, conflicting_replay: conflictCount }, reconciliationStatus === "GREEN" ? "No canonical recovery decision is pending." : reconciliationStatus === "TIM_REQUIRED" ? "Start may open the Recovery Center; answer only through the exact canonical TIM_REQUIRED response path." : reconciliationStatus === "ACTION_REQUIRED" ? "Open the Recovery Center and choose an evidence-bound action; no automatic repair or rerun occurs." : "Do not start. Preserve all records and obtain Tim review for the conflicting or invalid canonical evidence."));

  const orphanEvidence = ownership.owner?.owned_children ?? [];
  const confirmedOrphans = orphanEvidence.filter((child) => processMatchesOwner(child, inspectProcess(child.process_id)));
  const orphanStatus = ownership.disposition === "ACTIVE_OWNER_CONFIRMED" || confirmedOrphans.length === 0 ? "GREEN" : "ACTION_REQUIRED";
  checks.push(check("owned_child_evidence", orphanStatus, { recorded_children: orphanEvidence, confirmed_processes: confirmedOrphans }, orphanStatus === "GREEN" ? "No unowned TSF child process is inferred." : "Preserve evidence and use only exact owner recovery; do not kill an arbitrary PID."));

  const precedence = ["UNSAFE_TO_START", "TIM_REQUIRED", "ACTION_REQUIRED", "GREEN_WITH_CAVEATS", "GREEN"];
  const overall = precedence.find((status) => checks.some((item) => item.status === status)) ?? "GREEN";
  const activeOwner = ownership.disposition === "ACTIVE_OWNER_CONFIRMED";
  const ownerBlocksStart = ownership.disposition !== "ABSENT";
  const unsafe = checks.some((item) => item.status === "UNSAFE_TO_START");
  const safeToStart = !unsafe && !ownerBlocksStart && reconciliation.safe_to_reconcile;
  const exactNextAction = safeToStart
    ? "Run .\\tools\\hq-dispatch\\v1\\Start-TsfHqDispatchV1.ps1 in the foreground. No mission is submitted or resumed automatically."
    : activeOwner
      ? "Use the active local URL or run .\\tools\\hq-dispatch\\v1\\Stop-TsfHqDispatchV1.ps1."
      : checks.find((item) => item.status === "UNSAFE_TO_START")?.next_action ?? checks.find((item) => item.status === "ACTION_REQUIRED")?.next_action ?? "Review the evidence-bound Doctor checks.";
  return {
    schema_version: DOCTOR_SCHEMA,
    generated_at: nowIso(),
    read_only: true,
    repairs_performed: false,
    mission_resumed: false,
    process_terminated: false,
    overall_status: overall,
    safe_to_start: safeToStart,
    exact_next_action: exactNextAction,
    repository: repo,
    listener_state: { host, port, listeners },
    process_owner: ownership,
    active_child: ownership.owner?.owned_children ?? [],
    path_budget: budget,
    queue_consistency: reconciliation.counts,
    pending_tim_required_requests: timCount,
    interrupted_missions: interruptedCount,
    duplicate_replay_conflicts: conflictCount,
    canonical_runtime_root: path.resolve(runtimeRoot),
    canonical_queue_root: path.resolve(queueRoot),
    local_lifecycle_root: path.resolve(path.dirname(ownerPath)),
    checks,
    reconciliation,
  };
}

function baseOwner({ repositoryRoot, host, port, serverInstanceId, sessionGeneration, stopToken, mode }) {
  const observed = inspectProcess(process.pid);
  if (!observed || !samePath(observed.executable, process.execPath)) throw new Error("OWN_PROCESS_IDENTITY_UNAVAILABLE");
  const repo = repositoryEvidence(repositoryRoot);
  return {
    schema_version: OWNER_SCHEMA,
    lifecycle_state: "STARTING",
    mode,
    process_id: process.pid,
    process_start_time: observed.process_start_time,
    executable: observed.executable,
    repository: path.resolve(repositoryRoot),
    worktree: path.resolve(repositoryRoot),
    branch: repo.branch ?? null,
    commit: repo.head ?? null,
    host,
    port,
    server_instance_id: serverInstanceId,
    operator_session_generation: sessionGeneration,
    owned_child_process_ids: [],
    owned_children: [],
    active_mission: null,
    created_at: nowIso(),
    updated_at: nowIso(),
    control_token_sha256: sha256(stopToken),
  };
}

export class ProcessOwnership {
  constructor({ repositoryRoot = REPOSITORY_ROOT, ownerPath = OWNER_PATH, tokenPath = STOP_TOKEN_PATH, host = HQ_HOST, port = HQ_PORT, mode = "PRODUCTION" } = {}) {
    this.repositoryRoot = path.resolve(repositoryRoot);
    this.ownerPath = path.resolve(ownerPath);
    this.tokenPath = path.resolve(tokenPath);
    this.host = host;
    this.port = port;
    this.mode = mode;
    this.serverInstanceId = `hq-instance-${randomUUID()}`;
    this.sessionGeneration = `hq-session-generation-${randomUUID()}`;
    this.stopToken = randomBytes(32).toString("base64url");
    this.owner = null;
    this.ownedProcessRegistryPath = path.join(
      path.dirname(this.ownerPath),
      "owned-process-registry",
      `${this.serverInstanceId}.jsonl`,
    );
    this.ownedProcessRegistry = new Map();
    this.ownedProcessRegistrySequence = 0;
    this.ownedProcessRegistrationSequence = 0;
    this.ownedProcessRegistryGeneration = 0;
    this.ownedProcessRegistryPreviousHash = null;
    this.ownedProcessRegistryClosing = null;
    this.pendingOwnedProcessExitObservations = new Map();
    this.ownedProcessProjectedActions = [];
    this.defaultProcessActionSequence = 0;
    this.defaultProcessActionPreviousHash = null;
    this.processActionLedgerPath = path.join(
      path.dirname(this.ownerPath),
      "process-action-ledger",
      `${this.serverInstanceId}.jsonl`,
    );
    this.processActionRecorder = (action) => this.#appendDefaultProcessActionEvent(action);
  }

  setProcessActionRecorder(recorder, { ledgerPath = null } = {}) {
    if (recorder !== null && typeof recorder !== "function") throw new Error("OWNED_PROCESS_ACTION_RECORDER_INVALID");
    this.processActionRecorder = recorder ?? ((action) => this.#appendDefaultProcessActionEvent(action));
    if (ledgerPath) this.processActionLedgerPath = path.resolve(ledgerPath);
  }

  #appendDefaultProcessActionEvent(action) {
    const body = {
      schema_version: "tsf_process_action_v1",
      action_id: `process-action-${randomUUID()}`,
      writer_identity: `${this.mode}:${this.serverInstanceId}`,
      causal_ledger_sequence: ++this.defaultProcessActionSequence,
      utc_timestamp: nowIso(),
      previous_evidence_sha256: this.defaultProcessActionPreviousHash,
      ...action,
    };
    const event = { ...body, evidence_sha256: hashObject(body) };
    mkdirSync(path.dirname(this.processActionLedgerPath), { recursive: true });
    const descriptor = openSync(this.processActionLedgerPath, "a", 0o600);
    try {
      writeFileSync(descriptor, `${JSON.stringify(event)}\n`, "utf8");
      fsyncSync(descriptor);
    } finally {
      closeSync(descriptor);
    }
    this.defaultProcessActionPreviousHash = event.evidence_sha256;
    return event;
  }

  #appendOwnedProcessRegistryEvent(eventType, values = {}) {
    const body = {
      schema_version: OWNED_PROCESS_REGISTRY_SCHEMA,
      sequence: ++this.ownedProcessRegistrySequence,
      event_type: eventType,
      registry_generation: this.ownedProcessRegistryGeneration,
      server_instance_id: this.serverInstanceId,
      recorded_at: nowIso(),
      previous_evidence_sha256: this.ownedProcessRegistryPreviousHash,
      ...values,
    };
    const event = { ...body, evidence_sha256: hashObject(body) };
    mkdirSync(path.dirname(this.ownedProcessRegistryPath), { recursive: true });
    const descriptor = openSync(this.ownedProcessRegistryPath, "a", 0o600);
    try {
      writeFileSync(descriptor, `${JSON.stringify(event)}\n`, "utf8");
      fsyncSync(descriptor);
    } finally {
      closeSync(descriptor);
    }
    this.ownedProcessRegistryPreviousHash = event.evidence_sha256;
    return event;
  }

  #registryIdentityKey(identity) {
    return `${Number(identity?.process_id)}|${Date.parse(identity?.process_start_time)}`;
  }

  #registryEntryByProcessId(processId) {
    return [...this.ownedProcessRegistry.values()].find((entry) => Number(entry.process_id) === Number(processId)) ?? null;
  }

  #registerOwnedProcessAndLedgerEvent(identity, metadata = {}) {
    if (!identity || !Number.isInteger(Number(identity.process_id)) || !Number.isFinite(Date.parse(identity.process_start_time)) || !identity.executable) {
      throw new Error("OWNED_PROCESS_REGISTRY_IDENTITY_INVALID");
    }
    const key = this.#registryIdentityKey(identity);
    const existing = this.ownedProcessRegistry.get(key);
    if (existing) {
      if (existing.registration_status !== "COMMITTED") throw new Error("OWNED_PROCESS_REGISTRATION_INCOMPLETE");
      return existing;
    }
    const causalRegistrationAt = metadata.causal_registration_at ?? nowIso();
    if (this.ownedProcessRegistryClosing
        && (!Number.isFinite(Date.parse(causalRegistrationAt))
          || Date.parse(causalRegistrationAt) > Date.parse(this.ownedProcessRegistryClosing.cutoff_at))) {
      this.#appendOwnedProcessRegistryEvent("LATE_REGISTRATION_REJECTED", {
        process_id: Number(identity.process_id),
        process_start_time: identity.process_start_time,
        failure_classification: "OWNED_PROCESS_LATE_REGISTRATION_UNVERIFIED",
      });
      throw new Error("OWNED_PROCESS_LATE_REGISTRATION_UNVERIFIED");
    }
    this.ownedProcessRegistryGeneration += 1;
    const parentEntry = this.#registryEntryByProcessId(identity.parent_process_id);
    if (parentEntry && parentEntry.registration_status !== "COMMITTED") throw new Error("OWNED_PROCESS_PARENT_REGISTRATION_INCOMPLETE");
    const rootEntry = metadata.root_process_registration_id
      ? [...this.ownedProcessRegistry.values()].find((entry) => entry.process_registration_id === metadata.root_process_registration_id)
      : null;
    if (rootEntry && rootEntry.registration_status !== "COMMITTED") throw new Error("OWNED_PROCESS_ROOT_REGISTRATION_INCOMPLETE");
    const registrationBody = {
      process_registration_id: `owned-process-${randomUUID()}`,
      registration_sequence: ++this.ownedProcessRegistrationSequence,
      server_instance_id: this.serverInstanceId,
      process_id: Number(identity.process_id),
      process_start_time: identity.process_start_time,
      executable: identity.executable,
      process_name: identity.process_name ?? path.basename(identity.executable),
      parent_process_id: Number.isInteger(Number(identity.parent_process_id)) ? Number(identity.parent_process_id) : null,
      parent_process_start_time: identity.parent_process_start_time ?? null,
      parent_executable: identity.parent_executable ?? null,
      parent_process_registration_id: parentEntry?.process_registration_id ?? null,
      root_process_registration_id: rootEntry?.process_registration_id ?? metadata.root_process_registration_id ?? null,
      mission_identity: metadata.mission_identity ?? this.owner?.active_mission ?? null,
      worktree: metadata.worktree ?? this.owner?.worktree ?? this.repositoryRoot,
      candidate_commit: metadata.candidate_commit ?? this.owner?.commit ?? null,
      proof_capability_identity_sha256: metadata.capability_identity_sha256 ?? null,
      launch_event_identity_sha256: metadata.launch_identity_sha256 ?? hashObject({
        process_id: Number(identity.process_id),
        process_start_time: identity.process_start_time,
        executable: identity.executable,
        server_instance_id: this.serverInstanceId,
      }),
      ownership_evidence_sha256: metadata.ownership_evidence_sha256 ?? this.owner?.evidence_hash ?? null,
      causal_registration_at: causalRegistrationAt,
      registration_generation: this.ownedProcessRegistryGeneration,
      registration_status: "PENDING",
      immutable_registry_event_sha256: null,
      ownership_ledger_event_sha256: null,
      current_observation_status: "REGISTERED_ALIVE",
      terminal_cleanup_disposition: null,
      terminal_evidence_sha256: null,
    };
    if (!registrationBody.root_process_registration_id) registrationBody.root_process_registration_id = registrationBody.process_registration_id;
    let entry = { ...registrationBody };
    this.ownedProcessRegistry.set(key, entry);
    let registryEvent;
    try {
      registryEvent = this.#appendOwnedProcessRegistryEvent(this.ownedProcessRegistryClosing ? "LATE_PROCESS_REGISTERED" : "IMMUTABLE_REGISTRY_REGISTRATION", {
        ...registrationBody,
        late_registration: Boolean(this.ownedProcessRegistryClosing),
      });
      entry = { ...entry, immutable_registry_event_sha256: registryEvent.evidence_sha256 };
      this.ownedProcessRegistry.set(key, entry);
      const ledgerEvent = this.#recordProcessAction({
        proof_stage: "IMMUTABLE_OWNED_PROCESS_REGISTRATION",
        action_type: "REGISTER_PROOF_OWNERSHIP",
        reason: this.ownedProcessRegistryClosing ? "CAUSALLY_VALID_LATE_REGISTRATION" : "AUTHORITATIVE_OWNED_PROCESS_REGISTRATION",
        requested_operation: "REGISTER_EXACT_OWNED_PROCESS",
        os_api_result: { status: "REGISTRATION_PROJECTED_DURABLY" },
        registration_status: "COMMITTING",
        immutable_registry_event_sha256: registryEvent.evidence_sha256,
      }, entry);
      if (!ledgerEvent?.evidence_sha256) throw new Error("OWNED_PROCESS_LEDGER_DURABLE_EVENT_REQUIRED");
      const committedEvent = this.#appendOwnedProcessRegistryEvent("OWNED_PROCESS_REGISTRATION_COMMITTED", {
        process_registration_id: entry.process_registration_id,
        registration_sequence: entry.registration_sequence,
        process_id: entry.process_id,
        process_start_time: entry.process_start_time,
        immutable_registry_event_sha256: registryEvent.evidence_sha256,
        ownership_ledger_event_sha256: ledgerEvent.evidence_sha256,
      });
      entry = {
        ...entry,
        registration_status: "COMMITTED",
        ownership_ledger_event_sha256: ledgerEvent.evidence_sha256,
        registration_commit_event_sha256: committedEvent.evidence_sha256,
      };
      this.ownedProcessRegistry.set(key, entry);
    } catch (error) {
      const incomplete = { ...entry, registration_status: "INCOMPLETE_LEDGER_WRITE_FAILED", registration_failure: String(error?.message ?? error) };
      this.ownedProcessRegistry.set(key, incomplete);
      try {
        this.#appendOwnedProcessRegistryEvent("OWNED_PROCESS_REGISTRATION_COMMIT_FAILED", {
          process_registration_id: incomplete.process_registration_id,
          registration_sequence: incomplete.registration_sequence,
          process_id: incomplete.process_id,
          process_start_time: incomplete.process_start_time,
          immutable_registry_event_sha256: registryEvent?.evidence_sha256 ?? null,
          failure_classification: "OWNED_PROCESS_LEDGER_REGISTRATION_WRITE_FAILED",
        });
      } catch {}
      throw Object.assign(new Error(`OWNED_PROCESS_REGISTRATION_COMMIT_FAILED:${error?.message ?? error}`), { cause: error });
    }
    const bufferedExit = this.pendingOwnedProcessExitObservations.get(key);
    if (bufferedExit) {
      this.pendingOwnedProcessExitObservations.delete(key);
      this.#recordTerminalOwnedProcess(entry, bufferedExit.disposition, bufferedExit.observation, bufferedExit.values);
      entry = this.ownedProcessRegistry.get(key);
    }
    return entry;
  }

  #enrichOwnedProcessRegistration(entry, metadata) {
    if (!entry) throw new Error("OWNED_PROCESS_REGISTRY_ENTRY_MISSING");
    if (entry.terminal_cleanup_disposition) throw new Error("OWNED_PROCESS_REGISTRY_TERMINAL_ENTRY_CANNOT_BE_REBOUND");
    const next = {
      ...entry,
      proof_mission_identity: metadata.mission_identity ?? entry.proof_mission_identity ?? entry.mission_identity,
      proof_capability_identity_sha256: metadata.capability_identity_sha256 ?? entry.proof_capability_identity_sha256,
      proof_launch_event_identity_sha256: metadata.launch_identity_sha256 ?? entry.proof_launch_event_identity_sha256 ?? entry.launch_event_identity_sha256,
      proof_ownership_evidence_sha256: metadata.ownership_evidence_sha256 ?? entry.proof_ownership_evidence_sha256 ?? entry.ownership_evidence_sha256,
    };
    this.ownedProcessRegistry.set(this.#registryIdentityKey(entry), next);
    this.#appendOwnedProcessRegistryEvent("PROCESS_REGISTRATION_ENRICHED", {
      process_registration_id: next.process_registration_id,
      process_id: next.process_id,
      process_start_time: next.process_start_time,
      mission_identity: next.proof_mission_identity,
      proof_capability_identity_sha256: next.proof_capability_identity_sha256,
      launch_event_identity_sha256: next.proof_launch_event_identity_sha256,
      ownership_evidence_sha256: next.proof_ownership_evidence_sha256,
    });
    return next;
  }

  #recordProcessAction(action, entry) {
    const event = this.processActionRecorder({
      process_registration_id: entry.process_registration_id,
      registration_sequence: entry.registration_sequence,
      root_process_registration_id: entry.root_process_registration_id,
      parent_process_registration_id: entry.parent_process_registration_id,
      target_process_id: entry.process_id,
      target_process_start_time: entry.process_start_time,
      target_executable_identity: entry.executable,
      ownership_classification: "PROOF_OWNED",
      ownership_evidence_sha256: entry.ownership_evidence_sha256,
      parent_identity: entry.parent_process_id ? {
        process_id: entry.parent_process_id,
        process_start_time: entry.parent_process_start_time,
        executable: entry.parent_executable,
      } : null,
      server_instance_id: this.serverInstanceId,
      mission_identity: entry.mission_identity,
      candidate_worktree: entry.worktree,
      candidate_commit: entry.candidate_commit,
      launch_identity_sha256: entry.launch_event_identity_sha256,
      selection_method: "EXACT_REGISTERED_PID_START_TIME_EXECUTABLE",
      ...action,
    });
    if (!event || typeof event !== "object") throw new Error("OWNED_PROCESS_ACTION_LEDGER_EVENT_REQUIRED");
    this.ownedProcessProjectedActions.push(event);
    return event;
  }

  #recordTerminalOwnedProcess(entry, disposition, observation, values = {}) {
    if (!OWNED_PROCESS_TERMINAL_DISPOSITIONS.has(disposition)) throw new Error("OWNED_PROCESS_TERMINAL_DISPOSITION_INVALID");
    const current = this.ownedProcessRegistry.get(this.#registryIdentityKey(entry));
    if (!current) throw new Error("OWNED_PROCESS_REGISTRY_ENTRY_MISSING");
    if (current.registration_status !== "COMMITTED") throw new Error("OWNED_PROCESS_TERMINAL_BEFORE_COMMITTED_REGISTRATION");
    if (current.terminal_cleanup_disposition) {
      if (current.terminal_cleanup_disposition !== disposition) throw new Error("OWNED_PROCESS_CONFLICTING_TERMINAL_DISPOSITION");
      return current;
    }
    const observedAt = values.observed_exit_or_close_at ?? nowIso();
    const observationEvent = this.#appendOwnedProcessRegistryEvent("EXIT_OBSERVATION_RECORDED", {
      process_registration_id: current.process_registration_id,
      registration_sequence: current.registration_sequence,
      process_id: current.process_id,
      process_start_time: current.process_start_time,
      observed_exit_or_close_at: observedAt,
      final_liveness_observation: observation,
    });
    this.#recordProcessAction({
      proof_stage: "EXACT_OWNED_EXIT_OBSERVATION",
      action_type: "OBSERVE_PROCESS",
      reason: values.reason ?? "EXACT_REGISTERED_EXIT_OBSERVED",
      requested_operation: "OBSERVE_EXACT_REGISTERED_IDENTITY",
      os_api_result: { status: "EXIT_OBSERVATION_RECORDED", registry_evidence_sha256: observationEvent.evidence_sha256 },
      post_action_observation: { alive: disposition === "CLEANUP_UNCONFIRMED" ? Boolean(observation?.same_identity_alive) : false },
      observed_exit_or_close_at: observedAt,
    }, current);
    const event = this.#appendOwnedProcessRegistryEvent("TERMINAL_PROCESS_DISPOSITION_RECORDED", {
      process_registration_id: current.process_registration_id,
      registration_sequence: current.registration_sequence,
      process_id: current.process_id,
      process_start_time: current.process_start_time,
      terminal_cleanup_disposition: disposition,
      final_liveness_observation: observation,
      ...values,
    });
    const terminal = {
      ...current,
      current_observation_status: disposition === "CLEANUP_UNCONFIRMED" ? "CLEANUP_UNCONFIRMED" : "TERMINAL_EXIT_CONFIRMED",
      terminal_cleanup_disposition: disposition,
      terminal_evidence_sha256: event.evidence_sha256,
    };
    this.ownedProcessRegistry.set(this.#registryIdentityKey(current), terminal);
    this.#recordProcessAction({
      proof_stage: "EXACT_OWNED_REGISTRY_EXIT_CONFIRMATION",
      action_type: "CONFIRM_PROCESS_EXIT",
      reason: values.reason ?? "ROOT_INDEPENDENT_REGISTRY_RECONCILIATION",
      requested_operation: "OBSERVE_EXACT_REGISTERED_IDENTITY",
      os_api_result: values.os_api_result ?? { status: disposition },
      post_action_observation: { alive: disposition === "CLEANUP_UNCONFIRMED" ? Boolean(observation?.same_identity_alive) : false },
      terminal_disposition: disposition,
      cooperative_request_identity: this.ownedProcessRegistryClosing?.cooperative_request_identity ?? null,
      forced_termination_identity: values.forced_termination_identity ?? null,
      observed_exit_or_close_at: observedAt,
      exit_code: Number.isInteger(values.exit_code) ? values.exit_code : null,
      exit_code_disposition: Number.isInteger(values.exit_code) ? "NUMERIC_EXIT_OBSERVED" : (values.exit_code_disposition ?? "EXIT_CODE_NOT_EXPOSED_BY_PLATFORM"),
      pid_reuse_check: observation?.pid_reused ? "PID_REUSED_BY_UNRELATED_IDENTITY" : (observation?.same_identity_alive ? "OWNED_IDENTITY_STILL_ALIVE" : "PID_ABSENT_NO_REUSE_OBSERVED"),
    }, terminal);
    return terminal;
  }

  beginOwnedProcessShutdown(reason = "SERVER_SHUTDOWN") {
    this.reconcileOwnedProcessRegistryAndLedger();
    if (!this.ownedProcessRegistryClosing) {
      this.ownedProcessRegistryClosing = {
        cutoff_at: nowIso(),
        reason,
        cooperative_request_identity: `${this.serverInstanceId}:${reason}`,
      };
      this.#appendOwnedProcessRegistryEvent("REGISTRY_CLOSING", {
        cutoff_at: this.ownedProcessRegistryClosing.cutoff_at,
        reason,
        captured_generation: this.ownedProcessRegistryGeneration,
      });
    }
    return this.ownedProcessRegistrySnapshot();
  }

  ownedProcessRegistrySnapshot() {
    return {
      schema_version: "tsf_hq_dispatch_owned_process_registry_snapshot_v1",
      registry_path: this.ownedProcessRegistryPath,
      server_instance_id: this.serverInstanceId,
      generation: this.ownedProcessRegistryGeneration,
      closing: Boolean(this.ownedProcessRegistryClosing),
      cutoff_at: this.ownedProcessRegistryClosing?.cutoff_at ?? null,
      entries: [...this.ownedProcessRegistry.values()].map((entry) => ({ ...entry })),
      causal_ledger_path: this.processActionLedgerPath,
      evidence_sha256: this.ownedProcessRegistryPreviousHash,
    };
  }

  reconcileOwnedProcessRegistryAndLedger() {
    const entries = [...this.ownedProcessRegistry.values()];
    const registrations = this.ownedProcessProjectedActions.filter((event) => event.action_type === "REGISTER_PROOF_OWNERSHIP" && event.process_registration_id);
    for (const entry of entries) {
      if (entry.registration_status !== "COMMITTED") throw new Error("OWNED_PROCESS_REGISTRY_LEDGER_REGISTRATION_INCOMPLETE");
      const matches = registrations.filter((event) => event.process_registration_id === entry.process_registration_id);
      if (matches.length !== 1) throw new Error(matches.length === 0 ? "OWNED_PROCESS_REGISTRY_WITHOUT_LEDGER_REGISTRATION" : "OWNED_PROCESS_DUPLICATE_LEDGER_REGISTRATION");
      const event = matches[0];
      if (Number(event.registration_sequence) !== Number(entry.registration_sequence)
          || Number(event.target_process_id) !== Number(entry.process_id)
          || Date.parse(event.target_process_start_time) !== Date.parse(entry.process_start_time)
          || event.ownership_evidence_sha256 !== entry.ownership_evidence_sha256
          || event.server_instance_id !== this.serverInstanceId
          || event.root_process_registration_id !== entry.root_process_registration_id
          || JSON.stringify(event.mission_identity ?? null) !== JSON.stringify(entry.mission_identity ?? null)) {
        throw new Error("OWNED_PROCESS_REGISTRY_LEDGER_IDENTITY_MISMATCH");
      }
      const registrationIndex = this.ownedProcessProjectedActions.indexOf(event);
      const terminalIndex = this.ownedProcessProjectedActions.findIndex((candidate) => candidate.action_type === "CONFIRM_PROCESS_EXIT" && candidate.process_registration_id === entry.process_registration_id);
      if (terminalIndex >= 0 && terminalIndex <= registrationIndex) throw new Error("OWNED_PROCESS_TERMINAL_BEFORE_LEDGER_REGISTRATION");
    }
    const registryIds = new Set(entries.map((entry) => entry.process_registration_id));
    if (registrations.some((event) => !registryIds.has(event.process_registration_id))) throw new Error("OWNED_PROCESS_LEDGER_WITHOUT_REGISTRY_REGISTRATION");
    return { status: "PASS", registry_entries: entries.length, ownership_ledger_events: registrations.length, registry_generation: this.ownedProcessRegistryGeneration };
  }

  claim() {
    if (existsSync(this.ownerPath)) throw new Error("HQ_DISPATCH_OWNER_RECORD_ALREADY_EXISTS");
    if (existsSync(this.tokenPath)) throw new Error("HQ_DISPATCH_STOP_TOKEN_ALREADY_EXISTS");
    const body = baseOwner({ repositoryRoot: this.repositoryRoot, host: this.host, port: this.port, serverInstanceId: this.serverInstanceId, sessionGeneration: this.sessionGeneration, stopToken: this.stopToken, mode: this.mode });
    const owner = withOwnerHash(body);
    atomicWriteJson(this.ownerPath, owner, { noReplace: true });
    try { writeFileSync(this.tokenPath, `${this.stopToken}\n`, { encoding: "utf8", flag: "wx", mode: 0o600 }); }
    catch (error) { this.release(); throw error; }
    this.owner = owner;
    return owner;
  }

  update(values = {}) {
    if (!this.owner) throw new Error("HQ_DISPATCH_OWNER_NOT_CLAIMED");
    const current = readJson(this.ownerPath);
    const shape = validateOwnerShape(current);
    if (!shape.valid || current.server_instance_id !== this.serverInstanceId || current.process_id !== process.pid || current.evidence_hash !== this.owner.evidence_hash) {
      throw new Error("HQ_DISPATCH_OWNER_CHANGED_OR_MISMATCHED");
    }
    const next = withOwnerHash({ ...ownerBody(current), ...values, updated_at: nowIso() });
    atomicWriteJson(this.ownerPath, next);
    this.owner = next;
    return next;
  }

  activate() { return this.update({ lifecycle_state: "ACTIVE" }); }
  stopping() { return this.update({ lifecycle_state: "STOPPING" }); }

  childStarted(child) {
    const observed = inspectProcessWithParent(child.pid) ?? inspectProcess(child.pid);
    if (!observed) throw new Error("OWNED_CHILD_IDENTITY_UNAVAILABLE");
    const registration = this.#registerOwnedProcessAndLedgerEvent(observed, {
      mission_identity: this.owner?.active_mission ?? null,
      worktree: this.owner?.worktree,
      candidate_commit: this.owner?.commit,
      ownership_evidence_sha256: this.owner?.evidence_hash,
      causal_registration_at: nowIso(),
    });
    if (registration.terminal_cleanup_disposition) return this.owner;
    const children = [...(this.owner?.owned_children ?? []).filter((item) => item.process_id !== child.pid), observed];
    return this.update({ owned_child_process_ids: children.map((item) => item.process_id), owned_children: children });
  }

  childExited(processId) {
    const registration = this.#registryEntryByProcessId(processId);
    if (registration && !registration.terminal_cleanup_disposition) {
      const observed = inspectProcess(registration.process_id);
      const sameIdentityAlive = processMatchesOwner(registration, observed);
      if (!sameIdentityAlive) {
        const buffered = {
          disposition: this.ownedProcessRegistryClosing ? "COOPERATIVE_EXIT_CONFIRMED" : "ALREADY_GONE_WITH_IDENTITY_CONFIRMED",
          observation: { same_identity_alive: false, pid_reused: Boolean(observed) },
          values: {
            reason: this.ownedProcessRegistryClosing ? "ROOT_CLOSE_AFTER_COOPERATIVE_STOP" : "ROOT_CLOSE_OBSERVED",
            observed_exit_or_close_at: nowIso(),
            exit_code_disposition: "EXIT_CODE_NOT_EXPOSED_BY_CHILD_EXIT_CALLBACK",
          },
        };
        if (registration.registration_status === "PENDING") {
          this.pendingOwnedProcessExitObservations.set(this.#registryIdentityKey(registration), buffered);
        } else if (registration.registration_status === "COMMITTED") {
          this.#recordTerminalOwnedProcess(registration, buffered.disposition, buffered.observation, buffered.values);
        } else {
          this.#appendOwnedProcessRegistryEvent("INCOMPLETE_REGISTRATION_EXIT_OBSERVED", {
            process_registration_id: registration.process_registration_id,
            registration_sequence: registration.registration_sequence,
            process_id: registration.process_id,
            process_start_time: registration.process_start_time,
            observed_exit_or_close_at: buffered.values.observed_exit_or_close_at,
            failure_classification: "EXIT_OBSERVED_WITHOUT_COMMITTED_OWNERSHIP",
          });
        }
      }
    }
    const children = (this.owner?.owned_children ?? []).filter((item) => item.process_id !== Number(processId));
    return this.update({ owned_child_process_ids: children.map((item) => item.process_id), owned_children: children });
  }

  missionChanged(activeMission) { return this.update({ active_mission: activeMission ?? null }); }

  ownsChild(processId) {
    const child = (this.owner?.owned_children ?? []).find((item) => item.process_id === Number(processId));
    return Boolean(child && processMatchesOwner(child, inspectProcess(child.process_id)));
  }

  childrenStartedFromEvidence({
    rootProcessId,
    processes,
    serverInstanceId,
    capabilityIdentitySha256,
    ownershipEvidenceSha256,
    launchIdentitySha256 = null,
    registrationCreatedAt = null,
  }) {
    const rootId = Number(rootProcessId);
    const root = (this.owner?.owned_children ?? []).find((item) => item.process_id === rootId);
    if (!root || !processMatchesOwner(root, inspectProcess(rootId))) throw new Error("OWNED_DESCENDANT_ROOT_IDENTITY_MISMATCH");
    if (serverInstanceId !== this.serverInstanceId) throw new Error("OWNED_DESCENDANT_SERVER_INSTANCE_MISMATCH");
    for (const [name, value] of [["CAPABILITY", capabilityIdentitySha256], ["EVIDENCE", ownershipEvidenceSha256]]) {
      if (!/^[a-f0-9]{64}$/.test(String(value ?? ""))) throw new Error(`OWNED_DESCENDANT_${name}_HASH_INVALID`);
    }
    if (!Array.isArray(processes) || processes.length === 0) throw new Error("OWNED_DESCENDANT_PROCESS_CHAIN_REQUIRED");
    const byId = new Map([[rootId, root]]);
    for (const processIdentity of processes) {
      const processId = Number(processIdentity?.process_id);
      if (!Number.isInteger(processId) || processId <= 0 || processId === rootId || byId.has(processId)) {
        throw new Error("OWNED_DESCENDANT_PROCESS_CHAIN_DUPLICATE_OR_INVALID");
      }
      byId.set(processId, processIdentity);
    }
    for (const processIdentity of processes) {
      const parentId = Number(processIdentity.parent_process_id);
      if (!byId.has(parentId)) throw new Error("OWNED_DESCENDANT_PARENT_OUTSIDE_EXACT_CHAIN");
      const observed = inspectProcessWithParent(Number(processIdentity.process_id));
      if (!processMatchesOwner(processIdentity, observed) || Number(observed.parent_process_id) !== parentId) {
        throw new Error("OWNED_DESCENDANT_PROCESS_IDENTITY_MISMATCH");
      }
      const parent = byId.get(parentId);
      if (processIdentity.parent_process_start_time
          && Date.parse(processIdentity.parent_process_start_time) !== Date.parse(parent.process_start_time)) {
        throw new Error("OWNED_DESCENDANT_PARENT_START_TIME_MISMATCH");
      }
      if (processIdentity.parent_executable && !samePath(processIdentity.parent_executable, parent.executable)) {
        throw new Error("OWNED_DESCENDANT_PARENT_EXECUTABLE_MISMATCH");
      }
      const visited = new Set([Number(processIdentity.process_id)]);
      let cursor = parentId;
      while (cursor !== rootId) {
        if (visited.has(cursor) || !byId.has(cursor)) throw new Error("OWNED_DESCENDANT_PROCESS_CHAIN_NOT_ROOTED");
        visited.add(cursor);
        cursor = Number(byId.get(cursor).parent_process_id);
      }
    }
    const additions = processes.map((processIdentity) => ({
      ...processIdentity,
      owned_tree_root_process_id: rootId,
      server_instance_id: this.serverInstanceId,
      capability_identity_sha256: capabilityIdentitySha256,
      ownership_evidence_sha256: ownershipEvidenceSha256,
    }));
    const rootRegistration = this.#registryEntryByProcessId(rootId);
    if (!rootRegistration) throw new Error("OWNED_DESCENDANT_ROOT_REGISTRY_MISSING");
    const enrichedRoot = this.#enrichOwnedProcessRegistration(rootRegistration, {
      mission_identity: this.owner?.active_mission ?? null,
      capability_identity_sha256: capabilityIdentitySha256,
      launch_identity_sha256: launchIdentitySha256,
      ownership_evidence_sha256: ownershipEvidenceSha256,
    });
    const pending = [...additions];
    for (let pass = 0; pending.length && pass <= additions.length; pass += 1) {
      for (let index = pending.length - 1; index >= 0; index -= 1) {
        const identity = pending[index];
        const parentRegistration = Number(identity.parent_process_id) === rootId
          ? enrichedRoot
          : this.#registryEntryByProcessId(identity.parent_process_id);
        if (!parentRegistration) continue;
        this.#registerOwnedProcessAndLedgerEvent(identity, {
          root_process_registration_id: enrichedRoot.process_registration_id,
          mission_identity: this.owner?.active_mission ?? null,
          worktree: this.owner?.worktree,
          candidate_commit: this.owner?.commit,
          capability_identity_sha256: capabilityIdentitySha256,
          launch_identity_sha256: launchIdentitySha256,
          ownership_evidence_sha256: ownershipEvidenceSha256,
          causal_registration_at: registrationCreatedAt ?? nowIso(),
        });
        pending.splice(index, 1);
      }
    }
    if (pending.length) throw new Error("OWNED_DESCENDANT_REGISTRY_PARENT_MISSING");
    this.reconcileOwnedProcessRegistryAndLedger();
    const additionIds = new Set(additions.map((item) => item.process_id));
    const children = [...(this.owner?.owned_children ?? []).filter((item) => !additionIds.has(item.process_id)), ...additions];
    return this.update({ owned_child_process_ids: children.map((item) => item.process_id), owned_children: children });
  }

  childrenExitedFromEvidence({ rootProcessId, processes, capabilityIdentitySha256, ownershipEvidenceSha256 }) {
    const rootId = Number(rootProcessId);
    const removals = new Set();
    const dispositions = [];
    for (const processIdentity of processes ?? []) {
      const recorded = (this.owner?.owned_children ?? []).find((item) => item.process_id === Number(processIdentity.process_id));
      if (!recorded || recorded.owned_tree_root_process_id !== rootId
          || recorded.capability_identity_sha256 !== capabilityIdentitySha256
          || recorded.ownership_evidence_sha256 !== ownershipEvidenceSha256) {
        throw new Error("OWNED_DESCENDANT_CLEANUP_EVIDENCE_MISMATCH");
      }
      const registryEntry = this.ownedProcessRegistry.get(this.#registryIdentityKey(recorded));
      if (!registryEntry || (registryEntry.proof_ownership_evidence_sha256 ?? registryEntry.ownership_evidence_sha256) !== ownershipEvidenceSha256
          || !OWNED_PROCESS_TERMINAL_DISPOSITIONS.has(registryEntry.terminal_cleanup_disposition)
          || registryEntry.terminal_cleanup_disposition === "CLEANUP_UNCONFIRMED") {
        throw new Error("OWNED_DESCENDANT_REGISTRY_CLEANUP_UNCONFIRMED");
      }
      const observed = inspectProcess(recorded.process_id);
      if (processMatchesOwner(recorded, observed)) throw new Error("OWNED_DESCENDANT_STILL_RUNNING_AFTER_CLEANUP");
      removals.add(recorded.process_id);
      dispositions.push({
        process_id: recorded.process_id,
        disposition: registryEntry.terminal_cleanup_disposition,
        terminal_evidence_sha256: registryEntry.terminal_evidence_sha256,
      });
    }
    const children = (this.owner?.owned_children ?? []).filter((item) => !removals.has(item.process_id));
    this.update({ owned_child_process_ids: children.map((item) => item.process_id), owned_children: children });
    return dispositions;
  }

  async cleanupRegisteredOwnedProcesses({ liveRootChild = null, reason = "EXACT_OPERATOR_STOP", cooperativeWaitMs = 500 } = {}) {
    this.beginOwnedProcessShutdown(reason);
    this.reconcileOwnedProcessRegistryAndLedger();
    const rootEntry = liveRootChild?.pid ? this.#registryEntryByProcessId(liveRootChild.pid) : null;
    if (liveRootChild && rootEntry) {
      const observed = inspectProcess(rootEntry.process_id);
      if (processMatchesOwner(rootEntry, observed) && !liveRootChild.killed) {
        this.#recordProcessAction({
          proof_stage: "EXACT_OWNED_REGISTRY_COOPERATIVE_STOP",
          action_type: "REQUEST_COOPERATIVE_STOP",
          reason,
          requested_operation: "CHILD_PROCESS_EXACT_COOPERATIVE_STOP",
          os_api_result: { status: "REQUEST_ISSUED" },
          post_action_observation: { alive: true },
        }, rootEntry);
        liveRootChild.kill();
      }
    }
    const cooperativeDeadline = Date.now() + Math.max(0, Math.min(Number(cooperativeWaitMs) || 0, 5_000));
    while (Date.now() < cooperativeDeadline) {
      if ([...this.ownedProcessRegistry.values()].every((entry) => entry.terminal_cleanup_disposition || !processMatchesOwner(entry, inspectProcess(entry.process_id)))) break;
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
    let stableGeneration = null;
    for (let pass = 0; pass < 8; pass += 1) {
      const generation = this.ownedProcessRegistryGeneration;
      const registrations = [...this.ownedProcessRegistry.values()];
      const byRegistrationId = new Map(registrations.map((entry) => [entry.process_registration_id, entry]));
      for (const entry of registrations) {
        if (!byRegistrationId.has(entry.root_process_registration_id)
            || (entry.parent_process_registration_id && !byRegistrationId.has(entry.parent_process_registration_id))) {
          this.#recordTerminalOwnedProcess(entry, "CLEANUP_UNCONFIRMED", { same_identity_alive: Boolean(inspectProcess(entry.process_id)), pid_reused: false }, {
            reason: "OWNED_PROCESS_REGISTRY_RELATIONSHIP_UNCONFIRMED",
            exit_code_disposition: "EXIT_NOT_RELIABLY_OBSERVED",
          });
          throw new Error("OWNED_PROCESS_REGISTRY_RELATIONSHIP_UNCONFIRMED");
        }
      }
      const depth = (entry) => {
        let current = entry;
        let value = 0;
        const visited = new Set();
        while (current.parent_process_registration_id) {
          if (visited.has(current.process_registration_id)) throw new Error("OWNED_PROCESS_REGISTRY_PARENT_CYCLE");
          visited.add(current.process_registration_id);
          current = byRegistrationId.get(current.parent_process_registration_id);
          if (!current) break;
          value += 1;
        }
        return value;
      };
      const pending = registrations.filter((entry) => !entry.terminal_cleanup_disposition).sort((left, right) => depth(right) - depth(left));
      for (const entry of pending) {
        let observed = inspectProcess(entry.process_id);
        if (!processMatchesOwner(entry, observed)) {
          this.#recordTerminalOwnedProcess(entry, "ALREADY_GONE_WITH_IDENTITY_CONFIRMED", {
            same_identity_alive: false,
            pid_reused: Boolean(observed),
          }, {
            reason: observed ? "REGISTERED_PID_REUSED_UNRELATED_PROCESS_PRESERVED" : "REGISTERED_PROCESS_ALREADY_ABSENT",
            exit_code_disposition: "EXIT_CODE_NOT_EXPOSED_BY_PLATFORM",
          });
          continue;
        }
        this.#recordProcessAction({
          proof_stage: "EXACT_OWNED_REGISTRY_FORCED_TERMINATION",
          action_type: "TERMINATE_OWNED_PROCESS",
          reason: "PROCESS_REMAINED_AFTER_BOUNDED_COOPERATIVE_WAIT",
          requested_operation: "TASKKILL_EXACT_PID_FORCE_NO_TREE",
          os_api_result: { status: "REQUEST_ISSUED" },
          post_action_observation: { alive: true },
        }, entry);
        const result = spawnSync("C:\\Windows\\System32\\taskkill.exe", ["/PID", String(entry.process_id), "/F"], {
          encoding: "utf8",
          windowsHide: true,
          timeout: 10_000,
        });
        const exitDeadline = Date.now() + 5_000;
        do {
          observed = inspectProcess(entry.process_id);
          if (!processMatchesOwner(entry, observed)) break;
          await new Promise((resolve) => setTimeout(resolve, 25));
        } while (Date.now() < exitDeadline);
        if (processMatchesOwner(entry, observed)) {
          this.#recordTerminalOwnedProcess(entry, "CLEANUP_UNCONFIRMED", { same_identity_alive: true, pid_reused: false }, {
            reason: "EXACT_REGISTERED_PROCESS_EXIT_NOT_CONFIRMED",
            os_api_result: { status: result.status, stderr: String(result.stderr ?? "").slice(0, 1024) },
            forced_termination_identity: `taskkill-exact-pid:${entry.process_id}:${entry.process_start_time}`,
            exit_code_disposition: "EXIT_NOT_RELIABLY_OBSERVED",
          });
          throw new Error("EXACT_REGISTERED_PROCESS_EXIT_NOT_CONFIRMED");
        }
        this.#recordTerminalOwnedProcess(entry, "FORCED_TERMINATION_CONFIRMED", {
          same_identity_alive: false,
          pid_reused: Boolean(observed),
        }, {
          reason: "EXACT_REGISTERED_PROCESS_FORCED_EXIT_CONFIRMED",
          os_api_result: { status: result.status, stderr_sha256: sha256(String(result.stderr ?? "")) },
          forced_termination_identity: `taskkill-exact-pid:${entry.process_id}:${entry.process_start_time}`,
          exit_code_disposition: "EXIT_CODE_NOT_EXPOSED_BY_TASKKILL",
        });
      }
      await new Promise((resolve) => setImmediate(resolve));
      if (generation === this.ownedProcessRegistryGeneration
          && [...this.ownedProcessRegistry.values()].every((entry) => entry.terminal_cleanup_disposition && entry.terminal_cleanup_disposition !== "CLEANUP_UNCONFIRMED")) {
        this.reconcileOwnedProcessRegistryAndLedger();
        stableGeneration = generation;
        break;
      }
    }
    if (stableGeneration === null) {
      this.#appendOwnedProcessRegistryEvent("REGISTRY_STABILITY_FAILED", { failure_classification: "OWNED_PROCESS_REGISTRY_GENERATION_UNSTABLE" });
      throw new Error("OWNED_PROCESS_REGISTRY_GENERATION_UNSTABLE");
    }
    const terminalEntries = [...this.ownedProcessRegistry.values()];
    const stableEvent = this.#appendOwnedProcessRegistryEvent("REGISTRY_GENERATION_STABLE", {
      stable_generation: stableGeneration,
      terminal_process_count: terminalEntries.length,
      terminal_dispositions: terminalEntries.map((entry) => ({
        process_registration_id: entry.process_registration_id,
        process_id: entry.process_id,
        process_start_time: entry.process_start_time,
        terminal_disposition: entry.terminal_cleanup_disposition,
        terminal_evidence_sha256: entry.terminal_evidence_sha256,
      })),
    });
    return {
      status: "CLEANUP_CONFIRMED",
      registry_path: this.ownedProcessRegistryPath,
      registry_generation: stableGeneration,
      registry_evidence_sha256: stableEvent.evidence_sha256,
      terminal_dispositions: terminalEntries.map((entry) => ({
        process_registration_id: entry.process_registration_id,
        process_id: entry.process_id,
        process_start_time: entry.process_start_time,
        terminal_disposition: entry.terminal_cleanup_disposition,
        terminal_evidence_sha256: entry.terminal_evidence_sha256,
      })),
      unrelated_processes_targeted: false,
      root_handle_required: false,
    };
  }

  terminateOwnedChildTree(childProcess) {
    return this.cleanupRegisteredOwnedProcesses({ liveRootChild: childProcess, reason: "EXACT_OPERATOR_STOP" });
  }

  authenticateStop(token, body) {
    if (typeof token !== "string" || typeof body !== "object" || body === null) return false;
    const supplied = Buffer.from(token, "utf8");
    const expected = Buffer.from(this.stopToken, "utf8");
    if (supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) return false;
    return body.server_instance_id === this.serverInstanceId
      && body.evidence_hash === stopAuthenticationHash(this.owner)
      && body.process_id === process.pid;
  }

  release() {
    if (existsSync(this.ownerPath)) {
      try {
        const current = readJson(this.ownerPath);
        const observed = inspectProcess(process.pid);
        if (validateOwnerShape(current).valid && current.server_instance_id === this.serverInstanceId && current.process_id === process.pid && processMatchesOwner(current, observed)) rmSync(this.ownerPath, { force: true });
      } catch { /* Preserve mismatched evidence. */ }
    }
    if (existsSync(this.tokenPath)) {
      try {
        const token = readFileSync(this.tokenPath, "utf8").trim();
        if (sha256(token) === sha256(this.stopToken)) rmSync(this.tokenPath, { force: true });
      } catch { /* Preserve mismatched evidence. */ }
    }
  }
}

function recoveryReceiptPath(localRoot, receiptId) {
  return path.join(localRoot, "recovery-receipts", `hr-${sha256(receiptId).slice(0, 32)}.json`);
}

function recoveryReceiptIdentity(item, action) {
  return { recovery_item_id: item.recovery_item_id, evidence_hash: item.evidence_hash, action };
}

function existingRecoveryReceipt(item, action, localRoot) {
  const identity = recoveryReceiptIdentity(item, action);
  const receiptId = `hq-recovery-receipt-${hashObject(identity).slice(0, 32)}`;
  const output = recoveryReceiptPath(localRoot, receiptId);
  if (!existsSync(output)) return null;
  const existing = readJson(output);
  if (existing.idempotency_identity_sha256 !== hashObject(identity) || existing.source_evidence_hash !== item.evidence_hash || existing.action !== action) throw new Error("RECOVERY_RECEIPT_CONFLICT");
  return { ...existing, receipt_path: output, idempotent_replay: true };
}

export function writeRecoveryReceipt({ item, action, sessionGeneration, localRoot = LOCAL_LIFECYCLE_ROOT, changes, immutable, extra = {} }) {
  const identity = recoveryReceiptIdentity(item, action);
  const receiptId = `hq-recovery-receipt-${hashObject(identity).slice(0, 32)}`;
  const receipt = {
    schema_version: RECOVERY_RECEIPT_SCHEMA,
    receipt_id: receiptId,
    recorded_at: nowIso(),
    mission_id: item.mission_id,
    mission_revision: item.mission_revision,
    run_id: item.run_id,
    result_id: item.result_id,
    source_classification: item.classification,
    source_evidence_hash: item.evidence_hash,
    source_paths: item.canonical_paths,
    action,
    operator_session_generation: sessionGeneration,
    changes,
    immutable,
    grants_approval: false,
    grants_merge_authority: false,
    grants_deployment_authority: false,
    grants_production_authority: false,
    idempotency_identity_sha256: hashObject(identity),
    ...extra,
  };
  const output = recoveryReceiptPath(localRoot, receiptId);
  const existing = existsSync(output) ? readJson(output) : null;
  if (existing) {
    if (existing.idempotency_identity_sha256 !== receipt.idempotency_identity_sha256 || existing.source_evidence_hash !== item.evidence_hash) throw new Error("RECOVERY_RECEIPT_CONFLICT");
    return { ...existing, receipt_path: output, idempotent_replay: true };
  }
  atomicWriteJson(output, receipt, { noReplace: true });
  return { ...receipt, receipt_path: output, idempotent_replay: false };
}

function firstPath(item, role) {
  const value = item?.canonical_paths?.[role];
  return Array.isArray(value) ? value[0] ?? null : value ?? null;
}

export function writeInterruptionEvidence({ item, reason, serverInstanceId = null, operatorInitiated = false, cleanupSummary = null }) {
  const queuePath = firstPath(item, "queue_documents") ?? firstPath(item, "runtime_queue_document") ?? item?.last_canonical_event?.path;
  if (!queuePath || !existsSync(queuePath)) throw new Error("INTERRUPTION_QUEUE_EVIDENCE_MISSING");
  const runtimeQueuePath = firstPath(item, "runtime_queue_document");
  const evidenceDirectory = runtimeQueuePath ? path.join(path.dirname(runtimeQueuePath), "recovery") : path.join(LOCAL_LIFECYCLE_ROOT, "interrupted", item.recovery_item_id);
  const stopPath = path.join(evidenceDirectory, "STOP_RECORD.json");
  const snapshotPath = path.join(evidenceDirectory, "queue-record-preflight-pending.json");
  const queueHash = sha256(readFileSync(queuePath));
  if (existsSync(snapshotPath)) {
    if (sha256(readFileSync(snapshotPath)) !== queueHash) throw new Error("INTERRUPTION_QUEUE_SNAPSHOT_CONFLICT");
  } else {
    mkdirSync(evidenceDirectory, { recursive: true });
    copyFileSync(queuePath, snapshotPath, fsConstants.COPYFILE_EXCL);
  }
  if (cleanupSummary !== null) {
    if (cleanupSummary?.schema_version !== "tsf_hq_dispatch_exact_cleanup_summary_v1"
        || cleanupSummary?.status !== "CLEANUP_CONFIRMED"
        || !Array.isArray(cleanupSummary?.terminal_dispositions)
        || cleanupSummary.terminal_dispositions.length === 0
        || !/^[a-f0-9]{64}$/.test(String(cleanupSummary?.cleanup_summary_sha256 ?? ""))) {
      throw new Error("INTERRUPTION_CLEANUP_SUMMARY_INVALID");
    }
    const unsigned = { ...cleanupSummary };
    delete unsigned.cleanup_summary_sha256;
    if (sha256(JSON.stringify(unsigned)) !== cleanupSummary.cleanup_summary_sha256) throw new Error("INTERRUPTION_CLEANUP_SUMMARY_HASH_MISMATCH");
  }
  const stopIdentity = { mission_id: item.mission_id, mission_revision: item.mission_revision, run_id: item.run_id, source_evidence_hash: item.evidence_hash, queue_document_sha256: queueHash, reason, cleanup_summary_sha256: cleanupSummary?.cleanup_summary_sha256 ?? null };
  const record = {
    schema_version: INTERRUPTION_SCHEMA,
    mission_id: item.mission_id,
    mission_revision: item.mission_revision,
    run_id: item.run_id,
    result_id: item.result_id,
    recorded_at: nowIso(),
    reason,
    server_instance_id: serverInstanceId,
    operator_initiated: operatorInitiated,
    original_attempt_completed: false,
    original_attempt_resumable: false,
    automatic_retry_performed: false,
    old_thread_or_turn_resumed: false,
    queue_record_path: path.resolve(queuePath),
    queue_record_sha256: queueHash,
    queue_snapshot_path: path.resolve(snapshotPath),
    queue_snapshot_sha256: queueHash,
    source_evidence_hash: item.evidence_hash,
    cleanup_summary: cleanupSummary,
    interruption_identity_sha256: hashObject(stopIdentity),
  };
  const existing = existsSync(stopPath) ? readJson(stopPath) : null;
  if (existing) {
    if (existing.interruption_identity_sha256 !== record.interruption_identity_sha256) throw new Error("INTERRUPTION_EVIDENCE_CONFLICT");
    return { ...existing, stop_record_path: stopPath, recovery_evidence_directory: evidenceDirectory, idempotent_replay: true };
  }
  atomicWriteJson(stopPath, record, { noReplace: true });
  return { ...record, stop_record_path: stopPath, recovery_evidence_directory: evidenceDirectory, idempotent_replay: false };
}

export function recoverVerifiedStaleOwnership({ ownerPath = OWNER_PATH, tokenPath = STOP_TOKEN_PATH, localRoot = LOCAL_LIFECYCLE_ROOT } = {}) {
  const ownership = readOwnership(ownerPath);
  if (!["STALE_PROCESS_GONE", "PID_REUSED_OR_IDENTITY_MISMATCH"].includes(ownership.disposition)) throw new Error("STALE_OWNERSHIP_NOT_CONFIRMED");
  if (ownership.observed_process && ownership.disposition === "PID_REUSED_OR_IDENTITY_MISMATCH") {
    // The unrelated process is explicitly preserved. Only stale files are removed.
  }
  const evidence = { owner_path: ownerPath, owner_sha256: sha256(readFileSync(ownerPath)), disposition: ownership.disposition, unrelated_process_terminated: false, recovered_at: nowIso() };
  const receiptPath = path.join(localRoot, "stale-owner-recovery", `sr-${evidence.owner_sha256.slice(0, 32)}.json`);
  atomicWriteJson(receiptPath, { schema_version: "tsf_hq_dispatch_stale_owner_recovery_v1", ...evidence }, { noReplace: true });
  rmSync(ownerPath, { force: true });
  if (existsSync(tokenPath)) rmSync(tokenPath, { force: true });
  return { status: "STALE_OWNERSHIP_RECOVERED", receipt_path: receiptPath, ...evidence };
}

export function stopRequestEvidence({ ownerPath = OWNER_PATH, tokenPath = STOP_TOKEN_PATH } = {}) {
  const ownership = readOwnership(ownerPath);
  if (ownership.disposition !== "ACTIVE_OWNER_CONFIRMED") throw new Error(`ACTIVE_HQ_DISPATCH_OWNER_NOT_CONFIRMED:${ownership.disposition}`);
  const owner = ownership.owner;
  const listeners = inspectListeners(owner.port);
  if (!listeners.some((listener) => Number(listener.process_id) === owner.process_id && [owner.host, "::ffff:127.0.0.1"].includes(String(listener.host)))) throw new Error("ACTIVE_OWNER_LISTENER_NOT_CONFIRMED");
  const token = readFileSync(tokenPath, "utf8").trim();
  if (sha256(token) !== owner.control_token_sha256) throw new Error("STOP_TOKEN_OWNER_BINDING_MISMATCH");
  return { owner, token, listeners, stop_authentication_hash: stopAuthenticationHash(owner) };
}

export function recoveryActionDescription(action) {
  const descriptions = {
    ACKNOWLEDGE_COMPLETED: { changes: "Writes one idempotent local audit receipt acknowledging the canonical terminal result.", immutable: "Mission, result, verifier, admission, queue history, and worker identities remain unchanged." },
    VIEW_CANONICAL_RECEIPT: { changes: "Performs a fresh read-only projection of exact canonical paths and hashes.", immutable: "All files and process state remain unchanged." },
    RESPOND_TO_TIM_REQUIRED: { changes: "No recovery write occurs here; the operator is routed to the existing canonical TIM_REQUIRED response endpoint.", immutable: "The original terminal run remains immutable and is never resumed." },
    CREATE_NEW_REVISION: { changes: "Uses the existing canonical TIM_REQUIRED response path to create a strictly higher mission revision.", immutable: "The original result, thread, turn, verifier, admission, and response evidence remain immutable." },
    RETRY_AS_NEW_RUN: { changes: "Creates a new mission and run identity through canonical preparation, routing, queue, execution, verification, and admission controls.", immutable: "The interrupted source run and all of its evidence remain immutable; no thread, turn, result, verifier, or admission identity is reused." },
    MARK_PROCESS_INTERRUPTED: { changes: "Writes an immutable interruption record and byte-exact queue snapshot; it does not mark the mission completed.", immutable: "Existing canonical records and the observed queue document remain unchanged." },
    RECONCILE_QUEUE_FROM_CANONICAL_RECEIPT: { changes: "May move one exact queue document only through the existing canonical recovery-envelope transition control.", immutable: "The admission receipt, transaction, result, and prior queue history remain unchanged." },
    DECLINE_RECOVERY: { changes: "Writes one idempotent local audit receipt recording that no recovery was selected.", immutable: "All canonical mission and queue state remains unchanged." },
    TIM_REQUIRED: { changes: "Performs no mutation and records that broader authority or conflicting evidence requires Tim review.", immutable: "All evidence remains unchanged." },
  };
  return descriptions[action] ?? null;
}

export async function performRecoveryAction({ item, action, operatorConfirmation, sessionGeneration, sessionKey = null, relay = null, localRoot = LOCAL_LIFECYCLE_ROOT, serverInstanceId = null }) {
  const allowed = item?.safe_operator_options ?? [];
  if (!allowed.includes(action)) throw new Error("RECOVERY_ACTION_NOT_ALLOWED_FOR_CLASSIFICATION");
  if (operatorConfirmation !== action) throw new Error("EXACT_RECOVERY_CONFIRMATION_REQUIRED");
  const description = recoveryActionDescription(action);
  if (!description) throw new Error("UNKNOWN_RECOVERY_ACTION");
  const existing = existingRecoveryReceipt(item, action, localRoot);
  if (existing) {
    return {
      schema_version: "tsf_hq_dispatch_recovery_action_result_v1",
      action,
      changed: false,
      idempotent_replay: true,
      receipt: existing,
      interruption: existing.interruption ?? null,
      new_run: existing.new_run ?? null,
    };
  }
  if (action === "RESPOND_TO_TIM_REQUIRED") {
    if (!relay || typeof relay.loadReconciledTimRequired !== "function" || !sessionKey) throw new Error("CANONICAL_TIM_REQUIRED_RECONCILIATION_UNAVAILABLE");
    const mission_status = relay.loadReconciledTimRequired(item, sessionKey);
    return { schema_version: "tsf_hq_dispatch_recovery_action_result_v1", action, source_evidence_hash: item.evidence_hash, changed: false, ...description, mission_status };
  }
  if (action === "VIEW_CANONICAL_RECEIPT" || action === "TIM_REQUIRED") {
    return { schema_version: "tsf_hq_dispatch_recovery_action_result_v1", action, source_evidence_hash: item.evidence_hash, changed: false, tim_required: action === "TIM_REQUIRED" || action === "RECONCILE_QUEUE_FROM_CANONICAL_RECEIPT", ...description, canonical_paths: item.canonical_paths };
  }
  if (action === "RECONCILE_QUEUE_FROM_CANONICAL_RECEIPT") {
    if (!relay || typeof relay.reconcileQueueFromCanonicalReceipt !== "function") throw new Error("CANONICAL_QUEUE_RECONCILIATION_UNAVAILABLE");
    const queue_reconciliation = await relay.reconcileQueueFromCanonicalReceipt(item);
    const receipt = writeRecoveryReceipt({ item, action, sessionGeneration, localRoot, changes: description.changes, immutable: description.immutable, extra: { queue_reconciliation } });
    return { schema_version: "tsf_hq_dispatch_recovery_action_result_v1", action, changed: !queue_reconciliation.idempotent_replay, queue_reconciliation, receipt };
  }
  if (action === "MARK_PROCESS_INTERRUPTED") {
    const interruption = writeInterruptionEvidence({ item, reason: "EXPLICIT_OPERATOR_INTERRUPTION_CLASSIFICATION", serverInstanceId, operatorInitiated: true });
    const receipt = writeRecoveryReceipt({ item, action, sessionGeneration, localRoot, changes: description.changes, immutable: description.immutable, extra: { interruption } });
    return { schema_version: "tsf_hq_dispatch_recovery_action_result_v1", action, changed: !interruption.idempotent_replay, interruption, receipt };
  }
  if (action === "RETRY_AS_NEW_RUN") {
    if (!relay || typeof relay.retryInterrupted !== "function") throw new Error("CANONICAL_NEW_RUN_RETRY_UNAVAILABLE");
    const interruption = item.interruption_evidence ? null : writeInterruptionEvidence({ item, reason: "NEW_RUN_RECOVERY_SOURCE_PRESERVATION", serverInstanceId, operatorInitiated: true });
    const outcome = await relay.retryInterrupted({ item, interruption, sessionGeneration });
    const receipt = writeRecoveryReceipt({ item, action, sessionGeneration, localRoot, changes: description.changes, immutable: description.immutable, extra: { new_run: { mission_id: outcome.mission_id, mission_revision: outcome.mission_revision, run_id: outcome.run_id, result_id: outcome.result_id, source_path: outcome.source_path } } });
    return { schema_version: "tsf_hq_dispatch_recovery_action_result_v1", action, changed: !receipt.idempotent_replay, new_run: outcome, receipt };
  }
  const receipt = writeRecoveryReceipt({ item, action, sessionGeneration, localRoot, changes: description.changes, immutable: description.immutable });
  return { schema_version: "tsf_hq_dispatch_recovery_action_result_v1", action, changed: !receipt.idempotent_replay, receipt };
}
