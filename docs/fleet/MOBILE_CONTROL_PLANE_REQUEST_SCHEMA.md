# Mobile Control Plane Request Schema

Prepared: 2026-06-10

Evidence only; not executable authority or approval.

## Request Object

```json
{
  "requestId": "mcp-20260610-0001",
  "createdAt": "2026-06-10T15:00:00Z",
  "requester": "tim",
  "project": "codex-fleet",
  "taskSummary": "Harden static Phone HQ wording",
  "qualityMode": "best_value",
  "requestedModelTier": "standard",
  "filesRequested": [
    "docs/index.html",
    "docs/fleet/PHONE_HQ_DASHBOARD.md"
  ],
  "forbiddenOperations": [
    "store secrets",
    "direct browser command execution",
    "product repo access",
    "all-fleet",
    "overnight runner",
    "deploy",
    "stage",
    "commit",
    "push"
  ],
  "validationRequested": [
    "powershell -NoProfile -ExecutionPolicy Bypass -File .\\tests\\run-fleet-tests.ps1"
  ],
  "approvalRequired": true,
  "emergencyStop": false,
  "status": "requested",
  "auditNotes": "Phone request only; not execution authority."
}
```

## Field Rules

- `requestId` must be immutable and unique.
- `createdAt` must be an immutable creation timestamp.
- `requester` must identify the authenticated user.
- `project` must not imply product repo access by default.
- `taskSummary` must describe one bounded task.
- `qualityMode` must be `best_value` or `perfection`.
- `requestedModelTier` records preference only; model routing / cost-quality recommendation still applies.
- `filesRequested` must be reviewed into `allowedFiles` before execution.
- `forbiddenOperations` must preserve no secrets, no direct browser command execution, no phone approval authority, no product repo access by default, no all-fleet, no overnight runner, no deploys, no staging, no commits, no pushes, no migrations, no lock deletion, and no permission widening.
- `validationRequested` must be reviewed into `validationCommands` before execution.
- `approvalRequired` must be true for any private, product, deploy, high-risk, or runner-connected work.
- `emergencyStop` can request a stop signal but cannot become arbitrary command execution.
- `status` must use a controlled vocabulary such as `requested`, `triaged`, `blocked`, `approved_for_runner`, `running`, `validation_failed`, or `complete`.
- `auditNotes` must not contain secrets.

## Execution Contract Derivation

Before a request can reach a runner, HQ must derive:

- one-task boundary
- allowedFiles
- validationCommands
- stopIf
- policy classification
- model routing / cost-quality recommendation
- approval requirement
- audit log entry

If any required field or derived contract is missing, the request remains YELLOW or RED and must not execute.
