[CmdletBinding()]
param([switch]$StaticOnly)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$sha256 = [System.Security.Cryptography.SHA256]::Create()

function Get-TextSha256 {
    param([AllowEmptyString()][string]$Text)
    $bytes = $utf8NoBom.GetBytes($Text)
    try { return ([System.BitConverter]::ToString($sha256.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { }
}

function Invoke-CapturedValidation {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [Parameter(Mandatory = $true)][string]$FileName,
        [Parameter(Mandatory = $true)][string]$Arguments,
        [Parameter(Mandatory = $true)][string]$Command
    )
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $FileName
    $info.Arguments = $Arguments
    $info.WorkingDirectory = $repositoryRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.EnvironmentVariables['TSF_NETWORK_MODE'] = 'DISABLED'
    $startedAt = [DateTimeOffset]::UtcNow
    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $info
    if (-not $process.Start()) { throw "VALIDATION_PROCESS_START_FAILED:$Id" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $finishedAt = [DateTimeOffset]::UtcNow
    $assertions = 0
    foreach ($match in [regex]::Matches($stdout, '"assertions"\s*:\s*(\d+)')) {
        $assertions += [int]$match.Groups[1].Value
    }
    if ($assertions -eq 0) {
        foreach ($match in [regex]::Matches($stdout, 'assertions=(\d+)')) {
            $assertions += [int]$match.Groups[1].Value
        }
    }
    if ($assertions -eq 0) {
        $testCount = [regex]::Match($stdout, '(?m)^tests\s*:\s*(\d+)')
        if ($testCount.Success) { $assertions = [int]$testCount.Groups[1].Value }
    }
    if ($assertions -eq 0) {
        $assertions = [regex]::Matches($stdout, '(?m)^PASS(?:ED)?(?:\s|:)').Count
    }
    $evidenceSummary = $null
    foreach ($line in @($stdout.Trim().Split("`n") | Where-Object { $_.Trim() } | Select-Object -Last 4)) {
        try {
            $candidate = $line.Trim() | ConvertFrom-Json
            if ($candidate.schema_version -like 'tsf_hq_dispatch_tim_relay_*') { $evidenceSummary = $candidate }
        } catch { }
    }
    [pscustomobject]@{
        id = $Id
        command = $Command
        started_at_utc = $startedAt.ToString('o')
        finished_at_utc = $finishedAt.ToString('o')
        duration_ms = [int][Math]::Round(($finishedAt - $startedAt).TotalMilliseconds)
        exit_code = $process.ExitCode
        assertions = $assertions
        stdout_sha256 = Get-TextSha256 -Text $stdout
        stderr_sha256 = Get-TextSha256 -Text $stderr
        stdout_bytes = $utf8NoBom.GetByteCount($stdout)
        stderr_bytes = $utf8NoBom.GetByteCount($stderr)
        status = if ($process.ExitCode -eq 0) { 'PASS' } else { 'FAIL' }
        evidence_summary = $evidenceSummary
    }
}

$results = [System.Collections.Generic.List[object]]::new()
$node = (Get-Command node.exe -ErrorAction Stop).Source
if (-not $StaticOnly) {
    $powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $results.Add((Invoke-CapturedValidation -Id 'M2B-CANONICAL' -FileName $node -Arguments 'tests/test-tsf-hq-dispatch-tim-relay-canonical-v1.mjs' -Command 'node tests/test-tsf-hq-dispatch-tim-relay-canonical-v1.mjs'))
    $results.Add((Invoke-CapturedValidation -Id 'M2B-HTTP-UI' -FileName $node -Arguments 'tests/test-tsf-hq-dispatch-tim-relay-http-v1.mjs' -Command 'node tests/test-tsf-hq-dispatch-tim-relay-http-v1.mjs'))
    $results.Add((Invoke-CapturedValidation -Id 'M2A-NODE-REGRESSION' -FileName $node -Arguments '--test tests/test-tsf-hq-dispatch-exact-response-adapter-v1.mjs tests/test-tsf-hq-dispatch-request-result-relay-v1.mjs' -Command 'node --test tests/test-tsf-hq-dispatch-exact-response-adapter-v1.mjs tests/test-tsf-hq-dispatch-request-result-relay-v1.mjs'))

    $powerShellTests = @(
        @('OPTIONAL-LIFECYCLE', 'tests/run-tsf-optional-lifecycle-argument-tests.ps1'),
        @('EXACT-RESULT-EVIDENCE', 'tests/run-tsf-hq-dispatch-exact-result-evidence-tests.ps1'),
        @('MINIMUM-KERNEL', 'tests/run-minimum-viable-kernel-tests.ps1'),
        @('MISSION-QUEUE', 'tests/run-tsf-mission-queue-tests.ps1'),
        @('PROJECT-MAIN-BOT', 'tests/run-project-main-bot-role-foundation-tests.ps1'),
        @('SELF-HOSTED-RECOVERY', 'tests/run-tsf-self-hosted-lifecycle-recovery-tests.ps1'),
        @('FINAL-THREE-AUTHORITY', 'tests/run-tsf-final-three-authority-tests.ps1')
    )
    foreach ($entry in $powerShellTests) {
        $scriptPath = Join-Path $repositoryRoot $entry[1]
        $args = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`""
        $command = "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $($entry[1])"
        $results.Add((Invoke-CapturedValidation -Id $entry[0] -FileName $powershell -Arguments $args -Command $command))
    }
}

$staticStartedAt = [DateTimeOffset]::UtcNow
$staticLines = [System.Collections.Generic.List[string]]::new()
$staticAssertions = 0
function Confirm-Static {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "STATIC_VALIDATION_FAILED:$Message" }
    $script:staticAssertions++
    $script:staticLines.Add("PASS: $Message")
}

$changed = @(& git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot diff --name-only HEAD; & git -C $repositoryRoot ls-files --others --exclude-standard)
$changed = @($changed | Where-Object { $_ } | Sort-Object -Unique)
$allowedPrefixes = @('docs/hq/enforcement_kernel/minimum_viable_local_tsf_enforcement_kernel_v1/', 'docs/hq/tsf_hq_dispatch_tim_relay_v1_20260715/', 'docs/hq/tsf_v1_general_result_intent_fidelity_hotfix_v1_20260722/', 'fleet/control/', 'tests/', 'tools/')
foreach ($relative in $changed) {
    Confirm-Static -Condition (@($allowedPrefixes | Where-Object { $relative.Replace('\', '/').StartsWith($_) }).Count -gt 0) -Message "protected-path diff permits $relative"
    Confirm-Static -Condition ((Join-Path $repositoryRoot $relative).Length -lt 240) -Message "source path remains below 240 characters: $relative"
}

$diffCheck = & git -c core.autocrlf=false -c core.safecrlf=false -C $repositoryRoot diff --check 2>&1
Confirm-Static -Condition ($LASTEXITCODE -eq 0) -Message 'git diff --check is clean'

$nodeFiles = @($changed | Where-Object { $_ -match '\.(mjs|js)$' })
foreach ($relative in $nodeFiles) {
    $syntax = & $node --check (Join-Path $repositoryRoot $relative) 2>&1
    Confirm-Static -Condition ($LASTEXITCODE -eq 0) -Message "Node syntax parses: $relative"
}

$powerShellFiles = @(& git -C $repositoryRoot ls-files '*.ps1'; & git -C $repositoryRoot ls-files --others --exclude-standard '*.ps1') | Sort-Object -Unique
foreach ($relative in $powerShellFiles) {
    $tokens = $null
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repositoryRoot $relative), [ref]$tokens, [ref]$errors)
    Confirm-Static -Condition (@($errors).Count -eq 0) -Message "PowerShell parses: $relative"
}

$jsonFiles = @(& git -C $repositoryRoot ls-files '*.json'; & git -C $repositoryRoot ls-files --others --exclude-standard '*.json') | Sort-Object -Unique
foreach ($relative in $jsonFiles) {
    try { [void](Get-Content -LiteralPath (Join-Path $repositoryRoot $relative) -Raw | ConvertFrom-Json) }
    catch { throw "STATIC_VALIDATION_FAILED:JSON parses:$relative" }
    $staticAssertions++
}
$staticLines.Add("PASS: JSON validation parsed $($jsonFiles.Count) files")

$csvFiles = @(& git -C $repositoryRoot ls-files '*.csv'; & git -C $repositoryRoot ls-files --others --exclude-standard '*.csv') | Sort-Object -Unique
foreach ($relative in $csvFiles) {
    try { [void](Import-Csv -LiteralPath (Join-Path $repositoryRoot $relative)) }
    catch { throw "STATIC_VALIDATION_FAILED:CSV parses:$relative" }
    $staticAssertions++
}
$staticLines.Add("PASS: CSV validation parsed $($csvFiles.Count) files")

$allChangedText = ($changed -join "`n")
Confirm-Static -Condition (-not [regex]::IsMatch($allChangedText, '(?i)(plugin\.json|plugins?/|nytheria|private.?lens|career.?hq|houseos|tsf-nwr|\bnwr\b)')) -Message 'plugin-free and unrelated-product changed-path boundary holds'
Confirm-Static -Condition ((Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools/hq-dispatch/v1/server.mjs') -Raw) -match 'plugin_access_enabled:\s*false') -Message 'server projection keeps plugins disabled'
Confirm-Static -Condition ((Get-Content -LiteralPath (Join-Path $repositoryRoot 'tools/hq-dispatch/v1/New-TsfHqDispatchGovernedMission.ps1') -Raw) -match "worker_tool_network_policy = 'DISABLED'") -Message 'governed mission keeps worker-tool network disabled'
$staticFinishedAt = [DateTimeOffset]::UtcNow
$staticStdout = $staticLines -join "`n"
$results.Add([pscustomobject]@{
    id = 'STATIC-INTEGRITY'
    command = 'PowerShell parser + Node --check + JSON/CSV validation + protected-path/plugin/path-budget checks + git diff --check'
    started_at_utc = $staticStartedAt.ToString('o')
    finished_at_utc = $staticFinishedAt.ToString('o')
    duration_ms = [int][Math]::Round(($staticFinishedAt - $staticStartedAt).TotalMilliseconds)
    exit_code = 0
    assertions = $staticAssertions
    stdout_sha256 = Get-TextSha256 -Text $staticStdout
    stderr_sha256 = Get-TextSha256 -Text ''
    stdout_bytes = $utf8NoBom.GetByteCount($staticStdout)
    stderr_bytes = 0
    status = 'PASS'
})

$sha256.Dispose()
$failed = @($results | Where-Object { $_.exit_code -ne 0 })
$summary = [ordered]@{
    schema_version = 'tsf_hq_dispatch_tim_relay_validation_run_v1'
    generated_at_utc = [DateTimeOffset]::UtcNow.ToString('o')
    status = if ($failed.Count -eq 0) { 'PASS' } else { 'FAIL' }
    command_count = $results.Count
    assertion_count = ($results | Measure-Object -Property assertions -Sum).Sum
    results = @($results)
}
$summary | ConvertTo-Json -Depth 8
if ($failed.Count -ne 0) { exit 1 }
