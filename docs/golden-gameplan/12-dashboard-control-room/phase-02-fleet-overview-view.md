# Stage 12 Phase 2 Prompt: Fleet Overview View

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 12 Phase 2 only: Fleet Overview View.

Goal:
Define the main dashboard screen.

The Fleet Overview should show:
- running ships
- blocked ships
- taste-gated ships
- rate-paused ships
- parked ships
- ships safe to inspect
- ships unsafe to touch
- selected lane counts
- current budget/rate status
- latest overnight status
- top next safe commands

Required first-screen cards:
- Running
- Needs Captain
- Blocked / Repair
- Safe To Inspect
- Budget

Guardrails:
- Do not cram every detail into the overview.
- Do not call parked ships finished unless done contract is met.
- Do not hide active dirty ships.
- Do not implement UI code in this docs stage.

Acceptance:
- Fleet Overview spec exists.
- It includes desktop and phone-readable layouts.
- It explains what data powers every card.

Proof:
Show spec path and sample overview content.
```

## Notes

This is the answer to "how is the fleet doing?"

## Implemented Fleet Overview

The Stage 12 control-room report opens with five cards:

| Card | Includes | Excludes |
| --- | --- | --- |
| Running | `RUNNING` ships with active ownership. | Stop/kill buttons. |
| Needs Captain | `AUDIT_READY`, `PACKET_READY`, and `TASTE_GATE` ships. | Broken deterministic builds. |
| Blocked / Repair | `BLOCKED` and `REPAIRING` ships. | Runnable ships. |
| Safe To Inspect | `PARKED` ships with evidence to review. | Claims that parked means finished. |
| Budget | `RATE_LIMIT_PAUSED` ships and Stage 10 governor summary. | Invented percentages or reset times. |

Desktop layout:

```text
Captain Summary
First Screen Cards
Ship Table
Blocker / Repair Board
Taste Gate Board
Budget / Overnight
Audit Packages And Task Packets
Safe Command Suggestions
```

Phone-readable layout:

```text
Running: 1 | Needs captain: 2 | Blocked/repair: 1 | Safe to inspect: 1 | Budget: low -> BLOCK_NEW_WORK
Next: Review blocker/repair board first.
```
