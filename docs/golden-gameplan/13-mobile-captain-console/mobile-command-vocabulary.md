# Mobile Command Vocabulary

Stage 15 hardening keeps the phone surface powerful but request-shaped. A phone
message is never a shell, never a direct fleet launcher, and never enough by
itself to approve risky work. It becomes a local command record with
`executes = false`.

## First Screen Cards

Every phone status response should make these cards visible before details:

```text
Running
Blocked
Needs Approval
Budget
Incidents
```

The first screen should answer:

- what is active
- what is stuck or risky
- what needs the captain
- whether budget/rate state is safe
- what local artifact or report to open next

## Allowed Phone Phrases

| User phrase | Internal request | Result |
| --- | --- | --- |
| `status`, `how is the fleet`, `what is stuck` | `STATUS` | read-only phone summary |
| `why`, `what happened`, `why is it blocked` | `WHY` | read-only explanation/status view |
| `digest`, `summary`, `overnight report` | `DIGEST` | read-only compact digest |
| `submit idea`, `new idea`, `what if...` | `CAPTURE_IDEA` | idea record only; no queue mutation |
| `approve plan` | `APPROVE_PLAN` | approval request only; local PC must revalidate |
| `reject plan` | `REJECT_PLAN` | rejection record only |
| `resume safe`, `resume after reset` | `RESUME_AFTER_RESET` | resume request only; Stage 10 eligibility required |
| `audit package`, `package audit` | `PACKAGE_AUDIT` | request to create/review evidence for an explicit ship |
| `mute`, `snooze` | `MUTE_NOTIFICATIONS` | notification preference request only |
| `safe stop`, `park`, `dry check`, `run one bounded batch` | existing Stage 13 requests | still require explicit scope and local validation |

## Always Rejected From Phone

- arbitrary shell or command strings
- PowerShell, CMD, Bash, Git cleanup/reset, package install/update commands
- destructive gestures such as `Remove-Item`, `rm -`, `taskkill`, or lock deletion
- implicit all-fleet work such as `run the whole fleet`
- merge, push, deploy, auth, payments, secrets, migrations, production data, package/dependency edits
- self-approval of high-risk work
- replaying a stale approval after reset without validation

## Approval Rule

Phone approval means:

```text
The captain approved the generated plan record for local revalidation.
```

It does not mean:

```text
Run this raw instruction now.
```

Before execution, the local PC must re-check ship scope, state, budget, packet
evidence, plan expiry, rollback path, and idempotency.

## Evidence Required

Any future mobile integration must preserve:

- command record JSON
- phone-readable Markdown response
- validation status
- next captain action
- link/path to the control-room, audit package, packet, or plan evidence
