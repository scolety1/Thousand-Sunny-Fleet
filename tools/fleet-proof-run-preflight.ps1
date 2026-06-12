[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [string]$ConfigPath = ".\projects.json",

    [string]$TaskSelector = "",

    [switch]$RequireSelectedTask
)

$ErrorActionPreference = "Continue"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { Split-Path -Parent $PSScriptRoot } else { (Get-Location).Path }

function ConvertTo-ProofRunId {
    param([string]$Value)
    return (([string]$Value).Trim().ToLowerInvariant() -replace "[^a-z0-9]+", "")
}

function Add-Check {
    param(
        [System.Collections.Generic.List[object]]$Checks,
        [string]$Name,
        [bool]$Ok,
        [string]$Detail
    )

    $Checks.Add([pscustomobject]@{
        name = $Name
        ok = $Ok
        detail = $Detail
    }) | Out-Null
}

function Get-JsonProjects {
    param([string]$Path)
    $resolved = Resolve-Path -LiteralPath $Path -ErrorAction SilentlyContinue
    if (!$resolved) { throw "Config not found: $Path" }
    $loaded = Get-Content -LiteralPath $resolved.Path -Raw | ConvertFrom-Json
    if ($loaded -is [array]) { return @($loaded) }
    return @($loaded)
}

function Test-BuildCommandEvidence {
    param(
        [string]$RepoPath,
        [string]$BuildCommand,
        [string]$BuildDirectory
    )

    if ([string]::IsNullOrWhiteSpace($BuildCommand)) {
        return [pscustomobject]@{ ok = $false; detail = "buildCommand is missing" }
    }

    $resolvedBuildDir = if ([string]::IsNullOrWhiteSpace($BuildDirectory)) { $RepoPath } else { Join-Path $RepoPath $BuildDirectory }
    if (!(Test-Path -LiteralPath $resolvedBuildDir)) {
        return [pscustomobject]@{ ok = $false; detail = "buildDirectory not found" }
    }

    if ($BuildCommand -match "(?i)^npm\.cmd\s+run\s+([a-z0-9:_-]+)") {
        $scriptName = $Matches[1]
        $packagePath = Join-Path $resolvedBuildDir "package.json"
        if (!(Test-Path -LiteralPath $packagePath)) {
            return [pscustomobject]@{ ok = $false; detail = "package.json missing for npm build command" }
        }
        $package = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
        $hasScript = $null -ne $package.scripts -and $null -ne $package.scripts.PSObject.Properties[$scriptName]
        return [pscustomobject]@{ ok = $hasScript; detail = "npm script '$scriptName' " + $(if ($hasScript) { "exists" } else { "missing" }) }
    }

    if ($BuildCommand -match "(?i)-File\s+(.+?)(\s|$)") {
        $scriptPath = $Matches[1].Trim('"', "'")
        $candidate = Join-Path $resolvedBuildDir $scriptPath
        return [pscustomobject]@{ ok = (Test-Path -LiteralPath $candidate); detail = "PowerShell build script checked" }
    }

    return [pscustomobject]@{ ok = $true; detail = "buildCommand present; exact command existence not executed" }
}

function Get-CodexCliEvidence {
    $command = Get-Command "codex" -ErrorAction SilentlyContinue
    if ($null -eq $command) {
        return [pscustomobject]@{
            ok = $false
            version = ""
            detail = "codex command missing or unreadable"
        }
    }

    try {
        $versionOutput = @(codex --version 2>&1)
        $exitCode = $LASTEXITCODE
        $versionText = ($versionOutput -join " ").Trim()
        if ($exitCode -eq 0 -and ![string]::IsNullOrWhiteSpace($versionText)) {
            return [pscustomobject]@{
                ok = $true
                version = $versionText
                detail = $versionText
            }
        }

        $detail = if (![string]::IsNullOrWhiteSpace($versionText)) {
            "codex command found but version check failed: $versionText"
        } else {
            "codex command found but version check failed"
        }
        return [pscustomobject]@{
            ok = $false
            version = ""
            detail = $detail
        }
    } catch {
        $message = ($_.Exception.Message -replace "\s+", " ").Trim()
        return [pscustomobject]@{
            ok = $false
            version = ""
            detail = "codex command found but not executable: $message"
        }
    }
}

