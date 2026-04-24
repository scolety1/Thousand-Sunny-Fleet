# Codex Fleet

Reusable local harness for running bounded Codex task loops across multiple projects.

## Projects

Configured in `projects.json`:

- EasyLife
- RestaurantDemo

## Commands

```powershell
cd C:\Dev\codex-fleet

.\fleet-status.ps1
.\fleet-brief.ps1
.\fleet-morning-review.ps1
.\debug-checkpoint.ps1 -Repo C:\Dev\restaurant-automation-demo
.\make-context-bundles.ps1
.\run-fleet.ps1
```

`run-fleet.ps1` starts each project loop in a separate PowerShell window. Keep rounds low until the reports feel boring and predictable.

`make-context-bundles.ps1` writes paste-ready ChatGPT Pro context bundles into `out/`.

`fleet-morning-review.ps1` checks each configured project before you merge: branch, dirty state, unchecked tasks, changed files, recent report entries, and build result.

`debug-checkpoint.ps1` inspects a checkpoint branch for weirdness: dirty tree, forbidden files, suspicious added lines, non-GREEN checkpoint review, task/report issues, and oversized changes.

## Mission Checkpoint Loop

Run a mission-driven branch in reviewed batches:

```powershell
.\run-checkpoint-loop.ps1 -Project RestaurantDemo -BatchSize 5 -MaxBatches 2 -PushCheckpoint
```

The checkpoint loop:

- keeps work on a Codex branch
- implements tasks one at a time
- runs external builds
- commits each successful task
- writes `docs/codex/CHECKPOINT_REVIEW.md`
- runs the checkpoint debugger unless `-SkipDebug` is passed
- generates/imports the next five tasks when the queue is empty
- never merges to `main`

## Reusable Harness

Install the base docs/scripts into a new repo:

```powershell
.\install-harness.ps1 -Repo C:\Dev\your-project -Profile frontend-static-demo -AddToFleet
```

Generate a next-task request after a run:

```powershell
.\planner\prepare-next-task-request.ps1 -Repo C:\Dev\your-project
```

Ask Codex CLI to propose next tasks:

```powershell
.\planner\run-planner.ps1 -Repo C:\Dev\your-project
```

Validate and import proposed tasks:

```powershell
.\planner\import-next-tasks.ps1 -Repo C:\Dev\your-project -Mode append
```

More detail: [docs/HOW_TO_ADD_PROJECT.md](docs/HOW_TO_ADD_PROJECT.md)
