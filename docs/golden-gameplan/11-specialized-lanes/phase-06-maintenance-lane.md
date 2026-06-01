# Stage 11 Phase 6 Prompt: Maintenance Lane

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 11 Phase 6 only: Maintenance Lane.

Goal:
Define the low-cost lane for routine cleanup, bug patches, docs upkeep, and small repairs.

This lane covers:
- small bug fixes
- docs cleanup
- report cleanup
- stale file detection
- fixture repair
- low-token status work
- test harness upkeep
- non-product polish only when specific

Required priorities:
- small diff
- specific issue
- clear proof
- cheap model mode
- no broad redesign
- no feature expansion
- no churn

Required evidence:
- issue fixed
- files changed
- test or check command
- before/after note
- reason it stayed small

Forbidden by default:
- broad copy rewrites
- new product features
- large visual redesigns
- dependency updates unless explicitly maintenance-approved
- "polish" without concrete target

Guardrails:
- Do not edit real maintenance tasks in this phase.
- Do not use premium models by default in this lane.
- Do not let maintenance become hidden product work.

Acceptance:
- Maintenance lane profile exists.
- It defines low-token/default model behavior.
- It includes examples of valid and invalid maintenance tasks.

Proof:
Show profile path and examples.
```

## Notes

This lane helps reduce rate burn and stops small chores from becoming expeditions.

## Implementation Status

Status: GREEN

Implemented as lane ID `maintenance` with cheap budget defaults, small-diff
evidence, focused tests, and escalation when the request grows into broad
product redesign.
