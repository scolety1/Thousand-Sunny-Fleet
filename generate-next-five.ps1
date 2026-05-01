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

$preStatus = @(git status --porcelain 2>$null)
if ($preStatus.Count -gt 0) {
    Write-Host "Nami requires a clean working tree before planning tasks." -ForegroundColor Red
    $preStatus | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$branch = git branch --show-current
$head = git rev-parse --short HEAD
$gitComparison = Get-FleetGitComparison -BaseBranch $BaseBranch -MaxCommits 30
$changed = @($gitComparison.changed)
$commits = @($gitComparison.commits)
$unchecked = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue | ForEach-Object { $_.Line.Trim() })
$completed = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[x\]" -ErrorAction SilentlyContinue | Select-Object -Last 30 | ForEach-Object { $_.Line.Trim() })
$quarantined = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[!\]" -ErrorAction SilentlyContinue | Select-Object -Last 30 | ForEach-Object { $_.Line.Trim() })
$mission = if (Test-Path "docs/codex/MISSION.md") { Get-Content "docs/codex/MISSION.md" -Raw } else { "No mission file found." }
$userJob = if (Test-Path "docs/codex/USER_JOB.md") { Get-Content "docs/codex/USER_JOB.md" -Raw } else { "No user job file found." }
$evaluators = if (Test-Path "docs/codex/EVALUATORS.md") { Get-Content "docs/codex/EVALUATORS.md" -Raw } else { "No evaluators file found." }
$shipAdmission = if (Test-Path "docs/codex/SHIP_ADMISSION.md") { Get-Content "docs/codex/SHIP_ADMISSION.md" -Raw } else { "No ship admission file found." }
$shipScorecard = if (Test-Path "docs/codex/SHIP_SCORECARD.md") { Get-Content "docs/codex/SHIP_SCORECARD.md" -Raw } else { "No ship scorecard file found." }
$shipAdmissionReview = if (Test-Path "docs/codex/SHIP_ADMISSION_REVIEW.md") { Get-Content "docs/codex/SHIP_ADMISSION_REVIEW.md" -Raw } else { "No ship admission review found." }
$productUsefulness = if (Test-Path "docs/codex/PRODUCT_USEFULNESS.md") { Get-Content "docs/codex/PRODUCT_USEFULNESS.md" -Raw } else { "No product usefulness file found." }
$productUsefulnessReview = if (Test-Path "docs/codex/PRODUCT_USEFULNESS_REVIEW.md") { Get-Content "docs/codex/PRODUCT_USEFULNESS_REVIEW.md" -Raw } else { "No product usefulness review found." }
$informationStaging = if (Test-Path "docs/codex/INFORMATION_STAGING.md") { Get-Content "docs/codex/INFORMATION_STAGING.md" -Raw } else { "No information staging file found." }
$operatingMode = if (Test-Path "docs/codex/OPERATING_MODE.md") { Get-Content "docs/codex/OPERATING_MODE.md" -Raw } else { "No operating mode file found." }
$referenceBrief = if (Test-Path "docs/codex/REFERENCE_BRIEF.md") { Get-Content "docs/codex/REFERENCE_BRIEF.md" -Raw } elseif (Test-Path "docs/codex/CREATIVE_BRIEF.md") { Get-Content "docs/codex/CREATIVE_BRIEF.md" -Raw } else { "No reference brief file found." }
$magicMission = if (Test-Path "docs/codex/MAGIC_MISSION.md") { Get-Content "docs/codex/MAGIC_MISSION.md" -Raw } else { "No magic mission file found." }
$workPacks = if (Test-Path "docs/codex/WORK_PACKS.md") { Get-Content "docs/codex/WORK_PACKS.md" -Raw } else { "No work packs file found." }
$workPackStatus = if (Test-Path "docs/codex/WORK_PACK_STATUS.md") { Get-Content "docs/codex/WORK_PACK_STATUS.md" -Raw } else { "No work pack status file found." }
$phaseState = if (Test-Path "docs/codex/PHASE_STATE.md") { Get-Content "docs/codex/PHASE_STATE.md" -Raw } else { "No phase state file found." }
$websiteStageRules = if (Test-Path "docs/codex/WEBSITE_STAGE_RULES.md") { Get-Content "docs/codex/WEBSITE_STAGE_RULES.md" -Raw } else { "No website stage rules file found." }
$doneContract = if (Test-Path "docs/codex/DONE_CONTRACT.md") { Get-Content "docs/codex/DONE_CONTRACT.md" -Raw } else { "No done contract file found." }
$magicScorecard = if (Test-Path "docs/codex/MAGIC_SCORECARD.md") { Get-Content "docs/codex/MAGIC_SCORECARD.md" -Tail 160 } else { @("No magic scorecard found.") }
$qualityQuarantine = if (Test-Path "docs/codex/QUALITY_QUARANTINE.md") { Get-Content "docs/codex/QUALITY_QUARANTINE.md" -Tail 120 } else { @("No quality quarantine found.") }
$policy = if (Test-Path "docs/codex/RUN_POLICY.md") { Get-Content "docs/codex/RUN_POLICY.md" -Raw } else { "No run policy found." }
$siteMap = if (Test-Path "docs/codex/SITE_MAP.md") { Get-Content "docs/codex/SITE_MAP.md" -Raw } else { "No site map found." }
$visualRoutes = if (Test-Path "docs/codex/visual-routes.json") { Get-Content "docs/codex/visual-routes.json" -Raw } else { "No visual route config found." }
$checkpoint = if (Test-Path "docs/codex/CHECKPOINT_REVIEW.md") { Get-Content "docs/codex/CHECKPOINT_REVIEW.md" -Raw } else { "No checkpoint review found." }
$simon = if (Test-Path "docs/codex/SIMON_DESIGN_REVIEW.md") { Get-Content "docs/codex/SIMON_DESIGN_REVIEW.md" -Raw } else { "No Simon design review found." }
$visualBugs = if (Test-Path "docs/codex/VISUAL_BUGS.md") { Get-Content "docs/codex/VISUAL_BUGS.md" -Raw } else { "No visual bug report found." }
$robin = if (Test-Path "docs/codex/ROBIN_COPY_REVIEW.md") { Get-Content "docs/codex/ROBIN_COPY_REVIEW.md" -Raw } else { "No Robin copy review found." }
$accessibility = if (Test-Path "docs/codex/ACCESSIBILITY_REVIEW.md") { Get-Content "docs/codex/ACCESSIBILITY_REVIEW.md" -Raw } else { "No accessibility review found." }
$performance = if (Test-Path "docs/codex/PERFORMANCE_REVIEW.md") { Get-Content "docs/codex/PERFORMANCE_REVIEW.md" -Raw } else { "No performance review found." }
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

