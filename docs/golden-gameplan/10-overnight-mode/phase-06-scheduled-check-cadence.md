# Stage 10 Phase 6 Prompt: Scheduled Check Cadence

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 10 Phase 6 only: Scheduled Check Cadence.

Goal:
Define the overnight monitoring cadence.

The schedule should support:
- takeoff watch
- regular checks
- low-budget checks
- reset checks
- morning final report

Recommended defaults:
- first 30 minutes: check every 5 minutes
- stable run: check every 20 minutes
- low budget: check every 5 minutes or safe land
- reset pending: check at configured reset window
- morning report: at configured end time

Each check should:
- refresh selected ship status
- refresh budget governor status
- apply decision engine
- take only bounded approved action
- write report
- update heartbeat/monitor record

Guardrails:
- Do not implement app automation unless explicitly available and requested.
- Do not create raw heartbeat directives manually if an automation tool exists in the future.
- Do not relaunch after taste gate/block/explicit stop.
- Do not run forever after end time.

Acceptance:
- Cadence policy exists.
- Check types are documented.
- Schedule examples exist for 2-hour, 6-hour, and overnight runs.

Proof:
Show cadence doc and examples.
```

## Notes

This gives the fleet a rhythm without turning every check into a full implementation run.

## Implementation Status

Status: GREEN

Stage 10 records cadence in the overnight contract and report output. It does
not create a real scheduler during tests. Actual phone/mobile notification and
remote command surfaces remain Stage 13.
