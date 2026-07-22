import { spawn, execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from "node:fs";
import path from "node:path";
import {
  createM3RealInterruptionBarrier,
} from "../../tools/hq-dispatch/v1/mission-relay.mjs";

export const FIXTURE_TYPE = "TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1";
export const FIXTURE_RELATIVE_ROOT = path.join(".codex-local", "fixtures", "hq-dispatch-m3-real-interruption-v1");
export const BARRIER_HOOK_POINT = "AUTHORITATIVE_REAL_APP_SERVER_SUSPENDED_AFTER_EXACT_OWNERSHIP_REGISTRATION";

function hashObject(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
}

function hashFile(filePath) {
  return createHash("sha256").update(readFileSync(filePath)).digest("hex");
}

function samePath(left, right) {
  return path.resolve(String(left ?? "")).toLowerCase() === path.resolve(String(right ?? "")).toLowerCase();
}

function barrierError(classification, detail = classification) {
  const error = new Error(`${classification}:${detail}`);
  error.classification = classification;
  return error;
}

function atomicWriteJson(filePath, value) {
  mkdirSync(path.dirname(filePath), { recursive: true });
  const temporary = `${filePath}.${process.pid}.${Date.now()}.tmp`;
  writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, { encoding: "utf8", flag: "wx" });
  renameSync(temporary, filePath);
}

function encodedPowerShell(source) {
  return Buffer.from(source, "utf16le").toString("base64");
}

function gitText(repositoryRoot, args) {
  return execFileSync("git.exe", ["-C", repositoryRoot, ...args], { encoding: "utf8", windowsHide: true, timeout: 10_000 }).trim();
}

function candidateIdentity(repositoryRoot) {
  return {
    worktree: gitText(repositoryRoot, ["rev-parse", "--show-toplevel"]),
    commit: gitText(repositoryRoot, ["rev-parse", "HEAD"]),
    tree: gitText(repositoryRoot, ["rev-parse", "HEAD^{tree}"]),
  };
}

function spawnBody(value) {
  const { ownership_source_sha256: ignored, ...body } = value;
  return body;
}

export function validateAuthoritativeSpawnEvidence(value, expected) {
  if (!value || value.schema_version !== "tsf_codex_app_server_authoritative_spawn_v1"
      || value.event_type !== "AUTHORITATIVE_APP_SERVER_SPAWN") {
    throw barrierError("APP_SERVER_CHILD_NOT_SPAWNED", "AUTHORITATIVE_SPAWN_EVENT_SCHEMA_INVALID");
  }
  if (value.ownership_source_sha256 !== hashObject(spawnBody(value))) {
    throw barrierError("APP_SERVER_CHILD_NOT_OWNED", "AUTHORITATIVE_SPAWN_EVENT_HASH_MISMATCH");
  }
  for (const [field, wanted] of Object.entries({
    mission_id: expected.mission_id,
    mission_revision: Number(expected.mission_revision),
    run_id: expected.run_id,
    result_id: expected.result_id,
  })) {
    if (value[field] !== wanted) throw barrierError("TEST_RUN_ID_MISMATCH", `AUTHORITATIVE_SPAWN_${field.toUpperCase()}_MISMATCH`);
  }
  if (!samePath(value.repository_worktree, expected.worktree)
      || value.candidate_commit !== expected.commit || value.candidate_tree !== expected.tree) {
    throw barrierError("TEST_CAPABILITY_IDENTITY_MISMATCH", "CANDIDATE_OR_WORKTREE_IDENTITY_MISMATCH");
  }
  if (Date.parse(value.creation_event_timestamp) < Date.parse(expected.not_before_utc)) {
    throw barrierError("PREEXISTING_PROCESS_FALSE_MATCH", "AUTHORITATIVE_SPAWN_PREDATES_PROOF");
  }
  for (const field of ["app_server_process_id", "app_server_parent_process_id"]) {
    if (!Number.isInteger(value[field]) || value[field] <= 0) throw barrierError("APP_SERVER_CHILD_NOT_OWNED", `${field.toUpperCase()}_INVALID`);
  }
  for (const field of ["app_server_process_start_time", "app_server_executable", "app_server_parent_process_start_time", "app_server_parent_executable"]) {
    if (typeof value[field] !== "string" || !value[field]) throw barrierError("APP_SERVER_CHILD_NOT_OWNED", `${field.toUpperCase()}_INVALID`);
  }
  for (const field of ["launch_identity_sha256", "ownership_source_sha256"]) {
    if (!/^[a-f0-9]{64}$/.test(String(value[field] ?? ""))) throw barrierError("APP_SERVER_CHILD_NOT_OWNED", `${field.toUpperCase()}_INVALID`);
  }
  return value;
}