function Test-FleetTaskHasProductShape {
    param([string]$Task)

    $required = @(
        "User pain:",
        "Target:",
        "Change:",
        "Remove/simplify:",
        "Guardrails:",
        "Acceptance:",
        "Check:"
    )

    foreach ($label in $required) {
        if ($Task -notmatch [regex]::Escape($label)) {
            return $false
        }
    }

    return $true
}

function Test-FleetTaskRequiresSurface {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    if ($Task -match "(?i)(?:^|[\s\[])impact:(visible|showpiece)\b") { return $true }
    if ($Task -match "(?i)(?:^|[\s\[])class:(feature|design|copy)\b") { return $true }
    return $false
}

function Test-FleetTaskHasSurface {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    return ($Task -match "(?i)(?:^|[\s\[])surface:(public|app|internal|mixed)\b")
}

function Get-FleetTaskSurfaceCount {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return 0 }
    return @([regex]::Matches($Task, "(?i)(?:^|[\s\[])surface:(public|app|internal|mixed)\b")).Count
}

function Test-FleetTaskHasFirstScreenField {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    $match = [regex]::Match($Task, "(?i)\bfirst[- ]screen(?:\s+job)?\s*:\s*([^.\[\r\n]+)")
    if (!$match.Success) { return $false }
    $value = $match.Groups[1].Value.Trim()
    return !($value -match "(?i)\b(todo|tbd|unknown|fill this|to be decided|not decided|placeholder|lorem ipsum)\b" -or $value -match "(?i)^(n/a|none)\.?$")
}

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
- Each task line must use this product-shape format, in this order: "User pain: ... Target: ... Change: ... Remove/simplify: ... Guardrails: ... Acceptance: ... Check: ...".
- For UI/product tasks, insert "First screen: ..." between Change and Remove/simplify, like: "User pain: ... Target: ... Change: ... First screen: ... Remove/simplify: ... Guardrails: ... Acceptance: ... Check: ...".
- User pain must name the concrete confusion, wasted time, broken workflow, missing trust, or blocked demo value the task addresses.
- Target must name the route, screen, component, module, docs file, formula, test, or local evaluator affected.
- Change must say the specific behavior, layout, formula, copy, test, or route change to make.
- Remove/simplify must name what to remove, demote, combine, shorten, hide, or preserve as "none, preserve X" when removal is not appropriate.
- Guardrails must include explicit forbidden scope and any phase/admission/usefulness constraint.
- Acceptance must include the normal documented build/check command, a documented test/static-check command, or a docs-only acceptance when the task is intentionally docs-only.
- Check must include the visual, manual, fixture, formula, or report check that proves usefulness.
- For UI/product tasks, the task must preserve information staging: name the first-screen job, keep the primary surface dominant, and move secondary/detail/internal information behind clear navigation, buttons, tabs, accordions, drawers, or detail views.
- UI/product tasks with class:feature, class:design, class:copy, impact:visible, or impact:showpiece must include a concrete "First screen: ..." field in the task text. This field names what must be visible and dominant before helper/detail content.
- UI/product tasks with class:feature, class:design, class:copy, impact:visible, or impact:showpiece must include exactly one surface metadata value: surface:public, surface:app, surface:internal, or surface:mixed.
- Public/customer surfaces sell or serve the visitor; app/internal surfaces support the working tool. Do not blend guest-facing restaurant pages with staff-only service notes unless the task explicitly creates a staff mode.
- Prefer this metadata syntax at the end of each task when useful: [class:feature risk:low mode:single impact:visible scope:src/,docs/codex/].
- Supported classes: feature, bugfix, refactor, test, docs, design, copy, backend, migration, integration, performance.
- Supported risks: low, medium, high, gated. Use high/gated only for work that should require an approved architecture plan.
- Supported modes: mode:single and mode:feature-pack. Use mode:feature-pack only when SOFTWARE_FEATURE_PLAN.md and SOFTWARE_FEATURE_APPROVAL.md are approved and the task has explicit scope and accept metadata.
- Supported impacts: impact:standard, impact:visible, and impact:showpiece. Use impact:visible for design/copy/page/mobile tasks. Use impact:showpiece for final, demo-ready, major redesign, premium, or high-expectation creative tasks.
- Use scope: only when the task can be safely bounded to clear path prefixes.
- Use accept: only for task-specific checks beyond the normal external build, and only when the exact command is already documented in the ship's run policy/profile or package scripts. Do not invent npm.cmd test.
- If accept: is omitted, the checkpoint loop will infer safe existing checks from package scripts or Python project files, such as test, lint, typecheck, pytest, or ruff when present.
- Large Phase 3 work must be plan-first and slice-based. Use risk:high or mode:feature-pack only when SOFTWARE_FEATURE_PLAN.md names the active slice, files/modules, runtime scenarios, and acceptance commands.
- If a request sounds large but no approved/specific plan exists, generate a planning or slice-definition task instead of one broad implementation task.
- Each task must be small enough for one Codex implementation round.
- Each task must include explicit forbidden scope.
- Prefer tasks that advance the mission and reduce obvious rough edges.
- Treat Simon, Visual Bug Report, Robin, Accessibility, Performance, and Joey as active repair orders, not optional reading.
- Treat OPERATING_MODE.md as a first-class instruction. It does not replace phases; it tells you what kind of judgment belongs inside the phase.
- If operating mode is hospitality-studio, plan like a restaurant creative director before coding: choose one surface type, protect the first-screen contract, avoid dashboard/feature dumping, keep copy concrete, and put secondary information behind clear discovery controls.
- If operating mode is hospitality-studio, treat REFERENCE_BRIEF.md as first-class creative direction. Tasks must preserve its reference qualities, first-screen rules, forbidden patterns, and acceptance lens.
- If operating mode is hospitality-studio and no reference brief exists, generate a docs-first task to create docs/codex/REFERENCE_BRIEF.md before showpiece implementation, unless the current loop phase is repair and a blocking runtime issue must be cleared.
- If operating mode is formula-lab, prioritize formulas, fixtures, provenance, calibration, and tests over visual polish. Never create persuasive model output without deterministic proof.
- If operating mode is software-engineering, prefer narrow code slices, tests, runtime verification, and security guardrails. Do not broaden scope for visual taste.
- If operating mode is demo-forge, build one compelling visible path, screenshot it, and park before it becomes a fake platform.
- Priority order for next tasks:
  1. If Joey is RED or says stop for human security review and Current loop phase is not repair, output one docs-only task to summarize the security stop-risk, then no more tasks.
  2. If Visual Bug Report has HIGH findings or suggested visual fix tasks, turn those into the first tasks.
  3. If Simon has a Priority Fix, Designer Handoff, What Not To Do Next, or Next 5 Design Tasks, use those to shape the next tasks before inventing unrelated work.
  4. If Robin is RED or says stop for human copy review and Current loop phase is not repair, output one docs-only task to summarize the copy stop-risk, then no more tasks.
  5. If Robin has a Priority Rewrite, Suggested Rewrites, Voice Rules, or Next 5 Copy Tasks, use those to shape copy/voice tasks before inventing unrelated work.
  6. If Accessibility Review is RED or says stop for human accessibility review and Current loop phase is not repair, output one smallest accessibility repair task, then no unrelated tasks.
  7. If Performance Review is RED or says stop for human performance review and Current loop phase is not repair, output one smallest performance repair task, then no unrelated tasks.
  8. If Checkpoint Review says patch first, convert the patch concern into task(s).
  9. Only after those repair orders are addressed, generate fresh mission-forward tasks.
