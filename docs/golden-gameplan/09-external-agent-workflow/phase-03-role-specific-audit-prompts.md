# Stage 9 Phase 3 Prompt: Role-Specific Audit Prompts

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 9 Phase 3 only: Role-Specific Audit Prompts.

Goal:
Write specialized external audit prompts for each role.

Create prompts for:
- Issue Auditor
- Improvement Auditor
- Product Taste Auditor
- Formula Auditor
- Security / Scope Auditor
- Tie-Breaker Auditor

Each prompt should request:
- verdict
- top issues
- evidence references
- recommended tasks
- task packet JSON when appropriate
- what to reject or avoid
- questions for the captain

Role-specific requirements:
- Product Taste Auditor should focus on first-screen clarity, information hierarchy, copy, and overwhelm.
- Formula Auditor should focus on deterministic formulas, tests, fixtures, assumptions, and fake-confidence risks.
- Security / Scope Auditor should focus on forbidden files, secrets, auth, payments, deploy config, package changes, and risky migrations.
- Tie-Breaker Auditor should reconcile multiple reports and produce a conservative plan.

Guardrails:
- Do not let prompts ask for direct repo edits.
- Do not ask for code dumps.
- Do not allow task packets that skip fleet validation.

Acceptance:
- Every role prompt exists.
- Prompts are specific and non-overlapping.
- Prompts produce outputs the fleet can validate later.

Proof:
Show prompt paths and brief summaries.
```

## Notes

Specific prompts are the difference between useful audits and vague consultant fog.

## Implementation Status

Status: GREEN

Implemented through role-specific guidance in `tools/codex-fleet-external-agent.ps1`.
