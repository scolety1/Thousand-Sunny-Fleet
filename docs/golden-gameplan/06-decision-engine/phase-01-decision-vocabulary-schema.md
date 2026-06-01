# Stage 6 Phase 1 Prompt: Decision Vocabulary And Schema

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 6 Phase 1 only: Decision Vocabulary and Schema.

Goal:
Define the canonical decision outputs for Codex Fleet without executing them yet.

Required decision values:
- NOOP
- RUN_AGAIN
- REPAIR
- PACKAGE_AUDIT
- WAIT_FOR_EXTERNAL_AUDIT
- WAIT_FOR_TASK_PACKET
- USER_TASTE_GATE
- WAIT_FOR_RATE_RESET
- PARK
- BLOCK
- ARCHIVE

Create a decision schema that supports:
- ship name
- current state
- decision
- reason
- confidence
- evidence paths
- required human action
- allowed next commands
- forbidden next commands
- budget notes
- safety notes
- generated timestamp

Guardrails:
- Do not launch ships.
- Do not repair ships.
- Do not ingest task packets.
- Do not implement long-running loops.
- Do not touch downstream product code.

Acceptance:
- Decision schema exists.
- Each decision value is documented.
- Validation examples cover at least NOOP, RUN_AGAIN, REPAIR, USER_TASTE_GATE, WAIT_FOR_RATE_RESET, PARK, and BLOCK.
- Focused tests or schema validation examples pass.

Proof:
Report schema path, decision examples, and validation output.
```

## Notes

This phase creates the vocabulary. Later phases use it.

## Implementation Status

Status: GREEN

Evidence:
- `templates/decision-schema.json`
- `tools/codex-fleet-decision.ps1`
- `tests/run-fleet-tests.ps1`

Verified decisions:
- `NOOP`
- `RUN_AGAIN`
- `REPAIR`
- `PACKAGE_AUDIT`
- `WAIT_FOR_EXTERNAL_AUDIT`
- `WAIT_FOR_TASK_PACKET`
- `USER_TASTE_GATE`
- `WAIT_FOR_RATE_RESET`
- `PARK`
- `BLOCK`
- `ARCHIVE`