export function selectAuthoritativeSpawnEvent(entries, expected) {
  const candidates = entries
    .filter((entry) => entry?.direction === "adapter_internal"
      && entry?.message?.event_type === "AUTHORITATIVE_APP_SERVER_SPAWN")
    .filter((entry) => entry.message.mission_id === expected.mission_id
      && Number(entry.message.mission_revision) === Number(expected.mission_revision)
      && entry.message.run_id === expected.run_id
      && entry.message.result_id === expected.result_id);
  if (candidates.length === 0) return null;
  if (candidates.length !== 1) throw barrierError("APP_SERVER_CHILD_NOT_OWNED", "MULTIPLE_AUTHORITATIVE_SPAWN_EVENTS_FOR_RUN");
  return validateAuthoritativeSpawnEvidence(candidates[0].message, expected);
}

function readCompleteJournalEntries(eventPath) {
  if (!existsSync(eventPath)) return [];
  const text = readFileSync(eventPath, "utf8");
  const lines = text.split(/\r?\n/);
  const entries = [];
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index].trim();
    if (!line) continue;
    try { entries.push(JSON.parse(line)); }
    catch (error) {
      if (index === lines.length - 1 && !text.endsWith("\n")) continue;
      throw barrierError("APP_SERVER_CHILD_NOT_OWNED", `AUTHORITATIVE_EVENT_JOURNAL_INVALID:${error.message}`);
    }
  }
  return entries;
}

export async function waitForAuthoritativeSpawnEvent({
  eventPath,
  expected,
  terminalPaths,
  executorChild,
  timeoutMs,
  readEntries = readCompleteJournalEntries,
  intervalMs = 25,
}) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (executorChild.exitCode !== null || executorChild.signalCode !== null) {
      throw barrierError("CHILD_COMPLETED_BEFORE_BARRIER", `EXECUTOR_EXITED:${executorChild.exitCode ?? executorChild.signalCode}`);
    }
    if (terminalPaths.some((terminalPath) => terminalPath && existsSync(terminalPath))) {
      throw barrierError("CHILD_COMPLETED_BEFORE_BARRIER", "TERMINAL_EVIDENCE_PRECEDED_BARRIER");
    }
    const selected = selectAuthoritativeSpawnEvent(readEntries(eventPath), expected);
    if (selected) return selected;
    await new Promise((resolveWait) => setTimeout(resolveWait, intervalMs));
  }
  throw barrierError("APP_SERVER_CHILD_NOT_SPAWNED", `AUTHORITATIVE_SPAWN_TIMEOUT_MS_${timeoutMs}`);
}

