# Stage 6 Phase 6 Prompt: Park, Taste Gate, And Wait Rules

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 6 Phase 6 only: Park, Taste Gate, and Wait Rules.

Goal:
Teach the decision engine to stop gracefully when more coding is not the right next action.

Decision rules:

PARK when:
- done contract is met
- no valid tasks remain
- repo is clean
- latest gates pass
- ship is intentionally idle

USER_TASTE_GATE when:
- deterministic gates pass
- product appears usable enough for human review
- remaining issues are subjective visual style, copy tone, or product taste
- no clear objective task remains

WAIT_FOR_EXTERNAL_AUDIT when:
- audit package exists
- external review is required
- no task packet has been accepted yet

WAIT_FOR_TASK_PACKET when:
- no valid tasks remain
- the ship is not done enough to park
- an external/captain task packet is the intended next input

WAIT_FOR_RATE_RESET when:
- rate-limit pause state is active
- budget is below threshold
- safe close has been requested

Guardrails:
- Do not auto-resume after rate reset in this phase.
- Do not call poor output done just because gates pass.
- Do not over-polish past taste gate.

Acceptance:
- Tests cover PARK, USER_TASTE_GATE, WAIT_FOR_EXTERNAL_AUDIT, WAIT_FOR_TASK_PACKET, and WAIT_FOR_RATE_RESET.
- Decision reasons clearly explain what the human should do next.

Proof:
Show wait/park/taste decision examples and tests.
```

## Notes

This phase is about saving limits and reducing endless churn.

## Implementation Status

Status: GREEN

Evidence:
- `Resolve-FleetDecision`
- `tests/run-fleet-tests.ps1`

Verification:
- Tests cover `PARK`, `USER_TASTE_GATE`, `WAIT_FOR_EXTERNAL_AUDIT`, `WAIT_FOR_TASK_PACKET`, and `WAIT_FOR_RATE_RESET`.
- Decision reasons explain whether the captain should leave a ship parked, provide taste direction, send an audit package, import a task packet, or wait for rate-limit reset evidence.
- No wait/park/taste decision mutates state or executes work in Stage 6.
