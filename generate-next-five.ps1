param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [int]$Count = 5,

    [string]$OutFile = "docs/codex/NEXT_5_TASKS.md",

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

$preStatus = @(git status --porcelain)
if ($preStatus.Count -gt 0) {
    Write-Host "Nami requires a clean working tree before planning tasks." -ForegroundColor Red
    $preStatus | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$branch = git branch --show-current
$head = git rev-parse --short HEAD
$changed = @(git diff --name-status "$BaseBranch..HEAD")
$commits = @(git log --oneline "$BaseBranch..HEAD" -n 30)
$unchecked = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() })
$completed = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[x\]" -ErrorAction SilentlyContinue | Select-Object -Last 30 | ForEach-Object { $_.Line.Trim() })
$quarantined = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[!\]" -ErrorAction SilentlyContinue | Select-Object -Last 30 | ForEach-Object { $_.Line.Trim() })
$mission = if (Test-Path "docs/codex/MISSION.md") { Get-Content "docs/codex/MISSION.md" -Raw } else { "No mission file found." }
$policy = if (Test-Path "docs/codex/RUN_POLICY.md") { Get-Content "docs/codex/RUN_POLICY.md" -Raw } else { "No run policy found." }
$checkpoint = if (Test-Path "docs/codex/CHECKPOINT_REVIEW.md") { Get-Content "docs/codex/CHECKPOINT_REVIEW.md" -Raw } else { "No checkpoint review found." }
$simon = if (Test-Path "docs/codex/SIMON_DESIGN_REVIEW.md") { Get-Content "docs/codex/SIMON_DESIGN_REVIEW.md" -Raw } else { "No Simon design review found." }
$visualBugs = if (Test-Path "docs/codex/VISUAL_BUGS.md") { Get-Content "docs/codex/VISUAL_BUGS.md" -Raw } else { "No visual bug report found." }
$robin = if (Test-Path "docs/codex/ROBIN_COPY_REVIEW.md") { Get-Content "docs/codex/ROBIN_COPY_REVIEW.md" -Raw } else { "No Robin copy review found." }
$joey = if (Test-Path "docs/codex/JOEY_SECURITY_REVIEW.md") { Get-Content "docs/codex/JOEY_SECURITY_REVIEW.md" -Raw } else { "No Joey security review found." }
$reportTail = if (Test-Path "docs/codex/NIGHTLY_REPORT.md") { Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 140 } else { @("No report found.") }
$quarantineTail = if (Test-Path "docs/codex/QUARANTINED_TASKS.md") { Get-Content "docs/codex/QUARANTINED_TASKS.md" -Tail 140 } else { @("No quarantined tasks report found.") }

$prompt = @"
You are the mission planner for an unattended Codex branch.

Generate exactly $Count next tasks as markdown checklist lines.

Rules:
- Output only checklist lines, no commentary.
- Each line must start with "- [ ] ".
- Prefer this metadata syntax at the end of each task when useful: [class:feature risk:low scope:src/,docs/codex/ accept:npm.cmd test].
- Supported classes: feature, bugfix, refactor, test, docs, design, copy, backend, migration, integration, performance.
- Supported risks: low, medium, high, gated. Use high/gated only for work that should require an approved architecture plan.
- Use scope: only when the task can be safely bounded to clear path prefixes.
- Use accept: only for task-specific checks beyond the normal external build.
- Each task must be small enough for one Codex implementation round.
- Each task must include explicit forbidden scope.
- Prefer tasks that advance the mission and reduce obvious rough edges.
- Treat Simon, Visual Bug Report, Robin, and Joey as active repair orders, not optional reading.
- Priority order for next tasks:
  1. If Joey is RED or says stop for human security review, output one docs-only task to summarize the security stop-risk, then no more tasks.
  2. If Visual Bug Report has HIGH findings or suggested visual fix tasks, turn those into the first tasks.
  3. If Simon has a Priority Fix, Designer Handoff, What Not To Do Next, or Next 5 Design Tasks, use those to shape the next tasks before inventing unrelated work.
  4. If Robin is RED or says stop for human copy review, output one docs-only task to summarize the copy stop-risk, then no more tasks.
  5. If Robin has a Priority Rewrite, Suggested Rewrites, Voice Rules, or Next 5 Copy Tasks, use those to shape copy/voice tasks before inventing unrelated work.
  6. If Checkpoint Review says patch first, convert the patch concern into task(s).
  7. Only after those repair orders are addressed, generate fresh mission-forward tasks.
- If Simon says "continue but fix visual issues first", the next tasks must fix those visual issues first.
- If Robin says "continue but fix copy first", the next tasks must fix those wording issues first.
- Do not generate generic polish tasks when Simon or Visual Bug Report names a concrete issue.
- Do not generate generic copy polish tasks when Robin names a concrete rewrite.
- Do not repeat recently completed tasks unless Simon, Visual Bug Report, Robin, Joey, or Checkpoint Review says the issue remains.
- Do not repeat quarantined tasks. If a quarantined task still matters, propose a smaller safer version that avoids the failure reason.
- Do not propose merges, deploys, pushes to main, secrets, auth changes, billing, DNS, backend changes, or broad rewrites.
- If the checkpoint review says RED or stop for human review, output one docs-only task to summarize the blocker and stop-risk, then no more tasks.

