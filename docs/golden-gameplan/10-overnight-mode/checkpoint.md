# Stage 10 Checkpoint

Use this checklist before moving to Stage 11.

## Required Docs

- [x] `stage-plan.md`
- [x] `phase-01-overnight-mode-contract.md`
- [x] `phase-02-rate-governor-policy.md`
- [x] `phase-03-low-budget-safe-landing.md`
- [x] `phase-04-reset-window-resume-metadata.md`
- [x] `phase-05-auto-resume-eligibility.md`
- [x] `phase-06-scheduled-check-cadence.md`
- [x] `phase-07-morning-report-evidence.md`
- [x] `phase-08-stage10-integration-check.md`
- [x] `audit-prompt.md`
- [x] `checkpoint.md`

## Implementation Completion Criteria

- [x] Overnight mode contract exists.
- [x] Rate governor policy exists.
- [x] Safe landing flow exists.
- [x] Reset/resume metadata exists.
- [x] Auto-resume eligibility rules exist.
- [x] Scheduled check cadence exists.
- [x] Morning report template exists.
- [x] Fixture tests cover low budget and reset.
- [x] No real overnight schedule is created during tests.
- [x] No unbounded loop is possible.

## Scenarios To Prove

- [x] Healthy budget allows bounded work.
- [x] Low budget blocks new work.
- [x] Critical/3% budget triggers safe landing.
- [x] Exhausted budget waits for reset.
- [x] Unknown budget is conservative.
- [x] Configured reset window records resume metadata.
- [x] Recovered budget resumes eligible ships.
- [x] Taste-gated ship does not resume.
- [x] Blocked ship does not resume.
- [x] Max resume attempts stop retry loops.
- [x] Morning report is generated.

## Red Flags

Do not move to Stage 11 if:

- Overnight mode can launch implicit all-fleet runs.
- Rate governor fabricates budget numbers.
- Safe landing skips evidence.
- Critical budget still launches implementation work.
- Auto-resume ignores taste gate or block state.
- Reset time is guessed without labeling it.
- Configured reset window alone can resume high-risk or model-heavy work.
- Max resume attempts are missing.
- Reports are not enough to understand what happened overnight.

## Stage 11 Readiness Statement

Before Stage 11 begins, write a short note answering:

```text
Can the fleet sleep safely without draining limits?
Can it pause before low budget becomes failure?
Can it resume only when safe?
Which project lanes need specialized overnight behavior?
```

## Implementation Status

Status: GREEN

Completed on 2026-05-27.

Evidence:
- `tools/codex-fleet-overnight.ps1`
- `invoke-overnight-mode.ps1`
- `tests/run-fleet-tests.ps1`

Verification:
- `.\tests\run-fleet-tests.ps1` passed.
- Focused tests prove healthy/low/critical/exhausted/unknown budget decisions.
- Focused tests prove critical budget writes resume metadata and a readable report.
- Focused tests prove recovered budget can mark an eligible fixture as auto-resume ready.
- Focused tests prove taste-gated ships do not auto-resume.
- Focused tests prove max resume attempts stop retry loops.
- Focused tests prove default `MaxShips = 1` prevents accidental multi-ship overnight runs.

Stage 11 readiness:
- The fleet can sleep more safely because Stage 10 blocks unknown or low-budget model-heavy work, safe-lands at the configured threshold, and writes resume evidence.
- It can pause before low budget becomes failure by mapping 3% or critical budget to `SAFE_LAND_NOW`.
- It can resume only when a recovered budget or approved configured reset window is present and the selected ship is eligible.
- Stage 11 should specialize overnight defaults by lane: hospitality websites may need visual evidence cadence, manager tools may need workflow proof, analytical software may need formula/test proof, backend-sensitive work should remain approval-gated, and maintenance can use status-only checks.
