[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",
    [string]$StatePath = "fleet\state\ship-state.json",
    [string[]]$Ship = @(),
    [ValidateSet("", "fixture-only")]
    [string]$Preset = "",
    [switch]$Execute,
    [switch]$AllowRunBatch,
    [switch]$AllowAuditPackage,
    [switch]$AllowTaskPacketImport,
    [switch]$AllowRepairTask,
    [switch]$AllowParkShip,
    [string]$ApprovedPacketEvidence = "",
    [switch]$LowTokenMode,
    [int]$MaxCycles = 1,
    [int]$MaxRuntimeMinutes = 10,
    [int]$MaxShips = 1,
    [int]$MaxRunBatchesPerShip = 1,
    [int]$MaxRepairAttempts = 1,
    [int]$MaxAuditPackages = 1,
    [int]$MaxTaskPacketImports = 1,
    [int]$StopBeforeRateLimitPercent = 3,
    [string]$ReportPath = "",
    [string]$JsonReportPath = ""
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-state.ps1")
. (Join-Path $fleetRoot "tools\codex-fleet-decision.ps1")
. (Join-Path $fleetRoot "tools\codex-fleet-autonomy.ps1")

function Resolve-Stage8Path {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

$started = Get-Date
$runId = "stage8-cycle-" + $started.ToString("yyyyMMdd-HHmmss-fff") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = "out\stage8-autonomy\$runId\cycle-summary.md" }
if ([string]::IsNullOrWhiteSpace($JsonReportPath)) { $JsonReportPath = "out\stage8-autonomy\$runId\cycle-result.json" }
$reportFull = Resolve-Stage8Path $ReportPath
$jsonFull = Resolve-Stage8Path $JsonReportPath

$mode = if ($Execute) { "execute" } else { "dry-run" }
$status = "GREEN"
$fatal = ""
$shipResults = @()
$scopeResult = $null
$budget = New-FleetAutonomyBudget -MaxCycles $MaxCycles -MaxRuntimeMinutes $MaxRuntimeMinutes -MaxShips $MaxShips -MaxRunBatchesPerShip $MaxRunBatchesPerShip -MaxRepairAttempts $MaxRepairAttempts -MaxAuditPackages $MaxAuditPackages -MaxTaskPacketImports $MaxTaskPacketImports -LowTokenMode:$LowTokenMode -StopBeforeRateLimitPercent $StopBeforeRateLimitPercent
$approvedPacketEvidenceResult = Test-FleetApprovedPacketEvidence -Path $ApprovedPacketEvidence -FleetRoot $fleetRoot

try {
    if ($budget.maxCycles -ne 1) { throw "Stage 8 only supports one bounded cycle; MaxCycles must be 1." }
    $configFull = Resolve-Stage8Path $ConfigPath
    if (!(Test-Path -LiteralPath $configFull)) { throw "Config not found: $configFull" }
    $projects = @(Get-Content -LiteralPath $configFull -Raw | ConvertFrom-Json | ForEach-Object { $_ })
    $scopeResult = Test-FleetAutonomyScope -Projects $projects -Ship $Ship -Preset $Preset -MaxShips $budget.maxShips

    $stateFull = Resolve-Stage8Path $StatePath
    $stateFile = Read-FleetShipStateFile -StatePath $stateFull
    foreach ($project in @($scopeResult.selected)) {
        $shipName = [string]$project.name
        $repoValue = [string]$project.repo
        $repo = if ([System.IO.Path]::IsPathRooted($repoValue)) { [System.IO.Path]::GetFullPath($repoValue) } else { [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $repoValue)) }
        $state = @($stateFile.ships | Where-Object { [string]$_.ship -eq $shipName } | Select-Object -First 1)
        if ($state.Count -eq 0) {
            $repoState = Get-FleetRepoState -Repo $repo
            $state = Resolve-FleetShipStateFromEvidence -Ship $shipName -Repo $repo -RepoState $repoState.state -RepoClean ([bool]$repoState.clean) -EvidencePaths @("State synthesized by Stage 8 wrapper because no state record existed.")
        } else {
            $state = $state[0]
        }

        $decisionInput = New-FleetDecisionInput -State $state -EvidenceFreshness "fresh"
        $decision = Resolve-FleetDecision -Input $decisionInput
        $action = Resolve-FleetAutonomyAction -Decision $decision -Budget $budget -AllowRunBatch:$AllowRunBatch -AllowAuditPackage:$AllowAuditPackage -AllowTaskPacketImport:$AllowTaskPacketImport -AllowRepairTask:$AllowRepairTask -AllowParkShip:$AllowParkShip -ApprovedPacketEvidence $ApprovedPacketEvidence -FleetRoot $fleetRoot
        $executed = $false
        $executionStatus = "planned"
        $executionEvidence = @()
        $errorText = ""

        if ($Execute) {
            try {
                switch ($action.action) {
                    "WRITE_STATUS_REPORT" {
                        $executed = $true
                        $executionStatus = "reported"
                    }
                    "MAKE_AUDIT_PACKAGE" {
                        if (!$AllowAuditPackage) { throw "Audit package action was not allowed." }
                        $auditId = "$runId-$shipName"
                        $auditRoot = "out\stage8-autonomy\$runId\audit"
                        $audit = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "new-audit-package.ps1") -ConfigPath $configFull -Project $shipName -OutRoot $auditRoot -AuditId $auditId 2>&1
                        if ($LASTEXITCODE -ne 0) { throw ($audit -join "`n") }
                        $executed = $true
                        $executionStatus = "audit-package-created"
                        $executionEvidence += $audit
                    }
                    "RUN_ONE_BATCH" {
                        if (!$AllowRunBatch) { throw "Run batch action was not allowed." }
                        $executed = $true
                        $executionStatus = "bounded-run-approved-not-launched"
                        $executionEvidence += "Stage 8 approved exactly one bounded run action for $shipName, but this wrapper does not call product launch scripts in harness tests."
                    }
                    "IMPORT_APPROVED_PACKET" {
                        if (!$AllowTaskPacketImport -or !$approvedPacketEvidenceResult.valid) { throw "Task packet import requires a real Stage 4 validation artifact: $($approvedPacketEvidenceResult.reason)" }
                        $executed = $true
                        $executionStatus = "approved-packet-ready"
                        $executionEvidence += "Stage 8.5 verified packet evidence: $($approvedPacketEvidenceResult.path)"
                    }
                    "WRITE_REPAIR_TASK" {
                        if (!$AllowRepairTask) { throw "Repair task creation was not allowed." }
                        $executed = $true
                        $executionStatus = "repair-task-requested"
                    }
                    "PARK_SHIP" {
                        if (!$AllowParkShip) { throw "Park ship action was not allowed." }
                        $executed = $true
                        $executionStatus = "park-requested"
                    }
                    "REQUEST_TASTE_GATE" {
                        $executed = $true
                        $executionStatus = "taste-gate-requested"
                    }
                    "BLOCK_WITH_REASON" {
                        $executed = $true
                        $executionStatus = "blocked"
                    }
                    default {
                        throw "Unknown action: $($action.action)"
                    }
                }
            } catch {
                $status = "YELLOW"
                $executionStatus = "failed-contained"
                $errorText = $_.Exception.Message
            }
        }

        $shipResults += [pscustomobject]@{
            ship = $shipName
            state = [string]$state.status
            repo = $repo
            decision = $decision.decision
            action = $action.action
            reason = $decision.reason
            risk = $action.risk
            requiredApproval = $action.requiredApproval
            blockedReason = $action.blockedReason
            executed = $executed
            executionStatus = $executionStatus
            error = $errorText
            evidence = @($decision.evidence + $executionEvidence)
        }
    }
} catch {
    $status = "RED"
    $fatal = $_.Exception.Message
}

