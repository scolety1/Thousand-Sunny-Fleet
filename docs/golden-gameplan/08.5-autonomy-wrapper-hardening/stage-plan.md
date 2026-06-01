# Golden Gameplan Stage 8.5: Autonomy Wrapper Hardening

## Purpose

Stage 8.5 is a focused hardening pass between the bounded autonomy wrapper and the external-agent workflow.

Stage 8 proved that the fleet can run one controlled local cycle:

```text
inspect -> decide -> execute approved bounded action -> report -> stop
```

The Stage 8 external audit returned `PASS WITH FIXES`. The fixes are not a new broad feature stage. They tighten the wrapper before Stage 9 starts handing audit packages and task packets to external agents.

## Outcomes

Stage 8.5 is complete when:

- failure containment has tests for the most likely wrapper failures
- packet import requires a real Stage 4 validation artifact
- phone-readable reports have a concise captain summary
- long blocked reasons are shortened for small screens
- `LowTokenMode` is documented as a manual Stage 8 safety override
- default scope is one ship unless the captain explicitly raises `MaxShips`
- Stage 9 has a safer handoff point

## Non-Goals

Do not implement these in Stage 8.5:

- Stage 9 external agent orchestration
- Stage 10 overnight scheduling or automatic rate reset
- Stage 13 mobile captain console
- real product ship launches
- merge, push, deploy, lock deletion, or product repo edits

## Phase List

1. Failure Containment Coverage
2. Approved Packet Evidence Gate
3. Phone Report Hardening
4. Low-Token Documentation
5. One-Ship Default Scope
6. Stage 8.5 Integration Check

## Acceptance

- `.\tests\run-fleet-tests.ps1` passes.
- Missing/corrupt state evidence writes a contained report.
- Audit package creation failure stays contained to the selected ship.
- Packet import blocks without a valid evidence artifact.
- Packet import can proceed only when a JSON validation artifact records a valid packet with accepted tasks.
- Reports include a captain summary and next action.
- Default `MaxShips` is one.
- Stage 8.5 checkpoint is GREEN, or any remaining YELLOW/RED items are explicit.

