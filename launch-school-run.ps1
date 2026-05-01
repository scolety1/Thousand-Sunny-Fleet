[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string[]]$ExcludeProject = @("CursorPets"),

    [string[]]$ExpectedProject = @(),

    [ValidateSet("cheap", "balanced", "premium")]
    [string]$BudgetMode = "cheap",

    [ValidateSet("auto", "brief", "foundation", "shape", "simplicity", "polish", "proof", "parked", "repair", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof")]
    [string]$LoopPhase = "auto",

    [int]$BatchSize = 3,

    [int]$MaxBatches = 10,

    [int]$MaxRuntimeMinutes = 0,

    [int]$MaxCompletedTasks = 0,

    [int]$MaxPlannerBatches = 0,

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 5,

    [int]$MaxTaskQuarantines = 3,

    [switch]$SkipDoctor,

    [switch]$PushCheckpoint,

    [switch]$QuarantineFailedTasks,

    [switch]$AllowSafeStopRequests,

    [switch]$RequirePhaseValidation,

    [switch]$UseGlobalRunShape,

    [ValidateSet("off", "warn", "enforce")]
    [string]$LaunchGateMode = "warn",

    [ValidateSet("off", "warn", "enforce")]
    [string]$KillSwitchMode = "warn",

    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function ConvertTo-ProjectList {
    param([string[]]$Values)

    return @(
        $Values |
            ForEach-Object { [string]$_ } |
            ForEach-Object { $_ -split "," } |
            ForEach-Object { $_.Trim() } |
            Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
}

function Get-Projects {
    if (!(Test-Path $ConfigPath)) {
        Stop-WithMessage "Config not found: $ConfigPath"
    }

    $parsed = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsed | ForEach-Object { $_ })
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
        if ($projects.Count -ne 1) {
            Stop-WithMessage "Project not found: $Project"
        }
    }
    if ($ExcludeProject.Count -gt 0) {
        $exclude = @(ConvertTo-ProjectList -Values $ExcludeProject)
        $projects = @($projects | Where-Object { $exclude -notcontains [string]$_.name })
    }

    return $projects
}

function Get-ShipInt {
    param(
        [object]$Ship,
        [string]$Name,
        [int]$Default
    )

    if ($null -ne $Ship -and $Ship.PSObject.Properties[$Name]) {
        $value = $Ship.PSObject.Properties[$Name].Value
        if ($null -ne $value -and [int]$value -gt 0) {
            return [int]$value
        }
    }

    return $Default
}

function Get-MinPositive {
    param(
        [int]$Value,
        [int]$Cap
    )

    if ($Value -le 0) { return $Value }
    if ($Cap -le 0) { return $Value }
    return [Math]::Min($Value, $Cap)
}

function Resolve-BudgetShape {
    param(
        [int]$ShipBatchSize,
        [int]$ShipMaxBatches,
        [int]$ShipMaxRuntimeMinutes,
        [int]$ShipMaxCompletedTasks,
        [int]$ShipMaxPlannerBatches,
        [int]$ShipVisualEvery,
        [int]$ShipSimonEvery,
        [int]$ShipRobinEvery,
        [int]$ShipAccessibilityEvery,
        [int]$ShipPerformanceEvery,
        [int]$ShipJoeyEvery
    )

    if ($BudgetMode -eq "cheap") {
        return [pscustomobject]@{
            batchSize = Get-MinPositive -Value $ShipBatchSize -Cap 1
            maxBatches = Get-MinPositive -Value $ShipMaxBatches -Cap 3
            maxRuntimeMinutes = Get-MinPositive -Value $ShipMaxRuntimeMinutes -Cap 120
            maxCompletedTasks = Get-MinPositive -Value $ShipMaxCompletedTasks -Cap 2
            maxPlannerBatches = Get-MinPositive -Value $ShipMaxPlannerBatches -Cap 2
            visualEvery = if ($ShipVisualEvery -gt 0) { [Math]::Max($ShipVisualEvery, 2) } else { 0 }
            simonEvery = if ($ShipSimonEvery -gt 0) { [Math]::Max($ShipSimonEvery, 2) } else { 0 }
            robinEvery = if ($ShipRobinEvery -gt 0) { [Math]::Max($ShipRobinEvery, 3) } else { 0 }
            accessibilityEvery = if ($ShipAccessibilityEvery -gt 0) { [Math]::Max($ShipAccessibilityEvery, 4) } else { 0 }
            performanceEvery = if ($ShipPerformanceEvery -gt 0) { [Math]::Max($ShipPerformanceEvery, 4) } else { 0 }
            joeyEvery = if ($ShipJoeyEvery -gt 0) { [Math]::Max($ShipJoeyEvery, 6) } else { 0 }
        }
    }

    if ($BudgetMode -eq "premium") {
        return [pscustomobject]@{
            batchSize = $ShipBatchSize
            maxBatches = $ShipMaxBatches
            maxRuntimeMinutes = $ShipMaxRuntimeMinutes
            maxCompletedTasks = $ShipMaxCompletedTasks
            maxPlannerBatches = $ShipMaxPlannerBatches
            visualEvery = if ($ShipVisualEvery -gt 0) { 1 } else { 0 }
            simonEvery = if ($ShipSimonEvery -gt 0) { 1 } else { 0 }
            robinEvery = if ($ShipRobinEvery -gt 0) { 1 } else { 0 }
            accessibilityEvery = if ($ShipAccessibilityEvery -gt 0) { 1 } else { 0 }
            performanceEvery = if ($ShipPerformanceEvery -gt 0) { 1 } else { 0 }
            joeyEvery = $ShipJoeyEvery
        }
    }

    return [pscustomobject]@{
        batchSize = $ShipBatchSize
        maxBatches = $ShipMaxBatches
        maxRuntimeMinutes = $ShipMaxRuntimeMinutes
        maxCompletedTasks = $ShipMaxCompletedTasks
        maxPlannerBatches = $ShipMaxPlannerBatches
        visualEvery = $ShipVisualEvery
        simonEvery = $ShipSimonEvery
        robinEvery = $ShipRobinEvery
        accessibilityEvery = $ShipAccessibilityEvery
        performanceEvery = $ShipPerformanceEvery
        joeyEvery = $ShipJoeyEvery
    }
}

if ($BatchSize -lt 1) { Stop-WithMessage "-BatchSize must be at least 1." }
if ($MaxBatches -lt 1) { Stop-WithMessage "-MaxBatches must be at least 1." }
if ($MaxRuntimeMinutes -lt 0) { Stop-WithMessage "-MaxRuntimeMinutes must be 0 or greater." }
if ($MaxCompletedTasks -lt 0) { Stop-WithMessage "-MaxCompletedTasks must be 0 or greater." }
if ($MaxPlannerBatches -lt 0) { Stop-WithMessage "-MaxPlannerBatches must be 0 or greater." }
if ($MaxTaskQuarantines -lt 0) { Stop-WithMessage "-MaxTaskQuarantines must be 0 or greater." }

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")
Assert-NoFleetSafeStopRequests -FleetRoot $fleetRoot -ProjectFilter $Project -ExcludeProject $ExcludeProject -AllowSafeStopRequests:$AllowSafeStopRequests

if (!$SkipDoctor) {
    $doctorArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fleetRoot "fleet-doctor.ps1"), "-ConfigPath", $ConfigPath)
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $doctorArgs += @("-Project", $Project)
    }
    $doctorExclusions = @($ExcludeProject | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
    if ($doctorExclusions.Count -gt 0) {
        $doctorArgs += @("-ExcludeProject", ($doctorExclusions -join ","))
    }
    & powershell @doctorArgs
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "School run refused. Chopper found a ship that is not ready."
    }
}

