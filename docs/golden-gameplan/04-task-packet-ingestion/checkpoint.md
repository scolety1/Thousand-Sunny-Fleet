# Stage 4 Checkpoint: Task Packet Ingestion

Status: GREEN

## Phase Checklist

- [x] Phase 1: Task packet schema
- [x] Phase 2: Packet storage and traceability
- [x] Phase 3: Packet validator
- [x] Phase 4: Task Contract V2 normalization
- [x] Phase 5: Safe queue append
- [x] Phase 6: Rejection and ingest reports
- [x] Phase 7: Stale packet and duplicate protection
- [x] Phase 8: Stage 4 integration check

## Required Final Evidence

- [x] `.\tests\run-fleet-tests.ps1` passes
- [x] task packet schema/template exists
- [x] original packets are preserved
- [x] valid packet validates
- [x] malformed packet rejects
- [x] unknown project rejects by validator path
- [x] stale base commit rejects by default
- [x] duplicate packet rejects in apply mode
- [x] duplicate task ID rejects
- [x] forbidden scope rejects unless explicit approval is present
- [x] accepted tasks append to correct queue section
- [x] rejected packets do not mutate queues
- [x] ingest Markdown report is written
- [x] ingest JSON report is written and parses
- [x] ingestion does not launch ships

## Deferrals

```text
No blocking deferrals. Morning watch item: add a larger matrix test for unknown-project and forbidden-scope examples, even though the validator paths exist now.
```

## Stage Verdict

```text
Verdict: GREEN
Date: 2026-05-26
Summary: Stage 4 added `ingest-task-packet.ps1`, schema docs, packet trace storage, Task Contract V2 validation, stale base-commit rejection, duplicate packet protection, duplicate task-ID rejection, safe queue append, and Markdown/JSON ingest reports.
Known risks: Later Stage 5 and Stage 6 should make ingestion feed the state machine and decision engine instead of only appending tasks.
Ready for Stage 5: yes
```
