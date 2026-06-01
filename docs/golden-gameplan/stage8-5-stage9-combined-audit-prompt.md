# Combined Stage 8.5 + Stage 9 External Audit Prompt

```text
You are auditing Codex Fleet Golden Gameplan Stage 8.5 and Stage 9.

Context:
- Stage 8.5 is Autonomy Wrapper Hardening.
- Stage 9 is External Agent Workflow.
- Do not evaluate Stage 10 overnight mode yet.
- Do not ask the fleet to launch product ships, touch product repos, merge, push, deploy, delete locks, or bypass validation.

Goal of Stage 8.5:
The fleet should harden the bounded autonomy wrapper before external-agent workflow begins.

Stage 8.5 audit questions:
1. Does packet import require a real Stage 4 validation artifact rather than a boolean flag?
2. Does missing, invalid, malformed, stale, outside-scope, or unsafe packet evidence block import?
3. Does the wrapper default to one selected ship unless MaxShips is explicitly raised?
4. Are corrupt state evidence, audit package failure, and run-batch budget failure contained with reports?
5. Are reports readable from a phone with a clear captain summary and next action?
6. Is LowTokenMode documented as manual only, not automatic rate-limit detection?

Goal of Stage 9:
The fleet should formalize the external-agent review loop without letting outside agents control the repo.

Stage 9 audit questions:
1. Are external agent roles clear and non-overlapping?
2. Can the harness generate reusable pasteable prompts for each role?
3. Does the response format produce structured findings, rejected ideas, captain questions, and task-packet suggestions?
4. Does validation reject stale base commits, unknown roles, malformed packets, forbidden scope, deploy/package/auth/payment-style suggestions, and broad unsafe redesigns?
5. Does multi-agent comparison separate ACCEPT, ACCEPT_WITH_EDITS, DEFER, REJECT, and NEEDS_CAPTAIN style outcomes?
6. Is human/captain review treated as the final taste/high-risk approval gate, not the normal repair path for broken builds or stalled loops?
7. Does Stage 9 avoid calling external agents, ingesting packets, launching ships, or starting overnight behavior?

Evidence to inspect:
- `docs/codex/RUN_RESULT.json`
- `docs/codex/RUN_SUMMARY.md`
- `docs/codex/EVIDENCE_INDEX.md`
- `docs/golden-gameplan/08.5-autonomy-wrapper-hardening/`
- `docs/golden-gameplan/09-external-agent-workflow/`
- `docs/templates/external-agent-workflow/`
- `invoke-autonomy-wrapper.ps1`
- `tools/codex-fleet-autonomy.ps1`
- `tools/codex-fleet-external-agent.ps1`
- `new-external-agent-workflow.ps1`
- `tests/run-fleet-tests.ps1`
- latest test transcript evidence under `out/stage9-test-evidence/`

Return:
- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Separate verdicts for Stage 8.5 and Stage 9.
- Top 5 issues, ordered by severity.
- Any unsafe action mappings or validation bypasses.
- Any prompt/report gaps that would confuse a phone/mobile review.
- Any missing tests before Stage 10.
- Recommended fixes before implementing Stage 10.

Do not recommend implementing Stage 10 inside this audit. Stage 10 is the next separate stage for overnight mode, rate-limit protection, safe landing, and auto-resume.
```

