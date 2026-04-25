param(
    [string]$ConfigPath = ".\projects.json",

    [switch]$SkipDoctor,

    [switch]$AllowSafeStopRequests
)

$ErrorActionPreference = "Continue"

if (!(Test-Path $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$fleetRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")
Assert-NoFleetSafeStopRequests -FleetRoot $fleetRoot -AllowSafeStopRequests:$AllowSafeStopRequests

if (!$SkipDoctor) {
    $doctorPath = Join-Path $fleetRoot "fleet-doctor.ps1"
    powershell -NoProfile -ExecutionPolicy Bypass -File $doctorPath -ConfigPath $ConfigPath
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Fleet launch refused. Chopper found at least one ship that is not ready to sail." -ForegroundColor Red
        Write-Host "Fix the report findings or rerun with -SkipDoctor if you are intentionally bypassing preflight." -ForegroundColor Yellow
        exit 1
    }
}

$parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$projects = @($parsedProjects | ForEach-Object { $_ })
$manifest = New-FleetLaunchManifest -FleetRoot $fleetRoot -Mode "legacy-run-fleet" -ConfigPath $ConfigPath

foreach ($project in $projects) {
    if (!(Test-Path $project.repo)) {
        Write-Host "Repo missing, skipping $($project.name): $($project.repo)" -ForegroundColor Red
        continue
    }

    $loopPath = Join-Path $project.repo $project.loopScript
    if (!(Test-Path $loopPath)) {
        Write-Host "Loop script missing, skipping $($project.name): $loopPath" -ForegroundColor Red
        continue
    }

    $command = "cd '$($project.repo)'; powershell -ExecutionPolicy Bypass -File '$loopPath' -Rounds $($project.rounds)"
    Write-Host "Starting $($project.name) for $($project.rounds) round(s)..." -ForegroundColor Cyan
    $process = Start-Process powershell -ArgumentList "-NoExit", "-Command", $command -PassThru
    Add-FleetLaunchManifestEntry -Manifest $manifest -Ship $project.name -Command $command -ProcessId $process.Id
}

Write-FleetLaunchManifest -Manifest $manifest
