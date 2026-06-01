# Stage 12 Phase 8 Prompt: Stage 12 Integration Check

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 12 Phase 8 only: Stage 12 Integration Check.

Goal:
Verify the dashboard/control-room docs are complete and coherent.

Check that:
- information architecture exists
- fleet overview spec exists
- ship detail spec exists
- blocker/repair/taste board specs exist
- budget/overnight view spec exists
- audit/task packet view spec exists
- safe command suggestion spec exists
- audit prompt exists
- checkpoint exists

Fixture scenarios:
- running ship
- blocked ship
- taste-gated ship
- audit-ready ship
- packet-ready ship
- rate-paused ship
- overnight safe landing
- analytical formula blocker
- backend-sensitive approval block

Guardrails:
- Do not implement dashboard UI.
- Do not launch ships.
- Do not edit downstream repos.
- Do not implement Stage 13 mobile console.

Acceptance:
- Stage 12 docs check passes.
- Every fixture scenario has a clear dashboard representation.
- First-screen summary remains concise.
- Readiness notes identify what Stage 13 needs.

Proof:
Show file list, fixture mapping, and readiness notes.
```

## Notes

This is the final design check before adding mobile captain control.

## Implemented Integration Check

Stage 12 is represented by:

- `tools/codex-fleet-control-room.ps1`
- `invoke-control-room.ps1`
- this Stage 12 doc folder
- focused tests in `tests/run-fleet-tests.ps1`

Fixture scenario mapping:

| Scenario | Dashboard Representation |
| --- | --- |
| running ship | Running card plus `Leave running` suggestion. |
| blocked ship | Blocker / Repair board plus repair or approval suggestion. |
| repairing ship | Blocker / Repair board with attempt-limit warning. |
| taste-gated ship | Taste Gate board plus captain question. |
| parked ship | Safe To Inspect card, not finished by default. |
| audit-ready ship | Needs Captain and Audit Packages board. |
| packet-ready ship | Needs Captain and Task Packet board. |
| rate-paused ship | Budget card and wait/resume guidance. |
| overnight safe landing | Budget / Overnight view with Stage 10 decision. |
| backend-sensitive approval block | Approval-required safe command. |
| analytical formula blocker | Blocker board requiring deterministic formula evidence. |
| safe next command suggestion | Suggestion object with `executes = false`. |

Stage 13 readiness:

The captain can understand the fleet quickly from the first-screen cards and
phone-readable captain summary. Stage 13 should turn summaries and suggestions
into mobile requests, but those requests must still pass local scope, state,
budget, and safety validation before any action.
