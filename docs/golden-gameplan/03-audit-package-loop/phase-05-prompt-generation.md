# Stage 3 Phase 5: Audit Prompt Generation

## Goal

Generate the prompts that external agents should use with the audit package.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 3 Phase 5 only: Audit prompt generation.

Do not implement any other Golden Gameplan phase.

Goal:
Add prompt files to each audit package so the captain can send the same evidence
bundle to external agents with clear roles.

Before editing:
- Run .\fleet-status.ps1.
- Inspect the package builder and existing audit prompts.
- Review the three external-agent roles: issue auditor, improvement auditor,
  decision architect.

Scope:
- Likely files: package builder script, prompt templates, tests/run-fleet-tests.ps1.
- Do not call external agents.
- Do not parse responses.

Required prompt files:
- prompts/issues-audit.md
- prompts/improvement-audit.md
- prompts/decision-architect.md

Prompt requirements:
- Tell the agent to rely on included evidence.
- Ask for file citations when possible.
- Ask for severity or priority.
- Ask for smallest practical fixes.
- Ask for missing tests.
- Ask for an explicit proceed/stop verdict when relevant.
- Prohibit broad rewrites, production deploys, or sensitive changes unless
  evidence proves they are necessary.

Acceptance:
- Add tests that prompt files are included.
- Add tests that prompt files mention the selected ship or package context.
- Add tests that decision prompt asks for concrete next implementation plan.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/03-audit-package-loop/checkpoint.md.

Stop if:
- Prompt generation needs Stage 4 task packet schema. Keep prompts textual and
  defer machine-ingest output to Stage 4.
```

## Done When

Every package includes ready-to-send external audit prompts.

