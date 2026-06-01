# Golden Gameplan Stage 10 Audit Prompt

Use this prompt after Stage 10 is implemented and tested.

```text
You are auditing Codex Fleet Golden Gameplan Stage 10: Overnight Mode.

Goal of Stage 10:
The fleet should support safer unattended runs with a rate governor, safe landing at low budget, reset/resume metadata, auto-resume eligibility, scheduled checks, and morning reports.

Please review the provided docs, configs, tests, reports, fixture runs, and examples.

Audit questions:

1. Does overnight mode require explicit selected scope?
2. Does the rate governor prevent new work at low/critical budget?
3. Does the 3% or critical threshold trigger safe landing correctly?
4. Does safe landing write evidence and state before stopping?
5. Is RATE_LIMIT_PAUSED represented clearly?
6. Is reset timing handled honestly when exact reset is unknown?
7. Are auto-resume eligibility rules conservative enough?
8. Can blocked or taste-gated ships accidentally resume?
9. Are max resume attempts and end times enough to prevent retry loops?
10. Is the morning report honest and useful?

Return:

- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues, ordered by severity.
- Any unsafe resume path.
- Any missing rate-governor condition.
- Any reporting gap.
- Recommended fixes before Stage 11.

Do not recommend broad unattended autonomy unless safe landing and resume eligibility are proven.
```

