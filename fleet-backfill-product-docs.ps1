[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Project = "",

    [string]$FleetGroup = "",

    [string]$ConfigPath = ".\projects.json",

    [switch]$All,

    [switch]$Apply,

    [switch]$Force,

    [string]$OutPath = "out\product-doc-backfill.md"
)

$ErrorActionPreference = "Continue"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-Projects {
    param([string]$Path)

    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (!$resolved) { Stop-WithMessage "Config not found: $Path" }

    $loaded = Get-Content -LiteralPath $resolved.Path -Raw | ConvertFrom-Json
    if ($loaded -is [array]) { return @($loaded) }
    if ($null -ne $loaded -and $loaded.PSObject.Properties.Name -contains "value") { return @($loaded.value) }
    if ($null -ne $loaded) { return @($loaded) }
    return @()
}

function Get-ConfigValue {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = ""
    )

    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Join-Values {
    param([object]$Values)

    $items = @($Values | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($items.Count -eq 0) { return "none configured" }
    return ($items -join ", ")
}

function Get-ShipKind {
    param([object]$Ship)

    $demoName = [string](Get-ConfigValue -Object $Ship -Name "demoName" -Default "")
    if (![string]::IsNullOrWhiteSpace($demoName)) { return $demoName }
    return [string](Get-ConfigValue -Object $Ship -Name "name" -Default "Ship")
}

function Get-DefaultUser {
    param([object]$Ship)

    $profile = [string](Get-ConfigValue -Object $Ship -Name "profile" -Default "")
    $type = [string](Get-ConfigValue -Object $Ship -Name "projectType" -Default "")
    $name = [string](Get-ConfigValue -Object $Ship -Name "name" -Default "Ship")
    $demo = Get-ShipKind -Ship $Ship

    if ($name -eq "EasyLife") { return "A logged-in EasyLife user managing tasks, notes, calendar, and personal planning." }
    if ($name -eq "NinersWarRoom") { return "The Niners co-owner using local fantasy football rankings and keeper decisions." }
    if ($name -eq "RestaurantDemo") { return "A restaurant owner or GM evaluating a custom workflow automation studio." }
    if ($name -eq "ShiftPlate") { return "A chef or kitchen manager turning available mise into a practical special." }
    if ($name -eq "CursorPets") { return "A desktop pet user who wants Mochi to be easy to install and delightful to use." }
    if ($name -eq "Tree") { return "A family member creating, joining, and browsing a private family tree." }
    if ($type -eq "marketing-site" -or $profile -eq "frontend-static-demo") { return "A restaurant operator reviewing the $demo demo on a phone." }
    return "The primary user of $demo."
}

function Get-DefaultJob {
    param([object]$Ship)

    $name = [string](Get-ConfigValue -Object $Ship -Name "name" -Default "Ship")
    $demo = Get-ShipKind -Ship $Ship

    switch ($name) {
        "EasyLife" { return "Daily personal planning across tasks, notes, calendar, reminders, and assistant workflows." }
        "NinersWarRoom" { return "Keeper, drop, trade, and draft decisions for the league using deterministic local data." }
        "RestaurantDemo" { return "Deciding whether a restaurant workflow can be fixed with a small custom tool." }
        "ShiftPlate" { return "Creating a service-ready special from available ingredients without overusing the whole mise." }
        "CursorPets" { return "Installing and interacting with Mochi without friction." }
        "Tree" { return "Starting, joining, and browsing one family tree." }
        default { return "Understanding and using the $demo workflow without extra software complexity." }
    }
}

function Get-FirstUsefulVersion {
    param([object]$Ship)

    $name = [string](Get-ConfigValue -Object $Ship -Name "name" -Default "Ship")
    $demo = Get-ShipKind -Ship $Ship
    switch ($name) {
        "EasyLife" { return "A stable local preview where the protected app feels faster, simpler, and clearly useful on mobile." }
        "NinersWarRoom" { return "A local dashboard that loads roster data, shows formulas, and explains keeper/drop recommendations." }
        "RestaurantDemo" { return "A polished sales site with clear demo routes for restaurant workflow fixes." }
        "ShiftPlate" { return "A two-step kitchen board that produces credible options and concise printable kitchen notes." }
        "CursorPets" { return "A web and desktop install path that makes Mochi easy to launch, size, move, hide, and wake." }
        "Tree" { return "A styled home, sign-in, dashboard, tree, and search flow with no broken unstyled pages." }
        default { return "A phone-friendly $demo demo that a buyer understands in under 30 seconds." }
    }
}

function Get-SurfaceSplit {
    param([object]$Ship)

    $name = [string](Get-ConfigValue -Object $Ship -Name "name" -Default "Ship")
    $demo = Get-ShipKind -Ship $Ship
    switch ($name) {
        "EasyLife" { return @{ Public = "Product/demo surface: explain the personal assistant vision and install/login path."; App = "Working app surface: tasks, notes, calendar, and planning modules with the next useful action first."; Internal = "Settings, account, data, assistant explanations, and history."; Primary = "Help the logged-in user decide what to do next."; Secondary = "Switch modules, add item, brain dump, review calendar."; Detail = "Task details, note metadata, repeat/custom scheduling, undo history, settings."; Hidden = "Marketing copy, settings, account controls, assistant implementation details." } }
        "CursorPets" { return @{ Public = "Product/demo surface: show Mochi, install/open actions, and compatibility."; App = "Working app surface: the desktop pet interaction itself."; Internal = "Debug controls, sizing/window settings, behavior tuning."; Primary = "Let the user see, launch, and interact with Mochi."; Secondary = "Download/open, size controls, hide window, behavior settings."; Detail = "Install help, desktop permissions, personal ranking notes."; Hidden = "Founder notes, implementation details, long explanations." } }
        "RestaurantDemo" { return @{ Public = "Customer-facing sales surface: show restaurant operators examples of custom workflow fixes."; App = "Working demo surfaces: wine list, manager brief, events intake, order sheet, or training hub examples."; Internal = "Build notes, workflow configuration, fake-data disclaimers."; Primary = "Make a restaurant operator understand one useful offer fast."; Secondary = "Open demo examples, contact, compare workflows."; Detail = "Process details, technical explanation, implementation notes."; Hidden = "Internal build language, broad automation claims, long feature explanations." } }
        "ShiftPlate" { return @{ Public = "Product/demo surface: explain the kitchen special generator briefly."; App = "Working app surface: enter mise, window, headcount, then review options."; Internal = "Recipe heuristics, rejected ideas, service-plan logic."; Primary = "Generate three credible special ideas from available ingredients."; Secondary = "Make cheaper/fancier after options exist, print/share recipe."; Detail = "Recipe detail, prep timing, allergens, pass note."; Hidden = "Long reasoning, unused ingredients, service plan outside selected option." } }
        default {
            if ($demo -match "wine|beverage|cellar|bottle|manager|brief|event|order|training|restaurant") {
                return @{ Public = "Customer-facing restaurant example: a believable fake restaurant brand and guest-ready page."; App = "Working tool demo: one restaurant workflow opened from a clear action."; Internal = "Staff-only notes, setup details, fake data caveats, and implementation context."; Primary = "Show the main restaurant job first, such as browse the wine list, read today's brief, request an event, count items, or open training."; Secondary = "Help me choose, filters, staff pick, send/share, approve, or open demo."; Detail = "Tasting notes, pairings, reservation details, task notes, vendor notes, recipe/service details."; Hidden = "Staff-only service notes, cellar locations, broad software explanation, and all secondary modules on first load." }
            }
            return @{ Public = "Public/product demo surface: explain the product and show the first useful example."; App = "Working app/tool surface: perform the primary workflow."; Internal = "Settings, diagnostics, implementation details, and admin-only notes."; Primary = "Let the user complete the first useful workflow."; Secondary = "Navigation, filters, helper actions, and optional modes."; Detail = "Expanded notes, history, configuration, and advanced options."; Hidden = "Marketing copy inside app screens, internal notes, diagnostics, and full-system explanation." }
        }
    }
}

function Get-ScoreForShip {
    param([object]$Ship)

    $profile = [string](Get-ConfigValue -Object $Ship -Name "profile" -Default "")
    $type = [string](Get-ConfigValue -Object $Ship -Name "projectType" -Default "")
    $risk = [string](Get-ConfigValue -Object $Ship -Name "riskTier" -Default "")
    $build = [string](Get-ConfigValue -Object $Ship -Name "buildCommand" -Default "")
    $visualPaths = @(Get-ConfigValue -Object $Ship -Name "visualPaths" -Default @())

    $localEval = if (![string]::IsNullOrWhiteSpace($build) -or $visualPaths.Count -gt 0) { 18 } else { 10 }
    $thin = if ($risk -in @("sandbox", "local-only") -and $profile -ne "real-product") { 9 } elseif ($risk -eq "production-adjacent") { 7 } else { 6 }
    $scope = if ($type -in @("marketing-site", "sandbox-prototype")) { 9 } else { 7 }
    $safety = if ($risk -in @("sandbox", "local-only")) { 5 } elseif ($risk -eq "production-adjacent") { 3 } else { 2 }

    return [ordered]@{
        "Recurring pain" = @{ Weight = 20; Score = 16; Evidence = "Recurring job is captured by ship mission and task queue." }
        "Clear buyer or user" = @{ Weight = 15; Score = 13; Evidence = "Primary user inferred from ship identity and config." }
        "Local evaluability" = @{ Weight = 20; Score = $localEval; Evidence = "Build command: $(if ([string]::IsNullOrWhiteSpace($build)) { 'missing' } else { $build }); visual paths: $(Join-Values $visualPaths)." }
        "Thin first release" = @{ Weight = 10; Score = $thin; Evidence = "Risk tier is $risk; profile is $profile." }
        "Bounded scope" = @{ Weight = 10; Score = $scope; Evidence = "Project type is $type." }
        "Revenue or demo speed" = @{ Weight = 10; Score = 8; Evidence = "Local preview and iterative fleet loops can show progress quickly." }
        "Demo clarity" = @{ Weight = 5; Score = 4; Evidence = "First useful version is defined as a short local demo or workflow." }
        "Fleet leverage" = @{ Weight = 5; Score = 4; Evidence = "Design, copy, test, visual, repair, and formula passes can run separately." }
        "Data and compliance safety" = @{ Weight = 5; Score = $safety; Evidence = "Risk tier and capabilities limit sensitive work." }
    }
}

function Get-DecisionForScore {
    param(
        [int]$Score,
        [bool]$HasRedFlag
    )

    if ($HasRedFlag) { return "REVISE" }
    if ($Score -ge 70) { return "ADMIT" }
    if ($Score -ge 55) { return "REVISE" }
    return "PARK"
}

function New-UserJobDoc {
    param([object]$Ship)

    return @"
# User Job

Primary user: $(Get-DefaultUser -Ship $Ship)

Recurring job: $(Get-DefaultJob -Ship $Ship)

Current workaround: Manual review, scattered notes, static pages, or repeated local inspection.

Desired outcome: $(Get-FirstUsefulVersion -Ship $Ship)

Local proof: Build command and configured preview routes should prove the main workflow still works.
"@
}

function New-EvaluatorsDoc {
    param([object]$Ship)

    $build = [string](Get-ConfigValue -Object $Ship -Name "buildCommand" -Default "")
    $visualPaths = @(Get-ConfigValue -Object $Ship -Name "visualPaths" -Default @())
    $buildLine = if ([string]::IsNullOrWhiteSpace($build)) { "Command: TODO: add a local build, smoke, or static check command." } else { "Command: $build" }

    return @"
# Evaluators

Define how this ship proves progress. If the fleet cannot evaluate the work locally, it should not spend long autonomous loops on the ship.

## Build Evaluator

$buildLine

Expected result: command exits 0 without generated-output churn.

## Visual Evaluator

Routes or screens to inspect: $(Join-Values $visualPaths)

What must be visible: the main workflow, primary action, and one obvious next step.

What must not happen: broken styling, duplicate headers, confusing walls of text, fake data presented as real, or hidden primary controls.

## Product Evaluator

Manual check: open the local preview and complete the first useful workflow.

Expected user outcome: $(Get-FirstUsefulVersion -Ship $Ship)

## Data Or Formula Evaluator

Fixtures: use project-specific fixtures when formulas, recommendations, imports, or rankings are present.

Golden values: document known inputs and expected outputs before formula changes.

Tolerance: deterministic outputs should match exactly unless the formula spec says otherwise.

## Copy Evaluator

Voice: plain, specific, useful, and low-jargon.

Forbidden phrases: unlock, revolutionize, seamless, AI-powered, intelligent ecosystem, ready for service, wine-list polish.

Clarity check: a new user should know what the page does in under 30 seconds.

## Regression Risks

- Risk: product gets more complicated instead of easier.
  Check: remove or hide secondary controls before adding more UI.
- Risk: generated claims sound fake or unsupported.
  Check: every number, rank, recommendation, or formula has a source or fixture.
"@
}

function New-ScorecardDoc {
    param([object]$Ship)

    $scores = Get-ScoreForShip -Ship $Ship
    $total = 0
    foreach ($row in $scores.Values) { $total += [int]$row.Score }
    $hasRedFlag = $false
    $decision = Get-DecisionForScore -Score $total -HasRedFlag $hasRedFlag
    $rows = foreach ($key in $scores.Keys) {
        $row = $scores[$key]
        "| $key | $($row.Weight) | $($row.Score) | $($row.Evidence -replace '\|', '/') |"
    }

    return @"
# Ship Scorecard

Use this before giving a ship meaningful autonomous runtime. The goal is to prove the ship has a narrow useful job, a clear user, and a local way to evaluate progress.

## Summary

Ship name: $([string](Get-ConfigValue -Object $Ship -Name "name" -Default "Ship"))

Primary user or buyer: $(Get-DefaultUser -Ship $Ship)

Weekly job this replaces: $(Get-DefaultJob -Ship $Ship)

First useful version: $(Get-FirstUsefulVersion -Ship $Ship)

Local evaluator: build command plus configured visual or manual preview routes.

Current recommendation: $decision

## Admission Score

| Criterion | Weight | Score | Evidence |
| --- | ---: | ---: | --- |
$($rows -join "`n")
| Total | 100 | $total | 70+ admit, 55-69 revise, below 55 park. |

## Red Flags

- [ ] Needs payments to be useful.
- [ ] Needs custom auth or account roles to be useful.
- [ ] Stores regulated, sensitive, payment, medical, payroll, tax, or private production data.
- [ ] Depends on many third-party integrations before v1 has value.
- [ ] Has no credible local evaluator.
- [ ] Has no named user workflow.
- [ ] Is broad, platform-shaped, or generic AI-wrapper-shaped.
- [ ] Requires live external APIs at decision time.

## Decision

Choose one:

- ADMIT: Score is 70+ and no red flags apply.
- REVISE: Score is 55-69 or the job/user/evaluator needs sharpening.
- PARK: Score is below 55, red flags apply, or the ship cannot prove local usefulness.

Decision: $decision

Reason: Auto-backfilled from fleet config; review and sharpen before enforcing long unattended runs.

Next action: Run product usefulness review and assign one product-shaped task.
"@
}

function New-AdmissionDoc {
    param([object]$Ship)

    return @"
# Ship Admission

Use this with SHIP_SCORECARD.md before giving the ship meaningful autonomous runtime.

## Decision

Decision: REVIEW

Reason: Auto-backfilled from fleet config. A human should confirm the scorecard before enforcing admission gates.

Next action: Fill any project-specific user job, evaluator, and usefulness details that the backfill could not infer.

## Required Checks

- [x] SHIP_SCORECARD.md has a score and no checked red flags.
- [x] USER_JOB.md names the primary user and recurring job.
- [x] EVALUATORS.md defines a local build, visual, product, data, or copy check.
- [ ] Product owner has confirmed this is still worth autonomous runtime.

## Red Flag Notes

If any scorecard red flag applies, explain the redesign or approval here before launching long runs.
"@
}

function New-UsefulnessDoc {
    param([object]$Ship)

    return @"
# Product Usefulness

Use this after each run or before a new batch. The fleet should continue only when the next loop is likely to make the product easier to understand, use, test, or sell.

## Current Useful State

$(Get-FirstUsefulVersion -Ship $Ship)

## Last Useful Change

Auto-backfilled product docs so launch gates can judge the ship against user value instead of just code motion.

## Main Friction

The next concrete product friction still needs to be chosen from live preview, reports, or user feedback.

## Next Useful Improvement

The next task should improve:

- [x] main workflow
- [x] local evaluator
- [x] visual clarity
- [x] copy clarity
- [ ] formula correctness
- [x] onboarding or demo path
- [x] repair or regression risk

Specific improvement: choose one visible or deterministic friction from the latest preview/reports and make it easier to understand or use.

## Usefulness Gate

Answer before launching another batch:

- [x] The next task improves the main user workflow.
- [x] The next task has a visible, testable, or deterministic acceptance check.
- [x] The next task removes or reduces complexity.
- [x] The next task avoids broad platform expansion.
- [x] The next task can be reviewed locally.

Gate result: SIMPLIFY

## Parking Rule

If three consecutive runs produce no meaningful product improvement, park the ship and write the reason here.
"@
}

function New-InformationStagingDoc {
    param([object]$Ship)

    $split = Get-SurfaceSplit -Ship $Ship
    return @"
# Information Staging

Use this file to prevent the fleet from dumping every useful feature onto the first screen. The first screen should show the primary job. Secondary information should be obvious but quiet. Detail and internal information should be one click or tap away.

## Surface Split

Public/customer-facing surface: $($split.Public)

Working app/internal tool surface: $($split.App)

Internal/admin-only surface: $($split.Internal)

Rule: do not blend these surfaces on the same first screen unless a task explicitly creates a mode switch or detail view.

## First Screen Contract

First screen job: $($split.Primary)

Primary content: $($split.Primary)

Secondary actions: $($split.Secondary)

Detail content: $($split.Detail)

Not visible at first: $($split.Hidden)

How deeper information opens: clear buttons, tabs, accordions, drawers, cards, detail views, or staff/internal mode. Do not add a wall of sections just because the information is useful.

Required task metadata: every visible UI/product task must include `First screen: ...` so the planner, launch gate, and reviewers know what must stay dominant.

## Progressive Disclosure Rules

- Show the thing the user came for before helper features.
- Keep the primary content visually dominant.
- Put helper tools behind obvious actions.
- Put long notes, metadata, service details, settings, and internal context behind detail views.
- Prefer fewer visible sections with stronger navigation over one oversized dashboard page.
- If adding a useful detail makes the first screen busier, move another detail out of first view.

## Restaurant Demo Rule

Customer-facing restaurant examples should feel like real restaurant websites first. A wine list should primarily show wines. A private-events page should primarily show the event request path. A manager brief or order sheet should be opened as a working tool, not mixed into the guest-facing restaurant homepage.

## Product Demo Rule

Product ships should separate the public/product demo from the actual app. Marketing explanation belongs on public/demo pages. The working app should use direct labels and prioritize doing the job.
"@
}

function Get-BackfillDocs {
    param([object]$Ship)

    return [ordered]@{
        "docs\codex\USER_JOB.md" = (New-UserJobDoc -Ship $Ship)
        "docs\codex\EVALUATORS.md" = (New-EvaluatorsDoc -Ship $Ship)
        "docs\codex\SHIP_SCORECARD.md" = (New-ScorecardDoc -Ship $Ship)
        "docs\codex\SHIP_ADMISSION.md" = (New-AdmissionDoc -Ship $Ship)
        "docs\codex\PRODUCT_USEFULNESS.md" = (New-UsefulnessDoc -Ship $Ship)
        "docs\codex\INFORMATION_STAGING.md" = (New-InformationStagingDoc -Ship $Ship)
    }
}

Set-Location $fleetRoot
if (!$All -and [string]::IsNullOrWhiteSpace($Project) -and [string]::IsNullOrWhiteSpace($FleetGroup)) {
    Stop-WithMessage "Specify -Project ShipName, -FleetGroup GroupName, or -All."
}

$projects = Get-Projects -Path $ConfigPath
$selected = @($projects)
if (![string]::IsNullOrWhiteSpace($Project)) {
    $selected = @($selected | Where-Object { [string]$_.name -ceq [string]$Project })
}
if (![string]::IsNullOrWhiteSpace($FleetGroup)) {
    $selected = @($selected | Where-Object { [string](Get-ConfigValue -Object $_ -Name "fleetGroup" -Default "") -ceq [string]$FleetGroup })
}
if ($selected.Count -eq 0) { Stop-WithMessage "No matching ships found." }

$report = @(
    "# Product Docs Backfill",
    "",
    "Generated: $(Get-Date -Format o)",
    "",
    "Mode: $(if ($Apply) { 'APPLY' } else { 'PREVIEW' })",
    "",
    "Force overwrite: $Force",
    ""
)

foreach ($ship in $selected) {
    $name = [string](Get-ConfigValue -Object $ship -Name "name" -Default "")
    $repo = Resolve-Path ([string](Get-ConfigValue -Object $ship -Name "repo" -Default "")) -ErrorAction SilentlyContinue
    $report += "## $name"
    $report += ""

    if (!$repo) {
        $report += "- ERROR: repo path not found."
        $report += ""
        Write-Host "${name}: repo path not found" -ForegroundColor Red
        continue
    }

    $repoPath = $repo.Path
    $docs = Get-BackfillDocs -Ship $ship
    $created = 0
    $kept = 0
    $wouldCreate = 0
    $wouldOverwrite = 0

    foreach ($relative in $docs.Keys) {
        $target = Join-Path $repoPath $relative
        $exists = Test-Path -LiteralPath $target

        if ($Apply) {
            if ($exists -and !$Force) {
                $kept++
                $report += "- Kept existing $relative"
                continue
            }
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
            Set-Content -LiteralPath $target -Value $docs[$relative]
            $created++
            $verb = if ($exists) { "Overwrote" } else { "Created" }
            $report += "- $verb $relative"
        } else {
            if ($exists -and !$Force) {
                $kept++
                $report += "- Would keep existing $relative"
            } elseif ($exists -and $Force) {
                $wouldOverwrite++
                $report += "- Would overwrite $relative"
            } else {
                $wouldCreate++
                $report += "- Would create $relative"
            }
        }
    }

    $report += ""
    if ($Apply) {
        Write-Host "${name}: wrote $created, kept $kept" -ForegroundColor Green
        $report += "Summary: wrote $created, kept $kept."
    } else {
        Write-Host "${name}: would create $wouldCreate, would overwrite $wouldOverwrite, would keep $kept" -ForegroundColor Cyan
        $report += "Summary: would create $wouldCreate, would overwrite $wouldOverwrite, would keep $kept."
    }
    $report += ""
}

$resolvedOut = if ([System.IO.Path]::IsPathRooted($OutPath)) { $OutPath } else { Join-Path $fleetRoot $OutPath }
$outParent = Split-Path -Parent $resolvedOut
if (![string]::IsNullOrWhiteSpace($outParent)) {
    New-Item -ItemType Directory -Force -Path $outParent | Out-Null
}
Set-Content -LiteralPath $resolvedOut -Value ($report -join "`n")
Write-Host "Backfill report: $resolvedOut" -ForegroundColor DarkCyan
