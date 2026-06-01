# Stage 10 Phase 5 Prompt: Auto-Resume Eligibility

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 10 Phase 5 only: Auto-Resume Eligibility.

Goal:
Define when a paused overnight run may resume automatically after reset.

A ship is resume eligible only if:
- it was paused by safe landing
- budget is confirmed recovered, or a configured reset window has passed and
  conservative mode is active
- repo state is clean or known/resumable
- no active human taste gate exists
- no BLOCK decision exists
- no explicit stop request exists
- no sensitive approval is pending
- valid tasks remain or approved packet is ready
- resume attempts remain
- decision engine says RUN_AGAIN or allowed bounded action

A ship is not resume eligible if:
- dirty unowned repo
- stale lock ambiguity
- failed deterministic gates without repair plan
- taste gate waiting for user
- archived/parked by captain
- rate-limit source is unknown and no manual config exists
- max resume attempts exceeded

Guardrails:
- Auto-resume should never broaden scope.
- Auto-resume should never launch ships not in the original selected set.
- Auto-resume should produce a report before and after resuming.
- A configured reset window alone is not enough to resume high-risk or
  model-heavy work if local budget/state signals are missing.
- Do not implement scheduling yet in this phase.

Acceptance:
- Resume eligibility rules exist.
- Eligible and ineligible examples exist.
- The rules prioritize safety over momentum.

Proof:
Show eligibility matrix and examples.
```

## Notes

Auto-resume is useful only if it does not wake up messy.

## Implementation Status

Status: GREEN

Implemented by `Test-FleetOvernightResumeEligibility` in
`tools/codex-fleet-overnight.ps1`. It blocks taste-gated, blocked, parked,
archived, unclean, out-of-scope, and max-attempt-exhausted ships.
