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
.\software-feature-mode.ps1 -Repo C:\Dev\my-project -Template
.\release-readiness.ps1 -Project EasyLife
.\fleet-maintenance.ps1
.\fleet-autopilot-policy.ps1
.\launch-proof-run.ps1 -Project RestaurantDemo
.\launch-school-run.ps1
.\launch-overnight-run.ps1 -Project EasyLife
.\fleet-status.ps1
.\fleet-product-dashboard.ps1
.\fleet-kill-switch.ps1 -Project EasyLife
.\fleet-backfill-product-docs.ps1 -Project EasyLife
.\harbor-master.ps1
.\fleet-supervisor.ps1 -Once
.\prepare-magic-run.ps1
.\test-fleet-harness.ps1
.\scheduled-selected-overnight-run.ps1 -DryRun
.\fleet-night-report.ps1 -SinceHours 24
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
.\performance-review.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\joey-security-review.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
.\make-context-bundles.ps1
.\run-fleet.ps1
```

`run-fleet.ps1` starts each project loop in a separate PowerShell window. Keep rounds low until the reports feel boring and predictable.

`request-safe-stop.ps1` is the cooperative stop button. It writes a local stop request under `.codex-local/stop-requests/`; checkpoint loops stop before the next task, batch, or planning step instead of killing in-progress work. Launchers refuse to start while matching safe stop requests are active unless `-AllowSafeStopRequests` is used.

`fleet-doctor.ps1` runs Tony Tony Chopper, the fleet doctor. It checks each ship before launch and writes `out/fleet-doctor.md`. Dirty working trees, missing task queues, missing repos, missing profiles, invalid Phase 0 intake metadata, RED Joey/checkpoint/Simon/Robin reports, and missing build directories block launch.

`harbor-master.ps1` writes `out/harbor-master.md` and `out/harbor-master.json`. It is the quick truth board for the fleet: each ship gets a state plus a failure class such as `working`, `running-clean-stage`, `idle-shell-finished`, `stale-lock`, `build-or-acceptance-failed`, `task-quarantined`, `policy-or-scope-blocked`, `review-blocked`, or `dirty-without-run`. Use it when a ship "went down" before deciding whether to relaunch, repair, or leave active work alone.

`fleet-product-dashboard.ps1` writes `out/fleet-product-dashboard.md` and `out/fleet-product-dashboard.html`. It is the product usefulness board: admission decision, admission score, usefulness decision, launch gate state, phase, unchecked tasks, visual findings, dirty/lock state, and recommended next action for each ship. Use it before deciding whether to run, park, repair, or backfill admission docs.

`fleet-kill-switch.ps1` writes `out/kill-switches/ShipName.md`. It detects ships that should stop consuming unattended runtime because usefulness is parked/needs direction, launch gates are blocked, quality quarantine is repeating, or Simon scorecard signals are repeatedly flat/regressed. Checkpoint loops run it in `warn` mode by default; use `-KillSwitchMode enforce` only after admission/usefulness docs are backfilled and trusted.

`fleet-backfill-product-docs.ps1` previews or creates the first-class product docs used by the admission, usefulness, launch-gate, dashboard, and kill-switch flow. By default it only writes `out/product-doc-backfill.md`; add `-Apply` to create missing `USER_JOB.md`, `EVALUATORS.md`, `SHIP_SCORECARD.md`, `SHIP_ADMISSION.md`, and `PRODUCT_USEFULNESS.md` in selected ship repos. It keeps existing files unless `-Force` is passed.

`fleet-plan.ps1` is the Phase 1 Architect gate. It writes or validates `docs/codex/ARCHITECTURE.md`, `docs/codex/ENGINEERING_PLAN.md`, `docs/codex/RISK_REGISTER.md`, and `docs/codex/ARCHITECTURE_APPROVAL.md`. Use `-Template` for local templates, or run without `-Template` to ask Codex Architect for a planning pack. `-ValidateOnly` passes only when the approval file says `Status: APPROVED`.

`scaffold-project.ps1` is the Phase 2 scaffold and dependency gate. It supports allowlisted scaffolds (`vite-react`, `next-js`, `express-api`, `electron-desktop`, `python-cli`, `library-js`, `test-harness`) and refuses to scaffold until `ARCHITECTURE_APPROVAL.md` says `Status: APPROVED`. Scaffolds with package dependencies write `docs/codex/DEPENDENCY_PROPOSAL.md` and `docs/codex/DEPENDENCY_APPROVAL.md` in DRAFT status for human review.

`migration-review.ps1` is the Phase 4 migration safety gate. Migration tasks require `docs/codex/MIGRATION_PROPOSAL.md` with summary, environment, reversibility, forward-only justification, data impact, data-loss detection, affected tables/collections, local run evidence, and rollback plan, plus `docs/codex/MIGRATION_APPROVAL.md` with `Status: APPROVED`. Production migrations additionally require `Human Approval: APPROVED`.

`api-contract-review.ps1` and `seed-fixture-review.ps1` are the Phase 4 backend/data safety gates. Backend and integration tasks require approved `API_CONTRACT.md` plus `API_CONTRACT_TESTS.md`; backend and migration tasks require approved `SEED_FIXTURE_PLAN.md` plus `SEED_FIXTURE_EVIDENCE.md`. Use the `backend-local` or `backend-staging` profile only when the ship has approved architecture and real local evaluators.

`sensitive-systems-review.ps1` is the Phase 5 auth, payment, secrets, deployment-config, env-var, and external-service gate. It scans staged diffs for common secret patterns and validates `EXTERNAL_SERVICES.md`, `AUTH_POLICY.md`/`AUTH_APPROVAL.md`, `PAYMENT_RISK.md`/`PAYMENT_APPROVAL.md`, and `DEPLOYMENT_RISK.md`/`DEPLOYMENT_APPROVAL.md` when those sensitive areas are in play. Use `.\sensitive-systems-review.ps1 -Repo C:\Dev\my-project -Template` to scaffold the approval docs. The checkpoint loop runs this gate before every Fleet commit.

`runtime-verify.ps1` is the Phase 6 runtime verification gate. It reads `docs/codex/RUNTIME_CHECKS.md` and writes `docs/codex/RUNTIME_VERIFICATION.md`. Checks can be `command: ...`, `url: ...`, `url-text: URL => expected text`, `text: file => expected text`, or `file: path/to/file`. Command checks are timeout-bounded and run from the target repo; URL checks require a 2xx/3xx response; reports include check details and durations. Integration/performance tasks and tasks with `accept:` commands trigger runtime verification during the checkpoint loop.

`software-feature-mode.ps1` is the Devil Fruit Phase 5 gate for sophisticated software work. It prepares or validates `SOFTWARE_FEATURE_PLAN.md`, `SOFTWARE_FEATURE_APPROVAL.md`, `RUNTIME_CHECKS.md`, and optional dependency proposal/approval docs. Checkpoint tasks using `mode:feature-pack` require approved architecture, approved feature plan, explicit `scope:`, explicit `accept:`, runtime scenarios, and dependency approval plus enabled package/dependency capabilities before package files may change.

`release-readiness.ps1` is the Phase 7 release and operations gate. It writes `out/release-readiness.md` plus machine-readable JSON with build status, commits, changed files, checkpoint/security/runtime/visual/migration/sensitive-system gates, deployment plan status, post-deploy smoke plan status, rollback plan status, and release approval status. Use `-Template` to create release templates for `DEPLOYMENT_PLAN.md`, `POST_DEPLOY_SMOKE.md`, `ROLLBACK_PLAN.md`, and `RELEASE_APPROVAL.md`; use `-TreatWarningsAsBlockers` when a release review should fail closed instead of entering human-review state. It never deploys.

`fleet-maintenance.ps1` is the Phase 8 autonomous maintenance intake lane. It scans existing local reports for issue intake, bug triage, flaky-test/performance/dependency/debt signals, and writes `out/fleet-maintenance.md` plus `out/fleet-maintenance.json`. Long reports are tail-scanned by default with `-TailLines` so stale failures do not drown out current work, and repeated signals are de-duplicated. Dirty ships are skipped by default so active work is not inspected; use `-IncludeDirty` only for an approved rescue or review. Use `-Template` to install `MAINTENANCE_QUEUE.md`, `MAINTENANCE_WINDOWS.md`, and `TECH_DEBT.md` when a ship is ready for recurring maintenance. By default it is report-only; pass `-QueueTasks -MaxQueueItems 3` to append bounded low-risk maintenance tasks into configured ship queues.

`fleet-autopilot-policy.ps1` is the Phase 9 limited business autopilot gate. It validates `AUTOPILOT_POLICY.md` and `AUTOPILOT_APPROVAL.md`, requires explicit rules for spending limits, customer-data handling, escalation, and concrete safe automatic lanes, writes a Markdown report, JSON report, and audit log under `.codex-local/audit/`, fails closed on dirty ships unless `-IncludeDirty` is explicitly passed, and never spends money, deploys, emails customers, changes auth/payments, edits legal text, or touches customer data. Approved autopilot lanes must be listed in the policy safe-lane section and must not contain human-approval-only actions.

`franky-formula-review.ps1` is the Phase 10 specialist reviewer layer for analytical and formula-heavy ships. Franky is deterministic and checks `FORMULA_SPEC.md`, `FIXTURE_TEST_PLAN.md`, formula-oriented tests, analytical number provenance, and calibration visibility before formula work can pretend to be insight. The checkpoint loop can run it with `-FrankyEvery 1`, and analytical phases auto-run it before the final checkpoint.

`accessibility-review.ps1` is the Phase 11 accessibility reviewer layer for websites and app surfaces. Ada is deterministic and checks missing image alt text, unlabeled inputs, empty or icon-only buttons, dead hash links, vague link text, and removed focus outlines. The checkpoint loop can run it with `-AccessibilityEvery 1`; proof/school/overnight launchers forward accessibility cadence so accessibility can be part of normal polish without needing a browser model call.

`performance-review.ps1` is the Phase 12 performance reviewer layer for websites and app surfaces. Percy is deterministic and checks oversized build artifacts, missing build artifacts when a build script exists, large inline base64 assets, transition-all CSS, blur/filter usage, very short polling intervals, broad will-change usage, and eager autoplay video. The checkpoint loop can run it with `-PerformanceEvery 1`; proof/school/overnight launchers forward performance cadence so obvious page-weight and runtime-cost issues get caught before final checkpoint review.

`fleet-experiment.ps1` is the Phase 13 experiment runner and parallel metrics lane. It reads an experiment manifest, validates the selected ships, refuses dirty selected repos unless explicitly allowed, and writes Markdown plus JSON evidence with serial baseline, parallel wall-clock, speedup, efficiency, load imbalance, retry overhead, reviewer cadence, and exact checkpoint commands. Use `-Template` to create a starter manifest, `-DryRun` to generate evidence without opening terminals, and `-SkipDoctor` only for disposable fixtures or controlled tests:

```powershell
.\fleet-experiment.ps1 -Template -ManifestPath .\experiments\three-ship-smoke.json
.\fleet-experiment.ps1 -ManifestPath .\experiments\three-ship-smoke.json -DryRun
```

`launch-proof-run.ps1`, `launch-school-run.ps1`, and `launch-overnight-run.ps1` are preset launchers for checkpoint loops. They run Chopper first unless `-SkipDoctor` is passed, then start one PowerShell window per ship. Use `-Project ShipName` to launch only one ship, `-ExcludeProject ShipName` to leave a ship docked, or `-DryRun` to print the commands without opening windows. Proof runs include visual inspection, Simon, Robin, accessibility, performance, Joey, checkpoint review, and the checkpoint debugger by default; pass `-RobinEvery 0` only when intentionally skipping copy review for a non-copy technical probe.

Trial overnight launches start ships back-to-back by default. Pass `-LaunchDelaySeconds 90` only when you explicitly want spaced departures.

Every launcher writes `out/latest-launch.md` plus raw launch JSON under `.codex-local/launches/`, including each ship command and PowerShell PID.

`recover-interrupted-task.ps1` handles a half-finished task after an interrupted run. By default it does a dry run: changed files, first unchecked task, guardrails, and build. Add `-ConfirmRecovery` only when you want it to mark the task complete, append the report, and commit.

`make-context-bundles.ps1` writes paste-ready ChatGPT Pro context bundles into `out/`.

`fleet-morning-review.ps1` checks each configured project before you merge: branch, dirty state, unchecked tasks, changed files, recent report entries, and build result.

`fleet-supervisor.ps1` writes `out/fleet-supervisor.md` and `out/fleet-overnight-digest.md`, and can stay open as an all-day watchdog. It classifies each ship as progressing, ready, idle, blocked, looping, or over budget; shows active work pack, Simon improvement score, run lock state, task budgets, and safe recommendations; and gives safe restart guidance without deleting locks or killing active work. Add `-AutoSafeStop` during unattended runs to create safe-stop requests for over-budget, looping-quality, idle-running, or blocked-review ships so they pause at the next task boundary instead of churning overnight.

Add `-AutoRepair` when you want the supervisor to queue one high-priority repair task for clean, stopped ships in `BUDGET_STOP`, `LOOPING_QUALITY`, or `IDLE_READY`. It prepends a small bounded task to `docs/codex/TASK_QUEUE.md`, records the action in `docs/codex/AUTO_REPAIR.md`, commits the repair task on that ship branch, and skips active or dirty ships. Add `-ClearSafeStopAfterRepair` only when you want that ship eligible for the next launcher run immediately after the repair task is queued.

Add `-AutoRelaunchRepair` to let the supervisor clear that ship's safe-stop request and open a one-batch repair run for clean, unlocked ships that already have an unchecked auto-repair task. Repair relaunches default to `-BatchSize 1 -MaxBatches 1` so the ship repairs, re-scores, and returns control to the supervisor instead of sprinting blindly.

`start-overnight-autopilot.ps1` is the single-command overnight wrapper. It runs supervisor cycles with auto safe-stops, auto repair task queueing, and one-batch repair relaunches; it excludes `NinersDynastyWarRoom` by default and writes `out/overnight-autopilot.md`. Add `-LaunchFirst` when you also want it to call `launch-overnight-run.ps1` before supervising; use `-Once` or `-DryRun` for trials. It forwards the important launch controls (`-BudgetMode`, `-LoopPhase`, `-ExpectedProject`, `-RequirePhaseValidation`, `-LaunchGateMode`, `-KillSwitchMode`, and visual/Simon/Robin/Joey cadence) so selected overnight runs can fail closed and stay in the intended phase. Each supervisor step is bounded by `-StepTimeoutSeconds` and writes stdout/stderr under `out/autopilot-runs/`.

`scheduled-selected-overnight-run.ps1` is the safer selected-fleet departure wrapper. It accepts comma-separated or array-style `-Project` values, saves report-only dirty files before launch, runs `test-fleet-harness.ps1` before clearing safe-stop, computes exclusions dynamically from `projects.json`, and calls `launch-overnight-run.ps1` with `-ExpectedProject` so selected launches fail closed if the wrong ships would depart. Use `-DryRun` before scheduling or manual launch. For a cautious proof run, use `.\scheduled-selected-overnight-run.ps1 -RunLabel proof -BatchSize 1 -MaxBatches 1 -VisualInspectEvery 1 -SimonEvery 1 -RobinEvery 1 -JoeyEvery 1 -MaxTaskQuarantines 2`.

`test-fleet-harness.ps1` is the deterministic control-room self-test. It parses core scripts, verifies selected launch inclusion/exclusion, checks that launch validation rejects unexpected ships, verifies dry-runs write `out/latest-proof-launch.md` without overwriting the real `out/latest-launch.md`, verifies night-report dry-run filtering, and validates the selected checkpoint-loop configs unless `-SkipProjectValidation` is passed. It writes `out/fleet-harness-test.md`.

`fleet-night-report.ps1` is the morning debrief. It reads scheduled run logs, launch state, ship locks, dirty status, task counts, and latest nightly outcomes, then writes `out/fleet-night-report.md` and `out/fleet-night-report.json` with successes, skips, failures, and next actions. Add `-IgnoreDryRuns` when you want a real overnight report without dry-run, proof-run, harness, or check-run noise.

`prepare-magic-run.ps1` is the 12-hour autonomy preflight. It checks clean working trees, active run locks, task supply, `MAGIC_MISSION.md`, `WORK_PACKS.md`, `WORK_PACK_STATUS.md`, and `MAGIC_SCORECARD.md`, then writes `out/magic-run-preflight.md`. Use `-Template` to install starter mission, work-pack, active-pack, and scorecard files in a ship; fill those files before expecting a true long unattended design run. `launch-overnight-run.ps1 -RequireMagicPreflight` runs the preflight in strict mode and refuses departure when blockers or warnings remain.

The longer path is tracked in `docs/TWELVE_HOUR_MAGIC_ROADMAP.md`: product direction, coherent work selection, before/after quality memory, long-run supervision, and larger software-engineering modes.

`merge-readiness.ps1` runs Jimbei Harbor Master and writes `out/merge-readiness.md`. It gives each ship one of three answers: `DO NOT MERGE`, `SAFE TO INSPECT`, or `SAFE TO MERGE AFTER HUMAN REVIEW`.

`visual-gallery.ps1` writes `out/visual-gallery.html`, a local screenshot gallery for the latest visual smoke and visual inspection runs across the fleet.

`fleet-visual-check.ps1` is the direct visual QA lane. It reads `projects.json`, launches selected ships, runs `visual-inspect.ps1` against their configured routes, writes screenshots and visual reports into `.codex-logs`, and summarizes the fleet in `out/fleet-visual-check.md`. Use it when you want screenshots without starting a full checkpoint mission:

```powershell
.\fleet-visual-check.ps1 -Project EasyLife,RestaurantDemo -RefreshGallery
```

By default this direct check does not dirty ship working trees with `docs/codex/VISUAL_BUGS.md`; add `-WriteShipReports` when you intentionally want the ship-local report updated. Add `-VerboseRunner` if you want the full raw browser JSON in the terminal.

Medium/low visual findings are reported as `WARN` with grouped top findings in `out/fleet-visual-check.md`; only high findings or infrastructure failures block the command unless you explicitly tolerate high findings with `-NoFailOnFindings`.

`tests\run-fleet-tests.ps1` runs deterministic fleet tests without touching real ships. It generates disposable fixture repos under `.codex-local/fixtures/`, validates parsing/config/guardrail helpers, and removes fixtures when it finishes unless `-KeepFixtures` is passed.

`debug-checkpoint.ps1` inspects a checkpoint branch for weirdness: dirty tree, forbidden files, suspicious added lines, non-GREEN checkpoint review, task/report issues, and oversized changes. During checkpoint loops, the current batch diff is the hard file-count gate; the whole branch diff is still reported as a warning when it grows large.

`merge-readiness.ps1` also reads the latest Batch QA entry in `MAGIC_SCORECARD.md`. Missing Batch QA memory becomes an inspection warning, Batch QA memory with newer commits after it is marked stale, and RED batch QA verdicts or failed debug results block merge readiness.

`visual-smoke.ps1` launches the site, opens Chrome/Edge headless, checks key text/anchors on desktop and mobile, records console issues, and saves screenshots under `.codex-logs/visual-*`.

`visual-inspect.ps1` launches the site, opens desktop and mobile viewports, screenshots the page, and writes `docs/codex/VISUAL_BUGS.md` with suspicious layout issues such as horizontal overflow, clipped text, covered headings, console errors, and small tap targets.

Ships can optionally provide `docs/codex/visual-routes.json` or `.codex/visual-routes.json` to override the simple `visualPaths` list with named routes, route-specific required text, wait time, and custom viewports. Use `templates/visual-routes.json` as the starter.

Projects whose build/static-check root differs from their preview root can set `visualServeDirectory` in `projects.json`. This keeps normal builds pointed at `buildDirectory` while screenshots serve the correct HTML/app folder.

`set-ship-pages.ps1` makes real page work reusable across ships. It updates the selected ship's `visualPaths`, can install a starter `docs/codex/SITE_MAP.md`, and writes `docs/codex/visual-routes.json` so the next visual QA run inspects every declared page:

```powershell
.\set-ship-pages.ps1 -Project RestaurantDemo -Path /,/wine-list,/operations,/events,/contact -InstallSiteMap
```

The checkpoint loop and Nami planner read `SITE_MAP.md` and `visual-routes.json`. If a task asks for page splits, route repair, navigation cleanup, or real pages, Codex is allowed to make frontend-only route changes inside the task scope and should update those route docs. Package/dependency edits still require explicit approval.

`simon-design-review.ps1` runs Simon, a sharp mission-driven design reviewer, and writes `docs/codex/SIMON_DESIGN_REVIEW.md` with a taste check, mission-fit review, visual problems, and the next five design tasks.

`robin-copy-review.ps1` runs Robin, the fleet voice editor, and writes `docs/codex/ROBIN_COPY_REVIEW.md` with mission-fit copy notes, delicate wording risks, rewrite opportunities, voice rules, and the next five copy tasks. Before asking Robin, the wrapper now adds deterministic public-copy smoke hits for likely scaffolding terms such as `demo`, `sample`, `proof`, `artifact`, `workflow`, `automation`, and vague phrases like `service notes`, while telling Robin to ignore harmless component names and internal identifiers.

`fleet-copy-smoke.ps1` is the no-model version of that early warning check. It scans public source/content files for vague customer-facing wording such as `ready for service`, `manager-ready`, `workflow`, `polish`, `handoff`, and `start with`, plus likely double-header route structures, then writes `docs/codex/COPY_SMOKE.md`:

```powershell
.\fleet-copy-smoke.ps1 -Repo C:\Dev\restaurant-automation-demo -Project RestaurantDemo
```

Use `-FailOnHigh` when you want high-risk copy smoke findings to return a nonzero exit code. This is intended as a cheap preflight before spending Robin/Simon review calls.

`joey-security-review.ps1` runs Joey Tough Knuckles, a deterministic security guardrail reviewer, and writes `docs/codex/JOEY_SECURITY_REVIEW.md` with blocked file checks, sensitive added-line checks, and a security merge recommendation.

## Mission Checkpoint Loop

Run a mission-driven branch in reviewed batches:

```powershell
.\run-checkpoint-loop.ps1 -Project RestaurantDemo -BatchSize 5 -MaxBatches 2 -VisualEvery 1 -VisualInspectEvery 1 -SimonEvery 1 -RobinEvery 1 -AccessibilityEvery 1 -PerformanceEvery 1 -JoeyEvery 1 -ContinueOnYellowCheckpoint -PushCheckpoint
```

The checkpoint loop:

- keeps work on a Codex branch
- implements tasks one at a time
- runs external builds
- commits each successful task
- stages only the files it intentionally changed instead of using `git add .`
- writes `docs/codex/CHECKPOINT_REVIEW.md` after fresh visual, Simon, Robin, accessibility, performance, and Joey gates
- includes completed task, changed file, latest visual, latest Simon, latest Robin, latest accessibility, latest performance, latest Joey, and next-batch guidance in checkpoint reviews
- runs the checkpoint debugger unless `-SkipDebug` is passed
- optionally runs visual smoke checks with `-VisualEvery N`
- optionally writes visual bug reports with `-VisualInspectEvery N`
- optionally runs Simon design reviews with `-SimonEvery N`
- optionally runs Robin copy reviews with `-RobinEvery N`
- optionally runs accessibility reviews with `-AccessibilityEvery N`
- optionally runs performance reviews with `-PerformanceEvery N`
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

Nami's task planner reads the mission, run policy, checkpoint review, Simon design review, visual bug report, Robin copy review, accessibility review, performance review, Joey security review, recent commits, completed tasks, and nightly report. Simon/visual/Robin/accessibility/performance/Joey repair orders take priority over fresh feature work.

When present, Nami also reads `MAGIC_MISSION.md`, `WORK_PACKS.md`, `WORK_PACK_STATUS.md`, and `MAGIC_SCORECARD.md`. Those files turn overnight planning from isolated polish tasks into coherent work-pack progress: one product direction, one active pack, and a memory of weak or blocked slices to avoid. If `WORK_PACK_STATUS.md` names an active pack, planner output must mention that active pack before the tasks can be imported.

Phase 3 Devil Fruit quality memory adds before/after visual evidence to `MAGIC_SCORECARD.md`, asks Simon for a required `Magic Improvement Score`, and writes `QUALITY_QUARANTINE.md` when Simon says the active pack is flat, regressed, or scoring too weakly to continue unattended. After the final visual, Simon, Robin, Joey, checkpoint, and debug gates pass, the loop also appends a fresh batch QA scorecard entry with latest visual evidence, review verdicts, Simon score, impact mode, and debug result. Nami reads that scorecard/quarantine memory before planning fresh work.

Phase 3 task contracts can be added to task lines when a task needs tighter implementation controls:

```md
- [ ] Add API health smoke test. [class:test risk:medium scope:tests/,src/ accept:npm.cmd test]
- [ ] Build Pack 1 - Product Spine settings workflow slice. [class:feature risk:high mode:feature-pack scope:app-vNext/src/,docs/codex/ accept:npm.cmd run build,npm.cmd test]
```

Supported classes are `feature`, `bugfix`, `refactor`, `test`, `docs`, `design`, `copy`, `backend`, `migration`, `integration`, and `performance`. Supported risks are `low`, `medium`, `high`, and `gated`; `high` and `gated` tasks require an approved Phase 1 architecture plan. Supported modes are `single` and `feature-pack`; `feature-pack` requires approved software feature docs, explicit scope, acceptance commands, and runtime scenarios. Supported impacts are `standard`, `visible`, and `showpiece`; visible/showpiece tasks must change actual product source, route, component, content, or style files enough for a user-noticeable result. `scope:` limits changed files to path prefixes, and `accept:` runs task-specific checks in addition to the normal external build.

When `accept:` is omitted, Phase 3 uses inferred acceptance checks only from commands the repo already advertises: package `test`, `lint`, `typecheck`/`tsc` scripts, Python `pytest` when tests/project files exist, and Python `ruff` when configured. Larger Phase 3 work is plan-first: broad, high-risk, gated, or feature-pack tasks must have explicit `scope:` and a concrete `docs/codex/SOFTWARE_FEATURE_PLAN.md` slice plan before implementation.

The visible-impact guard is for high-expectation design passes. If Nami or the task marks `impact:visible` or `impact:showpiece`, the checkpoint loop asks Codex to state the visible user impact, rejects report-only/doc-only work, and quarantines showpiece tasks that look like tiny CSS polish instead of real product progress. This is meant to catch "the build passed but I can barely see what changed" before the task is marked done.

Backend and migration task classes are additionally gated. `class:backend` requires approved architecture, enabled `canEditBackendCode`, approved API contract tests, and approved seed fixture evidence. `class:migration` requires approved architecture, enabled `canEditMigrations`, approved seed fixture evidence, plus the Phase 4 migration proposal and approval gate.

Sensitive tasks are gated too. `class:integration` requires `docs/codex/EXTERNAL_SERVICES.md`; auth-related tasks require approved `AUTH_APPROVAL.md`; payment-related tasks require approved `PAYMENT_APPROVAL.md`. Production credentials and payment activation remain human-controlled.

Phase 8 maintenance is an intake lane, not a repair bot. `fleet-maintenance.ps1` looks at existing Fleet reports and maintenance docs, classifies likely bugs, dependency-review items, performance regressions, flaky-test signals, and technical debt. In report-only mode it writes the finding list. In `-QueueTasks` mode it appends a capped set of low-risk maintenance tasks to configured ship queues for the checkpoint loop and human approval gates.

Phase 9 limited autopilot is policy-first. `fleet-autopilot-policy.ps1` can prepare templates and validate whether a ship has approved safe lanes, zero spending, customer-data rules, escalation rules, machine-readable audit evidence, and explicit human approval for reputation, money, auth, payments, legal text, mass email, data deletion, and production deploy decisions.

Phase 10 specialist reviewers give the Fleet domain-specific stoppers. The first reviewer is Franky Formula Review: formula/model work must show a spec, fixtures, expected outputs, tests, provenance, and calibration caveats before the loop treats analytical output as trustworthy.

Phase 11 accessibility review adds Ada Accessibility Review: website and app ships can run deterministic accessibility smoke checks for alt text, labels, focus visibility, dead links, and vague controls before checkpoint review.

Phase 12 performance review adds Percy Performance Review: website and app ships can run deterministic page-weight and runtime-footgun checks for bundle size, CSS size, large assets, inline base64 media, transition-all CSS, blur/filter overuse, tiny polling intervals, and eager autoplay video before checkpoint review.

Phase 13 experiment runner adds controlled parallel-run evidence: selected ships can run from one manifest with the same mission shape, capped runtime, reviewer cadence, and model budget while Fleet records speedup, efficiency, load imbalance, retry overhead, stop reasons, and exact commands for presentation or tuning work.

Nami and the checkpoint reviewer run in read-only Codex mode and fail if they dirty anything outside their report file. The final checkpoint review runs after fresh visual inspection, Simon, Robin, accessibility, performance, Joey, and Franky reports so its verdict reflects the latest gates rather than stale reports from a previous batch. Task review responses are parsed for unresolved `P1`/`P2` findings before a task can be marked complete.

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
