# Stage 8.5 Phase 3: Phone Report Hardening

## Goal

Make wrapper reports easier to read from a phone while the fleet still runs on the PC.

## Required Report Shape

- top `Captain Summary`
- status, mode, selected ship count, executed action count
- next captain action
- packet evidence path when relevant
- shortened blocked reasons in tables and lists
- Stage 9 readiness note

## Acceptance

- Long reasons do not dominate the first screen.
- The next action is visible without reading the whole report.

## Implementation Status

Status: GREEN

Implemented in `invoke-autonomy-wrapper.ps1` with `Get-FleetAutonomyShortText`.

