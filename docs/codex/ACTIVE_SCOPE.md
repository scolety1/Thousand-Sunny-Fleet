# Fleet Active Scope

`fleet/control/run-mode.json` is the default project allowlist for unattended launch-capable paths.

When `activeProjects` is set to `["EasyLife"]`:

- watchdog launch validation and relaunch paths may only produce EasyLife launch commands
- scheduled selected overnight runs filter their requested/default project list to EasyLife
- `launch-overnight-run.ps1` filters ship selection to EasyLife before `ExpectedProject` validation
- supervisor reporting, repair queuing, and repair relaunch default to the active project set
- supervisor repair relaunch passes `-ExpectedProject <ship>` into `run-checkpoint-loop.ps1`

Status publishing uses the active project set by default. Pass `-Project` for an explicit subset, or `-AllProjects` when an all-project inspection report is intentionally needed.

Stale locks for projects outside the active scope must not trigger launch or relaunch.
