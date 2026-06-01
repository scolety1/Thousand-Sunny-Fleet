# Stage 12 Phase 3 Prompt: Ship Detail View

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 12 Phase 3 only: Ship Detail View.

Goal:
Define the per-ship detail view.

The Ship Detail view should show:
- ship name
- repo path
- branch/head
- lane
- state
- decision
- current tasks
- latest run result
- latest evidence
- latest audit package
- latest task packet
- blockers
- taste notes
- rate/overnight status
- safe next command
- forbidden next command

It should answer:
- What happened last?
- Why is it in this state?
- What evidence proves it?
- What should I do next?

Guardrails:
- Do not expose secret/env contents.
- Do not include raw huge logs on first view.
- Do not implement UI code.
- Do not modify ship repos.

Acceptance:
- Ship Detail spec exists.
- It includes data source mapping.
- It includes examples for running, blocked, taste-gated, and audit-ready ships.

Proof:
Show spec path and example ship detail cards.
```

## Notes

This view replaces terminal detective work.

## Implemented Ship Detail Fields

The read-only snapshot records these per-ship fields:

| Field | Meaning |
| --- | --- |
| `ship` | Stable ship/project name. |
| `repo`, `branch`, `head` | Local code location and git identity, when supplied by sanitized input. |
| `status` | Stage 5 lifecycle state normalized for the dashboard. |
| `decision` | Stage 6 decision or latest action hint. |
| `lane` | Stage 11 specialized lane. |
| `tasksRemaining` | Queue count from evidence input. |
| `dirty`, `active` | Whether inspection/run actions are risky. |
| `latestEvidence` | Best proof path for the current state. |
| `latestAuditPackage`, `latestTaskPacket`, `packetStatus` | Stage 3/4/9 review loop status. |
| `blocker`, `tasteQuestion` | Human-readable issue or subjective question. |
| `overnightStatus`, `rateStatus` | Stage 10 run/budget state. |
| `safeCommand` | Read-only suggestion with risk, approvals, dry-run, and forbidden-if conditions. |

Examples:

- Running: safe command is `Leave running`.
- Blocked backend-sensitive: safe command is `Request approval / write blocker note`.
- Taste-gated: safe command is `Request taste review`.
- Audit-ready: safe command is `Package or send audit package`.
