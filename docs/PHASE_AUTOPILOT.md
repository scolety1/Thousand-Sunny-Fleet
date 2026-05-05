# Generic Phase Autopilot

`phase-autopilot.ps1` is a reusable phase runner for larger fleet projects.

It watches one configured project, keeps its current phase moving, and advances to the next phase when the current phase reaches:

- unchecked tasks: `0`
- run lock: none
- working tree: clean
- configured build command passes

On transition it:

- writes `docs/codex/PHASE_N_REVIEW.md`
- updates `docs/codex/PHASE_STATE.md`
- writes `docs/codex/NEXT_5_TASKS.md`
- appends next phase tasks to `docs/codex/TASK_QUEUE.md`
- commits docs/codex changes
- launches the next phase

## Usage

```powershell
.\phase-autopilot.ps1 -Project RestaurantDemo -PhasePlanPath C:\Dev\restaurant-automation-demo\docs\codex\PHASE_AUTOPILOT_PLAN.json
```

Useful knobs:

```powershell
.\phase-autopilot.ps1 `
  -Project RestaurantDemo `
  -PhasePlanPath C:\Dev\restaurant-automation-demo\docs\codex\PHASE_AUTOPILOT_PLAN.json `
  -IntervalSeconds 600 `
  -MaxIterations 288 `
  -BatchSize 1 `
  -MaxBatches 5 `
  -QuarantineFailedTasks
```

## Project Requirements

The target project should have:

- `docs/codex/PHASE_STATE.md`
- `docs/codex/TASK_QUEUE.md`
- `docs/codex/NEXT_5_TASKS.md`
- a phase plan JSON based on `templates/phase-autopilot-plan.example.json`
- a valid `buildDirectory` and `buildCommand` in `projects.json`

## Customization

Each project customizes behavior by editing its phase plan JSON:

- `number`
- `key`
- `name`
- `showable`
- `doneSignal`
- `nextCriteria`
- `reviewOutcome`
- `tasks`

Tasks should include their own guardrails, safe scopes, and acceptance checks. The generic autopilot does not invent tasks; it only writes the next predefined packet.

## Safety

The autopilot intentionally does not repair dirty states by itself. If the working tree is dirty, it logs the dirty state and waits for Codex/user repair. This avoids overwriting valid in-progress work.

Keep forbidden scope in each project's roadmap and task text. For production-adjacent projects, explicitly forbid auth, backend, deployment, dependency, generated-output, secrets, and data-migration changes unless approved.
