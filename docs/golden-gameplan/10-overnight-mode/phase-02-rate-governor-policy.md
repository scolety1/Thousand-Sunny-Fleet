# Stage 10 Phase 2 Prompt: Rate Governor Policy

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 10 Phase 2 only: Rate Governor Policy.

Goal:
Define the rate governor that decides whether model-heavy work may start or continue.

The policy should support:
- configured remaining-budget percentage when available
- manual budget level when exact percentage is unavailable
- low-budget threshold, default 10%
- safe-landing threshold, default 3%
- cooldown after rate-limit errors
- model tier selection rules
- max concurrent ships by budget mode
- stop-new-work switch
- status-only mode

Budget levels:
- healthy
- cautious
- low
- critical
- exhausted
- reset_pending
- recovered

Required decisions:
- ALLOW_RUN
- ALLOW_STATUS_ONLY
- BLOCK_NEW_WORK
- SAFE_LAND_NOW
- WAIT_FOR_RESET

Guardrails:
- Do not query private account internals unless an approved local signal exists.
- Do not fabricate exact budget numbers.
- If budget cannot be known, use conservative configured/manual mode.
- Do not launch ships.

Acceptance:
- Rate governor policy exists.
- Thresholds and decisions are documented.
- Unknown budget state is conservative.
- Examples cover healthy, low, 3% critical, exhausted, and recovered states.

Proof:
Show policy doc and decision examples.
```

## Notes

The point is not perfect budget telemetry. The point is not crashing into zero.

## Threshold Defaults And Tuning

Default thresholds:

| Threshold | Default | Meaning |
| --- | ---: | --- |
| Low budget | `10%` | Stop starting new model-heavy work. Status reports and cheap evidence are still allowed. |
| Safe landing | `3%` | Begin safe landing. Write state/evidence, stop new work, and prepare resume metadata. |
| Exhausted | `0%` or explicit `exhausted` | Wait for reset or a recovered budget signal. |

How to choose thresholds:

- Use higher low-budget thresholds for expensive multi-ship runs, premium models, or high retry risk.
- Keep the safe-landing threshold conservative enough to write reports before budget exhaustion.
- Treat configured percentages as operator-provided signals unless a trusted local status signal exists.
- Never invent exact remaining percentages or reset times.
- If budget is unknown, use `ALLOW_STATUS_ONLY` instead of `ALLOW_RUN`.

Default rationale:

`10%` creates room to stop launching new work before panic. `3%` reserves a
small final buffer for safe landing evidence. These values can be tuned per run,
but lower thresholds increase the chance of abrupt model/rate failure.

## Implementation Status

Status: GREEN

Implemented by `Resolve-FleetRateGovernor` in `tools/codex-fleet-overnight.ps1`.
It supports configured percentages, manual budget levels, low/critical
thresholds, status-only unknown budget behavior, reset metadata, and
conservative blocking decisions.
