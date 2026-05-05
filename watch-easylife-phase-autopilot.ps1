param(
    [int]$IntervalSeconds = 600,
    [int]$MaxIterations = 288
)

$ErrorActionPreference = "Continue"
$fleetRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = "C:\Dev\easylifehq.github.io"
$docs = Join-Path $repo "docs\codex"
$appDir = Join-Path $repo "app-vNext"
$logPath = Join-Path $fleetRoot "out\easylife-phase-autopilot.log"

function Write-Log {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$stamp $Message" | Tee-Object -FilePath $logPath -Append
}

function Get-EasyLifeStatusBlock {
    $status = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "fleet-status.ps1") 2>&1
    $lines = @($status)
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match "^===== EasyLife =====") {
            $start = $i
            break
        }
    }
    if ($start -lt 0) { return @() }
    $end = $lines.Count - 1
    for ($j = $start + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match "^=====") {
            $end = $j - 1
            break
        }
    }
    return $lines[$start..$end]
}

function Start-EasyLifeRun {
    param([int]$MaxBatches = 5)
    $cmd = "Set-Location '$fleetRoot'; .\run-checkpoint-loop.ps1 -Project 'EasyLife' -BatchSize 1 -MaxBatches $MaxBatches -VisualInspectEvery 1 -SimonEvery 1 -RobinEvery 1 -AccessibilityEvery 1 -PerformanceEvery 2 -JoeyEvery 2 -ContinueOnYellowCheckpoint -RateLimitCooldownSeconds 3600 -RateLimitMaxCooldowns 2 -MaxTaskQuarantines 2 -QuarantineFailedTasks"
    $process = Start-Process powershell -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd) -WindowStyle Hidden -PassThru
    Write-Log "Launched EasyLife run PID=$($process.Id) maxBatches=$MaxBatches"
}

function Get-CurrentPhaseKey {
    $phaseState = Join-Path $docs "PHASE_STATE.md"
    if (!(Test-Path $phaseState)) { return "" }
    $content = Get-Content $phaseState -Raw
    if ($content -match "Current Phase:\s*(\S+)") { return $Matches[1] }
    return ""
}

function Set-PhaseState {
    param(
        [hashtable]$Phase
    )
    $phaseState = Join-Path $docs "PHASE_STATE.md"
    $content = Get-Content $phaseState -Raw
    $content = $content -replace "Current Phase:\s*\S+", "Current Phase: $($Phase.Key)"
    $content = $content -replace "Showable Moment:.*", "Showable Moment: $($Phase.Showable)"
    $content = $content -replace "Done Signal:.*", "Done Signal: $($Phase.DoneSignal)"
    $content = $content -replace "Next Phase Criteria:.*", "Next Phase Criteria: $($Phase.NextCriteria)"
    $content = $content -replace "Repair Return Phase:\s*\S+", "Repair Return Phase: $($Phase.Key)"
    $content = $content -replace "Updated At:.*", "Updated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Set-Content -Path $phaseState -Value $content -Encoding UTF8
}

function Get-PhaseReviewPath {
    param([hashtable]$Phase)
    return (Join-Path $docs ("PHASE_{0}_REVIEW.md" -f $Phase.Number))
}

function Write-PhaseReview {
    param(
        [hashtable]$Phase,
        [hashtable]$NextPhase
    )
    $path = Get-PhaseReviewPath -Phase $Phase
    if (Test-Path $path) { return }
    $recent = (& git -C $repo log -8 --oneline) -join "`n"
    $nextText = if ($NextPhase) { "Ready for Phase $($NextPhase.Number): $($NextPhase.Name)." } else { "Final phase complete. Ready to park." }
    $body = @"
# Phase $($Phase.Number) Review - $($Phase.Name)

## Status

Phase $($Phase.Number) reached zero unchecked tasks with a clean working tree.

## Recent Commits

````text
$recent
````

## Evidence

- Fleet status reported EasyLife unchecked tasks: `0`
- Run lock: none
- Working tree: clean
- Phase task packet consumed.

## Outcome

$($Phase.ReviewOutcome)

## Next Step

$nextText
"@
    Set-Content -Path $path -Value $body -Encoding UTF8
}

