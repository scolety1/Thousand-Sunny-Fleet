# Stage 9 Phase 7 Prompt: Captain Summary And Approval Points

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 9 Phase 7 only: Captain Summary and Approval Points.

Goal:
Define the summary the user sees after external audits return.

The captain summary should show:
- selected ship
- audit roles used
- consensus findings
- urgent blockers
- accepted task candidates
- rejected task candidates
- deferred ideas
- taste questions
- high-risk approvals needed
- recommended next command

Approval points should be required for:
- broad redesigns
- dependency changes
- backend/auth/payment/deployment changes
- formula strategy changes
- destructive cleanup
- merge/push/deploy
- taste direction when reports conflict

Guardrails:
- Do not overwhelm the captain with raw audit text.
- Do not hide serious findings.
- Do not ask the captain to approve every tiny safe task.
- Keep mobile readability in mind.

Acceptance:
- Captain summary template exists.
- Approval categories are explicit.
- Example summary exists for a website ship and an analytical ship.

Proof:
Show summary template and examples.
```

## Notes

This is the user-facing bridge: enough control without turning every loop into homework.

## Implementation Status

Status: GREEN

Implemented in `docs/templates/external-agent-workflow/captain-summary-template.md`. Human/captain review is documented as the final taste/high-risk approval gate, not the normal repair path.
