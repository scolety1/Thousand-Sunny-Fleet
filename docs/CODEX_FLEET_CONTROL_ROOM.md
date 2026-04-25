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

Morning review:

```powershell
cd C:\Dev\codex-fleet
.\fleet-morning-review.ps1
```
