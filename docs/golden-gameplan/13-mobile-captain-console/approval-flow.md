# Mobile Approval Flow

Phone approval is safe only when the phone approves a generated plan record.
It must never approve a raw instruction, shell command, broad all-fleet action,
or vague "yes, do it" message.

## Flow

```text
phone message
  -> normalize request
  -> evaluate policy
  -> create generated plan
  -> show approval card
  -> captain approves or rejects
  -> local PC revalidates
  -> execution may be considered by later local stages
```

The mobile layer remains request-only. It writes approval/rejection records and
phone-readable responses; it does not execute fleet work.

## Generated Plan Requirements

A generated plan must include:

- `planId`
- `requestId`
- `ship`
- `action`
- `riskLevel`
- `scope`
- `diffSummary`
- `evidenceSummary`
- `budgetImpact`
- `rollbackPath`
- `expiresAt`
- `idempotencyKey`
- `createdAt`
- `status`

The plan must also show whether the local PC already has proof for:

- explicit ship scope
- clean/owned state
- packet validation evidence, when relevant
- dry-run evidence, when relevant
- budget/rate eligibility
- rollback path

## Phone Approval Card

The first phone card must show:

```text
Ship
Action
Risk level
Diff/evidence summary
Budget impact
Expiration
Rollback path
Approve
Reject
Desktop-only
```

The `Desktop-only` choice is required for anything the captain does not want to
approve from a phone.

## Rejection Rules

Reject or require desktop-only handling when any of these are true:

- missing `planId`
- missing `idempotencyKey`
- expired `expiresAt`
- stale or missing evidence
- missing rollback path
- unbounded budget/cost
- raw shell command
- broad all-fleet action
- backend/auth/payment/deploy/migration/package/secrets scope
- implicit approval such as `yes`, `sounds good`, or `go`

## Local Revalidation

After the captain taps approve, the local PC must revalidate:

```text
plan id
idempotency key
ship scope
current ship state
budget/rate state
rollback path
plan expiry
evidence freshness
safety policy
```

If anything changed since the plan was generated, approval becomes stale and the
fleet must generate a new plan or ask for desktop review.

## Positive Example

```json
{
  "schemaVersion": 1,
  "requestId": "mobile-20260528-001",
  "approval": {
    "decision": "approve",
    "approvedPlanId": "plan-bottlelight-audit-001",
    "idempotencyKey": "idem-bottlelight-audit-001",
    "approvedAt": "2026-05-28T15:00:00Z",
    "approvedBy": "captain"
  },
  "generatedPlan": {
    "planId": "plan-bottlelight-audit-001",
    "ship": "Bottlelight",
    "action": "PACKAGE_AUDIT",
    "riskLevel": "safe",
    "scope": ["Bottlelight"],
    "diffSummary": "No product file changes; package current evidence only.",
    "evidenceSummary": "RUN_RESULT.json and EVIDENCE_INDEX.md exist.",
    "budgetImpact": "No model implementation calls.",
    "rollbackPath": "Delete generated audit package only.",
    "expiresAt": "2026-05-28T15:10:00Z",
    "idempotencyKey": "idem-bottlelight-audit-001",
    "createdAt": "2026-05-28T14:55:00Z",
    "status": "PENDING_APPROVAL"
  }
}
```

## Negative Examples

Raw instruction:

```json
{ "approval": { "decision": "approve" }, "rawCommand": "powershell Remove-Item .codex-local -Recurse" }
```

Expired plan:

```json
{ "approval": { "decision": "approve", "approvedPlanId": "plan-old" }, "generatedPlan": { "planId": "plan-old", "expiresAt": "2020-01-01T00:00:00Z" } }
```

Missing rollback:

```json
{ "approval": { "decision": "approve", "approvedPlanId": "plan-risky" }, "generatedPlan": { "planId": "plan-risky", "rollbackPath": "" } }
```
