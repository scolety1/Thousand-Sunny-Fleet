[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ManifestPath = ".\experiment-manifest.json",

    [string]$ConfigPath = ".\projects.json",

    [string]$OutPath = ".\out\fleet-experiment.md",

    [string]$JsonOutPath = ".\out\fleet-experiment.json",

    [switch]$Template,

    [switch]$DryRun,

    [switch]$SkipDoctor,

    [switch]$AllowDirty,

    [switch]$AllowSafeStopRequests
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")

function Stop-Experiment {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Resolve-ControlPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    return Join-Path $fleetRoot $Path
}

function ConvertTo-ExperimentList {
    param([object]$Value)

    if ($null -eq $Value) { return @() }
    return @(
        @($Value) |
            ForEach-Object { [string]$_ } |
            ForEach-Object { $_ -split "," } |
            ForEach-Object { $_.Trim() } |
            Where-Object { ![string]::IsNullOrWhiteSpace($_) }
    )
}

function ConvertTo-ExperimentTextList {
    param([object]$Value)

    if ($null -eq $Value) { return @() }
    return @(
        @($Value) |
            ForEach-Object { [string]$_ } |
            ForEach-Object { $_.Trim() } |
            Where-Object { ![string]::IsNullOrWhiteSpace($_) }
    )
}

function Get-ManifestInt {
    param(
        [object]$Manifest,
        [string]$Name,
        [int]$Default
    )

    if ($null -ne $Manifest -and $Manifest.PSObject.Properties[$Name]) {
        $value = $Manifest.PSObject.Properties[$Name].Value
        if ($null -ne $value -and [int]$value -gt 0) {
            return [int]$value
        }
    }
    return $Default
}

function Get-ManifestString {
    param(
        [object]$Manifest,
        [string]$Name,
        [string]$Default
    )

    if ($null -ne $Manifest -and $Manifest.PSObject.Properties[$Name]) {
        $value = [string]$Manifest.PSObject.Properties[$Name].Value
        if (![string]::IsNullOrWhiteSpace($value)) {
            return $value
        }
    }
    return $Default
}

function Get-ReviewerCadenceInt {
    param(
        [object]$Cadence,
        [string]$Name,
        [int]$Default
    )

    if ($null -ne $Cadence -and $Cadence.PSObject.Properties[$Name]) {
        $value = $Cadence.PSObject.Properties[$Name].Value
        if ($null -ne $value -and [int]$value -ge 0) {
            return [int]$value
        }
    }
    return $Default
}

function Get-ShipRuntimeMinutes {
    param(
        [object]$Manifest,
        [string]$ShipName,
        [int]$DefaultMinutes
    )

    if ($null -ne $Manifest.perShipRuntimeMinutes -and $Manifest.perShipRuntimeMinutes.PSObject.Properties[$ShipName]) {
        $value = $Manifest.perShipRuntimeMinutes.PSObject.Properties[$ShipName].Value
        if ($null -ne $value -and [double]$value -gt 0) {
            return [double]$value
        }
    }
    return [double]$DefaultMinutes
}

function Write-ExperimentTemplate {
    param([string]$Path)

    $template = [pscustomobject]@{
        experimentName = "thousand-sunny-three-ship-smoke"
        selectedShips = @("Bottlelight", "ShiftLedger", "OrderPilot")
        workloadClass = "static-demo-polish"
        sharedTaskParameters = "Same mission shape, one bounded task per ship, no package/backend/auth/payment/deploy changes."
        loopPhase = "simplicity"
        modelBudget = "cheap"
        batchSize = 1
        maxBatches = 1
        maxRuntimeMinutes = 45
        baselineSerialMinutes = 135
        reviewerCadence = [pscustomobject]@{
            visualInspectEvery = 1
            simonEvery = 1
            robinEvery = 1
            accessibilityEvery = 1
            performanceEvery = 1
            joeyEvery = 0
        }
        successCriteria = @(
            "Each selected ship completes or stops with a clear gate reason.",
            "Fleet writes Markdown and JSON evidence for speedup, efficiency, load imbalance, and retry overhead.",
            "No dirty active ship is touched."
        )
        perShipRuntimeMinutes = [pscustomobject]@{
            Bottlelight = 45
            ShiftLedger = 45
            OrderPilot = 45
        }
    }

    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $template | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
    Write-Host "Experiment template written: $Path" -ForegroundColor Green
}

function Get-ProjectsFromConfig {
    param([string]$Path)

    if (!(Test-Path $Path)) {
        Stop-Experiment "Config not found: $Path"
    }

    return @(Get-Content $Path -Raw | ConvertFrom-Json | ForEach-Object { $_ })
}

function Test-RepoDirty {
    param([string]$Repo)

    if (!(Test-Path $Repo)) {
        return $true
    }

    Push-Location $Repo
    try {
        $status = @(git status --short 2>$null)
        if ($LASTEXITCODE -ne 0) {
            return $true
        }
        return ($status.Count -gt 0)
    } finally {
        Pop-Location
    }
}

function New-ExperimentCommand {
    param(
        [object]$Manifest,
        [object]$Ship,
        [int]$BatchSize,
        [int]$MaxBatches,
        [string]$LoopPhase,
        [string]$ModelBudget,
        [int]$VisualInspectEvery,
        [int]$SimonEvery,
        [int]$RobinEvery,
        [int]$AccessibilityEvery,
        [int]$PerformanceEvery,
        [int]$JoeyEvery
    )

    return @(
        "Set-Location '$fleetRoot'",
        ".\run-checkpoint-loop.ps1 -Project '$($Ship.name)' -BatchSize $BatchSize -MaxBatches $MaxBatches -ModelBudget $ModelBudget -LoopPhase $LoopPhase -LaunchGateMode warn -KillSwitchMode warn -VisualInspectEvery $VisualInspectEvery -SimonEvery $SimonEvery -RobinEvery $RobinEvery -AccessibilityEvery $AccessibilityEvery -PerformanceEvery $PerformanceEvery -JoeyEvery $JoeyEvery -ContinueOnYellowCheckpoint -MaxTaskQuarantines 1"
    ) -join "; "
}

function New-ExperimentMetrics {
    param(
        [object]$Manifest,
        [object[]]$Entries,
        [int]$MaxRuntimeMinutes,
        [double]$BaselineSerialMinutes
    )

    $shipCount = @($Entries).Count
    $plannedDurations = @($Entries | ForEach-Object { [double]$_.plannedRuntimeMinutes })
    $parallelWallClock = if ($plannedDurations.Count -gt 0) { [double]($plannedDurations | Measure-Object -Maximum).Maximum } else { [double]$MaxRuntimeMinutes }
    if ($parallelWallClock -le 0) { $parallelWallClock = [double]$MaxRuntimeMinutes }
    if ($parallelWallClock -le 0) { $parallelWallClock = 1.0 }

    if ($BaselineSerialMinutes -le 0) {
        $BaselineSerialMinutes = [double](($plannedDurations | Measure-Object -Sum).Sum)
    }
    if ($BaselineSerialMinutes -le 0) {
        $BaselineSerialMinutes = [double]($shipCount * $parallelWallClock)
    }

    $speedup = [Math]::Round(($BaselineSerialMinutes / $parallelWallClock), 3)
    $efficiency = if ($shipCount -gt 0) { [Math]::Round(($speedup / $shipCount), 3) } else { 0 }
    $average = if ($plannedDurations.Count -gt 0) { [double]($plannedDurations | Measure-Object -Average).Average } else { 0 }
    $maximum = if ($plannedDurations.Count -gt 0) { [double]($plannedDurations | Measure-Object -Maximum).Maximum } else { 0 }
    $minimum = if ($plannedDurations.Count -gt 0) { [double]($plannedDurations | Measure-Object -Minimum).Minimum } else { 0 }
    $loadImbalance = if ($average -gt 0) { [Math]::Round((($maximum - $average) / $average), 3) } else { 0 }

    return [pscustomobject]@{
        shipCount = $shipCount
        baselineSerialMinutes = [Math]::Round($BaselineSerialMinutes, 3)
        parallelWallClockMinutes = [Math]::Round($parallelWallClock, 3)
        speedup = $speedup
        efficiency = $efficiency
        minShipRuntimeMinutes = [Math]::Round($minimum, 3)
        avgShipRuntimeMinutes = [Math]::Round($average, 3)
        maxShipRuntimeMinutes = [Math]::Round($maximum, 3)
        loadImbalance = $loadImbalance
        failureRetryOverhead = 0
        reviewerGateOverhead = "tracked by checkpoint reports after real runs"
    }
}

$manifestFullPath = Resolve-ControlPath -Path $ManifestPath
$outFullPath = Resolve-ControlPath -Path $OutPath
$jsonOutFullPath = Resolve-ControlPath -Path $JsonOutPath
$configFullPath = Resolve-ControlPath -Path $ConfigPath

if ($Template) {
    Write-ExperimentTemplate -Path $manifestFullPath
    exit 0
}

if (!(Test-Path $manifestFullPath)) {
    Stop-Experiment "Experiment manifest not found: $manifestFullPath. Create one with .\fleet-experiment.ps1 -Template."
}

$manifest = $null
try {
    $manifest = Get-Content $manifestFullPath -Raw | ConvertFrom-Json
} catch {
    Stop-Experiment "Experiment manifest is not valid JSON: $manifestFullPath"
}

$experimentName = Get-ManifestString -Manifest $manifest -Name "experimentName" -Default "unnamed-experiment"
$selectedShips = @(ConvertTo-ExperimentList -Value $manifest.selectedShips)
if ($selectedShips.Count -eq 0) {
    Stop-Experiment "Experiment manifest must include selectedShips."
}

$loopPhase = Get-ManifestString -Manifest $manifest -Name "loopPhase" -Default "simplicity"
$modelBudget = Get-ManifestString -Manifest $manifest -Name "modelBudget" -Default "cheap"
if (@("auto", "brief", "foundation", "shape", "simplicity", "polish", "proof", "parked", "repair", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof") -notcontains $loopPhase) {
    Stop-Experiment "Invalid loopPhase '$loopPhase'."
}
if (@("cheap", "balanced", "premium") -notcontains $modelBudget) {
    Stop-Experiment "Invalid modelBudget '$modelBudget'."
}

$batchSize = Get-ManifestInt -Manifest $manifest -Name "batchSize" -Default 1
$maxBatches = Get-ManifestInt -Manifest $manifest -Name "maxBatches" -Default 1
$maxRuntimeMinutes = Get-ManifestInt -Manifest $manifest -Name "maxRuntimeMinutes" -Default 45
$baselineSerialMinutes = [double](Get-ManifestInt -Manifest $manifest -Name "baselineSerialMinutes" -Default 0)

$cadence = $manifest.reviewerCadence
$visualInspectEvery = Get-ReviewerCadenceInt -Cadence $cadence -Name "visualInspectEvery" -Default 1
$simonEvery = Get-ReviewerCadenceInt -Cadence $cadence -Name "simonEvery" -Default 1
$robinEvery = Get-ReviewerCadenceInt -Cadence $cadence -Name "robinEvery" -Default 1
$accessibilityEvery = Get-ReviewerCadenceInt -Cadence $cadence -Name "accessibilityEvery" -Default 1
$performanceEvery = Get-ReviewerCadenceInt -Cadence $cadence -Name "performanceEvery" -Default 1
$joeyEvery = Get-ReviewerCadenceInt -Cadence $cadence -Name "joeyEvery" -Default 0

if ($batchSize -lt 1) { Stop-Experiment "batchSize must be at least 1." }
if ($maxBatches -lt 1) { Stop-Experiment "maxBatches must be at least 1." }
if ($maxRuntimeMinutes -lt 1) { Stop-Experiment "maxRuntimeMinutes must be at least 1." }

Assert-NoFleetSafeStopRequests -FleetRoot $fleetRoot -ProjectFilter "" -ExcludeProject @() -AllowSafeStopRequests:$AllowSafeStopRequests

$projects = @(Get-ProjectsFromConfig -Path $configFullPath)
$selectedProjects = @()
$missingShips = [System.Collections.Generic.List[string]]::new()
foreach ($shipName in $selectedShips) {
    $match = @($projects | Where-Object { [string]$_.name -ceq $shipName })
    if ($match.Count -ne 1) {
        $missingShips.Add($shipName) | Out-Null
    } else {
        $selectedProjects += $match[0]
    }
}
if ($missingShips.Count -gt 0) {
    Stop-Experiment "Experiment references unknown ship(s): $($missingShips -join ', ')"
}

$dirtyShips = @()
if (!$AllowDirty) {
    foreach ($ship in $selectedProjects) {
        if (Test-RepoDirty -Repo ([string]$ship.repo)) {
            $dirtyShips += [string]$ship.name
        }
    }
}
if ($dirtyShips.Count -gt 0) {
    Stop-Experiment "Experiment refused because selected ship(s) are dirty or unreadable: $($dirtyShips -join ', '). Use -AllowDirty only for an approved rescue."
}

if (!$SkipDoctor) {
    foreach ($shipName in $selectedShips) {
        $doctorArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fleetRoot "fleet-doctor.ps1"), "-ConfigPath", $configFullPath, "-Project", $shipName)
        & powershell @doctorArgs
        if ($LASTEXITCODE -ne 0) {
            Stop-Experiment "Experiment refused. Chopper found that $shipName is not ready."
        }
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outFullPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonOutFullPath) | Out-Null

$experimentId = "{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss-fff"), ([guid]::NewGuid().ToString("N").Substring(0, 6))
$startedAt = Get-Date
$entries = [System.Collections.Generic.List[object]]::new()
$queueIndex = 0
foreach ($ship in $selectedProjects) {
    $plannedRuntime = Get-ShipRuntimeMinutes -Manifest $manifest -ShipName ([string]$ship.name) -DefaultMinutes $maxRuntimeMinutes
    $command = New-ExperimentCommand -Manifest $manifest -Ship $ship -BatchSize $batchSize -MaxBatches $maxBatches -LoopPhase $loopPhase -ModelBudget $modelBudget -VisualInspectEvery $visualInspectEvery -SimonEvery $simonEvery -RobinEvery $robinEvery -AccessibilityEvery $accessibilityEvery -PerformanceEvery $performanceEvery -JoeyEvery $joeyEvery
    $queuedAt = $startedAt.AddSeconds($queueIndex)
    $processId = 0
    $launchStatus = "DRY_RUN"
    if (!$DryRun) {
        $process = Start-Process powershell -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) -PassThru
        $processId = $process.Id
        $launchStatus = "LAUNCHED"
    }

    $entries.Add([pscustomobject]@{
        ship = [string]$ship.name
        repo = [string]$ship.repo
        queueIndex = $queueIndex
        queuedAt = $queuedAt.ToString("o")
        launchedAt = (Get-Date).ToString("o")
        processId = $processId
        status = $launchStatus
        plannedRuntimeMinutes = $plannedRuntime
        retryCount = 0
        stopReason = if ($DryRun) { "dry-run only" } else { "running or pending checkpoint report" }
        command = $command
    }) | Out-Null
    $queueIndex += 1
}

