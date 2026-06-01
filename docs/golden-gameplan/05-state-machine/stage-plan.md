# Golden Gameplan Stage 5: State Machine

## Purpose

Stage 5 gives every ship a shared lifecycle language.

The fleet should stop guessing from scattered terminals, locks, dirty files, and Markdown notes. It should be able to say, in a machine-readable way:

```text
This ship is running.
This ship is blocked.
This ship is waiting for external audit.
This ship is safe to park.
This ship is paused for rate limits.
```

This stage does **not** make autonomous rerun decisions yet. It records the truth cleanly so Stage 6 can make decisions from reliable state.

## Why This Matters

The fleet has failed or stalled in predictable ways:

- A ship looked done but only stopped early.
- A ship looked failed but was actually active and dirty.
- A ship had useful output but no obvious next state.
- A ship was waiting for review, but the fleet treated it like a generic stop.
- Rate-limit situations were not represented as a first-class status.

The state machine fixes this by making ship status explicit, finite, and testable.

## Stage 5 Outcome

At the end of Stage 5, the fleet should have:

- A canonical state schema.
- A fleet-level state file.
- Per-ship current state files.
- A reader/writer for state updates.
- Supervisor classification that maps observed repo/run conditions into states.
- Transition rules that describe legal state changes.
- Reports that show state clearly to the captain.

## Non-Goals

Do not implement these in Stage 5:

- Auto-rerun logic.
- External task packet decisions.
- Full overnight restart behavior.
- Taste decisions.
- Model budget policy.
- Website quality scoring.
- Merges, pushes, or deployment.

Those belong to later stages.

## Canonical States

Use these states unless implementation discovers a strong reason to adjust them:

```text
UNKNOWN
READY
RUNNING
REVIEWING
AUDIT_READY
PACKET_READY
REPAIRING
BLOCKED
TASTE_GATE
RATE_LIMIT_PAUSED
PARKED
ARCHIVED
```

## State Meanings

`UNKNOWN`

The fleet cannot confidently classify the ship. This should be temporary and should trigger better evidence collection, not a launch.

`READY`

The ship has valid tasks, passes preflight, and is eligible to run.

`RUNNING`

The ship has an active owned process, active lock, or fresh heartbeat showing implementation work.

`REVIEWING`

The ship completed a run and is being reviewed by local gates or human/external review.

`AUDIT_READY`

The ship produced enough evidence for an audit package and is waiting for external or human review.

`PACKET_READY`

A valid task packet has been imported and the ship has accepted next tasks.

`REPAIRING`

The ship has a known failure and a bounded repair path.

`BLOCKED`

The ship cannot continue safely without human attention or a missing input.

`TASTE_GATE`

The deterministic gates pass, but remaining work is subjective product/design/copy taste.

`RATE_LIMIT_PAUSED`

The ship should be safely paused because model budget is too low or rate-limit recovery is pending.

`PARKED`

The ship is intentionally idle and should not be relaunched without a new command or accepted packet.

`ARCHIVED`

The ship is out of active scope.

## Phase List

1. State Schema
2. Current State Files
3. State Reader and Writer
4. Supervisor Classification
5. Transition Rules
6. State Reporting
7. Backward Compatibility
8. Stage 5 Integration Check

## Acceptance For Stage 5

Stage 5 is complete when:

- State files can be generated without launching ships.
- Every selected fixture ship can be classified into one canonical state.
- State classification is deterministic from available evidence.
- Unknown states are reported clearly.
- Stage 5 tests pass.
- No auto-rerun behavior has been introduced.

## Hand-Off To Stage 6

Stage 6 will use these state files to decide:

```text
RUN_AGAIN
REPAIR
PARK
USER_TASTE_GATE
WAIT_FOR_PACKET
WAIT_FOR_RATE_RESET
```

Stage 5 should make those decisions possible, but it should not make them itself.