Set-Location $fleetRoot
$checks = [System.Collections.Generic.List[object]]::new()
$stopSigns = [System.Collections.Generic.List[string]]::new()

try {
    $projects = @(Get-JsonProjects -Path $ConfigPath)
} catch {
    Write-Host "RED: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

$normalizedProjectId = ConvertTo-ProofRunId -Value $ProjectId
$matches = @($projects | Where-Object {
    [string]$_.name -ieq $ProjectId -or (ConvertTo-ProofRunId -Value $_.name) -eq $normalizedProjectId
})

Add-Check -Checks $checks -Name "exactly_one_project" -Ok ($matches.Count -eq 1) -Detail "matched $($matches.Count) project(s) for '$ProjectId'"
if ($matches.Count -ne 1) {
    $stopSigns.Add("selected project must match exactly one projects.json entry") | Out-Null
}

$project = if ($matches.Count -eq 1) { $matches[0] } else { $null }
$repoPath = if ($null -ne $project) { [string]$project.repo } else { "" }
$repoExists = ![string]::IsNullOrWhiteSpace($repoPath) -and (Test-Path -LiteralPath $repoPath)
Add-Check -Checks $checks -Name "repo_exists" -Ok $repoExists -Detail $(if ($repoExists) { "repo path exists" } else { "repo path missing" })

$taskQueuePath = if ($repoExists) { Join-Path $repoPath "docs\codex\TASK_QUEUE.md" } else { "" }
$taskQueueExists = ![string]::IsNullOrWhiteSpace($taskQueuePath) -and (Test-Path -LiteralPath $taskQueuePath)
Add-Check -Checks $checks -Name "task_queue_exists" -Ok $taskQueueExists -Detail $(if ($taskQueueExists) { "docs/codex/TASK_QUEUE.md found" } else { "docs/codex/TASK_QUEUE.md missing" })

$uncheckedTasks = @()
if ($taskQueueExists) {
    $uncheckedTasks = @(Select-String -LiteralPath $taskQueuePath -Pattern "^\s*-\s+\[ \]\s+(.+)$" | ForEach-Object { $_.Line.Trim() })
}

$selectedTaskMatches = @()
if (![string]::IsNullOrWhiteSpace($TaskSelector) -and $taskQueueExists) {
    $selectedTaskMatches = @($uncheckedTasks | Where-Object { $_ -match [regex]::Escape($TaskSelector) })
}

$hasExactlyOneSelectedTask = (![string]::IsNullOrWhiteSpace($TaskSelector) -and $selectedTaskMatches.Count -eq 1)
$selectedTaskDetail = if ($hasExactlyOneSelectedTask) {
    "exactly one selected task matched"
} elseif ([string]::IsNullOrWhiteSpace($TaskSelector)) {
    "no TaskSelector supplied; actual proof run remains blocked until exactly one task is selected"
} else {
    "TaskSelector matched $($selectedTaskMatches.Count) unchecked task(s)"
}
Add-Check -Checks $checks -Name "exactly_one_selected_task_for_actual_run" -Ok ($hasExactlyOneSelectedTask -or !$RequireSelectedTask) -Detail $selectedTaskDetail
if ($RequireSelectedTask -and !$hasExactlyOneSelectedTask) {
    $stopSigns.Add("actual proof run requires exactly one selected task") | Out-Null
}

if ($repoExists) {
    $gitStatus = @(git -C $repoPath status --short 2>$null)
    $gitBranch = (git -C $repoPath branch --show-current 2>$null | Select-Object -First 1)
    $cleanState = if ($gitStatus.Count -eq 0) { "clean" } else { "dirty" }
    Add-Check -Checks $checks -Name "repo_state_known" -Ok $true -Detail "branch=$gitBranch; state=$cleanState"
} else {
    Add-Check -Checks $checks -Name "repo_state_known" -Ok $false -Detail "repo not available"
}

if ($null -ne $project) {
    $buildEvidence = Test-BuildCommandEvidence -RepoPath $repoPath -BuildCommand ([string]$project.buildCommand) -BuildDirectory ([string]$project.buildDirectory)
    Add-Check -Checks $checks -Name "build_validation_command_exists" -Ok ([bool]$buildEvidence.ok) -Detail ([string]$buildEvidence.detail)
}

$launchGatePath = Join-Path $fleetRoot "fleet-launch-gate.ps1"
Add-Check -Checks $checks -Name "launch_gate_script_exists" -Ok (Test-Path -LiteralPath $launchGatePath) -Detail "launch gate must run before Codex"

$checkpointReviewPath = Join-Path $fleetRoot "checkpoint-review.ps1"
Add-Check -Checks $checks -Name "checkpoint_review_script_exists" -Ok (Test-Path -LiteralPath $checkpointReviewPath) -Detail "checkpoint review required after Codex edits"

$codexEvidence = Get-CodexCliEvidence
$codexVersion = [string]$codexEvidence.version
Add-Check -Checks $checks -Name "codex_cli_detected" -Ok ([bool]$codexEvidence.ok) -Detail ([string]$codexEvidence.detail)

$runtimePath = Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1"
$runtimeText = if (Test-Path -LiteralPath $runtimePath) { Get-Content -LiteralPath $runtimePath -Raw } else { "" }
$runtimeUsesSupportedTier = $runtimeText -match 'service_tier="(fast|flex)"'
Add-Check -Checks $checks -Name "service_tier_supported" -Ok $runtimeUsesSupportedTier -Detail $(if ($runtimeUsesSupportedTier) { "Fleet runtime uses supported service_tier" } else { "Fleet runtime service_tier compatibility not proven" })

$configPath = Join-Path $HOME ".codex\config.toml"
if (Test-Path -LiteralPath $configPath) {
    $configText = Get-Content -LiteralPath $configPath -Raw
    $badTier = $configText -match '(?im)^\s*service_tier\s*=\s*"default"\s*$'
    $effectiveTierOk = (!$badTier) -or ($runtimeUsesSupportedTier -and ![string]::IsNullOrWhiteSpace($codexVersion))
    $tierDetail = if ($badTier -and $effectiveTierOk) {
        "unsupported config default present but Fleet runtime overrides with supported service_tier"
    } elseif ($badTier) {
        "unsupported service_tier default found"
    } else {
        "no unsupported service_tier default found"
    }
    Add-Check -Checks $checks -Name "codex_config_no_default_service_tier" -Ok $effectiveTierOk -Detail $tierDetail
}

foreach ($check in $checks) {
    $prefix = if ($check.ok) { "PASS" } else { "WARN" }
    Write-Output "${prefix}: $($check.name) - $($check.detail)"
}

Write-Output ""
Write-Output "Project: $ProjectId"
Write-Output "Task queue unchecked count: $($uncheckedTasks.Count)"
$failedCheckCount = @($checks | Where-Object { -not $_.ok }).Count
Write-Output "Actual proof-run ready: $($hasExactlyOneSelectedTask -and $stopSigns.Count -eq 0 -and $failedCheckCount -eq 0)"
Write-Output "Phone/dashboard controls: request/status only"
Write-Output "Forbidden operations remain blocked: secrets, backend/auth/payments/deploy, installs, migrations, remote access, all-fleet, overnight runner, merge, push, deploy, broader authority"

if ($stopSigns.Count -gt 0) {
    Write-Output ""
    Write-Output "Stop signs:"
    $stopSigns | ForEach-Object { Write-Output "- $_" }
    exit 1
}

if ($failedCheckCount -gt 0) {
    Write-Output ""
    Write-Output "Preflight posture: YELLOW"
    exit 0
}

Write-Output ""
Write-Output "Preflight posture: GREEN"
exit 0
