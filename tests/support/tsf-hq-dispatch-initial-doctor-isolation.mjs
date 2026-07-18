import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import {
  HQ_PORT,
  REPOSITORY_ROOT,
  inspectProcess,
  runDoctor,
} from "../../tools/hq-dispatch/v1/reliability.mjs";

const MODULE_PATH = fileURLToPath(import.meta.url);
const EXIT_BY_STATUS = Object.freeze({
  GREEN: 0,
  GREEN_WITH_CAVEATS: 0,
  ACTION_REQUIRED: 2,
  TIM_REQUIRED: 3,
  UNSAFE_TO_START: 4,
});

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function samePath(left, right) {
  return path.resolve(left).toLowerCase() === path.resolve(right).toLowerCase();
}

function inside(candidate, root) {
  const relative = path.relative(path.resolve(root), path.resolve(candidate));
  return relative === "" || (!relative.startsWith("..") && !path.isAbsolute(relative));
}

function requiredChild(candidate, root, label) {
  if (!inside(candidate, root) || samePath(candidate, root)) throw new Error(`ISOLATION_${label}_NOT_UNIQUE`);
}

export function validateInitialDoctorIsolation(context) {
  if (!context || typeof context !== "object") throw new Error("ISOLATION_CONTEXT_REQUIRED");
  const repositoryRoot = path.resolve(context.repository_root ?? REPOSITORY_ROOT);
  const fixtureRoot = path.resolve(context.fixture_root ?? "");
  if (!inside(fixtureRoot, repositoryRoot) || samePath(fixtureRoot, repositoryRoot)) throw new Error("ISOLATION_FIXTURE_ROOT_INVALID");
  const isolationRoot = path.resolve(context.isolation_root ?? "");
  if (!inside(isolationRoot, repositoryRoot) || samePath(isolationRoot, repositoryRoot) || samePath(isolationRoot, fixtureRoot)) throw new Error("ISOLATION_STATE_ROOT_INVALID");
  for (const [key, label] of [
    ["runtime_root", "RUNTIME_ROOT"],
    ["owner_root", "OWNER_ROOT"],
    ["owner_path", "OWNER_PATH"],
    ["token_path", "TOKEN_PATH"],
    ["evidence_root", "EVIDENCE_ROOT"],
  ]) requiredChild(context[key], isolationRoot, label);
  requiredChild(context.queue_root, fixtureRoot, "QUEUE_ROOT");
  if (!inside(context.owner_path, context.owner_root) || !inside(context.token_path, context.owner_root)) throw new Error("ISOLATION_OWNER_FILES_OUTSIDE_OWNER_ROOT");
  const distinctRoots = [context.runtime_root, context.queue_root, context.owner_root, context.evidence_root].map((item) => path.resolve(item).toLowerCase());
  if (new Set(distinctRoots).size !== distinctRoots.length) throw new Error("ISOLATION_ROOTS_NOT_DISTINCT");
  if (!/^run-[a-z0-9-]+$/i.test(String(context.test_run_identity ?? ""))) throw new Error("ISOLATION_RUN_IDENTITY_INVALID");
  return { ...context, repository_root: repositoryRoot, fixture_root: fixtureRoot, isolation_root: isolationRoot, port: Number(context.port ?? HQ_PORT) };
}

export function allocateInitialDoctorIsolation({
  repositoryRoot = REPOSITORY_ROOT,
  fixtureRelativeRoot,
  testRunIdentity,
} = {}) {
  if (!fixtureRelativeRoot || !testRunIdentity) throw new Error("ISOLATION_ALLOCATION_ARGUMENTS_REQUIRED");
  const fixtureRoot = path.join(repositoryRoot, fixtureRelativeRoot, testRunIdentity);
  const isolationRoot = path.join(repositoryRoot, ".codex-local", "i", `i-${testRunIdentity.split("-").at(-1)}`);
  const context = validateInitialDoctorIsolation({
    schema_version: "tsf_hq_dispatch_initial_doctor_isolation_context_v1",
    test_run_identity: testRunIdentity,
    repository_root: repositoryRoot,
    fixture_root: fixtureRoot,
    isolation_root: isolationRoot,
    runtime_root: path.join(isolationRoot, "r"),
    queue_root: path.join(fixtureRoot, "q"),
    owner_root: path.join(isolationRoot, "o"),
    owner_path: path.join(isolationRoot, "o", "owner.json"),
    token_path: path.join(isolationRoot, "o", "stop-token.txt"),
    evidence_root: path.join(isolationRoot, "e"),
    port: HQ_PORT,
  });
  if (existsSync(context.fixture_root)) throw new Error(`ISOLATION_FIXTURE_ALREADY_EXISTS:${context.fixture_root}`);
  if (existsSync(context.isolation_root)) throw new Error(`ISOLATION_STATE_ALREADY_EXISTS:${context.isolation_root}`);
  for (const directory of [context.fixture_root, context.runtime_root, context.queue_root, context.owner_root, context.evidence_root]) mkdirSync(directory, { recursive: true });
  return context;
}

