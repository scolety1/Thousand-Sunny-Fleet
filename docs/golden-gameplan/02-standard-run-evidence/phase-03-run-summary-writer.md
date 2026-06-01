# Stage 2 Phase 3: RUN_SUMMARY Writer

## Goal

Write a concise human-readable `docs/codex/RUN_SUMMARY.md` after each run.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 2 Phase 3 only: RUN_SUMMARY writer.

Do not implement any other Golden Gameplan phase.

Goal:
Create docs/codex/RUN_SUMMARY.md from RUN_RESULT.json or the same run data.
This should be readable on desktop or phone without opening many reports.

Before editing:
- Run .\fleet-status.ps1.
- Confirm RUN_RESULT.json writer exists from Stage 2 Phase 2.
- Inspect existing night/checkpoint reports for reusable summary language.

Scope:
- Likely files: run-checkpoint-loop.ps1, fleet-night-report.ps1 or helper,
  tests/run-fleet-tests.ps1.
- Do not build EVIDENCE_INDEX.md yet.
- Do not replace detailed reports.

Required sections:
- Run status
- Ship and branch
- Tasks attempted/completed/quarantined/blocked
- Checks passed/failed/skipped
- Material changes summary
- Warnings/errors
- Next suggested action or decision hint

Acceptance:
- Add tests proving RUN_SUMMARY.md is written.
- Add tests proving it includes ship, tasks, checks, and next-action fields.
- Summary should stay compact and not dump full logs.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/02-standard-run-evidence/checkpoint.md.

Stop if:
- Summary generation needs the final decision engine. Use `decisionHint` only
  and defer full decisions to Stage 6.
```

## Why It Matters

The captain needs one readable answer to "what happened?" without terminal archaeology.

## Done When

Every run can produce a short run summary.

