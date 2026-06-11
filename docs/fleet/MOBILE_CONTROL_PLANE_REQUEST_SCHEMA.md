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

## Quick Mission Request Mapping

The public phone quick mission file is a request template only. It is not the authenticated control plane and does not execute anything.

Map `fleet/control/quick-mission.md` into a future request object as follows:

- `Status` maps to request intake state and may use `draft`, `requested`, `blocked`, or `completed`.
- `One Task` maps to `taskSummary` and must stay singular.
- `Desired Project` maps to `project`, but product repo access remains denied by default.
- `Quality Mode` maps to `qualityMode` and must be `best_value` or `perfection`.
- `Requested Model Tier` maps to `requestedModelTier` as a preference only.
- `Requested Files` maps to `filesRequested`; it is not `allowedFiles` until HQ/Codex review.
- `Validation Requested` maps to `validationRequested`; it is not `validationCommands` until HQ/Codex review.
- `Forbidden Operations` maps to `forbiddenOperations` and must preserve no product-repo mutation, no all-fleet, no overnight, no deploy, no stage, no commit, no push, no installs, no migrations, no secrets, no lock deletion, no permission widening, no runtime command binding, no phone approval, and no remote access configuration.
- `Stop If` maps to later `stopIf` conditions.
- `Next Checkpoint` maps to `auditNotes` or triage notes and must not include secrets.

Quick mission requests require later HQ/Codex review before work. Phone requests cannot approve work, execute Codex, trigger GitHub Actions, bind runtime commands, touch product repos, or grant future authority.

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

## Authenticated Intake Cutline

This request schema is not implementation approval. It does not approve authentication code, backend services, GitHub Actions triggers, command execution, runner integration, product-repo access, staging, commit, push, deploy, installs, migrations, lock deletion, permission widening, or secret handling.

Before any authenticated request intake implementation starts, a separate one-task packet must define:

- authentication design
- secret storage boundary
- request integrity and replay resistance
- policy gate
- allowedFiles
- validationCommands
- stopIf
- model routing / cost-quality recommendation
- runner refusal behavior
- audit logs
- human approval rules

If those preconditions are absent, a request object remains planning evidence only and cannot become execution authority.
