# Autonomous Software Roadmap

This roadmap describes how Codex Fleet can grow from a guarded task runner into a staged autonomous software organization for full websites, full-stack products, desktop apps, developer tools, data systems, AI workflows, and other sophisticated software.

The goal is not blind production autopilot. The goal is an increasingly capable system where Fleet does routine engineering independently, asks for approval at high-risk gates, and produces reviewable evidence before anything reaches users.

## North Star

Fleet should eventually be able to take a product mission and return with:

- a planned architecture
- a working local implementation
- tests and build evidence
- screenshots or runtime evidence where relevant
- security, design, copy, and maintainability reviews
- migration and deployment plans
- a clean branch or pull request
- clear human approval requests for risk-bearing decisions

Fleet should not silently spend money, expose secrets, change production data, weaken auth, alter payment behavior, or deploy user-facing production changes without explicit policy and approval.

## Operating Model

Fleet needs phases, gates, and role-specific reviewers.

## Analytical Software Loop Roadmap

This track is for Niners-style tools, market research runners, ranking engines, scoring systems, recipe/order recommendation engines, and any project where the hard part is deterministic calculation rather than visual polish.

Current status:

- [x] Add analytical phase names: `problem-brief`, `data-contract`, `formula-spec`, `fixture-tests`, `engine-build`, `calibration`, `dashboard`, `scenario-tools`, `analysis-proof`.
- [x] Teach the planner that analytical ships must be data-first, fixture-first, deterministic, and explainable.
- [x] Add `fleet-analysis.ps1` to create the planning pack: `ANALYSIS_BRIEF.md`, `DATA_CONTRACT.md`, `FORMULA_SPEC.md`, `FIXTURE_TEST_PLAN.md`, `CALIBRATION_PLAN.md`, and `ANALYSIS_APPROVAL.md`.
- [x] Add Fleet Doctor reporting for missing, draft, or approved analytical planning packs.

Next upgrades:

### A1 - Engine-Build Approval Blocker - done

Problem:
The fleet can enter `engine-build` before the human has approved the decision, data contract, formulas, fixtures, and calibration plan.

Target:
Block `engine-build`, `calibration`, `dashboard`, `scenario-tools`, and `analysis-proof` unless `ANALYSIS_APPROVAL.md` says `Status: APPROVED`.

Status:
Implemented in `run-checkpoint-loop.ps1`. The checkpoint loop resolves `-LoopPhase auto` from `PHASE_STATE.md`, blocks the implementation/UI analytical phases when the planning pack is missing or draft, releases the fleet run lock, and prints the `fleet-analysis.ps1` commands needed to prepare and validate approval.

Acceptance:

- `run-checkpoint-loop.ps1 -LoopPhase engine-build` refuses unapproved analytical packs.
- The refusal tells the operator to run or review `fleet-analysis.ps1`.
- Tests cover approved, draft, and missing analytical packs.

### A2 - No Fake Numbers Gate - done

Problem:
Analytical apps can look convincing while showing hardcoded or invented percentages, ranks, scores, probabilities, dollar values, or recommendations.

Target:
Add a gate that scans staged UI/report text for numeric claims and requires an obvious code/data source, fixture, or generated output path behind those numbers.

Status:
Implemented as `analytical-number-provenance.ps1` and wired into `run-checkpoint-loop.ps1` before commits during analytical phases. The gate scans staged user-facing additions for hardcoded analytical percentages, scores, ranks, dollar values, forecasts, and recommendation numbers while allowing fixtures, sample data, tests, formula specs, data contracts, and generated reports.

Acceptance:

- The gate warns or blocks hardcoded probability/score/rank claims in user-facing files.
- Fixture/sample files and deterministic test expectations are allowed.
- Reports explain which numbers need provenance.

### A3 - Fixture-First Enforcement - done

Problem:
Formula implementation can drift if tests come after the model code.

Target:
During `formula-spec` and `fixture-tests`, require tiny known input/output examples before `engine-build` starts.

Status:
Implemented as `analytical-fixture-readiness.ps1` and wired into `run-checkpoint-loop.ps1` before `engine-build` and later analytical phases. The planner now prioritizes fixture examples in `formula-spec` and `fixture-tests`, and engine work is blocked until the ship has concrete fixture data, expected outputs, and test files.

