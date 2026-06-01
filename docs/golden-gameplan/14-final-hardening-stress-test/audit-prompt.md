# Golden Gameplan Stage 14 Audit Prompt

Use this prompt after Stage 14 is implemented and tested.

```text
You are auditing Codex Fleet Golden Gameplan Stage 14: Final Hardening and Stress Test.

Goal of Stage 14:
The fleet should have a complete hardening and stress-test plan covering full-loop behavior, overnight simulation, failure injection, audit/task packet stress, rollback/recovery, and final readiness.

Please review the docs, matrices, fixtures, examples, scorecard, and checkpoint.

Audit questions:

1. Does the full-loop matrix cover all stages from 1-13?
2. Are fixture/disposable ships enough to test without risking real user work?
3. Does the overnight simulation prove safe landing and resume behavior?
4. Does failure injection cover the real ways the fleet has failed before?
5. Are external audit and task packet stress cases realistic?
6. Are rollback/recovery checks careful enough with user work?
7. Is the readiness scorecard honest and actionable?
8. Are go/no-go criteria clear?
9. Are any critical failure modes missing?
10. Would you trust this plan before implementing the final autonomy system?

Return:

- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues, ordered by severity.
- Any missing stress tests.
- Any unsafe rollback assumption.
- Any readiness criterion that is too vague.
- Recommended fixes before implementation begins.

Do not recommend real product stress tests until fixture coverage is proven.
```

