# Stage 2 Audit Prompt

Use this prompt after Stage 2 implementation is complete and an audit package is
created.

```text
You are auditing Codex Fleet after Golden Gameplan Stage 2: Standard Run Evidence.

Context:
Codex Fleet is a local PowerShell-based orchestration system for AI coding
projects called ships. Stage 2 was supposed to create canonical run evidence so
later stages can build audit packages, task ingestion, state machines, decision
engines, overnight mode, and mobile status reports.

Stage 2 goals:
1. Normal runs write docs/codex/RUN_RESULT.json.
2. Normal runs write docs/codex/RUN_SUMMARY.md.
3. Normal runs write docs/codex/EVIDENCE_INDEX.md.
4. Experiment and dry-run paths write compatible evidence.
5. Failed, blocked, quarantined, or partial runs still write honest evidence
   where safe.
6. Evidence files are current and do not accidentally reflect stale previous runs.
7. The test suite validates success, failure, and partial evidence behavior.

Audit the attached package and answer:

1. Is Stage 2 complete enough to start Stage 3?
2. Is RUN_RESULT.json useful as the canonical machine-readable run record?
3. Are RUN_SUMMARY.md and EVIDENCE_INDEX.md useful to a human and an external agent?
4. Are failure and partial-run paths honest, or do they hide errors?
5. Are evidence files stable enough for audit package generation?
6. Are required fields missing or ambiguous?
7. Are tests strong enough, or mostly happy-path checks?
8. What is the smallest patch list before Stage 3?

Output format:
- Verdict: GREEN / YELLOW / RED
- Top blockers
- Evidence cited by file
- Missing tests
- Recommended patch order
- Decision: proceed to Stage 3 or stop

Do not suggest task packet ingestion or decision engine work unless Stage 2 is
complete enough. Focus on evidence quality and consistency only.
```

