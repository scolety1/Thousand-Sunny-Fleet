# Stage 6 Phase 3 Prompt: Pure Decision Function

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 6 Phase 3 only: Pure Decision Function.

Goal:
Create the deterministic function or script that maps normalized input to a decision object.

The function should be pure:
- same input produces same output
- no ship launches
- no file mutations except optional dry-run output/report files
- no task queue edits
- no process kills

Inputs:
- normalized decision input from Phase 2

Outputs:
- decision object from Phase 1 schema

Required behavior:
- active owned work => NOOP
- explicit archive => ARCHIVE
- explicit safe stop/park => PARK or NOOP depending active work
- rate-limit pause => WAIT_FOR_RATE_RESET
- deterministic failure with repair path => REPAIR
- deterministic failure without repair path => BLOCK
- completed run with no audit package => PACKAGE_AUDIT
- audit package ready with no packet => WAIT_FOR_EXTERNAL_AUDIT
- no valid tasks and no packet => WAIT_FOR_TASK_PACKET or PARK depending done evidence
- taste gate state => USER_TASTE_GATE
- ready with valid tasks and budget => RUN_AGAIN

Guardrails:
- Repair and block must override run again.
- Unknown evidence must never produce RUN_AGAIN unless an explicit safe default says so.
- Do not implement execution of the decision.

Acceptance:
- Unit tests cover every canonical decision.
- Decision output includes reason and evidence paths.
- Unknown or conflicting input produces BLOCK, NOOP, or WAIT, not unsafe RUN_AGAIN.

Proof:
Show test command output and a decision matrix.
```

## Notes

This is the core of Stage 6. Keep it easy to test.

## Implementation Status

Status: GREEN

Evidence:
- `tools/codex-fleet-decision.ps1`
- `Resolve-FleetDecision`
- `tests/run-fleet-tests.ps1`

Verification:
- `Resolve-FleetDecision` returns structured decisions with reason, confidence, evidence, human-action guidance, allowed next commands, forbidden next commands, budget notes, and safety notes.
- Tests cover every canonical decision and prove unknown or conflicting input falls back conservatively.
- The function is pure/advisory: it does not launch, mutate queues, delete locks, or touch product repos.
