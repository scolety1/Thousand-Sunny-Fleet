# Stage 5 Phase 4 Prompt: Supervisor Classification

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 5 Phase 4 only: Supervisor Classification.

Goal:
Teach the supervisor to classify observed ship conditions into canonical states.

Classification should inspect existing evidence such as:
- active process / PID
- lock file
- heartbeat freshness
- git status
- task queue
- quarantined tasks
- RUN_RESULT.json
- audit package presence
- task packet presence
- safe-stop requests
- rate-limit notes
- latest build/test/runtime/review gates

Suggested classification rules:
- active fresh PID or heartbeat => RUNNING
- valid imported packet + accepted tasks => PACKET_READY
- latest run completed + audit package exists + no accepted packet yet => AUDIT_READY
- failed deterministic gate + repair task exists => REPAIRING
- failed deterministic gate + no safe repair path => BLOCKED
- deterministic gates pass + subjective notes remain => TASTE_GATE
- low model budget or explicit rate-limit pause => RATE_LIMIT_PAUSED
- clean repo + valid tasks + no blocker => READY
- clean repo + no useful tasks + intentionally idle => PARKED
- ignored/retired ship => ARCHIVED
- uncertain evidence => UNKNOWN

Guardrails:
- Classification only records status.
- Do not relaunch, stop, kill, delete locks, or patch ships from this phase.
- If evidence conflicts, prefer safer states: RUNNING over READY, BLOCKED over READY, UNKNOWN over guessing.

Acceptance:
- Supervisor can classify at least five fixture ship scenarios.
- Conflicting evidence produces a conservative state.
- Active dirty ships remain RUNNING or UNKNOWN, not READY.
- Focused tests pass.

Proof:
Show a classification table with input condition and resulting state.
```

## Notes

This is where the fleet starts becoming understandable. It still should not act automatically.

## Implementation Status

Status: GREEN

Evidence:

- `Resolve-FleetShipStateFromEvidence`
- fixture tests for `READY`, `RUNNING`, `BLOCKED`, `TASTE_GATE`, `RATE_LIMIT_PAUSED`, `PARKED`, `UNKNOWN`, `AUDIT_READY`, `PACKET_READY`, `REPAIRING`, and `ARCHIVED`
- active/dirty evidence maps conservatively and does not become `READY`
- `.\tests\run-fleet-tests.ps1` passed
