# Codex Fleet

Reusable local harness for running bounded Codex task loops across multiple projects.

## Projects

Configured in `projects.json`:

- EasyLife
- NinersDynastyWarRoom
- RestaurantDemo
- ShiftPlate
- CursorPets
- UrbanKitchenWineList

## Commands

```powershell
cd C:\Dev\codex-fleet

.\add-project.ps1 -Name MyProject -Repo C:\Dev\my-project -Profile frontend-static-demo -BuildDirectory . -BuildCommand "npm.cmd run build"
.\fleet-doctor.ps1
.\fleet-plan.ps1 -Project EasyLife -Template
.\fleet-plan.ps1 -Project EasyLife -ValidateOnly
.\scaffold-project.ps1 -Repo C:\Dev\my-project -ScaffoldType vite-react -Register
.\migration-review.ps1 -Repo C:\Dev\my-project
.\sensitive-systems-review.ps1 -Repo C:\Dev\my-project
.\runtime-verify.ps1 -Repo C:\Dev\my-project -Template
.\release-readiness.ps1 -Project EasyLife
.\fleet-maintenance.ps1
.\fleet-autopilot-policy.ps1
.\launch-proof-run.ps1 -Project RestaurantDemo
.\launch-school-run.ps1
.\launch-overnight-run.ps1 -Project EasyLife
.\fleet-status.ps1
.\fleet-supervisor.ps1 -Once
.\prepare-magic-run.ps1
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
.\robin-copy-review.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\joey-security-review.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\make-context-bundles.ps1
.\run-fleet.ps1
```

`run-fleet.ps1` starts each project loop in a separate PowerShell window. Keep rounds low until the reports feel boring and predictable.

`request-safe-stop.ps1` is the cooperative stop button. It writes a local stop request under `.codex-local/stop-requests/`; checkpoint loops stop before the next task, batch, or planning step instead of killing in-progress work. Launchers refuse to start while matching safe stop requests are active unless `-AllowSafeStopRequests` is used.

`fleet-doctor.ps1` runs Tony Tony Chopper, the fleet doctor. It checks each ship before launch and writes `out/fleet-doctor.md`. Dirty working trees, missing task queues, missing repos, missing profiles, invalid Phase 0 intake metadata, RED Joey/checkpoint/Simon/Robin reports, and missing build directories block launch.

`fleet-plan.ps1` is the Phase 1 Architect gate. It writes or validates `docs/codex/ARCHITECTURE.md`, `docs/codex/ENGINEERING_PLAN.md`, `docs/codex/RISK_REGISTER.md`, and `docs/codex/ARCHITECTURE_APPROVAL.md`. Use `-Template` for local templates, or run without `-Template` to ask Codex Architect for a planning pack. `-ValidateOnly` passes only when the approval file says `Status: APPROVED`.

`scaffold-project.ps1` is the Phase 2 scaffold and dependency gate. It supports allowlisted scaffolds (`vite-react`, `next-js`, `express-api`, `electron-desktop`, `python-cli`, `library-js`, `test-harness`) and refuses to scaffold until `ARCHITECTURE_APPROVAL.md` says `Status: APPROVED`. Scaffolds with package dependencies write `docs/codex/DEPENDENCY_PROPOSAL.md` and `docs/codex/DEPENDENCY_APPROVAL.md` in DRAFT status for human review.

`migration-review.ps1` is the Phase 4 migration safety gate. Migration tasks require `docs/codex/MIGRATION_PROPOSAL.md` with summary, reversibility, data impact, affected tables/collections, local run evidence, and rollback plan, plus `docs/codex/MIGRATION_APPROVAL.md` with `Status: APPROVED`.

`sensitive-systems-review.ps1` is the Phase 5 auth, payment, secrets, and external-service gate. It scans staged diffs for common secret patterns and validates `EXTERNAL_SERVICES.md`, `AUTH_POLICY.md`/`AUTH_APPROVAL.md`, and `PAYMENT_RISK.md`/`PAYMENT_APPROVAL.md` when those sensitive areas are in play. The checkpoint loop runs this gate before every Fleet commit.

`runtime-verify.ps1` is the Phase 6 runtime verification gate. It reads `docs/codex/RUNTIME_CHECKS.md` and writes `docs/codex/RUNTIME_VERIFICATION.md`. Checks can be `command: ...`, `url: ...`, or `text: file => expected text`. Integration/performance tasks and tasks with `accept:` commands trigger runtime verification during the checkpoint loop.