function runPowerShellJson(powershellExe, source, timeoutMs = 15_000) {
  return new Promise((resolveRun, rejectRun) => {
    const child = spawn(powershellExe, ["-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", encodedPowerShell(source)], {
      detached: false,
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    const timer = setTimeout(() => { child.kill(); rejectRun(barrierError("APP_SERVER_CHILD_NOT_OWNED", `EXACT_PROCESS_INSPECTOR_TIMEOUT:${timeoutMs}`)); }, timeoutMs);
    child.stdout.on("data", (chunk) => { stdout += chunk.toString("utf8"); });
    child.stderr.on("data", (chunk) => { stderr += chunk.toString("utf8"); });
    child.once("error", (error) => { clearTimeout(timer); rejectRun(error); });
    child.once("close", (code) => {
      clearTimeout(timer);
      if (code !== 0) {
        rejectRun(barrierError("APP_SERVER_CHILD_NOT_OWNED", `EXACT_PROCESS_INSPECTOR_FAILED:${code}:${stderr.trim()}`));
        return;
      }
      try { resolveRun(JSON.parse(stdout.trim().split(/\r?\n/).at(-1))); }
      catch (error) { rejectRun(barrierError("APP_SERVER_CHILD_NOT_OWNED", `EXACT_PROCESS_INSPECTOR_OUTPUT_INVALID:${error.message}`)); }
    });
  });
}

async function inspectExactAncestry({ powershellExe, appServerProcessId, executorProcessId }) {
  const source = `
$ErrorActionPreference='Stop'
$cursor=${Number(appServerProcessId)}
$root=${Number(executorProcessId)}
$rows=[Collections.Generic.List[object]]::new()
for($depth=0;$depth-lt32;$depth++){
  $cim=Get-CimInstance Win32_Process -Filter "ProcessId=$cursor" -ErrorAction Stop
  $process=Get-Process -Id $cursor -ErrorAction Stop
  $rows.Add([pscustomobject]@{
    process_id=[int]$process.Id
    process_start_time=$process.StartTime.ToUniversalTime().ToString('o')
    executable=[string]$process.Path
    process_name=[string]$process.ProcessName
    parent_process_id=[int]$cim.ParentProcessId
  })|Out-Null
  if($cursor-eq$root){break}
  $cursor=[int]$cim.ParentProcessId
}
if($rows.Count-eq0-or[int]$rows[$rows.Count-1].process_id-ne$root){throw 'EXACT_APP_SERVER_NOT_DESCENDANT_OF_EXECUTOR'}
ConvertTo-Json -Compress -InputObject @($rows)
`;
  const parsed = await runPowerShellJson(powershellExe, source);
  const chain = Array.isArray(parsed) ? parsed : [parsed];
  if (chain[0]?.process_id !== Number(appServerProcessId) || chain.at(-1)?.process_id !== Number(executorProcessId)) {
    throw barrierError("APP_SERVER_CHILD_NOT_OWNED", "EXACT_PROCESS_CHAIN_ROOT_MISMATCH");
  }
  for (let index = 0; index < chain.length - 1; index += 1) {
    if (Number(chain[index].parent_process_id) !== Number(chain[index + 1].process_id)) {
      throw barrierError("APP_SERVER_CHILD_NOT_OWNED", "EXACT_PROCESS_CHAIN_PARENT_MISMATCH");
    }
  }
  return chain;
}

async function suspendExactAppServer({ powershellExe, spawnEvidence }) {
  const encoded = (value) => Buffer.from(String(value), "utf8").toString("base64");
  const source = `
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TsfM3ExactProcessBarrier {
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, int processId);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr handle);
  [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr handle);
}
'@
$expectedExecutable=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${encoded(spawnEvidence.app_server_executable)}'))
$expectedParentExecutable=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('${encoded(spawnEvidence.app_server_parent_executable)}'))
$child=Get-CimInstance Win32_Process -Filter "ProcessId=${Number(spawnEvidence.app_server_process_id)}" -ErrorAction Stop
$parent=Get-CimInstance Win32_Process -Filter "ProcessId=${Number(spawnEvidence.app_server_parent_process_id)}" -ErrorAction Stop
$childProcess=Get-Process -Id ${Number(spawnEvidence.app_server_process_id)} -ErrorAction Stop
$parentProcess=Get-Process -Id ${Number(spawnEvidence.app_server_parent_process_id)} -ErrorAction Stop
if([int]$child.ParentProcessId-ne${Number(spawnEvidence.app_server_parent_process_id)}){throw 'EXACT_PARENT_PID_MISMATCH'}
if($childProcess.StartTime.ToUniversalTime().Ticks-ne[datetimeoffset]::Parse('${spawnEvidence.app_server_process_start_time}').UtcTicks){throw 'EXACT_CHILD_START_TIME_MISMATCH'}
if($parentProcess.StartTime.ToUniversalTime().Ticks-ne[datetimeoffset]::Parse('${spawnEvidence.app_server_parent_process_start_time}').UtcTicks){throw 'EXACT_PARENT_START_TIME_MISMATCH'}
if(![string]::Equals([string]$child.ExecutablePath,$expectedExecutable,[StringComparison]::OrdinalIgnoreCase)){throw 'EXACT_CHILD_EXECUTABLE_MISMATCH'}
if(![string]::Equals([string]$parent.ExecutablePath,$expectedParentExecutable,[StringComparison]::OrdinalIgnoreCase)){throw 'EXACT_PARENT_EXECUTABLE_MISMATCH'}
$handle=[TsfM3ExactProcessBarrier]::OpenProcess(0x1800,$false,[int]$child.ProcessId)
if($handle-eq[IntPtr]::Zero){throw "OPEN_PROCESS_FAILED:$([Runtime.InteropServices.Marshal]::GetLastWin32Error())"}
try{$status=[TsfM3ExactProcessBarrier]::NtSuspendProcess($handle)}finally{[void][TsfM3ExactProcessBarrier]::CloseHandle($handle)}
if($status-ne0){throw "NT_SUSPEND_PROCESS_FAILED:$status"}
[pscustomobject]@{
  process_id=[int]$child.ProcessId
  process_start_time=$childProcess.StartTime.ToUniversalTime().ToString('o')
  executable=[string]$child.ExecutablePath
  parent_process_id=[int]$child.ParentProcessId
  parent_process_start_time=$parentProcess.StartTime.ToUniversalTime().ToString('o')
  parent_executable=[string]$parent.ExecutablePath
  nt_suspend_status=$status
  suspended_at=[DateTimeOffset]::UtcNow.ToString('o')
}|ConvertTo-Json -Compress
`;
  return runPowerShellJson(powershellExe, source);
}

export function createFixtureOnlyInterruptionBarrier({
  repositoryRoot,
  powershellExe,
  owner,
  serverInstanceId,
  testRunIdentity,
  inspectProcess,
  timeoutMs = 180_000,
}) {
  const fixtureRoot = path.resolve(repositoryRoot, FIXTURE_RELATIVE_ROOT);
  const testRunRoot = path.join(fixtureRoot, testRunIdentity);
  const diagnosticPath = path.join(testRunRoot, "BARRIER_DIAGNOSTIC.json");
  const expectedCandidate = candidateIdentity(repositoryRoot);
  const installedAt = new Date().toISOString();
  const inMemoryCapability = Object.freeze(Object.create(null));
  let resolveReady;
  let rejectReady;
  let activated = false;
  let ownedRegistration = null;
  let barrier;
  let diagnostic = {
    schema_version: "tsf_hq_dispatch_m3_interruption_barrier_diagnostic_v1",
    barrier_state: "INSTALLED",
    last_reached_stage: "TEST_CAPABILITY_INSTALLED",
    fixture_identity: FIXTURE_TYPE,
    test_run_identity: testRunIdentity,
    candidate_commit: expectedCandidate.commit,
    candidate_tree: expectedCandidate.tree,
    candidate_worktree: expectedCandidate.worktree,
    expected_evidence_root: testRunRoot,
    observed_evidence_root: null,
    server_instance_id: serverInstanceId,
    executor: null,
    app_server: null,
    timeout_ms: timeoutMs,
    abort_state: false,
    failure_classification: "PENDING",
    installed_at: installedAt,
    updated_at: installedAt,
    ready_at: null,
    cleanup_at: null,
  };
  const updateDiagnostic = (stage, values = {}) => {
    diagnostic = { ...diagnostic, ...values, last_reached_stage: stage, updated_at: new Date().toISOString() };
    atomicWriteJson(diagnosticPath, diagnostic);
  };
  mkdirSync(testRunRoot, { recursive: true });
  updateDiagnostic("TEST_CAPABILITY_INSTALLED");
  const ready = new Promise((resolve, reject) => { resolveReady = resolve; rejectReady = reject; });
  barrier = createM3RealInterruptionBarrier({
    repositoryRoot,
    fixtureType: FIXTURE_TYPE,
    fixtureRoot,
    testRunIdentity,
    access: {
      permission_mode: "READ_ONLY",
      worker_tool_network_policy: "DISABLED",
      control_plane_service_network_policy: "CODEX_SERVICE_ONLY",
      allowed_writes: [],
      repository: repositoryRoot,
      product_repository_targeted: false,
    },
    inMemoryCapability,
    timeoutMs,
    onOwnedExecutor: async (context) => {
      if (activated) throw barrierError("TEST_CAPABILITY_IDENTITY_MISMATCH", "BARRIER_REACTIVATION_REJECTED");
      activated = true;
      try {
        if (context.fixture_type !== FIXTURE_TYPE || context.test_run_identity !== testRunIdentity
            || !samePath(context.fixture_root, fixtureRoot) || !samePath(context.test_run_root, testRunRoot)) {
          throw barrierError("TEST_CAPABILITY_IDENTITY_MISMATCH", "FIXTURE_OR_TEST_RUN_CONTEXT_MISMATCH");
        }
        updateDiagnostic("BARRIER_CONTEXT_VALIDATED", { observed_evidence_root: path.resolve(context.test_run_root) });
        if (!owner.ownsChild(context.executor_child.pid)) throw barrierError("APP_SERVER_CHILD_NOT_OWNED", "EXECUTOR_NOT_EXACTLY_OWNED");
        const executor = inspectProcess(context.executor_child.pid);
        if (!executor) throw barrierError("CHILD_COMPLETED_BEFORE_BARRIER", "EXECUTOR_PROCESS_GONE");
        updateDiagnostic("EXECUTOR_IDENTITY_REGISTERED", {
          executor: {
            process_id: executor.process_id,
            process_start_time: executor.process_start_time,
            executable: executor.executable,
            parent_process_id: executor.parent_process_id,
          },
        });
        const eventPath = path.resolve(context.preparation.adapter_event_path ?? "");
        const expectedEventPath = path.resolve(path.dirname(context.preparation.adapter_result_path), "ej.jsonl");
        if (!eventPath || !samePath(eventPath, expectedEventPath)) {
          throw barrierError("BARRIER_EVENT_WRITTEN_TO_WRONG_ROOT", `${eventPath}:${expectedEventPath}`);
        }
        const terminalPaths = [
          context.preparation.lifecycle_result_path,
          context.preparation.adapter_result_path,
          context.preparation.verifier_result_path,
        ];
        const expectedSpawn = {
          mission_id: context.mission_id,
          mission_revision: context.mission_revision,
          run_id: context.run_id,
          result_id: context.result_id,
          worktree: expectedCandidate.worktree,
          commit: expectedCandidate.commit,
          tree: expectedCandidate.tree,
          not_before_utc: installedAt,
        };
        updateDiagnostic("WAITING_FOR_AUTHORITATIVE_SPAWN", { adapter_event_path: eventPath });
        const spawnEvidence = await waitForAuthoritativeSpawnEvent({
          eventPath,
          expected: expectedSpawn,
          terminalPaths,
          executorChild: context.executor_child,
          timeoutMs: context.timeout_ms,
        });
        updateDiagnostic("AUTHORITATIVE_SPAWN_OBSERVED", {
          app_server: {
            process_id: spawnEvidence.app_server_process_id,
            process_start_time: spawnEvidence.app_server_process_start_time,
            executable: spawnEvidence.app_server_executable,
            parent_process_id: spawnEvidence.app_server_parent_process_id,
            parent_process_start_time: spawnEvidence.app_server_parent_process_start_time,
            parent_executable: spawnEvidence.app_server_parent_executable,
            creation_event_timestamp: spawnEvidence.creation_event_timestamp,
            launch_identity_sha256: spawnEvidence.launch_identity_sha256,
            ownership_source_sha256: spawnEvidence.ownership_source_sha256,
          },
        });
        const chain = await inspectExactAncestry({
          powershellExe,
          appServerProcessId: spawnEvidence.app_server_process_id,
          executorProcessId: context.executor_child.pid,
        });
        const appServer = chain[0];
        if (Date.parse(appServer.process_start_time) !== Date.parse(spawnEvidence.app_server_process_start_time)
            || !samePath(appServer.executable, spawnEvidence.app_server_executable)
            || Number(appServer.parent_process_id) !== Number(spawnEvidence.app_server_parent_process_id)) {
          throw barrierError("APP_SERVER_CHILD_NOT_OWNED", "AUTHORITATIVE_SPAWN_OS_IDENTITY_MISMATCH");
        }
        const registrationProcesses = chain.slice(0, -1).map((processIdentity, index) => ({
          ...processIdentity,
          parent_process_start_time: chain[index + 1].process_start_time,
          parent_executable: chain[index + 1].executable,
        }));
        const ownershipBody = {
          schema_version: "tsf_hq_dispatch_m3_exact_process_ownership_v1",
          server_instance_id: serverInstanceId,
          mission_id: context.mission_id,
          mission_revision: context.mission_revision,
          run_id: context.run_id,
          result_id: context.result_id,
          test_run_identity: testRunIdentity,
          capability_identity_sha256: barrier.capability_identity_sha256,
          executor_process_id: context.executor_child.pid,
          authoritative_spawn_sha256: spawnEvidence.ownership_source_sha256,
          process_chain: chain,
          registered_at: new Date().toISOString(),
        };
        const ownershipEvidenceSha256 = hashObject(ownershipBody);
        ownedRegistration = {
          rootProcessId: context.executor_child.pid,
          processes: registrationProcesses,
          capabilityIdentitySha256: barrier.capability_identity_sha256,
          ownershipEvidenceSha256,
          launchIdentitySha256: spawnEvidence.launch_identity_sha256,
          registrationCreatedAt: ownershipBody.registered_at,
        };
        owner.childrenStartedFromEvidence({
          ...ownedRegistration,
          serverInstanceId,
        });
        owner.reconcileOwnedProcessRegistryAndLedger();
        if (!owner.ownsChild(spawnEvidence.app_server_process_id)) {
          throw barrierError("APP_SERVER_CHILD_NOT_OWNED", "APP_SERVER_OWNER_REGISTRATION_NOT_REPRODUCIBLE");
        }
        updateDiagnostic("EXACT_PROCESS_CHAIN_REGISTERED", {
          ownership_evidence_sha256: ownershipEvidenceSha256,
          capability_identity_sha256: barrier.capability_identity_sha256,
          owned_process_chain: chain,
        });
        if (terminalPaths.some((terminalPath) => terminalPath && existsSync(terminalPath))) {
          throw barrierError("CHILD_COMPLETED_BEFORE_BARRIER", "TERMINAL_EVIDENCE_PRESENT_BEFORE_SUSPEND");
        }
        const suspended = await suspendExactAppServer({ powershellExe, spawnEvidence });
        if (suspended.nt_suspend_status !== 0
            || Date.parse(suspended.process_start_time) !== Date.parse(spawnEvidence.app_server_process_start_time)
            || !samePath(suspended.executable, spawnEvidence.app_server_executable)) {
          throw barrierError("APP_SERVER_CHILD_NOT_OWNED", "SUSPENDED_PROCESS_IDENTITY_MISMATCH");
        }
        if (terminalPaths.some((terminalPath) => terminalPath && existsSync(terminalPath))) {
          throw barrierError("CHILD_COMPLETED_BEFORE_BARRIER", "TERMINAL_EVIDENCE_PRESENT_AFTER_SUSPEND");
        }
        const body = {
          schema_version: "tsf_hq_dispatch_m3_real_interruption_barrier_ready_v2",
          fixture_type: FIXTURE_TYPE,
          fixture_root: fixtureRoot,
          test_run_identity: testRunIdentity,
          mission_id: context.mission_id,
          mission_revision: context.mission_revision,
          run_id: context.run_id,
          result_id: context.result_id,
          server_instance_id: serverInstanceId,
          capability_identity_sha256: barrier.capability_identity_sha256,
          candidate_worktree: expectedCandidate.worktree,
          candidate_commit: expectedCandidate.commit,
          candidate_tree: expectedCandidate.tree,
          owned_executor_process_id: context.executor_child.pid,
          owned_executor_start_time: executor.process_start_time,
          app_server_process_id: spawnEvidence.app_server_process_id,
          app_server_process_start_time: spawnEvidence.app_server_process_start_time,
          app_server_executable: spawnEvidence.app_server_executable,
          app_server_parent_process_id: spawnEvidence.app_server_parent_process_id,
          app_server_parent_process_start_time: spawnEvidence.app_server_parent_process_start_time,
          app_server_parent_executable: spawnEvidence.app_server_parent_executable,
          launch_identity_sha256: spawnEvidence.launch_identity_sha256,
          authoritative_spawn_sha256: spawnEvidence.ownership_source_sha256,
          ownership_evidence_sha256: ownershipEvidenceSha256,
          owned_process_chain: chain,
          hook_point: BARRIER_HOOK_POINT,
          ready_at: new Date().toISOString(),
          terminal_result_present: false,
          verifier_result_present: false,
          admission_receipt_present: false,
        };
        const evidence = { ...body, evidence_hash: hashObject(body) };
        const evidencePath = path.join(context.test_run_root, "BARRIER_READY.json");
        atomicWriteJson(evidencePath, evidence);
        updateDiagnostic("BARRIER_READY", {
          barrier_state: "READY",
          failure_classification: "NONE",
          ready_at: evidence.ready_at,
          barrier_ready_path: evidencePath,
          barrier_ready_sha256: hashObject(evidence),
        });
        const value = { ...evidence, evidence_path: evidencePath, diagnostic_path: diagnosticPath };
        resolveReady(value);
        return value;
      } catch (error) {
        const classification = error?.classification ?? String(error?.message ?? "OTHER_EXACTLY_PROVEN_CAUSE").split(":", 1)[0];
        updateDiagnostic("BARRIER_FAILED_CLOSED", {
          barrier_state: "FAILED",
          abort_state: true,
          failure_classification: classification || "OTHER_EXACTLY_PROVEN_CAUSE",
          failure_detail: error instanceof Error ? error.message : String(error),
        });
        rejectReady(error);
        throw error;
      }
    },
    onOwnedCleanup: async () => {
      if (!ownedRegistration) {
        updateDiagnostic("CLEANUP_NO_REGISTERED_PROCESS", { cleanup_at: new Date().toISOString() });
        return { owned_processes: [], dispositions: [] };
      }
      const dispositions = owner.childrenExitedFromEvidence(ownedRegistration);
      const cleaned = ownedRegistration.processes.map((item) => item.process_id);
      ownedRegistration = null;
      updateDiagnostic("EXACT_OWNED_PROCESS_CLEANUP_CONFIRMED_PENDING_SERVER_FINALIZATION", {
        barrier_state: diagnostic.barrier_state === "FAILED" ? "FAILED_CLEANED" : "READY_CLEANUP_PENDING_SERVER_FINALIZATION",
        cleanup_at: new Date().toISOString(),
        owned_cleanup_process_ids: cleaned,
        owned_cleanup_dispositions: dispositions,
      });
      return { owned_processes: cleaned, dispositions };
    },
  });
  return {
    barrier,
    capability: inMemoryCapability,
    ready,
    fixtureRoot,
    testRunRoot,
    diagnosticPath,
    finalizeServerCleanup({ stopRecordPath, cleanupSummary }) {
      if (diagnostic.barrier_state !== "READY_CLEANUP_PENDING_SERVER_FINALIZATION"
          || !stopRecordPath || !existsSync(stopRecordPath)
          || cleanupSummary?.status !== "CLEANUP_CONFIRMED") {
        updateDiagnostic("SERVER_FINALIZATION_FAILED_CLOSED", { barrier_state: "FAILED_CLEANED", failure_classification: "SERVER_FINALIZATION_NOT_CONFIRMED" });
        throw barrierError("OTHER_EXACTLY_PROVEN_CAUSE", "SERVER_FINALIZATION_NOT_CONFIRMED");
      }
      updateDiagnostic("EXACT_OWNED_PROCESS_AND_SERVER_CLEANUP_CONFIRMED", {
        barrier_state: "READY_CLEANED", stop_record_path: stopRecordPath,
        stop_record_sha256: hashFile(stopRecordPath), cleanup_summary_sha256: cleanupSummary.cleanup_summary_sha256,
        server_finalized_at: new Date().toISOString(),
      });
      return diagnostic;
    },
  };
}
