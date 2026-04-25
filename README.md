# Codex Fleet

Reusable local harness for running bounded Codex task loops across multiple projects.

## Projects

Configured in `projects.json`:

- EasyLife
- RestaurantDemo

## Commands

```powershell
cd C:\Dev\codex-fleet

.\add-project.ps1 -Name MyProject -Repo C:\Dev\my-project -Profile frontend-static-demo -BuildDirectory . -BuildCommand "npm.cmd run build"
.\fleet-status.ps1
.\fleet-brief.ps1
.\fleet-morning-review.ps1
.\debug-checkpoint.ps1 -Repo C:\Dev\restaurant-automation-demo
.\visual-smoke.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\visual-inspect.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\simon-design-review.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\joey-security-review.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\make-context-bundles.ps1
.\run-fleet.ps1
```

`run-fleet.ps1` starts each project loop in a separate PowerShell window. Keep rounds low until the reports feel boring and predictable.

`make-context-bundles.ps1` writes paste-ready ChatGPT Pro context bundles into `out/`.

`fleet-morning-review.ps1` checks each configured project before you merge: branch, dirty state, unchecked tasks, changed files, recent report entries, and build result.

`debug-checkpoint.ps1` inspects a checkpoint branch for weirdness: dirty tree, forbidden files, suspicious added lines, non-GREEN checkpoint review, task/report issues, and oversized changes.

`visual-smoke.ps1` launches the site, opens Chrome/Edge headless, checks key text/anchors on desktop and mobile, records console issues, and saves screenshots under `.codex-logs/visual-*`.

`visual-inspect.ps1` launches the site, opens desktop and mobile viewports, screenshots the page, and writes `docs/codex/VISUAL_BUGS.md` with suspicious layout issues such as horizontal overflow, clipped text, covered headings, console errors, and small tap targets.

`simon-design-review.ps1` runs Simon, a sharp mission-driven design reviewer, and writes `docs/codex/SIMON_DESIGN_REVIEW.md` with a taste check, mission-fit review, visual problems, and the next five design tasks.

`joey-security-review.ps1` runs Joey Tough Knuckles, a deterministic security guardrail reviewer, and writes `docs/codex/JOEY_SECURITY_REVIEW.md` with blocked file checks, sensitive added-line checks, and a security merge recommendation.

## Mission Checkpoint Loop

Run a mission-driven branch in reviewed batches:

```powershell
.\run-checkpoint-loop.ps1 -Project RestaurantDemo -BatchSize 5 -MaxBatches 2 -VisualEvery 1 -VisualInspectEvery 1 -SimonEvery 1 -JoeyEvery 1 -ContinueOnYellowCheckpoint -PushCheckpoint
```

The checkpoint loop:

- keeps work on a Codex branch
- implements tasks one at a time
- runs external builds
- commits each successful task
- writes `docs/codex/CHECKPOINT_REVIEW.md`
- runs the checkpoint debugger unless `-SkipDebug` is passed
- optionally runs visual smoke checks with `-VisualEvery N`
- optionally writes visual bug reports with `-VisualInspectEvery N`
- optionally runs Simon design reviews with `-SimonEvery N`
- optionally runs Joey security reviews with `-JoeyEvery N`
- can continue through non-blocking YELLOW checkpoint reviews with `-ContinueOnYellowCheckpoint`
- generates/imports the next five tasks when the queue is empty
- never merges to `main`

`-ContinueOnYellowCheckpoint` is intended for unattended runs. RED reviews, human-stop recommendations, failed builds, blocked files, Joey RED reports, and blocking visual issues still stop the loop. A YELLOW review becomes a warning when the follow-up gates stay clean.

Nami's task planner reads the mission, run policy, checkpoint review, Simon design review, visual bug report, Joey security review, recent commits, completed tasks, and nightly report. Simon/visual/Joey repair orders take priority over fresh feature work.

When `-PushCheckpoint` is used, projects without an `origin` remote print a warning and keep running. Projects with an `origin` remote still push the checkpoint branch.

For larger real-product sprints, the checkpoint debugger allows up to 60 changed files before stopping for review. Keep `BatchSize` modest and increase `MaxBatches` when a ship needs more work.

## Reusable Harness

Add a new repo to the fleet:

```powershell
.\add-project.ps1 -Name MyProject -Repo C:\Dev\my-project -Profile frontend-static-demo -BuildDirectory . -BuildCommand "npm.cmd run build"
```

Then prove it with one small task:

```powershell
.\run-checkpoint-loop.ps1 -Project MyProject -BatchSize 1 -MaxBatches 1
```

`add-project.ps1` installs starter `docs/codex` files, registers the project in `projects.json`, adds `.codex-logs/` to the repo's local Git exclude, and validates that the checkpoint loop can find the project.

Install only the base docs/scripts into a repo:

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
