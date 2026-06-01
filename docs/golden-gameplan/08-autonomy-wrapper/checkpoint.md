# Stage 8 Checkpoint

Use this checklist before moving to Stage 9.

## Required Docs

- [x] `stage-plan.md`
- [x] `phase-01-wrapper-command-contract.md`
- [x] `phase-02-dry-run-planner.md`
- [x] `phase-03-selected-ship-scope.md`
- [x] `phase-04-safe-action-executor.md`
- [x] `phase-05-budget-loop-limits.md`
- [x] `phase-06-report-evidence-output.md`
- [x] `phase-07-failure-containment.md`
- [x] `phase-08-stage8-integration-check.md`
- [x] `audit-prompt.md`
- [x] `checkpoint.md`

## Implementation Completion Criteria

- [x] Wrapper command contract exists.
- [x] Dry-run mode exists and is side-effect free.
- [x] Selected ship scope is required.
- [x] Decision-to-action mapping exists.
- [x] Safe action executor is bounded.
- [x] Budget and loop limits exist.
- [x] Reports are generated.
- [x] Failure containment exists.
- [x] Tests prove no implicit full-fleet launch.
- [x] Tests prove no unbounded loop.

## Actions To Prove

- [x] `NOOP`
- [x] `RUN_ONE_BATCH`
- [x] `MAKE_AUDIT_PACKAGE`
- [x] `IMPORT_APPROVED_PACKET`
- [x] `WRITE_REPAIR_TASK`
- [x] `WRITE_STATUS_REPORT`
- [x] `PARK_SHIP`
- [x] `REQUEST_TASTE_GATE`
- [x] `WAIT_FOR_RATE_RESET`
- [x] `BLOCK_WITH_REASON`

## Red Flags

Do not move to Stage 9 if:

- Dry-run mutates files or launches work.
- Missing scope defaults to all ships.
- RUN_AGAIN executes without an explicit allow flag.
- Wrapper can run forever.
- Failure cleanup touches user work.
- Reports are missing or overwritten.
- High-risk ships can run without explicit approval.
- Low-token mode still launches implementation work.
- IMPORT_APPROVED_PACKET can bypass Stage 4 validation evidence.
- RUN_ONE_BATCH can run without explicit ship scope, clean/owned state, and budget checks.

## Stage 9 Readiness Statement

Before Stage 9 begins, write a short note answering:

```text
Can the wrapper safely perform one bounded cycle?
Which actions still require human approval?
What evidence should be sent to external agents?
```

## Implementation Status

Status: GREEN

Completed on 2026-05-27.

Evidence:
- `invoke-autonomy-wrapper.ps1`
- `tools/codex-fleet-autonomy.ps1`
- `tests/run-fleet-tests.ps1`

Verification:
- `.\tests\run-fleet-tests.ps1` passed.
- Tests prove missing scope fails fast and still writes a contained report.
- Tests prove dry-run does not execute actions.
- Tests prove selected scope does not expand to all ships.
- Tests prove `RUN_AGAIN` requires explicit run approval and stays bounded.
- Tests prove low-token mode blocks implementation runs.
- Tests prove approved audit-package creation works.
- Tests prove taste gates become `REQUEST_TASTE_GATE`.

Stage 9 readiness:
- The wrapper can safely perform one bounded local cycle.
- Human approval is still required for real implementation batches, task packet import, repair task writing, parking, archive behavior, product repo work, and any merge/push/deploy.
- External agents should receive audit packages, run summaries, evidence indexes, state/decision reports, and wrapper cycle reports. Stage 9 should formalize that handoff; Stage 8 does not orchestrate external agents.

## Stage 8.5 Hardening Note

The Stage 8 external audit returned `PASS WITH FIXES`, so a focused Stage 8.5 hardening pass was added before Stage 9.

Stage 8.5 covers:
- expanded failure-containment tests
- real `ApprovedPacketEvidence` validation artifacts
- phone-readable report summaries
- manual `LowTokenMode` documentation
- one-ship default scope

See `docs/golden-gameplan/08.5-autonomy-wrapper-hardening/checkpoint.md`.
