# Weekly Reset Preview Pause

When the weekly model/reset budget is near exhaustion, the fleet should not keep trying to squeeze in one more implementation run. At about five percent remaining, unfinished ships should find a stable pause point, keep their current preview/evidence available, and wait for the weekly reset.

## Trigger

- Default threshold: `WeeklyResetPauseThresholdPercent = 5`.
- Input signal: `-WeeklyRatePercent`.
- Decision: `WEEKLY_PREVIEW_PAUSE`.
- Ship action: `PAUSE_FOR_WEEKLY_PREVIEW`.

This is separate from the per-run safe landing threshold. A daily/session budget may still be healthy while the weekly budget is almost gone.

## Required Behavior

- Stop new model-heavy implementation work.
- Preserve or plan to preserve the current preview until reset.
- Write `weekly-preview-plan.json`.
- Record unfinished ships that were `READY`, `RUNNING`, `REVIEWING`, `REPAIRING`, or `QUARANTINED`.
- Point the captain to `docs/codex/WEEKLY_RESET_REVIEW_NOTES.md`.
- Resume only after weekly reset recovery is confirmed and normal resume eligibility stays GREEN.

## Captain Review Window

During the pause, the captain can inspect the preview/site/software manually and write:

- visual bugs
- broken flows
- copy problems
- missing pieces
- confusing layout
- formula or data issues
- mobile issues
- priority for post-reset repair

The bug doc becomes the next human-authored evidence artifact after reset. It should be converted into bounded tasks, not treated as permission for broad rewrites.

## Non-Goals

- No product ship launch.
- No real preview server management in this harness-only task.
- No automatic provider-side weekly reset detection unless a future provider integration proves it.
- No manual lock deletion.
- No broad all-fleet resume after reset.
