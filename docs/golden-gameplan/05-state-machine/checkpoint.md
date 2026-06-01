# Stage 5 Checkpoint

Use this checklist before moving to Stage 6.

## Required Docs

- [x] `stage-plan.md`
- [x] `phase-01-state-schema.md`
- [x] `phase-02-current-state-files.md`
- [x] `phase-03-state-writer-reader.md`
- [x] `phase-04-supervisor-classification.md`
- [x] `phase-05-transition-rules.md`
- [x] `phase-06-state-reporting.md`
- [x] `phase-07-backward-compatibility.md`
- [x] `phase-08-stage5-integration-check.md`
- [x] `audit-prompt.md`
- [x] `checkpoint.md`

## Implementation Completion Criteria

- [x] Canonical state schema exists.
- [x] Fleet-level state file can be generated.
- [x] Per-ship current state file can be generated.
- [x] Valid states are accepted.
- [x] Invalid states are rejected.
- [x] Supervisor can classify fixture ship states.
- [x] Unknown/conflicting evidence is handled conservatively.
- [x] State reporting is readable.
- [x] Stage 5 tests pass.
- [x] No automatic rerun or repair decisions were introduced.

## States To Prove

- [x] `UNKNOWN`
- [x] `READY`
- [x] `RUNNING`
- [x] `REVIEWING`
- [x] `AUDIT_READY`
- [x] `PACKET_READY`
- [x] `REPAIRING`
- [x] `BLOCKED`
- [x] `TASTE_GATE`
- [x] `RATE_LIMIT_PAUSED`
- [x] `PARKED`
- [x] `ARCHIVED`

## Red Flags

Do not move to Stage 6 if:

- State classification launches ships.
- Stopped ships are automatically treated as done.
- Active dirty ships are treated as safe to touch.
- Rate-limit conditions are invisible.
- Missing legacy files crash the supervisor.
- The state schema is only Markdown and has no machine-readable representation.
- The reporting is too vague to use from a phone.

## Stage 6 Readiness Statement

Before Stage 6 begins, write a short note answering:

```text
Can the decision engine trust the state files?
What states are still ambiguous?
Which tests prove the state machine is safe?
```

## Stage 5 Result

Status: GREEN

Stage 5 is implemented as a truth/reporting layer only. It added a canonical
state schema, transition map, state reader/writer helpers, deterministic
classification helpers, a `fleet-state.ps1` command, generated fleet/per-ship
state files, and focused tests. It did not add automatic rerun, repair,
decision-engine, merge, push, deploy, product-ship launch, or lock-deletion
behavior.

Evidence:

```text
Schema: templates/ship-state-schema.json
Transition map: templates/ship-state-transition-map.json
Command: fleet-state.ps1
Helper: tools/codex-fleet-state.ps1
Fleet state: fleet/state/ship-state.json
Fleet report: fleet/status/current.md
Fleet report JSON: fleet/status/current.json
Harness current state: docs/codex/CURRENT_STATE.md
Tests: .\tests\run-fleet-tests.ps1 passed
```

Stage 6 readiness:

```text
Can the decision engine trust the state files?
Yes for Stage 6 dry-run decision work. State values are finite, validated, and
serializable, and invalid states/transitions are rejected.

What states are still ambiguous?
Real active-process heartbeat freshness remains conservative because Stage 5
does not own process control. Ambiguous or missing legacy evidence maps to
UNKNOWN or BLOCKED instead of READY.

Which tests prove the state machine is safe?
The Stage 5 focused tests validate all canonical states, valid/invalid state
updates, legal/illegal transitions, classification scenarios, missing legacy
repo behavior, state reports, and per-ship CURRENT_STATE generation.
```
