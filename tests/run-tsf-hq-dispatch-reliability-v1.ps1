[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$EvidenceRoot
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$utf8NoBom = [Text.UTF8Encoding]::new($false)
if (-not $EvidenceRoot) {
    $stamp = [datetimeoffset]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    $EvidenceRoot = Join-Path $repoRoot ".codex-local\evidence\m3-validation\$stamp-$PID"
}
$EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
[IO.Directory]::CreateDirectory($EvidenceRoot) | Out-Null
$rows = [Collections.Generic.List[object]]::new()
$hasFailure = $false
function Add-Result([string]$Check,[string]$Status,[string]$Evidence) {
    $rows.Add([pscustomobject]@{
        check = $Check
        status = $Status
        exit_code = 0
        evidence = $Evidence
        stdout_path = $null
        stdout_sha256 = $null
        stderr_path = $null
        stderr_sha256 = $null
    }) | Out-Null
}
function Invoke-Checked([string]$Name,[string]$File,[string[]]$Arguments=@()) {
    $safeName = $Name -replace '[^A-Za-z0-9_.-]', '_'
    $stdoutPath = Join-Path $EvidenceRoot "$safeName.stdout.txt"
    $stderrPath = Join-Path $EvidenceRoot "$safeName.stderr.txt"
    $exitCode = -1
    $launchError = $null
    try {
        $process = Start-Process -FilePath $File -ArgumentList $Arguments -WorkingDirectory $repoRoot -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
        $exitCode = [int]$process.ExitCode
    } catch {
        $launchError = $_.Exception.ToString()
        if (-not (Test-Path -LiteralPath $stdoutPath)) { [IO.File]::WriteAllText($stdoutPath, '', $utf8NoBom) }
        if (-not (Test-Path -LiteralPath $stderrPath)) { [IO.File]::WriteAllText($stderrPath, $launchError, $utf8NoBom) }
    }
    if (-not (Test-Path -LiteralPath $stdoutPath)) { [IO.File]::WriteAllText($stdoutPath, '', $utf8NoBom) }
    if (-not (Test-Path -LiteralPath $stderrPath)) { [IO.File]::WriteAllText($stderrPath, '', $utf8NoBom) }
    $stdout = [IO.File]::ReadAllText($stdoutPath)
    $stderr = [IO.File]::ReadAllText($stderrPath)
    $status = if ($exitCode -eq 0 -and -not $launchError) { 'PASS' } else { 'FAIL' }
    if ($status -eq 'FAIL') { $script:hasFailure = $true }
    $rows.Add([pscustomobject]@{
        check = $Name
        status = $status
        exit_code = $exitCode
        evidence = $stdout.Trim()
        stdout_path = $stdoutPath
        stdout_sha256 = (Get-FileHash -LiteralPath $stdoutPath -Algorithm SHA256).Hash.ToLowerInvariant()
        stderr = $stderr.Trim()
        stderr_path = $stderrPath
        stderr_sha256 = (Get-FileHash -LiteralPath $stderrPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }) | Out-Null
}

$powerShellFiles = @(
    'tools/hq-dispatch/v1/Test-TsfHqDispatchDoctorV1.ps1',
    'tools/hq-dispatch/v1/Start-TsfHqDispatchV1.ps1',
    'tools/hq-dispatch/v1/Stop-TsfHqDispatchV1.ps1',
    'tools/hq-dispatch/v1/Start-TsfHqDispatchDemoV1.ps1',
    'tools/hq-dispatch/v1/New-TsfHqDispatchGovernedMission.ps1',
    'tools/hq-dispatch/v1/Invoke-TsfHqDispatchTimResponse.ps1',
    'tools/hq-dispatch/v1/Invoke-TsfHqDispatchQueueReconcileV1.ps1'
)
foreach ($relative in $powerShellFiles) {
    $tokens=$null;$errors=$null
    [Management.Automation.Language.Parser]::ParseFile((Join-Path $repoRoot $relative),[ref]$tokens,[ref]$errors)|Out-Null
    if ($errors.Count) {
        $hasFailure = $true
        Add-Result "powershell_syntax:$relative" 'FAIL' ($errors.Message -join '; ')
    }
}
if (-not @($rows | Where-Object { $_.check -like 'powershell_syntax:*' -and $_.status -eq 'FAIL' }).Count) {
    Add-Result 'powershell_syntax' 'PASS' ($powerShellFiles -join ', ')
}

$nodeFiles = @(
    'tools/hq-dispatch/v1/server.mjs',
    'tools/hq-dispatch/v1/mission-relay.mjs',
    'tools/hq-dispatch/v1/reliability.mjs',
    'tools/hq-dispatch/v1/reliability-cli.mjs',
    'tools/hq-dispatch/v1/demo.mjs',
    'tools/hq-dispatch/v1/demo-fixtures.mjs',
    'tools/hq-dispatch/v1/public/app.js',
    'tests/test-tsf-hq-dispatch-reliability-v1.mjs',
    'tests/test-tsf-hq-dispatch-start-stop-v1.mjs',
    'tests/test-tsf-hq-dispatch-demo-v1.mjs',
    'tests/test-tsf-hq-dispatch-restart-tim-v1.mjs',
    'tests/test-tsf-hq-dispatch-interruption-barrier-safety-v1.mjs',
    'tests/support/tsf-hq-dispatch-m3-real-interruption-barrier.mjs',
    'tests/test-tsf-hq-dispatch-real-reliability-v1.mjs'
)
foreach ($relative in $nodeFiles) { Invoke-Checked "node_syntax:$relative" 'node' @('--check',(Join-Path $repoRoot $relative)) }

$jsonFiles = @(
    'fleet/control/hq-dispatch/hq-dispatch-process-owner.schema.v1.json',
    'fleet/control/hq-dispatch/hq-dispatch-interruption-evidence.schema.v1.json',
    'fleet/control/hq-dispatch/hq-dispatch-recovery-receipt.schema.v1.json'
)
foreach ($relative in $jsonFiles) { Get-Content -LiteralPath (Join-Path $repoRoot $relative) -Raw | ConvertFrom-Json | Out-Null }
Add-Result 'json_parseability' 'PASS' ($jsonFiles -join ', ')

Invoke-Checked 'failure_injection_matrix_21' 'node' @('tests/test-tsf-hq-dispatch-reliability-v1.mjs')
Invoke-Checked 'start_doctor_stop_fixture_proof' 'node' @('tests/test-tsf-hq-dispatch-start-stop-v1.mjs')
Invoke-Checked 'deterministic_demo_m1_m2a_m2b' 'node' @('tests/test-tsf-hq-dispatch-demo-v1.mjs')
Invoke-Checked 'restart_tim_required_reconciliation' 'node' @('tests/test-tsf-hq-dispatch-restart-tim-v1.mjs')
Invoke-Checked 'fixture_only_interruption_barrier_safety' 'node' @('tests/test-tsf-hq-dispatch-interruption-barrier-safety-v1.mjs')
Invoke-Checked 'milestone_2a_regression' 'node' @('tests/test-tsf-hq-dispatch-request-result-relay-v1.mjs')
Invoke-Checked 'milestone_2b_http_regression' 'node' @('tests/test-tsf-hq-dispatch-tim-relay-http-v1.mjs')
Invoke-Checked 'milestone_2b_canonical_regression' 'node' @('tests/test-tsf-hq-dispatch-tim-relay-canonical-v1.mjs')
Invoke-Checked 'git_diff_check' 'git' @('-C', $repoRoot, 'diff', '--check')

$result = [pscustomobject][ordered]@{
    schema_version = 'tsf_hq_dispatch_reliability_validation_v1'
    generated_at = [datetimeoffset]::UtcNow.ToString('o')
    status = if ($hasFailure) { 'FAIL' } else { 'PASS' }
    evidence_root = $EvidenceRoot
    checks = @($rows)
    background_process_created = $false
    scheduled_task_created = $false
    service_created = $false
    product_repository_used = $false
    plugin_used = $false
    credential_used = $false
    worker_tool_network_used = $false
    milestone_4_acceptance_started = $false
}
$summaryPath = Join-Path $EvidenceRoot 'validation-summary.json'
$summaryJson = $result | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText($summaryPath, $summaryJson, $utf8NoBom)
$summaryJson
if ($hasFailure) { exit 1 }
