# Stage 9.5 Checkpoint

Use this checklist before moving to Stage 10.

## Required Docs

- [x] `stage-plan.md`
- [x] `checkpoint.md`

## Implementation Completion Criteria

- [x] Low-token documentation warns that Stage 8/9 behavior is manual only.
- [x] Captain summary generation exists.
- [x] Comparison examples exist.
- [x] Validation tests cover missing fields.
- [x] Validation tests cover unknown roles.
- [x] Validation tests cover invalid verdicts.
- [x] Validation tests cover malformed JSON.
- [x] Validation tests cover forbidden patterns.
- [x] Taste disagreement maps to `NEEDS_CAPTAIN`.

## Implementation Status

Status: GREEN

Evidence:
- `tools/codex-fleet-external-agent.ps1`
- `new-external-agent-workflow.ps1`
- `tests/run-fleet-tests.ps1`
- `docs/templates/external-agent-workflow/`

Verification:
- `.\tests\run-fleet-tests.ps1` passed.

Stage 10 readiness:
- Stage 10 can now depend on stronger external-review validation and phone-readable captain summaries.
- Stage 10 still owns rate-limit detection, safe landing, and auto-resume.

