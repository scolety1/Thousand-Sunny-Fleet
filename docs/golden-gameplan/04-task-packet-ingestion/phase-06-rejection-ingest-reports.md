# Stage 4 Phase 6: Rejection and Ingest Reports

## Goal

Write clear reports showing which packet tasks were accepted, rejected, or
skipped and why.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 4 Phase 6 only: Rejection and ingest reports.

Do not implement any other Golden Gameplan phase.

Goal:
Make packet ingestion auditable. Every ingest attempt should produce a readable
Markdown report and a machine-readable JSON report.

Before editing:
- Run .\fleet-status.ps1.
- Review existing packet validation and queue append behavior.

Scope:
- Likely files: ingest-task-packet.ps1, tests/run-fleet-tests.ps1.
- Do not add decision automation.

Reports should include:
- packet ID
- audit ID
- target ship
- base commit
- ingest mode: dry-run/apply
- accepted tasks
- rejected tasks
- rejection reasons
- queue file touched or not touched
- current HEAD
- warnings

Acceptance:
- Add tests that reports are written for accepted packet.
- Add tests that reports are written for rejected packet.
- Add tests that queue remains unchanged when packet is rejected.
- Add tests that machine report parses as JSON.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/04-task-packet-ingestion/checkpoint.md.

Stop if:
- Report locations conflict with Stage 3 package layout. Keep reports local and
  document paths for Stage 5/6.
```

## Done When

Every packet leaves a paper trail, even when rejected.

