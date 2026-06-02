# Runtime Enforcement Implementation Plan

Prepared: 2026-06-01

Scope: planning only for Codex Fleet / Thousand Sunny Fleet runtime enforcement. This document does not implement runtime enforcement, touch product repositories, create worktrees, launch product ships, run all-fleet commands, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, stage files, commit, push, or approve real-project work.

This plan keeps runtime implementation deferred until a future captain-approved task names exact allowed files, dry-run validation, and human approval gates.

## Purpose

The current control plane has contracts, schemas, fixture helpers, selected-ship ledgers, repo fingerprint helpers, worktree boundary validators, lease heartbeat classifiers, runtime policy decisions, and failure fingerprints. Those artifacts are evidence and design vocabulary. They are not full runtime enforcement gates.

Plain invariant: planning is not permission.
Plain invariant: dry-run evidence is not execution authority.
Plain invariant: the model cannot grant itself runtime enforcement approval.

## Current Boundary

Runtime enforcement remains deferred. Automated or mutating product-mode work stays YELLOW or RED unless a later bounded implementation task is approved and validated.

Allowed now:

- docs, schemas, contracts, and tests
- fixture-only rehearsal
- dry-run helper validation
- bounded external audit preparation
- commit-scope review
- one explicitly approved manual read-only single-project demo, only after approval packet completion, inactive stop signs, audit disposition, and commit-scope review

Blocked now:

- product-repo mutation
- product ship launch
- all-fleet command execution
- runtime policy enforcement as authority
- worktree creation or deletion
- durable lease enforcement
- Fleet.Core or SQLite implementation
- package installation
- database migrations
- secrets/auth/payments/deploy access
- lock deletion
- permission widening
- merge, push, stage, or commit

## Anti-Confusion Note For Current Queue

The current queue strengthens vocabulary and evidence only. Strict schemas, contracts, ledgers, audit package plans, reviewer prompts, reviewer outputs, selected-ship records, repo fingerprint records, worktree boundary records, lease heartbeat records, runtime policy decision records, and passing tests are not runtime gates and are not permission.

The current queue does not implement runtime enforcement. It does not wire policy decisions into launchers, create worktrees, enforce leases, enforce repo fingerprints, change broad entrypoint behavior, create Fleet.Core or SQLite runtime storage, approve product-mode automation, or authorize mutating work.

Future runtime implementation requires a separate captain-approved bounded task with exact allowed files, dry-run-first validation, fail-closed defaults, and explicit stop signs. Until that task exists and passes validation, every ambiguous, stale, missing, broad, externally supplied, mobile-sourced, DOCX-sourced, audit-package-sourced, or queue-prose-sourced input remains non-executable and cannot promote YELLOW evidence to GREEN execution authority.

## Future Phase 0: Evidence Freeze And Preconditions

Goal: prove that the evidence vocabulary is stable before code enforces it.

## Runtime Pilot Evidence Freeze

HQ-069 freezes the next phase as dry-run runtime enforcement for one named entrypoint only: `invoke-autonomy-wrapper.ps1`. This freeze is prerequisite evidence for later helper or wrapper work. It does not implement runtime enforcement, wire launchers, create or delete worktrees, enforce leases, enforce repo fingerprints, create product-mode automation authority, or change any broad entrypoint behavior.

All `ALLOW`, `ALLOW_DRY_RUN`, or positive pilot outcomes are local evidence only until a later separately approved task changes behavior. They have no authority for product mutation, staging, commit, push, demo trial, worktree creation/deletion, package installation, launch, deploy, all-fleet scope, migration, secrets/auth/payments/deploy access, lock deletion, permission widening, merge, or future runs.

`ALLOW_DRY_RUN` plain-language guard: `ALLOW_DRY_RUN` means "the dry-run fixture passed"; it never means approval to execute, mutate, stage, commit, push, launch, run a demo, or carry future authority. Every runtime pilot report that shows `ALLOW_DRY_RUN` must show the non-executable fields beside it: `executesProductActions = false`, `mutatesProductRepos = false`, `canApproveFutureRuns = false`, and `commandInput = false`.

Human decisions still required before any real-project demo or runtime widening:

- real demo approval packet with exact current values
- stop signs reviewed and inactive
- exact product/project selection and absolute repo path
- explicit runtime widening approval beyond the named dry-run entrypoint

