# Audit Loop One-Task Runner

`invoke-audit-loop-task.ps1` is the optional Audit Loop Mode dispatcher. It is intentionally narrow: it selects exactly one unchecked task from a generated audit-loop queue, validates that it is safe to attempt, writes evidence, and stops.

## What It Does

- Selects the earliest unchecked task in `## Temporary Audit Loop Mode Queue`.
- Rejects skip-ahead requests when `-TaskId` is not the first unchecked task.
- Requires declared `requiredChecks`.
- Refuses broad scope such as `*`, parent traversal, real product repos, secrets, auth, payments, deploy, migrations, package files, `.git`, `.env`, `node_modules`, build output, and lock files.
- Blocks high-risk tasks unless `-CaptainApproved` is present.
- Records `audit-loop-task-result.json` in the requested evidence directory.
- In default dry-run mode, records which checks would run.
- In fixture test mode with `-RunChecks`, runs only a tiny safe PowerShell check shape and blocks mutating commands.

## What It Does Not Do

- Does not launch ships.
- Does not edit product repositories.
- Does not run arbitrary shell commands.
- Does not skip ahead to a later task.
- Does not auto-delete locks or recover ambiguous state.
- Does not continue into Post-Golden Gameplan Hardening tasks.

## Accepted-Limitation Stop

If the queue has no unchecked tasks and only skipped accepted limitations remain, the runner writes `STOP_ACCEPTED_LIMITATION`. That is a normal stop, not a failure. The captain can decide whether the limitation is still acceptable before asking for another audit loop.

## Safe Use

```powershell
.\invoke-audit-loop-task.ps1 `
  -QueuePath .\docs\codex\TASK_QUEUE.md `
  -OutDir .\out\audit-loop-task
```

For disposable fixture tests only:

```powershell
.\invoke-audit-loop-task.ps1 `
  -QueuePath .\.codex-local\fixtures\audit-loop-queue.md `
  -OutDir .\.codex-local\fixtures\audit-loop-out `
  -RunChecks
```

The runner is a guardrail around one-task execution. It is not a general automation engine.
