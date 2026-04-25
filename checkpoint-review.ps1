param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [string]$OutFile = "docs/codex/CHECKPOINT_REVIEW.md",

    [string]$BuildDirectory = "",

    [string]$BuildCommand = "",

    [switch]$SkipBuild,

    [string]$Model = ""
)

$ErrorActionPreference = "Continue"

function Invoke-ConfiguredBuild {
    if ($SkipBuild -or [string]::IsNullOrWhiteSpace($BuildCommand)) {
        return $true
    }

    $buildPath = if ([string]::IsNullOrWhiteSpace($BuildDirectory)) { "." } else { $BuildDirectory }
    Push-Location $buildPath
    Invoke-Expression $BuildCommand
    $ok = $LASTEXITCODE -eq 0
    Pop-Location
    return $ok
}

$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo not found: $Repo" -ForegroundColor Red
    exit 1
}

Set-Location $repoPath.Path

$preStatus = @(git status --porcelain)
if ($preStatus.Count -gt 0) {
    Write-Host "Checkpoint reviewer requires a clean working tree before writing $OutFile." -ForegroundColor Red
    $preStatus | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$branch = git branch --show-current
$head = git rev-parse --short HEAD
$status = @(git status --short)
$changed = @(git diff --name-status "$BaseBranch..HEAD")
$commits = @(git log --oneline "$BaseBranch..HEAD")
$taskTail = if (Test-Path "docs/codex/TASK_QUEUE.md") { Get-Content "docs/codex/TASK_QUEUE.md" -Tail 120 } else { @("No task queue found.") }
$reportTail = if (Test-Path "docs/codex/NIGHTLY_REPORT.md") { Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 160 } else { @("No nightly report found.") }
$mission = if (Test-Path "docs/codex/MISSION.md") { Get-Content "docs/codex/MISSION.md" -Raw } else { "No mission file found." }
$buildOk = Invoke-ConfiguredBuild

$prompt = @"
You are the checkpoint reviewer for an unattended Codex branch.

Write a concise markdown review to this exact structure:

# Checkpoint Review

## Verdict
Use exactly one: GREEN, YELLOW, or RED.

## Progress Against Mission
Summarize whether the branch is moving toward the mission.

## Safety Review
Call out risky files, risky behavior, or say none found.

## Build Result
Say whether the external build passed.

## Recommended Next Step
Choose one: continue, patch first, stop for human review.

## Notes For Human Reviewer
Short bullets only.

Repository: $($repoPath.Path)
Branch: $branch
HEAD: $head
Base branch: $BaseBranch
Build passed: $buildOk

Working tree:
$(if ($status.Count -eq 0) { "- Clean" } else { ($status | ForEach-Object { "- $_" }) -join "`n" })

Changed files since base:
$(if ($changed.Count -eq 0) { "- None" } else { ($changed | ForEach-Object { "- $_" }) -join "`n" })

Commits since base:
$(if ($commits.Count -eq 0) { "- None" } else { ($commits | ForEach-Object { "- $_" }) -join "`n" })

Mission:
$mission

Task queue tail:
$($taskTail -join "`n")

Nightly report tail:
$($reportTail -join "`n")
"@

$tmp = New-TemporaryFile
$codexArgs = @("exec")
if (![string]::IsNullOrWhiteSpace($Model)) {
    $codexArgs += @("-m", $Model)
}
$codexArgs += @("-", "-o", $tmp.FullName)
$prompt | & codex @codexArgs
$codexExit = $LASTEXITCODE

if (!(Test-Path $tmp.FullName) -or ((Get-Item $tmp.FullName).Length -eq 0)) {
    Write-Host "Checkpoint reviewer produced no output." -ForegroundColor Red
    Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
    exit 1
}

$outPath = Join-Path $repoPath.Path $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
Copy-Item $tmp.FullName $outPath -Force
Remove-Item $tmp.FullName -Force

$allowedPath = $OutFile.Replace("\", "/")
$dirtyAfter = @(git status --porcelain)
$unexpected = @($dirtyAfter | Where-Object {
    $line = [string]$_
    $path = $line.Substring([Math]::Min(3, $line.Length)).Replace("\", "/")
    $path -ne $allowedPath
})
if ($unexpected.Count -gt 0) {
    Write-Host "Checkpoint reviewer changed files outside $OutFile. Stop for human review." -ForegroundColor Red
    $unexpected | ForEach-Object { Write-Host "  $_" }
    exit 1
}

if ($codexExit -ne 0) {
    Write-Host "Checkpoint reviewer exited nonzero, but wrote $OutFile for inspection." -ForegroundColor Yellow
} else {
    Write-Host "Wrote $OutFile" -ForegroundColor Green
}

if (!$buildOk) {
    exit 1
}

exit 0
