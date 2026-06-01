# Stage 13 Phase 3 Prompt: Safe Remote Actions

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 13 Phase 3 only: Safe Remote Actions.

Goal:
Define which actions may be requested remotely and what validation each requires.

Safe remote action candidates:
- STATUS
- DIGEST
- PARK_SHIP
- REQUEST_SAFE_STOP
- APPROVE_TASTE_DIRECTION
- APPROVE_PACKET_IMPORT
- RUN_DRY_CHECK
- RUN_ONE_BOUNDED_BATCH
- PACKAGE_AUDIT
- CAPTURE_IDEA
- SET_OVERNIGHT_PRESET
- RESUME_AFTER_RESET

For each action define:
- required scope
- required state
- required approvals
- forbidden states
- budget/rate checks
- expected output
- failure response

Always forbidden remotely by default:
- merge
- push
- deploy
- delete user work
- kill active processes manually
- edit secrets/env
- change auth/payments
- run implicit all-fleet command

Guardrails:
- This phase defines actions only.
- Remote actions create local requests; they do not execute directly.
- RUN_ONE_BOUNDED_BATCH requires explicit ship scope, dry-run output, state check, and budget check.
- RESUME_AFTER_RESET requires Stage 10 resume eligibility evidence.
- APPROVE_TASTE_DIRECTION cannot approve backend, auth, payment, deployment, secret, migration, dependency, or formula-trust work.
- Do not implement execution.
- Do not integrate with phone/SMS/email.

Acceptance:
- Safe remote action matrix exists.
- Every action has validation requirements.
- Forbidden actions are explicit.

Proof:
Show action matrix path and examples.
```

## Notes

The user should be powerful from the phone, not dangerous from the phone.

## Implemented Safe Remote Action Matrix

| Action | Scope | Approval | Dry Run | Remote Result |
| --- | --- | --- | --- | --- |
| `STATUS` | optional | no | no | phone summary only |
| `DIGEST` | optional | no | no | phone digest only |
| `CAPTURE_IDEA` | optional | no | no | idea record only |
| `REQUEST_SAFE_STOP` | explicit ship | local review | no | request record |
| `PARK_SHIP` | explicit ship | yes | no | request record |
| `APPROVE_TASTE_DIRECTION` | explicit ship | yes | no | approval request |
| `APPROVE_PACKET_IMPORT` | explicit ship | yes | no | approval request |
| `RUN_DRY_CHECK` | explicit ship | no | no | request record |
| `RUN_ONE_BOUNDED_BATCH` | explicit ship | yes | yes | approval request |
| `PACKAGE_AUDIT` | explicit ship | no | no | request record |
| `SET_OVERNIGHT_PRESET` | explicit ships | yes | yes | approval request |
| `RESUME_AFTER_RESET` | explicit ship | yes | yes | approval request |

Always rejected remotely by default:

- merge
- push
- deploy
- delete user work
- manual lock deletion
- raw process killing
- secrets/env edits
- auth/payments/migrations/package changes without local high-risk approval
- implicit all-fleet run requests

All implemented suggestions set `executes = false`.