- If Simon says "continue but fix visual issues first", the next tasks must fix those visual issues first.
- If Robin says "continue but fix copy first", the next tasks must fix those wording issues first.
- Do not generate generic polish tasks when Simon or Visual Bug Report names a concrete issue.
- Do not generate generic copy polish tasks when Robin names a concrete rewrite.
- Do not repeat recently completed tasks unless Simon, Visual Bug Report, Robin, Accessibility, Performance, Joey, or Checkpoint Review says the issue remains.
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
- Plan from USER_JOB.md, EVALUATORS.md, SHIP_ADMISSION.md, SHIP_SCORECARD.md, SHIP_ADMISSION_REVIEW.md, PRODUCT_USEFULNESS.md, and PRODUCT_USEFULNESS_REVIEW.md before inventing work.
- If SHIP_ADMISSION_REVIEW.md says PARK, output one docs-only task to document that the ship is parked and should not continue unattended.
- If SHIP_ADMISSION_REVIEW.md says REVISE, generate admission/doc/evaluator sharpening tasks before product implementation.
- If PRODUCT_USEFULNESS_REVIEW.md says NEEDS HUMAN DIRECTION, generate one docs-only task to fill product truth fields and stop.
- If PRODUCT_USEFULNESS_REVIEW.md says PARK, output one docs-only parking task and stop.
- If PRODUCT_USEFULNESS_REVIEW.md says REPAIR, the next task must be repair-first and must name the failing gate.
- If PRODUCT_USEFULNESS_REVIEW.md says SIMPLIFY, the next task must reduce complexity before adding features.
- If PRODUCT_USEFULNESS_REVIEW.md says CONTINUE, generate only tasks that match the named Next Useful Improvement or its checked improvement areas.
- If INFORMATION_STAGING.md exists, treat it as the authority for first-screen job, primary content, secondary actions, detail content, internal-only content, and demo surface split. Generate tasks that repair violations before adding content.
- For restaurant/hospitality demos, separate the customer-facing restaurant example from the working operations tool: the public page should feel like a real restaurant website, and the working operations tool should live behind a clear "View wine list", "Open manager brief", "Plan event", or equivalent action.
- For product ships like EasyLife or CursorPets, separate the public/product demo surface from the actual working app surface. Marketing explanation must not crowd the working app's first screen.
- Visible/showpiece tasks must change the actual product surface, not only reports/docs or tiny spacing polish. If the desired change needs more structure, generate page/component/content tasks that make the improvement obvious in screenshots.
- Current loop phase: $effectivePhase.
- Read PHASE_STATE.md as a hard planning constraint. Every generated task must fit the current phase.
- If WEBSITE_STAGE_RULES.md exists, use it as the authoritative website stage contract: allowed work, forbidden work, exit criteria, reviewer gates, auto-advance rule, and stop rules for brief, foundation, shape, simplicity, polish, proof, and parked.
- For website stages, generate tasks only for missing exit criteria or named reviewer blockers. Do not generate generic polish when the stage contract says the ship should advance or park.
- If DONE_CONTRACT.md exists, use it as the ship-specific completion contract. Every generated task must close a failed Done Enough, Evidence Required, Must Not Do, or reviewer blocker bullet from that file.
- If DONE_CONTRACT.md says Done Enough is true or all listed evidence is already present, output one docs-only phase-advance or parked-review task instead of inventing more product work.
- Do not generate any task that conflicts with DONE_CONTRACT.md Must Not Do or the Advance Or Park Rule.
- Treat these PHASE_STATE.md fields as first-class requirements, not background notes: Audience, Product Promise, Primary Action, Showable Moment, What Not To Build, No More Features Lock, Complexity Budget, Before/After Judgment, Human Taste Note, Phase Model Policy, Parking State, Evidence Required, Done Signal, Next Phase Criteria, Repair Trigger, and Repair Return Phase.
- Every task must support the Product Promise and Showable Moment.
- Every task must serve the Audience and preserve the Primary Action.
- Every visible task must stage information progressively: primary surface first, secondary actions nearby, details one click/tap away, internal notes hidden unless the active surface is internal.
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
- Scenario-tools tasks are blocked until SCENARIO_SPEC.md and SCENARIO_APPROVAL.md are approved. Each scenario must name the inputs that may change, formulas affected, expected output changes, outputs that must remain fixed, scenario tests, and UI assumption labels.
- If scenario approval is missing or draft, generate scenario-spec/test tasks instead of sliders, strategy modes, or what-if UI controls.
- For calculation-heavy ships, prefer test/data/model tasks over visual polish until dashboard or scenario-tools phase.
- For shape, simplicity, and polish tasks, explicitly name what to remove, demote, combine, or preserve.
- Avoid tasks that make the first screen more crowded, add extra cards, add extra explanatory sections, or create more choices unless the current phase is foundation and the core flow is missing.
- Avoid "everything on one page" outcomes. If a task adds useful detail, it should also say where that detail lives so the first screen stays calm.
- In repair phase, do not output docs-only stop summaries unless the gate explicitly requires human approval. Prefer a bounded repair task that names the failing gate and the exact files/scope to touch.
  - Do not propose merges, deploys, pushes to main, secrets, auth changes, billing, DNS, or broad rewrites.
  - Do not propose backend, integration, or migration implementation unless the ship profile capability allows it and the matching Phase 4 evidence exists: API_CONTRACT.md plus approved API_CONTRACT_TESTS.md for backend/integration work, SEED_FIXTURE_PLAN.md plus approved SEED_FIXTURE_EVIDENCE.md for backend/migration work, and MIGRATION_PROPOSAL.md plus approved MIGRATION_APPROVAL.md for migration work. If evidence is missing, generate a docs/codex planning/evidence task instead.