Acceptance:

- Analytical phase validation can detect missing fixture files or missing expected-output sections.
- Planner tasks in `formula-spec` and `fixture-tests` prioritize examples, expected outputs, and edge cases.
- Engine-build tasks must include acceptance commands that run formula/import tests.

### A4 - Calibration Report Script - done

Problem:
Even deterministic formulas can be wrong, overconfident, or poorly calibrated.

Target:
Add `fleet-calibration.ps1` to inspect whether an analytical ship has calibration evidence: known-case comparisons, historical/backtest plan, confidence rules, failure modes, and tuning rules.

Status:
Implemented as `fleet-calibration.ps1` and wired into Fleet Doctor plus the checkpoint startup gate for `calibration`, `dashboard`, `scenario-tools`, and `analysis-proof`. The report distinguishes ignored history from explicitly unavailable history with fallback sanity or known-case checks.

Acceptance:

- The script writes a calibration readiness report under `docs/codex`.
- It distinguishes unavailable history from ignored history.
- Fleet Doctor reports calibration status for analytical ships.

### A5 - Analytical Dashboard Restraint - done

Problem:
The fleet can build a large dashboard before the model is trustworthy.

Target:
Prevent `dashboard` and `scenario-tools` from producing big UI work until tests, fixture outputs, import validation, and at least one deterministic report/table exist.

Status:
Implemented as `analytical-dashboard-readiness.ps1` and wired into the checkpoint startup gate for `dashboard` and `scenario-tools`. The planner now downgrades premature UI ideas into evidence tasks, and Simon/Robin are instructed to judge analytical UI/copy without encouraging fake insight text.

Acceptance:

- Planner guidance keeps analytical UI table-first and report-first.
- Dashboard tasks are blocked or downgraded when formula/test artifacts are missing.
- Simon/Robin are instructed to judge clarity without encouraging fake insight text.

### A6 - Scenario Approval Lane - done

Problem:
What-if sliders and strategy modes can quietly change formulas in ways nobody approved.

Target:
Add a scenario spec/approval artifact before `scenario-tools` work. Each scenario must state which inputs change, which formulas are affected, which outputs should change, and which outputs must remain fixed.

Status:
Implemented as `analytical-scenario-approval.ps1` and wired into the checkpoint startup gate for `scenario-tools`. The script can create `SCENARIO_SPEC.md` and `SCENARIO_APPROVAL.md` templates, validates approved scenario assumptions, requires scenario test or fixture evidence, and writes `SCENARIO_READINESS.md`.

Acceptance:

- `scenario-tools` refuses to run without an approved scenario spec.
- Tests cover at least one scenario where changing an input changes the expected score.
- Scenario UI labels explain assumptions without pretending to be final advice.

Exit criteria for this track:

- The fleet can build a new local-first analytical tool from blank repo to deterministic engine, tested fixtures, calibration report, and table-first dashboard without inventing unsupported numbers.

### Phase 0 - Intake

Purpose: Decide what kind of software this ship is and what Fleet is allowed to do.

Status: started. Fleet profiles and project registrations now carry `projectType`, `riskTier`, and `capabilities`; `add-project.ps1` can record them during intake, and `fleet-doctor.ps1` validates and reports them before launch.

Required upgrades:

- Add project type profiles beyond web demos:
  - `marketing-site`
  - `full-stack-web`
  - `desktop-app`
  - `cli-tool`
  - `library`
  - `data-pipeline`
  - `ai-workflow`
  - `mobile-app`
  - `game`
- Add risk tier per ship:
  - `sandbox`
  - `local-only`
  - `staging`
  - `production-adjacent`
  - `production`
- Add capability permissions:
  - can edit package files
  - can add dependencies
  - can edit backend code
  - can edit migrations
  - can edit auth policy
  - can edit deployment config
  - can use network APIs
  - can open PRs
  - can deploy

Exit criteria:

- Fleet can classify a new ship and refuse unsafe launch settings before work begins.

### Phase 1 - Product And Architecture Planning

Purpose: Let Fleet design before it codes.

Status: started. `fleet-plan.ps1` now creates or validates the Phase 1 architecture pack (`ARCHITECTURE.md`, `ENGINEERING_PLAN.md`, `RISK_REGISTER.md`, and `ARCHITECTURE_APPROVAL.md`), and Fleet Doctor reports whether serious ships are missing, draft, or approved.

