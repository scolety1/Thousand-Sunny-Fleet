param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [int]$Count = 5,

    [ValidateSet("auto", "brief", "foundation", "shape", "simplicity", "polish", "proof", "parked", "repair", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof")]
    [string]$LoopPhase = "auto",

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
$magicMission = if (Test-Path "docs/codex/MAGIC_MISSION.md") { Get-Content "docs/codex/MAGIC_MISSION.md" -Raw } else { "No magic mission file found." }
$workPacks = if (Test-Path "docs/codex/WORK_PACKS.md") { Get-Content "docs/codex/WORK_PACKS.md" -Raw } else { "No work packs file found." }
$workPackStatus = if (Test-Path "docs/codex/WORK_PACK_STATUS.md") { Get-Content "docs/codex/WORK_PACK_STATUS.md" -Raw } else { "No work pack status file found." }
$phaseState = if (Test-Path "docs/codex/PHASE_STATE.md") { Get-Content "docs/codex/PHASE_STATE.md" -Raw } else { "No phase state file found." }
$magicScorecard = if (Test-Path "docs/codex/MAGIC_SCORECARD.md") { Get-Content "docs/codex/MAGIC_SCORECARD.md" -Tail 160 } else { @("No magic scorecard found.") }
$qualityQuarantine = if (Test-Path "docs/codex/QUALITY_QUARANTINE.md") { Get-Content "docs/codex/QUALITY_QUARANTINE.md" -Tail 120 } else { @("No quality quarantine found.") }
$policy = if (Test-Path "docs/codex/RUN_POLICY.md") { Get-Content "docs/codex/RUN_POLICY.md" -Raw } else { "No run policy found." }
$siteMap = if (Test-Path "docs/codex/SITE_MAP.md") { Get-Content "docs/codex/SITE_MAP.md" -Raw } else { "No site map found." }
$visualRoutes = if (Test-Path "docs/codex/visual-routes.json") { Get-Content "docs/codex/visual-routes.json" -Raw } else { "No visual route config found." }
$checkpoint = if (Test-Path "docs/codex/CHECKPOINT_REVIEW.md") { Get-Content "docs/codex/CHECKPOINT_REVIEW.md" -Raw } else { "No checkpoint review found." }
$simon = if (Test-Path "docs/codex/SIMON_DESIGN_REVIEW.md") { Get-Content "docs/codex/SIMON_DESIGN_REVIEW.md" -Raw } else { "No Simon design review found." }
$visualBugs = if (Test-Path "docs/codex/VISUAL_BUGS.md") { Get-Content "docs/codex/VISUAL_BUGS.md" -Raw } else { "No visual bug report found." }
$robin = if (Test-Path "docs/codex/ROBIN_COPY_REVIEW.md") { Get-Content "docs/codex/ROBIN_COPY_REVIEW.md" -Raw } else { "No Robin copy review found." }
$joey = if (Test-Path "docs/codex/JOEY_SECURITY_REVIEW.md") { Get-Content "docs/codex/JOEY_SECURITY_REVIEW.md" -Raw } else { "No Joey security review found." }
$reportTail = if (Test-Path "docs/codex/NIGHTLY_REPORT.md") { Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 140 } else { @("No report found.") }
$quarantineTail = if (Test-Path "docs/codex/QUARANTINED_TASKS.md") { Get-Content "docs/codex/QUARANTINED_TASKS.md" -Tail 140 } else { @("No quarantined tasks report found.") }

function Get-ActiveWorkPack {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $activeLine = [regex]::Match($Text, "(?im)^-\s*(Pack\s+\d+\s+-\s+[^:]+):\s*ACTIVE\s*$")
    if ($activeLine.Success) {
        return $activeLine.Groups[1].Value.Trim()
    }

    $activeHeading = [regex]::Match($Text, "(?ims)^##\s+Active Work Pack\s*\r?\n\s*(Pack\s+\d+\s+-\s+[^\r\n]+)")
    if ($activeHeading.Success) {
        return $activeHeading.Groups[1].Value.Trim()
    }

    return ""
}

$activeWorkPack = Get-ActiveWorkPack -Text $workPackStatus

function Get-PhaseFromState {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $match = [regex]::Match($Text, "(?im)^Current Phase:\s*(brief|foundation|shape|simplicity|polish|proof|parked|repair|problem-brief|data-contract|formula-spec|fixture-tests|engine-build|calibration|dashboard|scenario-tools|analysis-proof)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim().ToLowerInvariant() }
    return ""
}

$effectivePhase = if ($LoopPhase -ne "auto") { $LoopPhase } else { Get-PhaseFromState -Text $phaseState }
if ([string]::IsNullOrWhiteSpace($effectivePhase)) { $effectivePhase = "foundation" }

$prompt = @"
You are the mission planner for an unattended Codex branch.

Generate exactly $Count next tasks as markdown checklist lines.

Rules:
- Output only checklist lines, no commentary.
- Each line must start with "- [ ] ".
- Prefer this metadata syntax at the end of each task when useful: [class:feature risk:low mode:single impact:visible scope:src/,docs/codex/].
- Supported classes: feature, bugfix, refactor, test, docs, design, copy, backend, migration, integration, performance.
- Supported risks: low, medium, high, gated. Use high/gated only for work that should require an approved architecture plan.
- Supported modes: mode:single and mode:feature-pack. Use mode:feature-pack only when SOFTWARE_FEATURE_PLAN.md and SOFTWARE_FEATURE_APPROVAL.md are approved and the task has explicit scope and accept metadata.
- Supported impacts: impact:standard, impact:visible, and impact:showpiece. Use impact:visible for design/copy/page/mobile tasks. Use impact:showpiece for final, demo-ready, major redesign, premium, or high-expectation creative tasks.
- Use scope: only when the task can be safely bounded to clear path prefixes.
- Use accept: only for task-specific checks beyond the normal external build, and only when the exact command is already documented in the ship's run policy/profile or package scripts. Do not invent npm.cmd test.
- Each task must be small enough for one Codex implementation round.
- Each task must include explicit forbidden scope.
- Prefer tasks that advance the mission and reduce obvious rough edges.
- Treat Simon, Visual Bug Report, Robin, and Joey as active repair orders, not optional reading.
- Priority order for next tasks:
  1. If Joey is RED or says stop for human security review and Current loop phase is not repair, output one docs-only task to summarize the security stop-risk, then no more tasks.
  2. If Visual Bug Report has HIGH findings or suggested visual fix tasks, turn those into the first tasks.
  3. If Simon has a Priority Fix, Designer Handoff, What Not To Do Next, or Next 5 Design Tasks, use those to shape the next tasks before inventing unrelated work.
  4. If Robin is RED or says stop for human copy review and Current loop phase is not repair, output one docs-only task to summarize the copy stop-risk, then no more tasks.
  5. If Robin has a Priority Rewrite, Suggested Rewrites, Voice Rules, or Next 5 Copy Tasks, use those to shape copy/voice tasks before inventing unrelated work.
  6. If Checkpoint Review says patch first, convert the patch concern into task(s).
  7. Only after those repair orders are addressed, generate fresh mission-forward tasks.
- If Simon says "continue but fix visual issues first", the next tasks must fix those visual issues first.
- If Robin says "continue but fix copy first", the next tasks must fix those wording issues first.
- Do not generate generic polish tasks when Simon or Visual Bug Report names a concrete issue.
- Do not generate generic copy polish tasks when Robin names a concrete rewrite.
- Do not repeat recently completed tasks unless Simon, Visual Bug Report, Robin, Joey, or Checkpoint Review says the issue remains.
- Do not repeat quarantined tasks. If a quarantined task still matters, propose a smaller safer version that avoids the failure reason.
- If MAGIC_MISSION.md and WORK_PACKS.md are present, plan from them before inventing isolated polish tasks.
- Prefer coherent work-pack progress: choose one active pack, generate tasks that advance it in order, and include the pack name in natural task wording.
- If WORK_PACK_STATUS.md names an active pack, every fresh mission-forward task must mention that active pack label, for example "Pack 1 - Product Spine".
- Do not move to a later pack until WORK_PACK_STATUS.md marks the current pack DONE.
- Use MAGIC_SCORECARD.md to avoid work that previously scored as weak, blocked, or repetitive.
- If SITE_MAP.md or visual-routes.json names multiple routes, treat them as intended product surfaces. Generate route/page tasks when splitting content into real pages would make the product clearer.
- Do not tell Codex to preserve current routes if the task is about page splits, route repair, navigation, or reducing an overloaded one-page experience.
- Route/page tasks must say frontend-only, prefer existing routing patterns, avoid new dependencies unless explicitly approved, and update SITE_MAP.md plus visual-routes.json when routes change.
- If QUALITY_QUARANTINE.md exists, treat it like an active repair order. The next task must be a smaller repair task for the named active work pack.
- Every task should make the next screenshot, workflow, or user-facing product state measurably better.
- Visible/showpiece tasks must change the actual product surface, not only reports/docs or tiny spacing polish. If the desired change needs more structure, generate page/component/content tasks that make the improvement obvious in screenshots.
- Current loop phase: $effectivePhase.
- Read PHASE_STATE.md as a hard planning constraint. Every generated task must fit the current phase.
- Treat these PHASE_STATE.md fields as first-class requirements, not background notes: Audience, Product Promise, Primary Action, Showable Moment, What Not To Build, No More Features Lock, Complexity Budget, Before/After Judgment, Human Taste Note, Phase Model Policy, Parking State, Evidence Required, Done Signal, Next Phase Criteria, Repair Trigger, and Repair Return Phase.
- Every task must support the Product Promise and Showable Moment.
- Every task must serve the Audience and preserve the Primary Action.
- If No More Features Lock is true, do not generate feature-addition tasks; generate removal, demotion, simplification, refinement, proof, or parked-review tasks only.
- Every task must respect What Not To Build and the Complexity Budget.
- For visible work, the task wording must say how the Before/After Judgment should improve.
- Every task acceptance should produce the Evidence Required or explain why the task is docs-only.
- Do not generate more work once the Done Signal is met except proof, parking, or explicitly requested user changes.
- Respect Next Phase Criteria when deciding whether to generate current-phase work or a phase-advancement task.
- If Parking State is PARKED_REVIEW_READY or Current Phase is parked, output only one docs-only task saying the ship is review-ready and should not continue unattended.
- Phase doctrine:
  - repair: interrupt lane for RED review gates, build/runtime failures, quarantine, stale/idle lock problems, security stops, and visual blockers. Generate exactly one smallest blocker-clearing task for the Repair Trigger; preserve the Repair Return Phase, keep No More Features Lock true, and do not add features.
  - brief: define or repair audience, product promise, primary action, showable moment, and what not to build; prefer docs/codex/PHASE_STATE.md or mission docs only.
  - foundation: add missing routes, components, local demo data, and core interactions; do not spend tasks on final polish or tiny visual refinements.
  - shape: clarify audience, promise, first screen, page order, and primary flow; reorganize or remove confusing sections; do not add unrelated features.
  - simplicity: reduce cognitive load; remove, combine, shorten, hide, or demote before adding; require one obvious primary action and fewer choices than before.
  - polish: refine typography, spacing, hierarchy, color, button rhythm, and final microcopy; do not add sections, routes, or new product capabilities.
  - proof: fix blockers only: broken routes, build/runtime failures, clipped text, tap targets, copy smoke, and visual QA issues; do not redesign.
  - parked: output one docs-only task explaining the ship is review-ready and should not continue unattended.
- Analytical software doctrine:
  - problem-brief: define the exact decision, user, output labels/tables, assumptions, and what the tool must not predict; docs-first.
  - data-contract: define CSV schemas, database tables, canonical IDs, snapshot folders, source metadata, missing-data warnings, and reject/warn rules; no UI polish.
  - formula-spec: write deterministic formulas, weights, priors/defaults, confidence rules, examples, and edge cases before implementation.
  - fixture-tests: create tiny sample datasets and expected outputs for every formula/rule/import validator; tests before app screens.
  - engine-build: implement loaders, validators, scoring/ranking/probability functions, exports, and CLI/service seams; core math must be reproducible.
  - calibration: compare outputs against historical data, sanity fixtures, known cases, and confidence behavior; tune thresholds without adding flashy UI.
  - dashboard: build table-first review UI, filters, explanations, and report views only after formulas/tests are trustworthy.
  - scenario-tools: add bounded what-if controls, strategy modes, weight changes, and comparisons using the deterministic engine.
  - analysis-proof: fix blockers only: tests, imports, deterministic report generation, no live-data dependency, no secrets, and reproducible outputs.
- For analytical phases, never ask Codex to invent final numbers from prose. Generate tasks that make code compute numbers from local data, fixtures, and deterministic formulas.
- For formula-spec and fixture-tests, prioritize concrete fixture examples: tiny input rows, expected outputs, formula tests, import tests, and edge cases. Engine-build is blocked until these exist.
- For engine-build and later analytical phases, every task should include an accept: command that runs the relevant formula/import/model tests when the ship has a documented test command.
- For calibration and later analytical phases, require calibration evidence before trusting UI: known-case comparisons, historical/backtest evidence or an explicit unavailable-history fallback, confidence behavior, failure modes, tuning rules, and CALIBRATION_READINESS.md.
- Dashboard and scenario-tools tasks must be table/report-first and should not add flashy insight text until calibration readiness is GREEN or intentionally YELLOW with documented unavailable history.
- Dashboard and scenario-tools tasks are blocked until ANALYTICAL_DASHBOARD_READINESS.md can show formula/model tests, import validation tests, fixture expected outputs, and at least one deterministic report/table artifact.
- If analytical dashboard readiness is missing or RED, downgrade UI ideas into evidence tasks: tests, import validators, generated model output tables, deterministic markdown reports, and restrained table views.
- For calculation-heavy ships, prefer test/data/model tasks over visual polish until dashboard or scenario-tools phase.
- For shape, simplicity, and polish tasks, explicitly name what to remove, demote, combine, or preserve.
- Avoid tasks that make the first screen more crowded, add extra cards, add extra explanatory sections, or create more choices unless the current phase is foundation and the core flow is missing.
- In repair phase, do not output docs-only stop summaries unless the gate explicitly requires human approval. Prefer a bounded repair task that names the failing gate and the exact files/scope to touch.
- Do not propose merges, deploys, pushes to main, secrets, auth changes, billing, DNS, backend changes, or broad rewrites.
- Do not propose package/dependency edits unless DEPENDENCY_APPROVAL.md is approved and the task explicitly asks for an approved dependency lane.
- If the checkpoint review says RED or stop for human review and Current loop phase is not repair, output one docs-only task to summarize the blocker and stop-risk, then no more tasks.

Repository: $($repoPath.Path)
Branch: $branch
HEAD: $head
Base branch: $BaseBranch

Mission:
$mission

Magic mission:
$magicMission

Work packs:
$workPacks

Work pack status:
$workPackStatus

Phase state:
$phaseState

Magic scorecard tail:
$($magicScorecard -join "`n")

Quality quarantine tail:
$($qualityQuarantine -join "`n")

Run policy:
$policy

Site map:
$siteMap

Visual route config:
$visualRoutes

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

if (![string]::IsNullOrWhiteSpace($activeWorkPack)) {
    $activePackNumber = [regex]::Match($activeWorkPack, "Pack\s+\d+").Value
    $packTasks = @($tasks | Where-Object { $_ -notmatch [regex]::Escape($activeWorkPack) -and $_ -notmatch [regex]::Escape($activePackNumber) })
    if ($packTasks.Count -gt 0) {
        Write-Host "Planner produced task(s) that do not mention the active work pack: $activeWorkPack" -ForegroundColor Red
        $packTasks | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
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
