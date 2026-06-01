# Stage 8.5 Phase 5: One-Ship Default Scope

## Goal

Reduce the blast radius of the first autonomy wrapper runs.

## Contract

The wrapper defaults to one selected ship. Multi-ship runs require the captain to explicitly raise `-MaxShips`.

This keeps a misconfigured preset or copied command from accidentally running several ships.

## Acceptance

- Default `MaxShips` is `1`.
- Tests prove selecting two ships without raising `MaxShips` fails fast.
- Selected scope still never defaults to all ships.

## Implementation Status

Status: GREEN

Implemented in `invoke-autonomy-wrapper.ps1` and `tools/codex-fleet-autonomy.ps1`.

