# Stage 2 Phase 5: Checkpoint Loop Integration

## Goal

Integrate canonical run evidence into normal checkpoint-loop runs.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 2 Phase 5 only: Checkpoint loop integration.

Do not implement any other Golden Gameplan phase.

Goal:
Make normal run-checkpoint-loop.ps1 executions write RUN_RESULT.json,
RUN_SUMMARY.md, and EVIDENCE_INDEX.md consistently.

Before editing:
- Run .\fleet-status.ps1.
- Confirm Phases 1-4 are complete.
- Inspect how the checkpoint loop exits on success, quarantine, blocked checks,
  safe-stop, and failure.

Scope:
- Likely files: run-checkpoint-loop.ps1, checkpoint-review.ps1,
  tests/run-fleet-tests.ps1.
- Keep existing reports intact.
- Do not change task completion semantics unless needed to report accurately.

Required behavior:
- Successful run writes all three canonical files.
- Quarantined task run writes all three canonical files.
- Blocked run writes all three canonical files where safe.
- Safe-stop run writes canonical evidence if the loop has enough context.
- The canonical files reflect current run outcome, not stale previous outcome.

Acceptance:
- Add tests for success, quarantine/block, and safe-stop or skipped run evidence.
- Add tests that stale previous RUN_RESULT is not mistaken for current evidence.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/02-standard-run-evidence/checkpoint.md.

Stop if:
- Some exit paths cannot safely write evidence. Document those exact paths and
  leave explicit warnings in tests/checkpoint.
```

## Why It Matters

The normal run loop is the backbone. Canonical evidence must not exist only in
special cases.

## Done When

Checkpoint-loop runs consistently leave canonical evidence.

