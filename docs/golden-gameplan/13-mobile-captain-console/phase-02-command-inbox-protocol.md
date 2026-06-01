# Stage 13 Phase 2 Prompt: Command Inbox Protocol

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 13 Phase 2 only: Command Inbox Protocol.

Goal:
Define a safe inbox format for remote captain commands.

The command inbox should represent incoming requests as structured records.

Required fields:
- commandId
- receivedAt
- source
- requestedBy
- commandType
- shipScope
- message
- parsedIntent
- riskLevel
- requiresApproval
- validationStatus
- status
- responsePath

Supported statuses:
- RECEIVED
- PARSED
- NEEDS_CLARIFICATION
- REJECTED
- APPROVAL_REQUIRED
- ACCEPTED
- EXECUTED
- PARKED

Guardrails:
- Remote text is not trusted by default.
- No command executes until parsed and validated locally.
- Missing scope must not default to all ships.
- Dangerous commands must become approval-required or rejected.

Acceptance:
- Command inbox schema/spec exists.
- Examples include status request, safe stop request, idea capture, run request, and rejected dangerous request.

Proof:
Show schema/spec path and examples.
```

## Notes

The inbox is the firewall between casual phone messages and actual fleet action.

## Implemented Command Record

The local mobile harness writes command records with:

```text
schemaVersion
commandId
receivedAt
source
requestedBy
commandType
shipScope
implicitAllRequested
message
parsedIntent
riskLevel
requiresApproval
requiresDryRun
validationStatus
status
responsePath
reasons
executes = false
```

Status meanings:

| Status | Meaning |
| --- | --- |
| `ACCEPTED` | Request was recorded and is safe as a request. |
| `NEEDS_CLARIFICATION` | Scope or wording is missing. |
| `REJECTED` | Forbidden, high-risk, or implicit all-fleet action. |
| `APPROVAL_REQUIRED` | Needs local approval/dry-run/evidence before action. |

Examples:

- `How is the fleet?` -> `STATUS`, `ACCEPTED`.
- `Stop Bottlelight safely` -> `REQUEST_SAFE_STOP`, scoped, approval-required.
- `Idea: add private dining flow to Bottlelight` -> `CAPTURE_IDEA`, accepted as idea only.
- `Run the cellar fleet tonight` -> rejected if it implies all ships.
- `Deploy and push everything` -> rejected forbidden remote action.