function Write-TaskFiles {
    param([hashtable]$Phase)
    $tasks = $Phase.Tasks
    $nextPath = Join-Path $docs "NEXT_5_TASKS.md"
    Set-Content -Path $nextPath -Value (($tasks -join "`r`n") + "`r`n") -Encoding UTF8

    $taskQueuePath = Join-Path $docs "TASK_QUEUE.md"
    $queue = Get-Content $taskQueuePath -Raw
    $header = "## EasyLife Next Variation Phase $($Phase.Number) - $($Phase.Name) $(Get-Date -Format 'yyyy-MM-dd')"
    if ($queue -notmatch [regex]::Escape($header)) {
        Add-Content -Path $taskQueuePath -Value ("`r`n$header`r`n`r`n" + ($tasks -join "`r`n") + "`r`n") -Encoding UTF8
    }
}

function Invoke-BuildCheck {
    Push-Location $appDir
    try {
        & npm.cmd run build
        return ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
}

function Commit-Transition {
    param([hashtable]$NextPhase)
    & git -C $repo add docs/codex
    & git -C $repo commit -m ("Advance EasyLife to phase {0} {1}" -f $NextPhase.Number, ($NextPhase.Name.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-"))
}

function Complete-FinalPark {
    $phaseState = Join-Path $docs "PHASE_STATE.md"
    $content = Get-Content $phaseState -Raw
    $content = $content -replace "Parking State:.*", "Parking State: PARKED_REVIEW_READY"
    $content = $content -replace "Updated At:.*", "Updated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Set-Content -Path $phaseState -Value $content -Encoding UTF8
    Set-Content -Path (Join-Path $docs "NEXT_5_TASKS.md") -Value "- [x] EasyLife Phase 12 complete: QA, polish, and park finished. [class:proof risk:low mode:single]`r`n" -Encoding UTF8
    & git -C $repo add docs/codex
    & git -C $repo commit -m "Park EasyLife phase 12 review ready"
}

$phaseList = @(
    @{
        Number = 3; Key = "phase-3-today-engine"; Name = "Today Engine";
        Showable = "The protected side opens to a useful Today surface that answers what matters now.";
        DoneSignal = "Today answers what Spencer should do now with a next best move, today context, calendar pressure, due work, and fast capture without becoming a dashboard dump.";
        NextCriteria = "Move to Phase 4 Command Layer when the Today surface is coherent and the next work is about fast command/capture behavior.";
        ReviewOutcome = "Phase 3 made Today the primary decision surface. Phase 4 should add fast command and capture behavior without visual noise.";
        Tasks = @()
    },
    @{
        Number = 4; Key = "phase-4-command-layer"; Name = "Command Layer";
        Showable = "EasyLife feels faster because common actions are reachable through a calm command layer.";
        DoneSignal = "The command layer supports quick add, plan my day, what am I forgetting, email-to-task entry, study-plan entry, and short time-window actions without crowding Today.";
        NextCriteria = "Move to Phase 5 Inbox Intelligence when command/capture entry points are coherent and the next work is email-derived tasks/events/follow-ups.";
        ReviewOutcome = "Phase 4 added the speed layer for command and capture. Phase 5 should make inbox intelligence useful while keeping approvals safe.";
        Tasks = @(
            "- [ ] Phase 4 - Command palette shell: create or refine a calm command palette/quick action entry for existing local actions such as Add task, Plan my day, What am I forgetting, and Capture note. Keep it frontend-only and deterministic. Guardrails: app-vNext/src UI only; no backend, auth, Firebase, dependencies, generated output, deploy config, old-site, root files, or real AI/API calls. Acceptance: from `app-vNext`, run `npm.cmd run build`. [class:feature risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/experiments/,app-vNext/src/features/hq/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 4 - Natural capture affordance: make one focused improvement so natural-language capture feels available from Today without taking over the first viewport. Preserve existing UniversalCapture behavior and data shapes. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/experiments/,app-vNext/src/features/hq/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 4 - Mobile command access: make command/capture entry thumb-friendly at 390px while preserving navigation and Today hierarchy. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/ accept:npm.cmd run build]",
            "- [ ] Phase 4 - Command Layer review packet: run checks and write docs/codex/PHASE_4_REVIEW.md with changed files, route evidence, bugs, and Phase 5 readiness. Do not start Phase 5. [class:proof risk:low mode:single impact:planning surface:docs scope:docs/codex/,app-vNext/src/ accept:npm.cmd run build]"
        )
    },
    @{
        Number = 5; Key = "phase-5-inbox-intelligence"; Name = "Inbox Intelligence";
        Showable = "Email becomes a quiet source of tasks, deadlines, events, follow-ups, and drafts for approval.";
        DoneSignal = "Inbox surfaces task/deadline/event/follow-up candidates and an approval queue without auto-sending, auto-archiving, or changing backend/auth.";
        NextCriteria = "Move to Phase 6 School Planner when inbox intelligence has safe approval flows and the next work is class/deadline planning.";
        ReviewOutcome = "Phase 5 connected email-derived work to EasyLife safely. Phase 6 should focus on school planning and study load.";
        Tasks = @(
            "- [ ] Phase 5 - Inbox approval queue UI: improve or add a frontend-only approval queue surface for email-derived task, deadline, event, and follow-up candidates using existing/mock/local data only. No real Gmail send/archive automation in this phase. Acceptance: npm.cmd run build from app-vNext. [class:feature risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/easylist/,app-vNext/src/features/hq/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 5 - Email classification language: make candidate types clear and calm: task, deadline, event, follow-up, keep visible, draft reply. Preserve behavior and data shapes. Acceptance: npm.cmd run build from app-vNext. [class:copy risk:low mode:single impact:visible surface:app scope:app-vNext/src/ accept:npm.cmd run build]",
            "- [ ] Phase 5 - Safe reply draft affordance: add or refine a non-sending draft-reply entry point that clearly requires user approval. No real send behavior. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/easylist/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 5 - Inbox Intelligence review packet: run checks and write docs/codex/PHASE_5_REVIEW.md. Do not start Phase 6. [class:proof risk:low mode:single impact:planning surface:docs scope:docs/codex/,app-vNext/src/ accept:npm.cmd run build]"
        )
    },
    @{
        Number = 6; Key = "phase-6-school-planner"; Name = "School Planner";
        Showable = "EasyLife can turn class deadlines and exams into a calm study plan surface.";
        DoneSignal = "School planning has course, assignment, exam, study-load, and heavy-week surfaces using safe local/mock data without schema/backend changes.";
        NextCriteria = "Move to Phase 7 Capacity And Coach when school planning is visible and the next work is realistic daily capacity.";
        ReviewOutcome = "Phase 6 made school planning a visible EasyLife layer. Phase 7 should connect plans to capacity and coaching.";
        Tasks = @(
            "- [ ] Phase 6 - School planner surface: add or refine a frontend-only school planning surface under More or Today context using local/mock data for courses, assignments, and exams. No backend/schema changes. Acceptance: npm.cmd run build from app-vNext. [class:feature risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/hq/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 6 - Study load view: add one compact study-load/heavy-week view that can show upcoming assignments/exams and suggested focus. Use local/mock data only. Acceptance: npm.cmd run build from app-vNext. [class:feature risk:medium mode:single impact:visible surface:app scope:app-vNext/src/ accept:npm.cmd run build]",
            "- [ ] Phase 6 - School-to-calendar/task affordance: add a safe UI affordance for turning a school item into a task/calendar block, without persistence changes if unsupported. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/ accept:npm.cmd run build]",
            "- [ ] Phase 6 - School Planner review packet: run checks and write docs/codex/PHASE_6_REVIEW.md. Do not start Phase 7. [class:proof risk:low mode:single impact:planning surface:docs scope:docs/codex/,app-vNext/src/ accept:npm.cmd run build]"
        )
    },
    @{
        Number = 7; Key = "phase-7-capacity-and-coach"; Name = "Capacity And Coach";
        Showable = "EasyLife helps choose a realistic plan based on day load, energy, and workouts.";
        DoneSignal = "Capacity/Coach shows daily capacity, light/normal/push planning, workout/recovery signal, and fitness coach context without preachiness.";
        NextCriteria = "Move to Phase 8 Notes And Memory when capacity and coach feel connected to Today.";
        ReviewOutcome = "Phase 7 connected plans to capacity and coaching. Phase 8 should make notes part of the action/memory system.";
        Tasks = @(
            "- [ ] Phase 7 - Capacity signal slice: add or refine a local deterministic capacity signal on Today/Coach using calendar/task/workout context where available. No backend/schema changes. Acceptance: npm.cmd run build from app-vNext. [class:feature risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/hq/,app-vNext/src/features/easyworkout/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 7 - Plan intensity modes: add or refine Light/Normal/Push plan UI copy and controls as local UI only. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/ accept:npm.cmd run build]",
            "- [ ] Phase 7 - Fitness coach connection: make workout logging/progress feel connected to the daily plan without overcrowding Today. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/easyworkout/,app-vNext/src/features/hq/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 7 - Capacity And Coach review packet: run checks and write docs/codex/PHASE_7_REVIEW.md. Do not start Phase 8. [class:proof risk:low mode:single impact:planning surface:docs scope:docs/codex/,app-vNext/src/ accept:npm.cmd run build]"
        )
    },
    @{
        Number = 8; Key = "phase-8-notes-and-memory"; Name = "Notes And Memory";
        Showable = "Notes feel connected to action, memory, and follow-up rather than a separate drawer.";
        DoneSignal = "Notes support quick capture, recent review, search/browse hierarchy, and visible paths to turn notes into actions.";
        NextCriteria = "Move to Phase 9 Optional Power Modules when notes feel connected and the next work is optional depth without clutter.";
        ReviewOutcome = "Phase 8 connected notes to action and memory. Phase 9 should organize optional modules without clutter.";
        Tasks = @(
            "- [ ] Phase 8 - Notes capture/review hierarchy: refine EasyNotes so quick capture and recent review are the dominant first jobs. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/easynotes/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 8 - Note-to-action affordance: add or refine a safe UI affordance for turning a note into a task/follow-up using existing behavior or mock/local UI only. Acceptance: npm.cmd run build from app-vNext. [class:feature risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/easynotes/,app-vNext/src/features/easylist/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 8 - Stale/recent memory cue: add one calm recent/stale note cue that helps review without making notes noisy. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/easynotes/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 8 - Notes And Memory review packet: run checks and write docs/codex/PHASE_8_REVIEW.md. Do not start Phase 9. [class:proof risk:low mode:single impact:planning surface:docs scope:docs/codex/,app-vNext/src/ accept:npm.cmd run build]"
        )
    },
    @{
        Number = 9; Key = "phase-9-optional-power-modules"; Name = "Optional Power Modules";
        Showable = "Optional modules are discoverable, useful, and quiet unless pinned or relevant.";
        DoneSignal = "More organizes Money, People, Fun/Drinks, Trips, Projects, Jobs, Future Plans, and Settings without crowding Today.";
        NextCriteria = "Move to Phase 10 Mobile Superpower Pass when optional modules have clear entry points and module toggles/pinning are understandable.";
        ReviewOutcome = "Phase 9 organized optional depth. Phase 10 should make the whole thing excellent on phone.";
        Tasks = @(
            "- [ ] Phase 9 - More hub organization: refine More so optional modules are grouped into calm categories and do not compete with core daily navigation. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/components/navigation/,app-vNext/src/features/settings/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 9 - Future Plans dock: add or refine a quiet Future Plans dock/list using docs-backed ideas as local/mock UI only. Acceptance: npm.cmd run build from app-vNext. [class:feature risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/hq/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 9 - Fun/Drinks entry: add or refine a hidden/optional Fun and drinks entry that feels playful but does not affect the default serious app. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/ accept:npm.cmd run build]",
            "- [ ] Phase 9 - Optional Power Modules review packet: run checks and write docs/codex/PHASE_9_REVIEW.md. Do not start Phase 10. [class:proof risk:low mode:single impact:planning surface:docs scope:docs/codex/,app-vNext/src/ accept:npm.cmd run build]"
        )
    },
    @{
        Number = 10; Key = "phase-10-mobile-superpower-pass"; Name = "Mobile Superpower Pass";
        Showable = "EasyLife is genuinely usable on a phone for Today, capture, calendar, tasks, and approvals.";
        DoneSignal = "Mobile first viewport, nav, capture, Today, calendar/tasks, and approval queues are readable and thumb-friendly.";
        NextCriteria = "Move to Phase 11 Themes when mobile is comfortable and the next work is controlled mood layers.";
        ReviewOutcome = "Phase 10 made EasyLife phone-friendly. Phase 11 should bring back themes as controlled mood layers.";
        Tasks = @(
            "- [ ] Phase 10 - Mobile nav and first viewport: repair mobile shell/Today density so the primary action appears high and tap targets are comfortable. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/ accept:npm.cmd run build]",
            "- [ ] Phase 10 - Mobile fast capture: make capture reachable and non-intrusive on phone. Preserve existing behavior. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/features/experiments/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 10 - Mobile core route scan: make one focused mobile repair to Calendar, Tasks, Notes, or Coach based on obvious cramped controls or first-viewport friction. Acceptance: npm.cmd run build from app-vNext. [class:bugfix risk:medium mode:single impact:visible surface:app scope:app-vNext/src/ accept:npm.cmd run build]",
            "- [ ] Phase 10 - Mobile Superpower review packet: run checks and write docs/codex/PHASE_10_REVIEW.md. Do not start Phase 11. [class:proof risk:low mode:single impact:planning surface:docs scope:docs/codex/,app-vNext/src/ accept:npm.cmd run build]"
        )
    },
    @{
        Number = 11; Key = "phase-11-themes"; Name = "Themes";
        Showable = "Themes feel like controlled moods over one stable EasyLife system.";
        DoneSignal = "Default, Focus, Night, Soft, and Candy directions are represented through tokens or previews without changing navigation/layout behavior.";
        NextCriteria = "Move to Phase 12 QA, Polish, And Park when themes are controlled and accessible.";
        ReviewOutcome = "Phase 11 restored themes as mood layers. Phase 12 should harden, polish, and park.";
        Tasks = @(
            "- [ ] Phase 11 - Theme token guardrails: refine theme tokens so themes change atmosphere, not layout or product hierarchy. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/styles/,app-vNext/src/features/settings/ accept:npm.cmd run build]",
            "- [ ] Phase 11 - Controlled Candy theme: make Candy feel fun but less overwhelming, preserving contrast and readability. Acceptance: npm.cmd run build from app-vNext. [class:design risk:medium mode:single impact:visible surface:app scope:app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 11 - Night/Focus/Soft preview clarity: improve theme selection or preview language so mood choices are understandable without feature clutter. Acceptance: npm.cmd run build from app-vNext. [class:copy risk:low mode:single impact:visible surface:app scope:app-vNext/src/features/settings/,app-vNext/src/styles/ accept:npm.cmd run build]",
            "- [ ] Phase 11 - Themes review packet: run checks and write docs/codex/PHASE_11_REVIEW.md. Do not start Phase 12. [class:proof risk:low mode:single impact:planning surface:docs scope:docs/codex/,app-vNext/src/ accept:npm.cmd run build]"
        )
    },
    @{
        Number = 12; Key = "phase-12-qa-polish-and-park"; Name = "QA Polish And Park";
        Showable = "EasyLife opens cleanly, looks strong, works on phone, and has no obvious broken flows.";
        DoneSignal = "Build, visual QA, accessibility, empty/loading/error states, screenshot review, and final checklist are clean enough for review.";
        NextCriteria = "Park review-ready. Do not generate new work unless Spencer asks.";
        ReviewOutcome = "Phase 12 hardened and parked EasyLife for review.";
        Tasks = @(
            "- [ ] Phase 12 - Build and route proof: run the source-of-truth build and inspect core protected routes for obvious breakage. Fix only blockers. [class:proof risk:low mode:single impact:stability surface:app scope:app-vNext/src/,docs/codex/ accept:npm.cmd run build]",
            "- [ ] Phase 12 - Empty/loading/error polish: make one small finish pass on empty, loading, or error states if an obvious rough edge remains. Acceptance: npm.cmd run build from app-vNext. [class:polish risk:low mode:single impact:visible surface:app scope:app-vNext/src/ accept:npm.cmd run build]",
            "- [ ] Phase 12 - Final mobile/readability check: make one small fix for mobile text fit, tap target, or overlap if found. Acceptance: npm.cmd run build from app-vNext. [class:bugfix risk:low mode:single impact:visible surface:app scope:app-vNext/src/ accept:npm.cmd run build]",
            "- [ ] Phase 12 - Final park packet: write docs/codex/PHASE_12_REVIEW.md with final status, checks, known risks, and review URL/route guidance. Leave repo clean and parked. [class:proof risk:low mode:single impact:planning surface:docs scope:docs/codex/ accept:npm.cmd run build]"
        )
    }
)

Write-Log "Starting EasyLife local phase autopilot interval=${IntervalSeconds}s maxIterations=$MaxIterations"

for ($iteration = 1; $iteration -le $MaxIterations; $iteration++) {
    $block = @(Get-EasyLifeStatusBlock)
    $text = $block -join "`n"
    $unchecked = if ($text -match "Unchecked tasks:\s+(\d+)") { [int]$Matches[1] } else { -1 }
    $hasRunLock = $text -match "Run lock:\s+active"
    $isDirty = $text -match "Working tree:\s+dirty"
    $phaseKey = Get-CurrentPhaseKey

    Write-Log "Iteration $iteration phase=$phaseKey unchecked=$unchecked runLock=$hasRunLock dirty=$isDirty"

    if ($isDirty) {
        Write-Log "DIRTY state detected. Leaving for Codex/user repair."
    } elseif ($unchecked -gt 0 -and -not $hasRunLock) {
        Start-EasyLifeRun
    } elseif ($unchecked -eq 0 -and -not $hasRunLock) {
        $current = $phaseList | Where-Object { $_.Key -eq $phaseKey } | Select-Object -First 1
        if (!$current) {
            Write-Log "No phase map entry for '$phaseKey'. Not transitioning."
        } else {
            $next = $phaseList | Where-Object { $_.Number -eq ($current.Number + 1) } | Select-Object -First 1
            Write-Log "Phase $($current.Number) appears complete. Running transition."
            $buildOk = Invoke-BuildCheck
            if (!$buildOk) {
                Write-Log "Build failed during transition check. Leaving for Codex/user repair."
            } else {
                Write-PhaseReview -Phase $current -NextPhase $next
                if ($next) {
                    Set-PhaseState -Phase $next
                    Write-TaskFiles -Phase $next
                    Commit-Transition -NextPhase $next
                    Start-EasyLifeRun
                } else {
                    Complete-FinalPark
                    Write-Log "Phase 12 complete and parked. Stopping watchdog."
                    break
                }
            }
        }
    }

    Start-Sleep -Seconds $IntervalSeconds
}

Write-Log "EasyLife local phase autopilot finished."