function doctorOptions(context) {
  return {
    repositoryRoot: context.repository_root,
    runtimeRoot: context.runtime_root,
    queueRoot: context.queue_root,
    ownerPath: context.owner_path,
    port: context.port,
    allowDirtyForTest: true,
    testOnlyAllowAlternateQueueRoot: true,
  };
}

function humanLines(report) {
  const lines = [
    `TSF HQ Dispatch Doctor V1: ${report.overall_status}`,
    `Safe to start: ${report.safe_to_start}`,
    `Repository: ${report.repository.top}`,
    `Commit: ${report.repository.head}`,
    `Listener: ${report.listener_state.host}:${report.listener_state.port} (${report.listener_state.listeners.length} listener(s))`,
    `Process owner: ${report.process_owner.disposition}`,
  ];
  for (const item of report.checks) {
    if (!item.id || !item.status || !item.next_action) throw new Error(`DOCTOR_HUMAN_CHECK_INVALID:${item?.id ?? "MISSING"}`);
    lines.push(`[${item.status}] ${item.id}`, `  Next: ${item.next_action}`);
  }
  lines.push(`Exact next action: ${report.exact_next_action}`, "Diagnostic output excludes the local stop capability and operator-session tokens.");
  return lines;
}

function encodeContext(context) {
  return Buffer.from(JSON.stringify(context), "utf8").toString("base64url");
}

function decodeContext(value) {
  return validateInitialDoctorIsolation(JSON.parse(Buffer.from(value, "base64url").toString("utf8")));
}

function runDoctorChild(mode, context) {
  const payload = encodeContext(context);
  const args = [MODULE_PATH, mode, payload];
  const startedAt = new Date().toISOString();
  const child = spawnSync(process.execPath, args, {
    cwd: context.repository_root,
    encoding: "utf8",
    windowsHide: true,
    env: { ...process.env },
    maxBuffer: 32 * 1024 * 1024,
  });
  const endedAt = new Date().toISOString();
  return {
    invocation: [process.execPath, ...args],
    started_at: startedAt,
    ended_at: endedAt,
    exit_code: child.status,
    signal: child.signal ?? null,
    error: child.error?.message ?? null,
    stdout: child.stdout ?? "",
    stderr: child.stderr ?? "",
    stdout_sha256: sha256(Buffer.from(child.stdout ?? "", "utf8")),
    stderr_sha256: sha256(Buffer.from(child.stderr ?? "", "utf8")),
  };
}

function parseJsonInvocation(invocation) {
  try { return JSON.parse(invocation.stdout); }
  catch (error) { throw new Error(`INITIAL_DOCTOR_JSON_PARSE_DEFECT:${error.message}:${invocation.stderr}`); }
}

function parseHumanInvocation(invocation) {
  const lines = invocation.stdout.replace(/\r\n/g, "\n").trimEnd().split("\n");
  const status = /^TSF HQ Dispatch Doctor V1: (.+)$/.exec(lines[0] ?? "")?.[1] ?? null;
  const safeRaw = /^Safe to start: (true|false)$/i.exec(lines[1] ?? "")?.[1] ?? null;
  if (!status || safeRaw === null) throw new Error(`INITIAL_DOCTOR_HUMAN_PARSE_DEFECT:${invocation.stdout}:${invocation.stderr}`);
  return { status, safe_to_start: safeRaw.toLowerCase() === "true", lines };
}

function collectEvidencePaths(value, output = new Set()) {
  if (typeof value === "string") {
    if (/^(?:[A-Za-z]:[\\/]|\.{0,2}[\\/])/.test(value)) output.add(value);
    return output;
  }
  if (Array.isArray(value)) for (const item of value) collectEvidencePaths(item, output);
  else if (value && typeof value === "object") for (const item of Object.values(value)) collectEvidencePaths(item, output);
  return output;
}

function gitInventory(repositoryRoot, ignored = false) {
  const args = ["-C", repositoryRoot, "status", "--porcelain=v2", "--untracked-files=all"];
  if (ignored) args.push("--ignored=matching");
  const result = spawnSync("git.exe", args, { encoding: "utf8", windowsHide: true });
  return { exit_code: result.status, lines: (result.stdout ?? "").replace(/\r\n/g, "\n").split("\n").filter(Boolean), stderr: result.stderr ?? "" };
}

function gitText(repositoryRoot, args) {
  const result = spawnSync("git.exe", ["-C", repositoryRoot, ...args], { encoding: "utf8", windowsHide: true });
  if (result.status !== 0) throw new Error(`INITIAL_DOCTOR_GIT_IDENTITY_UNAVAILABLE:${args.join(" ")}:${result.stderr}`);
  return result.stdout.trim();
}