$ended = Get-Date
$result = [pscustomobject]@{
    schemaVersion = 1
    runId = $runId
    stage = "Golden Gameplan Stage 8"
    mode = $mode
    status = $status
    startedAt = $started.ToUniversalTime().ToString("o")
    endedAt = $ended.ToUniversalTime().ToString("o")
    durationSeconds = [Math]::Round(($ended - $started).TotalSeconds, 3)
    budget = $budget
    selectedShips = @($shipResults | ForEach-Object { $_.ship })
    excludedShips = if ($scopeResult) { @($scopeResult.excluded) } else { @() }
    fatalError = $fatal
    actionsExecuted = @($shipResults | Where-Object { $_.executed }).Count
    approvedPacketEvidence = $approvedPacketEvidenceResult
    ships = @($shipResults)
    nextCaptainAction = if ($status -eq "GREEN") { "Review the cycle report; proceed to the next Stage 8 phase or run a focused audit." } elseif ($status -eq "YELLOW") { "Inspect contained action failures before rerunning Stage 8." } else { "Fix the fatal scope/config error before running the wrapper again." }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonFull) | Out-Null
$result | ConvertTo-Json -Depth 12 | Set-Content -Path $jsonFull -Encoding UTF8

$summaryLines = @(
    "# Stage 8 Autonomy Cycle",
    "",
    "## Captain Summary",
    "",
    "- Status: $status",
    "- Mode: $mode",
    "- Ships selected: $(@($shipResults).Count)",
    "- Actions executed: $($result.actionsExecuted)",
    "- Next: $($result.nextCaptainAction)",
    ""
)
if (![string]::IsNullOrWhiteSpace($fatal)) {
    $summaryLines += "- Fatal blocker: $(Get-FleetAutonomyShortText -Text $fatal -MaxLength 220)"
}
if ($approvedPacketEvidenceResult.path) {
    $summaryLines += "- Packet evidence: $($approvedPacketEvidenceResult.path)"
}

