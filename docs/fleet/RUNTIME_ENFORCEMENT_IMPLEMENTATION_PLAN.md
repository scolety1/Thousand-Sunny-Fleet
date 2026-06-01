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
