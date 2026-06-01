# Stage 13 Phase 1 Prompt: Mobile Status Contract

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 13 Phase 1 only: Mobile Status Contract.

Goal:
Define phone-friendly fleet and ship status messages.

Mobile status should support:
- fleet summary
- selected ship summary
- blockers
- taste gates
- rate-limit warnings
- overnight status
- safe next command

A fleet status response should fit on one phone screen when possible:
- headline
- running count
- blocked count
- needs captain count
- rate/budget state
- top 3 actions
- link/path to full report

A ship status response should include:
- ship
- lane
- state
- decision
- last action
- blocker/taste/rate note
- next safe action

Guardrails:
- Do not implement messaging integration.
- Do not expose secrets or huge logs.
- Do not include noisy raw terminal output.
- Do not imply an action has run when it is only suggested.

Acceptance:
- Mobile status format doc exists.
- Examples exist for healthy, blocked, taste-gated, rate-paused, and overnight-running states.
- Long report linking behavior is defined.

Proof:
Show status contract path and example messages.
```

## Notes

This is the answer to "how are the ships doing?" from a phone.

## Implemented Mobile Status Format

Fleet response:

```text
Fleet: Running: 1 | Needs captain: 2 | Blocked/repair: 1 | Safe to inspect: 1 | Budget: low -> BLOCK_NEW_WORK
Next: Review blocker/repair board first.
Top actions:
- Bottlelight: Inspect parked result
- ShiftLedger: Request taste review
- KeeperLab: Write repair task
Full report: out/stage12/control-room.json
```

Ship response:

```text
Ship: ShiftLedger
Lane: manager_internal_tool
State: TASTE_GATE
Decision: USER_TASTE_GATE
Note: deterministic gates passed; captain taste is needed
Next safe action: Request taste review
```

Examples:

- Healthy: status request returns top counts and dry-run suggestions.
- Blocked: blocker is named; mobile response does not run repair.
- Taste-gated: asks the captain one subjective question.
- Rate-paused: shows budget decision and says no new work.
- Overnight-running: says leave active work alone and links report.

Long report rule:

Mobile replies should include a short path/link to the full control-room report
instead of pasting raw logs.
