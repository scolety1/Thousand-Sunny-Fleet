# Fleet Run Heartbeat

Active checkpoint loops write a fleet-local heartbeat file at:

`.codex-local/runs/<Project>/heartbeat.json`

This file is intentionally outside product repos. It is runtime state only and is not a product artifact.

## Schema

Required fields:

- `project`: fleet project name.
- `pid`: PowerShell runner process id that owns the loop.
- `startedAt`: ISO timestamp for the run start.
- `lastHeartbeatAt`: ISO timestamp for the most recent heartbeat write.
- `lastProgressAt`: ISO timestamp for the most recent material progress point.
- `runShape`: bounded run controls such as batch size, batch cap, runtime cap, task cap, phase, quarantine, and push settings.
- `currentTaskSummary`: short status for the current loop step.
- `lastCommit`: current repo HEAD short SHA when the heartbeat was written.
- `status`: one of `starting`, `active`, `quarantined`, `completed`, `parked`, or `stopped`.

## Update Points

`run-checkpoint-loop.ps1` writes the heartbeat at loop preflight, lock acquisition, batch start, task selection, implementation start/return, review start/return, quarantine, checkpoint review, debug checkpoint, push checkpoint, budget parking, and clean completion.

## Watchdog Semantics

`fleet-runner-watchdog.ps1` reads heartbeat state before launching repair/proof work.

- `active`: heartbeat is current and the owning PID is alive.
- `idle`: the owning PID is alive, heartbeat is current, but progress is old.
- `stalled`: the owning PID is alive, but the heartbeat is stale.
- `completed`: the run marked clean completion.
- `parked`: the run intentionally stopped at a cooperative boundary.
- `stale`: heartbeat exists, but the owning PID is gone or unreadable.

Dead-PID heartbeats must never count as active work. The watchdog may skip live `active`, `idle`, or `stalled` runs to avoid duplicate loops, but stale/completed/parked files are observational state only.

## Status Publishing

`fleet-remote-control.ps1` includes the runner heartbeat summary in GitHub status output. Status publishing remains read-only by default and does not launch product work.
