# Stage 1 Audit Prompt

Use this prompt after Stage 1 implementation is complete and an audit package is
created.

```text
You are auditing Codex Fleet after Golden Gameplan Stage 1: Stability First.

Context:
Codex Fleet is a local PowerShell-based orchestration system for AI coding
projects called ships. Stage 1 was supposed to fix reliability blockers before
the fleet builds a full autonomy loop.

Stage 1 goals:
1. Safe-stop requests are scoped to selected ships.
2. Phase 13 experiment runner writes Markdown and JSON evidence.
3. Long-running loops have retry/time caps where needed.
4. Repo-state checks distinguish clean, dirty, missing, and git-error states.
5. Lock and heartbeat handling is less likely to false-clean active work.
6. Project/output paths resolve predictably from config or fleet root.
7. Base branches are configured rather than blindly assumed as main.
8. Safe generated ship names cannot collide silently.

Audit the attached package and answer:

1. Is Stage 1 complete enough to start Stage 2?
2. Which Stage 1 fixes are correctly implemented?
3. Which Stage 1 fixes are incomplete or risky?
4. Did any change introduce a new safety risk?
5. Are the tests strong enough, or are they only checking happy paths?
6. Does .\tests\run-fleet-tests.ps1 pass?
7. Are there remaining P0/P1 blockers?
8. What is the smallest patch list before Stage 2?

Output format:
- Verdict: GREEN / YELLOW / RED
- Top blockers
- Evidence cited by file
- Missing tests
- Recommended patch order
- Decision: proceed to Stage 2 or stop

Do not suggest Stage 2 features unless Stage 1 is stable enough.
Do not recommend product repo work.
Focus on reliability and safety only.
```

