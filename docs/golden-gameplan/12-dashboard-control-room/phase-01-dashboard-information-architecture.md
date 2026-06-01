# Stage 12 Phase 1 Prompt: Dashboard Information Architecture

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 12 Phase 1 only: Dashboard Information Architecture.

Goal:
Define the information architecture for the Codex Fleet dashboard/control room.

Required views:
- Fleet Overview
- Ship Detail
- Run Evidence
- Audit Packages
- Task Packets
- Blockers and Repairs
- Taste Gates
- Budget / Overnight
- Lane Health
- Next Safe Commands

For each view define:
- purpose
- primary user question
- required data sources
- displayed fields
- actions shown
- actions forbidden
- empty state
- mobile summary version

Guardrails:
- Do not implement a UI.
- Do not launch ships.
- Do not edit downstream repos.
- Do not add dangerous command buttons.

Acceptance:
- Information architecture doc exists.
- Each view maps to Stage 2-11 artifacts.
- First screen can answer what is running, blocked, needs user input, and safe to run next.

Proof:
Show IA doc path and view summary table.
```

## Notes

This phase prevents the control room from becoming another overwhelming dashboard.

## Implemented Information Architecture

| View | Purpose | Primary Question | Data Sources | Actions Shown | Actions Forbidden | Mobile Summary |
| --- | --- | --- | --- | --- | --- | --- |
| Fleet Overview | Show fleet health at a glance. | What is running, blocked, needs me, or safe to inspect? | Stage 5 state, Stage 6 decision, Stage 10 budget, Stage 11 lane. | Read-only safe suggestions. | Launch all, merge, push, deploy, delete locks. | Five-card summary. |
| Ship Detail | Explain one ship. | Why is this ship in this state? | `RUN_RESULT.json`, state, decision, lane, latest evidence. | Dry-run/status suggestions. | Raw secret/env/log dumping. | One card with next action. |
| Run Evidence | Point to proof. | What proves the last result? | Stage 2 evidence and Stage 3 package refs. | Open/read evidence paths. | Treat missing evidence as success. | Evidence path and status. |
| Audit Packages | Track external review readiness. | What package should be reviewed? | Stage 3/9 packages and prompts. | Package/send review suggestion. | Call external agents automatically. | Latest package path. |
| Task Packets | Track external work packets. | Is this packet validated? | Stage 4 packet validation artifacts. | Validate/import suggestion. | Trust stale or malformed packets. | Packet status and required approval. |
| Blockers and Repairs | Separate deterministic failures from taste. | What is stopping work? | Stage 6 decisions, failed gates, repair metadata. | Write bounded repair task. | Run blocked ships as ready. | Blocker reason and next safe repair. |
| Taste Gates | Preserve final captain taste review. | What subjective call is needed? | Stage 7 product-quality evidence. | Request taste review. | Treat taste as build failure. | One question plus evidence. |
| Budget / Overnight | Show rate and safe landing state. | Is it safe to keep running? | Stage 10 governor/resume metadata. | Wait/resume eligibility suggestion. | Fabricate budget percentages. | Budget level -> decision. |
| Lane Health | Show lane routing and gates. | Is this ship in the right lane? | Stage 11 lane resolver. | Approval/taste/check suggestions. | Hide backend-sensitive escalation. | Lane and approval flag. |
| Next Safe Commands | Suggest, do not execute. | What command can I approve next? | State, decision, budget, packet validation. | Dry-run equivalents. | Implicit all-fleet commands. | Label, risk, dry-run. |

First screen:

```text
Running | Needs Captain | Blocked / Repair | Safe To Inspect | Budget
```
