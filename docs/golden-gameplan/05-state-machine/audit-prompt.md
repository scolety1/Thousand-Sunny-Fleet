# Golden Gameplan Stage 5 Audit Prompt

Use this prompt after Stage 5 is implemented and tested.

```text
You are auditing Codex Fleet Golden Gameplan Stage 5: State Machine.

Goal of Stage 5:
The fleet should record canonical, machine-readable ship lifecycle state without making autonomous rerun decisions.

Please review the provided audit package, code, docs, tests, and sample state outputs.

Audit questions:

1. Are the state values clear, finite, and mutually understandable?
2. Is the state schema complete enough to support later decisions without becoming bloated?
3. Does the system distinguish RUNNING, READY, BLOCKED, REPAIRING, AUDIT_READY, PACKET_READY, TASTE_GATE, RATE_LIMIT_PAUSED, PARKED, and UNKNOWN correctly?
4. Does Stage 5 avoid implementing the Stage 6 decision engine too early?
5. Are active dirty ships protected from being misclassified as safe to touch?
6. Are missing legacy files handled safely?
7. Does the reporting help a remote human captain understand what is happening quickly?
8. Are transition rules documented and validated?
9. Are rate-limit paused states represented without pretending reset automation is already solved?
10. Are there any gaps that would cause overnight runs to stall or misreport progress?

Return:

- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues, ordered by severity.
- Any state names that should be changed before Stage 6.
- Any missing fields in the schema.
- Any unsafe transitions.
- Recommended fixes before implementing Stage 6.

Do not suggest broad new architecture unless Stage 5 cannot safely support Stage 6.
```

