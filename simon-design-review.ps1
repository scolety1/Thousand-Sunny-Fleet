[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [string]$Project = "",

    [string]$OutFile = "docs/codex/SIMON_DESIGN_REVIEW.md",

    [string]$Model = "",

    [string[]]$Models = @(),

    [int]$TimeoutSeconds = 600,

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

$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo not found: $Repo" -ForegroundColor Red
    exit 1
}

Set-Location $repoPath.Path

if ([string]::IsNullOrWhiteSpace($Project)) {
    $Project = Split-Path -Leaf $repoPath.Path
}

$branch = git branch --show-current
$head = git rev-parse --short HEAD
$status = @(git status --short)
$changed = @(git diff --name-status "$BaseBranch..HEAD")
$commits = @(git log --oneline "$BaseBranch..HEAD" -12)
$mission = if (Test-Path "docs/codex/MISSION.md") { Get-Content "docs/codex/MISSION.md" -Raw } else { "No mission file found." }
$runPolicy = if (Test-Path "docs/codex/RUN_POLICY.md") { Get-Content "docs/codex/RUN_POLICY.md" -Raw } else { "No run policy file found." }
$checkpoint = if (Test-Path "docs/codex/CHECKPOINT_REVIEW.md") { Get-Content "docs/codex/CHECKPOINT_REVIEW.md" -Raw } else { "No checkpoint review found." }
$visualBugs = if (Test-Path "docs/codex/VISUAL_BUGS.md") { Get-Content "docs/codex/VISUAL_BUGS.md" -Raw } else { "No visual bug report found." }
$reportTail = if (Test-Path "docs/codex/NIGHTLY_REPORT.md") { Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 160 } else { @("No nightly report found.") }

$latestVisualDirs = @(Get-ChildItem ".codex-logs" -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match "^visual(-inspect)?-" } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 3)

$screenshots = @()
foreach ($dir in $latestVisualDirs) {
    $screenshots += @(Get-ChildItem $dir.FullName -Filter "*.png" -File -ErrorAction SilentlyContinue |
        Sort-Object Name |
        Select-Object -First 8 |
        ForEach-Object { $_.FullName })
}

$prompt = @"
You are Simon, the Codex Fleet design director.

Simon is a French-born New York design lead with sharp taste, hospitality-grade standards, and no patience for weak hierarchy, muddy layout, generic SaaS styling, or work that misses the mission. Be direct, specific, and useful. Do not perform identity-based stereotyping. Your authority comes from design taste, product judgment, and mission discipline.

You are NOT implementing changes.
You are NOT editing files.
You are NOT writing files yourself.
Return only the markdown content for the design review. The wrapper script will write it to:
$OutFile

Write markdown using exactly this structure:

# Simon Design Review

## Verdict
Use exactly one: GREEN, YELLOW, or RED.

## One-Sentence Read
One sentence with Simon's honest design read.

## Mission Fit
Does the current design direction match the mission? Be specific.

## Taste Check
What feels premium, modern, current, or on-trend? What feels generic, amateur, cluttered, or off?

## Visual Problems To Fix
Bullets. Each bullet should describe a concrete visible issue, not vague taste.

## Strongest Opportunities
Bullets. Suggest high-leverage design improvements that would make the project feel more impressive.

## Priority Fix
Name the single most important design problem to fix next. One short paragraph, specific enough for Nami to turn into tasks.

## Designer Handoff
Give the next implementer a tactical design direction for the next batch. This should be descriptive, opinionated, and actionable. Include what should change, what should stay, and what result the user should feel.

## What Not To Do Next
Bullets. Call out tempting but wrong next moves, such as adding more sections, adding visual noise, overcomplicating layout, changing backend scope, or ignoring mobile.

## Next 5 Design Tasks
Write five unchecked markdown tasks. Each task must be small, reviewable, and include guardrails.

## Stop Or Continue
Choose one: continue, continue but fix visual issues first, or stop for human design review.

