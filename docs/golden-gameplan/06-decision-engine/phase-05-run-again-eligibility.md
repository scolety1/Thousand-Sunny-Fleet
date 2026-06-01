# Stage 6 Phase 5 Prompt: Run Again Eligibility

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 6 Phase 5 only: Run Again Eligibility.

Goal:
Define exactly when a ship is eligible to run another bounded batch.

RUN_AGAIN should require:
- current state is READY or PACKET_READY
- repo is clean
- no active PID or lock
- valid tasks remain
- no quarantined tasks
- deterministic gates are not failing
- rate limits are not paused
- budget remains
- last run made material progress or a valid new packet exists

RUN_AGAIN should be rejected if:
- tasks are vague or invalid
- only subjective taste remains
- no product/usefulness movement is expected
- the ship is blocked, archived, parked, or rate-limit paused
- a safe-stop request exists

Guardrails:
- Do not execute RUN_AGAIN.
- Do not generate new tasks.
- Do not mutate task queues.

Acceptance:
- Tests show eligible ships choose RUN_AGAIN.
- Tests show invalid/vague/no-op tasks do not choose RUN_AGAIN.
- Decision output explains the accepted task count and budget reason.

Proof:
Show eligibility matrix and tests.
```

## Notes

This prevents the fleet from burning limits on filler loops.

## Implementation Status

Status: GREEN

Evidence:
- `Resolve-FleetDecision`
- `tests/run-fleet-tests.ps1`

Verification:
- `RUN_AGAIN` requires clean repo state, valid remaining tasks, remaining budget, progress/new packet evidence, no quarantine, and `READY` or `PACKET_READY` state.
- Tests prove failed gates override run-again eligibility.
- Stage 6 only recommends `RUN_AGAIN`; execution is reserved for later stages.
