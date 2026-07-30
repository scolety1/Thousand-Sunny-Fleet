import {
  closeSync,
  copyFileSync,
  cpSync,
  existsSync,
  fsyncSync,
  lstatSync,
  mkdirSync,
  openSync,
  readFileSync,
  readdirSync,
  realpathSync,
  renameSync,
  statSync,
  unlinkSync,
  writeFileSync,
  writeSync,
} from "node:fs";
import { createHash, randomUUID } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";
import { performance } from "node:perf_hooks";

const HERE = path.dirname(fileURLToPath(import.meta.url));
export const TSF_ROOT = path.resolve(HERE, "..", "..", "..");
export const AUTHORITY_PATH = path.join(
  TSF_ROOT,
  "fleet",
  "control",
  "hq-dispatch",
  "hq-dispatch-synthetic-iteration-authority.v2.json",
);
export const AUTHORITY_SCHEMA_PATH = path.join(
  TSF_ROOT,
  "fleet",
  "control",
  "hq-dispatch",
  "hq-dispatch-synthetic-iteration-authority.schema.v2.json",
);
export const PILOT_ROOT = "C:\\TSF_SYNTHETIC_ITERATION_V2";
export const FIXTURE_ROOT = path.join(PILOT_ROOT, "fixture-repo");
export const EVIDENCE_ROOT = path.join(PILOT_ROOT, "evidence");
export const EXPECTED_AUTHORITY_SHA256 = "1721d6f9ac4380c22b8bad2d753432978d55f35f2f2cbcb1c9c9cce362471222";
const PINNED_EXECUTABLES = Object.freeze({
  node: Object.freeze({
    path: "C:\\Program Files\\nodejs\\node.exe",
    sha256: "3331e1ffe19874215472217c5e94f5a0c6d8e18c4ac7111d3937aa0ad5e9b4a5",
  }),
  git: Object.freeze({
    path: "C:\\Program Files\\Git\\cmd\\git.exe",
    sha256: "81ef35ae005ca9318018d18e3327578ce939fb99feaad6b2d7c8ab15f3de8db5",
  }),
  powershell: Object.freeze({
    path: "C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe",
    sha256: "7600ffe12da441fe89d035b13801e8e91d064bc544a27b19a5cf49f6ab8b18f5",
  }),
});
const PROCESS_TEMP_ROOT = path.join(PILOT_ROOT, "process-temp");
const PROCESS_HOME_ROOT = path.join(PILOT_ROOT, "empty-home");

