# Stage 13 Phase 5 Prompt: Rate-Limit Alerts

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 13 Phase 5 only: Rate-Limit Alerts.

Goal:
Define phone-friendly rate-limit and budget alerts.

Alert types:
- BUDGET_HEALTHY
- BUDGET_CAUTION
- BUDGET_LOW
- BUDGET_CRITICAL
- SAFE_LANDING_STARTED
- SAFE_LANDING_COMPLETE
- RESET_PENDING
- RESUME_ELIGIBLE
- RESUME_BLOCKED
- OVERNIGHT_STOPPED

Each alert should include:
- severity
- budget state
- affected ships
- action taken
- next check time
- user action needed
- link/path to report

Guardrails:
- Do not fabricate exact percentages if unavailable.
- Critical budget should recommend safe landing, not more work.
- Alerts should be concise.
- Do not implement notification delivery in this stage.

Acceptance:
- Rate-limit alert spec exists.
- Examples cover low budget, 3%/critical safe landing, reset pending, and resume eligible.
- Alerts map to Stage 10 rate governor states.

Proof:
Show alert spec path and examples.
```

## Notes

This is the "don't waste my limits just because I'm gone" layer.

## Implemented Rate Alert Shape

Rate alerts include:

```text
alertType
severity
budgetState
decision
affectedShips
actionTaken
nextCheckTime
userActionNeeded
reportPath
```

Examples:

- Low: `BUDGET_LOW`, warning, use status-only checks.
- Critical / 3 percent: `SAFE_LANDING_STARTED`, critical, let safe landing complete.
- Reset pending: `RESET_PENDING`, wait for reset or recovered-budget evidence.
- Resume eligible: `RESUME_ELIGIBLE`, dry-run selected ship before bounded run.

The mobile layer does not invent exact percentages. It reports only the Stage 10
budget evidence it receives.
