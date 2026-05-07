# Fleet Night Report

`fleet-night-report.ps1` summarizes scheduled run logs and ship outcomes for real fleet windows.

Default behavior remains product-aware: failed scheduled attempts, dirty ships, missing repos, or latest failed/quarantined/blocked product reports exit with attention needed.

Use `-IgnoreDryRuns` when proof, preflight, harness, or dry-run scheduled logs should be excluded from the scheduled-attempt table.

Use `-ScheduleOnly` for isolated scheduler proof checks that should validate scheduled logs without reading product repo state. This mode is intended for harness validation and dry-run fixtures; real night reports should omit it so product issues remain visible.
