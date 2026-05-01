[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateSet("school", "overnight")]
    [string]$Mode = "school",

    [string]$ConfigPath = ".\projects.json",

    [string]$FleetGroup = "CellarFleet",

    [string[]]$ExcludeProject = @(),

    [ValidateSet("cheap", "balanced", "premium")]
    [string]$BudgetMode = "cheap",

    [ValidateSet("auto", "brief", "foundation", "shape", "simplicity", "polish", "proof", "parked", "repair", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof")]
    [string]$LoopPhase = "auto",

    [int]$BatchSize = 0,

    [int]$MaxBatches = 0,

    [int]$MaxRuntimeMinutes = 0,

    [int]$MaxCompletedTasks = 0,

    [int]$MaxPlannerBatches = 0,

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 4,

    [int]$MaxTaskQuarantines = 2,

    [switch]$PushCheckpoint,

    [switch]$QuarantineFailedTasks,

    [switch]$AllowSafeStopRequests,

    [switch]$SkipDoctor,

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

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

if (!(Test-Path $ConfigPath)) {
    Stop-WithMessage "Config not found: $ConfigPath"
}

$parsedConfig = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$projects = if ($parsedConfig.PSObject.Properties.Name -contains "value") {
    @($parsedConfig.value | ForEach-Object { $_ })
} else {
    @($parsedConfig | ForEach-Object { $_ })
}
$requestedExcludeNames = @(ConvertTo-ProjectList -Values $ExcludeProject)
$cellarShips = @($projects | Where-Object { [string]$_.fleetGroup -eq $FleetGroup } | Sort-Object name)
if ($cellarShips.Count -eq 0) {
    Stop-WithMessage "No projects with fleetGroup=$FleetGroup found."
}

$selectedCellarShips = @($cellarShips | Where-Object { $requestedExcludeNames -notcontains [string]$_.name })
if ($selectedCellarShips.Count -eq 0) {
    Stop-WithMessage "All $FleetGroup ships were excluded."
}

$cellarNames = @($cellarShips | ForEach-Object { [string]$_.name })
$selectedCellarNames = @($selectedCellarShips | ForEach-Object { [string]$_.name })
$excludeNames = @(
    @($projects | Where-Object { [string]$_.fleetGroup -ne $FleetGroup } | ForEach-Object { [string]$_.name }) +
    $requestedExcludeNames
) | Sort-Object -Unique

Write-Host "$FleetGroup ships: $($cellarNames -join ', ')" -ForegroundColor Cyan
if ($requestedExcludeNames.Count -gt 0) {
    Write-Host "Selected $FleetGroup ships: $($selectedCellarNames -join ', ')" -ForegroundColor Cyan
}
if ($excludeNames.Count -gt 0) {
    Write-Host "Excluded ships: $($excludeNames -join ', ')" -ForegroundColor DarkGray
}

$launcher = if ($Mode -eq "overnight") { "launch-overnight-run.ps1" } else { "launch-school-run.ps1" }
$args = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot $launcher),
    "-ConfigPath", $ConfigPath,
    "-RateLimitCooldownSeconds", $RateLimitCooldownSeconds,
    "-RateLimitMaxCooldowns", $RateLimitMaxCooldowns,
    "-MaxTaskQuarantines", $MaxTaskQuarantines
)

if ($Mode -in @("school", "overnight")) {
    $args += @("-BudgetMode", $BudgetMode)
    $args += @("-LoopPhase", $LoopPhase)
}

if ($BatchSize -gt 0) { $args += @("-BatchSize", $BatchSize) }
if ($MaxBatches -gt 0) { $args += @("-MaxBatches", $MaxBatches) }
if ($MaxRuntimeMinutes -gt 0) { $args += @("-MaxRuntimeMinutes", $MaxRuntimeMinutes) }
if ($MaxCompletedTasks -gt 0) { $args += @("-MaxCompletedTasks", $MaxCompletedTasks) }
if ($MaxPlannerBatches -gt 0) { $args += @("-MaxPlannerBatches", $MaxPlannerBatches) }

if ($excludeNames.Count -gt 0) {
    $args += @("-ExcludeProject", ($excludeNames -join ","))
}

$args += @("-ExpectedProject", ($selectedCellarNames -join ","))

if ($PushCheckpoint) { $args += "-PushCheckpoint" }
if ($QuarantineFailedTasks) { $args += "-QuarantineFailedTasks" }
if ($AllowSafeStopRequests) { $args += "-AllowSafeStopRequests" }
if ($SkipDoctor) { $args += "-SkipDoctor" }
if ($RequirePhaseValidation) { $args += "-RequirePhaseValidation" }
if ($UseGlobalRunShape) { $args += "-UseGlobalRunShape" }
if (![string]::IsNullOrWhiteSpace($LaunchGateMode)) { $args += @("-LaunchGateMode", $LaunchGateMode) }
if (![string]::IsNullOrWhiteSpace($KillSwitchMode)) { $args += @("-KillSwitchMode", $KillSwitchMode) }
if ($DryRun) { $args += "-DryRun" }

& powershell @args
exit $LASTEXITCODE
