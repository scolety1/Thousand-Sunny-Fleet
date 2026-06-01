# Stage 13 Phase 7 Prompt: Approval And Rejection Rules

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 13 Phase 7 only: Approval and Rejection Rules.

Goal:
Define how mobile approvals work safely.

Approval should be explicit for:
- taste direction
- packet import
- bounded run
- overnight preset
- resume after reset
- backend-sensitive work
- formula strategy change

Approval records should include:
- approvalId
- commandId
- approvedBy
- approvedAt
- approvedScope
- exact approved action
- expiration
- conditions
- revoked flag

Reject or require clarification when:
- scope is missing
- command is broad
- action is forbidden
- ship is blocked
- repo is dirty/unowned
- budget is critical
- approval wording is ambiguous

Guardrails:
- "yes" alone is not enough for high-risk actions.
- Approval expires.
- Approval does not override safety gates.
- Do not implement execution in this stage.

Acceptance:
- Approval/rejection rules exist.
- Examples include safe approval, ambiguous approval, high-risk rejection, and expired approval.

Proof:
Show approval spec and examples.
```

## Notes

This prevents sleepy or rushed phone replies from becoming dangerous.

## Implemented Approval / Rejection Rules

Approval is a request record, not execution authority.

Safe-ish approval example:

```text
Approve taste direction for Bottlelight: use calmer wine-list layout.
```

Result:

```text
APPROVAL_REQUIRED
Requires local approval record.
Does not execute.
```

Ambiguous approval:

```text
yes go for it
```

Result:

```text
NEEDS_CLARIFICATION
Missing exact ship and action.
```

High-risk rejection:

```text
Deploy and push everything tonight.
```

Result:

```text
REJECTED_FORBIDDEN_REMOTE_ACTION
```

Expired approval rule:

Future implementation should attach expiration to approval records. Expired or
revoked approvals must fail validation before Stage 8 action mapping.

Mobile approval never overrides:

- dirty/unowned repo
- critical budget
- missing dry-run
- missing packet validation evidence
- backend/auth/payment/deploy/migration/package safety gates
