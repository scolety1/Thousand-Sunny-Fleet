[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string[]]$ExcludeProject = @(),

    [string[]]$ExpectedProject = @(),

    [ValidateSet("cheap", "balanced", "premium")]
    [string]$BudgetMode = "balanced",

    [ValidateSet("auto", "brief", "foundation", "shape", "simplicity", "polish", "proof", "parked", "repair", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof")]
    [string]$LoopPhase = "auto",

    [int]$BatchSize = 3,

    [int]$MaxBatches = 20,

    [int]$MaxRuntimeMinutes = 360,

    [int]$MaxCompletedTasks = 6,

    [int]$MaxPlannerBatches = 1,

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 8,

    [int]$MaxTaskQuarantines = 5,

    [int]$LaunchDelaySeconds = 0,

    [int]$VisualInspectEvery = 0,

    [int]$SimonEvery = 0,

    [int]$RobinEvery = 0,

    [int]$AccessibilityEvery = 0,

    [int]$PerformanceEvery = 0,

    [int]$JoeyEvery = 0,

    [switch]$SkipDoctor,

    [switch]$PushCheckpoint,

    [switch]$QuarantineFailedTasks,

    [switch]$AllowSafeStopRequests,

    [switch]$RequireMagicPreflight,

    [switch]$RequirePhaseValidation,

    [switch]$UseGlobalRunShape,

    [switch]$Safe12,

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
    param([string[]]$Values = @())

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
            maxBatches = Get-MinPositive -Value $ShipMaxBatches -Cap 4
            maxRuntimeMinutes = Get-MinPositive -Value $ShipMaxRuntimeMinutes -Cap 180
            maxCompletedTasks = Get-MinPositive -Value $ShipMaxCompletedTasks -Cap 3
            maxPlannerBatches = Get-MinPositive -Value $ShipMaxPlannerBatches -Cap 4
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
if ($RateLimitCooldownSeconds -lt 60) { Stop-WithMessage "-RateLimitCooldownSeconds must be at least 60." }
if ($RateLimitMaxCooldowns -lt 0) { Stop-WithMessage "-RateLimitMaxCooldowns must be 0 or greater." }
if ($MaxTaskQuarantines -lt 0) { Stop-WithMessage "-MaxTaskQuarantines must be 0 or greater." }
if ($LaunchDelaySeconds -lt 0) { Stop-WithMessage "-LaunchDelaySeconds must be 0 or greater." }
if ($VisualInspectEvery -lt 0) { Stop-WithMessage "-VisualInspectEvery must be 0 or greater." }
if ($SimonEvery -lt 0) { Stop-WithMessage "-SimonEvery must be 0 or greater." }
if ($RobinEvery -lt 0) { Stop-WithMessage "-RobinEvery must be 0 or greater." }
if ($AccessibilityEvery -lt 0) { Stop-WithMessage "-AccessibilityEvery must be 0 or greater." }
if ($PerformanceEvery -lt 0) { Stop-WithMessage "-PerformanceEvery must be 0 or greater." }
if ($JoeyEvery -lt 0) { Stop-WithMessage "-JoeyEvery must be 0 or greater." }

if ($Safe12) {
    $BatchSize = 1
    $MaxBatches = 24
    $MaxRuntimeMinutes = 720
    $MaxCompletedTasks = 14
    $MaxPlannerBatches = 0
    $VisualInspectEvery = 2
    $SimonEvery = 2
    $RobinEvery = 3
    $AccessibilityEvery = 4
    $PerformanceEvery = 4
    $JoeyEvery = 4
    $MaxTaskQuarantines = 5
    $BudgetMode = "balanced"
    $LoopPhase = "simplicity"
    $LaunchGateMode = "warn"
    $KillSwitchMode = "warn"
    $UseGlobalRunShape = $true
    $QuarantineFailedTasks = $true
    $PushCheckpoint = $true
}

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")
Assert-NoFleetSafeStopRequests -FleetRoot $fleetRoot -ProjectFilter $Project -ExcludeProject $ExcludeProject -AllowSafeStopRequests:$AllowSafeStopRequests

if (!$SkipDoctor) {
    $doctorArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fleetRoot "fleet-doctor.ps1"), "-ConfigPath", $ConfigPath)
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $doctorArgs += @("-Project", $Project)
    }
    $doctorExclusions = @(ConvertTo-ProjectList -Values $ExcludeProject)
    if ($doctorExclusions.Count -gt 0) {
        $doctorArgs += @("-ExcludeProject", ($doctorExclusions -join ","))
    }
    & powershell @doctorArgs
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "Overnight run refused. Chopper found a ship that is not ready."
    }
}