Required upgrades:

- Add an Architect role that creates:
  - product brief
  - user flows
  - system architecture
  - data model
  - API contracts
  - dependency proposal
  - test strategy
  - security model
  - deployment model
- Add architecture review gates:
  - architecture sanity review
  - security design review
  - cost and dependency review
  - human approval checkpoint
- Store approved plans in `docs/codex/ARCHITECTURE.md`, `docs/codex/ENGINEERING_PLAN.md`, and `docs/codex/RISK_REGISTER.md`.

Exit criteria:

- Fleet cannot scaffold or make broad changes until the architecture plan is accepted.

### Phase 2 - Scaffold And Dependency Gate

Purpose: Build new projects safely, including package files when approved.

Status: started. `scaffold-project.ps1` now supports allowlisted scaffolds, refuses to scaffold before architecture approval, and writes dependency proposal/approval files when package dependencies are introduced. Fleet Doctor reports dependency approval status for package/dependency-capable ships.

Required upgrades:

- Add a `scaffold-project.ps1` flow.
- Add allowlisted scaffolds:
  - Vite/React
  - Next.js
  - Express/Fastify API
  - Electron/Tauri desktop
  - Python CLI/package
  - library/package skeleton
  - test harness only
- Add dependency proposal files before package edits:
  - dependency name
  - purpose
  - license
  - maintenance status
  - known risks
  - alternatives
- Add a dependency approval gate that permits package changes only for the approved task.

Exit criteria:

- Fleet can create a real new codebase without treating package edits as normal unattended work.

### Phase 3 - Local Implementation Loop

Purpose: Extend the current checkpoint loop into serious implementation work.

Status: complete for the first production pass. The checkpoint loop now parses Phase 3 task contracts from task lines, reports task class/risk/scope/acceptance/implementation scale in nightly reports, blocks high/gated work without approved architecture, enforces declared file scopes, runs explicit or inferred acceptance commands in addition to the normal external build, and requires broad/high-risk implementation to be planned and sliced before Codex touches code.

Required upgrades:

- Add task classes:
  - feature
  - bugfix
  - refactor
  - test
  - docs
  - design
  - copy
  - backend
  - migration
  - integration
  - performance
- Add task risk levels and allowed file scopes.
- Add per-task acceptance tests.
- Automatic test selection now infers safe existing commands from the repo when `accept:` is omitted:
  - package test scripts
  - package lint scripts
  - package typecheck/tsc scripts
  - Python pytest when tests/project files are present
  - Python ruff when configured
  - build still runs through the normal external build gate
  - smoke/visual checks remain controlled by runtime/visual cadence and route config
- Larger-change handling now classifies implementation scale:
  - small tasks can run normally
  - high/gated/broad tasks require explicit scope
  - broad tasks require `SOFTWARE_FEATURE_PLAN.md`
  - Codex is instructed to implement the next named slice only
  - checkpoint/debug/scorecard gates still run after each slice
  - unresolved slices must be summarized for later work

Exit criteria:

- Fleet can build real features across frontend, backend, and shared code while still staying inside approved scope.

### Phase 4 - Backend, Data, And Migration Safety

Purpose: Allow serious backend work without risking production data.

Status: complete for the first production pass. `backend-local` and `backend-staging` profiles now separate local backend work from staging migration-capable work. `migration-review.ps1` validates migration proposals, approvals, destructive-operation acknowledgement, and production human approval. `api-contract-review.ps1` and `seed-fixture-review.ps1` gate backend/API/data work on contract tests and safe fixture evidence. The checkpoint loop blocks backend/migration tasks unless the ship has the right capabilities, approved architecture, and the Phase 4 evidence package before implementation and again before commit.

Required upgrades:

- Add backend profiles for local-only and staging-only work.
- Add migration reviewer role.
- Add migration safety checks:
  - reversible or forward-only justification
  - data-loss detection
  - table/collection impact summary
  - local migration run evidence
  - rollback plan
- Add API contract tests.
- Add local seed data and fixture generation.
- Add policy that production migrations require human approval.

Exit criteria:

- Fleet can build backend systems locally and propose production changes with evidence.

