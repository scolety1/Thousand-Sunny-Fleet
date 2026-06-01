# Stage 12 Phase 6 Prompt: Audit And Task Packet View

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 12 Phase 6 only: Audit and Task Packet View.

Goal:
Define views for audit packages and external task packets.

Audit Package view should show:
- ship
- audit package ID
- generated time
- included evidence
- role prompts available
- sent/not sent status
- external reports received

Task Packet view should show:
- packet ID
- source role
- ship
- base commit
- validation status
- accepted tasks
- rejected tasks
- deferred tasks
- captain approvals required

Guardrails:
- External packets are not trusted until validated.
- Rejected packets should remain traceable.
- Do not call external agents in this stage.
- Do not ingest packets in this docs stage.

Acceptance:
- Audit/Packet view spec exists.
- It maps to Stage 3, Stage 4, and Stage 9 artifacts.
- It includes valid, rejected, stale, and approval-required packet examples.

Proof:
Show spec path and examples.
```

## Notes

This is the control surface for the future audit-agent loop.

## Implemented Audit / Packet View

Audit package fields:

```text
ship, latestAuditPackage, latestEvidence, status, safe suggestion
```

Task packet fields:

```text
ship, latestTaskPacket, packetStatus, safe suggestion, required approvals
```

Packet examples:

| Packet State | Dashboard Action |
| --- | --- |
| `VALIDATED` | `Import approved packet`, approval-required, evidence path expected. |
| `REJECTED_STALE` | Validate/reject packet; do not import. |
| `REJECTED_MALFORMED` | Validate/reject packet; do not import. |
| `APPROVAL_REQUIRED` | Ask captain before queue mutation. |
| missing/unknown | Treat as untrusted and show validation first. |

Audit-ready example:

```text
Ship: UrbanKitchenSite
State: AUDIT_READY
Audit package: out/audit/urban-kitchen.zip
Action: Package or send audit package
```
