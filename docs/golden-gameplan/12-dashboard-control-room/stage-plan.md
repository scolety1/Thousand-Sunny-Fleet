# Golden Gameplan Stage 12: Dashboard and Control Room

## Purpose

Stage 12 defines the fleet control room: one place to see what is happening, what needs attention, what can run, and what should not be touched.

The user should not have to inspect ten terminals, scattered reports, dirty repos, and heartbeat messages just to answer:

```text
How is the fleet doing?
What is stuck?
What is safe to inspect?
What should I run next?
What is burning limits?
What needs my taste?
```

Stage 12 turns the prior stages into a readable command surface.

## Why This Matters

The fleet can only become more autonomous if it is also more observable.

The dashboard should make the following visible:

- ship state
- decision
- lane
- current task count
- dirty/running/blocked status
- rate/budget state
- overnight status
- latest audit package
- latest task packet
- product/taste gates
- formula/security blockers
- safe next command

## Stage 12 Outcome

At the end of Stage 12, the fleet should have a control-room design that supports:

- machine-readable status
- human-readable status
- a concise captain summary
- per-ship detail
- lane overview
- budget/rate overview
- blocker board
- taste gate board
- audit package board
- safe command suggestions

## Implemented Surface

Stage 12 adds a read-only control-room generator:

```text
invoke-control-room.ps1 -InputPath <sanitized-status.json>
```

The command writes:

- a machine-readable JSON snapshot
- a human-readable Markdown control-room report
- first-screen fleet cards
- per-ship status rows
- blocker/repair board
- taste-gate board
- budget/overnight summary
- audit package and task-packet board
- safe command suggestions that do not execute

The command intentionally requires an explicit sanitized input file. It does not
discover or launch product ships by default.

## Non-Goals

Do not implement these in Stage 12:

- mobile command interface
- real-time web app unless explicitly chosen later
- ship launching from UI
- merge/push/deploy buttons
- direct external agent calls
- new product work

This stage implements a read-only report surface, not an interactive execution
console.

## Control Room Views

The control room should eventually have these views:

```text
Fleet Overview
Ship Detail
Run Evidence
Audit Packages
Task Packets
Blockers and Repairs
Taste Gates
Budget / Overnight
Lane Health
Next Safe Commands
```

## First-Screen Rule

The first control-room screen should answer in under 10 seconds:

```text
What is running?
What is blocked?
What needs me?
What can safely run next?
```

## Phase List

1. Dashboard Information Architecture
2. Fleet Overview View
3. Ship Detail View
4. Blocker, Repair, and Taste Boards
5. Budget and Overnight View
6. Audit and Task Packet View
7. Safe Command Suggestions
8. Stage 12 Integration Check

## Acceptance For Stage 12

Stage 12 is complete when:

- dashboard/control-room docs exist
- first screen is defined
- every major prior artifact has a place
- the dashboard distinguishes running, blocked, parked, taste-gated, and rate-paused ships
- safe commands are suggestions, not reckless buttons
- phone-readable summary is included
- no fleet code or UI implementation was required for this docs stage

## Hand-Off To Stage 13

Stage 13 will define the mobile captain console: remote status questions, safe commands, idea capture, and on-the-go approval flow.
