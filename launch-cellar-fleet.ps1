[CmdletBinding(PositionalBinding = $false)]
param(
    [ValidateSet("school", "overnight")]
    [string]$Mode = "school",

    [string]$ConfigPath = ".\projects.json",

    [string]$FleetGroup = "CellarFleet",

    [ValidateSet("cheap", "balanced", "premium")]
    [string]$BudgetMode = "cheap",

    [ValidateSet("auto", "brief", "foundation", "shape", "simplicity", "polish", "proof", "parked", "repair", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof")]
    [string]$LoopPhase = "auto",

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 4,

    [int]$MaxTaskQuarantines = 2,

    [switch]$PushCheckpoint,

    [switch]$QuarantineFailedTasks,

    [switch]$AllowSafeStopRequests,

    [switch]$SkipDoctor,

    [switch]$RequirePhaseValidation,

    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
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
$cellarShips = @($projects | Where-Object { [string]$_.fleetGroup -eq $FleetGroup } | Sort-Object name)
if ($cellarShips.Count -eq 0) {
    Stop-WithMessage "No projects with fleetGroup=$FleetGroup found."
}

$cellarNames = @($cellarShips | ForEach-Object { [string]$_.name })
$excludeNames = @($projects | Where-Object { [string]$_.fleetGroup -ne $FleetGroup } | ForEach-Object { [string]$_.name } | Sort-Object -Unique)

Write-Host "$FleetGroup ships: $($cellarNames -join ', ')" -ForegroundColor Cyan
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

if ($excludeNames.Count -gt 0) {
    $args += @("-ExcludeProject", ($excludeNames -join ","))
}

$args += @("-ExpectedProject", ($cellarNames -join ","))

if ($PushCheckpoint) { $args += "-PushCheckpoint" }
if ($QuarantineFailedTasks) { $args += "-QuarantineFailedTasks" }
if ($AllowSafeStopRequests) { $args += "-AllowSafeStopRequests" }
if ($SkipDoctor) { $args += "-SkipDoctor" }
if ($RequirePhaseValidation) { $args += "-RequirePhaseValidation" }
if ($DryRun) { $args += "-DryRun" }

& powershell @args
exit $LASTEXITCODE
