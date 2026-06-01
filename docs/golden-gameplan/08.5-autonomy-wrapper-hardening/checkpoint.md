# Stage 8.5 Checkpoint

Use this checklist before moving to Stage 9.

## Required Docs

- [x] `stage-plan.md`
- [x] `phase-01-failure-containment-coverage.md`
- [x] `phase-02-approved-packet-evidence-gate.md`
- [x] `phase-03-phone-report-hardening.md`
- [x] `phase-04-low-token-documentation.md`
- [x] `phase-05-one-ship-default-scope.md`
- [x] `phase-06-stage85-integration-check.md`
- [x] `audit-prompt.md`
- [x] `checkpoint.md`

## Implementation Completion Criteria

- [x] Failure containment tests were expanded.
- [x] `ApprovedPacketEvidence` is a real path to JSON validation evidence.
- [x] Packet import blocks without valid evidence.
- [x] Phone-readable captain summary exists.
- [x] Long blocked reasons are shortened in reports.
- [x] Low-token behavior is documented as manual Stage 8.5 behavior.
- [x] Default `MaxShips` is one.
- [x] Tests prove accidental multi-ship selection fails by default.

## Red Flags

Do not move to Stage 9 if:

- Packet import can happen with only a boolean flag.
- Missing packet evidence still maps to import.
- Default scope allows multiple ships without explicit `MaxShips`.
- Corrupt state evidence crashes without a report.
- Reports hide next captain action.
- Low-token docs imply automatic rate detection before Stage 10.

## Implementation Status

Status: GREEN

Evidence:
- `invoke-autonomy-wrapper.ps1`
- `tools/codex-fleet-autonomy.ps1`
- `tests/run-fleet-tests.ps1`

Verification:
- `.\tests\run-fleet-tests.ps1` passed.

Stage 9 readiness:
- Stage 8.5 makes the local wrapper safe enough for Stage 9 to formalize external agent handoff.
- Stage 9 should still implement the actual external-agent workflow and stricter packet handoff semantics.
- Stage 10 remains responsible for automatic rate-limit detection, safe landing, and auto-resume.
- Stage 13 remains responsible for phone command and review surfaces.

