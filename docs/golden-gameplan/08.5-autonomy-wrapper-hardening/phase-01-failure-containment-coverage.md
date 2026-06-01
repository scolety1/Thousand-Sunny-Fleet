# Stage 8.5 Phase 1: Failure Containment Coverage

## Goal

Add tests for wrapper failure modes that Stage 8 did not fully prove.

## Required Cases

- corrupt state evidence
- audit package creation failure
- run-batch blocked by exhausted budget
- missing packet validation evidence

## Guardrails

- Use disposable fixtures only.
- Do not launch real ships.
- Do not delete locks or user work.

## Acceptance

- Failures write JSON/Markdown reports.
- Per-ship action failures return YELLOW, not a full unsafe crash.
- Fatal config/state failures return RED with a contained report.

## Implementation Status

Status: GREEN

Implemented in `tests/run-fleet-tests.ps1`.

