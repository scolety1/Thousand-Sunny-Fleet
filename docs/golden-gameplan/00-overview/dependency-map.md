# Golden Gameplan Dependency Map

This document prevents the stages from blurring together. Each stage may define
future behavior, but implementation should move in this order unless the captain
explicitly asks for planning-only docs.

## Linear Dependency Chain

```text
Stage 1  Stability First
  -> Stage 2  Standard Run Evidence
  -> Stage 3  Audit Package Loop
  -> Stage 4  Task Packet Ingestion
  -> Stage 5  State Machine
  -> Stage 6  Decision Engine
  -> Stage 7  Product Quality Contracts
  -> Stage 8  Autonomy Wrapper
  -> Stage 9  External Agent Workflow
  -> Stage 10 Overnight Mode
  -> Stage 11 Specialized Lanes
  -> Stage 12 Dashboard and Control Room
  -> Stage 13 Mobile Captain Console
  -> Stage 14 Final Hardening and Stress Test
```

## Contract Ownership

| Contract | Owner Stage | Consumers |
|---|---:|---|
| Safe stop scoping, lock safety, base branch config | 1 | all later stages |
| `RUN_RESULT.json`, `RUN_SUMMARY.md`, `EVIDENCE_INDEX.md` | 2 | 3, 5, 6, 7, 8, 12, 14 |
| Audit manifest and audit package layout | 3 | 9, 12, 14 |
| Task packet schema, validation, safe queue append | 4 | 8, 9, 12, 13, 14 |
| Ship lifecycle states | 5 | 6, 8, 10, 12, 13, 14 |
| Decision vocabulary and precedence rules | 6 | 8, 10, 12, 13, 14 |
| Product contracts and taste gates | 7 | 6, 8, 9, 11, 12, 14 |
| One bounded autonomy cycle | 8 | 10, 12, 13, 14 |
| External reviewer prompts and comparison workflow | 9 | 4, 8, 12, 14 |
| Rate governor, safe landing, auto-resume policy | 10 | 12, 13, 14 |
| Specialized lane routing | 11 | 7, 8, 10, 12, 14 |
| Read-only dashboard/control room | 12 | 13, 14 |
| Phone command protocol and mobile digest | 13 | 8, 10, 12, 14 |
| Fixture stress tests and readiness scorecard | 14 | all stages |

## Boundary Rules

Stage 3 packages evidence. It does not ingest external work.

Stage 4 validates and ingests task packets. It does not decide whether a packet
is strategically good; Stage 9 and the captain do that.

Stage 5 reports state. It does not choose actions.

Stage 6 chooses actions. It does not execute them.

Stage 8 executes one bounded local action after earlier gates approve it. It
does not schedule overnight work, run mobile commands, or orchestrate external
agents.

Stage 9 creates and compares external audit advice. External agents never edit
repos, bypass validation, or run the fleet.

Stage 10 handles unattended time, rate budget, safe landing, and conservative
resume. It does not add phone command handling.

Stage 13 accepts remote/mobile requests. Those requests are only requests until
local validation, state, budget, and decision checks pass.

Stage 14 stress tests only disposable fixtures or explicitly selected safe
scopes. It is not a license to run destructive tests on real product repos.

## Missing Dependency Rule

If a phase says to use a capability from a later stage, treat that as a
planning reference. During implementation, either:

1. use the current stage's minimal local equivalent, or
2. stop and write a dependency note in the phase report.

Do not silently implement later-stage behavior inside an earlier phase.