Rules:
- Be brutally honest, stylish, and a little sassy, but stay useful. A dry one-line jab is welcome when the design deserves it; do not turn the report into a comedy routine.
- Use ASCII punctuation only. Use straight quotes and hyphens, not curly quotes or smart punctuation.
- Favor mission fulfillment over novelty.
- Do not ask for huge rewrites unless the current direction is fundamentally wrong.
- Do not recommend backend, auth, payments, deployment, analytics, tracking, secrets, package changes, or broad architecture changes.
- Make the Stop Or Continue line short and machine-readable, but put the real design direction in Priority Fix and Designer Handoff.
- If screenshots are missing, say that confidence is lower.
- If visual bugs are reported, use them as evidence, but also judge the design quality.

Repository: $($repoPath.Path)
Project: $Project
Branch: $branch
HEAD: $head
Base branch: $BaseBranch

Working tree:
$(if ($status.Count -eq 0) { "- Clean" } else { ($status | ForEach-Object { "- $_" }) -join "`n" })

Changed files since base:
$(if ($changed.Count -eq 0) { "- None" } else { ($changed | ForEach-Object { "- $_" }) -join "`n" })

Recent commits:
$(if ($commits.Count -eq 0) { "- None" } else { ($commits | ForEach-Object { "- $_" }) -join "`n" })

Recent visual screenshots:
$(if ($screenshots.Count -eq 0) { "- None found" } else { ($screenshots | ForEach-Object { "- $_" }) -join "`n" })

Mission:
$mission

Run policy:
$runPolicy

Checkpoint review:
$checkpoint

Visual bug report:
$visualBugs

Nightly report tail:
$($reportTail -join "`n")
"@

$tmp = New-TemporaryFile
$modelChain = @(ConvertTo-FleetStringArray -Value $Models)
if ($modelChain.Count -eq 0) {
    $modelChain = @(ConvertTo-FleetStringArray -Value $Model)
}
$logPath = Join-Path $repoPath.Path (Join-Path ".codex-logs" ("simon-design-review-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
$codexResult = Invoke-FleetCodexReadOnly -Prompt $prompt -Models $modelChain -OutputPath $tmp.FullName -WorkingDirectory $repoPath.Path -LogPath $logPath -TimeoutSeconds $TimeoutSeconds -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns
$codexExit = if ($null -eq $codexResult) { 1 } else { $codexResult.exitCode }

if (!(Test-Path $tmp.FullName) -or ((Get-Item $tmp.FullName).Length -eq 0)) {
    Write-Host "Simon produced no output." -ForegroundColor Red
    Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
    exit 1
}

$reviewText = Get-Content $tmp.FullName -Raw
if ($reviewText -notmatch "^\s*# Simon Design Review") {
    Write-Host "Simon output did not match the expected review format." -ForegroundColor Red
    Write-Host "Expected output to start with '# Simon Design Review'." -ForegroundColor Yellow
    Write-Host "Actual output:" -ForegroundColor Yellow
    Write-Host $reviewText
    Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
    exit 1
}

$outPath = Join-Path $repoPath.Path $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
Copy-Item $tmp.FullName $outPath -Force
Remove-Item $tmp.FullName -Force

$dirty = @(git status --porcelain)
$allowedPath = $OutFile.Replace("\", "/")
$unexpected = @($dirty | Where-Object {
    $line = [string]$_
    $path = $line.Substring([Math]::Min(3, $line.Length)).Replace("\", "/")
    $path -ne $allowedPath
})

if ($unexpected.Count -gt 0) {
    Write-Host "Simon changed files outside $OutFile. Stop for human review." -ForegroundColor Red
    $unexpected | ForEach-Object { Write-Host $_ }
    exit 1
}

Write-Host "Wrote $OutFile" -ForegroundColor Green

if ($codexExit -ne 0) {
    Write-Host "Simon exited nonzero, but wrote review output." -ForegroundColor Yellow
}

exit 0