Repository: $($repoPath.Path)
Branch: $branch
HEAD: $head
Base branch: $BaseBranch

Mission:
$mission

Run policy:
$policy

Checkpoint review:
$checkpoint

Simon design review:
$simon

Visual bug report:
$visualBugs

Robin copy review:
$robin

Joey security review:
$joey

Existing unchecked tasks:
$(if ($unchecked.Count -eq 0) { "- None" } else { ($unchecked | ForEach-Object { "- $_" }) -join "`n" })

Recently completed tasks:
$(if ($completed.Count -eq 0) { "- None" } else { ($completed | ForEach-Object { "- $_" }) -join "`n" })

Recently quarantined tasks:
$(if ($quarantined.Count -eq 0) { "- None" } else { ($quarantined | ForEach-Object { "- $_" }) -join "`n" })

Changed files since base:
$(if ($changed.Count -eq 0) { "- None" } else { ($changed | ForEach-Object { "- $_" }) -join "`n" })

Recent branch commits:
$(if ($commits.Count -eq 0) { "- None" } else { ($commits | ForEach-Object { "- $_" }) -join "`n" })

Nightly report tail:
$($reportTail -join "`n")

Quarantined task report tail:
$($quarantineTail -join "`n")
"@

$tmp = New-TemporaryFile
$modelChain = @(ConvertTo-FleetStringArray -Value $Models)
if ($modelChain.Count -eq 0) {
    $modelChain = @(ConvertTo-FleetStringArray -Value $Model)
}
$logPath = Join-Path $repoPath.Path (Join-Path ".codex-logs" ("nami-planner-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
$codexResult = Invoke-FleetCodexReadOnly -Prompt $prompt -Models $modelChain -OutputPath $tmp.FullName -WorkingDirectory $repoPath.Path -LogPath $logPath -TimeoutSeconds $TimeoutSeconds -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns
$codexExit = if ($null -eq $codexResult) { 1 } else { $codexResult.exitCode }

if (!(Test-Path $tmp.FullName) -or ((Get-Item $tmp.FullName).Length -eq 0)) {
    Write-Host "Planner produced no output." -ForegroundColor Red
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
    Write-Host "Nami changed files outside $OutFile. Stop for human review." -ForegroundColor Red
    $unexpected | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$tasks = @(Get-Content $outPath | Where-Object { $_ -match "^\s*-\s+\[ \]\s+.+" })
if ($tasks.Count -eq 0) {
    Write-Host "Planner output did not include markdown checklist tasks." -ForegroundColor Red
    exit 1
}
if ($tasks.Count -gt $Count) {
    Write-Host "Planner produced too many tasks: $($tasks.Count), expected at most $Count." -ForegroundColor Red
    exit 1
}

$vagueTasks = @($tasks | Where-Object { $_ -notmatch "(?i)do not|without|avoid|forbidden" })
if ($vagueTasks.Count -gt 0) {
    Write-Host "Planner produced task(s) without explicit forbidden scope." -ForegroundColor Red
    $vagueTasks | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$repairContext = "$simon`n$visualBugs`n$robin"
$repairSignals = @(
    "Priority Fix",
    "Designer Handoff",
    "Visual Problems To Fix",
    "Suggested Task Queue Wording",
    "continue but fix visual issues first",
    "Priority Rewrite",
    "Suggested Rewrites",
    "Voice Rules",
    "Next 5 Copy Tasks",
    "continue but fix copy first"
)
$hasRepairSignal = $false
foreach ($signal in $repairSignals) {
    if ($repairContext -match [regex]::Escape($signal)) {
        $hasRepairSignal = $true
        break
    }
}
if ($hasRepairSignal) {
    $taskText = ($tasks -join "`n")
    $repairTerms = @(
        "visual",
        "mobile",
        "design",
        "layout",
        "hierarchy",
        "spacing",
        "tap",
        "overflow",
        "header",
        "hero",
        "filter",
        "card",
        "badge",
        "typography",
        "truncat",
        "copy",
        "wording",
        "voice",
        "tone",
        "rewrite",
        "description",
        "menu",
        "wine",
        "Simon",
        "Robin",
        "Walkthrough"
    )
    $mentionsRepair = $false
    foreach ($term in $repairTerms) {
        if ($taskText -match "(?i)$term") {
            $mentionsRepair = $true
            break
        }
    }
    if (-not $mentionsRepair) {
        Write-Host "Planner ignored active Simon/visual/Robin repair signals." -ForegroundColor Red
        Write-Host "Generated tasks:" -ForegroundColor Yellow
        $tasks | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
}

Write-Host "Wrote $OutFile with $($tasks.Count) proposed task(s)." -ForegroundColor Green
if ($codexExit -ne 0) {
    Write-Host "Planner exited nonzero, but proposed tasks were written for inspection." -ForegroundColor Yellow
}
