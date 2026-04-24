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
    Write-Host "===== $($project.name) =====" -ForegroundColor Cyan

    if (!(Test-Path $project.repo)) {
        Write-Host "Repo missing: $($project.repo)" -ForegroundColor Red
        continue
    }

    Push-Location $project.repo
    $branch = git branch --show-current
    $status = @(git status --short)
    $unchecked = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue)
    $head = git rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        $head = "none"
    }

    Write-Host "Path: $($project.repo)"
    Write-Host "Branch: $branch"
    Write-Host "HEAD: $head"
    Write-Host "Unchecked tasks: $($unchecked.Count)"

    if ($status.Count -eq 0) {
        Write-Host "Working tree: clean" -ForegroundColor Green
    } else {
        Write-Host "Working tree: dirty" -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host "  $_" }
    }

    Pop-Location
}
