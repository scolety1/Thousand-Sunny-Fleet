# Codex Fleet

Reusable local harness for running bounded Codex task loops across multiple projects.

## Projects

Configured in `projects.json`:

- EasyLife
- RestaurantDemo
- UrbanKitchenWineList

## Commands

```powershell
cd C:\Dev\codex-fleet

.\add-project.ps1 -Name MyProject -Repo C:\Dev\my-project -Profile frontend-static-demo -BuildDirectory . -BuildCommand "npm.cmd run build"
.\fleet-doctor.ps1
.\launch-proof-run.ps1 -Project RestaurantDemo
.\launch-school-run.ps1
.\launch-overnight-run.ps1 -Project EasyLife
.\fleet-status.ps1
.\fleet-supervisor.ps1 -Once
.\merge-readiness.ps1
.\visual-gallery.ps1
.\tests\run-fleet-tests.ps1
.\recover-interrupted-task.ps1 -Project EasyLife
.\fleet-brief.ps1
.\fleet-morning-review.ps1
.\request-safe-stop.ps1 -Project EasyLife
.\debug-checkpoint.ps1 -Repo C:\Dev\restaurant-automation-demo
.\visual-smoke.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\visual-inspect.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\simon-design-review.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\joey-security-review.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\make-context-bundles.ps1
.\run-fleet.ps1
```

`run-fleet.ps1` starts each project loop in a separate PowerShell window. Keep rounds low until the reports feel boring and predictable.

`request-safe-stop.ps1` is the cooperative stop button. It writes a local stop request under `.codex-local/stop-requests/`; checkpoint loops stop before the next task, batch, or planning step instead of killing in-progress work. Launchers refuse to start while matching safe stop requests are active unless `-AllowSafeStopRequests` is used.

`fleet-doctor.ps1` runs Tony Tony Chopper, the fleet doctor. It checks each ship before launch and writes `out/fleet-doctor.md`. Dirty working trees, missing task queues, missing repos, missing profiles, RED Joey/checkpoint/Simon reports, and missing build directories block launch.

`launch-proof-run.ps1`, `launch-school-run.ps1`, and `launch-overnight-run.ps1` are preset launchers for checkpoint loops. They run Chopper first unless `-SkipDoctor` is passed, then start one PowerShell window per ship. Use `-Project ShipName` to launch only one ship, or `-DryRun` to print the commands without opening windows.

Every launcher writes `out/latest-launch.md` plus raw launch JSON under `.codex-local/launches/`, including each ship command and PowerShell PID.

`recover-interrupted-task.ps1` handles a half-finished task after an interrupted run. By default it does a dry run: changed files, first unchecked task, guardrails, and build. Add `-ConfirmRecovery` only when you want it to mark the task complete, append the report, and commit.

`make-context-bundles.ps1` writes paste-ready ChatGPT Pro context bundles into `out/`.

`fleet-morning-review.ps1` checks each configured project before you merge: branch, dirty state, unchecked tasks, changed files, recent report entries, and build result.

`fleet-supervisor.ps1` writes `out/fleet-supervisor.md` and can stay open as an all-day dashboard. It shows each ship's branch, HEAD, dirty state, remaining tasks, checkpoint verdict, Simon verdict, Joey verdict, and latest report note.

`merge-readiness.ps1` runs Jimbei Harbor Master and writes `out/merge-readiness.md`. It gives each ship one of three answers: `DO NOT MERGE`, `SAFE TO INSPECT`, or `SAFE TO MERGE AFTER HUMAN REVIEW`.

`visual-gallery.ps1` writes `out/visual-gallery.html`, a local screenshot gallery for the latest visual smoke and visual inspection runs across the fleet.

`tests\run-fleet-tests.ps1` runs deterministic fleet tests without touching real ships. It generates disposable fixture repos under `.codex-local/fixtures/`, validates parsing/config/guardrail helpers, and removes fixtures when it finishes unless `-KeepFixtures` is passed.

`debug-checkpoint.ps1` inspects a checkpoint branch for weirdness: dirty tree, forbidden files, suspicious added lines, non-GREEN checkpoint review, task/report issues, and oversized changes. During checkpoint loops, the current batch diff is the hard file-count gate; the whole branch diff is still reported as a warning when it grows large.

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
- stages only the files it intentionally changed instead of using `git add .`
- writes `docs/codex/CHECKPOINT_REVIEW.md` after fresh visual, Simon, and Joey gates
- includes completed task, changed file, latest visual, latest Simon, latest Joey, and next-batch guidance in checkpoint reviews
- runs the checkpoint debugger unless `-SkipDebug` is passed
- optionally runs visual smoke checks with `-VisualEvery N`
- optionally writes visual bug reports with `-VisualInspectEvery N`
- optionally runs Simon design reviews with `-SimonEvery N`
- optionally runs Joey security reviews with `-JoeyEvery N`
- can continue through non-blocking YELLOW checkpoint reviews with `-ContinueOnYellowCheckpoint`
- generates/imports the next five tasks when the queue is empty
- never merges to `main`

Each project can configure `profile`, `model`, role-specific fallback `models`, `timeouts`, and `visualPaths` in `projects.json`. The loop passes role model chains to Codex for implementation, review, planning, checkpoint review, and Simon. If the first model fails without useful work, the fleet retries with backoff and then moves down the configured chain.

If Codex output looks like a usage/rate-limit response, the loop waits for the configured rate-limit cooldown and retries without counting that wait as a normal implementation attempt. Defaults are one-hour cooldowns with caps per ship/profile, so a school-day run can survive a temporary limit reset without sleeping forever.

Long-running steps are wrapped by the fleet watchdog, including Codex implementation/review, external builds, Nami planning, checkpoint review, visual smoke/inspect, Simon, Joey, guardrails, and the checkpoint debugger. Timeouts are configurable per ship or profile; watchdog logs are written under `.codex-logs/`.

`-ContinueOnYellowCheckpoint` is intended for unattended runs. RED reviews, human-stop recommendations, failed builds, blocked files, Joey RED reports, and blocking visual issues still stop the loop. A YELLOW review becomes a warning when the follow-up gates stay clean.

Nami's task planner reads the mission, run policy, checkpoint review, Simon design review, visual bug report, Joey security review, recent commits, completed tasks, and nightly report. Simon/visual/Joey repair orders take priority over fresh feature work.

Nami and the checkpoint reviewer run in read-only Codex mode and fail if they dirty anything outside their report file. The final checkpoint review runs after fresh visual inspection, Simon, and Joey reports so its verdict reflects the latest gates rather than stale reports from a previous batch. Task review responses are parsed for unresolved `P1`/`P2` findings before a task can be marked complete.

When `-PushCheckpoint` is used, projects without an `origin` remote print a warning and keep running. Projects with an `origin` remote still push the checkpoint branch.

For larger sprints, keep `BatchSize` modest and increase `MaxBatches` when a ship needs more work. Profile `maxBatchChangedFiles` controls the hard per-batch debugger limit; `maxChangedFiles` controls the whole-branch warning threshold.

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
