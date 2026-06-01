# Stage 5 Phase 3 Prompt: State Reader And Writer

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 5 Phase 3 only: State Reader and Writer.

Goal:
Add a small, deterministic way to read and write ship state.

Build a script or helper that can:
- load fleet/state/ship-state.json
- update one ship's state
- write per-ship CURRENT_STATE.md
- preserve unknown fields when possible
- validate status values against the state schema
- refuse invalid states
- record last updated timestamp

Inputs should allow:
- ship name
- status
- previous status
- reason
- evidence paths
- blocker notes
- gate summaries

Guardrails:
- Do not auto-classify ships in this phase.
- Do not auto-rerun ships.
- Do not edit TASK_QUEUE.md.
- Do not launch ships.
- Keep writes atomic enough to avoid corrupt state files.

Acceptance:
- A valid state update succeeds.
- An invalid state update fails with a clear error.
- Updating one ship does not erase other ships.
- CURRENT_STATE.md is regenerated in a readable format.
- Focused tests pass.

Proof:
Show commands used for valid and invalid updates and the resulting fixture state files.
```

## Notes

This is plumbing. Keep it boring and reliable.

## Implementation Status

Status: GREEN

Evidence:

- `fleet-state.ps1`
- `Set-FleetShipState`
- `Read-FleetShipStateFile`
- invalid state update test rejects `DONEISH`
- `.\tests\run-fleet-tests.ps1` passed
