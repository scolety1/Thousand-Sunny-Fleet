param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [string]$BuildDirectory = "",

    [string]$BuildCommand = "",

    [switch]$SkipBuild
)

$ErrorActionPreference = "Continue"

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "===== $Title =====" -ForegroundColor Cyan
}

$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo not found: $Repo" -ForegroundColor Red
    exit 1
}

$repoPath = $repoPath.Path
Push-Location $repoPath

$branch = git branch --show-current
$head = git rev-parse --short HEAD 2>$null
$dirty = @(git status --short 2>$null)
$mergeBase = git merge-base $BaseBranch HEAD 2>$null
$commitCount = 0
if ($LASTEXITCODE -eq 0 -and ![string]::IsNullOrWhiteSpace($mergeBase)) {
    $commitCount = [int](git rev-list --count "$BaseBranch..HEAD")
}

Write-Section "Summary"
Write-Host "Repo: $repoPath"
Write-Host "Branch: $branch"
Write-Host "HEAD: $head"
Write-Host "Commits ahead of ${BaseBranch}: $commitCount"

if ($dirty.Count -eq 0) {
    Write-Host "Working tree: clean" -ForegroundColor Green
} else {
    Write-Host "Working tree: dirty" -ForegroundColor Yellow
    $dirty | ForEach-Object { Write-Host "  $_" }
}

Write-Section "Unchecked Tasks"
if (Test-Path "docs/codex/TASK_QUEUE.md") {
    $unchecked = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue)
    Write-Host "Unchecked tasks: $($unchecked.Count)"
    $unchecked | Select-Object -First 10 | ForEach-Object { Write-Host "  $($_.Line.Trim())" }
} else {
    Write-Host "No docs/codex/TASK_QUEUE.md found." -ForegroundColor Yellow
}

Write-Section "Changed Files"
if ($commitCount -gt 0) {
    git diff --name-status "$BaseBranch..HEAD"
} else {
    Write-Host "No commits ahead of $BaseBranch."
}

Write-Section "Recent Commits"
git log --oneline --decorate -10

Write-Section "Report Tail"
if (Test-Path "docs/codex/NIGHTLY_REPORT.md") {
    Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 60
} else {
    Write-Host "No docs/codex/NIGHTLY_REPORT.md found." -ForegroundColor Yellow
}

$buildOk = $true
if (!$SkipBuild -and ![string]::IsNullOrWhiteSpace($BuildCommand)) {
    Write-Section "Build"
    $buildPath = if ([string]::IsNullOrWhiteSpace($BuildDirectory)) { "." } else { $BuildDirectory }
    Push-Location $buildPath
    Invoke-Expression $BuildCommand
    $buildOk = $LASTEXITCODE -eq 0
    Pop-Location

    if ($buildOk) {
        Write-Host "Build: passed" -ForegroundColor Green
    } else {
        Write-Host "Build: failed" -ForegroundColor Red
    }
}

Write-Section "Merge Gate"
$canMerge = $true
if ($branch -eq $BaseBranch) {
    Write-Host "FAIL: You are on $BaseBranch, not a review branch." -ForegroundColor Red
    $canMerge = $false
}
if ($dirty.Count -gt 0) {
    Write-Host "FAIL: Working tree is dirty." -ForegroundColor Red
    $canMerge = $false
}
if ($commitCount -eq 0) {
    Write-Host "FAIL: Branch has no commits ahead of $BaseBranch." -ForegroundColor Red
    $canMerge = $false
}
if (!$buildOk) {
    Write-Host "FAIL: Build did not pass." -ForegroundColor Red
    $canMerge = $false
}

if ($canMerge) {
    Write-Host "PASS: This branch is ready for human/code review before merge." -ForegroundColor Green
    Write-Host "Recommended merge command after review:"
    Write-Host "  git checkout $BaseBranch"
    Write-Host "  git merge --ff-only $branch"
} else {
    Write-Host "STOP: Do not merge yet." -ForegroundColor Red
}

Pop-Location

if ($canMerge) {
    exit 0
}
exit 1
