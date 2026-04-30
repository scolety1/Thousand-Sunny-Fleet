param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [string]$OutFile = "docs/codex/CHECKPOINT_REVIEW.md",

    [string]$BuildDirectory = "",

    [string]$BuildCommand = "",

    [switch]$SkipBuild,

    [string]$Model = "",

    [string[]]$Models = @(),

    [int]$TimeoutSeconds = 600,

    [int]$BuildTimeoutSeconds = 600,

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 4
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$fleetRuntime = Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1"
if (!(Test-Path $fleetRuntime)) {
    Write-Host "Fleet runtime helper not found: $fleetRuntime" -ForegroundColor Red
    exit 1
}
. $fleetRuntime

function Invoke-ConfiguredBuild {
    if ($SkipBuild -or [string]::IsNullOrWhiteSpace($BuildCommand)) {
        return $true
    }

    $buildPath = if ([string]::IsNullOrWhiteSpace($BuildDirectory)) { "." } else { $BuildDirectory }
    $resolvedBuildPath = Resolve-Path $buildPath -ErrorAction SilentlyContinue
    if (!$resolvedBuildPath) {
        Write-Host "Build directory not found: $buildPath" -ForegroundColor Red
        return $false
    }

    $logPath = Join-Path $repoPath.Path (Join-Path ".codex-logs" ("checkpoint-build-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
    $result = Invoke-FleetProcess -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $BuildCommand) -WorkingDirectory $resolvedBuildPath.Path -LogPath $logPath -TimeoutSeconds $BuildTimeoutSeconds
    @($result.output | Select-Object -Last 80) | ForEach-Object { Write-Host $_ }
    if ($result.timedOut) {
        Write-Host "Checkpoint build timed out after $BuildTimeoutSeconds seconds." -ForegroundColor Red
    }
    return ($result.exitCode -eq 0)
}

function Get-MarkdownValue {
    param(
        [string]$Path,
        [string]$Heading
    )

    if (!(Test-Path $Path)) {
        return "missing"
    }

    $text = Get-Content $Path -Raw
    $pattern = "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n\s*([^\r\n#]+)"
    $match = [regex]::Match($text, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return "unknown"
}

function Get-VisualSummary {
    if (!(Test-Path "docs/codex/VISUAL_BUGS.md")) {
        return "missing"
    }

    $high = @(Select-String -Path "docs/codex/VISUAL_BUGS.md" -Pattern "\[HIGH\]" -ErrorAction SilentlyContinue).Count
    $medium = @(Select-String -Path "docs/codex/VISUAL_BUGS.md" -Pattern "\[MEDIUM\]" -ErrorAction SilentlyContinue).Count
    $low = @(Select-String -Path "docs/codex/VISUAL_BUGS.md" -Pattern "\[LOW\]" -ErrorAction SilentlyContinue).Count
    return "high $high, medium $medium, low $low"
}

$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo not found: $Repo" -ForegroundColor Red
    exit 1
}

Set-Location $repoPath.Path

$preStatus = @(git status --porcelain 2>$null)
if ($preStatus.Count -gt 0) {
    Write-Host "Checkpoint reviewer requires a clean working tree before writing $OutFile." -ForegroundColor Red
    $preStatus | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$branch = git branch --show-current
$head = git rev-parse --short HEAD
$status = @(git status --short 2>$null)
$changed = @(git diff --name-status "$BaseBranch..HEAD")
$commits = @(git log --oneline "$BaseBranch..HEAD")
$taskTail = if (Test-Path "docs/codex/TASK_QUEUE.md") { Get-Content "docs/codex/TASK_QUEUE.md" -Tail 120 } else { @("No task queue found.") }
$completedTasks = if (Test-Path "docs/codex/TASK_QUEUE.md") { @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[x\]\s+(.+)" -ErrorAction SilentlyContinue | Select-Object -Last 12 | ForEach-Object { $_.Line.Trim() }) } else { @() }
$uncheckedTasks = if (Test-Path "docs/codex/TASK_QUEUE.md") { @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]\s+(.+)" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() }) } else { @() }
$reportTail = if (Test-Path "docs/codex/NIGHTLY_REPORT.md") { Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 160 } else { @("No nightly report found.") }
$mission = if (Test-Path "docs/codex/MISSION.md") { Get-Content "docs/codex/MISSION.md" -Raw } else { "No mission file found." }
$simonVerdict = Get-MarkdownValue -Path "docs/codex/SIMON_DESIGN_REVIEW.md" -Heading "Verdict"
$simonNextStep = Get-MarkdownValue -Path "docs/codex/SIMON_DESIGN_REVIEW.md" -Heading "Stop Or Continue"
$robinVerdict = Get-MarkdownValue -Path "docs/codex/ROBIN_COPY_REVIEW.md" -Heading "Verdict"
$robinNextStep = Get-MarkdownValue -Path "docs/codex/ROBIN_COPY_REVIEW.md" -Heading "Stop Or Continue"
$joeyVerdict = Get-MarkdownValue -Path "docs/codex/JOEY_SECURITY_REVIEW.md" -Heading "Verdict"
$joeyNextStep = Get-MarkdownValue -Path "docs/codex/JOEY_SECURITY_REVIEW.md" -Heading "Recommended Next Step"
$frankyVerdict = Get-MarkdownValue -Path "docs/codex/FRANKY_FORMULA_REVIEW.md" -Heading "Verdict"
$frankyNextStep = Get-MarkdownValue -Path "docs/codex/FRANKY_FORMULA_REVIEW.md" -Heading "Stop Or Continue"
$visualSummary = Get-VisualSummary
$buildOk = Invoke-ConfiguredBuild

$prompt = @"
You are the checkpoint reviewer for an unattended Codex branch.

Write a concise markdown review to this exact structure:

# Checkpoint Review

## Verdict
Use exactly one: GREEN, YELLOW, or RED.
Verdict rules:
- RED only for build failure, unsafe/risky changes, high visual issues, security/formula blockers, or a review gate that explicitly says stop.
- GREEN when build passed, the working tree is clean, no unchecked tasks remain, and there are no high/medium visual issues or blocking review signals. This means the ship is parked/ready, even if no new code landed in this checkpoint window.
- YELLOW for non-blocking polish debt, medium review concerns, or meaningful follow-up work that should shape the next task.
- Do not downgrade solely because no new code, commits, or task movement happened in this checkpoint window. An empty queue can be a successful stopping point.

## Progress Against Mission
Summarize whether the branch is moving toward the mission.

## Safety Review
Call out risky files, risky behavior, or say none found.

## Build Result
Say whether the external build passed.

## Batch Summary
Bullets:
- completed tasks in this checkpoint window
- files changed
- commits added
- queue status

## Follow-Up Gate Status
Bullets for visual bug report, Simon design review, Robin copy review, Joey security review, Franky formula review, and whether they should influence the next tasks.

## Recommended Next Step
Choose one: continue, patch first, stop for human review.
Use "stop for human review" for a clean, queue-empty, build-passing ship that appears ready to inspect or park. Use "patch first" only when there is a concrete non-blocking defect to repair. Use "continue" when there is still mission-forward queued work.

## Next Batch Guidance
Include:
- recommended next batch size as a number from 1 to 5
- next work mode: repair-first or mission-forward
- one sentence explaining why

## Notes For Human Reviewer
Short bullets only.

Repository: $($repoPath.Path)
Branch: $branch
HEAD: $head
Base branch: $BaseBranch
Build passed: $buildOk
Unchecked task count: $($uncheckedTasks.Count)
Recent completed task count shown: $($completedTasks.Count)
Simon verdict: $simonVerdict
Simon stop/continue: $simonNextStep
Robin verdict: $robinVerdict
Robin stop/continue: $robinNextStep
Joey verdict: $joeyVerdict
Joey next step: $joeyNextStep
Franky verdict: $frankyVerdict
Franky stop/continue: $frankyNextStep
Visual bug summary: $visualSummary

Working tree:
$(if ($status.Count -eq 0) { "- Clean" } else { ($status | ForEach-Object { "- $_" }) -join "`n" })

Changed files since base:
$(if ($changed.Count -eq 0) { "- None" } else { ($changed | ForEach-Object { "- $_" }) -join "`n" })

Commits since base:
$(if ($commits.Count -eq 0) { "- None" } else { ($commits | ForEach-Object { "- $_" }) -join "`n" })

Recently completed tasks:
$(if ($completedTasks.Count -eq 0) { "- None" } else { ($completedTasks | ForEach-Object { "- $_" }) -join "`n" })

Remaining unchecked tasks:
$(if ($uncheckedTasks.Count -eq 0) { "- None" } else { ($uncheckedTasks | Select-Object -First 20 | ForEach-Object { "- $_" }) -join "`n" })

Mission:
$mission

Task queue tail:
$($taskTail -join "`n")

Nightly report tail:
$($reportTail -join "`n")
"@

$tmp = New-TemporaryFile
$modelChain = @(ConvertTo-FleetStringArray -Value $Models)
if ($modelChain.Count -eq 0) {
    $modelChain = @(ConvertTo-FleetStringArray -Value $Model)
}
$logPath = Join-Path $repoPath.Path (Join-Path ".codex-logs" ("checkpoint-review-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
$codexResult = Invoke-FleetCodexReadOnly -Prompt $prompt -Models $modelChain -OutputPath $tmp.FullName -WorkingDirectory $repoPath.Path -LogPath $logPath -TimeoutSeconds $TimeoutSeconds -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns
$codexExit = if ($null -eq $codexResult) { 1 } else { $codexResult.exitCode }

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
$dirtyAfter = @(git status --porcelain 2>$null)
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
