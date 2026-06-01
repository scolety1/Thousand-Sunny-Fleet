# Golden Gameplan Stage 13 Audit Prompt

Use this prompt after Stage 13 is implemented and tested.

```text
You are auditing Codex Fleet Golden Gameplan Stage 13: Mobile Captain Console.

Goal of Stage 13:
The fleet should define a safe phone-friendly control layer for status, command inbox, safe remote actions, idea intake, rate-limit alerts, mobile digests, and approvals.

Please review the docs, schemas, examples, fixture responses, and checkpoint.

Audit questions:

1. Are status reports short and useful on a phone?
2. Does the command inbox treat remote messages as untrusted until validated?
3. Are safe remote actions constrained enough?
4. Are forbidden remote actions explicit?
5. Does idea intake preserve thoughts without immediately creating unsafe tasks?
6. Are rate-limit alerts clear, conservative, and tied to Stage 10?
7. Is the mobile digest honest and compact?
8. Are approval rules strong enough for high-risk actions?
9. Are ambiguous commands rejected or clarified?
10. Could any mobile command accidentally launch all ships or bypass safety gates?

Return:

- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues, ordered by severity.
- Any unsafe remote action.
- Any missing alert or digest type.
- Any approval wording that is too weak.
- Recommended fixes before Stage 14.

Do not recommend implementing real messaging until the protocol is safe.
```

