# Golden Gameplan Stage 8.5 Audit Prompt

```text
You are auditing Codex Fleet Golden Gameplan Stage 8.5: Autonomy Wrapper Hardening.

Goal:
Stage 8.5 should tighten the Stage 8 bounded autonomy wrapper before Stage 9 external-agent workflow begins.

Please review the provided code, docs, tests, and evidence.

Audit questions:
1. Does packet import require a real Stage 4 validation artifact instead of a boolean flag?
2. Does the wrapper block missing, malformed, invalid, forbidden, or outside-scope packet evidence?
3. Does default scope limit autonomy to one selected ship unless MaxShips is explicitly raised?
4. Are corrupt state evidence and action failures contained with JSON/Markdown reports?
5. Do reports include a phone-readable captain summary and clear next action?
6. Is LowTokenMode clearly documented as manual, not automatic rate-limit detection?
7. Is there any unsafe path to launch product ships, broaden scope, merge, push, deploy, delete locks, or bypass validation?

Return:
- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues by severity.
- Remaining YELLOW/RED items before Stage 9.
- Recommended fixes before starting Stage 9.

Do not recommend implementing Stage 9, Stage 10, or Stage 13 inside this stage.
```

