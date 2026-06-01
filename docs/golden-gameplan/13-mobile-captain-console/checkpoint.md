# Stage 13 Checkpoint

Use this checklist before moving to Stage 14.

## Required Docs

- [x] `stage-plan.md`
- [x] `phase-01-mobile-status-contract.md`
- [x] `phase-02-command-inbox-protocol.md`
- [x] `phase-03-safe-remote-actions.md`
- [x] `phase-04-idea-intake-task-drafting.md`
- [x] `phase-05-rate-limit-alerts.md`
- [x] `phase-06-mobile-digest.md`
- [x] `phase-07-approval-rejection-rules.md`
- [x] `phase-08-stage13-integration-check.md`
- [x] `audit-prompt.md`
- [x] `checkpoint.md`

## Implementation Completion Criteria

- [x] Mobile status contract exists.
- [x] Command inbox protocol exists.
- [x] Safe remote action matrix exists.
- [x] Idea intake spec exists.
- [x] Rate-limit alert spec exists.
- [x] Mobile digest template exists.
- [x] Approval/rejection rules exist.
- [x] Unsafe commands are rejected by design.
- [x] Phone summary is concise.
- [x] No actual remote integration was implemented during docs stage.

## Scenarios To Prove

- [x] "How is the fleet?"
- [x] "Stop EasyLife safely."
- [x] "Run the cellar fleet tonight."
- [x] "I have an idea for Niners."
- [x] "Approve the taste direction."
- [x] "Resume after reset."
- [x] Critical budget alert.
- [x] Ambiguous approval.
- [x] Backend-sensitive request.
- [x] Implicit all-fleet request rejected.

## Red Flags

Do not move to Stage 14 if:

- Remote commands can execute without validation.
- Missing scope defaults to all ships.
- High-risk work can be approved with vague language.
- Rate-limit alerts fabricate precision.
- Idea intake mutates task queues immediately.
- Mobile digest hides failures.
- Forbidden actions are not explicit.
- RUN_ONE_BOUNDED_BATCH can execute without dry-run, scope, state, and budget checks.
- RESUME_AFTER_RESET can run without Stage 10 eligibility evidence.

## Stage 14 Readiness Statement

Before Stage 14 begins, write a short note answering:

Can the captain safely check and steer the fleet from a phone?

Yes, at the request layer. The local harness can parse phone-style messages,
produce concise status/digest responses, capture ideas, and reject or hold risky
commands for local validation.

Which remote actions are safe enough for future implementation?

Read-only `STATUS`, `DIGEST`, `RUN_DRY_CHECK`, `PACKAGE_AUDIT`, and
`CAPTURE_IDEA` are safest. `REQUEST_SAFE_STOP`, `PARK_SHIP`, packet import,
bounded runs, overnight presets, and resume requests must remain local
validation requests.

Which actions must always stay manual?

Merge, push, deploy, destructive cleanup, lock deletion, secrets/env edits,
auth/payments/migrations/package changes, production data, and broad all-fleet
runs.

What final stress tests should Stage 14 run?

Stage 14 should test mobile request rejection, status/digest generation,
critical-budget safe landing, resume-after-reset gating, unvalidated packet
rejection, backend-sensitive rejection, and fixture-only bounded execution.

## Implementation Status

Status: GREEN

Evidence:

- `tools/codex-fleet-mobile.ps1`
- `invoke-mobile-console.ps1`
- `docs/golden-gameplan/13-mobile-captain-console/`
- `tests/run-fleet-tests.ps1`

Post-Golden Gameplan hardening:

- Added `mobile-command-vocabulary.md`.
- Phone vocabulary now centers on status, why, submit idea, approve plan,
  reject plan, resume safe, audit package, and mute/snooze notifications.
- Phone status responses include top cards for Running, Blocked,
  Needs Approval, Budget, and Incidents.
- Shell-like or destructive mobile text is rejected as a forbidden remote
  action. The phone layer still creates request records only.
- Added `approval-flow.md` and `templates/mobile-request-schema.json`.
- Phone approvals must approve generated plans with `planId`,
  `idempotencyKey`, scope, risk, evidence, budget impact, expiration, and
  rollback path. Raw commands, stale plans, broad all-fleet scope, missing
  rollback, and unbounded cost remain rejected before local execution.

Verification:

- `.\tests\run-fleet-tests.ps1` passed.

Stage 14 readiness:

- Cleared. Stage 14 may begin after this checkpoint.
