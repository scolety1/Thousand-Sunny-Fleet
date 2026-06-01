# Golden Gameplan Stage 6 Audit Prompt

Use this prompt after Stage 6 is implemented and tested.

```text
You are auditing Codex Fleet Golden Gameplan Stage 6: Decision Engine.

Goal of Stage 6:
The fleet should convert canonical ship state and run evidence into a safe next-action decision, without executing that decision automatically.

Please review the provided audit package, code, docs, tests, schemas, decision examples, and reports.

Audit questions:

1. Is the decision vocabulary clear and complete?
2. Does the decision engine use Stage 5 state and Stage 2-4 evidence correctly?
3. Is the decision function pure, deterministic, and testable?
4. Are repair and block decisions correctly prioritized over RUN_AGAIN?
5. Are active dirty ships protected with NOOP instead of unsafe action?
6. Does RUN_AGAIN require valid tasks, clean repo, budget, and no blockers?
7. Are PARK and USER_TASTE_GATE meaningfully different?
8. Are rate-limit pauses represented as WAIT_FOR_RATE_RESET without pretending full auto-resume is done?
9. Are missing or conflicting inputs handled conservatively?
10. Do reports give the captain enough information to act from a phone?

Return:

- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues, ordered by severity.
- Any unsafe decision paths.
- Any missing decision types.
- Any evidence fields needed before Stage 7.
- Recommended fixes before implementing product quality contracts.

Do not recommend autonomous execution unless the decision layer is already safe and well-tested.
```