Current pilot prerequisites are evidence only: checkpoint commit `5a1743f`, `HQ-068` done, `HQ-069` selected by the runtime pilot queue, and full local fleet tests passing. These prerequisites provide no execution authority. Any request to touch product repositories, change launchers, implement runtime behavior before this freeze, create worktrees, install packages, stage files, commit, push, or claim demo-trial approval remains a stop condition.

## Runtime Evidence Bundle Contract

The dry-run pilot vocabulary may use a local dry-run evidence bundle before any entrypoint wiring. The bundle references selected ship, entrypoint, action, repo fingerprint, worktree boundary, lease heartbeat, failure fingerprint, approval evidence, budget evidence, generated time, validation reasons, and source provenance.

The bundle is evidence only. Missing or stale refs deny/defer and never execute. Source provenance for external reports, mobile requests, task packets, audit packages, DOCX reports, queue prose, and generated evidence remains non-executable and has no authority for product work.

This contract adds no new runtime storage, DB, SQLite, migration, product repo access, real product repo fingerprinting, worktree creation/deletion, launcher behavior, lease takeover, staging, commit, push, deploy, or demo-trial approval.

## One-Entrypoint Dry-Run Pilot Wrapper Contract

`invoke-autonomy-wrapper.ps1` exposes `-RuntimePolicyPilotDryRun` as the only runtime-pilot entrypoint for this queue. The pilot path exits before normal project/config processing and evaluates schema-shaped runtime policy evidence for `invoke-autonomy-wrapper.ps1` only.

The pilot path can emit `ALLOW_DRY_RUN`, `DEFER_NEEDS_HUMAN`, or `DENY_UNSAFE` evidence. Even when `-Execute` is present, the pilot reports `executesProductActions = false`, `launchesShips = false`, `importsPackets = false`, and `mutatesProductRepos = false`.

The pilot path does not launch ships, import packets, mutate product repositories, create worktrees, delete locks, install packages, run migrations, touch secrets/auth/payments/deploy material, stage files, commit, push, or widen permissions. Default wrapper behavior outside `-RuntimePolicyPilotDryRun` remains unchanged.

Broad, blank, all, wildcard, mobile, external, DOCX, audit-package, task-packet, queue-prose, stale, missing, malformed, or unauthorized evidence stays denied or deferred by the runtime policy dry-run evaluator.

## Pilot Evidence Output And Audit Trail

The `-RuntimePolicyPilotDryRun` path writes local JSON and Markdown evidence only under local harness evidence roots or test fixtures: `out/stage8-autonomy/`, `out/runtime-pilot/`, `.codex-local/runtime-pilot/`, or `.codex-local/fixtures/`. The path guard rejects `.git`, `.env`, dependency folders, build outputs, secret-like paths, auth/payment/deploy/migration paths, and any output outside the fleet root.

Pilot evidence records selected ship or fixture id, entrypoint, action, policy result, denial/defer reason, evidence refs, generatedAt, non-executable status, artifact refs, and the runtime evidence bundle. The evidence record also states `canApproveFutureRuns = false` and `commandInput = false`.

Pilot evidence is an audit trail, not input for future commands. It cannot approve future runs, cannot approve demo trials, cannot authorize product repo access, cannot import packets, cannot launch ships, and cannot be treated as command input. If the policy result is `ALLOW_DRY_RUN`, the report must still be read as local non-executable evidence with `executesProductActions = false`, `mutatesProductRepos = false`, `canApproveFutureRuns = false`, and `commandInput = false`.

No audit package is created or sent by the runtime pilot evidence path.

## Runtime Pilot Fixture Matrix

The pilot fixture matrix is local validation evidence only. Real-project demo remains blocked. Product-repo mutation, launcher widening, all-fleet execution, staging, commit, push, package installation, migration, secrets/auth/payments/deploy access, lock deletion, permission widening, worktree creation/deletion, and future runs remain blocked.

Required positive fixture: a fixture-only selected ship with repo fingerprint ref, worktree boundary ref, lease heartbeat ref, failure fingerprint ref, budget ref, and exact pilot approval emits `ALLOW_DRY_RUN`, writes only local JSON/Markdown evidence, and records `executesProductActions = false`, `launchesShips = false`, `importsPackets = false`, `mutatesProductRepos = false`, `canApproveFutureRuns = false`, and `commandInput = false`.

