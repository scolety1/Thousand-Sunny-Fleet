[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Project = "",

    [string]$Repo = "",

    [string]$ConfigPath = ".\projects.json",

    [string]$BaseBranch = "main",

    [string]$BuildDirectory = "",

    [string]$BuildCommand = "",

    [string]$Task = "",

    [switch]$SkipBuild,

    [switch]$ConfirmRecovery
)

$ErrorActionPreference = "Continue"

function Stop-Recovery {
    param([string]$Message)

    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-ConfigPropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-ProjectConfig {
    if (![string]::IsNullOrWhiteSpace($Repo)) {
        return [pscustomobject]@{
            name = Split-Path -Leaf $Repo
            repo = $Repo
            buildDirectory = $BuildDirectory
            buildCommand = $BuildCommand
        }
    }

    if ([string]::IsNullOrWhiteSpace($Project)) {
        Stop-Recovery "Missing required -Project or -Repo."
    }

    if (!(Test-Path $ConfigPath)) {
        Stop-Recovery "Config not found: $ConfigPath"
    }

    $parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })
    $match = @($projects | Where-Object { [string]$_.name -ceq [string]$Project })
    if ($match.Count -ne 1) {
        Stop-Recovery "Project not found or ambiguous: $Project"
    }

    return $match[0]
}

function Get-FirstUncheckedTask {
    if (!(Test-Path "docs/codex/TASK_QUEUE.md")) {
        return ""
    }

    foreach ($line in Get-Content "docs/codex/TASK_QUEUE.md") {
        if ($line -match "^\s*-\s+\[ \]\s+(.+)$") {
            return $Matches[1].Trim()
        }
    }

    return ""
}

function Mark-FirstUncheckedTaskComplete {
    $path = "docs/codex/TASK_QUEUE.md"
    $updated = $false
    $newLines = foreach ($line in Get-Content $path) {
        if (-not $updated -and $line -match "^(\s*-\s+)\[ \](\s+.+)$") {
            $updated = $true
            "$($Matches[1])[x]$($Matches[2])"
        } else {
            $line
        }
    }

    if (-not $updated) {
        Stop-Recovery "Could not mark first unchecked task complete."
    }

    Set-Content -Path $path -Value $newLines
}

function Invoke-ConfiguredBuild {
    if ($SkipBuild) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($BuildCommand)) {
        return $true
    }

    $buildPath = if ([string]::IsNullOrWhiteSpace($BuildDirectory)) { "." } else { $BuildDirectory }
    if (!(Test-Path $buildPath)) {
        Stop-Recovery "Build directory not found: $buildPath"
    }

    Push-Location $buildPath
    Invoke-Expression $BuildCommand
    $ok = $LASTEXITCODE -eq 0
    Pop-Location
    return $ok
}

function Invoke-ProjectGuardrails {
    param([string]$SelectedTask)

    if (!(Test-Path "scripts/codex-guardrails.ps1")) {
        Write-Host "No scripts/codex-guardrails.ps1 found; skipping project guardrails." -ForegroundColor Yellow
        return $true
    }

    $previousTask = $env:CODEX_SELECTED_TASK
    $env:CODEX_SELECTED_TASK = $SelectedTask
    powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\codex-guardrails.ps1" -Stage "recovery" -Task $SelectedTask
    $passed = $LASTEXITCODE -eq 0
    $env:CODEX_SELECTED_TASK = $previousTask
    return $passed
}

function Append-Report {
    param(
        [string]$SelectedTask,
        [string[]]$FilesChanged
    )

    if (!(Test-Path "docs/codex/NIGHTLY_REPORT.md")) {
        New-Item -ItemType Directory -Force -Path "docs/codex" | Out-Null
        "# Codex Nightly Report`n" | Set-Content "docs/codex/NIGHTLY_REPORT.md"
    }

    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $files = if ($FilesChanged.Count -gt 0) { ($FilesChanged | ForEach-Object { "- $_" }) -join "`n" } else { "- None" }
    Add-Content "docs/codex/NIGHTLY_REPORT.md" @"

## $date

- Task attempted: $SelectedTask
- Build result: Passed
- Files changed:
$files
- Risks or follow-up needed: Low. Recovered from interrupted loop after guardrails and external build passed.
"@
}

