[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 1,

    [int]$MaxTaskQuarantines = 1,

    [int]$RobinEvery = 1,

    [int]$AccessibilityEvery = 1,

    [int]$PerformanceEvery = 1,

    [switch]$SkipDoctor,

    [switch]$PushCheckpoint,

    [switch]$QuarantineFailedTasks,

    [switch]$AllowSafeStopRequests,

    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
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

    return $projects
}

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")
Assert-NoFleetSafeStopRequests -FleetRoot $fleetRoot -ProjectFilter $Project -ExcludeProject $ExcludeProject -AllowSafeStopRequests:$AllowSafeStopRequests

if ($MaxTaskQuarantines -lt 0) { Stop-WithMessage "-MaxTaskQuarantines must be 0 or greater." }
if ($RobinEvery -lt 0) { Stop-WithMessage "-RobinEvery must be 0 or greater." }
if ($AccessibilityEvery -lt 0) { Stop-WithMessage "-AccessibilityEvery must be 0 or greater." }
if ($PerformanceEvery -lt 0) { Stop-WithMessage "-PerformanceEvery must be 0 or greater." }

if (!$SkipDoctor) {
    $doctorArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fleetRoot "fleet-doctor.ps1"), "-ConfigPath", $ConfigPath)
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $doctorArgs += @("-Project", $Project)
    }
    & powershell @doctorArgs
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "Proof run refused. Chopper found a ship that is not ready."
    }
}

$shipsToLaunch = @(Get-Projects)
$manifest = New-FleetLaunchManifest -FleetRoot $fleetRoot -Mode "proof" -ConfigPath $ConfigPath -ProjectFilter $Project
foreach ($ship in $shipsToLaunch) {
    $command = @(
        "Set-Location '$fleetRoot'",
        ".\run-checkpoint-loop.ps1 -Project '$($ship.name)' -BatchSize 1 -MaxBatches 1 -VisualInspectEvery 1 -SimonEvery 1 -RobinEvery $RobinEvery -AccessibilityEvery $AccessibilityEvery -PerformanceEvery $PerformanceEvery -JoeyEvery 1 -ContinueOnYellowCheckpoint -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns -MaxTaskQuarantines $MaxTaskQuarantines$(if ($QuarantineFailedTasks) { ' -QuarantineFailedTasks' } else { '' })$(if ($PushCheckpoint) { ' -PushCheckpoint' } else { '' })"
    ) -join "; "

    Write-Host "Launching proof run for $($ship.name) with Robin every $RobinEvery, accessibility every $AccessibilityEvery, and performance every $PerformanceEvery batch(es)..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host $command
        Add-FleetLaunchManifestEntry -Manifest $manifest -Ship $ship.name -Command $command -DryRun
    } else {
        $process = Start-Process powershell -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) -PassThru
        Add-FleetLaunchManifestEntry -Manifest $manifest -Ship $ship.name -Command $command -ProcessId $process.Id
    }
}

Write-FleetLaunchManifest -Manifest $manifest
