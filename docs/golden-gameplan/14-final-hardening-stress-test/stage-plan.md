# Golden Gameplan Stage 14: Final Hardening and Stress Test

## Purpose

Stage 14 is the final readiness gauntlet for the Golden Gameplan.

It proves that the full fleet loop can survive:

- normal successful runs
- failed builds
- dirty repos
- stale locks
- invalid task packets
- low budget
- overnight pause/resume
- bad external audit advice
- rollback needs
- blocked ships
- taste gates

This stage should answer:

```text
Is Codex Fleet ready to run in a bounded, observable, recoverable way?
```

## Why This Matters

The fleet is only useful if it can be trusted when things go wrong.

The final system should not merely work on happy paths. It should fail well:

- stop safely
- preserve user work
- write evidence
- explain what happened
- refuse unsafe commands
- avoid infinite loops
- avoid wasting rate limits
- show what the captain needs to do next

## Stage 14 Outcome

At the end of Stage 14, the fleet should have:

- full-loop test plan
- overnight simulation plan
- failure injection plan
- audit review plan
- rollback and recovery checks
- readiness scorecard
- final acceptance checklist
- go/no-go criteria
- a fixture-only final readiness scorer
- a machine-readable final readiness report

## Non-Goals

Do not implement these in Stage 14 docs stage:

- actual destructive stress tests on real product repos
- deployment
- merge/push automation
- production secrets testing
- broad product refactors
- unbounded overnight runs

Stress tests must use fixtures, disposable projects, or explicit safe scopes.

Real product repos are out of scope for destructive failure injection unless
the captain names the repo, names the exact test, and approves the rollback
plan. The default Stage 14 target is a disposable fixture suite.

## Final System Capabilities To Prove

The final hardening pass should prove:

```text
1. Evidence is always written.
2. State is always updated.
3. Decisions are deterministic.
4. Product quality gates influence run/park/taste decisions.
5. External task packets are validated.
6. Overnight mode pauses before budget danger.
7. Resume happens only when safe.
8. Dirty repos are protected.
9. Backend-sensitive work escalates.
10. The captain gets a clear report.
```

## Phase List

1. Full-Loop Test Matrix
2. Fixture and Disposable Ship Suite
3. Overnight Simulation
4. Failure Injection
5. Audit Review and Task Packet Stress
6. Rollback and Recovery Checks
7. Final Readiness Scorecard
8. Stage 14 Integration Check

## Acceptance For Stage 14

Stage 14 is complete when:

- every stage from 1-13 has a coverage point
- full-loop tests are specified
- failure injection tests are specified
- overnight simulation is specified
- audit review stress is specified
- rollback checks are specified
- final readiness has clear go/no-go criteria
- no real product code was changed while writing this docs stage
- fixture evidence proves the full loop before any real ship is trusted with
  unattended autonomy

## Final Output

The Golden Gameplan is ready for implementation when Stage 14 can produce:

```text
PASS
PASS WITH FIXES
FAIL
```

with specific evidence and next steps.

## Implemented Surface

Stage 14 adds a fixture-only readiness scorer:

```text
invoke-final-readiness.ps1 -InputPath <readiness-checks.json>
invoke-final-readiness.ps1 -UseExampleFixture
```

It writes:

- JSON scorecard
- Markdown readiness report
- fixture suite mapping
- missing stage/scenario coverage
- final verdict

Verdicts:

```text
READY_FOR_CONTROLLED_USE
READY_WITH_LIMITS
NOT_READY
```

The scorer exits non-zero on `FAIL`/`NOT_READY`, and it does not launch ships,
edit repos, clean worktrees, merge, push, deploy, or delete locks.
