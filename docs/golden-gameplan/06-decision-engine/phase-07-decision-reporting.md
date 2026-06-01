# Stage 6 Phase 7 Prompt: Decision Reporting

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 6 Phase 7 only: Decision Reporting.

Goal:
Make decisions readable and useful to the captain.

Create or update reporting so a status/check command can show:
- ship
- state
- decision
- reason
- confidence
- next safe action
- what not to do
- relevant evidence
- budget/rate-limit note

Reports may include:
- fleet/status/decisions.json
- fleet/status/decisions.md
- per-ship docs/codex/DECISION_REPORT.md
- terminal summary

Guardrails:
- Reporting must not execute decisions.
- Keep phone-readable summaries short.
- Do not bury BLOCK or REPAIR reasons.
- Do not say "finished" when the decision is only PARK or USER_TASTE_GATE.

Acceptance:
- A selected fixture fleet produces a readable decision summary.
- The report distinguishes RUN_AGAIN, REPAIR, PARK, USER_TASTE_GATE, and WAIT_FOR_RATE_RESET.
- Evidence paths are included.

Proof:
Show sample report output.
```

## Notes

This is the layer that lets the user ask, "How is the fleet?" and get an honest answer.

## Implementation Status

Status: GREEN

Evidence:
- `fleet-decision.ps1`
- `fleet/status/decisions.md`
- `fleet/status/decisions.json`
- `tests/run-fleet-tests.ps1`

Verification:
- `.\fleet-decision.ps1 -Action Report` writes a phone-readable Markdown report and a machine-readable JSON report.
- Tests prove fixture reports distinguish `RUN_AGAIN` and `USER_TASTE_GATE`.
- The reporting command remains advisory and does not execute decisions.