$shipsToLaunch = @(Get-Projects)
$expectedProjects = @(ConvertTo-ProjectList -Values $ExpectedProject)
if ($expectedProjects.Count -gt 0) {
    $actualProjects = @($shipsToLaunch | ForEach-Object { [string]$_.name } | Sort-Object -Unique)
    $missing = @($expectedProjects | Where-Object { $actualProjects -notcontains $_ })
    $unexpected = @($actualProjects | Where-Object { $expectedProjects -notcontains $_ })
    if ($missing.Count -gt 0 -or $unexpected.Count -gt 0) {
        Write-Host "Selected launch validation failed." -ForegroundColor Red
        Write-Host "Expected: $($expectedProjects -join ', ')" -ForegroundColor Yellow
        Write-Host "Actual: $($actualProjects -join ', ')" -ForegroundColor Yellow
        if ($missing.Count -gt 0) { Write-Host "Missing: $($missing -join ', ')" -ForegroundColor Yellow }
        if ($unexpected.Count -gt 0) { Write-Host "Unexpected: $($unexpected -join ', ')" -ForegroundColor Yellow }
        exit 1
    }
}

if ($RequirePhaseValidation) {
    foreach ($ship in $shipsToLaunch) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "fleet-phase.ps1") -ConfigPath $ConfigPath -Project ([string]$ship.name) -Validate
        if ($LASTEXITCODE -ne 0) {
            Stop-WithMessage "School run refused. Phase state validation failed for $($ship.name)."
        }
    }
}

