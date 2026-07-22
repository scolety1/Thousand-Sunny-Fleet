[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory)][string]$ScriptPath,
    [Parameter(Mandatory)][string]$EvidenceRoot,
    [string[]]$ScriptArguments = @(),
    [ValidateRange(0, 6)][int]$LadderLevel = 0,
    [ValidateSet('', 'safe', 'current-handler-close')][string]$LadderVariant = '',
    [ValidateRange(10, 900)][int]$TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$scriptFull = [IO.Path]::GetFullPath((Join-Path $repo $ScriptPath))
$evidenceFull = [IO.Path]::GetFullPath($EvidenceRoot)
if (!(Test-Path -LiteralPath $scriptFull -PathType Leaf)) { throw "NATIVE_DIAGNOSTIC_SCRIPT_MISSING:$scriptFull" }
if (Test-Path -LiteralPath $evidenceFull) { throw "NATIVE_DIAGNOSTIC_EVIDENCE_ROOT_ALREADY_EXISTS:$evidenceFull" }
New-Item -ItemType Directory -Path $evidenceFull | Out-Null
$reportRoot = Join-Path $evidenceFull 'node-reports'
New-Item -ItemType Directory -Path $reportRoot | Out-Null
$stdoutPath = Join-Path $evidenceFull 'stdout.txt'
$stderrPath = Join-Path $evidenceFull 'stderr.txt'
$processTracePath = Join-Path $evidenceFull 'NATIVE_TEST_PROCESS_TRACE.json'
$resultPath = Join-Path $evidenceFull 'NATIVE_TEST_RESULT.json'
$blockerPath = Join-Path $evidenceFull 'BLOCKER.json'
$receiptPath = Join-Path $evidenceFull 'NATIVE_TEST_WRAPPER_RECEIPT.json'
$stagePath = Join-Path $evidenceFull 'NATIVE_TEST_STAGE_TRACE.json'
$node = (Get-Command node.exe -ErrorAction Stop).Source
$nodeVersion = (& $node --version).Trim()
$effectiveScriptArguments = @($ScriptArguments)
if ($LadderLevel -gt 0) { $effectiveScriptArguments += "--level=$LadderLevel" }
if (![string]::IsNullOrWhiteSpace($LadderVariant)) { $effectiveScriptArguments += "--variant=$LadderVariant" }
$diagnosticArgs = @(
    '--report-on-fatalerror',
    '--report-uncaught-exception',
    '--trace-uncaught',
    '--trace-exit',
    "--report-directory=$reportRoot",
    $scriptFull
) + $effectiveScriptArguments
$started = (Get-Date).ToUniversalTime()
$priorExists = Test-Path Env:TSF_NATIVE_TEST_EVIDENCE_ROOT
$priorValue = $env:TSF_NATIVE_TEST_EVIDENCE_ROOT
$child = $null
try {
    $env:TSF_NATIVE_TEST_EVIDENCE_ROOT = $evidenceFull
    $child = Start-Process -FilePath $node -ArgumentList $diagnosticArgs -WorkingDirectory $repo -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
} finally {
    if ($priorExists) { $env:TSF_NATIVE_TEST_EVIDENCE_ROOT = $priorValue } else { Remove-Item Env:TSF_NATIVE_TEST_EVIDENCE_ROOT -ErrorAction SilentlyContinue }
}
$childStart = $null
try { $childStart = $child.StartTime.ToUniversalTime().ToString('o') } catch { $childStart = 'START_TIME_NOT_RELIABLY_OBSERVED' }
$initial = [ordered]@{
    schema_version = 'tsf_native_test_process_trace_v1'
    wrapper_process_id = $PID
    child_process_id = $child.Id
    child_process_start_time = $childStart
    executable = $node
    node_version = $nodeVersion
    working_directory = $repo
    command = @($node) + $diagnosticArgs
    environment_key_names = @('TSF_NATIVE_TEST_EVIDENCE_ROOT')
    environment_values_recorded = $false
    started_utc = $started.ToString('o')
    timeout_seconds = $TimeoutSeconds
    initial_descendants = @()
    final_descendants = @()
    timeout_action = $null
}
$initial | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $processTracePath -Encoding UTF8
$timedOut = !$child.WaitForExit($TimeoutSeconds * 1000)
if ($timedOut) {
    $initial.timeout_action = 'EXACT_CHILD_STOP_PROCESS_BY_PID'
    Stop-Process -Id $child.Id -Force -ErrorAction SilentlyContinue
    $child.WaitForExit()
}
$finished = (Get-Date).ToUniversalTime()
$exitCode = [int]$child.ExitCode
$exitUnsigned = [BitConverter]::ToUInt32([BitConverter]::GetBytes([int32]$exitCode), 0)
$exitHex = ('0x{0:X8}' -f $exitUnsigned)
$initial.finished_utc = $finished.ToString('o')
$initial.timed_out = $timedOut
$initial.numeric_exit_code = $exitCode
$initial.exit_code_hex = $exitHex
$initial.child_has_exited = $child.HasExited
$initial | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $processTracePath -Encoding UTF8
$lastStage = $null
if (Test-Path -LiteralPath $stagePath) {
    try { $lastStage = @((Get-Content -LiteralPath $stagePath -Raw | ConvertFrom-Json).events)[-1].stage_id } catch { $lastStage = 'NATIVE_STAGE_TRACE_PARSE_FAILED' }
}
$windowEvents = @()
try {
    $windowEvents = @(Get-WinEvent -FilterHashtable @{ LogName = 'Application'; StartTime = $started.AddSeconds(-2); EndTime = $finished.AddSeconds(5) } -ErrorAction Stop |
        Where-Object { $_.ProviderName -match 'Application Error|Windows Error Reporting' -or $_.Message -match "node\.exe|$($child.Id)|c0000409|0xc0000409" } |
        Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message)
} catch {
    $windowEvents = @([ordered]@{ classification = 'WINDOWS_EVENT_QUERY_UNAVAILABLE'; error = $_.Exception.Message })
}
$windowPath = Join-Path $evidenceFull 'WINDOWS_EVENT_CORRELATION.json'
$windowEvents | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $windowPath -Encoding UTF8
$sha = { param([string]$Path) if (Test-Path -LiteralPath $Path) { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant() } else { $null } }
$receipt = [ordered]@{
    schema_version = 'tsf_native_test_wrapper_receipt_v1'
    status = if ($exitCode -eq 0 -and !$timedOut) { 'PASS' } else { 'FAIL' }
    child_process_id = $child.Id
    child_process_start_time = $childStart
    numeric_exit_code = $exitCode
    exit_code_hex = $exitHex
    timed_out = $timedOut
    started_utc = $started.ToString('o')
    finished_utc = $finished.ToString('o')
    last_durable_child_stage = $lastStage
    stdout_path = $stdoutPath
    stdout_sha256 = & $sha $stdoutPath
    stderr_path = $stderrPath
    stderr_sha256 = & $sha $stderrPath
    stage_trace_path = $stagePath
    stage_trace_sha256 = & $sha $stagePath
    process_trace_path = $processTracePath
    windows_event_path = $windowPath
    windows_event_sha256 = & $sha $windowPath
    report_files = @(Get-ChildItem -LiteralPath $reportRoot -File -ErrorAction SilentlyContinue | ForEach-Object { [ordered]@{ path = $_.FullName; sha256 = & $sha $_.FullName; length = $_.Length } })
}
$receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $receiptPath -Encoding UTF8
if (!(Test-Path -LiteralPath $resultPath)) {
    $result = [ordered]@{
        schema_version = 'tsf_native_test_result_v1'
        status = if ($exitCode -eq 0 -and !$timedOut) { 'PASS' } else { 'FAIL' }
        numeric_exit_code = $exitCode
        exit_code_hex = $exitHex
        timed_out = $timedOut
        child_process_id = $child.Id
        child_process_start_time = $childStart
        last_completed_stage = $lastStage
        classification = if ($exitHex -eq '0xC0000409') { 'WINDOWS_NATIVE_FAST_FAIL_0xC0000409' } elseif ($timedOut) { 'NATIVE_TEST_TIMEOUT' } else { 'NATIVE_TEST_PROCESS_EXIT' }
        wrapper_receipt_path = $receiptPath
        recorded_at = (Get-Date).ToUniversalTime().ToString('o')
    }
    $result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resultPath -Encoding UTF8
}
if ($exitCode -ne 0 -or $timedOut) {
    $blocker = [ordered]@{
        schema_version = 'tsf_native_test_blocker_v1'
        status = 'BLOCKED'
        classification = if ($exitHex -eq '0xC0000409') { 'WINDOWS_NATIVE_FAST_FAIL_0xC0000409' } elseif ($timedOut) { 'NATIVE_TEST_TIMEOUT' } else { 'NATIVE_TEST_PROCESS_EXIT' }
        numeric_exit_code = $exitCode
        exit_code_hex = $exitHex
        last_completed_stage = $lastStage
        child_process_id = $child.Id
        evidence = $receiptPath
    }
    $blocker | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $blockerPath -Encoding UTF8
}
$receipt | ConvertTo-Json -Depth 8
if ($exitCode -ne 0 -or $timedOut) { exit 1 }
