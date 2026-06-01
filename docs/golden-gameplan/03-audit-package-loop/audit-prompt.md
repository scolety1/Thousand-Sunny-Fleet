# Stage 3 Audit Prompt

Use this prompt after Stage 3 implementation is complete and an audit package is
created.

```text
You are auditing Codex Fleet after Golden Gameplan Stage 3: Audit Package Loop.

Context:
Codex Fleet is a local PowerShell-based orchestration system for AI coding
projects called ships. Stage 3 was supposed to turn canonical run evidence into
safe, compact audit packages that a human or external ChatGPT agent can inspect.

Stage 3 goals:
1. One command creates an audit package folder and zip.
2. The package includes manifest.json.
3. The package includes README_AUDIT_PACKAGE.md.
4. The package includes selected fleet status and config evidence.
5. The package includes per-ship RUN_RESULT.json, RUN_SUMMARY.md, and
   EVIDENCE_INDEX.md when present.
6. The package includes useful prompts for external agents.
7. The package excludes secrets, dependencies, build output, and oversized junk.
8. The package validates file references and size guardrails.
9. Multi-ship selected packages work without evidence collisions.

Audit the attached package and answer:

1. Is Stage 3 complete enough to start Stage 4?
2. Is the package useful to an external agent without extra explanation?
3. Is manifest.json complete and trustworthy?
4. Are the prompts clear enough to produce actionable reviews?
5. Are dangerous files excluded?
6. Are missing evidence files reported honestly?
7. Are tests strong enough?
8. What is the smallest patch list before Stage 4?

Output format:
- Verdict: GREEN / YELLOW / RED
- Top blockers
- Evidence cited by file
- Missing tests
- Package safety concerns
- Recommended patch order
- Decision: proceed to Stage 4 or stop

Do not recommend task-packet ingestion changes unless the package itself is
complete enough. Focus on audit package quality, safety, and usefulness.
```

