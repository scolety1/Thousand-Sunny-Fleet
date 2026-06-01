# Stage 4 Phase 5: Safe Queue Append

## Goal

Append validated tasks to the correct ship queue without damaging existing tasks.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 4 Phase 5 only: Safe queue append.

Do not implement any other Golden Gameplan phase.

Goal:
Allow validated external task packets to append accepted tasks to the target
ship's docs/codex/TASK_QUEUE.md in a clearly marked section.

Before editing:
- Run .\fleet-status.ps1.
- Confirm packet validation and Task Contract normalization are complete.
- Inspect how TASK_QUEUE.md is currently read and written.

Scope:
- Likely files: ingest-task-packet.ps1, tests/run-fleet-tests.ps1.
- Do not launch the ship after appending.
- Do not rewrite the entire queue if append-only can work.
- Do not touch dirty product repos unless queue-only writes are explicitly safe.

Required behavior:
- Append accepted tasks under an "External Audit Tasks" section with timestamp,
  packet ID, and audit ID.
- Preserve existing unchecked, checked, and quarantined tasks.
- Avoid duplicate task IDs.
- Support dry-run mode showing what would be appended.
- Reject or skip if the target queue is missing unless scaffold mode is explicit.

Acceptance:
- Add tests appending valid tasks.
- Add tests preserving existing queue content.
- Add tests rejecting duplicate task IDs.
- Add tests for dry-run no-write mode.
- Add tests for missing queue behavior.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/04-task-packet-ingestion/checkpoint.md.

Stop if:
- The target ship repo is dirty in a way that makes queue writes unsafe. Report
  and stop rather than editing through unknown work.
```

## Done When

Validated packets can safely add tasks without executing them.