### Phase 5 - Auth, Secrets, Payments, And External Services

Purpose: Treat sensitive systems as gated capabilities, not permanent blockers.

Status: started. `sensitive-systems-review.ps1` now scans staged diffs for common secret patterns and validates external-service, auth, and payment approval artifacts. The checkpoint loop runs the sensitive systems review before every Fleet commit and blocks integration/auth/payment tasks without the required Phase 5 artifacts.

Required upgrades:

- Add secret scanner before every commit.
- Add auth policy reviewer.
- Add payment risk reviewer.
- Add external service registry:
  - service name
  - environment variables
  - scopes
  - cost risk
  - data sent
  - approval status
- Add mock-first integration workflow.
- Add staging-only live integration workflow.
- Keep production credentials and payment activation human-controlled.

Exit criteria:

- Fleet can write auth/payment/integration code behind explicit approvals, with tests and mocks first.

### Phase 6 - Runtime Verification

Purpose: Move beyond "build passed" into "software works."

Status: started. `runtime-verify.ps1` now runs configured command, URL, URL text, local text, and file-existence checks from `RUNTIME_CHECKS.md`, writes `RUNTIME_VERIFICATION.md` with detail and duration for each check, and the checkpoint loop invokes runtime verification for integration/performance tasks or task-specific acceptance work.

Required upgrades:

- Add app-specific smoke scenarios.
- Add Playwright or equivalent browser flows for web apps.
- Add CLI command tests for CLI tools.
- Add API endpoint tests for services.
- Add desktop app launch checks.
- Add performance budgets.
- Add accessibility checks.
- Add screenshot galleries for every relevant UI route.
- Add log and console issue summarization.

Exit criteria:

- Fleet can prove core workflows work, not just compile.

### Phase 7 - Release And Operations Gate

Purpose: Let Fleet prepare releases while keeping production control explicit.

Status: started. `release-readiness.ps1` now generates a release evidence package with build, commits, changed files, checkpoint/security/runtime/visual/migration/sensitive gates, deployment plan, post-deploy smoke plan, rollback plan, and human release approval status. It can scaffold the required release docs, validates required release-plan sections, writes a machine-readable JSON companion report, and never deploys.

Required upgrades:

- Add release readiness report:
  - changed files
  - commits
  - tests
  - visual evidence
  - security findings
  - migration status
  - rollback plan
  - known risks
- Add deployment plan generation.
- Add staging deploy support before production.
- Add production deploy approval gate.
- Add post-deploy smoke plan.
- Add rollback command documentation.

Exit criteria:

- Fleet can hand you a release package that is boring to review.

### Phase 8 - Autonomous Maintenance

Purpose: Let Fleet keep mature software healthy.

Status: implemented. `fleet-maintenance.ps1` now provides a Phase 8 maintenance lane that scans existing local reports for bugs, dependency-review signals, flaky-test/performance regression signals, and technical debt, writes Markdown plus JSON reports, tail-scans long reports to avoid stale-noise loops, de-duplicates repeated signals, can install maintenance queue/window templates, and can opt into `-QueueTasks` to append capped low-risk maintenance tasks to configured ships.

Required upgrades:

- Add issue intake from logs, CI, local reports, and human notes.
- Add bug triage role.
- Add dependency update lane with changelog and test evidence.
- Add recurring maintenance windows.
- Add flaky test detection.
- Add performance regression detection.
- Add technical debt queue.

Exit criteria:

- Fleet can maintain sophisticated software continuously without turning every change into a product sprint.

### Phase 9 - Limited Business Autopilot

Purpose: Automate low-risk business operations while preserving human control over reputation, money, and user trust.

Status: implemented. `fleet-autopilot-policy.ps1` now validates limited-autopilot policy and approval artifacts, requires spending limits, customer-data handling rules, escalation rules, concrete safe automatic lanes, and explicit human approval for sensitive business actions, fails closed on dirty ships, writes Markdown and JSON reports, and writes an audit log for each policy review.

Required upgrades:

- Add policy engine for what can happen automatically.
- Add spending limits.
- Add customer-data handling rules.
- Add escalation rules.
- Add audit log for every autonomous decision.
- Add safe automatic lanes:
  - content typo fixes
  - docs updates
  - non-sensitive UI polish
  - test-backed bug fixes
  - staging deploys
  - report generation