$manifestProjectFilter = $Project
if ($expectedProjects.Count -gt 0) {
    $manifestProjectFilter = $expectedProjects -join ", "
}
$manifestMode = if ($DryRun) { "school-proof" } else { "school" }
$latestManifestFile = if ($DryRun) { "latest-proof-launch.md" } else { "latest-launch.md" }
$manifest = New-FleetLaunchManifest -FleetRoot $fleetRoot -Mode $manifestMode -ConfigPath $ConfigPath -ProjectFilter $manifestProjectFilter -LatestFileName $latestManifestFile
foreach ($ship in $shipsToLaunch) {
    $shipBatchSize = if ($UseGlobalRunShape) { $BatchSize } else { Get-ShipInt -Ship $ship -Name "schoolBatchSize" -Default $BatchSize }
    $shipMaxBatches = if ($UseGlobalRunShape) { $MaxBatches } else { Get-ShipInt -Ship $ship -Name "schoolMaxBatches" -Default $MaxBatches }
    $shipMaxRuntimeMinutes = if ($UseGlobalRunShape) { $MaxRuntimeMinutes } else { Get-ShipInt -Ship $ship -Name "schoolMaxRuntimeMinutes" -Default $MaxRuntimeMinutes }
    $shipMaxCompletedTasks = if ($UseGlobalRunShape) { $MaxCompletedTasks } else { Get-ShipInt -Ship $ship -Name "schoolMaxCompletedTasks" -Default $MaxCompletedTasks }
    $shipMaxPlannerBatches = if ($UseGlobalRunShape) { $MaxPlannerBatches } else { Get-ShipInt -Ship $ship -Name "schoolMaxPlannerBatches" -Default $MaxPlannerBatches }
    $shipVisualEvery = if ($UseGlobalRunShape) { 2 } else { Get-ShipInt -Ship $ship -Name "schoolVisualInspectEvery" -Default 2 }
    $shipSimonEvery = if ($UseGlobalRunShape) { 2 } else { Get-ShipInt -Ship $ship -Name "schoolSimonEvery" -Default 2 }
    $shipRobinEvery = if ($UseGlobalRunShape) { 2 } else { Get-ShipInt -Ship $ship -Name "schoolRobinEvery" -Default 2 }
    $shipAccessibilityEvery = if ($UseGlobalRunShape) { 3 } else { Get-ShipInt -Ship $ship -Name "schoolAccessibilityEvery" -Default 3 }
    $shipPerformanceEvery = if ($UseGlobalRunShape) { 3 } else { Get-ShipInt -Ship $ship -Name "schoolPerformanceEvery" -Default 3 }
    $shipJoeyEvery = if ($UseGlobalRunShape) { 4 } else { Get-ShipInt -Ship $ship -Name "schoolJoeyEvery" -Default 4 }
    $budgetShape = Resolve-BudgetShape -ShipBatchSize $shipBatchSize -ShipMaxBatches $shipMaxBatches -ShipMaxRuntimeMinutes $shipMaxRuntimeMinutes -ShipMaxCompletedTasks $shipMaxCompletedTasks -ShipMaxPlannerBatches $shipMaxPlannerBatches -ShipVisualEvery $shipVisualEvery -ShipSimonEvery $shipSimonEvery -ShipRobinEvery $shipRobinEvery -ShipAccessibilityEvery $shipAccessibilityEvery -ShipPerformanceEvery $shipPerformanceEvery -ShipJoeyEvery $shipJoeyEvery

    $command = @(
        "Set-Location '$fleetRoot'",
        ".\run-checkpoint-loop.ps1 -ConfigPath '$ConfigPath' -Project '$($ship.name)' -BatchSize $($budgetShape.batchSize) -MaxBatches $($budgetShape.maxBatches) -MaxRuntimeMinutes $($budgetShape.maxRuntimeMinutes) -MaxCompletedTasks $($budgetShape.maxCompletedTasks) -MaxPlannerBatches $($budgetShape.maxPlannerBatches) -ModelBudget $BudgetMode -LoopPhase $LoopPhase -LaunchGateMode $LaunchGateMode -KillSwitchMode $KillSwitchMode -VisualInspectEvery $($budgetShape.visualEvery) -SimonEvery $($budgetShape.simonEvery) -RobinEvery $($budgetShape.robinEvery) -AccessibilityEvery $($budgetShape.accessibilityEvery) -PerformanceEvery $($budgetShape.performanceEvery) -JoeyEvery $($budgetShape.joeyEvery) -ContinueOnYellowCheckpoint -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns -MaxTaskQuarantines $MaxTaskQuarantines$(if ($QuarantineFailedTasks) { ' -QuarantineFailedTasks' } else { '' })$(if ($PushCheckpoint) { ' -PushCheckpoint' } else { '' })"
    ) -join "; "

    Write-Host "Launching school run for $($ship.name): budget $BudgetMode, batch $($budgetShape.batchSize) x $($budgetShape.maxBatches), max $($budgetShape.maxCompletedTasks) tasks, max $($budgetShape.maxRuntimeMinutes) minutes, planner batches $($budgetShape.maxPlannerBatches), visual $($budgetShape.visualEvery), Simon $($budgetShape.simonEvery), Robin $($budgetShape.robinEvery), accessibility $($budgetShape.accessibilityEvery), performance $($budgetShape.performanceEvery), Joey $($budgetShape.joeyEvery)..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host $command
        Add-FleetLaunchManifestEntry -Manifest $manifest -Ship $ship.name -Command $command -DryRun
    } else {
        $process = Start-Process powershell -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) -PassThru
        Add-FleetLaunchManifestEntry -Manifest $manifest -Ship $ship.name -Command $command -ProcessId $process.Id
    }
}

Write-FleetLaunchManifest -Manifest $manifest
