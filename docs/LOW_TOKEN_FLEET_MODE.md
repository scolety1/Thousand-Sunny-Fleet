# Low-Token Fleet Mode

Use this mode when the user is near rate limits but still wants high-quality fleet progress.

## Core Rules

- Check status once, summarize once.
- Work from existing repo docs and task queues instead of asking the user to restate goals.
- Prefer one focused ship or one focused group per run.
- Do not narrate routine tool output.
- Do not inspect clean ships unless they are the selected target.
- Do not launch heartbeats while limits are low.

## High-Quality, Low-Token Workflow

1. Run `.\fleet-status.ps1`.
2. Pick the highest-value target from current priorities.
3. Inspect only that target's task queue, latest report, and changed files.
4. Make one bounded pass.
5. Run only that target's configured build/static check.
6. Commit the target if clean and useful.
7. Report: target, change, verification, commit.

## Better Task Shape

Use compact tasks that include:

- Target page or feature.
- Desired user outcome.
- One or two acceptance checks.
- Files or areas to avoid.

Example:

```text
EasyLife command palette: make sample commands parse into useful approval cards.
Acceptance: build passes, mobile command page has no overlap, email/calendar/note examples route correctly.
Avoid: backend, auth, dependencies, deploy config.
```

## Batching Strategy

- Batch 1 is best for production-adjacent apps like EasyLife.
- Batch 2 is acceptable for isolated static demos.
- Batch 3+ only when tasks are fully independent and the user has plenty of rate remaining.

## Verification Strategy

- Build every changed ship.
- Visual-check only changed visual surfaces.
- Avoid full-fleet visual sweeps unless it is a release candidate.
- Use screenshots only for pages changed in the current pass.

## Recommended Next Low-Token Run

When limits recover, start with:

```text
Run a focused EasyLife pass only. Inspect current TASK_QUEUE/NEXT docs, choose the next single highest-value phone-use feature, implement it, build, screenshot the changed route, commit, and stop.
```

