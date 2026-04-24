param(
    [string]$ConfigPath = ".\projects.json",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Continue"

if (!(Test-Path $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$projects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$failed = 0

foreach ($project in $projects) {
    Write-Host ""
    Write-Host "############################################################" -ForegroundColor Cyan
    Write-Host "# $($project.name)" -ForegroundColor Cyan
    Write-Host "############################################################" -ForegroundColor Cyan

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", ".\morning-review.ps1",
        "-Repo", $project.repo
    )

    if ($project.buildDirectory) {
        $args += @("-BuildDirectory", $project.buildDirectory)
    }
    if ($project.buildCommand) {
        $args += @("-BuildCommand", $project.buildCommand)
    }
    if ($SkipBuild) {
        $args += "-SkipBuild"
    }

    & powershell @args
    if ($LASTEXITCODE -ne 0) {
        $failed++
    }
}

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "$failed project(s) are not ready to merge." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "All projects passed the morning review gate." -ForegroundColor Green
