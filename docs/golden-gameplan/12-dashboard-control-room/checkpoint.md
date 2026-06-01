# Stage 12 Checkpoint

Use this checklist before moving to Stage 13.

## Required Docs

- [x] `stage-plan.md`
- [x] `phase-01-dashboard-information-architecture.md`
- [x] `phase-02-fleet-overview-view.md`
- [x] `phase-03-ship-detail-view.md`
- [x] `phase-04-blocker-repair-taste-boards.md`
- [x] `phase-05-budget-overnight-view.md`
- [x] `phase-06-audit-task-packet-view.md`
- [x] `phase-07-safe-command-suggestions.md`
- [x] `phase-08-stage12-integration-check.md`
- [x] `audit-prompt.md`
- [x] `checkpoint.md`

## Implementation Completion Criteria

- [x] Control-room information architecture exists.
- [x] Fleet Overview view is defined.
- [x] Ship Detail view is defined.
- [x] Blocker Board is defined.
- [x] Repair Board is defined.
- [x] Taste Gate Board is defined.
- [x] Budget/Overnight view is defined.
- [x] Audit/Task Packet view is defined.
- [x] Safe command suggestions are defined.
- [x] Phone-readable captain summary is included.

## Scenarios To Prove

- [x] Running ship.
- [x] Blocked ship.
- [x] Repairing ship.
- [x] Taste-gated ship.
- [x] Parked ship.
- [x] Audit-ready ship.
- [x] Packet-ready ship.
- [x] Rate-paused ship.
- [x] Overnight safe landing.
- [x] Backend-sensitive approval block.
- [x] Analytical formula blocker.
- [x] Safe next command suggestion.

## Red Flags

Do not move to Stage 13 if:

- The first screen is overloaded.
- Active dirty ships are hidden.
- Blocked and taste-gated ships are conflated.
- Rate budget is vague or misleading.
- Command suggestions can launch all ships implicitly.
- External task packets look trusted before validation.
- The dashboard cannot explain why a ship is stuck.
- Phone summary is missing.

## Stage 13 Readiness Statement

Before Stage 13 begins, write a short note answering:

Can the captain understand the fleet quickly?

Yes. The first-screen cards answer running, needs-captain, blocked/repair,
safe-to-inspect, and budget status. The `captainSummary` field is short enough
to become a phone digest.

Which dashboard summaries should become mobile commands?

Stage 13 should expose read-only status questions first: fleet summary, ship
detail, blocker board, taste gate board, budget/overnight summary, latest audit
package, latest task packet, and safe command suggestions.

Which commands are safe enough to expose remotely?

Only request-style commands should be exposed first: request status, request
audit package, request packet validation, request taste review, request park,
and request dry-run for selected ships. They must remain requests until local
scope, state, budget, and safety checks pass.

## Implementation Status

Status: GREEN

Evidence:

- `tools/codex-fleet-control-room.ps1`
- `invoke-control-room.ps1`
- `docs/golden-gameplan/12-dashboard-control-room/`
- `tests/run-fleet-tests.ps1`

Verification:

- `.\tests\run-fleet-tests.ps1` passed.

Stage 13 readiness:

- Cleared. Stage 13 may begin after this checkpoint.
