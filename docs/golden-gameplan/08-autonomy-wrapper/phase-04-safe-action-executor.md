# Stage 8 Phase 4 Prompt: Safe Action Executor

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 8 Phase 4 only: Safe Action Executor.

Goal:
Map Stage 6 decisions to approved bounded actions.

Decision to action mapping:
- NOOP -> WRITE_STATUS_REPORT
- RUN_AGAIN -> RUN_ONE_BATCH only if allowed by flags and scope
- REPAIR -> WRITE_REPAIR_TASK or BLOCK_WITH_REASON depending risk
- PACKAGE_AUDIT -> MAKE_AUDIT_PACKAGE
- WAIT_FOR_EXTERNAL_AUDIT -> WRITE_STATUS_REPORT
- WAIT_FOR_TASK_PACKET -> WRITE_STATUS_REPORT
- USER_TASTE_GATE -> REQUEST_TASTE_GATE
- WAIT_FOR_RATE_RESET -> WRITE_STATUS_REPORT
- PARK -> PARK_SHIP only if allowed and clean
- BLOCK -> BLOCK_WITH_REASON
- ARCHIVE -> BLOCK_WITH_REASON unless explicit archive flag exists

Guardrails:
- Default mode should not run implementation batches unless explicitly allowed.
- IMPORT_APPROVED_PACKET requires Stage 4 validation evidence, not just a file name.
- RUN_ONE_BATCH requires explicit selected ship scope, clean/owned state, and budget checks.
- Never execute high-risk actions silently.
- Never merge, push, deploy, delete user work, or kill active processes.
- Stop after one bounded action per ship.

Acceptance:
- Action mapping exists.
- Tests prove unsafe decisions do not execute.
- Allowed RUN_ONE_BATCH is bounded.
- Package audit action can be selected without running code.

Proof:
Show decision/action matrix and focused test output.
```

## Notes

This phase is where the wrapper becomes useful, but it must stay conservative.

## Implementation Status

Status: GREEN

`Resolve-FleetAutonomyAction` maps Stage 6 decisions to bounded Stage 8 actions. Implementation runs require `-AllowRunBatch` and `-Execute`; audit packaging requires `-AllowAuditPackage`; task packet import requires approval evidence. Archive remains blocked without a later explicit archive path.
