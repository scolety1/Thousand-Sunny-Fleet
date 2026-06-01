# Golden Gameplan Stage 13: Mobile Captain Console

## Purpose

Stage 13 defines how the user can manage Codex Fleet while away from the main machine.

The user wants to be able to ask from a phone:

```text
How is the fleet doing?
Is anything stuck?
Are limits low?
What needs my taste?
Can I safely assign this idea?
Can I stop or park a ship?
Can I approve the next bounded run?
```

This stage defines and implements a local request-only mobile command layer. It
does not implement the actual remote app, notification transport, or message
delivery.

## Why This Matters

The fleet is meant to work while the user is at school, traveling, selling, sleeping, or doing other work.

Without a mobile captain layer, the user has to return to the desktop to:

- inspect status
- respond to blockers
- approve taste direction
- assign ideas
- stop runaway work
- protect rate limits
- resume after reset

Stage 13 makes those interactions compact, safe, and structured.

## Stage 13 Outcome

At the end of Stage 13, the fleet should have specs for:

- phone-friendly status reports
- command inbox
- safe remote actions
- idea intake
- rate-limit alerts
- mobile digest
- remote approval rules
- unsafe command rejection

## Non-Goals

Do not implement these in Stage 13:

- actual SMS/Gmail/Discord/Slack integration
- a deployed mobile web app
- push notifications
- authentication system
- remote shell execution
- automatic merge/push/deploy
- bypassing existing safe-stop and approval rules

This stage implements the local parser/response harness only:

```text
invoke-mobile-console.ps1 -Message "<phone text>" -InputPath <control-room-input-or-snapshot.json>
```

The command writes a JSON command record and a phone-readable Markdown response.
It never executes fleet actions.

## Mobile First Rule

Every mobile response should answer in a short screen:

```text
State
Problem
Next safe action
What needs the user
```

Long reports should be linked, not pasted.

## Safe Remote Actions

The console may eventually support remote requests for:

```text
STATUS
DIGEST
PARK_SHIP
REQUEST_SAFE_STOP
APPROVE_TASTE_DIRECTION
APPROVE_PACKET_IMPORT
RUN_DRY_CHECK
RUN_ONE_BOUNDED_BATCH
PACKAGE_AUDIT
CAPTURE_IDEA
SET_OVERNIGHT_PRESET
RESUME_AFTER_RESET
```

These are requests. They must still pass local validation before execution.

Mobile commands are never raw shell commands. They become command records that
the local fleet validates against Stage 4 packet rules, Stage 5 state, Stage 6
decisions, Stage 8 action safety, and Stage 10 budget policy before anything
can run.

`RUN_ONE_BOUNDED_BATCH` from a phone requires an explicit ship name, current
state, budget check, clean/owned repo state, and a dry-run summary first.

`RESUME_AFTER_RESET` from a phone requires Stage 10 auto-resume eligibility; it
cannot rely only on "I think the reset happened."

## Phase List

1. Mobile Status Contract
2. Command Inbox Protocol
3. Safe Remote Actions
4. Idea Intake and Task Drafting
5. Rate-Limit Alerts
6. Mobile Digest
7. Approval and Rejection Rules
8. Stage 13 Integration Check

## Acceptance For Stage 13

Stage 13 is complete when:

- mobile status format is defined
- command inbox schema is defined
- safe remote actions are listed and constrained
- idea intake can capture rough thoughts without becoming immediate tasks
- rate-limit alerts are clear and conservative
- daily/mobile digest format exists
- unsafe remote commands are rejected by design
- local request-only harness exists
- no actual remote integration is implemented

## Implemented Surface

Files:

- `tools/codex-fleet-mobile.ps1`
- `invoke-mobile-console.ps1`

Supported request types:

```text
STATUS
DIGEST
PARK_SHIP
REQUEST_SAFE_STOP
APPROVE_TASTE_DIRECTION
APPROVE_PACKET_IMPORT
RUN_DRY_CHECK
RUN_ONE_BOUNDED_BATCH
PACKAGE_AUDIT
CAPTURE_IDEA
SET_OVERNIGHT_PRESET
RESUME_AFTER_RESET
```

Remote commands become records with `executes = false`. Later local validators
must still approve scope, state, budget, packet evidence, dry-run output, and
safety before any real action can happen.

## Hand-Off To Stage 14

Stage 14 will define final hardening and stress tests across all stages before the fleet is considered a stable operating system.
