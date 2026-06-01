# Stage 8.5 Phase 2: Approved Packet Evidence Gate

## Goal

Make `ApprovedPacketEvidence` a real validation artifact instead of a boolean trust flag.

## Rules

- Packet import requires `-AllowTaskPacketImport`.
- Packet import also requires `-ApprovedPacketEvidence <path>`.
- The evidence path must stay inside the fleet root.
- The evidence file must be JSON.
- The JSON must record a valid Stage 4 packet.
- The JSON must include at least one accepted task record.

## Acceptance

- Missing, malformed, invalid, forbidden, or outside-scope evidence blocks import.
- Valid evidence maps `WAIT_FOR_TASK_PACKET` to `IMPORT_APPROVED_PACKET`.

## Implementation Status

Status: GREEN

Implemented in `tools/codex-fleet-autonomy.ps1` and exercised by `tests/run-fleet-tests.ps1`.