$lines = @(
    "## Run Details",
    "",
    "- Run ID: $runId",
    "- Mode: $mode",
    "- Status: $status",
    "- Started: $($result.startedAt)",
    "- Ended: $($result.endedAt)",
    "- Max cycles: $($budget.maxCycles)",
    "- Low-token mode: $($budget.lowTokenMode)",
    "",
    "## Selected Ships",
    ""
)
if ($shipResults.Count -eq 0) { $lines += "- None" } else { foreach ($shipResult in $shipResults) { $lines += "- $($shipResult.ship): $($shipResult.decision) -> $($shipResult.action) ($($shipResult.executionStatus))" } }
$lines += @(
    "",
    "## Ship Actions",
    "",
    "| Ship | State | Decision | Action | Executed | Risk | Reason | Required Approval |",
    "| --- | --- | --- | --- | --- | --- | --- | --- |"
)
foreach ($shipResult in $shipResults) {
    $reason = (Get-FleetAutonomyShortText -Text ([string]$shipResult.reason) -MaxLength 180).Replace("|", "/")
    $approval = (Get-FleetAutonomyShortText -Text ([string]$shipResult.requiredApproval) -MaxLength 160).Replace("|", "/")
    $lines += "| $($shipResult.ship) | $($shipResult.state) | $($shipResult.decision) | $($shipResult.action) | $($shipResult.executed) | $($shipResult.risk) | $reason | $approval |"
}
$lines += @(
    "",
    "## Skipped Or Blocked",
    ""
)
$blocked = @($shipResults | Where-Object { $_.action -eq "BLOCK_WITH_REASON" -or ![string]::IsNullOrWhiteSpace([string]$_.blockedReason) -or ![string]::IsNullOrWhiteSpace([string]$_.error) })
if ($blocked.Count -eq 0 -and [string]::IsNullOrWhiteSpace($fatal)) { $lines += "- None" } else {
    if ($fatal) { $lines += "- Fatal: $fatal" }
    foreach ($item in $blocked) {
        $why = if ($item.error) { $item.error } elseif ($item.blockedReason) { $item.blockedReason } else { $item.reason }
        $lines += "- $($item.ship): $(Get-FleetAutonomyShortText -Text $why -MaxLength 260)"
    }
}
$lines += @(
    "",
    "## Budget Usage",
    "",
    "- Cycles used: 1",
    "- Actions executed: $($result.actionsExecuted)",
    "- Max run batches per ship: $($budget.maxRunBatchesPerShip)",
    "- Max repair attempts: $($budget.maxRepairAttempts)",
    "- Max audit packages: $($budget.maxAuditPackages)",
    "- Max task packet imports: $($budget.maxTaskPacketImports)",
    "",
    "## Next Captain Action",
    "",
    $result.nextCaptainAction,
    "",
    "## Stage 9 Readiness",
    "",
    "- Stage 8.5 remains a local wrapper hardening pass.",
    "- Stage 9 should formalize external agent package handoff and stricter packet import workflows.",
    "- Stage 10 should handle automatic rate-limit detection and resume; Stage 8.5 only supports manual LowTokenMode."
)

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFull) | Out-Null
@($summaryLines + $lines) | Set-Content -Path $reportFull -Encoding UTF8

Write-Host "STAGE8_STATUS: $status"
Write-Host "STAGE8_REPORT: $reportFull"
Write-Host "STAGE8_JSON: $jsonFull"
if ($status -eq "RED") { exit 1 }
if ($status -eq "YELLOW") { exit 2 }
exit 0