const SHA256 = /^[a-f0-9]{64}$/;
const HEX40 = /^[a-f0-9]{40}$/;
const CONTROL = /[\x00-\x1f\x7f]/;
const SHELL_META = /[|&;<>()`]/;
const ENV_EXPANSION = /(?:\$\{|\$\(|\$[A-Za-z_]|\%[A-Za-z_][A-Za-z0-9_]*\%)/;
const WILDCARD = /[*?[\]]/;
const SHORT_NAME = /(?:^|[/\\])[^/\\]*~[0-9]+(?:\.[^/\\]*)?(?:[/\\]|$)/i;

export class AuthorityV2Error extends Error {
  constructor(code, disposition = "BLOCKED", details = {}) {
    super(code);
    this.name = "AuthorityV2Error";
    this.code = code;
    this.disposition = disposition;
    this.details = details;
  }
}

function requireValue(condition, code, disposition = "BLOCKED", details = {}) {
  if (!condition) throw new AuthorityV2Error(code, disposition, details);
}

function sortJson(value) {
  if (Array.isArray(value)) return value.map(sortJson);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, sortJson(value[key])]));
  }
  return value;
}

export function canonicalJson(value) {
  return JSON.stringify(sortJson(value));
}

export function sha256(value) {
  const bytes = Buffer.isBuffer(value) ? value : Buffer.from(String(value), "utf8");
  return createHash("sha256").update(bytes).digest("hex");
}

export function identityRecord(value, identityField = "identity_sha256") {
  const record = structuredClone(value);
  delete record[identityField];
  return { ...record, [identityField]: sha256(canonicalJson(record)) };
}

export function assertNoDuplicateJsonMembers(text, code = "DUPLICATE_JSON_MEMBER") {
  requireValue(typeof text === "string", `${code}_TEXT_REQUIRED`);
  const stack = [];
  let inString = false;
  let escaped = false;
  let stringStart = -1;
  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (inString) {
      if (escaped) escaped = false;
      else if (character === "\\") escaped = true;
      else if (character === '"') {
        inString = false;
        let cursor = index + 1;
        while (/\s/.test(text[cursor] ?? "")) cursor += 1;
        if (text[cursor] === ":") {
          const current = stack.at(-1);
          requireValue(current?.type === "object", `${code}_STRUCTURE_INVALID`);
          let key;
          try {
            key = JSON.parse(text.slice(stringStart, index + 1));
          } catch {
            throw new AuthorityV2Error(`${code}_STRUCTURE_INVALID`);
          }
          requireValue(!current.keys.has(key), code, "BLOCKED", { key });
          current.keys.add(key);
        }
      }
      continue;
    }
    if (character === '"') {
      inString = true;
      stringStart = index;
    } else if (character === "{") {
      stack.push({ type: "object", keys: new Set() });
    } else if (character === "[") {
      stack.push({ type: "array" });
    } else if (character === "}") {
      requireValue(stack.at(-1)?.type === "object", `${code}_STRUCTURE_INVALID`);
      stack.pop();
    } else if (character === "]") {
      requireValue(stack.at(-1)?.type === "array", `${code}_STRUCTURE_INVALID`);
      stack.pop();
    }
  }
  requireValue(!inString && stack.length === 0, `${code}_STRUCTURE_INVALID`);
  return { valid: true };
}

function exactKeys(value, keys, code) {
  requireValue(value && typeof value === "object" && !Array.isArray(value), `${code}_OBJECT_REQUIRED`);
  const actual = Object.keys(value).sort();
  const expected = [...keys].sort();
  requireValue(canonicalJson(actual) === canonicalJson(expected), `${code}_FIELDS_CHANGED`, "TIM_REQUIRED", { actual, expected });
}

export function loadAuthority(authorityPath = AUTHORITY_PATH) {
  const text = readFileSync(authorityPath, "utf8");
  assertNoDuplicateJsonMembers(text, "AUTHORITY_DUPLICATE_JSON_MEMBER");
  const authority = JSON.parse(text);
  validateAuthority(authority);
  return authority;
}

export function validateAuthority(authority) {
  exactKeys(authority, [
    "schema_version",
    "contract_version",
    "program_id",
    "action_id",
    "posture",
    "expires_at",
    "tim_authorization_provenance",
    "limits",
    "executables",
    "prohibitions",
    "repository",
    "command_templates",
    "iteration_states",
    "state_transitions",
    "tasks",
  ], "AUTHORITY");
  requireValue(authority.schema_version === "tsf_synthetic_iteration_authority_v2", "AUTHORITY_VERSION_CHANGED");
  requireValue(authority.contract_version === "SYNTHETIC_ITERATION_AUTHORITY_V2", "AUTHORITY_CONTRACT_CHANGED");
  requireValue(authority.program_id === "tsf-v1-synthetic-iteration-authority-v2-20260729", "PROGRAM_ID_CHANGED");
  requireValue(authority.action_id === "tsf_synthetic_workspace_iteration_v2", "ACTION_ID_CHANGED");
  requireValue(authority.posture === "CLOSED_TEST_ONLY", "AUTHORITY_NOT_TEST_ONLY");
  requireValue(sha256(canonicalJson(authority)) === EXPECTED_AUTHORITY_SHA256, "AUTHORITY_EXACT_IDENTITY_CHANGED", "TIM_REQUIRED");
  requireValue(authority.tim_authorization_provenance.automatic_approval_authority === false, "GENERAL_AUTOMATIC_APPROVAL_PROHIBITED");
  requireValue(authority.limits.maximum_tasks === 3, "TASK_LIMIT_CHANGED");
  requireValue(authority.limits.maximum_builder_iterations_per_task === 3, "ITERATION_LIMIT_CHANGED");
  requireValue(authority.limits.maximum_accepted_task_commits === 3, "COMMIT_LIMIT_CHANGED");
  requireValue(authority.limits.maximum_active_write_missions === 1, "ACTIVE_WRITE_LIMIT_CHANGED");
  requireValue(canonicalJson(authority.executables) === canonicalJson({
    node: PINNED_EXECUTABLES.node,
    git: PINNED_EXECUTABLES.git,
  }), "EXECUTABLE_AUTHORITY_CHANGED", "TIM_REQUIRED");
  requireValue(Object.values(authority.prohibitions).every((value) => value === true), "PROHIBITION_WEAKENED");
  requireValue(authority.repository.root === FIXTURE_ROOT, "REPOSITORY_ROOT_CHANGED");
  requireValue(authority.repository.branch === "pilot/tsf-synthetic-iteration-v2-20260729", "REPOSITORY_BRANCH_CHANGED");
  requireValue(authority.repository.allowed_paths.length === 13, "REPOSITORY_ALLOWLIST_CHANGED");
  requireValue(new Set(authority.repository.allowed_paths).size === 13, "REPOSITORY_ALLOWLIST_DUPLICATE");
  requireValue(authority.command_templates.length === 13, "COMMAND_TEMPLATE_SET_CHANGED");
  requireValue(authority.iteration_states.length === 20, "ITERATION_STATE_SET_CHANGED");
  requireValue(
    canonicalJson(Object.keys(authority.state_transitions).sort()) === canonicalJson([...authority.iteration_states].sort()),
    "ITERATION_TRANSITION_STATE_SET_CHANGED",
  );
  requireValue(authority.tasks.length === 3, "TASK_TEMPLATE_SET_CHANGED");
  const expectedTasks = [
    "synthetic-path-containment-v2",
    "synthetic-idempotency-replay-v2",
    "synthetic-result-identity-v2",
  ];
  requireValue(canonicalJson(authority.tasks.map((task) => task.task_id)) === canonicalJson(expectedTasks), "TASK_TEMPLATE_ORDER_OR_ID_CHANGED");
  for (const task of authority.tasks) {
    exactKeys(task, [
      "task_id",
      "goal",
      "authorized_source_paths",
      "authorized_test_paths",
      "focused_tests",
      "acceptance_tests",
      "acceptance_criteria",
      "required_commit_subject",
      "approved_builder_candidate_sets",
      "maximum_iterations",
    ], "TASK_TEMPLATE");
    requireValue(task.maximum_iterations === 3, "TASK_ITERATION_LIMIT_CHANGED");
    requireValue(task.authorized_source_paths.length === 1, "TASK_SOURCE_SCOPE_CHANGED");
    requireValue(task.focused_tests.length === 1 && task.acceptance_tests.length === 1, "TASK_TEST_SET_CHANGED");
    requireValue(
      Array.isArray(task.approved_builder_candidate_sets)
        && task.approved_builder_candidate_sets.length >= 1
        && task.approved_builder_candidate_sets.length <= 3,
      "BUILDER_CANDIDATE_SET_CHANGED",
    );
    const templateKeys = new Set();
    for (const template of task.approved_builder_candidate_sets) {
      exactKeys(template, [
        "contract_version",
        "iteration",
        "repository_relative_path",
        "maximum_candidate_count",
        "candidates",
      ], "BUILDER_CANDIDATE_TEMPLATE");
      requireValue(template.contract_version === "APPROVED_BUILDER_CANDIDATE_TEMPLATE_V2", "BUILDER_CANDIDATE_TEMPLATE_VERSION_CHANGED");
      requireValue(Number.isInteger(template.iteration) && template.iteration >= 1 && template.iteration <= task.maximum_iterations, "BUILDER_CANDIDATE_ITERATION_INVALID");
      requireValue(template.repository_relative_path === task.authorized_source_paths[0], "BUILDER_CANDIDATE_PATH_INVALID");
      requireValue(template.maximum_candidate_count === 1, "BUILDER_CANDIDATE_COUNT_LIMIT_CHANGED");
      requireValue(Array.isArray(template.candidates) && template.candidates.length === 1, "BUILDER_CANDIDATE_COUNT_INVALID");
      const templateKey = `${task.task_id}\n${template.iteration}\n${template.repository_relative_path}`;
      requireValue(!templateKeys.has(templateKey), "BUILDER_CANDIDATE_TEMPLATE_DUPLICATE");
      templateKeys.add(templateKey);
      const candidateHashes = new Set();
      for (const candidate of template.candidates) {
        exactKeys(candidate, ["sha256", "byte_length", "provenance", "generation_run_identity"], "BUILDER_CANDIDATE");
        requireValue(SHA256.test(candidate.sha256), "BUILDER_CANDIDATE_HASH_INVALID");
        requireValue(Number.isInteger(candidate.byte_length) && candidate.byte_length > 0, "BUILDER_CANDIDATE_BYTE_LENGTH_INVALID");
        requireValue(candidate.provenance === "STATIC_BUILDER_CANDIDATE_V2", "BUILDER_CANDIDATE_PROVENANCE_CHANGED");
        requireValue(
          candidate.generation_run_identity === `${task.task_id}-builder-generation-${template.iteration}`,
          "BUILDER_CANDIDATE_GENERATION_IDENTITY_CHANGED",
        );
        requireValue(!candidateHashes.has(candidate.sha256), "BUILDER_CANDIDATE_DUPLICATE");
        candidateHashes.add(candidate.sha256);
      }
    }
    requireValue(
      canonicalJson(task.approved_builder_candidate_sets.map((template) => template.iteration))
        === canonicalJson(task.approved_builder_candidate_sets.map((_, index) => index + 1)),
      "BUILDER_CANDIDATE_ITERATION_SEQUENCE_CHANGED",
    );
    for (const relative of [...task.authorized_source_paths, ...task.authorized_test_paths]) {
      requireValue(authority.repository.allowed_paths.includes(relative), "TASK_PATH_OUTSIDE_REPOSITORY_ALLOWLIST");
    }
  }
  return { valid: true, authority_sha256: sha256(canonicalJson(authority)) };
}

export function normalizeRepositoryRelativePath(value) {
  requireValue(typeof value === "string" && value.length > 0, "PATH_EMPTY");
  requireValue(!CONTROL.test(value), "PATH_CONTROL_CHARACTER");
  requireValue(!value.includes("%"), "PATH_ENCODED_FORM_PROHIBITED");
  requireValue(!value.includes("\\"), "PATH_SEPARATOR_NOT_CANONICAL");
  requireValue(!value.includes(":"), "PATH_ALTERNATE_DATA_STREAM_PROHIBITED");
  requireValue(!WILDCARD.test(value), "PATH_WILDCARD_PROHIBITED");
  requireValue(!SHORT_NAME.test(value), "PATH_SHORT_NAME_ALIAS_PROHIBITED");
  requireValue(!value.startsWith("//"), "PATH_UNC_PROHIBITED");
  requireValue(!path.win32.isAbsolute(value) && !path.posix.isAbsolute(value), "PATH_ABSOLUTE_PROHIBITED");
  const parts = value.split("/");
  requireValue(parts.every((part) => part && part !== "." && part !== ".."), "PATH_TRAVERSAL_PROHIBITED");
  requireValue(parts.every((part) => part === part.trim() && !/[. ]$/.test(part)), "PATH_TRAILING_DOT_OR_SPACE_PROHIBITED");
  requireValue(
    parts.every((part) => !/^(?:con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$/i.test(part)),
    "PATH_RESERVED_DEVICE_NAME_PROHIBITED",
  );
  requireValue(parts.every((part) => part.toLowerCase() !== ".git"), "DIRECT_GIT_PATH_PROHIBITED");
  return parts.join("/");
}

function sameWindowsPath(left, right) {
  return path.resolve(left).replaceAll("/", "\\").toLowerCase() === path.resolve(right).replaceAll("/", "\\").toLowerCase();
}

function pathInside(child, parent) {
  const relative = path.relative(path.resolve(parent), path.resolve(child));
  return relative === "" || (!relative.startsWith(`..${path.sep}`) && relative !== ".." && !path.isAbsolute(relative));
}

function assertNoReparseTraversal(repositoryRoot, fullPath) {
  requireValue(existsSync(repositoryRoot), "REPOSITORY_ROOT_ABSENT");
  requireValue(!lstatSync(repositoryRoot).isSymbolicLink(), "REPOSITORY_ROOT_REPARSE_POINT");
  const realRoot = realpathSync.native(repositoryRoot);
  requireValue(sameWindowsPath(realRoot, repositoryRoot), "REPOSITORY_ROOT_ALIAS_OR_REPARSE");
  const relative = path.relative(repositoryRoot, fullPath);
  let cursor = repositoryRoot;
  for (const part of relative.split(path.sep).filter(Boolean)) {
    cursor = path.join(cursor, part);
    if (!existsSync(cursor)) continue;
    requireValue(!lstatSync(cursor).isSymbolicLink(), "PATH_REPARSE_TRAVERSAL", "BLOCKED", { cursor });
    requireValue(pathInside(realpathSync.native(cursor), realRoot), "PATH_REALPATH_ESCAPE", "BLOCKED", { cursor });
  }
}

export function closedEnvironment(extra = {}) {
  mkdirSync(PROCESS_TEMP_ROOT, { recursive: true });
  mkdirSync(PROCESS_HOME_ROOT, { recursive: true });
  const allowedExtraKeys = new Set([
    "GIT_AUTHOR_NAME",
    "GIT_AUTHOR_EMAIL",
    "GIT_COMMITTER_NAME",
    "GIT_COMMITTER_EMAIL",
  ]);
  for (const [key, value] of Object.entries(extra)) {
    requireValue(allowedExtraKeys.has(key), "PROCESS_ENVIRONMENT_KEY_NOT_ALLOWLISTED", "BLOCKED", { key });
    requireValue(typeof value === "string" && value.length > 0, "PROCESS_ENVIRONMENT_VALUE_INVALID", "BLOCKED", { key });
  }
  return {
    SystemRoot: "C:\\Windows",
    WINDIR: "C:\\Windows",
    TEMP: PROCESS_TEMP_ROOT,
    TMP: PROCESS_TEMP_ROOT,
    HOME: PROCESS_HOME_ROOT,
    USERPROFILE: PROCESS_HOME_ROOT,
    PATH: "",
    PATHEXT: ".COM;.EXE;.BAT;.CMD",
    GIT_TERMINAL_PROMPT: "0",
    GCM_INTERACTIVE: "Never",
    GIT_CONFIG_NOSYSTEM: "1",
    GIT_CONFIG_GLOBAL: "NUL",
    GIT_CONFIG_COUNT: "2",
    GIT_CONFIG_KEY_0: "credential.helper",
    GIT_CONFIG_VALUE_0: "",
    GIT_CONFIG_KEY_1: "core.hooksPath",
    GIT_CONFIG_VALUE_1: "NUL",
    ...extra,
  };
}

function assertPinnedExecutable(identity, code = "COMMAND_EXECUTABLE_IDENTITY_CHANGED") {
  requireValue(identity && typeof identity.path === "string" && SHA256.test(identity.sha256), code);
  requireValue(existsSync(identity.path) && statSync(identity.path).isFile(), code);
  requireValue(!lstatSync(identity.path).isSymbolicLink(), code);
  requireValue(sameWindowsPath(realpathSync.native(identity.path), identity.path), code);
  requireValue(sha256(readFileSync(identity.path)) === identity.sha256, code);
  return identity.path;
}

export function validateAllowedPath({ repositoryRoot, relativePath, allowlist, requireExisting = false }) {
  const normalized = normalizeRepositoryRelativePath(relativePath);
  requireValue(allowlist.includes(normalized), "PATH_NOT_EXACTLY_ALLOWLISTED", "BLOCKED", { normalized });
  const fullPath = path.resolve(repositoryRoot, ...normalized.split("/"));
  requireValue(pathInside(fullPath, repositoryRoot), "PATH_ESCAPES_REPOSITORY");
  assertNoReparseTraversal(repositoryRoot, fullPath);
  if (requireExisting) requireValue(existsSync(fullPath), "ALLOWLISTED_PATH_ABSENT");
  return { normalized, fullPath };
}

function internalRun(executable, args, cwd, options = {}) {
  const result = spawnSync(executable, args, {
    cwd,
    encoding: "utf8",
    shell: false,
    windowsHide: true,
    timeout: options.timeout ?? 60_000,
    env: closedEnvironment(options.env ?? {}),
  });
  return {
    exit_code: result.status ?? (result.error ? 1 : 0),
    stdout: String(result.stdout ?? ""),
    stderr: String(result.stderr ?? result.error?.message ?? ""),
    signal: result.signal ?? null,
  };
}

function internalRunBytes(executable, args, cwd, options = {}) {
  const result = spawnSync(executable, args, {
    cwd,
    encoding: null,
    shell: false,
    windowsHide: true,
    timeout: options.timeout ?? 60_000,
    env: closedEnvironment(options.env ?? {}),
  });
  return {
    exit_code: result.status ?? (result.error ? 1 : 0),
    stdout: Buffer.isBuffer(result.stdout) ? result.stdout : Buffer.alloc(0),
    stderr: Buffer.isBuffer(result.stderr)
      ? result.stderr.toString("utf8")
      : String(result.error?.message ?? ""),
    signal: result.signal ?? null,
  };
}

function requireInternalSuccess(result, code) {
  requireValue(result.exit_code === 0, code, "BLOCKED", { exit_code: result.exit_code, stderr: result.stderr });
  return result.stdout.trim();
}

function gitInternal(cwd, args, options = {}) {
  return internalRun(assertPinnedExecutable(PINNED_EXECUTABLES.git), args, cwd, options);
}

function gitInternalBytes(cwd, args, options = {}) {
  return internalRunBytes(assertPinnedExecutable(PINNED_EXECUTABLES.git), args, cwd, options);
}

function listRepositoryFiles(root) {
  const files = [];
  function visit(directory, relativeBase = "") {
    for (const entry of readdirSync(directory, { withFileTypes: true })) {
      if (!relativeBase && entry.name === ".git") continue;
      const relative = relativeBase ? `${relativeBase}/${entry.name}` : entry.name;
      const full = path.join(directory, entry.name);
      requireValue(!lstatSync(full).isSymbolicLink(), "REPOSITORY_INVENTORY_REPARSE_POINT", "BLOCKED", { relative });
      if (entry.isDirectory()) {
        requireValue(entry.name.toLowerCase() !== ".git", "NESTED_FOREIGN_GIT_REPOSITORY", "BLOCKED", { relative });
        visit(full, relative);
      } else {
        files.push(relative);
      }
    }
  }
  visit(root);
  return files.sort();
}

function fileHashMap(root, files) {
  return Object.fromEntries(files.map((relative) => [relative, sha256(readFileSync(path.join(root, ...relative.split("/"))))]));
}

export function validateRegistrationRecord(record, authority, { now = new Date(), requireBaselineHead = true } = {}) {
  exactKeys(record, [
    "schema_version",
    "registration_id",
    "program_id",
    "action_id",
    "repository_root",
    "git_top_level",
    "branch",
    "baseline_commit",
    "baseline_tree",
    "baseline_subject",
    "file_inventory",
    "file_hashes",
    "remote_count",
    "registered_at",
    "expires_at",
    "contract_version",
    "registration_identity_sha256",
  ], "REGISTRATION");
  const identity = record.registration_identity_sha256;
  const expectedIdentity = identityRecord(record, "registration_identity_sha256").registration_identity_sha256;
  requireValue(identity === expectedIdentity && SHA256.test(identity), "REGISTRATION_IDENTITY_INVALID", "TIM_REQUIRED");
  requireValue(record.schema_version === "SYNTHETIC_REPOSITORY_REGISTRATION_V2", "REGISTRATION_VERSION_CHANGED", "TIM_REQUIRED");
  requireValue(record.program_id === authority.program_id && record.action_id === authority.action_id, "REGISTRATION_PROGRAM_OR_ACTION_CHANGED", "TIM_REQUIRED");
  requireValue(record.repository_root === authority.repository.root, "REGISTRATION_ROOT_CHANGED", "TIM_REQUIRED");
  requireValue(record.git_top_level === authority.repository.root, "REGISTRATION_GIT_TOP_CHANGED", "TIM_REQUIRED");
  requireValue(record.branch === authority.repository.branch, "REGISTRATION_BRANCH_CHANGED", "TIM_REQUIRED");
  requireValue(!requireBaselineHead || HEX40.test(record.baseline_commit), "REGISTRATION_BASELINE_INVALID", "TIM_REQUIRED");
  requireValue(HEX40.test(record.baseline_tree), "REGISTRATION_BASELINE_TREE_INVALID", "TIM_REQUIRED");
  requireValue(record.baseline_subject === authority.repository.baseline_subject, "REGISTRATION_BASELINE_SUBJECT_CHANGED", "TIM_REQUIRED");
  requireValue(canonicalJson(record.file_inventory) === canonicalJson([...authority.repository.allowed_paths].sort()), "REGISTRATION_FILE_INVENTORY_CHANGED", "TIM_REQUIRED");
  requireValue(
    canonicalJson(Object.keys(record.file_hashes).sort()) === canonicalJson([...record.file_inventory].sort()),
    "REGISTRATION_FILE_HASH_KEYS_CHANGED",
    "TIM_REQUIRED",
  );
  requireValue(Object.values(record.file_hashes).every((hash) => SHA256.test(hash)), "REGISTRATION_FILE_HASH_INVALID", "TIM_REQUIRED");
  requireValue(record.remote_count === 0, "REGISTRATION_REMOTE_PRESENT", "TIM_REQUIRED");
  requireValue(new Date(record.expires_at) >= now, "REGISTRATION_EXPIRED", "TIM_REQUIRED");
  requireValue(record.contract_version === authority.contract_version, "REGISTRATION_CONTRACT_CHANGED", "TIM_REQUIRED");
  return { valid: true, registration_identity_sha256: identity };
}

export function inspectFixtureRegistration(authority, { now = new Date() } = {}) {
  const root = authority.repository.root;
  requireValue(existsSync(root) && statSync(root).isDirectory(), "FIXTURE_REPOSITORY_ABSENT");
  requireValue(!lstatSync(root).isSymbolicLink(), "FIXTURE_REPOSITORY_REPARSE_POINT");
  requireValue(sameWindowsPath(realpathSync.native(root), root), "FIXTURE_REPOSITORY_ALIAS_OR_REPARSE");
  const top = requireInternalSuccess(gitInternal(root, ["rev-parse", "--show-toplevel"]), "FIXTURE_GIT_TOP_UNAVAILABLE");
  const branch = requireInternalSuccess(gitInternal(root, ["branch", "--show-current"]), "FIXTURE_BRANCH_UNAVAILABLE");
  const head = requireInternalSuccess(gitInternal(root, ["rev-parse", "HEAD"]), "FIXTURE_HEAD_UNAVAILABLE");
  const tree = requireInternalSuccess(gitInternal(root, ["rev-parse", "HEAD^{tree}"]), "FIXTURE_TREE_UNAVAILABLE");
  const subject = requireInternalSuccess(gitInternal(root, ["show", "-s", "--format=%s", head]), "FIXTURE_SUBJECT_UNAVAILABLE");
  const remoteText = requireInternalSuccess(gitInternal(root, ["remote"]), "FIXTURE_REMOTE_INSPECTION_FAILED");
  const files = listRepositoryFiles(root);
  requireValue(sameWindowsPath(top, root), "FIXTURE_GIT_TOP_MISMATCH");
  requireValue(branch === authority.repository.branch, "FIXTURE_BRANCH_MISMATCH");
  requireValue(canonicalJson(files) === canonicalJson([...authority.repository.allowed_paths].sort()), "FIXTURE_FILE_INVENTORY_MISMATCH");
  requireValue(remoteText === "", "FIXTURE_REMOTE_PRESENT");
  const base = {
    schema_version: "SYNTHETIC_REPOSITORY_REGISTRATION_V2",
    registration_id: `synthetic-registration-${sha256(`${root}\n${head}`).slice(0, 32)}`,
    program_id: authority.program_id,
    action_id: authority.action_id,
    repository_root: root,
    git_top_level: root,
    branch,
    baseline_commit: head,
    baseline_tree: tree,
    baseline_subject: subject,
    file_inventory: files,
    file_hashes: fileHashMap(root, files),
    remote_count: 0,
    registered_at: now.toISOString(),
    expires_at: authority.expires_at,
    contract_version: authority.contract_version,
  };
  const record = identityRecord(base, "registration_identity_sha256");
  validateRegistrationRecord(record, authority, { now });
  return record;
}

function resolveConcreteBaselineTree(registration, concreteBaselineCommit, concreteBaselineTree = null) {
  if (concreteBaselineTree !== null) {
    requireValue(HEX40.test(concreteBaselineTree), "TASK_BASELINE_TREE_INVALID", "TIM_REQUIRED");
    return concreteBaselineTree;
  }
  if (concreteBaselineCommit === registration.baseline_commit) return registration.baseline_tree;
  requireValue(
    existsSync(registration.repository_root) && statSync(registration.repository_root).isDirectory(),
    "TASK_BASELINE_TREE_REQUIRED",
    "TIM_REQUIRED",
  );
  const observed = requireInternalSuccess(
    gitInternal(registration.repository_root, ["rev-parse", `${concreteBaselineCommit}^{tree}`]),
    "TASK_BASELINE_TREE_UNAVAILABLE",
  );
  requireValue(HEX40.test(observed), "TASK_BASELINE_TREE_INVALID", "TIM_REQUIRED");
  return observed;
}

export function createTaskPreauthorization(
  authority,
  registration,
  taskId,
  concreteBaselineCommit = registration.baseline_commit,
  concreteBaselineTree = null,
) {
  validateRegistrationRecord(registration, authority);
  const task = authority.tasks.find((item) => item.task_id === taskId);
  requireValue(task, "UNKNOWN_TASK_TEMPLATE", "TIM_REQUIRED");
  requireValue(HEX40.test(concreteBaselineCommit), "TASK_BASELINE_INVALID", "TIM_REQUIRED");
  const baselineTree = resolveConcreteBaselineTree(registration, concreteBaselineCommit, concreteBaselineTree);
  const base = {
    schema_version: "SYNTHETIC_TASK_PREAUTHORIZATION_V2",
    program_id: authority.program_id,
    action_id: authority.action_id,
    task_id: task.task_id,
    goal: task.goal,
    repository_root: registration.repository_root,
    git_top_level: registration.git_top_level,
    branch: registration.branch,
    baseline_commit: concreteBaselineCommit,
    baseline_tree: baselineTree,
    authorized_source_paths: task.authorized_source_paths,
    authorized_test_paths: task.authorized_test_paths,
    authorized_command_templates: authority.command_templates,
    required_focused_tests: task.focused_tests,
    required_acceptance_tests: task.acceptance_tests,
    acceptance_criteria: task.acceptance_criteria,
    maximum_iterations: task.maximum_iterations,
    required_commit_subject: task.required_commit_subject,
    approved_candidate_template_sha256s: task.approved_builder_candidate_sets
      .map((template) => sha256(canonicalJson(template))),
    network_prohibited: true,
    remote_git_prohibited: true,
    package_installation_prohibited: true,
    expires_at: authority.expires_at,
    contract_version: authority.contract_version,
    tim_authorization_provenance: authority.tim_authorization_provenance,
  };
  return identityRecord(base, "preauthorization_identity_sha256");
}

export function createApprovedBuilderCandidateSet(
  authority,
  registration,
  task,
  preauthorization,
  iteration,
  relativePath = task.authorized_source_paths[0],
) {
  validateAuthority(authority);
  validateRegistrationRecord(registration, authority);
  const canonicalTask = authority.tasks.find((item) => item.task_id === task.task_id);
  requireValue(
    canonicalTask && canonicalJson(task) === canonicalJson(canonicalTask),
    "APPROVED_CANDIDATE_TASK_NOT_CANONICAL",
  );
  const expectedPreauthorization = createTaskPreauthorization(
    authority,
    registration,
    task.task_id,
    preauthorization.baseline_commit,
    preauthorization.baseline_tree,
  );
  requireValue(
    canonicalJson(preauthorization) === canonicalJson(expectedPreauthorization),
    "APPROVED_CANDIDATE_PREAUTHORIZATION_CHANGED",
    "TIM_REQUIRED",
  );
  const normalizedPath = normalizeRepositoryRelativePath(relativePath);
  const templates = task.approved_builder_candidate_sets.filter(
    (template) => template.iteration === iteration
      && template.repository_relative_path === normalizedPath,
  );
  requireValue(templates.length === 1, "APPROVED_BUILDER_CANDIDATE_SET_UNAVAILABLE");
  const template = templates[0];
  const base = {
    schema_version: "APPROVED_BUILDER_CANDIDATE_SET_V2",
    contract_version: "APPROVED_BUILDER_CANDIDATE_SET_V2",
    canonical_authority_sha256: EXPECTED_AUTHORITY_SHA256,
    program_id: authority.program_id,
    task_id: task.task_id,
    registration_identity_sha256: registration.registration_identity_sha256,
    preauthorization_identity_sha256: preauthorization.preauthorization_identity_sha256,
    repository_root: registration.repository_root,
    git_top_level: registration.git_top_level,
    branch: registration.branch,
    baseline_commit: preauthorization.baseline_commit,
    baseline_tree: preauthorization.baseline_tree,
    iteration,
    repository_relative_path: normalizedPath,
    candidates: structuredClone(template.candidates),
    maximum_candidate_count: template.maximum_candidate_count,
    expires_at: authority.expires_at,
  };
  return identityRecord(base, "candidate_set_identity_sha256");
}

export function validateApprovedBuilderCandidateSet(
  authority,
  registration,
  task,
  preauthorization,
  candidateSet,
  { now = new Date() } = {},
) {
  requireValue(candidateSet && typeof candidateSet === "object", "APPROVED_CANDIDATE_SET_REQUIRED");
  exactKeys(candidateSet, [
    "schema_version",
    "contract_version",
    "canonical_authority_sha256",
    "program_id",
    "task_id",
    "registration_identity_sha256",
    "preauthorization_identity_sha256",
    "repository_root",
    "git_top_level",
    "branch",
    "baseline_commit",
    "baseline_tree",
    "iteration",
    "repository_relative_path",
    "candidates",
    "maximum_candidate_count",
    "expires_at",
    "candidate_set_identity_sha256",
  ], "APPROVED_CANDIDATE_SET");
  requireValue(
    candidateSet.schema_version === "APPROVED_BUILDER_CANDIDATE_SET_V2"
      && candidateSet.contract_version === "APPROVED_BUILDER_CANDIDATE_SET_V2",
    "APPROVED_CANDIDATE_SET_VERSION_CHANGED",
  );
  requireValue(candidateSet.program_id === authority.program_id, "APPROVED_CANDIDATE_SET_PROGRAM_CHANGED");
  requireValue(candidateSet.task_id === task.task_id, "APPROVED_CANDIDATE_SET_TASK_CHANGED");
  requireValue(candidateSet.registration_identity_sha256 === registration.registration_identity_sha256, "APPROVED_CANDIDATE_SET_REGISTRATION_CHANGED");
  requireValue(
    candidateSet.preauthorization_identity_sha256 === preauthorization.preauthorization_identity_sha256,
    "APPROVED_CANDIDATE_SET_PREAUTHORIZATION_CHANGED",
  );
  requireValue(
    candidateSet.repository_root === registration.repository_root
      && candidateSet.git_top_level === registration.git_top_level
      && candidateSet.branch === registration.branch,
    "APPROVED_CANDIDATE_SET_REPOSITORY_CHANGED",
  );
  requireValue(
    candidateSet.baseline_commit === preauthorization.baseline_commit
      && candidateSet.baseline_tree === preauthorization.baseline_tree,
    "APPROVED_CANDIDATE_SET_BASELINE_CHANGED",
  );
  requireValue(
    task.authorized_source_paths.includes(candidateSet.repository_relative_path),
    "APPROVED_CANDIDATE_SET_PATH_CHANGED",
  );
  requireValue(
    Number.isInteger(candidateSet.iteration)
      && candidateSet.iteration >= 1
      && candidateSet.iteration <= task.maximum_iterations,
    "APPROVED_CANDIDATE_SET_ITERATION_CHANGED",
  );
  requireValue(new Date(candidateSet.expires_at) >= now, "APPROVED_CANDIDATE_SET_EXPIRED", "TIM_REQUIRED");
  const expected = createApprovedBuilderCandidateSet(
    authority,
    registration,
    task,
    preauthorization,
    candidateSet.iteration,
    candidateSet.repository_relative_path,
  );
  requireValue(
    canonicalJson(candidateSet) === canonicalJson(expected),
    "APPROVED_CANDIDATE_SET_CANONICAL_MISMATCH",
    "BLOCKED",
  );
  requireValue(candidateSet.candidates.length <= candidateSet.maximum_candidate_count, "APPROVED_CANDIDATE_SET_COUNT_EXCEEDED");
  requireValue(
    new Set(candidateSet.candidates.map((candidate) => candidate.sha256)).size === candidateSet.candidates.length,
    "APPROVED_CANDIDATE_SET_DUPLICATE_MEMBER",
  );
  return { valid: true, candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256 };
}

export function createPreauthorizedTaskBinding(authority, registration, candidatePreauthorization) {
  const expected = createTaskPreauthorization(
    authority,
    registration,
    candidatePreauthorization.task_id,
    candidatePreauthorization.baseline_commit,
    candidatePreauthorization.baseline_tree,
  );
  requireValue(canonicalJson(candidatePreauthorization) === canonicalJson(expected), "PREAUTHORIZATION_TEMPLATE_MISMATCH", "TIM_REQUIRED");
  const task = authority.tasks.find((item) => item.task_id === expected.task_id);
  const approvedCandidateSetIdentities = task.approved_builder_candidate_sets.map((template) => (
    createApprovedBuilderCandidateSet(
      authority,
      registration,
      task,
      expected,
      template.iteration,
      template.repository_relative_path,
    ).candidate_set_identity_sha256
  ));
  const base = {
    schema_version: "PREAUTHORIZED_TASK_BINDING_V2",
    program_id: authority.program_id,
    task_id: expected.task_id,
    registration_identity_sha256: registration.registration_identity_sha256,
    preauthorization_identity_sha256: expected.preauthorization_identity_sha256,
    repository_root: registration.repository_root,
    branch: registration.branch,
    baseline_commit: expected.baseline_commit,
    baseline_tree: expected.baseline_tree,
    approved_candidate_set_identity_sha256s: approvedCandidateSetIdentities,
    mission_authority_added: false,
    path_authority_added: false,
    command_authority_added: false,
    test_requirement_removed: false,
    acceptance_requirement_weakened: false,
    iteration_budget_increased: false,
    disposition: "PREAUTHORIZED",
  };
  return identityRecord(base, "binding_identity_sha256");
}

export function matchPreauthorizedTaskBinding(authority, registration, preauthorization, binding, taskId) {
  requireValue(taskId === preauthorization.task_id && taskId === binding.task_id, "CROSS_TASK_BINDING", "TIM_REQUIRED");
  const expectedPreauthorization = createTaskPreauthorization(
    authority,
    registration,
    taskId,
    preauthorization.baseline_commit,
    preauthorization.baseline_tree,
  );
  requireValue(canonicalJson(preauthorization) === canonicalJson(expectedPreauthorization), "PREAUTHORIZATION_CHANGED", "TIM_REQUIRED");
  const expectedBinding = createPreauthorizedTaskBinding(authority, registration, expectedPreauthorization);
  requireValue(canonicalJson(binding) === canonicalJson(expectedBinding), "PREAUTHORIZED_BINDING_CHANGED_OR_REPLAYED", "TIM_REQUIRED");
  return { disposition: "PREAUTHORIZED", binding_identity_sha256: binding.binding_identity_sha256 };
}

export function consumePreauthorizedTaskBinding(binding, consumedBindingIdentities) {
  requireValue(consumedBindingIdentities instanceof Set, "BINDING_CONSUMPTION_REGISTRY_REQUIRED");
  requireValue(!consumedBindingIdentities.has(binding.binding_identity_sha256), "PREAUTHORIZED_BINDING_REPLAYED", "TIM_REQUIRED");
  consumedBindingIdentities.add(binding.binding_identity_sha256);
  return { consumed: true, binding_identity_sha256: binding.binding_identity_sha256 };
}

export function transitionIteration(authority, currentState, nextState) {
  requireValue(authority.iteration_states.includes(currentState), "ITERATION_STATE_UNKNOWN");
  requireValue(authority.iteration_states.includes(nextState), "ITERATION_NEXT_STATE_UNKNOWN");
  requireValue(authority.state_transitions[currentState].includes(nextState), "ITERATION_TRANSITION_INVALID", "BLOCKED", { currentState, nextState });
  return nextState;
}

export function authorizeBuilderIteration(authority, task, existingIterations, requestedIteration) {
  const maximum = Math.min(authority.limits.maximum_builder_iterations_per_task, task.maximum_iterations);
  requireValue(requestedIteration === existingIterations.length + 1, "ITERATION_SEQUENCE_INVALID");
  requireValue(requestedIteration <= maximum, "ITERATION_LIMIT_EXHAUSTED", "EXHAUSTED");
  requireValue(!existingIterations.some((item) => item.iteration === requestedIteration), "ITERATION_REPLAYED");
  return {
    authorized: true,
    iteration: requestedIteration,
    run_id: `${task.task_id}-iteration-${requestedIteration}-${randomUUID()}`,
    maximum,
  };
}

export function createApprovedWriteset({
  authority,
  registration,
  task,
  preauthorization,
  binding,
  candidateSet,
  iteration,
  runId,
  relativePath,
  beforeSha256,
  content,
  candidateArtifactRelativePath,
  expectedFileMode = "100644",
}) {
  requireValue(preauthorization && candidateSet, "APPROVED_CANDIDATE_SET_REQUIRED");
  matchPreauthorizedTaskBinding(
    authority,
    registration,
    preauthorization,
    binding,
    task.task_id,
  );
  validateApprovedBuilderCandidateSet(authority, registration, task, preauthorization, candidateSet);
  requireValue(
    binding.approved_candidate_set_identity_sha256s.includes(candidateSet.candidate_set_identity_sha256),
    "APPROVED_CANDIDATE_SET_NOT_BOUND_TO_TASK",
  );
  const validated = validateAllowedPath({
    repositoryRoot: registration.repository_root,
    relativePath,
    allowlist: task.authorized_source_paths,
    requireExisting: true,
  });
  requireValue(SHA256.test(beforeSha256), "WRITESET_BEFORE_HASH_INVALID");
  const observedBeforeSha256 = sha256(readFileSync(validated.fullPath));
  requireValue(observedBeforeSha256 === beforeSha256, "WRITESET_STALE_BEFORE_WRITE");
  requireValue(candidateSet.iteration === iteration, "WRITESET_CANDIDATE_SET_ITERATION_CHANGED");
  requireValue(candidateSet.repository_relative_path === validated.normalized, "WRITESET_CANDIDATE_SET_PATH_CHANGED");
  const bytes = Buffer.isBuffer(content) ? content : Buffer.from(content, "utf8");
  const replacementSha256 = sha256(bytes);
  const member = candidateSet.candidates.find((candidate) => candidate.sha256 === replacementSha256);
  requireValue(member, "REPLACEMENT_SHA_NOT_IN_APPROVED_BUILDER_CANDIDATE_SET");
  requireValue(member.byte_length === bytes.length, "REPLACEMENT_BYTE_LENGTH_NOT_APPROVED");
  const artifactPath = normalizeRepositoryRelativePath(candidateArtifactRelativePath);
  requireValue(
    artifactPath === `tasks/${task.task_id}/iteration-${iteration}/replacement.bin`,
    "WRITESET_CANDIDATE_ARTIFACT_PATH_CHANGED",
  );
  requireValue(expectedFileMode === "100644", "WRITESET_EXPECTED_FILE_MODE_CHANGED");
  const base = {
    schema_version: "APPROVED_WRITESET_V2",
    program_id: authority.program_id,
    task_id: task.task_id,
    preauthorization_identity_sha256: preauthorization.preauthorization_identity_sha256,
    binding_identity_sha256: binding.binding_identity_sha256,
    approved_candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    registration_identity_sha256: registration.registration_identity_sha256,
    repository_root: registration.repository_root,
    branch: registration.branch,
    baseline_commit: binding.baseline_commit,
    baseline_tree: binding.baseline_tree,
    iteration,
    run_id: runId,
    writes: [{
      relative_path: validated.normalized,
      before_sha256: beforeSha256,
      approved_replacement_sha256: replacementSha256,
      replacement_byte_length: bytes.length,
      candidate_artifact_relative_path: artifactPath,
      candidate_artifact_sha256: replacementSha256,
      operation: "ATOMIC_REPLACE",
      expected_file_mode: expectedFileMode,
    }],
    temporary_files_inside_repository: [],
    command_templates: authority.command_templates,
  };
  const writeset = identityRecord(base, "writeset_identity_sha256");
  validateApprovedWriteset(
    authority,
    registration,
    task,
    preauthorization,
    binding,
    candidateSet,
    writeset,
    { replacementBytes: bytes, observedBeforeSha256 },
  );
  return writeset;
}

export function validateApprovedWriteset(
  authority,
  registration,
  task,
  preauthorization,
  binding,
  candidateSet,
  writeset,
  { replacementBytes = null, observedBeforeSha256 = null } = {},
) {
  requireValue(preauthorization && candidateSet, "APPROVED_CANDIDATE_SET_REQUIRED");
  matchPreauthorizedTaskBinding(authority, registration, preauthorization, binding, task.task_id);
  validateApprovedBuilderCandidateSet(authority, registration, task, preauthorization, candidateSet);
  exactKeys(writeset, [
    "schema_version",
    "program_id",
    "task_id",
    "preauthorization_identity_sha256",
    "binding_identity_sha256",
    "approved_candidate_set_identity_sha256",
    "registration_identity_sha256",
    "repository_root",
    "branch",
    "baseline_commit",
    "baseline_tree",
    "iteration",
    "run_id",
    "writes",
    "temporary_files_inside_repository",
    "command_templates",
    "writeset_identity_sha256",
  ], "WRITESET");
  requireValue(writeset.schema_version === "APPROVED_WRITESET_V2", "WRITESET_VERSION_CHANGED");
  requireValue(writeset.program_id === authority.program_id && writeset.task_id === task.task_id, "WRITESET_TASK_CHANGED");
  requireValue(
    writeset.preauthorization_identity_sha256 === preauthorization.preauthorization_identity_sha256,
    "WRITESET_PREAUTHORIZATION_CHANGED",
  );
  requireValue(writeset.registration_identity_sha256 === registration.registration_identity_sha256, "WRITESET_REGISTRATION_CHANGED");
  requireValue(writeset.binding_identity_sha256 === binding.binding_identity_sha256, "WRITESET_BINDING_CHANGED");
  requireValue(
    writeset.approved_candidate_set_identity_sha256 === candidateSet.candidate_set_identity_sha256
      && binding.approved_candidate_set_identity_sha256s.includes(candidateSet.candidate_set_identity_sha256),
    "WRITESET_CANDIDATE_SET_CHANGED",
  );
  requireValue(writeset.repository_root === registration.repository_root && writeset.branch === registration.branch, "WRITESET_REPOSITORY_CHANGED");
  requireValue(writeset.baseline_commit === binding.baseline_commit, "WRITESET_BASELINE_CHANGED");
  requireValue(writeset.baseline_tree === binding.baseline_tree, "WRITESET_BASELINE_TREE_CHANGED");
  requireValue(Number.isInteger(writeset.iteration) && writeset.iteration >= 1 && writeset.iteration <= task.maximum_iterations, "WRITESET_ITERATION_EXHAUSTED");
  requireValue(writeset.iteration === candidateSet.iteration, "WRITESET_CANDIDATE_SET_ITERATION_CHANGED");
  requireValue(typeof writeset.run_id === "string" && writeset.run_id.startsWith(`${task.task_id}-iteration-${writeset.iteration}-`), "WRITESET_RUN_CHANGED");
  requireValue(Array.isArray(writeset.writes) && writeset.writes.length === 1, "WRITESET_OPERATION_COUNT_CHANGED");
  exactKeys(writeset.writes[0], [
    "relative_path",
    "before_sha256",
    "approved_replacement_sha256",
    "replacement_byte_length",
    "candidate_artifact_relative_path",
    "candidate_artifact_sha256",
    "operation",
    "expected_file_mode",
  ], "WRITESET_OPERATION");
  requireValue(writeset.writes[0].relative_path === task.authorized_source_paths[0], "WRITESET_PATH_CHANGED");
  requireValue(writeset.writes[0].relative_path === candidateSet.repository_relative_path, "WRITESET_CANDIDATE_SET_PATH_CHANGED");
  requireValue(
    SHA256.test(writeset.writes[0].before_sha256)
      && SHA256.test(writeset.writes[0].approved_replacement_sha256),
    "WRITESET_CONTENT_IDENTITY_INVALID",
  );
  const member = candidateSet.candidates.find(
    (candidate) => candidate.sha256 === writeset.writes[0].approved_replacement_sha256,
  );
  requireValue(member, "REPLACEMENT_SHA_NOT_IN_APPROVED_BUILDER_CANDIDATE_SET");
  requireValue(
    writeset.writes[0].candidate_artifact_sha256 === member.sha256
      && writeset.writes[0].replacement_byte_length === member.byte_length,
    "WRITESET_CANDIDATE_ARTIFACT_IDENTITY_CHANGED",
  );
  requireValue(
    writeset.writes[0].candidate_artifact_relative_path
      === `tasks/${task.task_id}/iteration-${writeset.iteration}/replacement.bin`,
    "WRITESET_CANDIDATE_ARTIFACT_PATH_CHANGED",
  );
  requireValue(writeset.writes[0].expected_file_mode === "100644", "WRITESET_EXPECTED_FILE_MODE_CHANGED");
  requireValue(writeset.writes[0].operation === "ATOMIC_REPLACE", "WRITESET_OPERATION_CHANGED");
  if (observedBeforeSha256 !== null) {
    requireValue(observedBeforeSha256 === writeset.writes[0].before_sha256, "WRITESET_STALE_BEFORE_WRITE");
  }
  if (replacementBytes !== null) {
    const bytes = Buffer.isBuffer(replacementBytes) ? replacementBytes : Buffer.from(replacementBytes, "utf8");
    requireValue(sha256(bytes) === member.sha256, "WRITESET_CANDIDATE_ARTIFACT_BYTES_CHANGED");
    requireValue(bytes.length === member.byte_length, "WRITESET_CANDIDATE_ARTIFACT_LENGTH_CHANGED");
  }
  requireValue(Array.isArray(writeset.temporary_files_inside_repository) && writeset.temporary_files_inside_repository.length === 0, "WRITESET_TEMPORARY_SCOPE_CHANGED");
  requireValue(canonicalJson(writeset.command_templates) === canonicalJson(authority.command_templates), "WRITESET_COMMAND_AUTHORITY_CHANGED");
  requireValue(
    identityRecord(writeset, "writeset_identity_sha256").writeset_identity_sha256 === writeset.writeset_identity_sha256,
    "WRITESET_IDENTITY_MISMATCH",
  );
  return { valid: true };
}

export function validateRecoveryState(
  authority,
  registration,
  task,
  preauthorization,
  binding,
  candidateSet,
  writeset,
  recovery,
) {
  requireValue(candidateSet, "RECOVERY_CANONICAL_CANDIDATE_BINDING_ABSENT", "NEW_GOVERNED_RECOVERY_REQUIRED");
  validateApprovedWriteset(authority, registration, task, preauthorization, binding, candidateSet, writeset);
  exactKeys(recovery, [
    "schema_version",
    "program_id",
    "task_id",
    "repository_root",
    "branch",
    "baseline_commit",
    "baseline_tree",
    "registration_identity_sha256",
    "preauthorization_identity_sha256",
    "binding_identity_sha256",
    "candidate_set_identity_sha256",
    "candidate_set_relative_path",
    "candidate_set_file_sha256",
    "writeset_identity_sha256",
    "writeset_relative_path",
    "writeset_file_sha256",
    "iteration",
    "original_run_id",
    "recovery_run_id",
    "source_relative_path",
    "preimage_relative_path",
    "preimage_sha256",
    "replacement_relative_path",
    "replacement_sha256",
    "replacement_byte_length",
    "recovery_receipt_relative_path",
    "interruption_point",
    "repository_condition",
    "pre_iteration_sha256",
    "expected_replacement_sha256",
    "authorized_disposition",
    "auto_admitted",
    "auto_rerun",
    "recovery_identity_sha256",
  ], "RECOVERY");
  requireValue(recovery.schema_version === "SYNTHETIC_WRITE_RECOVERY_STATE_V2", "RECOVERY_VERSION_CHANGED");
  requireValue(recovery.program_id === authority.program_id, "RECOVERY_PROGRAM_CHANGED");
  requireValue(recovery.task_id === task.task_id, "RECOVERY_TASK_CHANGED");
  requireValue(recovery.repository_root === registration.repository_root, "RECOVERY_REPOSITORY_CHANGED");
  requireValue(recovery.branch === registration.branch, "RECOVERY_BRANCH_CHANGED");
  requireValue(recovery.baseline_commit === binding.baseline_commit, "RECOVERY_BASELINE_CHANGED");
  requireValue(recovery.baseline_tree === binding.baseline_tree, "RECOVERY_BASELINE_TREE_CHANGED");
  requireValue(recovery.registration_identity_sha256 === registration.registration_identity_sha256, "RECOVERY_REGISTRATION_CHANGED");
  requireValue(
    recovery.preauthorization_identity_sha256 === preauthorization.preauthorization_identity_sha256,
    "RECOVERY_PREAUTHORIZATION_CHANGED",
  );
  requireValue(recovery.binding_identity_sha256 === binding.binding_identity_sha256, "RECOVERY_BINDING_CHANGED");
  requireValue(
    recovery.candidate_set_identity_sha256 === candidateSet.candidate_set_identity_sha256,
    "RECOVERY_CANDIDATE_SET_IDENTITY_CHANGED",
  );
  requireValue(recovery.writeset_identity_sha256 === writeset.writeset_identity_sha256, "RECOVERY_WRITESET_IDENTITY_CHANGED");
  requireValue(recovery.iteration === writeset.iteration, "RECOVERY_ITERATION_CHANGED", "EXHAUSTED");
  requireValue(recovery.original_run_id === writeset.run_id, "RECOVERY_ORIGINAL_RUN_CHANGED");
  requireValue(recovery.original_run_id !== recovery.recovery_run_id, "RECOVERY_RUN_ID_REUSED");
  requireValue(recovery.source_relative_path === writeset.writes[0].relative_path, "RECOVERY_SOURCE_PATH_CHANGED");
  requireValue(recovery.pre_iteration_sha256 === writeset.writes[0].before_sha256, "RECOVERY_PREIMAGE_IDENTITY_CHANGED");
  requireValue(
    recovery.expected_replacement_sha256 === writeset.writes[0].approved_replacement_sha256,
    "RECOVERY_REPLACEMENT_IDENTITY_CHANGED",
  );
  requireValue(recovery.preimage_sha256 === recovery.pre_iteration_sha256, "RECOVERY_PREIMAGE_ARTIFACT_CHANGED");
  requireValue(recovery.replacement_sha256 === recovery.expected_replacement_sha256, "RECOVERY_REPLACEMENT_ARTIFACT_CHANGED");
  requireValue(
    recovery.replacement_byte_length === writeset.writes[0].replacement_byte_length,
    "RECOVERY_REPLACEMENT_BYTE_LENGTH_CHANGED",
  );
  for (const relative of [
    recovery.candidate_set_relative_path,
    recovery.writeset_relative_path,
    recovery.preimage_relative_path,
    recovery.replacement_relative_path,
    recovery.recovery_receipt_relative_path,
  ]) normalizeRepositoryRelativePath(relative);
  requireValue(SHA256.test(recovery.candidate_set_file_sha256), "RECOVERY_CANDIDATE_SET_FILE_HASH_INVALID");
  requireValue(SHA256.test(recovery.writeset_file_sha256), "RECOVERY_WRITESET_FILE_HASH_INVALID");
  requireValue(recovery.interruption_point === "PRE_WRITE_CHECKPOINT_FOR_ATOMIC_REPLACEMENT", "RECOVERY_INTERRUPTION_POINT_CHANGED");
  requireValue(recovery.repository_condition === "PREIMAGE_PRESENT_WRITE_NOT_STARTED", "RECOVERY_REPOSITORY_CONDITION_CHANGED");
  requireValue(SHA256.test(recovery.pre_iteration_sha256) && SHA256.test(recovery.expected_replacement_sha256), "RECOVERY_CONTENT_IDENTITY_INVALID");
  requireValue(["COMPLETE_EXACT_APPROVED_REPLACEMENT", "RESTORE_PRE_ITERATION_STATE"].includes(recovery.authorized_disposition), "RECOVERY_SCOPE_BROADENED");
  requireValue(recovery.auto_admitted === false && recovery.auto_rerun === false, "RECOVERY_AUTOMATION_SCOPE_WIDENED");
  requireValue(SHA256.test(recovery.recovery_identity_sha256), "RECOVERY_IDENTITY_INVALID");
  const expected = identityRecord(recovery, "recovery_identity_sha256").recovery_identity_sha256;
  requireValue(expected === recovery.recovery_identity_sha256, "RECOVERY_IDENTITY_MISMATCH");
  return { valid: true };
}

export function validateCommitAuthority(authority, task, candidate, context = {}) {
  exactKeys(candidate, [
    "schema_version",
    "program_id",
    "task_id",
    "registration_identity_sha256",
    "preauthorization_identity_sha256",
    "binding_identity_sha256",
    "verifier_identity_sha256",
    "approved_candidate_set_identity_sha256",
    "writeset_identity_sha256",
    "byte_observation_identity_sha256",
    "approved_replacement_sha256",
    "replacement_byte_length",
    "expected_file_mode",
    "baseline_commit",
    "baseline_tree",
    "iteration",
    "run_id",
    "focused_tests_passed",
    "acceptance_tests_passed",
    "verifier_verdict",
    "changed_paths",
    "unrelated_paths_clean",
    "unexpected_untracked_paths",
    "commit_subject",
    "remote_count",
    "push_performed",
    "amend",
    "use_count",
    "expires_at",
    "commit_authority_identity_sha256",
  ], "COMMIT_AUTHORITY");
  requireValue(candidate.schema_version === "SYNTHETIC_TASK_COMMIT_AUTHORITY_V2", "COMMIT_AUTHORITY_VERSION_CHANGED");
  requireValue(candidate.program_id === authority.program_id, "COMMIT_AUTHORITY_PROGRAM_CHANGED");
  requireValue(candidate.task_id === task.task_id, "COMMIT_AUTHORITY_TASK_CHANGED");
  requireValue(
    SHA256.test(candidate.registration_identity_sha256)
      && SHA256.test(candidate.preauthorization_identity_sha256)
      && SHA256.test(candidate.binding_identity_sha256)
      && SHA256.test(candidate.verifier_identity_sha256)
      && SHA256.test(candidate.approved_candidate_set_identity_sha256)
      && SHA256.test(candidate.writeset_identity_sha256)
      && SHA256.test(candidate.byte_observation_identity_sha256)
      && SHA256.test(candidate.approved_replacement_sha256),
    "COMMIT_AUTHORITY_BINDING_INVALID",
  );
  requireValue(Number.isInteger(candidate.replacement_byte_length) && candidate.replacement_byte_length > 0, "COMMIT_AUTHORITY_BYTE_LENGTH_INVALID");
  requireValue(candidate.expected_file_mode === "100644", "COMMIT_AUTHORITY_FILE_MODE_CHANGED");
  requireValue(candidate.focused_tests_passed === true, "COMMIT_BEFORE_FOCUSED_TESTS");
  requireValue(candidate.acceptance_tests_passed === true, "COMMIT_BEFORE_ACCEPTANCE_TESTS");
  requireValue(candidate.verifier_verdict === "GREEN", "COMMIT_BEFORE_VERIFIER_GREEN");
  requireValue(canonicalJson(candidate.changed_paths) === canonicalJson([...task.authorized_source_paths].sort()), "COMMIT_CHANGED_PATH_SET_INVALID");
  requireValue(candidate.unrelated_paths_clean === true && candidate.unexpected_untracked_paths.length === 0, "COMMIT_UNRELATED_PATHS_DIRTY");
  requireValue(candidate.commit_subject === task.required_commit_subject, "COMMIT_SUBJECT_CHANGED");
  requireValue(candidate.remote_count === 0 && candidate.push_performed === false, "COMMIT_REMOTE_OR_PUSH_PRESENT");
  requireValue(candidate.amend === false && candidate.use_count === 0, "COMMIT_AUTHORITY_REPLAY_OR_AMEND");
  requireValue(new Date(candidate.expires_at) >= new Date(), "COMMIT_AUTHORITY_EXPIRED");
  requireValue(HEX40.test(candidate.baseline_commit), "COMMIT_AUTHORITY_BASELINE_INVALID");
  requireValue(HEX40.test(candidate.baseline_tree), "COMMIT_AUTHORITY_BASELINE_TREE_INVALID");
  requireValue(Number.isInteger(candidate.iteration) && candidate.iteration >= 1 && candidate.iteration <= task.maximum_iterations, "COMMIT_AUTHORITY_ITERATION_INVALID");
  requireValue(typeof candidate.run_id === "string" && candidate.run_id.startsWith(`${task.task_id}-iteration-${candidate.iteration}-`), "COMMIT_AUTHORITY_RUN_INVALID");
  if (context.registration) {
    requireValue(candidate.registration_identity_sha256 === context.registration.registration_identity_sha256, "COMMIT_AUTHORITY_REGISTRATION_CHANGED");
  }
  if (context.binding) {
    requireValue(candidate.binding_identity_sha256 === context.binding.binding_identity_sha256, "COMMIT_AUTHORITY_BINDING_CHANGED");
    requireValue(candidate.baseline_commit === context.binding.baseline_commit, "COMMIT_AUTHORITY_BASELINE_CHANGED");
    requireValue(candidate.baseline_tree === context.binding.baseline_tree, "COMMIT_AUTHORITY_BASELINE_TREE_CHANGED");
  }
  if (context.preauthorization) {
    requireValue(
      candidate.preauthorization_identity_sha256 === context.preauthorization.preauthorization_identity_sha256,
      "COMMIT_AUTHORITY_PREAUTHORIZATION_CHANGED",
    );
  }
  if (context.candidateSet) {
    requireValue(
      candidate.approved_candidate_set_identity_sha256 === context.candidateSet.candidate_set_identity_sha256,
      "COMMIT_AUTHORITY_CANDIDATE_SET_CHANGED",
    );
  }
  if (context.writeset) {
    requireValue(candidate.writeset_identity_sha256 === context.writeset.writeset_identity_sha256, "COMMIT_AUTHORITY_WRITESET_CHANGED");
    requireValue(
      candidate.approved_replacement_sha256 === context.writeset.writes[0].approved_replacement_sha256
        && candidate.replacement_byte_length === context.writeset.writes[0].replacement_byte_length
        && candidate.expected_file_mode === context.writeset.writes[0].expected_file_mode,
      "COMMIT_AUTHORITY_REPLACEMENT_CHANGED",
    );
  }
  if (context.byteObservation) {
    requireValue(
      candidate.byte_observation_identity_sha256 === context.byteObservation.byte_observation_identity_sha256,
      "COMMIT_AUTHORITY_BYTE_EVIDENCE_CHANGED",
    );
  }
  if (context.verifier) {
    requireValue(candidate.verifier_identity_sha256 === context.verifier.verifier_identity_sha256, "COMMIT_AUTHORITY_VERIFIER_CHANGED");
    requireValue(candidate.iteration === context.verifier.iteration && candidate.run_id === context.verifier.run_id, "COMMIT_AUTHORITY_VERIFIER_CONTEXT_CHANGED");
  }
  requireValue(authority.limits.maximum_accepted_task_commits === 3, "COMMIT_LIMIT_CHANGED");
  requireValue(
    identityRecord(candidate, "commit_authority_identity_sha256").commit_authority_identity_sha256
      === candidate.commit_authority_identity_sha256,
    "COMMIT_AUTHORITY_IDENTITY_MISMATCH",
  );
  return { valid: true };
}

function executablePath(authority, executable) {
  requireValue(Object.hasOwn(authority.executables, executable), "COMMAND_EXECUTABLE_PROHIBITED");
  const identity = authority.executables[executable];
  requireValue(canonicalJson(identity) === canonicalJson(PINNED_EXECUTABLES[executable]), "COMMAND_EXECUTABLE_AUTHORITY_CHANGED");
  return assertPinnedExecutable(identity);
}

function commandTokensSafe(tokens) {
  return tokens.every((token) => typeof token === "string"
    && token.length > 0
    && !CONTROL.test(token)
    && !SHELL_META.test(token)
    && !ENV_EXPANSION.test(token)
    && !WILDCARD.test(token)
    && !token.includes(">"));
}

export function validateCommandInvocation(authority, task, invocation) {
  exactKeys(invocation, ["executable", "arguments", "working_directory"], "COMMAND_INVOCATION");
  requireValue(["node", "git"].includes(invocation.executable), "COMMAND_EXECUTABLE_PROHIBITED");
  requireValue(Array.isArray(invocation.arguments) && commandTokensSafe(invocation.arguments), "COMMAND_ARGUMENT_TOKEN_PROHIBITED");
  requireValue(invocation.working_directory === authority.repository.root, "COMMAND_WORKING_DIRECTORY_CHANGED");
  const args = invocation.arguments;
  let templateId = null;
  const equalArgs = (expected) => canonicalJson(args) === canonicalJson(expected);
  if (invocation.executable === "node") {
    if (equalArgs(["--test"])) templateId = "node-test-all";
    else if (args.length === 2 && args[0] === "--test") {
      const validated = validateAllowedPath({
        repositoryRoot: authority.repository.root,
        relativePath: args[1],
        allowlist: task.authorized_test_paths,
        requireExisting: true,
      });
      requireValue(validated.normalized.startsWith("test/") || validated.normalized.startsWith("acceptance/"), "COMMAND_TEST_PATH_CLASS_INVALID");
      templateId = "node-test-one";
    } else if (args.length === 2 && args[0] === "--check") {
      validateAllowedPath({
        repositoryRoot: authority.repository.root,
        relativePath: args[1],
        allowlist: task.authorized_source_paths,
        requireExisting: true,
      });
      requireValue(args[1].endsWith(".mjs"), "COMMAND_CHECK_PATH_CLASS_INVALID");
      templateId = "node-check-one";
    }
  } else {
    const fixed = new Map([
      [canonicalJson(["status", "--short"]), "git-status-short"],
      [canonicalJson(["status", "--porcelain=v2"]), "git-status-porcelain-v2"],
      [canonicalJson(["diff", "--check"]), "git-diff-check"],
      [canonicalJson(["diff", "--binary"]), "git-diff-binary"],
      [canonicalJson(["diff", "--name-only"]), "git-diff-name-only"],
      [canonicalJson(["rev-parse", "HEAD"]), "git-rev-parse-head"],
      [canonicalJson(["rev-parse", "--show-toplevel"]), "git-rev-parse-top"],
      [canonicalJson(["branch", "--show-current"]), "git-branch-current"],
    ]);
    templateId = fixed.get(canonicalJson(args)) ?? null;
    if (!templateId && args.length >= 3 && args[0] === "add" && args[1] === "--") {
      for (const relative of args.slice(2)) {
        validateAllowedPath({
          repositoryRoot: authority.repository.root,
          relativePath: relative,
          allowlist: task.authorized_source_paths,
          requireExisting: true,
        });
      }
      requireValue(new Set(args.slice(2)).size === args.slice(2).length, "COMMAND_ADD_PATH_DUPLICATE");
      templateId = "git-add-task-paths";
    } else if (!templateId && args.length === 3 && args[0] === "commit" && args[1] === "-m") {
      requireValue(args[2] === task.required_commit_subject, "COMMAND_COMMIT_SUBJECT_CHANGED");
      templateId = "git-commit-task-subject";
    }
  }
  requireValue(templateId && authority.command_templates.some((item) => item.template_id === templateId), "COMMAND_TEMPLATE_NOT_ALLOWLISTED");
  const resolvedExecutable = executablePath(authority, invocation.executable);
  const commandIdentity = {
    template_id: templateId,
    executable: invocation.executable,
    executable_path: resolvedExecutable,
    executable_sha256: sha256(readFileSync(resolvedExecutable)),
    arguments: args,
    working_directory: invocation.working_directory,
  };
  return identityRecord(commandIdentity, "command_identity_sha256");
}

export function executeAllowedCommand(authority, task, invocation, { timeout = 60_000 } = {}) {
  const command = validateCommandInvocation(authority, task, invocation);
  const started = performance.now();
  const env = {};
  if (command.template_id === "git-commit-task-subject") {
    Object.assign(env, {
      GIT_AUTHOR_NAME: "TSF Synthetic Pilot",
      GIT_AUTHOR_EMAIL: "tsf-synthetic@example.invalid",
      GIT_COMMITTER_NAME: "TSF Synthetic Pilot",
      GIT_COMMITTER_EMAIL: "tsf-synthetic@example.invalid",
    });
  }
  const result = internalRun(command.executable_path, invocation.arguments, invocation.working_directory, { timeout, env });
  return {
    schema_version: "APPROVED_COMMAND_EXECUTION_V2",
    ...command,
    exit_code: result.exit_code,
    stdout: result.stdout,
    stderr: result.stderr,
    signal: result.signal,
    duration_ms: Math.round((performance.now() - started) * 1000) / 1000,
    shell: false,
    network_used: false,
  };
}

const BASELINE_FIXTURE_FILES = {
  "README.md": `# TSF Synthetic Iteration Pilot V2

This repository is disposable, local-only, and test-only.
It has no remote and is governed by tsf_synthetic_workspace_iteration_v2.
`,
  "package.json": `${JSON.stringify({
    name: "tsf-synthetic-iteration-pilot-v2",
    private: true,
    type: "module",
    scripts: { test: "node --test" },
  }, null, 2)}\n`,
  "PILOT_CONTRACT.json": `${JSON.stringify({
    schema_version: "TSF_SYNTHETIC_PILOT_CONTRACT_V2",
    program_id: "tsf-v1-synthetic-iteration-authority-v2-20260729",
    action_id: "tsf_synthetic_workspace_iteration_v2",
    repository: "C:\\TSF_SYNTHETIC_ITERATION_V2\\fixture-repo",
    branch: "pilot/tsf-synthetic-iteration-v2-20260729",
    network: "PROHIBITED",
    remote_git: "PROHIBITED",
    maximum_tasks: 3,
    maximum_iterations_per_task: 3,
  }, null, 2)}\n`,
  ".gitignore": "# No generated mission or evidence files may be written inside this fixture.\n",
  "src/path-containment.mjs": `import path from "node:path";

export function isPathContained(root, candidate) {
  const resolvedRoot = path.resolve(root);
  return path.resolve(root, candidate).startsWith(resolvedRoot);
}
`,
  "src/job-admission.mjs": `export function admitJob(state, request) {
  const job = {
    job_id: \`job-\${state.jobs.length + 1}\`,
    idempotency_key: request.idempotency_key,
    payload: request.payload,
  };
  state.jobs.push(job);
  return { created: true, reused: false, job };
}
`,
  "src/result-parser.mjs": `export function parseResult(text) {
  return JSON.parse(text);
}
`,
  "test/path-containment.test.mjs": `import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { isPathContained } from "../src/path-containment.mjs";

test("accepts a direct child", () => {
  const root = path.join(process.cwd(), "fixture-root");
  assert.equal(isPathContained(root, "src/file.mjs"), true);
});

test("rejects parent traversal", () => {
  const root = path.join(process.cwd(), "fixture-root");
  assert.equal(isPathContained(root, "../escape.mjs"), false);
});

test("rejects a sibling with the same string prefix", () => {
  const root = path.join(process.cwd(), "fixture-root");
  assert.equal(isPathContained(root, \`\${root}-escape/file.mjs\`), false);
});
`,
  "acceptance/path-containment.acceptance.test.mjs": `import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { isPathContained } from "../src/path-containment.mjs";

test("mixed separators cannot traverse above the root", () => {
  const root = path.join(process.cwd(), "fixture-root");
  assert.equal(isPathContained(root, "safe\\\\..\\\\..\\\\escape.mjs"), false);
});

test("encoded traversal fails closed", () => {
  const root = path.join(process.cwd(), "fixture-root");
  assert.equal(isPathContained(root, "%2e%2e/escape.mjs"), false);
});

test("UNC and device paths fail closed", () => {
  const root = path.join(process.cwd(), "fixture-root");
  assert.equal(isPathContained(root, "\\\\\\\\server\\\\share\\\\file.mjs"), false);
  assert.equal(isPathContained(root, "\\\\\\\\?\\\\C:\\\\escape.mjs"), false);
});
`,
  "test/job-admission.test.mjs": `import test from "node:test";
import assert from "node:assert/strict";
import { admitJob } from "../src/job-admission.mjs";

test("an exact duplicate request reuses the existing job", () => {
  const state = { jobs: [] };
  const first = admitJob(state, { idempotency_key: "idem-1", payload: { value: 7 } });
  const replay = admitJob(state, { idempotency_key: "idem-1", payload: { value: 7 } });
  assert.equal(first.created, true);
  assert.equal(replay.created, false);
  assert.equal(replay.reused, true);
  assert.equal(replay.job.job_id, first.job.job_id);
  assert.equal(state.jobs.length, 1);
});
`,
  "acceptance/job-admission.acceptance.test.mjs": `import test from "node:test";
import assert from "node:assert/strict";
import { admitJob } from "../src/job-admission.mjs";

test("changed content under an existing identity fails closed", () => {
  const state = { jobs: [] };
  const first = admitJob(state, { idempotency_key: "idem-2", payload: { value: 7, nested: { ok: true } } });
  assert.throws(
    () => admitJob(state, { idempotency_key: "idem-2", payload: { value: 8, nested: { ok: true } } }),
    /IDEMPOTENCY_IDENTITY_CONFLICT/,
  );
  assert.equal(state.jobs.length, 1);
  assert.equal(state.jobs[0].job_id, first.job.job_id);
});

test("canonical key order does not change replay identity", () => {
  const state = { jobs: [] };
  const first = admitJob(state, { idempotency_key: "idem-3", payload: { alpha: 1, beta: 2 } });
  const replay = admitJob(state, { idempotency_key: "idem-3", payload: { beta: 2, alpha: 1 } });
  assert.equal(replay.reused, true);
  assert.equal(replay.job.job_id, first.job.job_id);
});
`,
  "test/result-parser.test.mjs": `import test from "node:test";
import assert from "node:assert/strict";
import { parseResult } from "../src/result-parser.mjs";

const expected = {
  program_id: "tsf-v1-synthetic-iteration-authority-v2-20260729",
  task_id: "synthetic-result-identity-v2",
  run_id: "run-result-1",
};

test("accepts a valid structured result", () => {
  const parsed = parseResult(JSON.stringify({ ...expected, status: "GREEN", result: { accepted: true } }), expected);
  assert.equal(parsed.status, "GREEN");
});

test("rejects an unknown program identity", () => {
  assert.throws(
    () => parseResult(JSON.stringify({ ...expected, program_id: "unknown", status: "GREEN", result: {} }), expected),
    /RESULT_IDENTITY_MISMATCH/,
  );
});

test("rejects a missing required identity", () => {
  const { task_id, ...missing } = expected;
  assert.throws(
    () => parseResult(JSON.stringify({ ...missing, status: "GREEN", result: {} }), expected),
    /RESULT_IDENTITY_MISMATCH/,
  );
});
`,
  "acceptance/result-parser.acceptance.test.mjs": `import test from "node:test";
import assert from "node:assert/strict";
import { parseResult } from "../src/result-parser.mjs";

const expected = {
  program_id: "tsf-v1-synthetic-iteration-authority-v2-20260729",
  task_id: "synthetic-result-identity-v2",
  run_id: "run-result-2",
};

test("rejects duplicate identity members even when the last value matches", () => {
  const text = \`{"program_id":"substitution","program_id":"\${expected.program_id}","task_id":"\${expected.task_id}","run_id":"\${expected.run_id}","status":"GREEN","result":{}}\`;
  assert.throws(() => parseResult(text, expected), /DUPLICATE_RESULT_IDENTITY_MEMBER/);
});

test("rejects unknown identity substitution and malformed JSON", () => {
  assert.throws(
    () => parseResult(JSON.stringify({ ...expected, run_id: "substituted", status: "GREEN", result: {} }), expected),
    /RESULT_IDENTITY_MISMATCH/,
  );
  assert.throws(() => parseResult("{", expected));
});

test("rejects an unrecognized identity-shaped member", () => {
  const text = JSON.stringify({ ...expected, mission_id: "unknown", status: "GREEN", result: {} });
  assert.throws(() => parseResult(text, expected), /UNKNOWN_RESULT_IDENTITY_MEMBER/);
});
`,
};

const BUILDER_CANDIDATES = {
  "synthetic-path-containment-v2": [{
    diagnosis: "String-prefix containment does not establish a path-segment boundary and does not normalize mixed separators.",
    content: `import path from "node:path";

export function isPathContained(root, candidate) {
  if (typeof root !== "string" || typeof candidate !== "string" || !root || !candidate) return false;
  if (candidate.includes("%") || /[\\x00-\\x1f\\x7f]/.test(candidate)) return false;
  if (path.win32.isAbsolute(candidate) || path.posix.isAbsolute(candidate) || /^[\\\\/]{2}/.test(candidate)) return false;
  const normalized = candidate.replaceAll("\\\\", "/");
  const parts = normalized.split("/");
  if (parts.some((part) => !part || part === "." || part === "..")) return false;
  const resolvedRoot = path.resolve(root);
  const resolvedCandidate = path.resolve(resolvedRoot, ...parts);
  const relative = path.relative(resolvedRoot, resolvedCandidate);
  return relative === "" || (relative !== ".." && !relative.startsWith(\`..\${path.sep}\`) && !path.isAbsolute(relative));
}
`,
  }],
  "synthetic-idempotency-replay-v2": [
    {
      diagnosis: "The baseline creates a new job for every request and ignores the idempotency key.",
      content: `export function admitJob(state, request) {
  const existing = state.jobs.find((job) => job.idempotency_key === request.idempotency_key);
  if (existing) return { created: false, reused: true, job: existing };
  const job = {
    job_id: \`job-\${state.jobs.length + 1}\`,
    idempotency_key: request.idempotency_key,
    payload: request.payload,
  };
  state.jobs.push(job);
  return { created: true, reused: false, job };
}
`,
    },
    {
      diagnosis: "The first correction keyed only on idempotency identity and failed to bind the original request content.",
      content: `function stable(value) {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, stable(value[key])]));
  }
  return value;
}

function contentIdentity(payload) {
  return JSON.stringify(stable(payload));
}

export function admitJob(state, request) {
  if (!request || typeof request.idempotency_key !== "string" || !request.idempotency_key) {
    throw new Error("IDEMPOTENCY_IDENTITY_INVALID");
  }
  const requestIdentity = contentIdentity(request.payload);
  const existing = state.jobs.find((job) => job.idempotency_key === request.idempotency_key);
  if (existing) {
    if (existing.request_identity !== requestIdentity) throw new Error("IDEMPOTENCY_IDENTITY_CONFLICT");
    return { created: false, reused: true, job: existing };
  }
  const job = {
    job_id: \`job-\${state.jobs.length + 1}\`,
    idempotency_key: request.idempotency_key,
    request_identity: requestIdentity,
    payload: request.payload,
  };
  state.jobs.push(job);
  return { created: true, reused: false, job };
}
`,
    },
  ],
  "synthetic-result-identity-v2": [
    {
      diagnosis: "The baseline accepts parsed JSON without exact result-identity validation.",
      content: `const REQUIRED = ["program_id", "task_id", "run_id"];

export function parseResult(text, expected) {
  const value = JSON.parse(text);
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("RESULT_IDENTITY_MISMATCH");
  for (const field of REQUIRED) {
    if (typeof value[field] !== "string" || value[field] !== expected[field]) throw new Error("RESULT_IDENTITY_MISMATCH");
  }
  if (Object.keys(value).some((key) => key.endsWith("_id") && !REQUIRED.includes(key))) {
    throw new Error("UNKNOWN_RESULT_IDENTITY_MEMBER");
  }
  if (value.status !== "GREEN" || !Object.hasOwn(value, "result")) throw new Error("RESULT_STRUCTURE_INVALID");
  return value;
}
`,
    },
    {
      diagnosis: "JSON.parse retained only the last duplicate member, so the first correction could not detect duplicate identity substitution.",
      content: `const REQUIRED = ["program_id", "task_id", "run_id"];

function topLevelKeys(text) {
  const keys = [];
  let depth = 0;
  let inString = false;
  let escaped = false;
  let stringStart = -1;
  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    if (inString) {
      if (escaped) escaped = false;
      else if (char === "\\\\") escaped = true;
      else if (char === '"') {
        inString = false;
        if (depth === 1) {
          let cursor = index + 1;
          while (/\\s/.test(text[cursor] ?? "")) cursor += 1;
          if (text[cursor] === ":") keys.push(JSON.parse(text.slice(stringStart, index + 1)));
        }
      }
      continue;
    }
    if (char === '"') {
      inString = true;
      stringStart = index;
    } else if (char === "{" || char === "[") depth += 1;
    else if (char === "}" || char === "]") depth -= 1;
  }
  return keys;
}

export function parseResult(text, expected) {
  if (typeof text !== "string" || typeof expected !== "object" || !expected) throw new Error("RESULT_IDENTITY_MISMATCH");
  const keys = topLevelKeys(text);
  for (const field of REQUIRED) {
    const occurrences = keys.filter((key) => key === field).length;
    if (occurrences === 0) throw new Error("RESULT_IDENTITY_MISMATCH");
    if (occurrences > 1) throw new Error("DUPLICATE_RESULT_IDENTITY_MEMBER");
  }
  if (keys.some((key) => key.endsWith("_id") && !REQUIRED.includes(key))) {
    throw new Error("UNKNOWN_RESULT_IDENTITY_MEMBER");
  }
  const value = JSON.parse(text);
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new Error("RESULT_IDENTITY_MISMATCH");
  for (const field of REQUIRED) {
    if (typeof value[field] !== "string" || value[field] !== expected[field]) throw new Error("RESULT_IDENTITY_MISMATCH");
  }
  if (value.status !== "GREEN" || !Object.hasOwn(value, "result")) throw new Error("RESULT_STRUCTURE_INVALID");
  return value;
}
`,
    },
  ],
};

export function getBuilderCandidateContent(taskId, iteration) {
  const candidates = BUILDER_CANDIDATES[taskId];
  requireValue(candidates && Number.isInteger(iteration) && iteration >= 1, "BUILDER_CANDIDATE_UNKNOWN");
  requireValue(iteration <= candidates.length, "BUILDER_CANDIDATE_ITERATION_UNAVAILABLE");
  return candidates[iteration - 1].content;
}

function assertSetupRootSafe(root) {
  requireValue(root === FIXTURE_ROOT, "SETUP_ROOT_CHANGED");
  const parent = path.dirname(root);
  if (!existsSync(parent)) mkdirSync(parent, { recursive: true });
  requireValue(!lstatSync(parent).isSymbolicLink(), "SETUP_PARENT_REPARSE_POINT");
  let cursor = parent;
  while (path.dirname(cursor) !== cursor) {
    requireValue(!existsSync(path.join(cursor, ".git")), "SETUP_PARENT_GIT_CAPTURE");
    cursor = path.dirname(cursor);
  }
  if (existsSync(root)) {
    requireValue(statSync(root).isDirectory() && readdirSync(root).length === 0, "SETUP_ROOT_NOT_EXACT_EMPTY");
    requireValue(!lstatSync(root).isSymbolicLink(), "SETUP_ROOT_REPARSE_POINT");
  } else {
    mkdirSync(root);
  }
}

function writeExactFixtureFiles(authority) {
  requireValue(
    canonicalJson(Object.keys(BASELINE_FIXTURE_FILES).sort()) === canonicalJson([...authority.repository.allowed_paths].sort()),
    "SETUP_FILE_TEMPLATE_SET_CHANGED",
  );
  for (const relative of authority.repository.allowed_paths) {
    const normalized = normalizeRepositoryRelativePath(relative);
    const full = path.join(authority.repository.root, ...normalized.split("/"));
    mkdirSync(path.dirname(full), { recursive: true });
    writeFileSync(full, BASELINE_FIXTURE_FILES[relative], { encoding: "utf8", flag: "wx" });
  }
}

export function seedSyntheticFixture(authority, { now = new Date() } = {}) {
  validateAuthority(authority);
  requireValue(now <= new Date(authority.expires_at), "SETUP_AUTHORITY_EXPIRED", "TIM_REQUIRED");
  assertSetupRootSafe(authority.repository.root);
  writeExactFixtureFiles(authority);
  const root = authority.repository.root;
  requireInternalSuccess(gitInternal(root, ["init", `--initial-branch=${authority.repository.branch}`]), "SETUP_GIT_INIT_FAILED");
  requireInternalSuccess(gitInternal(root, ["add", "--", ...authority.repository.allowed_paths]), "SETUP_GIT_ADD_FAILED");
  const env = {
    GIT_AUTHOR_NAME: "TSF Synthetic Pilot",
    GIT_AUTHOR_EMAIL: "tsf-synthetic@example.invalid",
    GIT_COMMITTER_NAME: "TSF Synthetic Pilot",
    GIT_COMMITTER_EMAIL: "tsf-synthetic@example.invalid",
  };
  requireInternalSuccess(gitInternal(root, ["commit", "-m", authority.repository.baseline_subject], { env }), "SETUP_BASELINE_COMMIT_FAILED");
  const registration = inspectFixtureRegistration(authority, { now });
  const status = requireInternalSuccess(gitInternal(root, ["status", "--porcelain=v2"]), "SETUP_STATUS_FAILED");
  requireValue(status === "", "SETUP_REPOSITORY_NOT_CLEAN");
  return registration;
}

function writeExclusiveDurable(fullPath, bytes) {
  mkdirSync(path.dirname(fullPath), { recursive: true });
  const descriptor = openSync(fullPath, "wx");
  try {
    writeSync(descriptor, bytes);
    fsyncSync(descriptor);
  } finally {
    closeSync(descriptor);
  }
}

class EvidenceStore {
  constructor(root) {
    requireValue(!existsSync(root), "EVIDENCE_RUN_ALREADY_EXISTS");
    mkdirSync(root, { recursive: true });
    this.root = root;
    this.records = [];
  }

  write(relative, value) {
    const normalized = normalizeRepositoryRelativePath(relative);
    const full = path.join(this.root, ...normalized.split("/"));
    requireValue(pathInside(full, this.root), "EVIDENCE_PATH_ESCAPE");
    requireValue(!existsSync(full), "IMMUTABLE_EVIDENCE_REWRITE");
    const bytes = Buffer.isBuffer(value)
      ? value
      : Buffer.from(typeof value === "string" ? value : `${JSON.stringify(value, null, 2)}\n`, "utf8");
    writeExclusiveDurable(full, bytes);
    const record = { path: normalized, sha256: sha256(bytes), bytes: bytes.length };
    this.records.push(record);
    return record;
  }

  captureExisting(relative) {
    const normalized = normalizeRepositoryRelativePath(relative);
    requireValue(!this.records.some((record) => record.path === normalized), "EVIDENCE_RECORD_ALREADY_CAPTURED");
    const full = path.join(this.root, ...normalized.split("/"));
    requireValue(pathInside(full, this.root) && existsSync(full) && statSync(full).isFile(), "EVIDENCE_CAPTURE_TARGET_INVALID");
    requireValue(!lstatSync(full).isSymbolicLink(), "EVIDENCE_CAPTURE_REPARSE_POINT");
    const bytes = readFileSync(full);
    const record = { path: normalized, sha256: sha256(bytes), bytes: bytes.length };
    this.records.push(record);
    return record;
  }

  finalize(summary) {
    const manifest = {
      schema_version: "TSF_SYNTHETIC_ITERATION_EVIDENCE_MANIFEST_V2",
      evidence_root: this.root,
      files: [...this.records].sort((a, b) => a.path.localeCompare(b.path)),
      summary,
    };
    const manifestRecord = this.write("MANIFEST.json", manifest);
    return { ...manifestRecord, manifest };
  }
}

function command(authority, task, executable, args) {
  return executeAllowedCommand(authority, task, {
    executable,
    arguments: args,
    working_directory: authority.repository.root,
  });
}

function currentGitFacts(authority, task) {
  const head = command(authority, task, "git", ["rev-parse", "HEAD"]);
  const top = command(authority, task, "git", ["rev-parse", "--show-toplevel"]);
  const branch = command(authority, task, "git", ["branch", "--show-current"]);
  const status = command(authority, task, "git", ["status", "--porcelain=v2"]);
  requireValue(head.exit_code === 0 && top.exit_code === 0 && branch.exit_code === 0 && status.exit_code === 0, "GIT_FACT_COMMAND_FAILED");
  requireValue(sameWindowsPath(top.stdout.trim(), authority.repository.root), "GIT_TOP_CHANGED");
  requireValue(branch.stdout.trim() === authority.repository.branch, "GIT_BRANCH_CHANGED");
  requireValue(requireInternalSuccess(gitInternal(authority.repository.root, ["remote"]), "GIT_REMOTE_CHECK_FAILED") === "", "SYNTHETIC_REMOTE_PRESENT");
  return {
    head: head.stdout.trim(),
    top: top.stdout.trim(),
    branch: branch.stdout.trim(),
    status_porcelain_v2: status.stdout,
    remote_count: 0,
    commands: [head, top, branch, status],
  };
}

function inspectTsfCandidate({ allowDirty = false } = {}) {
  const top = requireInternalSuccess(gitInternal(TSF_ROOT, ["rev-parse", "--show-toplevel"]), "TSF_CANDIDATE_TOP_UNAVAILABLE");
  const head = requireInternalSuccess(gitInternal(TSF_ROOT, ["rev-parse", "HEAD"]), "TSF_CANDIDATE_HEAD_UNAVAILABLE");
  const tree = requireInternalSuccess(gitInternal(TSF_ROOT, ["rev-parse", "HEAD^{tree}"]), "TSF_CANDIDATE_TREE_UNAVAILABLE");
  const parent = requireInternalSuccess(gitInternal(TSF_ROOT, ["rev-parse", "HEAD^"]), "TSF_CANDIDATE_PARENT_UNAVAILABLE");
  const subject = requireInternalSuccess(gitInternal(TSF_ROOT, ["show", "-s", "--format=%s", "HEAD"]), "TSF_CANDIDATE_SUBJECT_UNAVAILABLE");
  const branch = requireInternalSuccess(gitInternal(TSF_ROOT, ["branch", "--show-current"]), "TSF_CANDIDATE_BRANCH_UNAVAILABLE");
  const status = requireInternalSuccess(gitInternal(TSF_ROOT, ["status", "--porcelain=v2"]), "TSF_CANDIDATE_STATUS_UNAVAILABLE");
  requireValue(sameWindowsPath(top, TSF_ROOT), "TSF_CANDIDATE_TOP_MISMATCH");
  requireValue(HEX40.test(head) && HEX40.test(tree) && HEX40.test(parent), "TSF_CANDIDATE_IDENTITY_INVALID");
  requireValue(subject === "feat: add governed synthetic coding iterations", "TSF_CANDIDATE_SUBJECT_CHANGED");
  requireValue(allowDirty || status === "", "TSF_CANDIDATE_NOT_CLEAN");
  return {
    repository_root: TSF_ROOT,
    git_top_level: top,
    head,
    tree,
    parent,
    subject,
    branch: branch || null,
    detached: branch === "",
    clean: status === "",
    working_tree_status: status ? status.split(/\r?\n/).filter(Boolean) : [],
  };
}

export function assertApprovedCandidateBytes(candidateSet, writeset, bytes, code = "APPROVED_CANDIDATE_BYTES_MISMATCH") {
  requireValue(
    candidateSet?.candidate_set_identity_sha256 === writeset?.approved_candidate_set_identity_sha256,
    "APPROVED_CANDIDATE_SET_EVIDENCE_MISSING",
  );
  const buffer = Buffer.isBuffer(bytes) ? bytes : Buffer.from(bytes, "utf8");
  const write = writeset.writes[0];
  const member = candidateSet.candidates.find(
    (candidate) => candidate.sha256 === write.approved_replacement_sha256,
  );
  requireValue(member, "REPLACEMENT_SHA_NOT_IN_APPROVED_BUILDER_CANDIDATE_SET");
  requireValue(sha256(buffer) === member.sha256, code);
  requireValue(buffer.length === member.byte_length, `${code}_LENGTH`);
  return { sha256: member.sha256, byte_length: member.byte_length };
}

function assertApprovedFileBoundary(fullPath, candidateSet, writeset, code) {
  requireValue(existsSync(fullPath) && statSync(fullPath).isFile(), `${code}_FILE_ABSENT`);
  return assertApprovedCandidateBytes(candidateSet, writeset, readFileSync(fullPath), code);
}

function applyCanonicalApprovedAtomicReplacement({
  authority,
  registration,
  task,
  preauthorization,
  binding,
  candidateSet,
  writeset,
  content,
  evidenceStore,
}) {
  const write = writeset.writes[0];
  const target = path.join(writeset.repository_root, ...write.relative_path.split("/"));
  const bytes = Buffer.isBuffer(content) ? content : Buffer.from(content, "utf8");
  const observedBeforeSha256 = sha256(readFileSync(target));
  validateApprovedWriteset(
    authority,
    registration,
    task,
    preauthorization,
    binding,
    candidateSet,
    writeset,
    { replacementBytes: bytes, observedBeforeSha256 },
  );
  requireValue(observedBeforeSha256 === write.before_sha256, "WRITESET_STALE_BEFORE_WRITE");
  assertApprovedCandidateBytes(candidateSet, writeset, bytes, "WRITESET_CONTENT_CHANGED");
  const tempRelative = `temporary/${writeset.run_id}-${path.basename(write.relative_path)}.tmp`;
  const tempFull = path.join(evidenceStore.root, ...tempRelative.split("/"));
  writeExclusiveDurable(tempFull, bytes);
  const temporary = assertApprovedFileBoundary(tempFull, candidateSet, writeset, "WRITESET_TEMP_HASH_MISMATCH");
  renameSync(tempFull, target);
  const written = assertApprovedFileBoundary(target, candidateSet, writeset, "WRITESET_REPLACEMENT_HASH_MISMATCH");
  return {
    operation: "ATOMIC_REPLACE",
    target: write.relative_path,
    temporary_file: tempFull,
    temporary_file_inside_repository: false,
    candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    writeset_identity_sha256: writeset.writeset_identity_sha256,
    approved_replacement_sha256: write.approved_replacement_sha256,
    replacement_byte_length: write.replacement_byte_length,
    candidate_artifact_sha256: sha256(bytes),
    candidate_artifact_byte_length: bytes.length,
    before_file_sha256: observedBeforeSha256,
    temporary_file_sha256: temporary.sha256,
    post_write_file_sha256: written.sha256,
  };
}

function commandWithCandidateBoundary(authority, task, executable, args, candidateSet, writeset) {
  const target = path.join(authority.repository.root, ...writeset.writes[0].relative_path.split("/"));
  const before = assertApprovedFileBoundary(target, candidateSet, writeset, "PRE_TEST_APPROVED_BYTES_CHANGED");
  const receipt = command(authority, task, executable, args);
  const after = assertApprovedFileBoundary(target, candidateSet, writeset, "POST_TEST_APPROVED_BYTES_CHANGED");
  return {
    ...receipt,
    approved_candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    writeset_identity_sha256: writeset.writeset_identity_sha256,
    approved_replacement_sha256: writeset.writes[0].approved_replacement_sha256,
    approved_bytes_before_command_sha256: before.sha256,
    approved_bytes_after_command_sha256: after.sha256,
  };
}

function testReceipt(authority, task, relative, candidateSet = null, writeset = null) {
  if (candidateSet && writeset) {
    return commandWithCandidateBoundary(authority, task, "node", ["--test", relative], candidateSet, writeset);
  }
  return command(authority, task, "node", ["--test", relative]);
}

function runIndependentVerifier(
  authority,
  registration,
  task,
  preauthorization,
  binding,
  candidateSet,
  writeset,
  byteObservation,
  iteration,
  runId,
) {
  validateApprovedWriteset(authority, registration, task, preauthorization, binding, candidateSet, writeset);
  requireValue(
    byteObservation?.candidate_set_identity_sha256 === candidateSet.candidate_set_identity_sha256
      && byteObservation?.writeset_identity_sha256 === writeset.writeset_identity_sha256,
    "VERIFIER_BYTE_EVIDENCE_MISSING",
  );
  const syntax = commandWithCandidateBoundary(
    authority,
    task,
    "node",
    ["--check", task.authorized_source_paths[0]],
    candidateSet,
    writeset,
  );
  const focused = task.focused_tests.map(
    (relative) => testReceipt(authority, task, relative, candidateSet, writeset),
  );
  const acceptance = task.acceptance_tests.map(
    (relative) => testReceipt(authority, task, relative, candidateSet, writeset),
  );
  const diffCheck = command(authority, task, "git", ["diff", "--check"]);
  const diffNames = command(authority, task, "git", ["diff", "--name-only"]);
  const status = command(authority, task, "git", ["status", "--porcelain=v2"]);
  const changedPaths = diffNames.stdout.trim().split(/\r?\n/).filter(Boolean).sort();
  const requiredChangedPaths = [...task.authorized_source_paths].sort();
  const statusLines = status.stdout.split(/\r?\n/).filter(Boolean);
  const statusPaths = statusLines.map((line) => line.split(" ").at(-1)).sort();
  const statusIsExactUnstagedTaskChange = statusLines.length === requiredChangedPaths.length
    && statusLines.every((line) => line.startsWith("1 .M "))
    && canonicalJson(statusPaths) === canonicalJson(requiredChangedPaths);
  const passed = [
    syntax,
    ...focused,
    ...acceptance,
    diffCheck,
    diffNames,
    status,
  ].every((receipt) => receipt.exit_code === 0)
    && canonicalJson(changedPaths) === canonicalJson(requiredChangedPaths)
    && statusIsExactUnstagedTaskChange;
  const base = {
    schema_version: "TSF_SYNTHETIC_ITERATION_VERIFIER_V2",
    phase: "PRECOMMIT_EXECUTION",
    program_id: authority.program_id,
    verifier_id: `synthetic-verifier-${randomUUID()}`,
    verifier_role: "canonical-kernel-postrun-extension",
    independence: "SEPARATE_ROLE",
    task_id: task.task_id,
    registration_identity_sha256: registration.registration_identity_sha256,
    preauthorization_identity_sha256: preauthorization.preauthorization_identity_sha256,
    binding_identity_sha256: binding.binding_identity_sha256,
    approved_candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    writeset_identity_sha256: writeset.writeset_identity_sha256,
    baseline_commit: binding.baseline_commit,
    baseline_tree: binding.baseline_tree,
    iteration,
    run_id: runId,
    syntax,
    focused,
    acceptance,
    diff_check: diffCheck,
    changed_paths: changedPaths,
    required_changed_paths: requiredChangedPaths,
    status_porcelain_v2: status,
    approved_replacement_sha256: writeset.writes[0].approved_replacement_sha256,
    candidate_byte_evidence: structuredClone(byteObservation),
    verdict: passed ? "GREEN" : "RED",
    verified: passed,
  };
  return identityRecord(base, "verifier_identity_sha256");
}

function createCommitAuthority(
  authority,
  registration,
  task,
  preauthorization,
  binding,
  candidateSet,
  writeset,
  byteObservation,
  verifier,
) {
  validateApprovedWriteset(authority, registration, task, preauthorization, binding, candidateSet, writeset);
  requireValue(
    byteObservation?.byte_observation_identity_sha256
      && identityRecord(byteObservation, "byte_observation_identity_sha256").byte_observation_identity_sha256
        === byteObservation.byte_observation_identity_sha256,
    "COMMIT_AUTHORITY_BYTE_EVIDENCE_INVALID",
  );
  const target = path.join(authority.repository.root, ...writeset.writes[0].relative_path.split("/"));
  assertApprovedFileBoundary(target, candidateSet, writeset, "PRE_COMMIT_AUTHORITY_APPROVED_BYTES_CHANGED");
  const facts = currentGitFacts(authority, task);
  const diffNames = command(authority, task, "git", ["diff", "--name-only"]);
  const changedPaths = diffNames.stdout.trim().split(/\r?\n/).filter(Boolean).sort();
  const base = {
    schema_version: "SYNTHETIC_TASK_COMMIT_AUTHORITY_V2",
    program_id: authority.program_id,
    task_id: task.task_id,
    registration_identity_sha256: registration.registration_identity_sha256,
    preauthorization_identity_sha256: preauthorization.preauthorization_identity_sha256,
    binding_identity_sha256: binding.binding_identity_sha256,
    verifier_identity_sha256: verifier.verifier_identity_sha256,
    approved_candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    writeset_identity_sha256: writeset.writeset_identity_sha256,
    byte_observation_identity_sha256: byteObservation.byte_observation_identity_sha256,
    approved_replacement_sha256: writeset.writes[0].approved_replacement_sha256,
    replacement_byte_length: writeset.writes[0].replacement_byte_length,
    expected_file_mode: writeset.writes[0].expected_file_mode,
    baseline_commit: binding.baseline_commit,
    baseline_tree: binding.baseline_tree,
    iteration: verifier.iteration,
    run_id: verifier.run_id,
    focused_tests_passed: verifier.focused.every((receipt) => receipt.exit_code === 0),
    acceptance_tests_passed: verifier.acceptance.every((receipt) => receipt.exit_code === 0),
    verifier_verdict: verifier.verdict,
    changed_paths: changedPaths,
    unrelated_paths_clean: canonicalJson(changedPaths) === canonicalJson([...task.authorized_source_paths].sort()),
    unexpected_untracked_paths: facts.status_porcelain_v2.split(/\r?\n/).filter((line) => line.startsWith("? ")),
    commit_subject: task.required_commit_subject,
    remote_count: facts.remote_count,
    push_performed: false,
    amend: false,
    use_count: 0,
    expires_at: authority.expires_at,
  };
  const record = identityRecord(base, "commit_authority_identity_sha256");
  validateCommitAuthority(authority, task, record, {
    registration,
    preauthorization,
    binding,
    candidateSet,
    writeset,
    byteObservation,
    verifier,
  });
  return record;
}

function gitBlobProof(repositoryRoot, spec, relativePath, modeArguments, phase) {
  const blob = gitInternalBytes(repositoryRoot, ["show", spec]);
  requireValue(blob.exit_code === 0, `${phase}_BLOB_READ_FAILED`, "BLOCKED", { stderr: blob.stderr });
  const objectId = requireInternalSuccess(
    gitInternal(repositoryRoot, ["rev-parse", spec]),
    `${phase}_BLOB_IDENTITY_FAILED`,
  );
  const modeText = requireInternalSuccess(
    gitInternal(repositoryRoot, modeArguments),
    `${phase}_MODE_INSPECTION_FAILED`,
  );
  const modeMatch = modeText.match(/^(\d{6})\s+[a-z]+\s+[0-9a-f]{40}\t|^(\d{6})\s+[0-9a-f]{40}\s+\d+\t/);
  requireValue(modeMatch, `${phase}_MODE_INVALID`, "BLOCKED", { modeText, relativePath });
  return {
    phase,
    relative_path: relativePath,
    git_object_id: objectId,
    git_mode: modeMatch[1] ?? modeMatch[2],
    content_sha256: sha256(blob.stdout),
    byte_length: blob.stdout.length,
  };
}

function commitVerifiedTask(
  authority,
  registration,
  task,
  preauthorization,
  binding,
  candidateSet,
  writeset,
  byteObservation,
  verifier,
  commitAuthority,
) {
  validateCommitAuthority(authority, task, commitAuthority, {
    registration,
    preauthorization,
    binding,
    candidateSet,
    writeset,
    byteObservation,
    verifier,
  });
  const write = writeset.writes[0];
  const target = path.join(authority.repository.root, ...write.relative_path.split("/"));
  const beforeStage = assertApprovedFileBoundary(
    target,
    candidateSet,
    writeset,
    "PRE_STAGE_APPROVED_BYTES_CHANGED",
  );
  const preCommitHead = requireInternalSuccess(gitInternal(authority.repository.root, ["rev-parse", "HEAD"]), "TASK_PRECOMMIT_HEAD_INVALID");
  const add = command(authority, task, "git", ["add", "--", ...task.authorized_source_paths]);
  requireValue(add.exit_code === 0, "TASK_GIT_ADD_FAILED");
  const staged = gitInternal(authority.repository.root, ["diff", "--cached", "--name-only"]);
  requireValue(staged.exit_code === 0, "TASK_STAGED_PATH_INSPECTION_FAILED");
  const stagedPaths = staged.stdout.trim().split(/\r?\n/).filter(Boolean).sort();
  requireValue(canonicalJson(stagedPaths) === canonicalJson([...task.authorized_source_paths].sort()), "TASK_EXTRA_STAGED_PATH");
  const stagedBlob = gitBlobProof(
    authority.repository.root,
    `:${write.relative_path}`,
    write.relative_path,
    ["ls-files", "-s", "--", write.relative_path],
    "STAGED",
  );
  requireValue(
    stagedBlob.content_sha256 === write.approved_replacement_sha256
      && stagedBlob.byte_length === write.replacement_byte_length,
    "STAGED_BLOB_APPROVED_CANDIDATE_MISMATCH",
  );
  requireValue(stagedBlob.git_mode === write.expected_file_mode, "STAGED_BLOB_MODE_MISMATCH");
  const beforeCommit = assertApprovedFileBoundary(
    target,
    candidateSet,
    writeset,
    "PRE_COMMIT_APPROVED_BYTES_CHANGED",
  );
  const commit = command(authority, task, "git", ["commit", "-m", task.required_commit_subject]);
  requireValue(commit.exit_code === 0, "TASK_COMMIT_FAILED", "BLOCKED", { stderr: commit.stderr });
  const head = command(authority, task, "git", ["rev-parse", "HEAD"]);
  const status = command(authority, task, "git", ["status", "--porcelain=v2"]);
  requireValue(head.exit_code === 0 && HEX40.test(head.stdout.trim()), "TASK_COMMIT_HEAD_INVALID");
  requireValue(status.exit_code === 0 && status.stdout.trim() === "", "TASK_COMMIT_LEFT_DIRTY_STATE");
  const parent = requireInternalSuccess(gitInternal(authority.repository.root, ["rev-parse", "HEAD^"]), "TASK_COMMIT_PARENT_INVALID");
  const subject = requireInternalSuccess(gitInternal(authority.repository.root, ["show", "-s", "--format=%s", "HEAD"]), "TASK_COMMIT_SUBJECT_INVALID");
  const changedPaths = requireInternalSuccess(
    gitInternal(authority.repository.root, ["diff", "--name-only", `${parent}..${head.stdout.trim()}`]),
    "TASK_COMMIT_CHANGED_PATHS_INVALID",
  ).split(/\r?\n/).filter(Boolean).sort();
  requireValue(parent === preCommitHead, "TASK_COMMIT_PARENT_CHANGED");
  requireValue(subject === task.required_commit_subject, "TASK_COMMIT_SUBJECT_CHANGED");
  requireValue(canonicalJson(changedPaths) === canonicalJson([...task.authorized_source_paths].sort()), "TASK_COMMIT_CHANGED_PATH_SET_INVALID");
  const committedBlob = gitBlobProof(
    authority.repository.root,
    `${head.stdout.trim()}:${write.relative_path}`,
    write.relative_path,
    ["ls-tree", head.stdout.trim(), "--", write.relative_path],
    "COMMITTED",
  );
  requireValue(
    committedBlob.content_sha256 === write.approved_replacement_sha256
      && committedBlob.byte_length === write.replacement_byte_length,
    "COMMITTED_BLOB_APPROVED_CANDIDATE_MISMATCH",
  );
  requireValue(committedBlob.git_mode === write.expected_file_mode, "COMMITTED_BLOB_MODE_MISMATCH");
  requireValue(
    committedBlob.content_sha256 === stagedBlob.content_sha256
      && committedBlob.byte_length === stagedBlob.byte_length,
    "STAGED_AND_COMMITTED_BLOB_MISMATCH",
  );
  const afterCommit = assertApprovedFileBoundary(
    target,
    candidateSet,
    writeset,
    "POST_COMMIT_WORKTREE_APPROVED_BYTES_CHANGED",
  );
  return identityRecord({
    schema_version: "SYNTHETIC_TASK_COMMIT_RECEIPT_V2",
    task_id: task.task_id,
    commit_authority_identity_sha256: commitAuthority.commit_authority_identity_sha256,
    preauthorization_identity_sha256: preauthorization.preauthorization_identity_sha256,
    binding_identity_sha256: binding.binding_identity_sha256,
    approved_candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    writeset_identity_sha256: writeset.writeset_identity_sha256,
    byte_observation_identity_sha256: byteObservation.byte_observation_identity_sha256,
    precommit_verifier_identity_sha256: verifier.verifier_identity_sha256,
    approved_replacement_sha256: write.approved_replacement_sha256,
    replacement_byte_length: write.replacement_byte_length,
    expected_file_mode: write.expected_file_mode,
    commit: head.stdout.trim(),
    parent,
    subject,
    changed_paths: changedPaths,
    working_tree_before_stage_sha256: beforeStage.sha256,
    working_tree_before_commit_sha256: beforeCommit.sha256,
    working_tree_after_commit_sha256: afterCommit.sha256,
    staged_blob: stagedBlob,
    committed_blob: committedBlob,
    add_command: add,
    commit_command: commit,
    status_after: status,
    authority_use_count: 1,
    amend: false,
    push_performed: false,
  }, "commit_receipt_identity_sha256");
}

export function createCandidateIntegrityProof(
  candidateSet,
  writeset,
  byteObservation,
  precommitVerifier,
  commitReceipt,
) {
  requireValue(
    byteObservation.byte_observation_identity_sha256
      === identityRecord(byteObservation, "byte_observation_identity_sha256").byte_observation_identity_sha256,
    "CANDIDATE_INTEGRITY_BYTE_OBSERVATION_INVALID",
  );
  requireValue(
    commitReceipt.commit_receipt_identity_sha256
      === identityRecord(commitReceipt, "commit_receipt_identity_sha256").commit_receipt_identity_sha256,
    "CANDIDATE_INTEGRITY_COMMIT_RECEIPT_INVALID",
  );
  const expectedSha256 = writeset.writes[0].approved_replacement_sha256;
  const boundaryHashes = [
    byteObservation.candidate_artifact_sha256,
    byteObservation.temporary_file_sha256,
    byteObservation.post_write_file_sha256,
    byteObservation.pre_test_file_sha256,
    byteObservation.post_test_file_sha256,
    commitReceipt.working_tree_before_stage_sha256,
    commitReceipt.staged_blob.content_sha256,
    commitReceipt.working_tree_before_commit_sha256,
    commitReceipt.committed_blob.content_sha256,
    commitReceipt.working_tree_after_commit_sha256,
  ];
  requireValue(boundaryHashes.every((value) => value === expectedSha256), "CANDIDATE_INTEGRITY_BOUNDARY_HASH_MISMATCH");
  return identityRecord({
    schema_version: "TSF_SYNTHETIC_CANDIDATE_INTEGRITY_PROOF_V2",
    candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    writeset_identity_sha256: writeset.writeset_identity_sha256,
    byte_observation_identity_sha256: byteObservation.byte_observation_identity_sha256,
    precommit_verifier_identity_sha256: precommitVerifier.verifier_identity_sha256,
    commit_receipt_identity_sha256: commitReceipt.commit_receipt_identity_sha256,
    task_id: writeset.task_id,
    iteration: writeset.iteration,
    run_id: writeset.run_id,
    relative_path: writeset.writes[0].relative_path,
    approved_replacement_sha256: expectedSha256,
    replacement_byte_length: writeset.writes[0].replacement_byte_length,
    expected_file_mode: writeset.writes[0].expected_file_mode,
    boundary_hashes: {
      candidate_artifact: byteObservation.candidate_artifact_sha256,
      temporary_file: byteObservation.temporary_file_sha256,
      post_write_file: byteObservation.post_write_file_sha256,
      pre_test_file: byteObservation.pre_test_file_sha256,
      post_test_file: byteObservation.post_test_file_sha256,
      working_tree_before_stage: commitReceipt.working_tree_before_stage_sha256,
      staged_blob: commitReceipt.staged_blob.content_sha256,
      working_tree_before_commit: commitReceipt.working_tree_before_commit_sha256,
      committed_blob: commitReceipt.committed_blob.content_sha256,
      working_tree_after_commit: commitReceipt.working_tree_after_commit_sha256,
    },
    staged_blob: commitReceipt.staged_blob,
    committed_blob: commitReceipt.committed_blob,
    commit: commitReceipt.commit,
  }, "candidate_integrity_proof_identity_sha256");
}

function runCompletedVerifier(
  authority,
  registration,
  task,
  preauthorization,
  binding,
  candidateSet,
  writeset,
  byteObservation,
  precommitVerifier,
  commitReceipt,
  candidateIntegrityProof,
) {
  validateApprovedWriteset(authority, registration, task, preauthorization, binding, candidateSet, writeset);
  requireValue(precommitVerifier.phase === "PRECOMMIT_EXECUTION" && precommitVerifier.verdict === "GREEN", "FINAL_VERIFIER_PRECOMMIT_EVIDENCE_INVALID");
  requireValue(
    candidateIntegrityProof.candidate_integrity_proof_identity_sha256
      === identityRecord(candidateIntegrityProof, "candidate_integrity_proof_identity_sha256").candidate_integrity_proof_identity_sha256,
    "FINAL_VERIFIER_INTEGRITY_PROOF_INVALID",
  );
  requireValue(
    candidateIntegrityProof.candidate_set_identity_sha256 === candidateSet.candidate_set_identity_sha256
      && candidateIntegrityProof.writeset_identity_sha256 === writeset.writeset_identity_sha256
      && candidateIntegrityProof.byte_observation_identity_sha256 === byteObservation.byte_observation_identity_sha256
      && candidateIntegrityProof.precommit_verifier_identity_sha256 === precommitVerifier.verifier_identity_sha256
      && candidateIntegrityProof.commit_receipt_identity_sha256 === commitReceipt.commit_receipt_identity_sha256,
    "FINAL_VERIFIER_BINDING_EVIDENCE_INCONSISTENT",
  );
  const observedCommittedBlob = gitBlobProof(
    authority.repository.root,
    `${commitReceipt.commit}:${writeset.writes[0].relative_path}`,
    writeset.writes[0].relative_path,
    ["ls-tree", commitReceipt.commit, "--", writeset.writes[0].relative_path],
    "FINAL_VERIFIER_COMMITTED",
  );
  requireValue(
    canonicalJson(observedCommittedBlob) === canonicalJson({
      ...commitReceipt.committed_blob,
      phase: "FINAL_VERIFIER_COMMITTED",
    }),
    "FINAL_VERIFIER_COMMITTED_BLOB_CHANGED",
  );
  const status = command(authority, task, "git", ["status", "--porcelain=v2"]);
  const passed = status.exit_code === 0
    && status.stdout.trim() === ""
    && observedCommittedBlob.content_sha256 === writeset.writes[0].approved_replacement_sha256
    && observedCommittedBlob.byte_length === writeset.writes[0].replacement_byte_length
    && observedCommittedBlob.git_mode === writeset.writes[0].expected_file_mode;
  return identityRecord({
    schema_version: "TSF_SYNTHETIC_ITERATION_VERIFIER_V2",
    phase: "POSTCOMMIT_BINDING",
    program_id: authority.program_id,
    verifier_id: `synthetic-verifier-${randomUUID()}`,
    verifier_role: "canonical-kernel-postrun-extension",
    independence: "SEPARATE_ROLE",
    task_id: task.task_id,
    registration_identity_sha256: registration.registration_identity_sha256,
    preauthorization_identity_sha256: preauthorization.preauthorization_identity_sha256,
    binding_identity_sha256: binding.binding_identity_sha256,
    approved_candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    writeset_identity_sha256: writeset.writeset_identity_sha256,
    byte_observation_identity_sha256: byteObservation.byte_observation_identity_sha256,
    candidate_integrity_proof_identity_sha256: candidateIntegrityProof.candidate_integrity_proof_identity_sha256,
    precommit_verifier_identity_sha256: precommitVerifier.verifier_identity_sha256,
    commit_receipt_identity_sha256: commitReceipt.commit_receipt_identity_sha256,
    baseline_commit: binding.baseline_commit,
    baseline_tree: binding.baseline_tree,
    iteration: writeset.iteration,
    run_id: writeset.run_id,
    approved_replacement_sha256: writeset.writes[0].approved_replacement_sha256,
    replacement_byte_length: writeset.writes[0].replacement_byte_length,
    expected_file_mode: writeset.writes[0].expected_file_mode,
    syntax: precommitVerifier.syntax,
    focused: precommitVerifier.focused,
    acceptance: precommitVerifier.acceptance,
    diff_check: precommitVerifier.diff_check,
    changed_paths: commitReceipt.changed_paths,
    required_changed_paths: [...task.authorized_source_paths].sort(),
    status_porcelain_v2: status,
    staged_blob: commitReceipt.staged_blob,
    committed_blob: commitReceipt.committed_blob,
    observed_committed_blob: observedCommittedBlob,
    commit: commitReceipt.commit,
    verdict: passed ? "GREEN" : "RED",
    verified: passed,
    binding_evidence_complete: passed,
  }, "verifier_identity_sha256");
}

function admissionArtifactDescriptor(store, relative, identityField) {
  const artifact = readEvidenceArtifact(store.root, relative);
  const identity = artifact.value?.[identityField];
  requireValue(SHA256.test(identity), "ADMISSION_ARTIFACT_IDENTITY_ABSENT", "BLOCKED", { relative, identityField });
  requireValue(identityRecord(artifact.value, identityField)[identityField] === identity, "ADMISSION_ARTIFACT_IDENTITY_MISMATCH", "BLOCKED", { relative });
  return {
    relative_path: relative,
    sha256: artifact.sha256,
    identity_field: identityField,
    identity_sha256: identity,
  };
}

function getCanonicalTaskAdmission(
  authority,
  registration,
  task,
  preauthorization,
  binding,
  candidateSet,
  writeset,
  byteObservation,
  precommitVerifier,
  verifier,
  commitAuthority,
  commitReceipt,
  candidateIntegrityProof,
  store,
  iteration,
) {
  requireValue(verifier.verdict === "GREEN" && verifier.verified === true, "FAILED_VERIFIER_CANNOT_ADMIT");
  requireValue(verifier.phase === "POSTCOMMIT_BINDING" && verifier.binding_evidence_complete === true, "INCOMPLETE_VERIFIER_CANNOT_ADMIT");
  validateApprovedWriteset(authority, registration, task, preauthorization, binding, candidateSet, writeset);
  requireValue(commitReceipt.subject === task.required_commit_subject, "WRONG_COMMIT_CANNOT_ADMIT");
  const runId = verifier.run_id;
  const taskBase = `tasks/${task.task_id}`;
  const iterationBase = `${taskBase}/iteration-${iteration}`;
  const bundle = identityRecord({
    schema_version: "TSF_SYNTHETIC_ADMISSION_BUNDLE_V2",
    program_id: authority.program_id,
    task_id: task.task_id,
    iteration,
    run_id: runId,
    evidence_root: store.root,
    baseline_commit: binding.baseline_commit,
    commit: commitReceipt.commit,
    authorized_source_path: task.authorized_source_paths[0],
    artifacts: {
      registration: admissionArtifactDescriptor(store, "registration.json", "registration_identity_sha256"),
      preauthorization: admissionArtifactDescriptor(store, `${taskBase}/preauthorization.json`, "preauthorization_identity_sha256"),
      binding: admissionArtifactDescriptor(store, `${taskBase}/binding.json`, "binding_identity_sha256"),
      candidate_set: admissionArtifactDescriptor(store, `${iterationBase}/approved-candidate-set.json`, "candidate_set_identity_sha256"),
      writeset: admissionArtifactDescriptor(store, `${iterationBase}/approved-writeset.json`, "writeset_identity_sha256"),
      byte_observation: admissionArtifactDescriptor(store, `${iterationBase}/byte-observation.json`, "byte_observation_identity_sha256"),
      precommit_verifier: admissionArtifactDescriptor(store, `${iterationBase}/precommit-verifier.json`, "verifier_identity_sha256"),
      verifier: admissionArtifactDescriptor(store, `${iterationBase}/verifier.json`, "verifier_identity_sha256"),
      commit_authority: admissionArtifactDescriptor(store, `${iterationBase}/commit-authority.json`, "commit_authority_identity_sha256"),
      commit_receipt: admissionArtifactDescriptor(store, `${iterationBase}/commit-receipt.json`, "commit_receipt_identity_sha256"),
      candidate_integrity_proof: admissionArtifactDescriptor(
        store,
        `${iterationBase}/candidate-integrity-proof.json`,
        "candidate_integrity_proof_identity_sha256",
      ),
    },
  }, "admission_bundle_identity_sha256");
  const bundleRelative = `${iterationBase}/admission-bundle.json`;
  const bundleRecord = store.write(bundleRelative, bundle);
  const candidate = identityRecord({
    schema_version: "TSF_SYNTHETIC_TASK_ADMISSION_CANDIDATE_V2",
    program_id: authority.program_id,
    task_id: task.task_id,
    repository_root: authority.repository.root,
    branch: authority.repository.branch,
    evidence_root: store.root,
    iteration,
    run_id: runId,
    admission_bundle_relative_path: bundleRelative,
    admission_bundle_sha256: bundleRecord.sha256,
    admission_bundle_identity_sha256: bundle.admission_bundle_identity_sha256,
    registration_identity_sha256: registration.registration_identity_sha256,
    preauthorization_identity_sha256: preauthorization.preauthorization_identity_sha256,
    binding_identity_sha256: binding.binding_identity_sha256,
    candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    writeset_identity_sha256: writeset.writeset_identity_sha256,
    byte_observation_identity_sha256: byteObservation.byte_observation_identity_sha256,
    precommit_verifier_identity_sha256: precommitVerifier.verifier_identity_sha256,
    verifier_identity_sha256: verifier.verifier_identity_sha256,
    commit_authority_identity_sha256: commitAuthority.commit_authority_identity_sha256,
    commit_receipt_identity_sha256: commitReceipt.commit_receipt_identity_sha256,
    candidate_integrity_proof_identity_sha256: candidateIntegrityProof.candidate_integrity_proof_identity_sha256,
    approved_replacement_sha256: writeset.writes[0].approved_replacement_sha256,
    replacement_byte_length: writeset.writes[0].replacement_byte_length,
    expected_file_mode: writeset.writes[0].expected_file_mode,
    verifier_verdict: verifier.verdict,
    verifier_verified: verifier.verified,
    commit: commitReceipt.commit,
    commit_subject: commitReceipt.subject,
    authority_use_count: commitReceipt.authority_use_count,
    push_performed: commitReceipt.push_performed,
    amend: commitReceipt.amend,
    expected_commit_subject: task.required_commit_subject,
    expected_baseline_commit: binding.baseline_commit,
    grants_approval: false,
    grants_merge_authority: false,
    grants_push_authority: false,
    grants_product_authority: false,
  }, "candidate_identity_sha256");
  const candidateRelative = `tasks/${task.task_id}/iteration-${iteration}/admission-candidate.json`;
  store.write(candidateRelative, candidate);
  const candidatePath = path.join(store.root, ...candidateRelative.split("/"));
  const wrapper = path.join(TSF_ROOT, "tools", "Get-TsfSyntheticIterationAdmissionDecisionV2.ps1");
  requireValue(existsSync(wrapper), "CANONICAL_ADMISSION_EXTENSION_ABSENT");
  const result = internalRun(
    assertPinnedExecutable(PINNED_EXECUTABLES.powershell),
    ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", wrapper, "-CandidatePath", candidatePath],
    TSF_ROOT,
    { timeout: 60_000 },
  );
  requireValue(result.exit_code === 0, "CANONICAL_ADMISSION_EXTENSION_FAILED", "BLOCKED", {
    stderr: result.stderr,
    stdout: result.stdout,
  });
  let admission;
  try {
    admission = JSON.parse(result.stdout);
  } catch {
    throw new AuthorityV2Error("CANONICAL_ADMISSION_EXTENSION_RESULT_INVALID", "BLOCKED", { stdout: result.stdout });
  }
  requireValue(admission.schema_version === "TSF_SYNTHETIC_TASK_ADMISSION_EXTENSION_V2", "CANONICAL_ADMISSION_VERSION_CHANGED");
  requireValue(admission.admission_engine === "Get-TsfSyntheticIterationAdmissionDecisionV2", "NONCANONICAL_ADMISSION_ENGINE");
  requireValue(admission.disposition === "ADMITTED", "CANONICAL_ADMISSION_REJECTED", "BLOCKED", admission);
  requireValue(admission.candidate_identity_sha256 === candidate.candidate_identity_sha256, "CANONICAL_ADMISSION_CANDIDATE_MISMATCH");
  requireValue(admission.admission_bundle_identity_sha256 === bundle.admission_bundle_identity_sha256, "CANONICAL_ADMISSION_BUNDLE_MISMATCH");
  requireValue(admission.grants_approval === false
    && admission.grants_merge_authority === false
    && admission.grants_push_authority === false
    && admission.grants_product_authority === false, "CANONICAL_ADMISSION_GRANTED_AUTHORITY", "TIM_REQUIRED");
  return admission;
}

function newStateTrace(authority) {
  let state = "PLANNED";
  const first = identityRecord({
    sequence: 1,
    state,
    observed_at: new Date().toISOString(),
    previous_event_sha256: null,
    evidence: null,
  }, "event_identity_sha256");
  const events = [first];
  return {
    get state() { return state; },
    move(nextState, evidence = null) {
      state = transitionIteration(authority, state, nextState);
      events.push(identityRecord({
        sequence: events.length + 1,
        state,
        observed_at: new Date().toISOString(),
        previous_event_sha256: events.at(-1).event_identity_sha256,
        evidence,
      }, "event_identity_sha256"));
      return state;
    },
    events,
  };
}

function iterationFailureState(trace, state, diagnosis, hasNext) {
  trace.move(state, { diagnosis });
  if (hasNext) {
    trace.move("CORRECTION_PLANNED", { diagnosis });
    trace.move("CORRECTION_APPROVED", { scope_widened: false });
  } else {
    trace.move("EXHAUSTED", { diagnosis });
  }
}

function createRecoveryState(
  authority,
  registration,
  task,
  preauthorization,
  binding,
  candidateSet,
  writeset,
  iteration,
  originalRunId,
  artifacts,
) {
  const base = {
    schema_version: "SYNTHETIC_WRITE_RECOVERY_STATE_V2",
    program_id: authority.program_id,
    task_id: task.task_id,
    repository_root: registration.repository_root,
    branch: registration.branch,
    baseline_commit: binding.baseline_commit,
    baseline_tree: binding.baseline_tree,
    registration_identity_sha256: registration.registration_identity_sha256,
    preauthorization_identity_sha256: preauthorization.preauthorization_identity_sha256,
    binding_identity_sha256: binding.binding_identity_sha256,
    candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
    candidate_set_relative_path: artifacts.candidateSet.path,
    candidate_set_file_sha256: artifacts.candidateSet.sha256,
    writeset_identity_sha256: writeset.writeset_identity_sha256,
    writeset_relative_path: artifacts.writeset.path,
    writeset_file_sha256: artifacts.writeset.sha256,
    iteration,
    original_run_id: originalRunId,
    recovery_run_id: `${task.task_id}-recovery-${randomUUID()}`,
    source_relative_path: writeset.writes[0].relative_path,
    preimage_relative_path: artifacts.preimage.path,
    preimage_sha256: artifacts.preimage.sha256,
    replacement_relative_path: artifacts.replacement.path,
    replacement_sha256: artifacts.replacement.sha256,
    replacement_byte_length: artifacts.replacement.bytes,
    recovery_receipt_relative_path: `tasks/${task.task_id}/iteration-${iteration}/recovery-receipt.json`,
    interruption_point: "PRE_WRITE_CHECKPOINT_FOR_ATOMIC_REPLACEMENT",
    repository_condition: "PREIMAGE_PRESENT_WRITE_NOT_STARTED",
    pre_iteration_sha256: writeset.writes[0].before_sha256,
    expected_replacement_sha256: writeset.writes[0].approved_replacement_sha256,
    authorized_disposition: "COMPLETE_EXACT_APPROVED_REPLACEMENT",
    auto_admitted: false,
    auto_rerun: false,
  };
  return identityRecord(base, "recovery_identity_sha256");
}

function validateEvidenceRunRoot(evidenceRoot) {
  const resolved = path.resolve(evidenceRoot);
  requireValue(path.dirname(resolved).toLowerCase() === path.resolve(EVIDENCE_ROOT).toLowerCase(), "RECOVERY_EVIDENCE_ROOT_OUTSIDE_FIXED_ROOT");
  requireValue(/^[a-z0-9][a-z0-9-]{2,80}$/.test(path.basename(resolved)), "RECOVERY_EVIDENCE_LABEL_INVALID");
  requireValue(existsSync(resolved) && statSync(resolved).isDirectory(), "RECOVERY_EVIDENCE_ROOT_ABSENT");
  requireValue(!lstatSync(resolved).isSymbolicLink(), "RECOVERY_EVIDENCE_ROOT_REPARSE_POINT");
  requireValue(sameWindowsPath(realpathSync.native(resolved), resolved), "RECOVERY_EVIDENCE_ROOT_ALIAS");
  return resolved;
}

function readEvidenceArtifact(
  evidenceRoot,
  relative,
  { json = true, ignoreNonAuthoritativeStatus = false } = {},
) {
  const normalized = normalizeRepositoryRelativePath(relative);
  const full = path.join(evidenceRoot, ...normalized.split("/"));
  requireValue(pathInside(full, evidenceRoot) && existsSync(full) && statSync(full).isFile(), "RECOVERY_ARTIFACT_ABSENT", "BLOCKED", { relative });
  requireValue(!lstatSync(full).isSymbolicLink(), "RECOVERY_ARTIFACT_REPARSE_POINT", "BLOCKED", { relative });
  const bytes = readFileSync(full);
  if (!json) return { full, bytes, sha256: sha256(bytes) };
  try {
    const text = bytes.toString("utf8");
    assertNoDuplicateJsonMembers(text, "RECOVERY_ARTIFACT_DUPLICATE_JSON_MEMBER");
    const value = JSON.parse(text);
    if (ignoreNonAuthoritativeStatus) {
      delete value.valid;
      delete value.verified;
    }
    return { full, bytes, sha256: sha256(bytes), value };
  } catch (error) {
    if (error instanceof AuthorityV2Error) throw error;
    throw new AuthorityV2Error("RECOVERY_ARTIFACT_JSON_INVALID", "BLOCKED", { relative });
  }
}

export function loadPersistedRecoveryContext(evidenceRoot, taskId, iteration) {
  const root = validateEvidenceRunRoot(evidenceRoot);
  const authority = loadAuthority();
  const task = authority.tasks.find((item) => item.task_id === taskId);
  requireValue(task && Number.isInteger(iteration) && iteration >= 1 && iteration <= task.maximum_iterations, "RECOVERY_TASK_OR_ITERATION_INVALID");
  const base = `tasks/${task.task_id}/iteration-${iteration}`;
  const registrationArtifact = readEvidenceArtifact(root, "registration.json");
  const preauthorizationArtifact = readEvidenceArtifact(root, `tasks/${task.task_id}/preauthorization.json`);
  const bindingArtifact = readEvidenceArtifact(root, `tasks/${task.task_id}/binding.json`);
  const candidateSetRelative = `${base}/approved-candidate-set.json`;
  const candidateSetFull = path.join(root, ...candidateSetRelative.split("/"));
  requireValue(
    existsSync(candidateSetFull),
    "RECOVERY_CANONICAL_CANDIDATE_BINDING_ABSENT",
    "NEW_GOVERNED_RECOVERY_REQUIRED",
  );
  const candidateSetArtifact = readEvidenceArtifact(root, candidateSetRelative);
  const writesetArtifact = readEvidenceArtifact(root, `${base}/approved-writeset.json`);
  const recoveryArtifact = readEvidenceArtifact(
    root,
    `${base}/pre-write-recovery-state.json`,
    { ignoreNonAuthoritativeStatus: true },
  );
  const registration = registrationArtifact.value;
  const preauthorization = preauthorizationArtifact.value;
  const binding = bindingArtifact.value;
  const candidateSet = candidateSetArtifact.value;
  const writeset = writesetArtifact.value;
  const recovery = recoveryArtifact.value;
  validateRegistrationRecord(registration, authority, { requireBaselineHead: false });
  matchPreauthorizedTaskBinding(authority, registration, preauthorization, binding, task.task_id);
  const canonicalCandidateSet = createApprovedBuilderCandidateSet(
    authority,
    registration,
    task,
    preauthorization,
    iteration,
    task.authorized_source_paths[0],
  );
  requireValue(
    canonicalJson(candidateSet) === canonicalJson(canonicalCandidateSet),
    "RECOVERY_PERSISTED_CANDIDATE_SET_NOT_CANONICAL",
  );
  validateApprovedBuilderCandidateSet(authority, registration, task, preauthorization, candidateSet);
  validateApprovedWriteset(authority, registration, task, preauthorization, binding, candidateSet, writeset);
  validateRecoveryState(
    authority,
    registration,
    task,
    preauthorization,
    binding,
    candidateSet,
    writeset,
    recovery,
  );
  requireValue(recovery.candidate_set_relative_path === candidateSetRelative, "RECOVERY_CANDIDATE_SET_PATH_CHANGED");
  requireValue(recovery.candidate_set_file_sha256 === candidateSetArtifact.sha256, "RECOVERY_CANDIDATE_SET_FILE_HASH_CHANGED");
  requireValue(recovery.writeset_relative_path === `${base}/approved-writeset.json`, "RECOVERY_WRITESET_PATH_CHANGED");
  requireValue(recovery.writeset_file_sha256 === writesetArtifact.sha256, "RECOVERY_WRITESET_FILE_HASH_CHANGED");
  requireValue(recovery.preimage_relative_path === `${base}/preimage.bin`, "RECOVERY_PREIMAGE_PATH_CHANGED");
  requireValue(recovery.replacement_relative_path === `${base}/replacement.bin`, "RECOVERY_REPLACEMENT_PATH_CHANGED");
  requireValue(recovery.recovery_receipt_relative_path === `${base}/recovery-receipt.json`, "RECOVERY_RECEIPT_PATH_CHANGED");
  const preimage = readEvidenceArtifact(root, recovery.preimage_relative_path, { json: false });
  const replacement = readEvidenceArtifact(root, recovery.replacement_relative_path, { json: false });
  requireValue(preimage.sha256 === recovery.preimage_sha256, "RECOVERY_PREIMAGE_BLOB_CHANGED");
  requireValue(replacement.sha256 === recovery.replacement_sha256, "RECOVERY_REPLACEMENT_BLOB_CHANGED");
  requireValue(replacement.bytes.length === recovery.replacement_byte_length, "RECOVERY_REPLACEMENT_BLOB_LENGTH_CHANGED");
  assertApprovedCandidateBytes(candidateSet, writeset, replacement.bytes, "RECOVERY_REPLACEMENT_NOT_APPROVED");
  return {
    root,
    base,
    authority,
    task,
    registration,
    preauthorization,
    binding,
    candidateSet,
    writeset,
    recovery,
    preimage,
    replacement,
  };
}

export function applyPersistedReplacementForInterruption(evidenceRoot, taskId, iteration) {
  const context = loadPersistedRecoveryContext(evidenceRoot, taskId, iteration);
  const target = validateAllowedPath({
    repositoryRoot: context.registration.repository_root,
    relativePath: context.recovery.source_relative_path,
    allowlist: context.task.authorized_source_paths,
    requireExisting: true,
  }).fullPath;
  requireValue(sha256(readFileSync(target)) === context.recovery.pre_iteration_sha256, "RECOVERY_PREIMAGE_STATE_CHANGED");
  const facts = currentGitFacts(context.authority, context.task);
  requireValue(facts.head === context.binding.baseline_commit && facts.status_porcelain_v2.trim() === "", "RECOVERY_BASELINE_STATE_CHANGED");
  const observation = applyCanonicalApprovedAtomicReplacement({
    authority: context.authority,
    registration: context.registration,
    task: context.task,
    preauthorization: context.preauthorization,
    binding: context.binding,
    candidateSet: context.candidateSet,
    writeset: context.writeset,
    content: context.replacement.bytes,
    evidenceStore: { root: context.root },
  });
  const record = identityRecord({
    schema_version: "TSF_SYNTHETIC_INTERRUPTED_REPLACEMENT_OBSERVATION_V2",
    task_id: context.task.task_id,
    iteration,
    run_id: context.writeset.run_id,
    ...observation,
    tests_started: false,
  }, "interrupted_replacement_observation_identity_sha256");
  const observationPath = path.join(context.root, ...`${context.base}/interrupted-replacement-observation.json`.split("/"));
  writeExclusiveDurable(observationPath, Buffer.from(`${JSON.stringify(record, null, 2)}\n`, "utf8"));
  return record;
}

export function resumePersistedRecovery(evidenceRoot, taskId, iteration) {
  const context = loadPersistedRecoveryContext(evidenceRoot, taskId, iteration);
  const lockPath = path.join(context.root, ...`${context.base}/recovery.lock`.split("/"));
  const lock = openSync(lockPath, "wx");
  closeSync(lock);
  try {
    const receiptPath = path.join(context.root, ...context.recovery.recovery_receipt_relative_path.split("/"));
    requireValue(!existsSync(receiptPath), "RECOVERY_ALREADY_CONSUMED");
    const target = validateAllowedPath({
      repositoryRoot: context.registration.repository_root,
      relativePath: context.recovery.source_relative_path,
      allowlist: context.task.authorized_source_paths,
      requireExisting: true,
    }).fullPath;
    const factsBefore = currentGitFacts(context.authority, context.task);
    requireValue(factsBefore.head === context.binding.baseline_commit && factsBefore.remote_count === 0, "RECOVERY_REGISTRATION_REVALIDATION_FAILED");
    const observedBefore = sha256(readFileSync(target));
    let targetState;
    let replacementObservation;
    if (observedBefore === context.recovery.pre_iteration_sha256) {
      requireValue(factsBefore.status_porcelain_v2.trim() === "", "RECOVERY_PREIMAGE_WORKTREE_NOT_CLEAN");
      replacementObservation = applyCanonicalApprovedAtomicReplacement({
        authority: context.authority,
        registration: context.registration,
        task: context.task,
        preauthorization: context.preauthorization,
        binding: context.binding,
        candidateSet: context.candidateSet,
        writeset: context.writeset,
        content: context.replacement.bytes,
        evidenceStore: { root: context.root },
      });
      targetState = "PREIMAGE_COMPLETED_EXACT_REPLACEMENT";
    } else if (observedBefore === context.recovery.expected_replacement_sha256) {
      const statusLines = factsBefore.status_porcelain_v2.split(/\r?\n/).filter(Boolean);
      requireValue(
        statusLines.length === 1
          && statusLines[0].startsWith("1 .M ")
          && statusLines[0].split(" ").at(-1) === context.recovery.source_relative_path,
        "RECOVERY_REPLACEMENT_WORKTREE_AMBIGUOUS",
      );
      const interruptedObservation = readEvidenceArtifact(
        context.root,
        `${context.base}/interrupted-replacement-observation.json`,
      ).value;
      requireValue(
        interruptedObservation.schema_version === "TSF_SYNTHETIC_INTERRUPTED_REPLACEMENT_OBSERVATION_V2"
          && interruptedObservation.candidate_set_identity_sha256 === context.candidateSet.candidate_set_identity_sha256
          && interruptedObservation.writeset_identity_sha256 === context.writeset.writeset_identity_sha256
          && interruptedObservation.approved_replacement_sha256 === context.writeset.writes[0].approved_replacement_sha256
          && interruptedObservation.interrupted_replacement_observation_identity_sha256
            === identityRecord(
              interruptedObservation,
              "interrupted_replacement_observation_identity_sha256",
            ).interrupted_replacement_observation_identity_sha256,
        "RECOVERY_INTERRUPTED_REPLACEMENT_OBSERVATION_INVALID",
      );
      replacementObservation = interruptedObservation;
      targetState = "EXACT_REPLACEMENT_ALREADY_PRESENT";
    } else {
      throw new AuthorityV2Error("RECOVERY_TARGET_STATE_AMBIGUOUS", "BLOCKED", { observed_sha256: observedBefore });
    }
    assertApprovedFileBoundary(
      target,
      context.candidateSet,
      context.writeset,
      "RECOVERY_REPLACEMENT_STATE_CHANGED",
    );
    const receipt = identityRecord({
      schema_version: "TSF_SYNTHETIC_WRITE_RECOVERY_RECEIPT_V2",
      recovery_identity_sha256: context.recovery.recovery_identity_sha256,
      writeset_identity_sha256: context.writeset.writeset_identity_sha256,
      candidate_set_identity_sha256: context.candidateSet.candidate_set_identity_sha256,
      binding_identity_sha256: context.binding.binding_identity_sha256,
      original_run_id: context.recovery.original_run_id,
      recovery_run_id: context.recovery.recovery_run_id,
      disposition: "EXACT_RESUME",
      target_state: targetState,
      replacement_sha256: context.recovery.expected_replacement_sha256,
      replacement_byte_length: context.recovery.replacement_byte_length,
      interrupted_replacement_observation_identity_sha256:
        replacementObservation.interrupted_replacement_observation_identity_sha256 ?? null,
      tests_run_during_recovery: false,
      admitted_during_recovery: false,
      scope_widened: false,
      consumed: true,
    }, "recovery_receipt_identity_sha256");
    writeExclusiveDurable(receiptPath, Buffer.from(`${JSON.stringify(receipt, null, 2)}\n`, "utf8"));
    return { context, receipt, replacementObservation };
  } finally {
    if (existsSync(lockPath)) unlinkSync(lockPath);
  }
}

function resumableEvidenceWriter(root) {
  return {
    root,
    write(relative, value) {
      const normalized = normalizeRepositoryRelativePath(relative);
      const full = path.join(root, ...normalized.split("/"));
      requireValue(pathInside(full, root) && !existsSync(full), "IMMUTABLE_EVIDENCE_REWRITE");
      const bytes = Buffer.isBuffer(value)
        ? value
        : Buffer.from(typeof value === "string" ? value : `${JSON.stringify(value, null, 2)}\n`, "utf8");
      writeExclusiveDurable(full, bytes);
      return { path: normalized, sha256: sha256(bytes), bytes: bytes.length };
    },
  };
}

export function resumePersistedTask(evidenceRoot, taskId, iteration) {
  const { context, receipt, replacementObservation } = resumePersistedRecovery(evidenceRoot, taskId, iteration);
  const store = resumableEvidenceWriter(context.root);
  const syntax = commandWithCandidateBoundary(
    context.authority,
    context.task,
    "node",
    ["--check", context.task.authorized_source_paths[0]],
    context.candidateSet,
    context.writeset,
  );
  const focused = context.task.focused_tests.map(
    (relative) => testReceipt(context.authority, context.task, relative, context.candidateSet, context.writeset),
  );
  const acceptance = context.task.acceptance_tests.map(
    (relative) => testReceipt(context.authority, context.task, relative, context.candidateSet, context.writeset),
  );
  requireValue(syntax.exit_code === 0 && focused.every((item) => item.exit_code === 0), "RECOVERY_CONTINUATION_FOCUSED_TESTS_FAILED");
  requireValue(acceptance.every((item) => item.exit_code === 0), "RECOVERY_CONTINUATION_ACCEPTANCE_TESTS_FAILED");
  const byteObservation = identityRecord({
    schema_version: "TSF_SYNTHETIC_CANDIDATE_BYTE_OBSERVATION_V2",
    task_id: context.task.task_id,
    iteration,
    run_id: context.writeset.run_id,
    candidate_set_identity_sha256: context.candidateSet.candidate_set_identity_sha256,
    writeset_identity_sha256: context.writeset.writeset_identity_sha256,
    approved_replacement_sha256: context.writeset.writes[0].approved_replacement_sha256,
    replacement_byte_length: context.writeset.writes[0].replacement_byte_length,
    candidate_artifact_sha256: replacementObservation.candidate_artifact_sha256,
    candidate_artifact_byte_length: replacementObservation.candidate_artifact_byte_length,
    before_file_sha256: replacementObservation.before_file_sha256,
    temporary_file_sha256: replacementObservation.temporary_file_sha256,
    post_write_file_sha256: replacementObservation.post_write_file_sha256,
    pre_test_file_sha256: syntax.approved_bytes_before_command_sha256,
    post_test_file_sha256: acceptance.at(-1).approved_bytes_after_command_sha256,
  }, "byte_observation_identity_sha256");
  store.write(`${context.base}/byte-observation.json`, byteObservation);
  const patch = command(context.authority, context.task, "git", ["diff", "--binary"]);
  const patchRecord = store.write(`${context.base}/patch.diff`, patch.stdout);
  const precommitVerifier = runIndependentVerifier(
    context.authority,
    context.registration,
    context.task,
    context.preauthorization,
    context.binding,
    context.candidateSet,
    context.writeset,
    byteObservation,
    iteration,
    context.recovery.original_run_id,
  );
  requireValue(precommitVerifier.verdict === "GREEN" && precommitVerifier.verified === true, "RECOVERY_CONTINUATION_VERIFIER_REJECTED");
  store.write(`${context.base}/precommit-verifier.json`, precommitVerifier);
  const commitAuthority = createCommitAuthority(
    context.authority,
    context.registration,
    context.task,
    context.preauthorization,
    context.binding,
    context.candidateSet,
    context.writeset,
    byteObservation,
    precommitVerifier,
  );
  store.write(`${context.base}/commit-authority.json`, commitAuthority);
  const commitReceipt = commitVerifiedTask(
    context.authority,
    context.registration,
    context.task,
    context.preauthorization,
    context.binding,
    context.candidateSet,
    context.writeset,
    byteObservation,
    precommitVerifier,
    commitAuthority,
  );
  store.write(`${context.base}/commit-receipt.json`, commitReceipt);
  const candidateIntegrityProof = createCandidateIntegrityProof(
    context.candidateSet,
    context.writeset,
    byteObservation,
    precommitVerifier,
    commitReceipt,
  );
  store.write(`${context.base}/candidate-integrity-proof.json`, candidateIntegrityProof);
  const verifier = runCompletedVerifier(
    context.authority,
    context.registration,
    context.task,
    context.preauthorization,
    context.binding,
    context.candidateSet,
    context.writeset,
    byteObservation,
    precommitVerifier,
    commitReceipt,
    candidateIntegrityProof,
  );
  requireValue(verifier.verdict === "GREEN" && verifier.verified === true, "RECOVERY_FINAL_VERIFIER_REJECTED");
  store.write(`${context.base}/verifier.json`, verifier);
  const admission = getCanonicalTaskAdmission(
    context.authority,
    context.registration,
    context.task,
    context.preauthorization,
    context.binding,
    context.candidateSet,
    context.writeset,
    byteObservation,
    precommitVerifier,
    verifier,
    commitAuthority,
    commitReceipt,
    candidateIntegrityProof,
    store,
    iteration,
  );
  store.write(`${context.base}/admission.json`, admission);
  const result = identityRecord({
    schema_version: "TSF_SYNTHETIC_RECOVERY_CONTINUATION_RESULT_V2",
    task_id: context.task.task_id,
    iteration,
    syntax,
    focused,
    acceptance,
    patch: patchRecord,
    byte_observation: byteObservation,
    precommit_verifier: precommitVerifier,
    verifier,
    commit_authority: commitAuthority,
    commit_receipt: commitReceipt,
    candidate_integrity_proof: candidateIntegrityProof,
    admission,
    recovery_receipt: receipt,
  }, "continuation_result_identity_sha256");
  store.write(`${context.base}/continuation-result.json`, result);
  return result;
}

function runTask(authority, registration, task, store, consumedBindingIdentities, { interruptFirstWrite = false } = {}) {
  const concreteBaselineCommit = requireInternalSuccess(
    gitInternal(registration.repository_root, ["rev-parse", "HEAD"]),
    "TASK_BASELINE_INSPECTION_FAILED",
  );
  const concreteBaselineTree = requireInternalSuccess(
    gitInternal(registration.repository_root, ["rev-parse", "HEAD^{tree}"]),
    "TASK_BASELINE_TREE_INSPECTION_FAILED",
  );
  const statusAtStart = requireInternalSuccess(
    gitInternal(registration.repository_root, ["status", "--porcelain=v2"]),
    "TASK_START_STATUS_INSPECTION_FAILED",
  );
  requireValue(statusAtStart === "", "TASK_BASELINE_NOT_CLEAN");
  const preauthorization = createTaskPreauthorization(
    authority,
    registration,
    task.task_id,
    concreteBaselineCommit,
    concreteBaselineTree,
  );
  const binding = createPreauthorizedTaskBinding(authority, registration, preauthorization);
  matchPreauthorizedTaskBinding(authority, registration, preauthorization, binding, task.task_id);
  consumePreauthorizedTaskBinding(binding, consumedBindingIdentities);
  store.write(`tasks/${task.task_id}/preauthorization.json`, preauthorization);
  store.write(`tasks/${task.task_id}/binding.json`, binding);
  const candidates = BUILDER_CANDIDATES[task.task_id];
  requireValue(candidates && candidates.length <= 3, "BUILDER_CANDIDATE_SET_INVALID");
  requireValue(
    canonicalJson(candidates.map((candidate, index) => ({
      sha256: sha256(candidate.content),
      byte_length: Buffer.byteLength(candidate.content, "utf8"),
      iteration: index + 1,
      repository_relative_path: task.authorized_source_paths[0],
    })))
      === canonicalJson(task.approved_builder_candidate_sets.map((template) => ({
        sha256: template.candidates[0].sha256,
        byte_length: template.candidates[0].byte_length,
        iteration: template.iteration,
        repository_relative_path: template.repository_relative_path,
      }))),
    "BUILDER_CANDIDATE_CONTENT_NOT_PREAUTHORIZED",
    "TIM_REQUIRED",
  );
  const iterations = [];
  const taskStarted = performance.now();
  let finalVerifier = null;
  let commitReceipt = null;
  let admission = null;

  for (let index = 0; index < candidates.length; index += 1) {
    const iteration = index + 1;
    const authorization = authorizeBuilderIteration(authority, task, iterations, iteration);
    const trace = newStateTrace(authority);
    trace.move("PREAUTHORIZED", { binding_identity_sha256: binding.binding_identity_sha256 });
    trace.move("PREVIEWED", { candidate_content_sha256: sha256(candidates[index].content) });
    trace.move("QUEUED", { maximum_active_write_missions: 1 });
    trace.move("WORKER_RUNNING", { run_id: authorization.run_id, worker_network: false });
    const sourcePath = task.authorized_source_paths[0];
    const fullSource = validateAllowedPath({
      repositoryRoot: registration.repository_root,
      relativePath: sourcePath,
      allowlist: task.authorized_source_paths,
      requireExisting: true,
    }).fullPath;
    const beforeSha256 = sha256(readFileSync(fullSource));
    const candidateSet = createApprovedBuilderCandidateSet(
      authority,
      registration,
      task,
      preauthorization,
      iteration,
      sourcePath,
    );
    validateApprovedBuilderCandidateSet(authority, registration, task, preauthorization, candidateSet);
    requireValue(
      binding.approved_candidate_set_identity_sha256s.includes(candidateSet.candidate_set_identity_sha256),
      "TASK_CANDIDATE_SET_NOT_BOUND",
    );
    const iterationBase = `tasks/${task.task_id}/iteration-${iteration}`;
    const candidateSetRecord = store.write(`${iterationBase}/approved-candidate-set.json`, candidateSet);
    const preimageRecord = store.write(`${iterationBase}/preimage.bin`, readFileSync(fullSource));
    const replacementRecord = store.write(`${iterationBase}/replacement.bin`, Buffer.from(candidates[index].content, "utf8"));
    const writeset = createApprovedWriteset({
      authority,
      registration,
      task,
      preauthorization,
      binding,
      candidateSet,
      iteration,
      runId: authorization.run_id,
      relativePath: sourcePath,
      beforeSha256,
      content: candidates[index].content,
      candidateArtifactRelativePath: replacementRecord.path,
    });
    const writesetRecord = store.write(`${iterationBase}/approved-writeset.json`, writeset);
    const recovery = createRecoveryState(
      authority,
      registration,
      task,
      preauthorization,
      binding,
      candidateSet,
      writeset,
      iteration,
      authorization.run_id,
      {
        candidateSet: candidateSetRecord,
        writeset: writesetRecord,
        preimage: preimageRecord,
        replacement: replacementRecord,
      },
    );
    store.write(`${iterationBase}/pre-write-recovery-state.json`, recovery);
    let replacement = null;
    let recoveryReceipt = null;
    let byteObservation = null;
    let syntax;
    let focused;
    let acceptance;
    let patchRecord;
    let verifier = null;
    let precommitVerifier = null;
    let commitAuthority = null;
    let candidateIntegrityProof = null;
    let focusedPass;
    let acceptancePass;
    const hasNext = index + 1 < candidates.length;
    if (interruptFirstWrite && iteration === 1) {
      const cli = path.join(TSF_ROOT, "tools", "Invoke-TsfSyntheticIterationPilotV2.mjs");
      const interruptedWriter = internalRun(
        assertPinnedExecutable(PINNED_EXECUTABLES.node),
        [cli, "apply-and-crash", store.root, task.task_id, String(iteration)],
        TSF_ROOT,
        { timeout: 60_000 },
      );
      requireValue(interruptedWriter.exit_code === 86, "INTERRUPTED_WRITER_DID_NOT_TERMINATE_AT_FAILPOINT", "BLOCKED", interruptedWriter);
      trace.move("INTERRUPTED", {
        point: "AFTER_ATOMIC_REPLACEMENT_BEFORE_TESTS",
        terminated_writer_exit_code: 86,
        auto_admitted: false,
      });
      trace.move("RECOVERY_REQUIRED", { original_run_id: authorization.run_id });
      const resumed = internalRun(
        assertPinnedExecutable(PINNED_EXECUTABLES.node),
        [cli, "resume-task", store.root, task.task_id, String(iteration)],
        TSF_ROOT,
        { timeout: 120_000 },
      );
      requireValue(resumed.exit_code === 0, "RECOVERY_CONTINUATION_PROCESS_FAILED", "BLOCKED", resumed);
      const continuationRelative = `${iterationBase}/continuation-result.json`;
      const continuation = readEvidenceArtifact(store.root, continuationRelative).value;
      requireValue(
        continuation.schema_version === "TSF_SYNTHETIC_RECOVERY_CONTINUATION_RESULT_V2"
          && identityRecord(continuation, "continuation_result_identity_sha256").continuation_result_identity_sha256
            === continuation.continuation_result_identity_sha256,
        "RECOVERY_CONTINUATION_RESULT_INVALID",
      );
      for (const relative of [
        `${iterationBase}/interrupted-replacement-observation.json`,
        `${iterationBase}/recovery-receipt.json`,
        `${iterationBase}/byte-observation.json`,
        `${iterationBase}/patch.diff`,
        `${iterationBase}/precommit-verifier.json`,
        `${iterationBase}/verifier.json`,
        `${iterationBase}/commit-authority.json`,
        `${iterationBase}/commit-receipt.json`,
        `${iterationBase}/candidate-integrity-proof.json`,
        `${iterationBase}/admission-bundle.json`,
        `${iterationBase}/admission-candidate.json`,
        `${iterationBase}/admission.json`,
        continuationRelative,
      ]) store.captureExisting(relative);
      recoveryReceipt = continuation.recovery_receipt;
      syntax = continuation.syntax;
      focused = continuation.focused;
      acceptance = continuation.acceptance;
      patchRecord = continuation.patch;
      byteObservation = continuation.byte_observation;
      precommitVerifier = continuation.precommit_verifier;
      verifier = continuation.verifier;
      commitAuthority = continuation.commit_authority;
      commitReceipt = continuation.commit_receipt;
      candidateIntegrityProof = continuation.candidate_integrity_proof;
      admission = continuation.admission;
      replacement = {
        operation: "ATOMIC_REPLACE",
        target: sourcePath,
        temporary_file: null,
        temporary_file_inside_repository: false,
        candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
        writeset_identity_sha256: writeset.writeset_identity_sha256,
        approved_replacement_sha256: writeset.writes[0].approved_replacement_sha256,
        replacement_byte_length: writeset.writes[0].replacement_byte_length,
        writer_process_exit_code: 86,
        recovery_process_exit_code: 0,
      };
      trace.move("PATCH_PRODUCED", { recovery_run_id: recovery.recovery_run_id, disposition: "EXACT_RESUME" });
      trace.move("VERIFIED", {
        verifier_identity_sha256: precommitVerifier.verifier_identity_sha256,
        recovered_in_fresh_process: true,
      });
      trace.move("COMMIT_AUTHORIZED", { commit_authority_identity_sha256: continuation.commit_authority.commit_authority_identity_sha256 });
      trace.move("COMMITTED", { commit: commitReceipt.commit });
      trace.move("ADMITTED", { admission_identity_sha256: admission.admission_identity_sha256 });
      finalVerifier = verifier;
      focusedPass = true;
      acceptancePass = true;
    } else {
      replacement = applyCanonicalApprovedAtomicReplacement({
        authority,
        registration,
        task,
        preauthorization,
        binding,
        candidateSet,
        writeset,
        content: candidates[index].content,
        evidenceStore: store,
      });
      trace.move("PATCH_PRODUCED", {
        candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
        writeset_identity_sha256: writeset.writeset_identity_sha256,
        approved_replacement_sha256: replacement.approved_replacement_sha256,
      });
      syntax = commandWithCandidateBoundary(
        authority,
        task,
        "node",
        ["--check", sourcePath],
        candidateSet,
        writeset,
      );
      focused = task.focused_tests.map(
        (relative) => testReceipt(authority, task, relative, candidateSet, writeset),
      );
      acceptance = task.acceptance_tests.map(
        (relative) => testReceipt(authority, task, relative, candidateSet, writeset),
      );
      byteObservation = identityRecord({
        schema_version: "TSF_SYNTHETIC_CANDIDATE_BYTE_OBSERVATION_V2",
        task_id: task.task_id,
        iteration,
        run_id: authorization.run_id,
        candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
        writeset_identity_sha256: writeset.writeset_identity_sha256,
        approved_replacement_sha256: writeset.writes[0].approved_replacement_sha256,
        replacement_byte_length: writeset.writes[0].replacement_byte_length,
        candidate_artifact_sha256: replacement.candidate_artifact_sha256,
        candidate_artifact_byte_length: replacement.candidate_artifact_byte_length,
        before_file_sha256: replacement.before_file_sha256,
        temporary_file_sha256: replacement.temporary_file_sha256,
        post_write_file_sha256: replacement.post_write_file_sha256,
        pre_test_file_sha256: syntax.approved_bytes_before_command_sha256,
        post_test_file_sha256: acceptance.at(-1).approved_bytes_after_command_sha256,
      }, "byte_observation_identity_sha256");
      store.write(`${iterationBase}/byte-observation.json`, byteObservation);
      const patch = command(authority, task, "git", ["diff", "--binary"]);
      patchRecord = store.write(`${iterationBase}/patch.diff`, patch.stdout);
      focusedPass = syntax.exit_code === 0 && focused.every((receipt) => receipt.exit_code === 0);
      acceptancePass = acceptance.every((receipt) => receipt.exit_code === 0);
      if (!focusedPass) {
        iterationFailureState(trace, "FOCUSED_TESTS_FAILED", candidates[index].diagnosis, hasNext);
      } else if (!acceptancePass) {
        iterationFailureState(trace, "ACCEPTANCE_TESTS_FAILED", candidates[index].diagnosis, hasNext);
      } else {
        precommitVerifier = runIndependentVerifier(
          authority,
          registration,
          task,
          preauthorization,
          binding,
          candidateSet,
          writeset,
          byteObservation,
          iteration,
          authorization.run_id,
        );
        if (precommitVerifier.verdict !== "GREEN") {
          iterationFailureState(trace, "VERIFIER_REJECTED", "Independent verifier rejected the candidate.", hasNext);
        } else {
          trace.move("VERIFIED", { verifier_identity_sha256: precommitVerifier.verifier_identity_sha256 });
          store.write(`${iterationBase}/precommit-verifier.json`, precommitVerifier);
          commitAuthority = createCommitAuthority(
            authority,
            registration,
            task,
            preauthorization,
            binding,
            candidateSet,
            writeset,
            byteObservation,
            precommitVerifier,
          );
          store.write(`${iterationBase}/commit-authority.json`, commitAuthority);
          trace.move("COMMIT_AUTHORIZED", { commit_authority_identity_sha256: commitAuthority.commit_authority_identity_sha256 });
          commitReceipt = commitVerifiedTask(
            authority,
            registration,
            task,
            preauthorization,
            binding,
            candidateSet,
            writeset,
            byteObservation,
            precommitVerifier,
            commitAuthority,
          );
          store.write(`${iterationBase}/commit-receipt.json`, commitReceipt);
          trace.move("COMMITTED", { commit: commitReceipt.commit });
          candidateIntegrityProof = createCandidateIntegrityProof(
            candidateSet,
            writeset,
            byteObservation,
            precommitVerifier,
            commitReceipt,
          );
          store.write(`${iterationBase}/candidate-integrity-proof.json`, candidateIntegrityProof);
          verifier = runCompletedVerifier(
            authority,
            registration,
            task,
            preauthorization,
            binding,
            candidateSet,
            writeset,
            byteObservation,
            precommitVerifier,
            commitReceipt,
            candidateIntegrityProof,
          );
          requireValue(verifier.verdict === "GREEN" && verifier.verified === true, "FINAL_VERIFIER_REJECTED");
          store.write(`${iterationBase}/verifier.json`, verifier);
          admission = getCanonicalTaskAdmission(
            authority,
            registration,
            task,
            preauthorization,
            binding,
            candidateSet,
            writeset,
            byteObservation,
            precommitVerifier,
            verifier,
            commitAuthority,
            commitReceipt,
            candidateIntegrityProof,
            store,
            iteration,
          );
          store.write(`${iterationBase}/admission.json`, admission);
          trace.move("ADMITTED", { admission_identity_sha256: admission.admission_identity_sha256 });
          finalVerifier = verifier;
        }
      }
    }
    const record = {
      schema_version: "CODING_ITERATION_STATE_V2",
      program_id: authority.program_id,
      task_id: task.task_id,
      task_binding_identity_sha256: binding.binding_identity_sha256,
      iteration,
      run_id: authorization.run_id,
      maximum_iterations: authorization.maximum,
      diagnosis: candidates[index].diagnosis,
      candidate_content_sha256: sha256(candidates[index].content),
      approved_candidate_set: candidateSet,
      writeset,
      replacement,
      recovery_checkpoint: {
        recovery_identity_sha256: recovery.recovery_identity_sha256,
        recovery_run_id: recovery.recovery_run_id,
        exercised_after_interruption: Boolean(recoveryReceipt),
        receipt: recoveryReceipt,
      },
      syntax,
      focused_tests: focused,
      acceptance_tests: acceptance,
      byte_observation: byteObservation,
      precommit_verifier: precommitVerifier,
      verifier,
      commit_authority: commitAuthority,
      commit_receipt: trace.state === "ADMITTED" ? commitReceipt : null,
      candidate_integrity_proof: candidateIntegrityProof,
      patch: patchRecord,
      final_state: trace.state,
      state_events: trace.events,
      immutable_after_write: true,
    };
    const recordEvidence = store.write(`tasks/${task.task_id}/iteration-${iteration}/iteration.json`, record);
    iterations.push({
      iteration,
      run_id: authorization.run_id,
      final_state: trace.state,
      record_sha256: recordEvidence.sha256,
      patch_sha256: patchRecord.sha256,
      focused_passed: focusedPass,
      acceptance_passed: acceptancePass,
      verifier_verdict: verifier?.verdict ?? "NOT_RUN",
      approved_candidate_set_identity_sha256: candidateSet.candidate_set_identity_sha256,
      writeset_identity_sha256: writeset.writeset_identity_sha256,
      approved_replacement_sha256: writeset.writes[0].approved_replacement_sha256,
      staged_blob_sha256: commitReceipt?.staged_blob?.content_sha256 ?? null,
      committed_blob_sha256: commitReceipt?.committed_blob?.content_sha256 ?? null,
      diagnosis: candidates[index].diagnosis,
      interrupted: Boolean(recoveryReceipt),
    });
    if (trace.state === "ADMITTED") break;
    requireValue(hasNext, "TASK_ITERATIONS_EXHAUSTED", "EXHAUSTED");
  }

  requireValue(finalVerifier?.verdict === "GREEN" && commitReceipt && admission?.disposition === "ADMITTED", "TASK_NOT_ADMITTED");
  return {
    task_id: task.task_id,
    baseline_commit: preauthorization.baseline_commit,
    binding_identity_sha256: binding.binding_identity_sha256,
    preauthorization_identity_sha256: preauthorization.preauthorization_identity_sha256,
    iterations,
    iteration_count: iterations.length,
    final_verifier_identity_sha256: finalVerifier.verifier_identity_sha256,
    verifier_disposition: finalVerifier.verdict,
    final_candidate_set_identity_sha256: finalVerifier.approved_candidate_set_identity_sha256,
    final_writeset_identity_sha256: finalVerifier.writeset_identity_sha256,
    approved_replacement_sha256: finalVerifier.approved_replacement_sha256,
    staged_blob_sha256: finalVerifier.staged_blob.content_sha256,
    committed_blob_sha256: finalVerifier.committed_blob.content_sha256,
    commit: commitReceipt.commit,
    commit_subject: commitReceipt.subject,
    admission_identity_sha256: admission.admission_identity_sha256,
    admission_disposition: admission.disposition,
    duration_ms: Math.round((performance.now() - taskStarted) * 1000) / 1000,
  };
}

export function runThreeTaskPilot({
  authority = loadAuthority(),
  evidenceLabel = `pilot-${new Date().toISOString().replaceAll(/[:.]/g, "-")}`,
  now = new Date(),
  allowDirtyTsfCandidate = false,
} = {}) {
  validateAuthority(authority);
  requireValue(now <= new Date(authority.expires_at), "PILOT_AUTHORITY_EXPIRED", "TIM_REQUIRED");
  const tsfCandidate = inspectTsfCandidate({ allowDirty: allowDirtyTsfCandidate });
  const registration = seedSyntheticFixture(authority, { now });
  mkdirSync(EVIDENCE_ROOT, { recursive: true });
  const store = new EvidenceStore(path.join(EVIDENCE_ROOT, evidenceLabel));
  store.write("authority.json", authority);
  store.write("registration.json", registration);
  const pilotStarted = performance.now();
  const results = [];
  const consumedBindingIdentities = new Set();
  for (const task of authority.tasks) {
    results.push(runTask(authority, registration, task, store, consumedBindingIdentities, {
      interruptFirstWrite: task.task_id === "synthetic-path-containment-v2",
    }));
  }
  const finalTask = authority.tasks.at(-1);
  const finalFacts = currentGitFacts(authority, finalTask);
  const history = requireInternalSuccess(
    gitInternal(authority.repository.root, ["log", "--format=%H%x09%s", "--reverse"]),
    "PILOT_HISTORY_INSPECTION_FAILED",
  ).split(/\r?\n/).filter(Boolean);
  const remote = requireInternalSuccess(gitInternal(authority.repository.root, ["remote"]), "PILOT_REMOTE_INSPECTION_FAILED");
  requireValue(remote === "", "PILOT_REMOTE_PRESENT");
  requireValue(finalFacts.status_porcelain_v2.trim() === "", "PILOT_FINAL_REPOSITORY_DIRTY");
  requireValue(history.length === 4, "PILOT_COMMIT_COUNT_INVALID");
  requireValue(results.length === 3 && results.every((result) => result.admission_disposition === "ADMITTED"), "PILOT_TASK_ADMISSION_INCOMPLETE");
  requireValue(results[0].baseline_commit === registration.baseline_commit, "PILOT_TASK1_BASELINE_BINDING_INVALID");
  requireValue(results[1].baseline_commit === results[0].commit, "PILOT_TASK2_BASELINE_BINDING_INVALID");
  requireValue(results[2].baseline_commit === results[1].commit, "PILOT_TASK3_BASELINE_BINDING_INVALID");
  requireValue(results[1].iteration_count === 2 && results[1].iterations[0].acceptance_passed === false, "PILOT_TASK2_REJECTION_NOT_PROVEN");
  requireValue(results[2].iteration_count >= 2 && results[2].iterations[0].acceptance_passed === false, "PILOT_TASK3_CORRECTION_NOT_PROVEN");
  requireValue(results[0].iterations.some((item) => item.interrupted), "PILOT_INTERRUPTION_NOT_PROVEN");
  const summary = {
    schema_version: "TSF_SYNTHETIC_ITERATION_PILOT_RESULT_V2",
    program_id: authority.program_id,
    action_id: authority.action_id,
    tsf_candidate: tsfCandidate,
    authority_sha256: sha256(canonicalJson(authority)),
    registration_identity_sha256: registration.registration_identity_sha256,
    fixture_root: authority.repository.root,
    fixture_branch: authority.repository.branch,
    baseline_commit: registration.baseline_commit,
    baseline_tree: registration.baseline_tree,
    results,
    history,
    final_head: finalFacts.head,
    final_tree: requireInternalSuccess(gitInternal(authority.repository.root, ["rev-parse", "HEAD^{tree}"]), "PILOT_FINAL_TREE_FAILED"),
    final_status_clean: true,
    task_commit_count: history.length - 1,
    remote_count: 0,
    push_performed: false,
    synthetic_network_used: false,
    package_installation_used: false,
    plugin_used: false,
    credential_accessed: false,
    product_repository_accessed: false,
    service_or_persistent_process_created: false,
    duration_ms: Math.round((performance.now() - pilotStarted) * 1000) / 1000,
  };
  store.write("RESULTS.json", summary);
  const manifest = store.finalize({
    verdict: "GREEN",
    task_count: 3,
    task_commit_count: 3,
    interruption_recovered: true,
    task2_first_attempt_rejected: true,
  });
  return {
    ...summary,
    evidence_root: store.root,
    evidence_manifest_sha256: manifest.sha256,
  };
}

export function archiveFixtureForFreshProof(label, authority = loadAuthority()) {
  requireValue(/^[a-z0-9][a-z0-9-]{2,80}$/.test(label), "ARCHIVE_LABEL_INVALID");
  requireValue(existsSync(authority.repository.root), "ARCHIVE_FIXTURE_ABSENT");
  const remote = requireInternalSuccess(gitInternal(authority.repository.root, ["remote"]), "ARCHIVE_REMOTE_INSPECTION_FAILED");
  const status = requireInternalSuccess(gitInternal(authority.repository.root, ["status", "--porcelain=v2"]), "ARCHIVE_STATUS_INSPECTION_FAILED");
  requireValue(remote === "", "ARCHIVE_REMOTE_PRESENT");
  requireValue(status === "", "ARCHIVE_FIXTURE_DIRTY");
  const head = requireInternalSuccess(gitInternal(authority.repository.root, ["rev-parse", "HEAD"]), "ARCHIVE_HEAD_INSPECTION_FAILED");
  const destinationRoot = path.join(PILOT_ROOT, "preserved");
  mkdirSync(destinationRoot, { recursive: true });
  const destination = path.join(destinationRoot, label);
  requireValue(!existsSync(destination), "ARCHIVE_DESTINATION_EXISTS");
  renameSync(authority.repository.root, destination);
  const receipt = identityRecord({
    schema_version: "TSF_SYNTHETIC_FIXTURE_ARCHIVE_RECEIPT_V2",
    source: authority.repository.root,
    destination,
    head,
    remote_count: 0,
    clean: true,
    preserved_without_deletion: true,
    archived_at: new Date().toISOString(),
  }, "archive_identity_sha256");
  const receiptPath = path.join(destinationRoot, `${label}.receipt.json`);
  writeFileSync(receiptPath, `${JSON.stringify(receipt, null, 2)}\n`, { encoding: "utf8", flag: "wx" });
  return { ...receipt, receipt_path: receiptPath };
}

export function copyEvidenceTree(source, destination) {
  requireValue(existsSync(source) && !existsSync(destination), "EVIDENCE_COPY_PRECONDITION_FAILED");
  cpSync(source, destination, { recursive: true, errorOnExist: true });
  return { source, destination, copied: true };
}
