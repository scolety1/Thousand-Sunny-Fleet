# Stage 1 Phase 8: Safe-Name Uniqueness

## Goal

Prevent lock, heartbeat, run, and stop-request collisions between similarly named
ships.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 1 Phase 8 only: Safe-name uniqueness.

Do not implement any other Golden Gameplan phase.

Goal:
Make generated filesystem-safe ship names unique enough that ships whose names
differ only by punctuation or spacing cannot share locks, stop requests,
heartbeats, or run directories accidentally.

Before editing:
- Run .\fleet-status.ps1.
- Find ConvertTo-FleetLaunchSafeName or equivalent safe-name helpers.
- Identify all places safe names are used for locks, heartbeats, stop requests,
  run directories, and reports.

Scope:
- Likely files: codex-fleet-launcher.ps1, fleet-status.ps1,
  request-safe-stop.ps1, run-checkpoint-loop.ps1, tests/run-fleet-tests.ps1.
- Prefer a deterministic suffix or mapping that remains stable across runs.
- Preserve backwards compatibility for existing safe names where possible.
- Do not delete or migrate existing real lock/stop files automatically.

Required behavior:
- Two project names that normalize to the same slug receive distinct safe names.
- Stop requests for one do not affect the other.
- Heartbeat and lock paths are distinct.
- Existing ships remain readable in status output.

Acceptance:
- Add tests with two projects like Urban_Kitchen and Urban-Kitchen.
- Add tests that their stop requests, locks, and heartbeat paths do not collide.
- Add a compatibility note for existing safe-name artifacts.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/01-stability-first/checkpoint.md.

Stop if:
- Changing safe names would strand existing active locks. In that case, add
  collision detection first and defer migration.
```

## Why It Matters

Safe names are invisible until they collide. A collision can make one ship stop,
unlock, or overwrite another.

## Tests To Add

- punctuation collision produces distinct identifiers
- stop request targets only intended ship
- lock and heartbeat paths are distinct
- old safe names are still discoverable or reported

## Done When

Ship identity is stable and unique at the filesystem layer.

