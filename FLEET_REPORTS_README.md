# Fleet Reports README

Open this first when you are checking the fleet from GitHub.

## The Three Files That Matter

1. `fleet/status/current.md`
   - The latest captain status.
   - Overwritten each reporting cycle.
   - Best file for: "What is happening right now?"

2. `fleet/status/today.md`
   - The hourly running log for the current day.
   - Reset at day rollover after the old day is archived.
   - Best file for: "What changed today?"

3. `fleet/status/archive/YYYY-MM-DD.md`
   - Compact older daily logs.
   - Best file for: "What happened yesterday or last run?"

GitHub links:

- Latest status: https://github.com/scolety1/codex-fleet/blob/main/fleet/status/current.md
- Today's log: https://github.com/scolety1/codex-fleet/blob/main/fleet/status/today.md
- Archives: https://github.com/scolety1/codex-fleet/tree/main/fleet/status/archive

## How To Read `current.md`

Start at `Captain Summary`.

- `RUNNING`: a runner or live heartbeat is active.
- `READY`: clean, unlocked, and has tasks.
- `PARKED`: clean and stopped, or no launchable work is active.
- `BLOCKED`: dirty work, stop request, or another condition needs attention.
- `STALLED`: heartbeat exists, but progress is too old for comfort.

Useful fields:

- `phase`: where the product is in the loop.
- `unchecked`: how many task-queue items remain.
- `Next`: first unchecked task.
- `Progress`: latest `NIGHTLY_REPORT.md` entry from the product repo.
- `Branch sync`: whether local work is ahead/behind GitHub.

## How To Change The Fleet From GitHub

Edit these files in the GitHub repo:

- Change course: `fleet/control/mission.md`
- Pause/resume/select projects: `fleet/control/run-mode.json`
- Emergency stop: `fleet/control/emergency.md`

For an emergency stop, set:

```md
Emergency: STOP_ALL
```

The fleet treats reports as telemetry only. The mission and run-mode files are the source of truth.

## What The Hourly Report Does Not Mean

- A quiet hour does not always mean no work happened; it may mean status was unchanged or the reporting window skipped duplicate commits.
- Reports do not launch work by themselves.
- Old reports are not instructions. They are archived so the fleet does not lose track by reading stale status as the mission.

## Current Recommended Habit

1. Open `fleet/status/current.md`.
2. Read `Captain Summary`.
3. If something looks blocked, open the matching product repo's `docs/codex/CHECKPOINT_REVIEW.md` or `docs/codex/NIGHTLY_REPORT.md`.
4. If you want to redirect work, edit `fleet/control/mission.md`.
