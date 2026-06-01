# Stage 5 Phase 8 Prompt: Stage 5 Integration Check

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 5 Phase 8 only: Stage 5 Integration Check.

Goal:
Verify the state machine end to end without enabling autonomous decisions.

Run a focused integration check that:
- creates or uses fixture ships
- writes valid state
- rejects invalid state
- classifies READY, RUNNING, BLOCKED, TASTE_GATE, RATE_LIMIT_PAUSED, PARKED, and UNKNOWN scenarios
- generates fleet-level status
- generates per-ship CURRENT_STATE.md
- proves no auto-rerun behavior occurs

Guardrails:
- Do not launch real product ships.
- Do not change downstream app code.
- Do not implement Stage 6 decision engine.
- Do not create long-running loops.

Acceptance:
- Stage 5 tests pass.
- State files are generated.
- State classification is deterministic.
- Reports are readable.
- No scripts auto-launch ships as part of state classification.

Proof:
Provide:
- test command output
- generated state file paths
- sample status output
- known limitations before Stage 6
```

## Notes

This is the final checkpoint before the decision engine stage.

## Implementation Status

Status: GREEN

Evidence:

- valid state update succeeds
- invalid state update fails
- canonical state scenarios classify deterministically
- fleet-level and per-ship state files generate
- readable and JSON reports generate
- no auto-rerun behavior was introduced
- `.\tests\run-fleet-tests.ps1` passed
