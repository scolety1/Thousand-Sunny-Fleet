[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateSet("Update", "Classify", "Report", "ValidateTransition")]
    [string]$Action = "Report",
    [string]$ConfigPath = ".\projects.json",
    [string]$Ship = "",
    [string]$Repo = "",
    [string]$Status = "UNKNOWN",
    [string]$PreviousStatus = "",
    [string]$FromStatus = "",
    [string]$ToStatus = "",
    [string]$Phase = "",
    [string]$RiskTier = "",
    [string]$Reason = "",
    [string[]]$EvidencePath = @(),
    [string[]]$Blocker = @(),
    [string[]]$TasteGateReason = @(),
    [int]$TasksRemaining = 0,
    [int]$QuarantinedTasks = 0,
    [string]$LastRunStatus = "",
    [string]$LastRunResultPath = "",
    [string]$LastAuditPackagePath = "",
    [string]$LastTaskPacketPath = "",
    [switch]$RepoClean,
    [switch]$RepoDirty,
    [switch]$ActiveOwnedWork,
    [switch]$RepairTaskExists,
    [switch]$TasteGateRequired,
    [switch]$RateLimitPaused,
    [switch]$Archived,
    [switch]$WriteCurrentState,
    [string]$OutFile = "fleet\status\current.md",
    [string]$JsonOutFile = "fleet\status\current.json"
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-state.ps1")

function Resolve-RepoForShip {
    param([string]$ShipName, [string]$RepoValue)
    if (![string]::IsNullOrWhiteSpace($RepoValue)) { return [System.IO.Path]::GetFullPath($RepoValue) }
    if ([string]::IsNullOrWhiteSpace($ShipName) -or !(Test-Path -LiteralPath $ConfigPath)) { return "" }
    $projects = @(Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json)
    $match = @($projects | Where-Object { [string]$_.name -eq $ShipName } | Select-Object -First 1)
    if ($match.Count -eq 0) { return "" }
    return [System.IO.Path]::GetFullPath([string]$match[0].repo)
}

if ($Action -eq "ValidateTransition") {
    if ([string]::IsNullOrWhiteSpace($FromStatus) -or [string]::IsNullOrWhiteSpace($ToStatus)) {
        throw "ValidateTransition requires -FromStatus and -ToStatus."
    }
    if (Test-FleetShipStateTransition -FromStatus $FromStatus -ToStatus $ToStatus) {
        Write-Host "Transition valid: $($FromStatus.ToUpperInvariant()) -> $($ToStatus.ToUpperInvariant())"
        exit 0
    }
    Write-Host "Transition invalid: $FromStatus -> $ToStatus" -ForegroundColor Red
    exit 1
}

if ($Action -eq "Update") {
    if ([string]::IsNullOrWhiteSpace($Ship)) { throw "Update requires -Ship." }
    $resolvedRepo = Resolve-RepoForShip -ShipName $Ship -RepoValue $Repo
    $record = New-FleetShipStateRecord -Ship $Ship -Repo $resolvedRepo -Status $Status -PreviousStatus $PreviousStatus -Phase $Phase -RiskTier $RiskTier -TasksRemaining $TasksRemaining -QuarantinedTasks $QuarantinedTasks -LastRunResultPath $LastRunResultPath -LastAuditPackagePath $LastAuditPackagePath -LastTaskPacketPath $LastTaskPacketPath -Blockers $Blocker -TasteGateReasons $TasteGateReason -EvidencePaths $EvidencePath -Reason $Reason -RepoClean $(if ($RepoDirty) { $false } elseif ($RepoClean) { $true } else { $null })
    $written = Set-FleetShipState -FleetRoot $fleetRoot -State $record -WriteCurrentState:$WriteCurrentState
    Write-Host "STATE_FILE: $($written.statePath)"
    if ($written.currentStatePath) { Write-Host "CURRENT_STATE: $($written.currentStatePath)" }
    exit 0
}

if ($Action -eq "Classify") {
    if ([string]::IsNullOrWhiteSpace($Ship)) { throw "Classify requires -Ship." }
    $resolvedRepo = Resolve-RepoForShip -ShipName $Ship -RepoValue $Repo
    $repoState = ""
    $isClean = $RepoClean.IsPresent
    if ($RepoDirty) { $repoState = "dirty"; $isClean = $false }
    elseif ($RepoClean) { $repoState = "clean"; $isClean = $true }
    elseif (![string]::IsNullOrWhiteSpace($resolvedRepo)) {
        $observed = Get-FleetRepoState -Repo $resolvedRepo
        $repoState = $observed.state
        $isClean = [bool]$observed.clean
    }
    $record = Resolve-FleetShipStateFromEvidence -Ship $Ship -Repo $resolvedRepo -RepoState $repoState -RepoClean $isClean -ActiveOwnedWork:$ActiveOwnedWork -TasksRemaining $TasksRemaining -QuarantinedTasks $QuarantinedTasks -LastRunStatus $LastRunStatus -LastRunResultPath $LastRunResultPath -LastAuditPackagePath $LastAuditPackagePath -LastTaskPacketPath $LastTaskPacketPath -RepairTaskExists:$RepairTaskExists -TasteGateRequired:$TasteGateRequired -RateLimitPaused:$RateLimitPaused -Archived:$Archived -Phase $Phase -RiskTier $RiskTier -EvidencePaths $EvidencePath
    $written = Set-FleetShipState -FleetRoot $fleetRoot -State $record -WriteCurrentState:$WriteCurrentState
    Write-Host "$Ship => $($record.status): $($record.reason)"
    Write-Host "STATE_FILE: $($written.statePath)"
    if ($written.currentStatePath) { Write-Host "CURRENT_STATE: $($written.currentStatePath)" }
    exit 0
}

if (!(Test-Path -LiteralPath (Join-Path $fleetRoot "fleet\state\ship-state.json"))) {
    New-Item -ItemType Directory -Force -Path (Join-Path $fleetRoot "fleet\state") | Out-Null
    [pscustomobject]@{ schemaVersion = 1; generatedAt = (Get-Date).ToUniversalTime().ToString("o"); ships = @() } | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $fleetRoot "fleet\state\ship-state.json") -Encoding UTF8
}

$fleetState = Read-FleetShipStateFile -StatePath (Join-Path $fleetRoot "fleet\state\ship-state.json")
$lines = @(
    "# Codex Fleet Current State",
    "",
    "Generated: $((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))",
    "",
    "| Ship | State | Reason | Last Run | Blockers | Next Safe Human Action |",
    "| --- | --- | --- | --- | --- | --- |"
)
foreach ($state in @($fleetState.ships | Sort-Object ship)) {
    $blockers = if (@($state.blockers).Count -gt 0) { (@($state.blockers) -join "; ").Replace("|", "/") } else { "-" }
    $reasonText = ([string]$state.reason).Replace("|", "/")
    $next = ([string]$state.nextSafeHumanAction).Replace("|", "/")
    $lines += "| $($state.ship) | $($state.status) | $reasonText | $($state.lastRunResultPath) | $blockers | $next |"
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
$lines | Set-Content -Path $OutFile -Encoding UTF8
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOutFile) | Out-Null
$fleetState | ConvertTo-Json -Depth 12 | Set-Content -Path $JsonOutFile -Encoding UTF8
Write-Host "STATE_REPORT: $([System.IO.Path]::GetFullPath($OutFile))"
Write-Host "STATE_JSON: $([System.IO.Path]::GetFullPath($JsonOutFile))"
