# Stage 4 Phase 3: Packet Validator

## Goal

Validate task packets before any task queue changes.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 4 Phase 3 only: Packet validator.

Do not implement any other Golden Gameplan phase.

Goal:
Add validation logic for external task packets. Invalid packets should produce a
clear rejection report and make no queue changes.

Before editing:
- Run .\fleet-status.ps1.
- Review schema and storage conventions from Phases 1-2.

Scope:
- Likely files: import-task-packet.ps1 or ingest-task-packet.ps1,
  tests/run-fleet-tests.ps1.
- Validation only; do not append tasks yet.

Validation checks:
- packet parses as JSON
- required fields exist
- packet ID is unique
- audit ID exists or is marked external/manual
- target project exists in projects.json
- base commit matches current ship HEAD unless dry-run or override mode
- tasks array is non-empty unless packet intentionally parks/no-ops
- every task has ID, title, and checklistLine
- forbidden scopes are rejected

Acceptance:
- Add tests for valid packet validation.
- Add tests for invalid JSON.
- Add tests for unknown project.
- Add tests for stale base commit.
- Add tests for duplicate packet ID.
- Add tests for forbidden scope rejection.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/04-task-packet-ingestion/checkpoint.md.

Stop if:
- Base commit checks are impossible because Stage 2/3 evidence lacks commit data.
  Document dependency and implement the rest in dry-run-only mode.
```

## Done When

The fleet can say yes/no to a packet before touching any task queue.