`release-readiness.ps1` is the Phase 7 release and operations gate. It writes `out/release-readiness.md` with build status, commits, changed files, checkpoint/security/runtime/migration/sensitive-system gates, deployment plan status, post-deploy smoke plan status, rollback plan status, and release approval status. It never deploys.

`fleet-maintenance.ps1` is the Phase 8 autonomous maintenance intake lane. It scans existing local reports for issue intake, bug triage, flaky-test/performance/dependency/debt signals, and writes `out/fleet-maintenance.md` without editing ships. Dirty ships are skipped by default so active work is not inspected; use `-IncludeDirty` only for an approved rescue or review. Use `-Template` to install `MAINTENANCE_QUEUE.md`, `MAINTENANCE_WINDOWS.md`, and `TECH_DEBT.md` when a ship is ready for recurring maintenance.

`fleet-autopilot-policy.ps1` is the Phase 9 limited business autopilot gate. It validates `AUTOPILOT_POLICY.md` and `AUTOPILOT_APPROVAL.md`, requires explicit rules for spending limits, customer-data handling, and escalation, writes an audit log under `.codex-local/audit/`, and never spends money, deploys, emails customers, changes auth/payments, edits legal text, or touches customer data.

`launch-proof-run.ps1`, `launch-school-run.ps1`, and `launch-overnight-run.ps1` are preset launchers for checkpoint loops. They run Chopper first unless `-SkipDoctor` is passed, then start one PowerShell window per ship. Use `-Project ShipName` to launch only one ship, `-ExcludeProject ShipName` to leave a ship docked, or `-DryRun` to print the commands without opening windows.

Every launcher writes `out/latest-launch.md` plus raw launch JSON under `.codex-local/launches/`, including each ship command and PowerShell PID.

`recover-interrupted-task.ps1` handles a half-finished task after an interrupted run. By default it does a dry run: changed files, first unchecked task, guardrails, and build. Add `-ConfirmRecovery` only when you want it to mark the task complete, append the report, and commit.

`make-context-bundles.ps1` writes paste-ready ChatGPT Pro context bundles into `out/`.

`fleet-morning-review.ps1` checks each configured project before you merge: branch, dirty state, unchecked tasks, changed files, recent report entries, and build result.

`fleet-supervisor.ps1` writes `out/fleet-supervisor.md` and `out/fleet-overnight-digest.md`, and can stay open as an all-day watchdog. It classifies each ship as progressing, ready, idle, blocked, looping, or over budget; shows active work pack, Simon improvement score, run lock state, task budgets, and safe recommendations; and gives safe restart guidance without deleting locks or killing active work.

`prepare-magic-run.ps1` is the 12-hour autonomy preflight. It checks clean working trees, active run locks, task supply, `MAGIC_MISSION.md`, `WORK_PACKS.md`, `WORK_PACK_STATUS.md`, and `MAGIC_SCORECARD.md`, then writes `out/magic-run-preflight.md`. Use `-Template` to install starter mission, work-pack, active-pack, and scorecard files in a ship; fill those files before expecting a true long unattended design run. `launch-overnight-run.ps1 -RequireMagicPreflight` runs the preflight in strict mode and refuses departure when blockers or warnings remain.

The longer path is tracked in `docs/TWELVE_HOUR_MAGIC_ROADMAP.md`: product direction, coherent work selection, before/after quality memory, long-run supervision, and larger software-engineering modes.

`merge-readiness.ps1` runs Jimbei Harbor Master and writes `out/merge-readiness.md`. It gives each ship one of three answers: `DO NOT MERGE`, `SAFE TO INSPECT`, or `SAFE TO MERGE AFTER HUMAN REVIEW`.

`visual-gallery.ps1` writes `out/visual-gallery.html`, a local screenshot gallery for the latest visual smoke and visual inspection runs across the fleet.

`tests\run-fleet-tests.ps1` runs deterministic fleet tests without touching real ships. It generates disposable fixture repos under `.codex-local/fixtures/`, validates parsing/config/guardrail helpers, and removes fixtures when it finishes unless `-KeepFixtures` is passed.