- Do not propose package/dependency edits unless DEPENDENCY_APPROVAL.md is approved and the task explicitly asks for an approved dependency lane.
- If the checkpoint review says RED or a required human approval is missing and Current loop phase is not repair, output one docs-only task to summarize the blocker and stop-risk, then no more tasks.
- Exception: ignore stale or irrelevant Franky/formula-review RED signals outside analytical phases unless the current task, phase, or ship is actually formula/model/calculation work.
- If the checkpoint review merely says "stop for human review" because Simon/Robin are YELLOW while build, security, and visual blockers are otherwise clear, do not create a docs-only stop task during shape/simplicity/polish/proof runs. Instead generate one bounded product-surface repair from the named Simon/Robin concern, or stop planning if no concrete concern is named.

Repository: $($repoPath.Path)
Branch: $branch
HEAD: $head
Base branch: $BaseBranch
Resolved comparison base: $(if ([string]::IsNullOrWhiteSpace($gitComparison.baseRef)) { "none" } else { $gitComparison.baseRef })
Comparison range: $(if ([string]::IsNullOrWhiteSpace($gitComparison.range)) { "none" } else { $gitComparison.range })

Mission:
$mission

User job:
$userJob

Evaluators:
$evaluators

Ship admission:
$shipAdmission

Ship scorecard:
$shipScorecard

