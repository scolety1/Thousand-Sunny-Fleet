# Golden Gameplan Stage 6: Decision Engine

## Purpose

Stage 6 turns the Stage 5 state machine into clear next-action decisions.

Stage 5 answers:

```text
What state is this ship in?
```

Stage 6 answers:

```text
Given that state and the latest evidence, what should the fleet do next?
```

This stage should still be bounded. The decision engine may recommend or output an action, but it should not create an endless autonomous loop by itself.

## Why This Matters

The fleet has often stalled because a stopped ship needed interpretation:

- Did it finish?
- Did it fail?
- Does it need repair?
- Should it wait for taste feedback?
- Should it package an audit?
- Should it run again?
- Should it pause because limits are low?

The decision engine makes that interpretation deterministic and testable.

## Stage 6 Outcome

At the end of Stage 6, the fleet should have:

- A canonical decision vocabulary.
- A pure decision function or script.
- Decision inputs from Stage 2-5 evidence.
- Repair-first precedence rules.
- Park and taste-gate rules.
- Rate-limit pause decisions.
- Decision reports for the captain.
- Tests proving each decision path.

## Non-Goals

Do not implement these in Stage 6:

- Full overnight auto-resume.
- Mobile captain console.
- External agent orchestration.
- Continuous relaunch loops.
- Website taste scoring beyond using existing gates.
- Merges, pushes, or deployment.

Stage 6 should decide. Later stages decide how to execute those decisions over long periods.

## Canonical Decisions

Use these decision outputs unless implementation discovers a strong reason to adjust them:

```text
NOOP
RUN_AGAIN
REPAIR
PACKAGE_AUDIT
WAIT_FOR_EXTERNAL_AUDIT
WAIT_FOR_TASK_PACKET
USER_TASTE_GATE
WAIT_FOR_RATE_RESET
PARK
BLOCK
ARCHIVE
```

## Decision Meanings

`NOOP`

No action should be taken because the ship is active or the evidence is not ready.

`RUN_AGAIN`

The ship is ready, has valid tasks, has budget, and should run another bounded batch.

`REPAIR`

A deterministic failure exists and a bounded repair task should be created or run.

`PACKAGE_AUDIT`

The ship has completed a run and needs an audit package before new planning.

`WAIT_FOR_EXTERNAL_AUDIT`

An audit package exists and the fleet is waiting for outside review.

`WAIT_FOR_TASK_PACKET`

The fleet has no accepted next tasks and should wait for a task packet or captain direction.

`USER_TASTE_GATE`

Deterministic gates pass, but the remaining decision is subjective design/product taste.

`WAIT_FOR_RATE_RESET`

The fleet should stop safely because model budget is too low or rate-limit reset is pending.

`PARK`

The ship is done enough or intentionally idle.

`BLOCK`

The ship cannot proceed safely without human intervention.

`ARCHIVE`

The ship should be removed from active consideration by explicit instruction.

## Decision Precedence

The decision engine should follow conservative precedence:

1. Emergency stop or explicit park/archive.
2. Active running work.
3. Sensitive-system or safety violation.
4. Rate-limit pause.
5. Deterministic failure requiring repair.
6. Missing or stale evidence.
7. Audit packaging or external audit wait.
8. Task packet wait.
9. User taste gate.
10. Run again.
11. Park.

## Phase List

1. Decision Vocabulary and Schema
2. Decision Input Normalization
3. Pure Decision Function
4. Repair and Block Precedence
5. Run Again Eligibility
6. Park, Taste Gate, and Wait Rules
7. Decision Reporting
8. Stage 6 Integration Check

## Acceptance For Stage 6

Stage 6 is complete when:

- Every canonical state from Stage 5 maps to at least one safe decision path.
- Failed builds/tests choose `REPAIR` or `BLOCK`, not `RUN_AGAIN`.
- Active dirty ships choose `NOOP`.
- Audit-ready ships choose an audit/wait decision.
- Taste-gate ships choose `USER_TASTE_GATE`.
- Rate-limit paused ships choose `WAIT_FOR_RATE_RESET`.
- Done/idle ships choose `PARK`.
- Tests prove decisions are deterministic.

## Hand-Off To Stage 7

Stage 7 will improve product quality contracts so decisions know when a website or app is actually useful, simple, and ready for taste review.

## Implementation Status

Status: GREEN

Implemented:
- Decision vocabulary and schemas.
- Structured decision input normalization.
- Pure decision function with conservative precedence.
- Report-only decision command.
- Focused Stage 6 tests inside `tests/run-fleet-tests.ps1`.

Verification:
- `.\tests\run-fleet-tests.ps1` passed.
- `.\fleet-decision.ps1 -Action Report` passed.

Stage 6 remains advisory only. It recommends safe next actions; it does not launch, relaunch, repair, ingest packets, merge, push, deploy, delete locks, or touch product repos.