export function runInitialDoctorPair(context, { environmentBefore = null, requireSafe = true } = {}) {
  const validated = validateInitialDoctorIsolation(context);
  const jsonInvocation = runDoctorChild("--doctor-json", validated);
  const jsonReport = parseJsonInvocation(jsonInvocation);
  const humanInvocation = runDoctorChild("--doctor-human", validated);
  const humanReport = parseHumanInvocation(humanInvocation);
  const blocking = jsonReport.checks.filter((item) => ["UNSAFE_TO_START", "TIM_REQUIRED", "ACTION_REQUIRED"].includes(item.status));
  const cautionary = jsonReport.checks.filter((item) => item.status === "GREEN_WITH_CAVEATS");
  const diagnostic = {
    schema_version: "tsf_hq_dispatch_initial_doctor_diagnostic_v1",
    generated_at: new Date().toISOString(),
    test_run_identity: validated.test_run_identity,
    roots: {
      fixture: validated.fixture_root,
      isolation: validated.isolation_root,
      evidence: validated.evidence_root,
      runtime: validated.runtime_root,
      queue: validated.queue_root,
      owner: validated.owner_root,
      owner_record: validated.owner_path,
    },
    invocation_order: ["JSON_FIRST_STATE_OBSERVATION", "HUMAN_CLASSIFICATION_CONFIRMATION"],
    json: { ...jsonInvocation, stdout: undefined, report: jsonReport },
    human: { ...humanInvocation, stdout: undefined, classification: humanReport },
    classification_agreement: jsonReport.overall_status === humanReport.status && jsonReport.safe_to_start === humanReport.safe_to_start && jsonInvocation.exit_code === humanInvocation.exit_code,
    expected_exit_code: EXIT_BY_STATUS[jsonReport.overall_status] ?? 4,
    checks: jsonReport.checks.map((item) => ({
      id: item.id,
      status: item.status,
      evidence_paths: [...collectEvidencePaths(item.evidence)].sort(),
      evidence: item.evidence,
      next_action: item.next_action,
    })),
    blocking_findings: blocking.map((item) => ({ id: item.id, status: item.status, evidence: item.evidence, next_action: item.next_action })),
    cautionary_findings: cautionary.map((item) => ({ id: item.id, status: item.status, evidence: item.evidence, next_action: item.next_action })),
    repository: {
      top: jsonReport.repository.top,
      worktree: gitText(validated.repository_root, ["rev-parse", "--show-toplevel"]),
      head: jsonReport.repository.head,
      tree: gitText(validated.repository_root, ["rev-parse", "HEAD^{tree}"]),
      branch: jsonReport.repository.branch,
      status_lines: jsonReport.repository.status_lines,
    },
    owner_record_state: jsonReport.process_owner,
    listener_state: jsonReport.listener_state,
    process_state: { harness: inspectProcess(process.pid), active_child: jsonReport.active_child },
    runtime_queue_inventory: jsonReport.reconciliation.queue_inventory,
    source_dirtiness_inventory: gitInventory(validated.repository_root, false),
    ignored_and_untracked_inventory: gitInventory(validated.repository_root, true),
    environment_before: environmentBefore,
  };
  const diagnosticPath = path.join(validated.evidence_root, "INITIAL_DOCTOR_DIAGNOSTIC.json");
  writeFileSync(diagnosticPath, `${JSON.stringify(diagnostic, null, 2)}\n`, { encoding: "utf8", flag: "wx" });
  const complete = {
    ...diagnostic,
    diagnostic_path: diagnosticPath,
    diagnostic_sha256: sha256(readFileSync(diagnosticPath)),
  };
  if (!diagnostic.classification_agreement) throw new Error(`INITIAL_DOCTOR_CLASSIFICATION_MISMATCH:${JSON.stringify(complete)}`);
  if (jsonInvocation.exit_code !== complete.expected_exit_code || humanInvocation.exit_code !== complete.expected_exit_code) throw new Error(`INITIAL_DOCTOR_EXIT_MISMATCH:${JSON.stringify(complete)}`);
  if (requireSafe && (!jsonReport.safe_to_start || !["GREEN", "GREEN_WITH_CAVEATS"].includes(jsonReport.overall_status))) {
    throw new Error(`INITIAL_ISOLATED_DOCTOR_ASSERTION:${JSON.stringify(complete)}`);
  }
  return { report: jsonReport, diagnostic: complete };
}

function childMain() {
  const mode = process.argv[2];
  const context = decodeContext(process.argv[3] ?? "");
  const report = runDoctor(doctorOptions(context));
  if (mode === "--doctor-json") process.stdout.write(`${JSON.stringify(report)}\n`);
  else if (mode === "--doctor-human") process.stdout.write(`${humanLines(report).join("\n")}\n`);
  else throw new Error("ISOLATED_DOCTOR_MODE_INVALID");
  process.exitCode = EXIT_BY_STATUS[report.overall_status] ?? 4;
}

if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url) {
  try { childMain(); }
  catch (error) {
    process.stderr.write(`${error instanceof Error ? error.stack : String(error)}\n`);
    process.exitCode = 1;
  }
}
