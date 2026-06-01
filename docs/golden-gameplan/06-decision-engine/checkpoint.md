# Stage 6 Checkpoint

Use this checklist before moving to Stage 7.

## Required Docs

- [x] `stage-plan.md`
- [x] `phase-01-decision-vocabulary-schema.md`
- [x] `phase-02-decision-input-normalization.md`
- [x] `phase-03-pure-decision-function.md`
- [x] `phase-04-repair-block-precedence.md`
- [x] `phase-05-run-again-eligibility.md`
- [x] `phase-06-park-taste-wait-rules.md`
- [x] `phase-07-decision-reporting.md`
- [x] `phase-08-stage6-integration-check.md`
- [x] `audit-prompt.md`
- [x] `checkpoint.md`

## Implementation Completion Criteria

- [x] Decision schema exists.
- [x] Normalized decision input exists.
- [x] Pure decision function exists.
- [x] Decision reports exist.
- [x] Every canonical decision is tested.
- [x] Repair/block override run-again.
- [x] Active dirty ships are NOOP.
- [x] Rate-limit paused ships are WAIT_FOR_RATE_RESET.
- [x] Taste-gate ships are USER_TASTE_GATE.
- [x] Parked/done ships are PARK.
- [x] No decision execution happens in Stage 6.

## Decisions To Prove

- [x] `NOOP`
- [x] `RUN_AGAIN`
- [x] `REPAIR`
- [x] `PACKAGE_AUDIT`
- [x] `WAIT_FOR_EXTERNAL_AUDIT`
- [x] `WAIT_FOR_TASK_PACKET`
- [x] `USER_TASTE_GATE`
- [x] `WAIT_FOR_RATE_RESET`
- [x] `PARK`
- [x] `BLOCK`
- [x] `ARCHIVE`

## Red Flags

Do not move to Stage 7 if:

- Decision calculation launches or relaunches ships.
- Failed builds/tests can still produce RUN_AGAIN.
- Unknown evidence can produce RUN_AGAIN.
- PARK and USER_TASTE_GATE are treated as the same thing.
- Rate-limit logic is invisible.
- Reports are not readable from a phone.
- The decision engine mutates task queues.
- The decision engine depends on unstructured Markdown scraping when structured evidence exists.

## Stage 7 Readiness Statement

Before Stage 7 begins, write a short note answering:

```text
Can the decision engine safely choose what should happen next?
Which decisions still need human approval?
What product-quality evidence is missing?
```

## Implementation Status

Status: GREEN

Completed on 2026-05-26.

Evidence:
- `templates/decision-schema.json`
- `templates/decision-input-schema.json`
- `tools/codex-fleet-decision.ps1`
- `fleet-decision.ps1`
- `fleet/status/decisions.md`
- `fleet/status/decisions.json`
- `tests/run-fleet-tests.ps1`

Verification:
- `.\tests\run-fleet-tests.ps1` passed.
- `.\fleet-decision.ps1 -Action Report` passed and wrote readable Markdown plus JSON decision reports.

Stage 7 readiness:
- The decision engine can safely choose a next recommended action from structured Stage 5 state without executing that action.
- Human approval is still required for any action that launches work, imports external task packets, touches product repos, merges, pushes, deploys, deletes locks, or changes sensitive systems.
- Product-quality evidence is still intentionally shallow; Stage 7 should define first-screen, demo-promise, usefulness, visual, copy, and taste-gate contracts so the decision engine can classify product readiness more intelligently.
