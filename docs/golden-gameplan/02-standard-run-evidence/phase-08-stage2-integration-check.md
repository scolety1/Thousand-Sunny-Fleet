# Stage 2 Phase 8: Stage 2 Integration Check

## Goal

Verify that canonical run evidence is consistent and ready for Stage 3 audit
packages.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 2 Phase 8 only: Stage 2 integration check.

Do not implement any new fleet features.

Goal:
Run a full Stage 2 verification pass, patch only Stage 2 regressions, and update
the Stage 2 checkpoint with a clear ready/not-ready verdict.

Before editing:
- Run .\fleet-status.ps1.
- Review docs/golden-gameplan/02-standard-run-evidence/checkpoint.md.
- Confirm Phases 1-7 are complete or explicitly deferred.

Scope:
- Only patch regressions caused by Stage 2 work.
- Do not start Stage 3.
- Do not touch product repos.

Required checks:
- .\tests\run-fleet-tests.ps1
- successful fixture run writes RUN_RESULT.json, RUN_SUMMARY.md, EVIDENCE_INDEX.md
- failed fixture run writes partial canonical evidence
- experiment dry-run evidence is compatible
- canonical evidence does not rely on stale previous files

Acceptance:
- Stage 2 checkpoint has final status: GREEN, YELLOW, or RED.
- Any YELLOW item has explicit follow-up owner and stage.
- No RED item remains unless the user approves moving forward with known risk.
- The final response summarizes whether Stage 3 can begin.

Stop if:
- Evidence files are inconsistent enough that Stage 3 audit packages would be
  unreliable.
```

## Why It Matters

Stage 3 packages evidence. Stage 2 must prove the evidence exists first.

## Done When

Stage 2 has a clear integration verdict and a clean handoff to Stage 3.

