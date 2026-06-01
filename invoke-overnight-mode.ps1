[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",
    [string]$StatePath = "fleet\state\ship-state.json",
    [string[]]$Ship = @(),
    [ValidateSet("", "fixture-only")]
    [string]$Preset = "",
    [switch]$Execute,
    [double]$CurrentRatePercent = -1,
    [double]$WeeklyRatePercent = -1,
    [ValidateSet("unknown", "healthy", "cautious", "low", "critical", "exhausted", "reset_pending", "recovered")]
    [string]$ManualBudgetLevel = "unknown",
    [int]$LowBudgetThresholdPercent = 10,
    [int]$SafeLandingThresholdPercent = 3,
    [int]$WeeklyResetPauseThresholdPercent = 5,
    [string]$ResetAt = "",
    [switch]$AllowConfiguredResetResume,
    [int]$MaxShips = 1,
    [int]$MaxCyclesPerShip = 1,
    [int]$MaxResumeAttempts = 1,
    [int]$ResumeAttemptsUsed = 0,
    [int]$CheckCadenceMinutes = 20,
    [string]$ReportPath = "",
    [string]$JsonReportPath = "",
    [string]$ResumeMetadataPath = "",
    [string]$WeeklyPreviewPlanPath = ""
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-state.ps1")
. (Join-Path $fleetRoot "tools\codex-fleet-autonomy.ps1")
. (Join-Path $fleetRoot "tools\codex-fleet-overnight.ps1")

function Resolve-Stage10Path {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

$started = Get-Date
$runId = "stage10-overnight-" + $started.ToString("yyyyMMdd-HHmmss-fff") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = "out\stage10-overnight\$runId\overnight-report.md" }
if ([string]::IsNullOrWhiteSpace($JsonReportPath)) { $JsonReportPath = "out\stage10-overnight\$runId\overnight-result.json" }
if ([string]::IsNullOrWhiteSpace($ResumeMetadataPath)) { $ResumeMetadataPath = "out\stage10-overnight\$runId\resume-metadata.json" }
if ([string]::IsNullOrWhiteSpace($WeeklyPreviewPlanPath)) { $WeeklyPreviewPlanPath = "out\stage10-overnight\$runId\weekly-preview-plan.json" }
$reportFull = Resolve-Stage10Path $ReportPath
$jsonFull = Resolve-Stage10Path $JsonReportPath
$resumeFull = Resolve-Stage10Path $ResumeMetadataPath
$weeklyPreviewFull = Resolve-Stage10Path $WeeklyPreviewPlanPath

$status = "GREEN"
$fatal = ""
$scopeResult = $null
$shipResults = @()
$resumeEligibility = @()
$resumeMetadata = $null
$weeklyPreviewPlan = $null
$resetDate = $null

try {
    if (![string]::IsNullOrWhiteSpace($ResetAt)) {
        $parsedReset = [datetime]::MinValue
        if (![datetime]::TryParse($ResetAt, [ref]$parsedReset)) { throw "ResetAt is not a valid date/time: $ResetAt" }
        $resetDate = $parsedReset
    }

    $configFull = Resolve-Stage10Path $ConfigPath
    if (!(Test-Path -LiteralPath $configFull)) { throw "Config not found: $configFull" }
    $projects = @(Get-Content -LiteralPath $configFull -Raw | ConvertFrom-Json | ForEach-Object { $_ })
    $scopeResult = Test-FleetAutonomyScope -Projects $projects -Ship $Ship -Preset $Preset -MaxShips $MaxShips

    $stateFull = Resolve-Stage10Path $StatePath
    $stateFile = Read-FleetShipStateFile -StatePath $stateFull

    $contract = New-FleetOvernightContract -CheckCadenceMinutes $CheckCadenceMinutes -LowBudgetThresholdPercent $LowBudgetThresholdPercent -SafeLandingThresholdPercent $SafeLandingThresholdPercent -WeeklyResetPauseThresholdPercent $WeeklyResetPauseThresholdPercent -MaxShips $MaxShips -MaxCyclesPerShip $MaxCyclesPerShip -MaxResumeAttempts $MaxResumeAttempts
    $governorArgs = @{
        RemainingPercent = $CurrentRatePercent
        WeeklyRemainingPercent = $WeeklyRatePercent
        ManualBudgetLevel = $ManualBudgetLevel
        LowBudgetThresholdPercent = $LowBudgetThresholdPercent
        SafeLandingThresholdPercent = $SafeLandingThresholdPercent
        WeeklyResetPauseThresholdPercent = $WeeklyResetPauseThresholdPercent
    }
    if ($null -ne $resetDate) { $governorArgs.ResetAt = $resetDate }
    $governor = Resolve-FleetRateGovernor @governorArgs

    foreach ($project in @($scopeResult.selected)) {
        $shipName = [string]$($project.name)
        $repoValue = [string]$($project.repo)
        $repo = if ([System.IO.Path]::IsPathRooted($repoValue)) { [System.IO.Path]::GetFullPath($repoValue) } else { [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $repoValue)) }
        $state = @($stateFile.ships | Where-Object { [string]$($_.ship) -eq $shipName } | Select-Object -First 1)
        if ($state.Count -eq 0) {
            $repoState = Get-FleetRepoState -Repo $repo
            $state = Resolve-FleetShipStateFromEvidence -Ship $shipName -Repo $repo -RepoState $repoState.state -RepoClean ([bool]$repoState.clean) -EvidencePaths @("State synthesized by Stage 10 overnight wrapper.")
        } else {
            $state = $state[0]
        }

        $shipStatus = ([string]$($state.status)).ToUpperInvariant()
        $action = "WRITE_STATUS_REPORT"
        $reason = $governor.reason
        if ($shipStatus -in @("TASTE_GATE", "BLOCKED", "ARCHIVED")) {
            $action = "DO_NOT_RESUME"
            $reason = "Ship state $shipStatus blocks overnight resume."
        } elseif ($governor.decision -eq "ALLOW_RUN") {
            $action = if ($Execute) { "BOUNDED_RUN_APPROVED_NOT_LAUNCHED" } else { "PLAN_BOUNDED_RUN" }
            $reason = "Budget allows one bounded run plan. Stage 10 test wrapper does not launch product ships."
        } elseif ($governor.decision -eq "SAFE_LAND_NOW") {
            $action = "SAFE_LANDING"
        } elseif ($governor.decision -eq "WEEKLY_PREVIEW_PAUSE") {
            $action = "PAUSE_FOR_WEEKLY_PREVIEW"
        } elseif ($governor.decision -eq "WAIT_FOR_RESET") {
            $action = "WAIT_FOR_RATE_RESET"
        } elseif ($governor.decision -eq "BLOCK_NEW_WORK") {
            $action = "BLOCK_NEW_WORK"
        } elseif ($governor.decision -eq "ALLOW_STATUS_ONLY") {
            $action = "STATUS_ONLY_CHECK"
        }

        $shipResults += [pscustomobject]@{
            ship = $shipName
            state = $shipStatus
            repo = $repo
            action = $action
            reason = $reason
        }
    }

    if ($governor.decision -eq "SAFE_LAND_NOW" -or $governor.decision -eq "WAIT_FOR_RESET" -or $governor.decision -eq "WEEKLY_PREVIEW_PAUSE") {
        $resumeMetadata = New-FleetSafeLandingPlan -SelectedShips @($scopeResult.selected | ForEach-Object { [string]$($_.name) }) -Governor $governor -PausedAt $started -MaxResumeAttempts $MaxResumeAttempts -ResumeAttemptsUsed $ResumeAttemptsUsed -EvidencePath $jsonFull
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resumeFull) | Out-Null
        $resumeMetadata | ConvertTo-Json -Depth 12 | Set-Content -Path $resumeFull -Encoding UTF8
        if ($governor.decision -eq "WEEKLY_PREVIEW_PAUSE") {
            $weeklyPreviewPlan = New-FleetWeeklyResetPreviewPlan -Ships $shipResults -ResetAt $(if ($null -ne $resetDate) { $resetDate } else { [datetime]::MinValue }) -PreviewReportPath $reportFull -BugDocPath "docs/codex/WEEKLY_RESET_REVIEW_NOTES.md"
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $weeklyPreviewFull) | Out-Null
            $weeklyPreviewPlan | ConvertTo-Json -Depth 12 | Set-Content -Path $weeklyPreviewFull -Encoding UTF8
        }
    } else {
        $resumeMetadata = [pscustomobject]@{
            state = "NOT_PAUSED"
            selectedShips = @($scopeResult.selected | ForEach-Object { [string]$($_.name) })
            resumableShips = @($scopeResult.selected | ForEach-Object { [string]$($_.name) })
            maxResumeAttempts = $MaxResumeAttempts
            resumeAttemptsUsed = $ResumeAttemptsUsed
        }
    }

    foreach ($shipResultItem in @($shipResults)) {
        $currentShipName = [string]$($shipResultItem.ship)
        $state = @($stateFile.ships | Where-Object { [string]$($_.ship) -eq $currentShipName } | Select-Object -First 1)
        if ($state.Count -eq 0) {
            $resumeState = [pscustomobject]@{ ship = $currentShipName; status = $shipResultItem.state; repoClean = $true }
        } else {
            $state = $state[0]
            $resumeState = [pscustomobject]@{
                ship = $currentShipName
                status = [string]$($state.status)
                repoClean = if ($null -ne $state.repoClean) { [bool]$state.repoClean } else { $true }
            }
        }
        $resumeEligibility += Test-FleetOvernightResumeEligibility -ShipState $resumeState -ShipName $currentShipName -ResumeMetadata $resumeMetadata -Governor $governor -AllowConfiguredResetResume:$AllowConfiguredResetResume
    }
} catch {
    $status = "RED"
    $fatal = $_.Exception.Message
}

