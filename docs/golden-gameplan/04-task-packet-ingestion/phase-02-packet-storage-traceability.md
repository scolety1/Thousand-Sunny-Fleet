# Stage 4 Phase 2: Packet Storage and Traceability

## Goal

Store incoming packets and ingest history before applying any tasks.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 4 Phase 2 only: Packet storage and traceability.

Do not implement any other Golden Gameplan phase.

Goal:
Create the local storage convention for incoming, accepted, rejected, and applied
task packets.

Before editing:
- Run .\fleet-status.ps1.
- Review Stage 4 Phase 1 schema.

Scope:
- Add storage directories/templates/tests.
- Likely locations: .codex-local/packets/, out/task-packets/, tests.
- Do not apply tasks to queues yet.

Required behavior:
- Original packet is preserved unchanged.
- Ingest attempt writes a timestamped record.
- Accepted/rejected/applied status can be traced by packet ID.
- Duplicate packet IDs are discoverable before apply mode exists.

Acceptance:
- Add tests for packet storage path creation.
- Add tests for preserving original packet content.
- Add tests for duplicate packet ID detection.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/04-task-packet-ingestion/checkpoint.md.

Stop if:
- Packet storage location conflicts with existing fleet local-state policy.
```

## Done When

No external packet can disappear or be applied without a trace.

