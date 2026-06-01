# Stage 4: Task Packet Ingestion

Stage 4 makes external agent feedback actionable without making it dangerous.

Stage 3 creates audit packages for external review. Stage 4 defines how the
fleet safely accepts the returned task packet.

## Goal

Create a validated ingestion path for structured task packets from external
agents, humans, or future internal reviewers.

The fleet should be able to:

- receive a task packet
- validate the packet schema
- check audit ID and base commit assumptions
- reject stale or unsafe packets
- normalize accepted tasks into Task Contract V2
- append accepted tasks to the correct ship queue
- write a clear accepted/rejected ingest report
- preserve the original packet for traceability

## Why This Stage Matters

External agents are useful because they can inspect audit packages and propose
better next tasks. They are risky if their output is accepted blindly.

Stage 4 turns outside feedback into bounded local work. The external agent may
recommend. The fleet verifies.

## Phase Order

1. Task packet schema
2. Packet storage and traceability
3. Packet validator
4. Task Contract V2 normalization
5. Safe queue append
6. Rejection and ingest reports
7. Stale packet and duplicate protection
8. Stage 4 integration check

## Target Packet Concept

```json
{
  "packetId": "packet-20260526-001",
  "auditId": "audit-20260526-001",
  "generatedAt": "2026-05-26T12:00:00Z",
  "project": "Bottlelight",
  "baseCommit": "abc123",
  "phase": "refinement",
  "budget": {
    "maxRuntimeMinutes": 30,
    "maxTasks": 3,
    "budgetMode": "balanced"
  },
  "tasks": [
    {
      "id": "task-001",
      "title": "Simplify wine list first screen",
      "checklistLine": "- [ ] ... Task Contract V2 line ..."
    }
  ]
}
```

## Files Likely Touched During Implementation

Planning only in this document. When implementation begins, likely files include:

- new `import-task-packet.ps1` or `ingest-task-packet.ps1`
- `tests/run-fleet-tests.ps1`
- `docs/codex/TASK_CONTRACT_V2.md`
- packet schema under `templates/` or `schemas/`
- optional update to `generate-next-five.ps1` or task-quality helpers
- package docs such as `FLEET_REPORTS_README.md`

## Stage Exit Criteria

Stage 4 is complete when:

- task packet schema exists
- valid packets can be ingested in dry-run and apply modes
- invalid packets are rejected with reasons
- stale base commits are rejected or require explicit override
- duplicate packet IDs are not applied twice
- accepted tasks are appended to the correct queue section
- rejected tasks do not modify task queues
- original packets and ingest reports are preserved
- tests cover valid, invalid, stale, duplicate, and unsafe packets
- `.\tests\run-fleet-tests.ps1` passes

## Do Not Do

- Do not let external packets edit code directly.
- Do not launch a ship automatically after ingestion unless a later stage allows it.
- Do not accept broad, vague, sensitive, or unsafe tasks.
- Do not allow packet ingestion to touch dirty product work without explicit policy.
- Do not merge, push, deploy, delete, or clean repos.
- Do not build the final decision engine yet.

## Implementation Rule

The default posture is reject-with-reason. A packet that cannot be validated
should leave a report, not a changed task queue.