`debug-checkpoint.ps1` inspects a checkpoint branch for weirdness: dirty tree, forbidden files, suspicious added lines, non-GREEN checkpoint review, task/report issues, and oversized changes. During checkpoint loops, the current batch diff is the hard file-count gate; the whole branch diff is still reported as a warning when it grows large.

`visual-smoke.ps1` launches the site, opens Chrome/Edge headless, checks key text/anchors on desktop and mobile, records console issues, and saves screenshots under `.codex-logs/visual-*`.

`visual-inspect.ps1` launches the site, opens desktop and mobile viewports, screenshots the page, and writes `docs/codex/VISUAL_BUGS.md` with suspicious layout issues such as horizontal overflow, clipped text, covered headings, console errors, and small tap targets.

`simon-design-review.ps1` runs Simon, a sharp mission-driven design reviewer, and writes `docs/codex/SIMON_DESIGN_REVIEW.md` with a taste check, mission-fit review, visual problems, and the next five design tasks.

`robin-copy-review.ps1` runs Robin, the fleet voice editor, and writes `docs/codex/ROBIN_COPY_REVIEW.md` with mission-fit copy notes, delicate wording risks, rewrite opportunities, voice rules, and the next five copy tasks.

`joey-security-review.ps1` runs Joey Tough Knuckles, a deterministic security guardrail reviewer, and writes `docs/codex/JOEY_SECURITY_REVIEW.md` with blocked file checks, sensitive added-line checks, and a security merge recommendation.

## Mission Checkpoint Loop

Run a mission-driven branch in reviewed batches:

```powershell
.\run-checkpoint-loop.ps1 -Project RestaurantDemo -BatchSize 5 -MaxBatches 2 -VisualEvery 1 -VisualInspectEvery 1 -SimonEvery 1 -RobinEvery 1 -JoeyEvery 1 -ContinueOnYellowCheckpoint -PushCheckpoint
```

The checkpoint loop:

- keeps work on a Codex branch
- implements tasks one at a time
- runs external builds
- commits each successful task
- stages only the files it intentionally changed instead of using `git add .`
- writes `docs/codex/CHECKPOINT_REVIEW.md` after fresh visual, Simon, Robin, and Joey gates
- includes completed task, changed file, latest visual, latest Simon, latest Robin, latest Joey, and next-batch guidance in checkpoint reviews
- runs the checkpoint debugger unless `-SkipDebug` is passed
- optionally runs visual smoke checks with `-VisualEvery N`
- optionally writes visual bug reports with `-VisualInspectEvery N`
- optionally runs Simon design reviews with `-SimonEvery N`
- optionally runs Robin copy reviews with `-RobinEvery N`
- optionally runs Joey security reviews with `-JoeyEvery N`
- can continue through non-blocking YELLOW checkpoint reviews with `-ContinueOnYellowCheckpoint`
- generates/imports the next five tasks when the queue is empty
- refreshes `out/ship-previews.html` and `out/ship-previews.json` when a loop finishes, unless `-SkipShipPreviewRefresh` is passed
- never merges to `main`
- appends `docs/codex/MAGIC_SCORECARD.md` so long runs leave a product-progress memory for the next planner pass

Each project can configure `profile`, Phase 0 `projectType`, `riskTier`, `capabilities`, `model`, role-specific fallback `models`, `timeouts`, and `visualPaths` in `projects.json`. `visualPaths` can include query strings such as `/easylist?visualQa=1` for dev-only visual QA access. The loop passes role model chains to Codex for implementation, review, planning, checkpoint review, Simon, and Robin. If the first model fails without useful work, the fleet retries with backoff and then moves down the configured chain.

If Codex output looks like a usage/rate-limit response, the loop waits for the configured rate-limit cooldown and retries without counting that wait as a normal implementation attempt. Defaults are one-hour cooldowns with caps per ship/profile, so a school-day run can survive a temporary limit reset without sleeping forever.

Long-running steps are wrapped by the fleet watchdog, including Codex implementation/review, external builds, Nami planning, checkpoint review, visual smoke/inspect, Simon, Robin, Joey, guardrails, and the checkpoint debugger. Timeouts are configurable per ship or profile; watchdog logs are written under `.codex-logs/`.

`-ContinueOnYellowCheckpoint` is intended for unattended runs. RED reviews, human-stop recommendations, failed builds, blocked files, Joey RED reports, Robin RED reports, and blocking visual issues still stop the loop. A YELLOW review becomes a warning when the follow-up gates stay clean.

