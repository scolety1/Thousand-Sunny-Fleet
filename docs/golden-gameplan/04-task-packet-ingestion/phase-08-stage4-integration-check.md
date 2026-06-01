# Stage 4 Phase 8: Stage 4 Integration Check

## Goal

Verify that task packet ingestion is safe enough for the state machine and
decision engine stages.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 4 Phase 8 only: Stage 4 integration check.

Do not implement any new fleet features.

Goal:
Run a full Stage 4 verification pass, patch only Stage 4 regressions, and update
the Stage 4 checkpoint with a clear ready/not-ready verdict.

Before editing:
- Run .\fleet-status.ps1.
- Review docs/golden-gameplan/04-task-packet-ingestion/checkpoint.md.
- Confirm Phases 1-7 are complete or explicitly deferred.

Scope:
- Only patch regressions caused by Stage 4 work.
- Do not start Stage 5.
- Do not launch ships after ingesting tasks.
- Do not touch product code beyond test fixtures/queues.

Required checks:
- .\tests\run-fleet-tests.ps1
- valid packet dry-run
- valid packet apply
- invalid packet rejection
- stale packet rejection
- duplicate packet rejection
- forbidden scope rejection
- ingest reports written
- queue preserved when rejected

Acceptance:
- Stage 4 checkpoint has final status: GREEN, YELLOW, or RED.
- Any YELLOW item has explicit follow-up owner and stage.
- No RED item remains unless the user approves moving forward with known risk.
- The final response summarizes whether Stage 5 can begin.

Stop if:
- Packet ingestion can mutate a queue after validation failure.
```

## Done When

Stage 4 has a clear integration verdict and a safe handoff to Stage 5.

