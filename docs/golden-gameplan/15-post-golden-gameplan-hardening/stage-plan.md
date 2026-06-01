# Stage 15: Post-Golden Gameplan Hardening

## Purpose

Stage 15 turns the post-audit deep research into durable operating rules for
Codex Fleet. Stages 1 through 14 proved the harness can run in controlled use.
This stage makes the next layer more practical: better demos, safer mobile
control, clearer overnight recovery, and easier audits.

This stage is still harness/docs/tests work. It does not authorize real product
repo edits, product ship launches, merges, pushes, deploys, lock deletion, or
broad all-fleet runs.

## Research Inputs

The stage is based on five research tracks:

- hospitality customer-facing websites
- manager/internal restaurant tools
- mobile command and remote operations
- product demo quality contracts
- bounded autonomy and audit loops

The research should be converted into rules, templates, fixtures, and tests.
Do not paste long research reports into the repo. Keep the repo artifacts short,
actionable, and testable.

## Durable Laws

Stage 15 preserves these laws:

1. Workflow outer loop, agent inner loop.
2. Phone approves a server-generated plan, never a raw command.
3. Promise -> Proof -> Path is the default product-demo structure.
4. Manager-facing restaurant tools use a shift cockpit, not a generic dashboard.
5. Hospitality websites borrow structure, not authored identity.
6. Trust artifacts and histories, not prose summaries.

## Phase Queue

### Phase 1: Research Synthesis

Create `research-synthesis.md` and map the five reports into durable fleet
rules, target docs, and implementation priorities.

### Phase 2: Universal Product Demo Gate

Strengthen product-quality contracts around Promise -> Proof -> Path,
primary/secondary/tertiary information layers, proof artifacts, and taste gates.

### Phase 3: Hospitality Customer Website Lane

Add hospitality website archetypes and anti-copy rules for customer-facing
restaurant, bar, wine, hotel-dining, and cafe demos.

### Phase 4: Manager/Internal Shift Cockpit Lane

Add a manager-facing restaurant tool pattern centered on current-shift context,
attention queues, live operations cards, and in-place actions.

### Phase 5: Mobile Command Vocabulary

Document and test phone-safe request verbs: status, why, submit idea, approve
plan, reject plan, resume safe, audit package, and notification mute/snooze.

### Phase 6: Generated Plan Approval Flow

Require phone approvals to operate on generated plans with scope, risk, budget,
rollback, expiry, and idempotency evidence.

### Phase 7: Heartbeat, Lease, and Recovery Hardening

Clarify unattended run heartbeats, leases, stale-state behavior, and recovery
classes.

### Phase 8: Rate Governor and Budget State

Treat rate limits and model budget as first-class scheduling state. Keep manual
low-token mode honest until automatic detection exists.

### Phase 9: Summarized Test Report

Add a concise stage/scenario test summary to audit evidence while preserving
full logs.

### Phase 10: Captain Quick Start

Write a short controlled-use guide for status, audits, fixture checks, stop
rules, and prohibited actions.

### Phase 11: Controlled-Use Rehearsal

Define a fixture-only rehearsal for status, audit packaging, mobile request
capture, low-budget landing, heartbeat classification, and readiness scoring.

### Phase 12: Product Launch Checklist

Create the lane-specific checklist required before any real product ship is
selected for controlled autonomy.

### Phase 13: Edge-Case Fixture Expansion

Add or document mixed overnight/mobile/product-quality edge cases for future
stress tests.

## Non-Goals

- Do not implement a public mobile app or network service.
- Do not enable automatic provider-side rate-limit detection unless explicitly
  implemented and tested in a later task.
- Do not run product ships.
- Do not edit product repos.
- Do not merge, push, deploy, publish, or create pull requests.
- Do not delete locks, stop requests, generated product work, or user files.

## Acceptance

Stage 15 is ready to continue when:

- the research synthesis maps every report into durable rules
- each hardening task has a clear target, guardrail, and proof path
- tests or focused checks exist for any behavior change
- product-specific work still requires explicit ship selection and captain
  approval

