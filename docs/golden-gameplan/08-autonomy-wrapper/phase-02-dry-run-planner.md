# Stage 8 Phase 2 Prompt: Dry-Run Planner

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 8 Phase 2 only: Dry-Run Planner.

Goal:
Design and implement dry-run behavior for the autonomy wrapper.

Dry run should:
- load selected ships
- refresh or read state
- compute decisions
- map decisions to intended actions
- print what would happen
- write a dry-run report
- make no product changes
- launch no ships

Required output:
- ship
- state
- decision
- intended action
- reason
- risk
- required approval
- evidence paths

Guardrails:
- Dry run must not mutate task queues.
- Dry run must not import packets.
- Dry run must not write repair tasks.
- Dry run must not launch or stop processes.

Acceptance:
- Dry run works for fixture ships.
- Dry run clearly shows no actions were executed.
- High-risk actions are marked as blocked or approval-required.

Proof:
Show dry-run output and report path.
```

## Notes

Dry run is how the captain learns to trust the wrapper.

## Implementation Status

Status: GREEN

Dry-run is the default mode of `invoke-autonomy-wrapper.ps1`. It loads selected ships, reads state, resolves Stage 6 decisions, maps intended Stage 8 actions, writes JSON/Markdown reports, and executes no actions.
