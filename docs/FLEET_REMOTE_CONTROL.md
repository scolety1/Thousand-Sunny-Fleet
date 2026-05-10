# Fleet Remote Control

Remote control turns the fleet repo into a small GitHub control plane. The operator edits tracked control files, the harness accepts those edits on a schedule, and the bot writes short status back to tracked status files.

## Files

- `FLEET_REPORTS_README.md`: human guide for where to look on GitHub and how to read the reports.
- `fleet/control/mission.md`: user-owned mission text. Edit this from GitHub when the goal changes.
- `fleet/control/run-mode.json`: user-owned project selection and fleet mode.
- `fleet/control/emergency.md`: user-owned emergency stop. `Emergency: STOP_ALL` requests cooperative safe stops at any hour.
- `fleet/status/current.md`: bot-owned latest report, overwritten each reporting cycle.
- `fleet/status/today.md`: bot-owned rolling same-day log, reset at day rollover.
- `fleet/status/archive/YYYY-MM-DD.md`: bot-owned compact daily summaries, pruned by retention.
- `fleet/state/last-applied-mission.json`: bot-owned acknowledgement of the last accepted mission hash.
- `fleet/state/heartbeat.json`: bot-owned health marker for the most recent remote-control cycle.

Reports are telemetry. Mission and state are authority. The fleet should never depend on old hourly reports to remember what to do.

If you are reading from GitHub, open `fleet/status/current.md` first and read the `Captain Summary`. Use `fleet/status/today.md` only when you want the hourly history for the current day.

## Normal Cycle

```powershell
cd C:\Dev\codex-fleet
.\fleet-remote-control.ps1 -RunSupervisor -Publish
```

The cycle:

1. Pulls latest Git changes unless `-SkipPull` is used.
2. Reads `fleet/control/mission.md`, `run-mode.json`, and `emergency.md`.
3. Defers normal mission changes from 3 AM to 7 AM Pacific.
4. Honors `Emergency: STOP_ALL` even during quiet hours.
5. Optionally runs one supervisor cycle.
6. Writes `fleet/status/current.md` and appends to `fleet/status/today.md`.
7. Rotates yesterday's `today.md` into one daily archive and prunes old archives.
8. Commits and pushes status/state when `-Publish` is used.

## Suggested Schedule

Run hourly during the active reporting window:

```powershell
.\fleet-remote-control.ps1 -RunSupervisor -Publish
```

Run once shortly after midnight for maintenance:

```powershell
.\fleet-remote-control.ps1 -RotateOnly -Publish
```

Mission-policy updates are deferred from 3 AM to 7 AM Pacific by default, but work that is already running can continue. Emergency stop remains live.

## Safety Notes

- The remote-control script does not launch new work by itself.
- `-RunSupervisor` is observational unless the supervisor is separately given auto-repair or auto-stop behavior in the future.
- `-Publish` requires a configured Git remote. Without one, the script writes local files and skips push.
- Keep `mission.md` clear and directive: active project, phase goal, priority, do-not-do list, and next checkpoint.
