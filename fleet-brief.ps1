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
    Write-Host ""
    Write-Host "============================================================"
    Write-Host "# $($project.name)"
    Write-Host "============================================================"

    $scriptPath = Join-Path $project.repo $project.briefScript
    if (!(Test-Path $scriptPath)) {
        Write-Host "Brief script missing: $scriptPath" -ForegroundColor Red
        continue
    }

    Push-Location $project.repo
    powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath
    Pop-Location
}