$metrics = New-ExperimentMetrics -Manifest $manifest -Entries @($entries) -MaxRuntimeMinutes $maxRuntimeMinutes -BaselineSerialMinutes $baselineSerialMinutes

$json = [pscustomobject]@{
    experimentId = $experimentId
    experimentName = $experimentName
    manifestPath = $manifestFullPath
    configPath = $configFullPath
    dryRun = [bool]$DryRun
    workloadClass = Get-ManifestString -Manifest $manifest -Name "workloadClass" -Default "unspecified"
    sharedTaskParameters = Get-ManifestString -Manifest $manifest -Name "sharedTaskParameters" -Default ""
    loopPhase = $loopPhase
    modelBudget = $modelBudget
    batchSize = $batchSize
    maxBatches = $maxBatches
    maxRuntimeMinutes = $maxRuntimeMinutes
    reviewerCadence = [pscustomobject]@{
        visualInspectEvery = $visualInspectEvery
        simonEvery = $simonEvery
        robinEvery = $robinEvery
        accessibilityEvery = $accessibilityEvery
        performanceEvery = $performanceEvery
        joeyEvery = $joeyEvery
    }
    successCriteria = @(ConvertTo-ExperimentTextList -Value $manifest.successCriteria)
    startedAt = $startedAt.ToString("o")
    writtenAt = (Get-Date).ToString("o")
    metrics = $metrics
    entries = @($entries)
}
$json | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonOutFullPath -Encoding UTF8

