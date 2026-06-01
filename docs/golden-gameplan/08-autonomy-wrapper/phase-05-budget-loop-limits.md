# Stage 8 Phase 5 Prompt: Budget And Loop Limits

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 8 Phase 5 only: Budget and Loop Limits.

Goal:
Guarantee the autonomy wrapper cannot run forever or drain limits accidentally.

Add budget settings for:
- max cycles
- max runtime minutes
- max ships
- max run batches per ship
- max repair attempts
- max audit packages
- max task packet imports
- low-token mode
- stop-before-rate-limit threshold placeholder

Required behavior:
- max cycles defaults to 1
- run batches require explicit allow flag
- low-token mode blocks implementation runs
- exhausted budget produces report and stops
- rate-limit paused decision produces WAIT/REPORT, not retry storm

Guardrails:
- Do not implement automatic rate reset detection here.
- Do not schedule future runs.
- Do not create heartbeat automation.
- Do not ignore explicit safe-stop requests.

Acceptance:
- Budget defaults are safe.
- Budget exhaustion is reported.
- Low-token mode prevents run actions.
- Tests cover max cycle and max repair limits.

Proof:
Show budget examples and tests.
```

## Notes

Stage 10 will handle overnight rate-limit recovery. Stage 8 only prevents accidental drains.

## Implementation Status

Status: GREEN

`New-FleetAutonomyBudget` defines conservative budgets. `invoke-autonomy-wrapper.ps1` requires `MaxCycles = 1`, records budget usage, blocks low-token implementation runs, and never schedules future resumes.
