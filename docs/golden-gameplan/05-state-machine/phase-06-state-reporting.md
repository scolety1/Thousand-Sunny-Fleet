# Stage 5 Phase 6 Prompt: State Reporting

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 5 Phase 6 only: State Reporting.

Goal:
Make ship state easy for the captain to read quickly.

Update or add reporting so the fleet can print:
- each selected ship
- current state
- short reason
- last run result
- blockers
- next safe human action
- whether the ship is safe to inspect
- whether the ship is unsafe to touch because an active PID owns the work

Outputs may include:
- fleet/status/current.md
- fleet/status/current.json
- terminal summary from fleet-status.ps1 or supervisor scripts
- per-ship CURRENT_STATE.md updates

Guardrails:
- Reporting must not launch, stop, patch, or requeue ships.
- Keep the summary concise.
- Do not hide UNKNOWN or BLOCKED states.
- Do not call a ship done just because it is stopped.

Acceptance:
- A status command shows state for selected fixture ships.
- Active dirty ships are clearly marked unsafe to touch.
- Audit-ready ships are clearly marked ready for review, not necessarily done.
- Parked ships are clearly marked intentionally idle.

Proof:
Show sample status output.
```

## Notes

This phase should make "how are the ships doing?" answerable without detective work.

## Implementation Status

Status: GREEN

Evidence:

- `fleet-state.ps1 -Action Report`
- `fleet/status/current.md`
- `fleet/status/current.json`
- `docs/codex/CURRENT_STATE.md`
- `.\tests\run-fleet-tests.ps1` passed
