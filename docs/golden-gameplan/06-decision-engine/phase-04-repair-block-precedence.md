# Stage 6 Phase 4 Prompt: Repair And Block Precedence

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 6 Phase 4 only: Repair and Block Precedence.

Goal:
Harden the decision engine so failed or unsafe ships cannot accidentally choose RUN_AGAIN.

Precedence rules:
- security/sensitive-system violation => BLOCK
- dependency/package/backend/auth/payment/deployment changes without approval => BLOCK
- build/test/runtime failure with known bounded repair task => REPAIR
- build/test/runtime failure without repair task => BLOCK
- dirty repo with no active owner => BLOCK or REPAIR
- active dirty repo with fresh PID/heartbeat => NOOP
- quarantined tasks present => REPAIR
- repeated repair failure over budget => BLOCK

Guardrails:
- Do not create repair tasks yet unless this already exists as a safe no-op fixture behavior.
- Do not launch repair runs.
- Do not delete locks.
- Do not manually clean dirty repos.

Acceptance:
- Tests prove failures override RUN_AGAIN.
- Tests prove active dirty work chooses NOOP.
- Tests prove repeated failed repair chooses BLOCK.
- Decision reasons are specific enough for a human to understand.

Proof:
Show repair/block test cases and output.
```

## Notes

This phase is the fake-confidence-soup guardrail. If deterministic gates fail, the fleet must not keep pretending things are fine.

## Implementation Status

Status: GREEN

Evidence:
- `tools/codex-fleet-decision.ps1`
- `tests/run-fleet-tests.ps1`

Verification:
- Failed deterministic gates with a repair path choose `REPAIR`.
- Failed deterministic gates without a repair path choose `BLOCK`.
- Active dirty/running ships choose `NOOP`.
- Tests prove failure precedence overrides `RUN_AGAIN`.