$lines = @(
    "# Fleet Experiment",
    "",
    "- Experiment: $experimentName",
    "- ID: $experimentId",
    "- Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE LAUNCH' })",
    "- Workload class: $($json.workloadClass)",
    "- Loop phase: $loopPhase",
    "- Model budget: $modelBudget",
    "- Batch shape: $batchSize x $maxBatches",
    "- Max runtime cap: $maxRuntimeMinutes minutes",
    "- Manifest: $manifestFullPath",
    "- Raw JSON: $jsonOutFullPath",
    "",
    "## HPC Metrics",
    "",
    "| Metric | Value |",
    "| --- | ---: |",
    "| Ships | $($metrics.shipCount) |",
    "| Serial baseline minutes | $($metrics.baselineSerialMinutes) |",
    "| Parallel wall-clock minutes | $($metrics.parallelWallClockMinutes) |",
    "| Speedup | $($metrics.speedup) |",
    "| Efficiency | $($metrics.efficiency) |",
    "| Load imbalance | $($metrics.loadImbalance) |",
    "| Failure/retry overhead | $($metrics.failureRetryOverhead) |",
    "",
    "## Reviewer Cadence",
    "",
    "- Visual inspect every: $visualInspectEvery",
    "- Simon every: $simonEvery",
    "- Robin every: $robinEvery",
    "- Accessibility every: $accessibilityEvery",
    "- Performance every: $performanceEvery",
    "- Joey every: $joeyEvery",
    "",
    "## Ships",
    "",
    "| Ship | PID | Status | Planned Minutes | Queue Index | Stop Reason |",
    "| --- | ---: | --- | ---: | ---: | --- |"
)

foreach ($entry in $entries) {
    $lines += "| $($entry.ship) | $($entry.processId) | $($entry.status) | $($entry.plannedRuntimeMinutes) | $($entry.queueIndex) | $($entry.stopReason) |"
}

$criteria = @(ConvertTo-ExperimentTextList -Value $manifest.successCriteria)
if ($criteria.Count -gt 0) {
    $lines += @("", "## Success Criteria", "")
    foreach ($criterion in $criteria) {
        $lines += "- $criterion"
    }
}

$lines += @("", "## Commands", "")
foreach ($entry in $entries) {
    $lines += @(
        "### $($entry.ship)",
        "",
        '```powershell',
        $entry.command,
        '```',
        ""
    )
}

Set-Content -Path $outFullPath -Value $lines -Encoding UTF8
Write-Host "Experiment report: $outFullPath" -ForegroundColor Green
Write-Host "Experiment JSON: $jsonOutFullPath" -ForegroundColor DarkCyan
exit 0
