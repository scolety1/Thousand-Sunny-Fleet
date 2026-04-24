# How To Add A Project

## 1. Install the harness

```powershell
cd C:\Dev\codex-fleet
.\install-harness.ps1 -Repo C:\Dev\your-project -Profile frontend-static-demo -AddToFleet
```

Profiles:

- `real-product`
- `frontend-static-demo`
- `docs-only`
- `experimental-prototype`

## 2. Edit the task queue

Open:

```text
C:\Dev\your-project\docs\codex\TASK_QUEUE.md
```

Add small unchecked tasks using:

```md
- [ ] Narrow task: describe exactly one safe change. Do not add backend, auth, payment, secrets, deployment, dependencies, or broad rewrites.
```

## 3. Run the project

```powershell
cd C:\Dev\your-project
powershell -ExecutionPolicy Bypass -File .\scripts\codex-night-loop.ps1 -Rounds 3
```

Or run all configured projects:

```powershell
cd C:\Dev\codex-fleet
.\run-fleet.ps1
```

## 4. Generate next-task request

```powershell
cd C:\Dev\codex-fleet
.\planner\prepare-next-task-request.ps1 -Repo C:\Dev\your-project
```

Paste `docs/codex/NEXT_TASK_REQUEST.md` into ChatGPT Pro, or run the Codex CLI planner:

```powershell
.\planner\run-planner.ps1 -Repo C:\Dev\your-project
```

## 5. Import proposed tasks

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
