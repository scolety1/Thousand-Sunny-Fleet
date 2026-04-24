param(
    [string]$ConfigPath = ".\projects.json"
)

$ErrorActionPreference = "Continue"

if (!(Test-Path $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$projects = Get-Content $ConfigPath -Raw | ConvertFrom-Json

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
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $command
}