Nami's task planner reads the mission, run policy, checkpoint review, Simon design review, visual bug report, Robin copy review, Joey security review, recent commits, completed tasks, and nightly report. Simon/visual/Robin/Joey repair orders take priority over fresh feature work.

When present, Nami also reads `MAGIC_MISSION.md`, `WORK_PACKS.md`, `WORK_PACK_STATUS.md`, and `MAGIC_SCORECARD.md`. Those files turn overnight planning from isolated polish tasks into coherent work-pack progress: one product direction, one active pack, and a memory of weak or blocked slices to avoid. If `WORK_PACK_STATUS.md` names an active pack, planner output must mention that active pack before the tasks can be imported.

Phase 3 Devil Fruit quality memory adds before/after visual evidence to `MAGIC_SCORECARD.md`, asks Simon for a required `Magic Improvement Score`, and writes `QUALITY_QUARANTINE.md` when Simon says the active pack is flat, regressed, or scoring too weakly to continue unattended. Nami reads that quarantine as a repair order before planning fresh work.

Phase 3 task contracts can be added to task lines when a task needs tighter implementation controls:

```md
- [ ] Add API health smoke test. [class:test risk:medium scope:tests/,src/ accept:npm.cmd test]
```

Supported classes are `feature`, `bugfix`, `refactor`, `test`, `docs`, `design`, `copy`, `backend`, `migration`, `integration`, and `performance`. Supported risks are `low`, `medium`, `high`, and `gated`; `high` and `gated` tasks require an approved Phase 1 architecture plan. `scope:` limits changed files to path prefixes, and `accept:` runs task-specific checks in addition to the normal external build.

Backend and migration task classes are additionally gated. `class:backend` requires approved architecture. `class:migration` requires approved architecture plus the Phase 4 migration proposal and approval gate.

Sensitive tasks are gated too. `class:integration` requires `docs/codex/EXTERNAL_SERVICES.md`; auth-related tasks require approved `AUTH_APPROVAL.md`; payment-related tasks require approved `PAYMENT_APPROVAL.md`. Production credentials and payment activation remain human-controlled.

Phase 8 maintenance is an intake lane, not a repair bot. `fleet-maintenance.ps1` looks at existing Fleet reports and maintenance docs, classifies likely bugs, dependency-review items, performance regressions, flaky-test signals, and technical debt, then leaves the resulting queue for the checkpoint loop and human approval gates.

Phase 9 limited autopilot is policy-first. `fleet-autopilot-policy.ps1` can prepare templates and validate whether a ship has approved safe lanes, zero spending, customer-data rules, escalation rules, and explicit human approval for reputation, money, auth, payments, legal text, mass email, data deletion, and production deploy decisions.

Nami and the checkpoint reviewer run in read-only Codex mode and fail if they dirty anything outside their report file. The final checkpoint review runs after fresh visual inspection, Simon, Robin, and Joey reports so its verdict reflects the latest gates rather than stale reports from a previous batch. Task review responses are parsed for unresolved `P1`/`P2` findings before a task can be marked complete.

When `-PushCheckpoint` is used, projects without an `origin` remote print a warning and keep running. Projects with an `origin` remote still push the checkpoint branch.

For larger sprints, keep `BatchSize` modest and increase `MaxBatches` when a ship needs more work. Profile `maxBatchChangedFiles` controls the hard per-batch debugger limit; `maxChangedFiles` controls the whole-branch warning threshold.

## Reusable Harness

Add a new repo to the fleet:

```powershell
.\add-project.ps1 -Name MyProject -Repo C:\Dev\my-project -Profile frontend-static-demo -BuildDirectory . -BuildCommand "npm.cmd run build"
```

Phase 0 intake metadata is recorded for every ship:

- `projectType`: `marketing-site`, `full-stack-web`, `desktop-app`, `cli-tool`, `library`, `data-pipeline`, `ai-workflow`, `mobile-app`, `game`, `documentation`, or `sandbox-prototype`
- `riskTier`: `sandbox`, `local-only`, `staging`, `production-adjacent`, or `production`
- `capabilities`: explicit permission flags for package files, dependencies, backend code, migrations, auth policy, deployment config, network APIs, pull requests, and deploys

Profiles provide conservative defaults. Use `add-project.ps1 -ProjectType ... -RiskTier ... -Capability ...` only when a ship needs a more specific intake classification.

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
