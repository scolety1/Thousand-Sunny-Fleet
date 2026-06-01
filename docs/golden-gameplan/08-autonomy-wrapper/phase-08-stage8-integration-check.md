# Stage 8 Phase 8 Prompt: Stage 8 Integration Check

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 8 Phase 8 only: Stage 8 Integration Check.

Goal:
Verify the bounded autonomy wrapper works end to end without becoming an overnight loop.

Test scenarios:
- dry-run only
- selected fixture ships
- RUN_AGAIN decision with run action disabled
- RUN_AGAIN decision with one bounded batch allowed
- PACKAGE_AUDIT decision
- USER_TASTE_GATE decision
- WAIT_FOR_RATE_RESET decision
- BLOCK decision
- dirty active ship NOOP
- invalid scope failure
- budget exhaustion

Guardrails:
- Use fixture ships or safe test projects only.
- Do not launch real product ships.
- Do not touch downstream product code.
- Do not implement Stage 9 external agent workflow.
- Do not implement Stage 10 overnight scheduling.

Acceptance:
- Stage 8 tests pass.
- Wrapper stops after configured max cycles.
- Reports are produced.
- No implicit all-fleet launch is possible.
- No unbounded loop is possible.

Proof:
Provide:
- test command output
- dry-run report path
- bounded-cycle report path
- known limitations before Stage 9
```

## Notes

This is the point where the fleet gets a useful autopilot, not a runaway one.

## Implementation Status

Status: GREEN

`.\tests\run-fleet-tests.ps1` passes with Stage 8 fixture coverage for dry-run, explicit selected scope, `RUN_AGAIN` with run disabled, `RUN_AGAIN` with one bounded action approved, `PACKAGE_AUDIT`, `USER_TASTE_GATE`, low-token blocking, invalid scope failure, and max-cycle enforcement.
