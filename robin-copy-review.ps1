[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [string]$Project = "",

    [string]$OutFile = "docs/codex/ROBIN_COPY_REVIEW.md",

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
$taskQueue = if (Test-Path "docs/codex/TASK_QUEUE.md") { Get-Content "docs/codex/TASK_QUEUE.md" -Raw } else { "No task queue found." }
$checkpoint = if (Test-Path "docs/codex/CHECKPOINT_REVIEW.md") { Get-Content "docs/codex/CHECKPOINT_REVIEW.md" -Raw } else { "No checkpoint review found." }
$simon = if (Test-Path "docs/codex/SIMON_DESIGN_REVIEW.md") { Get-Content "docs/codex/SIMON_DESIGN_REVIEW.md" -Raw } else { "No Simon design review found." }
$visualBugs = if (Test-Path "docs/codex/VISUAL_BUGS.md") { Get-Content "docs/codex/VISUAL_BUGS.md" -Raw } else { "No visual bug report found." }
$reportTail = if (Test-Path "docs/codex/NIGHTLY_REPORT.md") { Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 160 } else { @("No nightly report found.") }

$textFiles = @(git ls-files |
    Where-Object {
        $_ -match "\.(tsx|ts|jsx|js|html|css|md|json)$" -and
        $_ -notmatch "^(dist|build|coverage|node_modules|\.codex-logs)/" -and
        $_ -notmatch "(package-lock|tsbuildinfo)"
    } |
    Select-Object -First 80)

$copySamples = @()
foreach ($file in $textFiles) {
    try {
        $matches = @(Select-String -Path $file -Pattern "[A-Za-z][A-Za-z ,;:'`"\.\!\?\-&/]{18,}" -AllMatches -ErrorAction SilentlyContinue |
            Select-Object -First 8)
        foreach ($match in $matches) {
            $line = $match.Line.Trim()
            if ($line.Length -gt 220) {
                $line = $line.Substring(0, 220) + "..."
            }
            $copySamples += "${file}:$($match.LineNumber): $line"
        }
    } catch {
        continue
    }
    if ($copySamples.Count -ge 120) { break }
}

$prompt = @"
You are Robin, the Codex Fleet voice editor.

Robin is calm, precise, literary, and excellent with delicate wording. She protects tone, product promise, hospitality language, sales copy, naming, menu descriptions, wine descriptions, and any copy that should feel beautiful without becoming fake, corny, manipulative, or overblown.

You are NOT implementing changes.
You are NOT editing files.
You are NOT writing files yourself.
Return only the markdown content for the copy review. The wrapper script will write it to:
$OutFile

Write markdown using exactly this structure:

# Robin Copy Review

## Verdict
Use exactly one: GREEN, YELLOW, or RED.

## One-Sentence Read
One sentence with Robin's copy and voice read.

## Mission Voice Fit
Does the language match the mission, audience, and product position? Be specific.

## Delicate Wording Risks
Bullets. Flag wording that feels misleading, overclaims, sounds student-made, sounds generic, is too cute for the audience, too corporate, too casual, too salesy, legally risky, insensitive, or off-brand.

## Beautiful Language Opportunities
Bullets. Name where copy could become clearer, warmer, more premium, more specific, or more evocative.

## Priority Rewrite
Name the single most important wording problem to fix next. One short paragraph, specific enough for Nami to turn into tasks.

## Suggested Rewrites
Provide 3 to 8 concise rewrite examples. Include before/after only when the source wording is available. Keep this practical.

## Voice Rules
Bullets. Define the voice rules the next implementer should follow.

## Next 5 Copy Tasks
Write five unchecked markdown tasks. Each task must be small, reviewable, and include guardrails.

## Stop Or Continue
Choose one: continue, continue but fix copy first, or stop for human copy review.

Rules:
- Use ASCII punctuation only. Use straight quotes and hyphens, not curly quotes or smart punctuation.
- Do not invent facts, sales claims, testimonials, results, prices, certifications, legal claims, or real restaurant data.
- For wine/menu/hospitality projects, favor vivid but honest sensory language: specific, elegant, restrained, useful to guests and staff.
- For playful projects, personality is welcome, but it must not bury clarity.
- Do not recommend backend, auth, payments, deployment, analytics, tracking, secrets, package changes, or broad architecture changes.
- RED is only for wording that is seriously misleading, risky, offensive, legally sensitive, or mission-breaking.
- YELLOW means copy should be improved before polish/merge, but the ship can continue.
- GREEN means the voice is clear, mission-fit, and has no obvious wording concerns.

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

Mission:
$mission

Run policy:
$runPolicy

Task queue:
$taskQueue

Checkpoint review:
$checkpoint

Simon design review:
$simon

Visual bug report:
$visualBugs

Nightly report tail:
$($reportTail -join "`n")

Copy samples:
$(if ($copySamples.Count -eq 0) { "- None found" } else { ($copySamples | Select-Object -First 120 | ForEach-Object { "- $_" }) -join "`n" })
"@

$tmp = New-TemporaryFile
$modelChain = @(ConvertTo-FleetStringArray -Value $Models)
if ($modelChain.Count -eq 0) {
    $modelChain = @(ConvertTo-FleetStringArray -Value $Model)
}
$logPath = Join-Path $repoPath.Path (Join-Path ".codex-logs" ("robin-copy-review-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
$codexResult = Invoke-FleetCodexReadOnly -Prompt $prompt -Models $modelChain -OutputPath $tmp.FullName -WorkingDirectory $repoPath.Path -LogPath $logPath -TimeoutSeconds $TimeoutSeconds -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns
$codexExit = if ($null -eq $codexResult) { 1 } else { $codexResult.exitCode }

if (!(Test-Path $tmp.FullName) -or ((Get-Item $tmp.FullName).Length -eq 0)) {
    Write-Host "Robin produced no output." -ForegroundColor Red
    Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
    exit 1
}

$reviewText = Get-Content $tmp.FullName -Raw
if ($reviewText -notmatch "^\s*# Robin Copy Review") {
    Write-Host "Robin output did not match the expected review format." -ForegroundColor Red
    Write-Host "Expected output to start with '# Robin Copy Review'." -ForegroundColor Yellow
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
    Write-Host "Robin changed files outside $OutFile. Stop for human review." -ForegroundColor Red
    $unexpected | ForEach-Object { Write-Host $_ }
    exit 1
}

Write-Host "Wrote $OutFile" -ForegroundColor Green

if ($codexExit -ne 0) {
    Write-Host "Robin exited nonzero, but wrote review output." -ForegroundColor Yellow
}

exit 0