if ($RequireMagicPreflight) {
    $preflightArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fleetRoot "prepare-magic-run.ps1"), "-ConfigPath", $ConfigPath, "-AllowNoTasks", "-Strict")
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $preflightArgs += @("-Project", $Project)
    }
    $preflightExclusions = @(ConvertTo-ProjectList -Values $ExcludeProject)
    if ($preflightExclusions.Count -gt 0) {
        $preflightArgs += @("-ExcludeProject", ($preflightExclusions -join ","))
    }
    & powershell @preflightArgs
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "Overnight run refused. Magic preflight found a blocking ship."
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
            Stop-WithMessage "Overnight run refused. Phase state validation failed for $($ship.name)."
        }
    }
}

$manifestProjectFilter = $Project
if ($expectedProjects.Count -gt 0) {
    $manifestProjectFilter = $expectedProjects -join ", "
}
$manifestMode = if ($DryRun) { "overnight-proof" } else { "overnight" }
$latestManifestFile = if ($DryRun) { "latest-proof-launch.md" } else { "latest-launch.md" }
$manifest = New-FleetLaunchManifest -FleetRoot $fleetRoot -Mode $manifestMode -ConfigPath $ConfigPath -ProjectFilter $manifestProjectFilter -LatestFileName $latestManifestFile
for ($shipIndex = 0; $shipIndex -lt $shipsToLaunch.Count; $shipIndex++) {
    $ship = $shipsToLaunch[$shipIndex]
    $shipBatchSize = if ($UseGlobalRunShape) { $BatchSize } else { Get-ShipInt -Ship $ship -Name "overnightBatchSize" -Default $BatchSize }
    $shipMaxBatches = if ($UseGlobalRunShape) { $MaxBatches } else { Get-ShipInt -Ship $ship -Name "overnightMaxBatches" -Default $MaxBatches }
    $shipMaxRuntimeMinutes = if ($UseGlobalRunShape) { $MaxRuntimeMinutes } else { Get-ShipInt -Ship $ship -Name "overnightMaxRuntimeMinutes" -Default $MaxRuntimeMinutes }
    $shipMaxCompletedTasks = if ($UseGlobalRunShape) { $MaxCompletedTasks } else { Get-ShipInt -Ship $ship -Name "overnightMaxCompletedTasks" -Default $MaxCompletedTasks }
    $shipMaxPlannerBatches = if ($UseGlobalRunShape) { $MaxPlannerBatches } else { Get-ShipInt -Ship $ship -Name "overnightMaxPlannerBatches" -Default $MaxPlannerBatches }
    $shipVisualEvery = if ($VisualInspectEvery -gt 0) { $VisualInspectEvery } else { Get-ShipInt -Ship $ship -Name "overnightVisualInspectEvery" -Default 3 }
    $shipSimonEvery = if ($SimonEvery -gt 0) { $SimonEvery } else { Get-ShipInt -Ship $ship -Name "overnightSimonEvery" -Default 3 }
    $shipRobinEvery = if ($RobinEvery -gt 0) { $RobinEvery } else { Get-ShipInt -Ship $ship -Name "overnightRobinEvery" -Default $shipSimonEvery }
    $shipAccessibilityEvery = if ($AccessibilityEvery -gt 0) { $AccessibilityEvery } else { Get-ShipInt -Ship $ship -Name "overnightAccessibilityEvery" -Default 4 }
    $shipPerformanceEvery = if ($PerformanceEvery -gt 0) { $PerformanceEvery } else { Get-ShipInt -Ship $ship -Name "overnightPerformanceEvery" -Default 4 }
    $shipJoeyEvery = if ($JoeyEvery -gt 0) { $JoeyEvery } else { Get-ShipInt -Ship $ship -Name "overnightJoeyEvery" -Default 6 }
    $shipLaunchDelay = Get-ShipInt -Ship $ship -Name "launchDelaySeconds" -Default $LaunchDelaySeconds
    $budgetShape = Resolve-BudgetShape -ShipBatchSize $shipBatchSize -ShipMaxBatches $shipMaxBatches -ShipMaxRuntimeMinutes $shipMaxRuntimeMinutes -ShipMaxCompletedTasks $shipMaxCompletedTasks -ShipMaxPlannerBatches $shipMaxPlannerBatches -ShipVisualEvery $shipVisualEvery -ShipSimonEvery $shipSimonEvery -ShipRobinEvery $shipRobinEvery -ShipAccessibilityEvery $shipAccessibilityEvery -ShipPerformanceEvery $shipPerformanceEvery -ShipJoeyEvery $shipJoeyEvery

    $command = @(
        "Set-Location '$fleetRoot'",
        ".\run-checkpoint-loop.ps1 -ConfigPath '$ConfigPath' -Project '$($ship.name)' -BatchSize $($budgetShape.batchSize) -MaxBatches $($budgetShape.maxBatches) -MaxRuntimeMinutes $($budgetShape.maxRuntimeMinutes) -MaxCompletedTasks $($budgetShape.maxCompletedTasks) -MaxPlannerBatches $($budgetShape.maxPlannerBatches) -ModelBudget $BudgetMode -LoopPhase $LoopPhase -LaunchGateMode $LaunchGateMode -KillSwitchMode $KillSwitchMode -VisualInspectEvery $($budgetShape.visualEvery) -SimonEvery $($budgetShape.simonEvery) -RobinEvery $($budgetShape.robinEvery) -AccessibilityEvery $($budgetShape.accessibilityEvery) -PerformanceEvery $($budgetShape.performanceEvery) -JoeyEvery $($budgetShape.joeyEvery) -ContinueOnYellowCheckpoint -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns -MaxTaskQuarantines $MaxTaskQuarantines$(if ($QuarantineFailedTasks) { ' -QuarantineFailedTasks' } else { '' })$(if ($PushCheckpoint) { ' -PushCheckpoint' } else { '' })"
    ) -join "; "

    Write-Host "Launching overnight run for $($ship.name): budget $BudgetMode, batch $($budgetShape.batchSize) x $($budgetShape.maxBatches), max $($budgetShape.maxCompletedTasks) tasks, max $($budgetShape.maxRuntimeMinutes) minutes, planner batches $($budgetShape.maxPlannerBatches), performance $($budgetShape.performanceEvery)..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host $command
        Add-FleetLaunchManifestEntry -Manifest $manifest -Ship $ship.name -Command $command -DryRun
    } else {
        $process = Start-Process powershell -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) -PassThru
        Add-FleetLaunchManifestEntry -Manifest $manifest -Ship $ship.name -Command $command -ProcessId $process.Id
        if ($shipIndex -lt ($shipsToLaunch.Count - 1) -and $shipLaunchDelay -gt 0) {
            Write-Host "Waiting $shipLaunchDelay seconds before launching the next ship..." -ForegroundColor DarkCyan
            Start-Sleep -Seconds $shipLaunchDelay
        }
    }
}

Write-FleetLaunchManifest -Manifest $manifest
