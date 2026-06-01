# Stage 4 Phase 7: Stale Packet and Duplicate Protection

## Goal

Prevent old or repeated task packets from corrupting the queue.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 4 Phase 7 only: Stale packet and duplicate protection.

Do not implement any other Golden Gameplan phase.

Goal:
Harden ingestion against stale base commits, duplicate packet IDs, duplicate task
IDs, replayed packets, and packets generated for old audit evidence.

Before editing:
- Run .\fleet-status.ps1.
- Review packet storage, validator, queue append, and reports.

Scope:
- Likely files: ingest-task-packet.ps1, packet storage helpers,
  tests/run-fleet-tests.ps1.
- Do not launch tasks.

Required behavior:
- Reject duplicate packet IDs in apply mode.
- Reject duplicate task IDs already applied from previous packets.
- Reject stale base commits by default.
- Allow explicit dry-run inspection of stale packets without queue writes.
- Record replay attempts in reports.
- Provide an explicit override path only if documented and safe.

Acceptance:
- Add tests for duplicate packet rejection.
- Add tests for duplicate task rejection.
- Add tests for stale commit rejection.
- Add tests for dry-run stale packet inspection.
- Add tests that replay attempts do not mutate queues.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/04-task-packet-ingestion/checkpoint.md.

Stop if:
- Commit matching is unreliable for some ship types. Document exceptions and
  require manual override for them.
```

## Done When

External packets cannot be accidentally applied twice or against the wrong code.

