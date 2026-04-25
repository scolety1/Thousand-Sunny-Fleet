[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 1,

    [switch]$SkipDoctor,

    [switch]$PushCheckpoint,

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

foreach ($ship in Get-Projects) {
    $command = @(
        "Set-Location '$fleetRoot'",
        ".\run-checkpoint-loop.ps1 -Project '$($ship.name)' -BatchSize 1 -MaxBatches 1 -VisualInspectEvery 1 -SimonEvery 1 -JoeyEvery 1 -ContinueOnYellowCheckpoint -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns$(if ($PushCheckpoint) { ' -PushCheckpoint' } else { '' })"
    ) -join "; "

    Write-Host "Launching proof run for $($ship.name)..." -ForegroundColor Cyan
    if ($DryRun) {
        Write-Host $command
    } else {
        Start-Process powershell -ArgumentList @("-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command)
    }
}
