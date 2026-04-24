param(
    [string]$ConfigPath = ".\projects.json",
    [string]$OutDir = ".\out"
)

$ErrorActionPreference = "Continue"

if (!(Test-Path $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$projects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"

foreach ($project in $projects) {
    $safeName = $project.name -replace "[^a-zA-Z0-9_-]", "-"
    $outPath = Join-Path $OutDir "$safeName-$timestamp.md"
    $briefScript = Join-Path $project.repo $project.briefScript

    if (!(Test-Path $briefScript)) {
        Write-Host "Brief script missing for $($project.name): $briefScript" -ForegroundColor Red
        continue
    }

    Push-Location $project.repo
    $brief = powershell -NoProfile -ExecutionPolicy Bypass -File $briefScript
    Pop-Location

    $instructions = @"
# $($project.name) Context Bundle

Paste this into the matching ChatGPT Pro project.

Ask:

Review this project state. Decide whether to continue, revise the queue, or stop. If continuing, return only small tasks in markdown checklist format suitable for docs/codex/TASK_QUEUE.md. Include explicit forbidden scope in each task.

---

"@

    Set-Content -Path $outPath -Value ($instructions + ($brief -join "`n"))
    Write-Host "Wrote $outPath" -ForegroundColor Green
}
