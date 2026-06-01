[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$QueuePath,
    [Parameter(Mandatory = $true)]
    [string]$OutDir,
    [string]$TaskId,
    [switch]$CaptainApproved,
    [switch]$RunChecks
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Resolve-FleetPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

function Test-AuditLoopUnsafeScope {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $normalized = ([string]$Value -replace "\\", "/").Trim()
    if ([System.IO.Path]::IsPathRooted($Value)) { return $true }
    if ($normalized -match "(^|/)\.\.(/|$)") { return $true }
    if ($normalized -match "(?i)(^|/)(\.env|\.git|node_modules|dist|build|\.codex-local/locks)(/|$)") { return $true }
    if ($normalized -match "(?i)(all repos|product repos|real product|launch all|broad cellar|secrets?|auth|payments?|deploy|migration|package\.json|pnpm-lock|package-lock)") { return $true }
    if ($normalized -match "\*") { return $true }
    return $false
}

function Convert-AuditLoopList {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
    return @($Value -split "\s*;\s*" | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
}

function Get-AuditLoopQueueTasks {
    param([string[]]$Lines)
    $tasks = [System.Collections.Generic.List[object]]::new()
    $current = $null
    foreach ($line in $Lines) {
        if ($line -match "^\s*-\s+\[(?<status>[ xX])\]\s+(?<title>.+)$") {
            if ($null -ne $current) { $tasks.Add([pscustomobject]$current) | Out-Null }
            $current = [ordered]@{
                title = $Matches.title.Trim()
                status = if ($Matches.status -match "[xX]") { "done" } else { "unchecked" }
                id = ""
                dispatchPhrase = ""
                goal = ""
                readList = @()
                workList = @()
                acceptanceCriteria = @()
                requiredChecks = @()
                commitExpectation = ""
                riskLevel = ""
                stopIf = @()
                proof = @()
            }
            continue
        }
        if ($null -eq $current) { continue }
        if ($line -match "^\s+-\s+(?<key>[A-Za-z][A-Za-z0-9]+):\s*(?<value>.*)$") {
            $key = $Matches.key
            $value = $Matches.value.Trim()
            $value = $value -replace "^``|``$", ""
            switch ($key) {
                "id" { $current.id = $value }
                "dispatchPhrase" { $current.dispatchPhrase = $value }
                "goal" { $current.goal = $value }
                "readList" { $current.readList = @(Convert-AuditLoopList $value) }
                "workList" { $current.workList = @(Convert-AuditLoopList $value) }
                "acceptanceCriteria" { $current.acceptanceCriteria = @(Convert-AuditLoopList $value) }
                "requiredChecks" { $current.requiredChecks = @(Convert-AuditLoopList $value) }
                "commitExpectation" { $current.commitExpectation = $value }
                "riskLevel" { $current.riskLevel = $value }
                "stopIf" { $current.stopIf = @(Convert-AuditLoopList $value) }
                "proof" { $current.proof = @(Convert-AuditLoopList $value) }
            }
        }
    }
    if ($null -ne $current) { $tasks.Add([pscustomobject]$current) | Out-Null }
    return @($tasks)
}

function Invoke-AuditLoopSafeCheck {
    param(
        [string]$Check,
        [string]$EvidenceDir
    )
    $check = ([string]$Check).Trim()
    if ([string]::IsNullOrWhiteSpace($check)) {
        return [pscustomobject]@{ check = $check; status = "failed"; exitCode = 1; reason = "empty-check"; evidence = $null }
    }
    $safePattern = '^(?i)(powershell|pwsh)\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-Command\s+".+"$'
    if ($check -notmatch $safePattern) {
        return [pscustomobject]@{ check = $check; status = "blocked"; exitCode = 1; reason = "unsupported-check-command"; evidence = $null }
    }
    if ($check -match '(?i)(Remove-Item|Set-Content|Add-Content|Out-File|New-Item|git\s+|npm\s+|pnpm\s+|yarn\s+|codex\s+|fleet-run|launch|delete|deploy|push)') {
        return [pscustomobject]@{ check = $check; status = "blocked"; exitCode = 1; reason = "mutating-check-command"; evidence = $null }
    }
    $stdout = Join-Path $EvidenceDir ("check-" + [guid]::NewGuid().ToString("N") + ".stdout.txt")
    $stderr = [System.IO.Path]::ChangeExtension($stdout, ".stderr.txt")
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "powershell"
    $psi.Arguments = $check.Substring($check.IndexOf(" ") + 1)
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $process = [System.Diagnostics.Process]::Start($psi)
    if (!$process.WaitForExit(30000)) {
        try { $process.Kill() } catch {}
        "Timed out after 30 seconds." | Set-Content -LiteralPath $stderr -Encoding UTF8
        return [pscustomobject]@{ check = $check; status = "failed"; exitCode = 124; reason = "timeout"; evidence = $stderr }
    }
    $process.StandardOutput.ReadToEnd() | Set-Content -LiteralPath $stdout -Encoding UTF8
    $process.StandardError.ReadToEnd() | Set-Content -LiteralPath $stderr -Encoding UTF8
    return [pscustomobject]@{
        check = $check
        status = if ($process.ExitCode -eq 0) { "passed" } else { "failed" }
        exitCode = $process.ExitCode
        reason = if ($process.ExitCode -eq 0) { "ok" } else { "check-failed" }
        evidence = $stdout
        stderr = $stderr
    }
}

$queueFullPath = Resolve-FleetPath $QueuePath
if (!(Test-Path -LiteralPath $queueFullPath)) { throw "Queue not found: $queueFullPath" }
$outFullDir = Resolve-FleetPath $OutDir
New-Item -ItemType Directory -Force -Path $outFullDir | Out-Null

$lines = Get-Content -LiteralPath $queueFullPath
$tasks = @(Get-AuditLoopQueueTasks -Lines $lines)
$unchecked = @($tasks | Where-Object { $_.status -eq "unchecked" })
$acceptedLimitationCount = @($lines | Where-Object { $_ -match "accepted-limitation" }).Count
$resultPath = Join-Path $outFullDir "audit-loop-task-result.json"

if (@($unchecked).Count -eq 0) {
    $status = if ($acceptedLimitationCount -gt 0) { "STOP_ACCEPTED_LIMITATION" } else { "NO_TASKS" }
    [pscustomobject]@{
        status = $status
        queuePath = $queueFullPath
        selectedTask = $null
        message = "No unchecked audit-loop task remains."
        executed = $false
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    Write-Host "AUDIT_LOOP_TASK_$status`: $resultPath"
    exit 0
}

$selected = $unchecked[0]
if (![string]::IsNullOrWhiteSpace($TaskId) -and !([string]$selected.id).Equals($TaskId, [System.StringComparison]::OrdinalIgnoreCase)) {
    [pscustomobject]@{
        status = "REJECTED_SKIP_AHEAD"
        requestedTaskId = $TaskId
        firstUncheckedTaskId = $selected.id
        queuePath = $queueFullPath
        executed = $false
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    Write-Host "AUDIT_LOOP_TASK_REJECTED: $resultPath"
    exit 1
}

$errors = [System.Collections.Generic.List[string]]::new()
if ([string]::IsNullOrWhiteSpace($selected.id)) { $errors.Add("missing id") | Out-Null }
if (@($selected.requiredChecks).Count -eq 0) { $errors.Add("missing requiredChecks") | Out-Null }
if ([string]$selected.riskLevel -eq "high" -and !$CaptainApproved) { $errors.Add("high-risk task requires captain approval") | Out-Null }
foreach ($item in @($selected.readList + $selected.workList)) {
    if (Test-AuditLoopUnsafeScope -Value ([string]$item)) {
        $errors.Add("broad or forbidden scope: $item") | Out-Null
    }
}

if (@($errors).Count -gt 0) {
    [pscustomobject]@{
        status = "REJECTED_UNSAFE_TASK"
        selectedTaskId = $selected.id
        errors = @($errors)
        queuePath = $queueFullPath
        executed = $false
        generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $resultPath -Encoding UTF8
    Write-Host "AUDIT_LOOP_TASK_REJECTED: $resultPath"
    exit 1
}

$checkResults = @()
if ($RunChecks) {
    foreach ($check in @($selected.requiredChecks)) {
        $checkResults += Invoke-AuditLoopSafeCheck -Check ([string]$check) -EvidenceDir $outFullDir
    }
} else {
    foreach ($check in @($selected.requiredChecks)) {
        $checkResults += [pscustomobject]@{
            check = [string]$check
            status = "would-run"
            exitCode = $null
            reason = "dry-run"
            evidence = $null
        }
    }
}

$failedChecks = @($checkResults | Where-Object { $_.status -notin @("passed", "would-run") })
$finalStatus = if (@($failedChecks).Count -eq 0) { "SELECTED_ONE_TASK" } else { "CHECK_FAILED" }
[pscustomobject]@{
    status = $finalStatus
    queuePath = $queueFullPath
    selectedTask = $selected
    selectedOnlyOneTask = $true
    executed = $RunChecks.IsPresent
    checkResults = @($checkResults)
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
} | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $resultPath -Encoding UTF8

Write-Host "AUDIT_LOOP_TASK_RESULT: $resultPath"
if ($finalStatus -eq "CHECK_FAILED") { exit 1 }
exit 0
