# Codex Fleet Control Room

Use this file as the project instructions for a dedicated Codex project that manages the fleet itself.

Suggested project name:

```text
Codex Fleet Control Room
```

Alternate name:

```text
Thousand Sunny Fleet Control
```

## Paste Into Codex Project Instructions

```md
# Codex Fleet Control Room

This Codex project manages my local autonomous coding framework called Codex Fleet.

Fleet repo:
C:\Dev\codex-fleet

The fleet is the reusable automation harness.
Each repo added to the fleet is a ship.

Current ships:
- EasyLife: C:\Dev\easylifehq.github.io
- RestaurantDemo: C:\Dev\restaurant-automation-demo
- UrbanKitchenWineList: C:\Dev\urban-kitchen-wine-list

Core rule:
Do not merge, push, deploy, or touch secrets unless explicitly requested.

Fleet responsibilities:
- onboard new ships
- write MISSION.md, TASK_QUEUE.md, and RUN_POLICY.md
- improve run scripts
- debug failed runs
- inspect reports
- improve visual/design/security/checkpoint gates
- keep work small and reviewable
- run deterministic tests after fleet script changes
- commit fleet changes only after tests pass

Ship roles:
- Luffy = human captain and final merge authority
- Nami = task planner
- Simon = design director
- Joey = security guard
- Chopper = ship doctor / readiness checker
- Frankie = debugger / shipwright
- Zoro = watchdog / timeout cutter

Important current behavior:
- Codex implements one selected markdown task at a time.
- PowerShell owns builds, task completion, reports, commits, checkpoint reviews, Simon, Joey, visual inspections, and guardrails.
- Builds run outside Codex.
- Failed tasks can be quarantined with `[!]`.
- Nami reads quarantined task reports and should avoid repeating failed tasks.
- Duplicate ship runs are blocked with per-ship locks.
- Nothing merges automatically.

When editing fleet code:
- Work in C:\Dev\codex-fleet.
- Keep changes small.
- Use PowerShell.
- Prefer existing scripts and patterns.
- Do not touch ship repos unless the task is explicitly ship onboarding or ship debugging.
- Run:
  powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
- Commit only after tests pass.

When onboarding a new ship:
1. Classify the ship profile:
   - real-product
   - frontend-static-demo
   - docs-only
   - experimental-prototype
2. Generate ship docs:
   - docs/codex/MISSION.md
   - docs/codex/TASK_QUEUE.md
   - docs/codex/RUN_POLICY.md
3. Recommend guardrails and blocked paths.
4. Add the ship with add-project.ps1.
5. Run one proof task first.
6. Scale only after boring success.

Never let the fleet:
- merge to main automatically
- push without explicit approval
- deploy
- edit secrets
- edit API keys
- bypass guardrails
- make backend/auth/payment/deployment changes unattended
- run duplicate loops on the same ship
```

## First Message To Send In The Codex Project

```md
We are setting up this Codex project as the control room for Codex Fleet.

Please inspect:

C:\Dev\codex-fleet

Then summarize:
- current fleet capabilities
- current ships
- how to onboard a new ship
- how to run a 1-task proof
- how to safely scale a ship
- what must never happen automatically

Do not edit files yet. Just orient yourself.
```

## Daily Control Room Commands

```powershell
cd C:\Dev\codex-fleet
.\fleet-status.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
```

Proof run:

```powershell
cd C:\Dev\codex-fleet
.\launch-proof-run.ps1 -Project ShipName -QuarantineFailedTasks
```

School run:

```powershell
cd C:\Dev\codex-fleet
.\launch-school-run.ps1 -Project ShipName -BatchSize 2 -MaxBatches 4 -QuarantineFailedTasks -MaxTaskQuarantines 3
```

Budget modes:

```powershell
.\launch-school-run.ps1 -Project ShipName -BudgetMode cheap
.\launch-school-run.ps1 -Project ShipName -BudgetMode balanced
.\launch-school-run.ps1 -Project ShipName -BudgetMode premium
```

- `cheap` is the default for school and Cellar runs. It caps batches lower and spaces out visual, Simon, Robin, and Joey reviews.
- `balanced` uses the ship's configured run shape.
- `premium` keeps reviews frequent for final polish or important demos.

Cheap budget mode also uses cheaper model chains for static/demo ships first:

- Implementation starts with `gpt-5.4-mini`, then tries `gpt-5.3-codex-spark`, then falls back to `gpt-5.4`.
- Planner, checkpoint, Simon, and Robin start with `gpt-5.4-mini`, then fall back to `gpt-5.4`.
- Cheap model ships: Cellar demo ships, RestaurantDemo, Tree, and CursorPets.
- Strong model ships: EasyLife, NinersWarRoom, and ShiftPlate.
- Real-product ships keep their configured model chains unless `cheapModelEligible` is explicitly set for that ship.

Overnight run with a rate budget:

```powershell
cd C:\Dev\codex-fleet
.\launch-overnight-run.ps1 -Project ShipName -MaxRuntimeMinutes 360 -MaxCompletedTasks 6 -MaxPlannerBatches 1 -QuarantineFailedTasks
```

Overnight budget caps:

- `-MaxRuntimeMinutes` stops a ship after the wall-clock budget is used.
- `-MaxCompletedTasks` stops a ship after it finishes that many implementation tasks.
- `-MaxPlannerBatches` limits how many times an overnight run can generate fresh tasks after the queue is empty.
- Pass `0` for any cap only when intentionally disabling that cap.
- Overnight also accepts `-BudgetMode cheap|balanced|premium`; default is `balanced`.