Required negative fixtures: blank ship, all ship, wildcard ship, multi-ship, stale fingerprint, missing repo fingerprint, missing worktree boundary, missing approval, stale active lease, ambiguous lease owner or fence token, repeated deterministic failure, external report, mobile request, DOCX report, audit package, and queue prose. Each negative fixture must return `DENY_UNSAFE`, `DEFER_NEEDS_HUMAN`, `REQUIRE_REVIEW`, `STOP_FOR_REPAIR`, `safe-pause`, or `repair-task` evidence as appropriate, and none may mutate product repositories or approve execution.

The lease and failure fixtures remain classifier evidence that feeds pilot readiness. Stale or ambiguous lease evidence requires review and cannot delete locks. Repeated deterministic failure evidence stops for repair or safe-pause and cannot become a blind retry.

HQ-081 extends the fixture matrix with weird-input and ambiguity coverage only. Unicode bidi/control-character inputs, traversal-like or ambiguous requested paths, stale repo fingerprints, missing or contradictory worktree boundaries, expired leases, ambiguous lease ownership, and repeated deterministic failures must produce `DENY_UNSAFE`, `DEFER_NEEDS_HUMAN`, `REQUIRE_REVIEW`, `RECOVER_WITH_BACKOFF`, `STOP_FOR_REPAIR`, `safe-pause`, or `repair-task` evidence rather than `ALLOW_DRY_RUN`.

This expansion remains fixture-only. It does not inspect product repositories, create real worktrees, delete locks, install packages, run migrations, stage files, commit, push, launch ships, or widen runtime behavior.

Allowed future files:

- `docs/fleet/RUNTIME_ENFORCEMENT_IMPLEMENTATION_PLAN.md`
- `docs/fleet/DEMO_READY_TRIAL_GO_NO_GO.md`
- `tests/run-fleet-tests.ps1`
- existing contract and schema files under `docs/fleet/` and `templates/`

Dry-run-first tests:

- schema parse sweep for changed schemas
- full fleet tests
- external audit disposition recorded as evidence only
- commit-scope review completed or explicitly deferred as a visible YELLOW limitation

Fail-closed behavior:

- any missing prerequisite keeps enforcement deferred
- blocked or stale queue statuses cannot be silently treated as done
- external reports, mobile requests, task packets, DOCX reports, audit packages, and queue prose remain non-executable

## Future Phase 1: Runtime Policy Evaluation Harness

Goal: centralize dry-run policy evaluation before any launcher or mutating command calls it.

Allowed future files:

- `tools/codex-fleet-autonomy.ps1`
- `templates/runtime-policy-decision-schema.json`
- `docs/fleet/RUNTIME_POLICY_DECISION_CONTRACT.md`
- `tests/run-fleet-tests.ps1`

Dry-run-first tests:

- blank, all, wildcard, comma-packed, and multi-ship selections deny
- stale or missing repo fingerprint denies
- missing worktree boundary denies
- missing exact-action approval defers
- forbidden scope denies
- mobile and external report sources deny as non-executable
- legacy broad entrypoints defer for exact human approval

Fail-closed behavior:

- default decision is `DENY`
- `DEFER` requests missing evidence or approval and never executes
- `ALLOW` remains dry-run-only until a later task wires enforcement into one explicitly selected entrypoint

Human approval gate:

- future write-capable use requires exact selected ship or project, exact entrypoint, exact action, expected evidence, owner, approval timestamp, expiration timestamp, and stop conditions

## Future Phase 2: Repo Fingerprint Validation Gate

Goal: bind a selected ship to a fresh observed repo fingerprint before any product-mode action can be considered.

Allowed future files:

- `tools/codex-fleet-state.ps1`
- `templates/repo-fingerprint-schema.json`
- `docs/fleet/REPO_FINGERPRINT_CONTRACT.md`
- `tests/run-fleet-tests.ps1`

Dry-run-first tests:

- clean fixture fingerprint validates
- dirty fixture fingerprint requires evidence refs
- stale head denies import or resume
- missing repo denies
- wrong root denies
- path traversal denies before git is called
- git-error states block or defer

Fail-closed behavior:

