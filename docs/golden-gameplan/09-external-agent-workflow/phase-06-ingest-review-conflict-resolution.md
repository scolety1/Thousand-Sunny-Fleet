# Stage 9 Phase 6 Prompt: Ingest Review And Conflict Resolution

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 9 Phase 6 only: Ingest Review and Conflict Resolution.

Goal:
Define how the fleet reviews external task packets before ingestion.

The ingest review should check:
- audit package ID matches
- ship exists
- base commit is current or safely reconcilable
- task IDs are unique
- task contract fields are complete
- scope is allowed
- risk level is correct
- acceptance/proof are concrete
- no forbidden files or systems are touched
- no task duplicates existing queue work

Conflict resolution should handle:
- two agents recommending opposite changes
- stale packet
- packet for wrong ship
- high-risk suggestion
- vague task
- task too large
- product-taste disagreement

Guardrails:
- Do not ingest invalid packets.
- Do not silently rewrite dangerous tasks.
- Do not accept broad redesigns without captain approval.
- Do not let external agents bypass Stage 4 validation.

Acceptance:
- Ingest review rules exist.
- Conflict outcomes are documented.
- Accepted/rejected/deferred reasons are machine-readable in principle.

Proof:
Show conflict examples and expected outcomes.
```

## Notes

This is the firewall between outside advice and fleet execution.

## Implementation Status

Status: GREEN

Implemented as local validation and comparison behavior only. Stage 9 does not ingest packets; accepted candidates still go through Stage 4 validation before import.
