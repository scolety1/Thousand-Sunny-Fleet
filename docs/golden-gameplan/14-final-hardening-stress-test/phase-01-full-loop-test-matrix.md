# Stage 14 Phase 1 Prompt: Full-Loop Test Matrix

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 14 Phase 1 only: Full-Loop Test Matrix.

Goal:
Define the complete test matrix for the Golden Gameplan.

The matrix should cover stages:
- Stability First
- Standard Run Evidence
- Audit Package Loop
- Task Packet Ingestion
- State Machine
- Decision Engine
- Product Quality Contracts
- Autonomy Wrapper
- External Agent Workflow
- Overnight Mode
- Specialized Lanes
- Dashboard and Control Room
- Mobile Captain Console

For each stage define:
- feature under test
- fixture needed
- expected output
- failure mode
- evidence path
- pass/fail criteria

Guardrails:
- Do not run tests yet.
- Do not implement missing code.
- Do not touch downstream repos.
- Keep the matrix actionable, not theoretical.

Acceptance:
- Full-loop test matrix exists.
- Every prior stage has at least one test scenario.
- Critical paths have multiple scenarios.

Proof:
Show matrix path and coverage summary.
```

## Notes

This phase says what "tested" means before we start stress testing.

## Implemented Full-Loop Matrix

| Stage | Feature Under Test | Fixture | Expected Output | Failure Mode | Evidence | Pass Criteria |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | safe stop / lock scope | active owned fixture | no unsafe touch | ambiguous lock | state/status report | no manual lock deletion |
| 2 | standard evidence | run evidence fixture | `RUN_RESULT`, summary, index | missing evidence | docs/codex evidence paths | no hollow success |
| 3 | audit package | dirty harness fixture | package with diffs/snapshots | dirty no diffs | audit manifest | reviewable package |
| 4 | task packet ingestion | packet fixtures | accept valid/reject bad | stale/malformed/forbidden | validation logs | no unsafe queue mutation |
| 5 | state machine | state fixtures | legal states/transitions | unknown state tries to run | state JSON/report | unknown blocks action |
| 6 | decision engine | decision fixtures | deterministic decision | failed gate says run | decision report | repair/block overrides run |
| 7 | product quality | UI evidence fixtures | taste/overload/done verdicts | feature dump | product-quality evidence | taste is distinct from failure |
| 8 | autonomy wrapper | selected fixture | one bounded action | missing scope | wrapper report | no implicit all-fleet |
| 9 | external agent workflow | audit response fixtures | compare/validate reports | bad advice | comparison summary | unsafe advice rejected |
| 10 | overnight mode | budget simulation | safe landing/resume report | low budget launches | overnight report | critical budget stops work |
| 11 | specialized lanes | lane fixtures | correct lane/gates | backend hidden as frontend | lane report | sensitive work escalates |
| 12 | control room | status fixture | dashboard JSON/MD | blocked hidden | control-room report | first screen clear |
| 13 | mobile console | phone text fixture | request-only record | phone executes command | mobile report | `executes = false` |

Critical path scenarios are also enumerated in
`tools/codex-fleet-final-readiness.ps1`.