- Keep these human-approved:
  - pricing changes
  - production deploys for sensitive apps
  - payment behavior
  - auth or permission changes
  - mass emails
  - deletion of user data
  - legal or compliance text

Exit criteria:

- Fleet can operate low-risk lanes overnight and produce a morning business report, while sensitive decisions wait for approval.

### Phase 10 - Specialist Reviewer Layer

Purpose: Add domain-specific reviewers that stop polished nonsense before it becomes trusted output.

Status: implemented for the first reviewer. `franky-formula-review.ps1` now reviews analytical and formula-heavy ships for concrete formula specs, fixture data, expected outputs, formula tests, number provenance, and calibration visibility. The checkpoint loop accepts `-FrankyEvery`, auto-runs Franky during analytical phases, stages `FRANKY_FORMULA_REVIEW.md`, and stops on RED formula findings before the final checkpoint.

Required upgrades:

- Add Franky Formula Review for deterministic formula/model correctness checks.
- Wire Franky into analytical phases automatically.
- Add Fleet Doctor visibility for Franky verdicts.
- Make final checkpoint happen after specialist reviewers.
- Keep future reviewers role-specific, deterministic where possible, and bounded to their evidence lane.

Exit criteria:

- Formula-heavy ships cannot continue with missing specs, missing fixtures, missing expected outputs, or missing formula-test evidence.

### Phase 11 - Accessibility Reviewer Layer

Purpose: Add a deterministic accessibility reviewer so polished website/app surfaces do not ship with obvious keyboard, label, alt text, or focus problems.

Status: implemented for the first accessibility lane. `accessibility-review.ps1` scans UI source files for missing image alt text, unlabeled inputs, empty/icon-only buttons, dead hash links, vague link text, and removed focus outlines. The checkpoint loop accepts `-AccessibilityEvery`, proof/school/overnight launchers forward accessibility cadence, Fleet Doctor reports accessibility verdicts, and checkpoint review reads `ACCESSIBILITY_REVIEW.md` before producing the final verdict.

Required upgrades:

- Add Ada Accessibility Review for deterministic accessibility smoke checks.
- Wire accessibility review into checkpoint loops before security/formula gates.
- Add Fleet Doctor visibility for accessibility verdicts.
- Forward accessibility cadence through launchers.
- Keep the check deterministic and bounded; deeper browser/screen-reader audits can be a later phase.

Exit criteria:

- Website/app ships can run a low-cost accessibility gate before checkpoint review, and RED accessibility findings can stop a loop before the fleet treats the surface as ready.

### Phase 12 - Performance Reviewer Layer

Purpose: Add a deterministic performance reviewer so websites and app surfaces do not quietly become bloated, slow, or runtime-expensive while the fleet is polishing visuals and copy.

Status: implemented for the first performance lane. `performance-review.ps1` scans build artifacts and source files for oversized JavaScript/CSS/static assets, missing build artifacts when a build script exists, large inline base64 assets, transition-all CSS, blur/filter usage, very short polling intervals, broad will-change usage, and eager autoplay video. The checkpoint loop accepts `-PerformanceEvery`, proof/school/overnight launchers forward performance cadence, Fleet Doctor reports performance verdicts, and checkpoint review reads `PERFORMANCE_REVIEW.md` before producing the final verdict.

Required upgrades:

- Add Percy Performance Review for deterministic page-weight and runtime-cost smoke checks.
- Wire performance review into checkpoint loops after accessibility and before security/formula gates.
- Add Fleet Doctor visibility for performance verdicts.
- Forward performance cadence through launchers.
- Keep the check deterministic and bounded; deeper Lighthouse/browser performance audits can be a later phase.

Exit criteria:

- Website/app ships can run a low-cost performance gate before checkpoint review, and RED performance findings can stop a loop before the fleet treats the surface as ready.

### Phase 13 - Experiment Runner And Parallel Metrics

Purpose: Add a bounded experiment lane so Fleet can launch the same mission shape across multiple ships, measure parallel performance, and produce evidence for the Thousand Sunny Fleet project without spending overnight budget blindly.

Status: prepared. The current control-room tests, harness self-test, phase audit, and Phase 12 performance smoke are passing, so Phase 13 can start from a clean base.

Required upgrades:

