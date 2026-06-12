# Model Routing Policy

Prepared: 2026-06-12

Evidence only; not executable authority or approval.

This policy helps future Fleet packets recommend a cost-quality lane without
wiring model selection into live execution. It uses aliases only. It does not
name current vendor models, claim current pricing, call model APIs, modify
runtime behavior, or approve any Codex run.

## Quality Modes

- `best_value`: choose the lowest adequate alias that can complete the bounded
  task with the available validation.
- `perfection`: allow escalation to a stronger review or reasoning alias when
  Tim explicitly asks for best possible quality, high confidence, or a
  polished final artifact.

## Model Aliases

- `fast_readonly`: read-only inspection, status checks, simple summaries,
  queue triage, and low-risk validation reporting.
- `standard_patch`: narrow docs/tests/scripts edits with strong validation and
  low ambiguity.
- `deep_reasoning`: cross-file planning, tricky failure diagnosis, security
  boundary review, or tasks with meaningful ambiguity.
- `premium_audit`: final audits, high-stakes safety reviews, external-facing
  package review, or perfection-mode review where failure cost is high.

Aliases are recommendations. They are not executable commands, model IDs,
pricing claims, or authority to bypass task contracts.

## Task Classifier Dimensions

Every request packet should classify:

- `scope`: read-only, docs-only, narrow patch, multi-file patch, architecture,
  or audit.
- `risk`: low, medium, high, or blocked.
- `ambiguity`: clear, moderate, high, or unresolved.
- `validation strength`: strong automated checks, partial checks, manual-only,
  or missing.
- `token pressure`: low, medium, high, or unknown.
- `failure cost`: low, moderate, high, or unacceptable.

## Escalation Triggers

Escalate the recommendation, or stop for HQ repacketization, when any of these
appear:

- repeated uncertainty
- validation failed twice
- security boundary unclear
- high token pressure
- product/deploy/secrets boundary
- explicit Tim "perfect" request

Escalation never grants broader file access, product-repo access, deploy rights,
phone approval authority, runtime command binding, all-fleet execution, or
overnight runner authority.

## Blocked Regardless Of Alias

No alias may proceed when the task requires:

- secrets
- unauthorized product repo access
- deploy/merge/push
- all-fleet
- overnight runner
- broad authority

Blocked conditions must be reported as blocked or RED, not solved by choosing a
stronger model alias.

## Request Packet Output

A future packet may include:

```text
qualityMode: best_value
recommendedModelAlias: standard_patch
modelRoutingReason: narrow docs/tests patch with strong validation
escalationTriggers: none
blockedRegardlessOfAlias: none
```

This output remains advisory until a separate runner-side policy gate is
implemented and validated.
