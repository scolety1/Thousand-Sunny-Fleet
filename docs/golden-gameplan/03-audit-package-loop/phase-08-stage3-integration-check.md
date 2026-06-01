# Stage 3 Phase 8: Stage 3 Integration Check

## Goal

Verify that the audit package loop is complete enough for Stage 4 task-packet
ingestion.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 3 Phase 8 only: Stage 3 integration check.

Do not implement any new fleet features.

Goal:
Run a full Stage 3 verification pass, patch only Stage 3 regressions, and update
the Stage 3 checkpoint with a clear ready/not-ready verdict.

Before editing:
- Run .\fleet-status.ps1.
- Review docs/golden-gameplan/03-audit-package-loop/checkpoint.md.
- Confirm Phases 1-7 are complete or explicitly deferred.

Scope:
- Only patch regressions caused by Stage 3 work.
- Do not start Stage 4.
- Do not ingest external agent output.
- Do not touch product repos.

Required checks:
- .\tests\run-fleet-tests.ps1
- package one fixture ship
- package multiple fixture ships
- validate manifest references
- verify excluded files stay out
- verify prompt files are included
- verify zip opens

Acceptance:
- Stage 3 checkpoint has final status: GREEN, YELLOW, or RED.
- Any YELLOW item has explicit follow-up owner and stage.
- No RED item remains unless the user approves moving forward with known risk.
- The final response summarizes whether Stage 4 can begin.

Stop if:
- Package output is too inconsistent for external agents to use.
```

## Done When

Stage 3 has a clear integration verdict and a clean handoff to Stage 4.