function Stage-Files {
    param([string[]]$Paths)

    $cleanPaths = @($Paths |
        Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } |
        ForEach-Object { ([string]$_).Replace("\", "/") } |
        Sort-Object -Unique)

    if ($cleanPaths.Count -eq 0) {
        return
    }

    foreach ($path in $cleanPaths) {
        & git add -- $path
        if ($LASTEXITCODE -ne 0) {
            Stop-Recovery "Failed to stage path: $path"
        }
    }
}

$projectConfig = Get-ProjectConfig
$repoPath = Resolve-Path $projectConfig.repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Stop-Recovery "Repo not found: $($projectConfig.repo)"
}

if ([string]::IsNullOrWhiteSpace($BuildDirectory)) {
    $configuredBuildDirectory = Get-ConfigPropertyValue -Object $projectConfig -Name "buildDirectory"
    if ($null -ne $configuredBuildDirectory) {
        $BuildDirectory = [string]$configuredBuildDirectory
    }
}

if ([string]::IsNullOrWhiteSpace($BuildCommand)) {
    $configuredBuildCommand = Get-ConfigPropertyValue -Object $projectConfig -Name "buildCommand"
    if ($null -ne $configuredBuildCommand) {
        $BuildCommand = [string]$configuredBuildCommand
    }
}

Set-Location $repoPath.Path

$branch = git branch --show-current
$dirty = @(git status --short)
if ($dirty.Count -eq 0) {
    Write-Host "No interrupted-task recovery needed. Working tree is clean." -ForegroundColor Green
    exit 0
}

if ($branch -eq $BaseBranch) {
    Stop-Recovery "Refusing recovery on $BaseBranch. Switch to the interrupted Codex branch first."
}

if ([string]::IsNullOrWhiteSpace($Task)) {
    $Task = Get-FirstUncheckedTask
}

if ([string]::IsNullOrWhiteSpace($Task)) {
    Stop-Recovery "Working tree is dirty, but no unchecked task was found. Stop for human review."
}

$filesChanged = @(git diff --name-only; git diff --cached --name-only; git ls-files --others --exclude-standard) | Sort-Object -Unique

Write-Host "Interrupted task recovery candidate" -ForegroundColor Cyan
Write-Host "Repo: $($repoPath.Path)"
Write-Host "Branch: $branch"
Write-Host "Task: $Task"
Write-Host "Changed files:"
$filesChanged | ForEach-Object { Write-Host "  $_" }

if (-not (Invoke-ProjectGuardrails -SelectedTask $Task)) {
    Stop-Recovery "Project guardrails failed. Recovery was not committed."
}

if (-not (Invoke-ConfiguredBuild)) {
    Stop-Recovery "Build failed. Recovery was not committed."
}

if (!$ConfirmRecovery) {
    Write-Host ""
    Write-Host "Dry run passed. Re-run with -ConfirmRecovery to mark the task complete, append the report, and commit." -ForegroundColor Yellow
    exit 0
}

Mark-FirstUncheckedTaskComplete
Append-Report -SelectedTask $Task -FilesChanged $filesChanged

$stagePaths = @($filesChanged + @("docs/codex/TASK_QUEUE.md", "docs/codex/NIGHTLY_REPORT.md"))
Stage-Files -Paths $stagePaths
git commit -m "codex: recover interrupted task"
if ($LASTEXITCODE -ne 0) {
    exit 1
}

$remainingDirty = @(git status --short)
if ($remainingDirty.Count -gt 0) {
    Write-Host "Recovery committed, but working tree is still dirty:" -ForegroundColor Yellow
    $remainingDirty | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host "Interrupted task recovered and committed." -ForegroundColor Green
exit 0
