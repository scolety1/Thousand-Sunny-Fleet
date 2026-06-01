# Stage 12 Phase 7 Prompt: Safe Command Suggestions

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 12 Phase 7 only: Safe Command Suggestions.

Goal:
Define how the dashboard suggests next safe commands without executing them recklessly.

Command suggestions should include:
- command label
- ship scope
- reason
- risk level
- required approvals
- expected effect
- dry-run equivalent
- forbidden if conditions

Examples:
- Dry-run selected ships
- Package audit for selected ship
- Import approved packet
- Run one bounded batch
- Park ship
- Request taste review
- Start overnight with selected preset

Guardrails:
- No merge/push/deploy suggestions by default.
- No implicit all-fleet command.
- High-risk commands require explicit approval.
- Suggestions are not execution.

Acceptance:
- Safe command suggestion spec exists.
- Examples distinguish safe, approval-required, and forbidden commands.
- The view explains why a command is suggested.

Proof:
Show spec path and sample command suggestions.
```

## Notes

This gives the captain power without handing the dashboard a loaded cannon.

## Implemented Safe Command Suggestion Contract

Each suggestion includes:

```text
label
ship
risk
reason
requiredApprovals
expectedEffect
dryRunEquivalent
forbiddenIf
executes = false
```

Examples:

| State | Suggestion | Risk | Why |
| --- | --- | --- | --- |
| `RUNNING` | Leave running | safe | Active work owns the ship. |
| `READY` | Dry-run selected ship | safe | Scope must be explicit before any run. |
| `BLOCKED` | Write repair task | moderate | Failed evidence should produce bounded repair. |
| `BLOCKED` + backend-sensitive | Request approval / write blocker note | approval-required | Sensitive work cannot be automatic. |
| `TASTE_GATE` | Request taste review | safe | Subjective decision belongs to the captain. |
| `AUDIT_READY` | Package or send audit package | safe | Review evidence before more tasks. |
| `PACKET_READY` + validated | Import approved packet | approval-required | Queue mutation requires validation proof. |
| `RATE_LIMIT_PAUSED` | Wait for budget recovery | safe | No new work while budget is unsafe. |

Forbidden by default:

- implicit all-fleet launch
- merge
- push
- deploy
- manual lock deletion
- unvalidated packet import
