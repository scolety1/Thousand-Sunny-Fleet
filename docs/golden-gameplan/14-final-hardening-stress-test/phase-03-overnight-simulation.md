# Stage 14 Phase 3 Prompt: Overnight Simulation

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 14 Phase 3 only: Overnight Simulation.

Goal:
Define a simulated overnight run that proves Stage 10 without burning a real night or real limits.

Simulation should cover:
- takeoff watch
- stable check cadence
- one ship succeeds
- one ship fails and is contained
- one ship reaches taste gate
- budget moves from healthy to low to critical
- safe landing triggers
- reset window occurs
- eligible ship resumes
- blocked/taste-gated ship does not resume
- morning report is generated

Required evidence:
- simulated timeline
- state transitions
- decisions
- budget governor decisions
- safe landing report
- resume metadata
- morning report

Guardrails:
- Use fixture/simulated budget signals.
- Do not use real rate-limit exhaustion.
- Do not schedule actual overnight work.
- Do not touch product repos.

Acceptance:
- Overnight simulation plan exists.
- Expected timeline and outputs are documented.
- Safety behavior is proven in principle.

Proof:
Show simulation doc and expected report examples.
```

## Notes

This is the rehearsal before trusting the fleet while asleep.

## Implemented Simulation Expectations

Timeline:

| Time | Event | Expected State | Evidence |
| --- | --- | --- | --- |
| T+0 | takeoff watch | selected fixtures only | overnight contract |
| T+20 | stable check | RUNNING remains untouched | status report |
| T+40 | one success | AUDIT_READY or PARKED | run evidence |
| T+60 | one failure | REPAIRING/BLOCKED | failed gate report |
| T+80 | taste gate | TASTE_GATE | product evidence |
| T+100 | budget low | BLOCK_NEW_WORK | governor report |
| T+120 | budget critical | SAFE_LAND_NOW | safe landing metadata |
| reset | reset window | WAIT_FOR_RESET until eligible | resume metadata |
| resume | eligible only | recovered fixture may resume | resume eligibility |
| morning | summary | phone-readable report | morning report |

Expected behavior:

- blocked and taste-gated ships do not auto-resume
- recovered budget alone is insufficient without Stage 10 eligibility
- unknown budget remains status-only
