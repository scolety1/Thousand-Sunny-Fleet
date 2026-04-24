# Next Improvements

## Must Fix

- [ ] Add retry/backoff handling to `codex-night-loop.ps1` for transient Codex failures such as model capacity, plugin sync, analytics, or reconnect noise. A temporary model/service failure should not kill an overnight run when no repo changes were made.
- [ ] Add optional fallback model/profile support for Codex CLI runs, so the loop can retry with a configured fallback instead of stopping on selected-model capacity.
- [ ] Add a max retry count per task and record retry attempts in `docs/codex/NIGHTLY_REPORT.md`.

## Planner Handoff

- [ ] Add `prepare-next-task-request.ps1` to generate a planner prompt after each project run.
- [ ] Add `import-next-tasks.ps1` to validate planner-proposed tasks before appending them to `docs/codex/TASK_QUEUE.md`.
