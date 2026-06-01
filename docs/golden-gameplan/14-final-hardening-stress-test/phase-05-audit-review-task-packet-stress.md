# Stage 14 Phase 5 Prompt: Audit Review And Task Packet Stress

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 14 Phase 5 only: Audit Review and Task Packet Stress.

Goal:
Define stress tests for external audits and task packet ingestion.

Test cases:
- valid issue-auditor packet
- valid improvement-auditor packet
- product taste packet requiring captain approval
- formula packet requiring Franky/formula audit
- security packet blocking work
- duplicate task IDs
- stale base commit
- unknown ship
- missing task contract fields
- forbidden backend/auth/payment/deploy change
- broad vague redesign
- conflicting multi-agent reports
- tie-breaker report

Expected outputs:
- accepted tasks
- accepted with edits
- rejected tasks
- deferred tasks
- captain questions
- ingest report

Guardrails:
- External packets are never trusted automatically.
- High-risk packets require explicit approval.
- Do not ingest packets into real queues in this docs stage.

Acceptance:
- Audit/task packet stress plan exists.
- It maps to Stage 3, 4, and 9.
- It covers valid, invalid, stale, conflicting, and risky packet cases.

Proof:
Show stress matrix and expected outcomes.
```

## Notes

This keeps the audit-agent loop from becoming a side door around the fleet's safety rules.

## Implemented Audit / Packet Stress Matrix

| Case | Expected Outcome |
| --- | --- |
| valid issue-auditor packet | accepted if schema/base/scope pass |
| valid improvement-auditor packet | accepted or deferred by scope |
| product taste packet | captain question; no deterministic repair claim |
| formula packet | requires formula evidence/Franky review |
| security packet | blocks risky work |
| duplicate task IDs | rejected |
| stale base commit | rejected |
| unknown ship | rejected |
| missing task fields | rejected |
| forbidden backend/auth/payment/deploy | rejected or approval-required, never imported casually |
| broad vague redesign | rejected/deferred for clarification |
| conflicting multi-agent reports | comparison lands in needs-captain/tie-breaker |
| tie-breaker report | accepted only as recommendation; still validates packets |

Stress acceptance:

- accepted tasks have evidence
- rejected tasks remain traceable
- deferred tasks explain missing captain input
- no packet bypasses Stage 4 validation
