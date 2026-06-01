# Stage 11 Phase 5 Prompt: Backend-Sensitive Work Lane

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 11 Phase 5 only: Backend-Sensitive Work Lane.

Goal:
Define the lane for high-risk backend, auth, payment, deployment, migration, dependency, and secret-adjacent work.

This lane covers:
- auth
- payments
- deployment config
- production data
- database migrations
- package/dependency updates
- secrets/env files
- external API contracts
- backend services

Required priorities:
- explicit approval
- minimal scope
- rollback plan
- test coverage
- security/scope audit
- migration/API contract review
- no silent broad changes

Required evidence:
- approval note
- changed files list
- risk assessment
- tests
- rollback instructions
- secret scan or scope check
- migration/API compatibility notes when relevant

Forbidden by default:
- autonomous execution without approval
- broad refactors
- storing secrets
- payment/auth changes inside normal website runs
- dependency churn for convenience
- deploy/push/merge without explicit command

Guardrails:
- Do not implement backend changes in this phase.
- Do not modify package files.
- Do not touch secrets or env files.
- Do not run deploy commands.

Acceptance:
- Backend-sensitive lane profile exists.
- It clearly escalates high-risk work out of normal autonomy.
- It includes approval gates and rollback expectations.

Proof:
Show profile path and examples.
```

## Notes

This lane is the fleet's seatbelt for expensive mistakes.

## Implementation Status

Status: GREEN

Implemented as lane ID `backend_sensitive`. Backend/auth/payment/deploy/
migration/package/dependency/secret scope overrides normal lane routing and
requires captain approval by default.
