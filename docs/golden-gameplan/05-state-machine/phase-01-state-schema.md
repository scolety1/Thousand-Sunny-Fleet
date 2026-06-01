# Stage 5 Phase 1 Prompt: State Schema

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 5 Phase 1 only: State Schema.

Goal:
Define the canonical machine-readable state schema for Codex Fleet ships.

Context:
Stage 5 is the truth layer. It records ship status. It must not make autonomous run decisions yet.

Create or update docs and schema files only as needed for this phase.

Required state values:
- UNKNOWN
- READY
- RUNNING
- REVIEWING
- AUDIT_READY
- PACKET_READY
- REPAIRING
- BLOCKED
- TASTE_GATE
- RATE_LIMIT_PAUSED
- PARKED
- ARCHIVED

The schema should support:
- ship name
- status
- previous status
- phase or lane
- risk tier
- active PID if known
- lock status
- heartbeat freshness
- repo cleanliness
- tasks remaining
- quarantined tasks
- last run ID
- last run result path
- last audit package path
- last task packet path
- build/test/runtime/visual/copy/design/formula gate summaries
- rate-limit pause metadata
- blocker reasons
- taste gate reasons
- updated timestamp
- evidence paths

Guardrails:
- Do not implement rerun logic.
- Do not launch any ships.
- Do not modify real product repositories.
- Do not change task queues except test fixtures if needed.
- Keep the schema small enough to be readable.

Acceptance:
- A schema file exists for ship state.
- The schema documents required and optional fields.
- Tests or validation examples cover at least READY, RUNNING, BLOCKED, TASTE_GATE, RATE_LIMIT_PAUSED, and PARKED.
- `.\run-fleet-tests.ps1` passes or the relevant focused test command passes.

Proof:
Report the schema path, validation examples, and test command output.
```

## Notes

This phase should create the state vocabulary before any scripts depend on it.

## Implementation Status

Status: GREEN

Evidence:

- `templates/ship-state-schema.json`
- `templates/ship-state-transition-map.json`
- `tools/codex-fleet-state.ps1`
- `.\tests\run-fleet-tests.ps1` passed
