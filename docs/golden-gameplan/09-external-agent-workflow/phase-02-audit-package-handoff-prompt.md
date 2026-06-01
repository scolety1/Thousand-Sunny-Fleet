# Stage 9 Phase 2 Prompt: Audit Package Handoff Prompt

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 9 Phase 2 only: Audit Package Handoff Prompt.

Goal:
Create the standard prompt a user can paste into ChatGPT Pro or another external agent with a Fleet audit package.

The prompt should tell the external agent:
- what Codex Fleet is
- what the selected ship is
- what evidence is included
- what role the agent should play
- what questions to answer
- what output format to use
- what must not be suggested
- how to write task packets

The handoff prompt should include placeholders for:
- ship name
- role
- audit package path/name
- current mission
- known constraints
- desired output type
- urgency/budget mode

Guardrails:
- Do not include secrets.
- Do not tell the external agent to edit files.
- Do not ask for broad rewrites unless explicitly selected.
- Keep the prompt reusable.

Acceptance:
- A reusable handoff prompt exists.
- The prompt supports role-specific insertion.
- The prompt asks for concise findings and structured task packets.

Proof:
Show prompt path and an example filled-in prompt.
```

## Notes

This should be the message the user can paste directly when asking three agents to audit the system.

## Implementation Status

Status: GREEN

Implemented in `docs/templates/external-agent-workflow/handoff-prompt-template.md` and `new-external-agent-workflow.ps1 -Mode Prompt`.