- Add an experiment manifest format that defines:
  - experiment name
  - selected ships
  - workload class
  - shared task parameters
  - loop phase
  - model budget
  - max runtime
  - reviewer cadence
  - success criteria
- Add an experiment launcher that can run a controlled batch without overwriting normal fleet launch state.
- Add per-ship timing capture:
  - queue time
  - launch time
  - active work duration
  - reviewer duration
  - repair/retry count
  - stop reason
- Add a summary report with HPC-friendly metrics:
  - serial baseline estimate
  - parallel wall-clock time
  - speedup
  - efficiency
  - load imbalance
  - failure/retry overhead
  - reviewer gate overhead
- Add safety limits so experiments cannot run forever:
  - hard wall-clock cap
  - per-ship retry cap
  - rate-limit stop behavior
  - dirty active work preservation
- Add tests that verify dry-run experiment manifests, expected ship filtering, timing report creation, and invalid manifest rejection.

Exit criteria:

- Fleet can run a small controlled experiment across several safe ships and produce a reproducible Markdown/JSON report showing parallel execution, load imbalance, speedup, and failure overhead.

## Reviewer Roles To Add

Existing roles cover checkpoint, design, copy, and security. Sophisticated software needs more reviewers.

- Franky Formula Review: formula specs, fixture expectations, tests, provenance, calibration caveats.
- Architect: system design, boundaries, data model, dependencies.
- Test Lead: test plan, coverage risk, missing workflow tests.
- Backend Reviewer: API behavior, persistence, error handling, observability.
- Migration Reviewer: data safety and rollback.
- Dependency Reviewer: package risk, license, maintenance.
- Performance Reviewer: load time, runtime cost, query cost, bundle size. First deterministic pass implemented in Phase 12.
- Accessibility Reviewer: keyboard, screen reader, contrast, motion. First deterministic pass implemented in Phase 11.
- Release Manager: deployment plan and rollback.
- Product Manager: task priority and user-value fit.
- Operator: logs, alerts, incident readiness, maintenance.

## Core Code Changes Needed

These are the practical Fleet upgrades that unlock the roadmap.

1. Add phase metadata to `projects.json`.
2. Add permission flags and risk tiers to profiles.
3. Add a gated approval file format under `.codex-local/approvals/`.
4. Add `fleet-plan.ps1` for architecture and implementation planning.
5. Add `scaffold-project.ps1` for approved new-project creation.
6. Add task classes and risk levels to task parsing.
7. Add allowed file scopes per task, not just per profile.
8. Add dependency proposal and dependency approval checks.
9. Add migration proposal and migration approval checks.
10. Add test matrix config per ship.
11. Add workflow smoke tests per ship.
12. Add release readiness reports.
13. Add audit logs for autonomous decisions.
14. Add staging deploy support as a separate gate from production deploy.
15. Add policy-driven autopilot lanes.

## Milestones

### Milestone A - Full Website Builder

Fleet can create and evolve complete marketing sites and rich frontend apps.

Must have:

- project intake
- architecture plan
- scaffold gate
- visual workflow tests
- release readiness

### Milestone B - Full-Stack App Builder

Fleet can build local full-stack products with APIs, persistence, and tests.

Must have:

- backend profile
- API contract tests
- local database workflow
- migration proposal gate
- integration smoke tests

### Milestone C - Sophisticated Software Builder

Fleet can handle CLIs, desktop apps, libraries, data systems, and AI workflows.

Must have:

- project type profiles
- runtime-specific test adapters
- dependency review
- architecture review
- release packages

### Milestone D - Production-Adjacent Operator

Fleet can prepare deploys and run staging operations.

Must have:

- staging deploy gate
- post-deploy smoke tests
- rollback plans
- audit log
- incident report template

### Milestone E - Limited Autopilot

Fleet can run safe business and engineering lanes overnight.

Must have:

- policy engine
- spending limits
- approval queues
- escalation rules
- morning operator report

## Practical Next Step

The best first upgrade is Phase 0 plus Phase 1:

1. Add richer profiles and risk tiers.
2. Add an architecture planning command.
3. Add a human approval gate before scaffold, dependency, backend, auth, payment, migration, or deploy work.

That turns Fleet from a careful task runner into the beginning of a real autonomous software shop.
