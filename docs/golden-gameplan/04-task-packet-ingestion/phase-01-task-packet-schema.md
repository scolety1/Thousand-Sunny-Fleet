# Stage 4 Phase 1: Task Packet Schema

## Goal

Define the structured packet format external agents must return.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 4 Phase 1 only: Task packet schema.

Do not implement any other Golden Gameplan phase.

Goal:
Create the task packet schema/template that external agents must follow when
returning tasks from an audit package.

Before editing:
- Run .\fleet-status.ps1.
- Confirm Stage 3 checkpoint is GREEN or explicitly approved to proceed.
- Review Task Contract V2 requirements and Stage 3 prompt outputs.

Scope:
- Add schema/template docs and tests only.
- Likely files: templates/task-packet-schema.json or schemas/task-packet.schema.json,
  tests/run-fleet-tests.ps1, docs/golden-gameplan/04-task-packet-ingestion.
- Do not implement ingestion yet.

Required fields:
- packetId
- auditId
- generatedAt
- project or projects
- baseCommit
- tasks
- task id
- task title
- checklistLine
- optional budget
- optional phase
- optional reviewNotes

Acceptance:
- Add a task packet schema or documented template.
- Add a valid sample packet fixture.
- Add an invalid sample packet fixture.
- Add tests for required field presence or schema completeness.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/04-task-packet-ingestion/checkpoint.md.

Stop if:
- Task Contract V2 requirements are unclear. Document the gap and stop instead
  of creating a loose schema.
```

## Done When

External agents have a strict format to target.