## Phase loops

The fleet can now plan inside a website/software phase instead of using one generic task brain:

```powershell
.\fleet-phase.ps1 -Project ShipName -Init -Phase shape -ProductPromise "This demo helps a GM turn scattered shift notes into one server-ready brief."
.\launch-school-run.ps1 -Project ShipName -LoopPhase shape
.\launch-cellar-fleet.ps1 -LoopPhase simplicity -BudgetMode cheap
```

Phase order:

```text
brief -> foundation -> shape -> simplicity -> polish -> proof -> parked
```

- `repair`: interrupt lane for RED review gates, build/runtime failures, quarantined tasks, stale/idle lock problems, security stops, and blocking visual bugs. It is not a normal destination; after the blocker clears, return to the prior product phase.
- `brief`: define audience, promise, primary action, showable moment, and what not to build.
- `foundation`: add missing routes/components/data/core behavior.
- `shape`: clarify product structure and primary flow; avoid feature sprawl.
- `simplicity`: remove, combine, shorten, hide, or demote before adding.
- `polish`: refine type, spacing, color, hierarchy, button rhythm, and final wording.
- `proof`: fix blockers only.
- `parked`: review-ready; do not continue unattended.

Repair runs should be tiny and gate-driven: one blocker, one bounded scope, one acceptance command, no fresh features, and `No More Features Lock: true`.

Supervisor repair automation now treats repair as a phase handoff, not just a queued task. When auto-repair is enabled it records the `Repair Trigger`, stores the previous `Repair Return Phase`, switches the ship into `repair`, and limits repeated repair attempts. Once the blocker is clear, the supervisor returns the ship to its previous phase and clears the repair fields.

The supervisor report includes each ship's current phase, repair attempt count, and any skipped repair attempts so overnight loops stop spending effort on the same blocker after the repair cap is reached.

Each ship may carry `docs/codex/PHASE_STATE.md` with the current phase, product promise, and human taste note. `-LoopPhase auto` reads that file; explicit `-LoopPhase simplicity` overrides it for the run.

`PHASE_STATE.md` carries the eight first-class website-quality controls:

- `Parking State`: `ACTIVE` or `PARKED_REVIEW_READY`.
- `No More Features Lock`: blocks feature-addition tasks after Foundation.
- `Before/After Judgment`: how the next change must improve the product.
- `Product Promise`: one sentence the planner must serve.
- `Complexity Budget`: limits sections, CTAs, choices, and visible copy.
- `Showable Moment`: the demo moment the buyer should understand fast.
- `Human Taste Note`: your override, such as `too much`, `too plain`, `wrong direction`, `almost there`, or `park it`.
- `Phase Model Policy`: `budget`, `balanced`, or `judgment-heavy`.

It also carries operational fields that keep the loop from drifting:

- `Audience`: the exact buyer or user the ship is serving.
- `Evidence Required`: what proof each task should leave behind.
- `Done Signal`: the practical condition for stopping instead of looping forever.
- `Next Phase Criteria`: when the ship may advance to the next loop.
- `Repair Trigger`: the exact RED gate, failed check, quarantine, stale/idle lock, or visual blocker that interrupted normal progress.
- `Repair Return Phase`: the prior non-repair phase to resume after the blocker clears.

Validate a ship phase file before long runs:

```powershell
.\fleet-phase.ps1 -Project Bottlelight -Validate
```

Audit all selected ships before deciding what can run:

```powershell
.\fleet-phase-audit.ps1
.\fleet-phase-audit.ps1 -Project RestaurantDemo -Strict
```

Require that validation before a serious launch:

```powershell
.\launch-overnight-run.ps1 -Project RestaurantDemo -RequirePhaseValidation
.\launch-cellar-fleet.ps1 -Mode school -RequirePhaseValidation
.\launch-cellar-fleet.ps1 -FleetGroup NewCellarFleet -Mode school -RequirePhaseValidation
```

When `-BudgetMode cheap` is used, implementation can still start on cheaper models for eligible demo ships, but Shape/Simplicity/Polish planning and taste-review roles use stronger judgment models. A ship can also set `Phase Model Policy: judgment-heavy` to force stronger planner, Simon, and Robin judgment during a cheap run, or `budget` to keep the whole cheap-eligible loop low-cost.

Morning review:

```powershell
cd C:\Dev\codex-fleet
.\fleet-morning-review.ps1
```

Safe stop requests:

```powershell
cd C:\Dev\codex-fleet
.\request-safe-stop.ps1 -Project EasyLife
.\request-safe-stop.ps1 -All
.\request-safe-stop.ps1 -List
.\request-safe-stop.ps1 -Project EasyLife -Clear
```

Safe stop is cooperative. It does not kill Codex, builds, or reviews mid-action; it stops the ship before the next task, batch, or planning step starts.

Launch control:

- Proof, school, overnight, and legacy fleet launchers refuse to start if matching safe stop requests are still active.
- Use `-AllowSafeStopRequests` only when intentionally testing immediate stop behavior.
- Launchers write `out/latest-launch.md` and raw JSON under `.codex-local/launches/` with ship commands and PowerShell PIDs.
- `fleet-status.ps1` shows active safe stop requests, latest launch report, and per-ship run locks.
