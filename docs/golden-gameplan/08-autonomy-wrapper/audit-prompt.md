# Golden Gameplan Stage 8 Audit Prompt

Use this prompt after Stage 8 is implemented and tested.

```text
You are auditing Codex Fleet Golden Gameplan Stage 8: Autonomy Wrapper.

Goal of Stage 8:
The fleet should have a bounded command that ties together state, decisions, audit packages, task packets, and product quality contracts for one controlled cycle.

Please review the provided audit package, code, docs, tests, dry-run reports, bounded-cycle reports, and failure cases.

Audit questions:

1. Does the wrapper require explicit selected ship scope?
2. Is dry-run truly side-effect free?
3. Are decisions mapped to safe bounded actions?
4. Can the wrapper execute at most one bounded action per ship per cycle?
5. Are high-risk actions blocked instead of executed?
6. Are budgets and loop limits strict enough to prevent runaway runs?
7. Does low-token mode prevent implementation work?
8. Are reports clear enough for the captain to understand from a phone?
9. Are failures contained to selected ships and actions?
10. Is there any path where the wrapper can launch the whole fleet accidentally?

Return:

- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues, ordered by severity.
- Any unsafe action mappings.
- Any missing budget guardrails.
- Any report gaps.
- Recommended fixes before implementing Stage 9.

Do not recommend overnight scheduling yet. That belongs to Stage 10.
```

