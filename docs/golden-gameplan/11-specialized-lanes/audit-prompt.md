# Golden Gameplan Stage 11 Audit Prompt

Use this prompt after Stage 11 is implemented and tested.

```text
You are auditing Codex Fleet Golden Gameplan Stage 11: Specialized Lanes.

Goal of Stage 11:
The fleet should classify work into specialized lanes so different projects receive different task rules, review gates, evidence requirements, budget modes, and stop conditions.

Please review the docs, lane profiles, examples, escalation rules, fixture mappings, and checkpoint.

Audit questions:

1. Are the five lanes clear and distinct?
2. Does the hospitality website lane prioritize guest-facing beauty, mobile, hierarchy, and brand feel?
3. Does the manager/internal lane prioritize daily workflow, status, priority, and action?
4. Does the analytical software lane prioritize formulas, fixtures, tests, assumptions, and audit receipts?
5. Does the backend-sensitive lane protect auth, payments, deployment, migrations, dependencies, secrets, and production data?
6. Does the maintenance lane stay small, cheap, and specific?
7. Are lane selection and escalation rules conservative enough?
8. Are review gates and evidence requirements appropriate for each lane?
9. Are overnight eligibility rules different enough by lane?
10. Are any tasks likely to be misclassified?

Return:

- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues, ordered by severity.
- Any lane that needs sharper boundaries.
- Any missing escalation rule.
- Any risky default.
- Recommended fixes before Stage 12.

Do not recommend merging lanes unless the distinction is truly unnecessary.
```

