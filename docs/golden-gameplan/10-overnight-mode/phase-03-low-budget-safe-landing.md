# Stage 10 Phase 3 Prompt: Low-Budget Safe Landing

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 10 Phase 3 only: Low-Budget Safe Landing.

Goal:
Define what the fleet does when budget reaches the safe-landing threshold.

Safe landing should:
- stop launching new work
- stop generating new tasks
- request safe stop for selected ships
- allow active bounded unit to finish only if safe
- write RUN_RESULT or partial evidence
- write CURRENT_STATE
- mark eligible ships RATE_LIMIT_PAUSED
- package audit if cheap and useful
- write resume metadata
- write captain summary

Safe landing must not:
- kill active work abruptly unless existing safe-stop process supports it
- delete locks manually
- clean dirty repos
- start repairs
- start new implementation tasks
- call external agents

Required report:
- why safe landing triggered
- budget signal used
- ships paused
- ships blocked
- ships already parked
- what can resume
- what needs human attention

Guardrails:
- Do not implement actual process control yet unless explicitly running this phase later.
- Do not touch downstream product repos.
- Do not hide partial failures.

Acceptance:
- Safe landing flow is documented.
- RATE_LIMIT_PAUSED state integration is specified.
- Resume metadata requirements are defined.

Proof:
Show flow doc and sample safe-landing report.
```

## Notes

This is the parachute. It should fire before panic.

## Implementation Status

Status: GREEN

Implemented by `New-FleetSafeLandingPlan` and `invoke-overnight-mode.ps1`.
Critical budget produces `SAFE_LANDING`, writes resume metadata, and produces a
captain-readable report without deleting locks or cleaning repos.
