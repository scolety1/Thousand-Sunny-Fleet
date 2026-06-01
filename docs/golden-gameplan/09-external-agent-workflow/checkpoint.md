# Stage 9 Checkpoint

Use this checklist before moving to Stage 10.

## Required Docs

- [x] `stage-plan.md`
- [x] `phase-01-external-review-roles.md`
- [x] `phase-02-audit-package-handoff-prompt.md`
- [x] `phase-03-role-specific-audit-prompts.md`
- [x] `phase-04-structured-task-packet-response.md`
- [x] `phase-05-multi-agent-comparison.md`
- [x] `phase-06-ingest-review-conflict-resolution.md`
- [x] `phase-07-captain-summary-approval-points.md`
- [x] `phase-08-stage9-integration-check.md`
- [x] `audit-prompt.md`
- [x] `checkpoint.md`

## Implementation Completion Criteria

- [x] External agent roles are defined.
- [x] Standard handoff prompt exists.
- [x] Role-specific prompts exist.
- [x] Structured response format exists.
- [x] Task packet response examples exist.
- [x] Multi-agent comparison process exists.
- [x] Conflict resolution rules exist.
- [x] Captain summary template exists.
- [x] Approval points are explicit.
- [x] External agents cannot bypass fleet validation.
- [x] Local harness can generate prompts without calling external agents.
- [x] Local harness can validate external response JSON.
- [x] Local harness can compare multiple response files.

## Scenarios To Prove

- [x] One-agent issue audit.
- [x] One-agent improvement audit.
- [x] Product taste audit.
- [x] Formula audit.
- [x] Security/scope audit.
- [x] Three-agent comparison.
- [x] Valid task packet.
- [x] Stale task packet.
- [x] Broad unsafe redesign packet.
- [x] Captain approval required.

## Red Flags

Do not move to Stage 10 if:

- External agents are allowed to edit repos directly.
- Task packets can bypass validation.
- Prompts are vague.
- Multi-agent disagreement has no resolution path.
- Captain approval points are unclear.
- High-risk suggestions can be accepted automatically.
- The workflow is too cumbersome to use from real audit packages.
- Human review is treated as the normal repair path for broken builds, missing evidence, or stalled loops.
- Stage 9 code calls online agents automatically.

## Stage 10 Readiness Statement

Before Stage 10 begins, write a short note answering:

```text
Can external audit packages now produce safe next-task candidates?
Which packet types still require human approval?
What rate-limit and overnight behavior should Stage 10 protect?
```

## Implementation Status

Status: GREEN

Completed on 2026-05-27.

Evidence:
- `tools/codex-fleet-external-agent.ps1`
- `new-external-agent-workflow.ps1`
- `docs/templates/external-agent-workflow/`
- `tests/run-fleet-tests.ps1`

Verification:
- `.\tests\run-fleet-tests.ps1` passed.

Stage 10 readiness:
- External audit packages can now produce safe next-task candidates as structured suggestions.
- Packets still require Stage 4 validation before ingestion and captain approval for high-risk/taste/business decisions.
- Stage 10 should protect rate-limit budget, safe landing, scheduled resume, and overnight run windows.
