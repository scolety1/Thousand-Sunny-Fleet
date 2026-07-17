import { spawn } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, renameSync, writeFileSync } from "node:fs";
import path from "node:path";
import {
  createM3RealInterruptionBarrier,
} from "../../tools/hq-dispatch/v1/mission-relay.mjs";

export const FIXTURE_TYPE = "TSF_HQ_DISPATCH_M3_REAL_INTERRUPTION_FIXTURE_V1";
export const FIXTURE_RELATIVE_ROOT = path.join(".codex-local", "fixtures", "hq-dispatch-m3-real-interruption-v1");
export const BARRIER_HOOK_POINT = "REAL_APP_SERVER_PROCESS_SUSPENDED_BEFORE_TERMINAL_RESULT";

function hashObject(value) {
  return createHash("sha256").update(JSON.stringify(value)).digest("hex");
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

function monitorAndSuspendRealAppServer({ powershellExe, executorProcessId, timeoutMs }) {
  const script = `
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TsfM3ProcessBarrier {
  [DllImport("kernel32.dll", SetLastError=true)] public static extern IntPtr OpenProcess(uint access, bool inherit, int processId);
  [DllImport("kernel32.dll", SetLastError=true)] public static extern bool CloseHandle(IntPtr handle);
  [DllImport("ntdll.dll")] public static extern int NtSuspendProcess(IntPtr handle);
}
'@
$root=${Number(executorProcessId)}
$deadline=[DateTimeOffset]::UtcNow.AddMilliseconds(${Number(timeoutMs)})
while([DateTimeOffset]::UtcNow -lt $deadline){
  $rows=@(Get-CimInstance Win32_Process -ErrorAction Stop)
  $byId=@{}
  foreach($row in $rows){$byId[[int]$row.ProcessId]=$row}
  foreach($candidate in @($rows|Where-Object {[string]$_.Name -ieq 'codex.exe'})){
    $cursor=$candidate
    $descendant=$false
    for($depth=0;$depth -lt 64 -and $null-ne$cursor;$depth++){
      if([int]$cursor.ParentProcessId -eq $root){$descendant=$true;break}
      $cursor=$byId[[int]$cursor.ParentProcessId]
    }
    if(!$descendant){continue}
    $handle=[TsfM3ProcessBarrier]::OpenProcess(0x1800,$false,[int]$candidate.ProcessId)
    if($handle -eq [IntPtr]::Zero){throw "OPEN_PROCESS_FAILED:$([Runtime.InteropServices.Marshal]::GetLastWin32Error())"}
    try{$status=[TsfM3ProcessBarrier]::NtSuspendProcess($handle)}finally{[void][TsfM3ProcessBarrier]::CloseHandle($handle)}
    if($status -ne 0){throw "NT_SUSPEND_PROCESS_FAILED:$status"}
    $observed=Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$candidate.ProcessId)" -ErrorAction Stop
    [pscustomobject]@{
      schema_version='tsf_hq_dispatch_m3_suspended_app_server_observation_v1'
      executor_process_id=$root
      app_server_process_id=[int]$observed.ProcessId
      app_server_parent_process_id=[int]$observed.ParentProcessId
      app_server_start_time=([datetime]$observed.CreationDate).ToUniversalTime().ToString('o')
      app_server_executable=[string]$observed.ExecutablePath
      nt_suspend_status=$status
      observed_at=[DateTimeOffset]::UtcNow.ToString('o')
    }|ConvertTo-Json -Compress
    exit 0
  }
  Start-Sleep -Milliseconds 5
}
Write-Error 'REAL_APP_SERVER_OBSERVATION_TIMEOUT'
exit 124
`;
  return new Promise((resolve, reject) => {
    const child = spawn(powershellExe, ["-NoLogo", "-NoProfile", "-NonInteractive", "-EncodedCommand", encodedPowerShell(script)], {
      detached: false,
      windowsHide: true,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.on("data", (chunk) => { stdout += chunk.toString("utf8"); });
    child.stderr.on("data", (chunk) => { stderr += chunk.toString("utf8"); });
    child.once("error", reject);
    child.once("close", (code) => {
      if (code !== 0) {
        reject(new Error(`M3_REAL_APP_SERVER_BARRIER_MONITOR_FAILED:${code}:${stderr.trim()}`));
        return;
      }
      try { resolve(JSON.parse(stdout.trim().split(/\r?\n/).at(-1))); }
      catch (error) { reject(new Error(`M3_REAL_APP_SERVER_BARRIER_OUTPUT_INVALID:${error.message}`)); }
    });
  });
}

export function createFixtureOnlyInterruptionBarrier({
  repositoryRoot,
  powershellExe,
  owner,
  serverInstanceId,
  testRunIdentity,
  inspectProcess,
}) {
  const fixtureRoot = path.resolve(repositoryRoot, FIXTURE_RELATIVE_ROOT);
  const inMemoryCapability = Object.freeze(Object.create(null));
  let resolveReady;
  let rejectReady;
  let activated = false;
  const ready = new Promise((resolve, reject) => { resolveReady = resolve; rejectReady = reject; });
  const barrier = createM3RealInterruptionBarrier({
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
    onOwnedExecutor: async (context) => {
      if (activated) throw new Error("M3_INTERRUPTION_BARRIER_REACTIVATION_REJECTED");
      activated = true;
      try {
        if (context.fixture_type !== FIXTURE_TYPE || context.test_run_identity !== testRunIdentity
            || path.resolve(context.fixture_root) !== fixtureRoot
            || path.resolve(context.test_run_root) !== path.join(fixtureRoot, testRunIdentity)) {
          throw new Error("M3_INTERRUPTION_BARRIER_CONTEXT_MISMATCH");
        }
        if (!owner.ownsChild(context.executor_child.pid)) throw new Error("M3_INTERRUPTION_EXECUTOR_NOT_EXACTLY_OWNED");
        const executor = inspectProcess(context.executor_child.pid);
        if (!executor) throw new Error("M3_INTERRUPTION_EXECUTOR_PROCESS_GONE");
        const observation = await monitorAndSuspendRealAppServer({
          powershellExe,
          executorProcessId: context.executor_child.pid,
          timeoutMs: context.timeout_ms,
        });
        const appServer = inspectProcess(observation.app_server_process_id);
        if (!appServer || Date.parse(appServer.process_start_time) !== Date.parse(observation.app_server_start_time)
            || path.resolve(appServer.executable).toLowerCase() !== path.resolve(observation.app_server_executable).toLowerCase()) {
          throw new Error("M3_INTERRUPTION_APP_SERVER_IDENTITY_MISMATCH");
        }
        for (const terminalPath of [
          context.preparation.lifecycle_result_path,
          context.preparation.adapter_result_path,
          context.preparation.verifier_result_path,
        ]) {
          if (terminalPath && existsSync(terminalPath)) throw new Error("M3_INTERRUPTION_TERMINAL_EVIDENCE_ALREADY_EXISTS");
        }
        const body = {
          schema_version: "tsf_hq_dispatch_m3_real_interruption_barrier_ready_v1",
          fixture_type: FIXTURE_TYPE,
          fixture_root: fixtureRoot,
          test_run_identity: testRunIdentity,
          mission_id: context.mission_id,
          mission_revision: context.mission_revision,
          run_id: context.run_id,
          result_id: context.result_id,
          server_instance_id: serverInstanceId,
          owned_executor_process_id: context.executor_child.pid,
          owned_executor_start_time: executor.process_start_time,
          app_server_process_id: observation.app_server_process_id,
          app_server_process_start_time: observation.app_server_start_time,
          app_server_executable: observation.app_server_executable,
          hook_point: BARRIER_HOOK_POINT,
          ready_at: new Date().toISOString(),
          terminal_result_present: false,
          verifier_result_present: false,
          admission_receipt_present: false,
        };
        const evidence = { ...body, evidence_hash: hashObject(body) };
        const evidencePath = path.join(context.test_run_root, "BARRIER_READY.json");
        atomicWriteJson(evidencePath, evidence);
        const value = { ...evidence, evidence_path: evidencePath };
        resolveReady(value);
        return value;
      } catch (error) {
        rejectReady(error);
        throw error;
      }
    },
  });
  return { barrier, ready, fixtureRoot, testRunRoot: path.join(fixtureRoot, testRunIdentity) };
}
