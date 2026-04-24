# How To Add A Project

## 1. Add the project to the fleet

Prefer `add-project.ps1` for new projects. It installs the repo harness files, registers build settings, excludes raw logs locally, and validates the fleet config.

```powershell
cd C:\Dev\codex-fleet
.\add-project.ps1 -Name YourProject -Repo C:\Dev\your-project -Profile frontend-static-demo -BuildDirectory . -BuildCommand "npm.cmd run build"
```

Profiles:

- `real-product`
- `frontend-static-demo`
- `docs-only`
- `experimental-prototype`

For EasyLife-style repos where the app lives in a subfolder:

```powershell
.\add-project.ps1 -Name YourProduct -Repo C:\Dev\your-product -Profile real-product -BuildDirectory app-vNext -BuildCommand "npm.cmd run build"
```

If the repo already has uncommitted changes, commit them first. Use `-Force` only when you intentionally want to install/register despite a dirty tree.

## 2. Edit the task queue

Open:

```text
C:\Dev\your-project\docs\codex\TASK_QUEUE.md
```

Add small unchecked tasks using:

```md
- [ ] Narrow task: describe exactly one safe change. Do not add backend, auth, payment, secrets, deployment, dependencies, or broad rewrites.
```

## 3. Prove the project with one task first

```powershell
cd C:\Dev\codex-fleet
.\run-checkpoint-loop.ps1 -Project YourProject -BatchSize 1 -MaxBatches 1
```

If that passes, scale slowly:

```powershell
.\run-checkpoint-loop.ps1 -Project YourProject -BatchSize 2 -MaxBatches 1
```

Then choose longer settings based on risk:

```powershell
.\run-checkpoint-loop.ps1 -Project YourProject -BatchSize 3 -MaxBatches 4
```

## 4. Validate or review anytime

```powershell
.\run-checkpoint-loop.ps1 -Project YourProject -ValidateOnly
.\debug-checkpoint.ps1 -Repo C:\Dev\your-project
.\fleet-status.ps1
```

## 5. Generate next-task request

```powershell
cd C:\Dev\codex-fleet
.\planner\prepare-next-task-request.ps1 -Repo C:\Dev\your-project
```

Paste `docs/codex/NEXT_TASK_REQUEST.md` into ChatGPT Pro, or run the Codex CLI planner:

```powershell
.\planner\run-planner.ps1 -Repo C:\Dev\your-project
```

## 6. Import proposed tasks

Review:

```text
C:\Dev\your-project\docs\codex\NEXT_TASKS_PROPOSED.md
```

Then import:

```powershell
.\planner\import-next-tasks.ps1 -Repo C:\Dev\your-project -Mode append
```

## Morning merge check

Before merging an unattended branch, run:

```powershell
cd C:\Dev\codex-fleet
.\fleet-morning-review.ps1
```

Only merge after the branch is clean, the build passes, and the report/diff look safe.

## Mission checkpoint loop

For longer autonomous work, create or edit:

```text
C:\Dev\your-project\docs\codex\MISSION.md
```

Then run:

```powershell
cd C:\Dev\codex-fleet
.\run-checkpoint-loop.ps1 -Project YourProjectName -BatchSize 5 -MaxBatches 2 -PushCheckpoint
```

The loop may push the Codex branch if `-PushCheckpoint` is used, but it never merges to `main`.

## What a project needs

Minimum files inside the target repo:

```text
docs/codex/MISSION.md
docs/codex/TASK_QUEUE.md
docs/codex/RUN_POLICY.md
docs/codex/NIGHTLY_REPORT.md
scripts/codex-brief.ps1
scripts/codex-guardrails.ps1
scripts/codex-night-loop.ps1
```

`add-project.ps1` creates these from templates when they are missing.
