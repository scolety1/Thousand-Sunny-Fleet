# Next Improvements

## Must Fix

- [x] Add retry/backoff handling to the reusable `templates/scripts/codex-night-loop.ps1` for transient Codex failures such as model capacity, plugin sync, analytics, or reconnect noise. A temporary model/service failure should not kill an overnight run when no repo changes were made.
- [x] Add model/profile config for Codex CLI runs.
- [x] Add fallback model chains for Codex CLI runs, so the loop can retry with a configured fallback instead of stopping on selected-model capacity.
- [x] Add a max retry count per task in the reusable loop template.
- [x] Add hard timeout watchdogs for Codex, build, visual, Simon, Joey, Nami, and checkpoint steps.
- [x] Add rate-limit cooldown handling so Codex usage-limit failures can wait and retry instead of killing long unattended runs.
- [x] Add `fleet-doctor.ps1` as the preflight command before school-day or overnight runs.

## Planner Handoff

- [x] Add `prepare-next-task-request.ps1` to generate a planner prompt after each project run.
- [x] Add `import-next-tasks.ps1` to validate planner-proposed tasks before appending them to `docs/codex/TASK_QUEUE.md`.
- [x] Feed Simon, visual bugs, and Joey into Nami's next-task generation.

## Review And Recovery

- [x] Add `recover-interrupted-task.ps1` for clean interrupted-run recovery.
- [x] Add `merge-readiness.ps1` for a single morning merge/no-merge answer.
- [x] Add a latest screenshot gallery for visual review.
- [x] Improve checkpoint summaries with completed tasks, changed files, visual/Simon/Joey status, and next-batch guidance.
- [x] Add launch presets for proof, school-day, and overnight runs.
- [x] Add lightweight script-level tests for task parsing, staging, model resolution, visual paths, and review finding parsing.

More detail: `docs/FLEET_IMPROVEMENT_GAMEPLAN.md`.