$ended = Get-Date
$nextCaptainAction = if ($status -eq "RED") {
    "Fix the overnight scope/config error before running Stage 10 again."
} elseif ($governor -and $governor.decision -eq "SAFE_LAND_NOW") {
    "Let the safe landing stand; resume only after budget recovers and eligibility stays GREEN."
} elseif ($governor -and $governor.decision -eq "WEEKLY_PREVIEW_PAUSE") {
    "Keep previews available until weekly reset, inspect unfinished work, and write bugs/errors in docs/codex/WEEKLY_RESET_REVIEW_NOTES.md."
} elseif ($governor -and $governor.decision -eq "WAIT_FOR_RESET") {
    "Wait for reset or provide a recovered budget signal, then rerun overnight mode."
} elseif (@($resumeEligibility | Where-Object { $_.eligible }).Count -gt 0) {
    "Eligible ships may resume with an explicit bounded run approval."
} else {
    "Review the overnight report and continue with Stage 10 tests or documentation."
}

$result = [pscustomobject]@{
    schemaVersion = 1
    runId = $runId
    stage = "Golden Gameplan Stage 10"
    mode = if ($Execute) { "execute-plan" } else { "dry-run" }
    status = $status
    startedAt = $started.ToUniversalTime().ToString("o")
    endedAt = $ended.ToUniversalTime().ToString("o")
    durationSeconds = [Math]::Round(($ended - $started).TotalSeconds, 3)
    contract = $contract
    governor = $governor
    selectedShips = @($shipResults | ForEach-Object { $_.ship })
    excludedShips = if ($scopeResult) { @($scopeResult.excluded) } else { @() }
    ships = @($shipResults)
    safeLanding = ($governor -and $governor.safeLandingRequired)
    weeklyPreviewPause = ($governor -and $governor.decision -eq "WEEKLY_PREVIEW_PAUSE")
    weeklyPreviewPlanPath = if (Test-Path -LiteralPath $weeklyPreviewFull) { $weeklyPreviewFull } else { "" }
    weeklyPreviewPlan = $weeklyPreviewPlan
    resumeMetadataPath = if (Test-Path -LiteralPath $resumeFull) { $resumeFull } else { "" }
    resumeMetadata = $resumeMetadata
    resumeEligibility = @($resumeEligibility)
    fatalError = $fatal
    reportPath = $reportFull
    jsonReportPath = $jsonFull
    nextCaptainAction = $nextCaptainAction
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonFull) | Out-Null
$result | ConvertTo-Json -Depth 14 | Set-Content -Path $jsonFull -Encoding UTF8

$reportText = New-FleetOvernightMorningReport -Result $result
if (![string]::IsNullOrWhiteSpace($fatal)) {
    $reportText += "`n`n## Fatal Blocker`n`n- $(Get-FleetOvernightShortText -Text $fatal -MaxLength 260)`n"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFull) | Out-Null
$reportText | Set-Content -Path $reportFull -Encoding UTF8

Write-Host "STAGE10_STATUS: $status"
Write-Host "STAGE10_REPORT: $reportFull"
Write-Host "STAGE10_JSON: $jsonFull"
if ($result.resumeMetadataPath) { Write-Host "STAGE10_RESUME: $($result.resumeMetadataPath)" }
if ($result.weeklyPreviewPlanPath) { Write-Host "STAGE10_WEEKLY_PREVIEW: $($result.weeklyPreviewPlanPath)" }
if ($status -eq "RED") { exit 1 }
exit 0
