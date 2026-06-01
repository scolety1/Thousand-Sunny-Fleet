# Golden Gameplan Stage 9 Audit Prompt

Use this prompt after Stage 9 is implemented and tested.

```text
You are auditing Codex Fleet Golden Gameplan Stage 9: External Agent Workflow.

Goal of Stage 9:
The fleet should have a clear manual-to-automatable workflow for sending audit packages to outside agents, receiving structured task packets, comparing reports, and safely deciding what can be ingested.

Please review the provided docs, prompts, schemas, examples, and checkpoint.

Audit questions:

1. Are the external agent roles clear and useful?
2. Is the handoff prompt reusable by a human without extra explanation?
3. Are role-specific prompts concrete enough to avoid vague advice?
4. Does the structured response format map cleanly to task packet ingestion?
5. Does multi-agent comparison handle consensus and disagreement safely?
6. Are stale, risky, vague, or broad packets rejected or deferred?
7. Are captain approval points explicit and reasonable?
8. Does the workflow keep external agents from directly controlling the fleet?
9. Is the workflow lightweight enough to use repeatedly?
10. What must be fixed before implementing automated external-audit support?

Return:

- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues, ordered by severity.
- Any missing prompts.
- Any unsafe assumptions.
- Any task packet fields that need changes.
- Recommended fixes before Stage 10.

Do not recommend direct external-agent execution unless the validation loop is safe.
```

