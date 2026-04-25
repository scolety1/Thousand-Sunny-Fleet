[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [int]$BatchSize = 3,

    [int]$MaxBatches = 20,

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 8,

    [int]$MaxTaskQuarantines = 5,

    [int]$LaunchDelaySeconds = 90,

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

if ($BatchSize -lt 1) { Stop-WithMessage "-BatchSize must be at least 1." }
if ($MaxBatches -lt 1) { Stop-WithMessage "-MaxBatches must be at least 1." }
if ($MaxTaskQuarantines -lt 0) { Stop-WithMessage "-MaxTaskQuarantines must be 0 or greater." }
if ($LaunchDelaySeconds -lt 0) { Stop-WithMessage "-LaunchDelaySeconds must be 0 or greater." }

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")
Assert-NoFleetSafeStopRequests -FleetRoot $fleetRoot -ProjectFilter $Project -AllowSafeStopRequests:$AllowSafeStopRequests

if (!$SkipDoctor) {
    $doctorArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fleetRoot "fleet-doctor.ps1"), "-ConfigPath", $ConfigPath)
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $doctorArgs += @("-Project", $Project)
    }
    & powershell @doctorArgs
    if ($LASTEXITCODE -ne 0) {
        Stop-WithMessage "Overnight run refused. Chopper found a ship that is not ready."
    }
}

$shipsToLaunch = @(Get-Projects)
$manifest = New-FleetLaunchManifest -FleetRoot $fleetRoot -Mode "overnight" -ConfigPath $ConfigPath -ProjectFilter $Project
for ($shipIndex = 0; $shipIndex -lt $shipsToLaunch.Count; $shipIndex++) {
    $ship = $shipsToLaunch[$shipIndex]
    $shipBatchSize = Get-ShipInt -Ship $ship -Name "overnightBatchSize" -Default $BatchSize
    $shipMaxBatches = Get-ShipInt -Ship $ship -Name "overnightMaxBatches" -Default $MaxBatches
    $shipVisualEvery = Get-ShipInt -Ship $ship -Name "overnightVisualInspectEvery" -Default 3
    $shipSimonEvery = Get-ShipInt -Ship $ship -Name "overnightSimonEvery" -Default 3
    $shipJoeyEvery = Get-ShipInt -Ship $ship -Name "overnightJoeyEvery" -Default 6
    $shipLaunchDelay = Get-ShipInt -Ship $ship -Name "launchDelaySeconds" -Default $LaunchDelaySeconds

    $command = @(
        "Set-Location '$fleetRoot'",
        ".\run-checkpoint-loop.ps1 -Project '$($ship.name)' -BatchSize $shipBatchSize -MaxBatches $shipMaxBatches -VisualInspectEvery $shipVisualEvery -SimonEvery $shipSimonEvery -JoeyEvery $shipJoeyEvery -ContinueOnYellowCheckpoint -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns -MaxTaskQuarantines $MaxTaskQuarantines$(if ($QuarantineFailedTasks) { ' -QuarantineFailedTasks' } else { '' })$(if ($PushCheckpoint) { ' -PushCheckpoint' } else { '' })"
    ) -join "; "

    Write-Host "Launching overnight run for $($ship.name): batch $shipBatchSize x $shipMaxBatches, Simon every $shipSimonEvery..." -ForegroundColor Cyan
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