Ship admission review:
$shipAdmissionReview

Product usefulness:
$productUsefulness

Product usefulness review:
$productUsefulnessReview

Information staging:
$informationStaging

Operating mode:
$operatingMode

Reference brief:
$referenceBrief

Magic mission:
$magicMission

Work packs:
$workPacks

Work pack status:
$workPackStatus

Phase state:
$phaseState

Website stage rules:
$websiteStageRules

Done contract:
$doneContract

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

Accessibility review:
$accessibility

Performance review:
$performance

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
$dirtyAfter = @(git status --porcelain 2>$null)
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

$vagueTasks = @($tasks | Where-Object { -not (Test-FleetTaskHasForbiddenScope -Task $_) })
if ($vagueTasks.Count -gt 0) {
    Write-Host "Planner produced task(s) without explicit forbidden scope." -ForegroundColor Red
    $vagueTasks | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$unshapedTasks = @($tasks | Where-Object { -not (Test-FleetTaskHasProductShape -Task $_) })
if ($unshapedTasks.Count -gt 0) {
    Write-Host "Planner produced task(s) without required product-shape fields." -ForegroundColor Red
    Write-Host "Required labels: User pain:, Target:, Change:, Remove/simplify:, Guardrails:, Acceptance:, Check:" -ForegroundColor Yellow
    $unshapedTasks | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$missingSurfaceTasks = @($tasks | Where-Object { (Test-FleetTaskRequiresSurface -Task $_) -and -not (Test-FleetTaskHasSurface -Task $_) })
if ($missingSurfaceTasks.Count -gt 0) {
    Write-Host "Planner produced UI/product task(s) without required surface metadata." -ForegroundColor Red
    Write-Host "Required surface metadata: surface:public, surface:app, surface:internal, or surface:mixed." -ForegroundColor Yellow
    $missingSurfaceTasks | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$ambiguousSurfaceTasks = @($tasks | Where-Object { (Test-FleetTaskRequiresSurface -Task $_) -and (Get-FleetTaskSurfaceCount -Task $_) -ne 1 })
if ($ambiguousSurfaceTasks.Count -gt 0) {
    Write-Host "Planner produced UI/product task(s) with ambiguous surface metadata." -ForegroundColor Red
    Write-Host "Use exactly one surface metadata value: surface:public, surface:app, surface:internal, or surface:mixed." -ForegroundColor Yellow
    $ambiguousSurfaceTasks | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$missingFirstScreenTasks = @($tasks | Where-Object { (Test-FleetTaskRequiresSurface -Task $_) -and -not (Test-FleetTaskHasFirstScreenField -Task $_) })
if ($missingFirstScreenTasks.Count -gt 0) {
    Write-Host "Planner produced UI/product task(s) without required first-screen metadata." -ForegroundColor Red
    Write-Host "Required first-screen metadata: First screen: <the dominant first-screen job/content>." -ForegroundColor Yellow
    $missingFirstScreenTasks | ForEach-Object { Write-Host "  $_" }
    exit 1
}

if (![string]::IsNullOrWhiteSpace($activeWorkPack)) {
    $activePackNumber = [regex]::Match($activeWorkPack, "Pack\s+\d+").Value
    $normalizedTasks = @()
    $changedPackLabels = $false
    foreach ($task in $tasks) {
        if ($task -match [regex]::Escape($activeWorkPack) -or (![string]::IsNullOrWhiteSpace($activePackNumber) -and $task -match [regex]::Escape($activePackNumber))) {
            $normalizedTasks += $task
            continue
        }

        $normalizedTasks += ($task -replace "User pain:\s*", "User pain: $activeWorkPack - ")
        $changedPackLabels = $true
    }

    if ($changedPackLabels) {
        Set-Content -Path $outPath -Encoding UTF8 -Value ($normalizedTasks -join "`n")
        $tasks = @($normalizedTasks)
    }

    $packTasks = @($tasks | Where-Object { $_ -notmatch [regex]::Escape($activeWorkPack) -and (![string]::IsNullOrWhiteSpace($activePackNumber) -and $_ -notmatch [regex]::Escape($activePackNumber)) })
    if ($packTasks.Count -gt 0) {
        Write-Host "Planner produced task(s) that do not mention the active work pack: $activeWorkPack" -ForegroundColor Red
        $packTasks | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
}

$repairContext = "$simon`n$visualBugs`n$robin`n$accessibility`n$performance"
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
    "continue but fix copy first",
    "stop for human accessibility review",
    "stop for human performance review",
    "JavaScript bundle exceeds",
    "CSS bundle exceeds"
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
        "accessibility",
        "performance",
        "bundle",
        "runtime",
        "asset",
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
