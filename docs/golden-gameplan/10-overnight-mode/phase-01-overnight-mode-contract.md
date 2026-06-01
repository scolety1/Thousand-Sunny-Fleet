# Stage 10 Phase 1 Prompt: Overnight Mode Contract

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 10 Phase 1 only: Overnight Mode Contract.

Goal:
Define the contract for a safe overnight run mode.

Overnight mode should include:
- selected ships or approved preset
- start time
- end time
- check cadence
- budget mode
- max active ships
- max cycles per ship
- max repair attempts
- max resume attempts
- low-budget threshold
- safe-landing threshold
- reset window configuration
- final report path

Required default posture:
- conservative
- selected scope required
- no implicit all-fleet launch
- no deploy/merge/push
- no sensitive-system changes without approval
- no unbounded loops

Guardrails:
- Do not implement scheduling yet in this phase.
- Do not launch ships.
- Do not modify product repos.
- Do not assume exact rate-limit reset can be detected automatically.

Acceptance:
- Overnight mode contract doc exists.
- Safe defaults are documented.
- Example configurations exist for 3-ship, 5-ship, and status-only overnight runs.

Proof:
Show contract path and example configs.
```

## Notes

This is the promise of overnight mode before any automation touches it.

## Implementation Status

Status: GREEN

Implemented by `New-FleetOvernightContract` in `tools/codex-fleet-overnight.ps1`.
The contract defaults to selected scope, one ship, one cycle per ship,
bounded repair/resume attempts, and explicit forbidden actions.