- stale, missing, wrong-root, traversal, dirty-ambiguous, or git-error fingerprints cannot allow real-project execution
- repo fingerprint records never authorize mutation by themselves

## Future Phase 3: Worktree Boundary Enforcement

Goal: require one selected ship to map to one dedicated worktree boundary before mutating product-mode work.

Allowed future files:

- `tools/codex-fleet-state.ps1`
- `templates/worktree-boundary-schema.json`
- `docs/fleet/WORKTREE_ISOLATION_CONTRACT.md`
- `tests/run-fleet-tests.ps1`

Dry-run-first tests:

- missing worktree denies
- direct product-root marker denies
- mismatched ship id denies
- traversal path denies
- ambiguous, stale, blocked, or planned-only boundary defers
- fixture-only exception never promotes to product-mode execution

Fail-closed behavior:

- no implicit direct product-root mutation
- no worktree creation or deletion without a later exact approved task
- no lock deletion as cleanup

## Future Phase 4: Lease Heartbeat Management

Goal: prevent accidental takeover of active work by enforcing owner, fence token, heartbeat age, lease expiry, and recovery class.

Allowed future files:

- `tools/codex-fleet-overnight.ps1`
- `templates/lease-heartbeat-schema.json`
- `docs/fleet/LEASE_HEARTBEAT_CONTRACT.md`
- `tests/run-fleet-tests.ps1`

Dry-run-first tests:

- fresh active owner leaves running
- stale active lease requires review
- expired stale lease permits only bounded recovery planning
- ambiguous owner requires review
- fence-token mismatch requires review
- clock-skew suspicion requires review
- deterministic failure stops for repair

Fail-closed behavior:

- `deletesLocks` stays false
- no process killing
- no live lock rewrite
- no ownership takeover from ambiguous evidence

## Future Phase 5: Failure Fingerprint Anti-Loop Gate

Goal: stop repeated failed attempts from becoming blind retries.

Allowed future files:

- `tools/codex-fleet-runtime.ps1`
- `templates/failure-fingerprint-schema.json`
- `docs/fleet/FAILURE_FINGERPRINT_CONTRACT.md`
- `tests/run-fleet-tests.ps1`

Dry-run-first tests:

- timestamps, temp paths, GUIDs, noisy ids, machine roots, durations, absolute paths, ports, and line endings normalize
- same fingerprint plus same hypothesis twice maps to safe-pause or repair-task
- policy denial is non-retriable
- missing evidence does not retry

Fail-closed behavior:

- repeated deterministic failures become repair work or safe pause
- policy denials are not retried
- failure fingerprints are evidence, not permission to retry

## Future Phase 6: One Entrypoint Integration

Goal: integrate enforcement into one explicitly selected, low-risk, dry-run entrypoint before any broader launcher changes.

Allowed future files:

- one named selected-ship wrapper, preferably `invoke-autonomy-wrapper.ps1` or another captain-approved dry-run-only wrapper
- relevant helper under `tools/`
- `tests/run-fleet-tests.ps1`
- docs under `docs/fleet/`

Dry-run-first tests:

- safe selected fixture path produces a non-executing decision
- missing fingerprint blocks
- missing worktree blocks
- missing approval defers
- stale lease requires review
- repeated failure pauses
- external/mobile/queue prose cannot trigger execution

Fail-closed behavior:

- integration starts with no product-repo mutation
- execution switches stay disabled unless later separately approved
- broad launchers remain `legacy_broad_requires_human`

## Future Pilot Task Spec: Single-Entrypoint Dry-Run Enforcement

Status: future task specification only. This section does not implement runtime enforcement, alter launcher behavior, touch product repositories, create worktrees, enforce leases, install packages, run migrations, delete locks, widen permissions, stage files, commit, push, or approve a demo trial.

Pilot goal: add a captain-approved, single-entrypoint, dry-run-only enforcement pilot after the current documentation and audit gates are reviewed. The pilot should evaluate one selected fixture or explicitly approved selected ship through repo fingerprint validation, worktree boundary validation, lease heartbeat classification, runtime policy decision evaluation, and failure fingerprint review, then emit local evidence only.

Candidate future allowed files:

