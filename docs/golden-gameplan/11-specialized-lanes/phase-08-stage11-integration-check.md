# Stage 11 Phase 8 Prompt: Stage 11 Integration Check

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 11 Phase 8 only: Stage 11 Integration Check.

Goal:
Verify specialized lane docs and examples are complete.

Check that:
- lane taxonomy exists
- hospitality website profile exists
- manager/internal tool profile exists
- analytical software profile exists
- backend-sensitive profile exists
- maintenance profile exists
- lane selection/escalation rules exist
- audit prompt exists
- checkpoint exists

Fixture scenarios:
- customer-facing restaurant website
- wine list demo
- manager brief tool
- Niners-style formula task
- backend/auth task
- package update task
- maintenance bug patch
- ambiguous task requiring safer lane

Guardrails:
- Do not route real tasks yet.
- Do not launch ships.
- Do not edit downstream repos.
- Do not implement Stage 12 dashboard.

Acceptance:
- Stage 11 docs check passes.
- Each fixture maps to the expected lane.
- Escalation rules block unsafe normal-lane work.
- Readiness notes identify what Stage 12 needs.

Proof:
Show file list, fixture mapping table, and readiness notes.
```

## Notes

This check proves the lane system is coherent before wiring it into the fleet.

## Implementation Status

Status: GREEN

Focused Stage 11 tests live in `Test-GoldenGameplanStageElevenSupport` inside
`tests/run-fleet-tests.ps1`. They use fixture text only and do not route real
tasks or launch ships.