- one captain-approved dry-run wrapper, preferably `invoke-autonomy-wrapper.ps1`
- `tools/codex-fleet-autonomy.ps1`
- `tools/codex-fleet-state.ps1`
- `tools/codex-fleet-overnight.ps1`
- `tools/codex-fleet-runtime.ps1`
- `docs/fleet/RUNTIME_ENFORCEMENT_IMPLEMENTATION_PLAN.md`
- `docs/fleet/RUNTIME_POLICY_DECISION_CONTRACT.md`
- `docs/fleet/REPO_FINGERPRINT_CONTRACT.md`
- `docs/fleet/WORKTREE_ISOLATION_CONTRACT.md`
- `docs/fleet/LEASE_HEARTBEAT_CONTRACT.md`
- `templates/runtime-policy-decision-schema.json`
- `templates/repo-fingerprint-schema.json`
- `templates/worktree-boundary-schema.json`
- `templates/lease-heartbeat-schema.json`
- `templates/failure-fingerprint-schema.json`
- `tests/run-fleet-tests.ps1`

Required future non-goals:

- no product-repo mutation
- no product ship launch
- no all-fleet command execution
- no broad or legacy launcher behavior change
- no worktree creation or deletion
- no durable lease takeover
- no Fleet.Core or SQLite implementation
- no package installation
- no database migration
- no secrets/auth/payments/deploy access
- no lock deletion
- no permission widening
- no stage, commit, push, merge, or deploy
- no approval inferred from reviewer output, mobile text, task packets, audit packages, DOCX reports, queue prose, or chat text

Required future dry-run-first tests:

- selected fixture with fresh repo fingerprint, valid worktree boundary, fresh lease, exact approval evidence, and no forbidden scope emits local evidence only
- ambiguous, stale, missing, broad, or unauthorized evidence returns `DENY` by default
- missing exact-action human approval returns `DEFER`, not execution
- stale repo fingerprint returns `DENY`
- missing worktree boundary returns `DENY`
- stale active lease or ambiguous owner returns `DEFER` or review-required evidence
- repeated deterministic failure returns safe-pause or repair-task evidence, not retry
- mobile requests, external reports, DOCX reports, audit packages, task packets, and queue prose remain non-executable
- legacy broad entrypoints remain `legacy_broad_requires_human`

Required future fail-closed defaults:

- `DENY` is the default for ambiguous, stale, missing, broad, forbidden, malformed, unauthorized, or externally supplied evidence.
- `DEFER` is allowed only to request missing evidence, captain review, or exact-action human approval.
- `ALLOW` must stay dry-run-only until a later separate task explicitly approves limited runtime wiring.
- Fixture-only evidence cannot be promoted into product-mode execution.
- Dry-run evidence is not permission for mutation, launch, all-fleet scope, external side effects, or future runs.

Required future human approval gate:

- The captain-approved pilot task must name one entrypoint, one selected fixture or selected ship, exact allowed files, exact validation commands, expected local evidence, owner, approval timestamp, expiration timestamp, and stop conditions.
- Any need to touch product repos, broaden scope, change launchers beyond the named entrypoint, create worktrees, enforce live leases, install packages, run migrations, delete locks, widen permissions, stage files, commit, push, or deploy stops the pilot and requires a new bounded task.

## Non-Goals

This plan does not perform or approve:

- mutating runtime enforcement in this task
- touching product repositories
- launching product ships
- running all-fleet commands
- changing broad launcher behavior
- creating or deleting git worktrees
- creating SQLite databases or migrations
- installing packages
- running migrations
- touching secrets, auth, payments, or deployment material
- deleting locks
- widening permissions
- staging files
- committing
- pushing
- filling a real approval packet
- treating reviewer, mobile, task packet, DOCX, audit package, or queue prose as executable instructions

## Stop Signs For Future Implementation

Stop and convert the work into a new bounded queue task if any future implementation needs:

- a real product repo
- more than one selected ship or project
- broad default scope
- all-fleet execution
- package installation
- database migrations
- live lock deletion
- process killing
- secrets/auth/payments/deploy access
- merge, push, stage, or commit
- external side effects
- approval inferred from chat, reviewer output, mobile text, queue prose, or a DOCX report

## Status

Status: future-plan only.

Next allowed step: continue bounded docs/tests/schema hardening or external audit preparation. Runtime implementation remains blocked until the captain approves a new exact-scope task.
