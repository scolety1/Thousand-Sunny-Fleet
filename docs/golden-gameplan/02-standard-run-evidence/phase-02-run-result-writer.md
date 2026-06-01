# Stage 2 Phase 2: RUN_RESULT Writer

## Goal

Write `docs/codex/RUN_RESULT.json` at the end of a run using the Stage 2 schema.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 2 Phase 2 only: RUN_RESULT writer.

Do not implement any other Golden Gameplan phase.

Goal:
Add the smallest reliable writer that creates or updates
docs/codex/RUN_RESULT.json for a ship after a checkpoint run.

Before editing:
- Run .\fleet-status.ps1.
- Read the Stage 2 Phase 1 schema.
- Inspect run-checkpoint-loop.ps1 for available run data.

Scope:
- Likely files: run-checkpoint-loop.ps1, tests/run-fleet-tests.ps1, optional
  helper function/script for writing JSON.
- Do not build RUN_SUMMARY.md or EVIDENCE_INDEX.md yet.
- Do not build the Stage 5 state machine.

Required behavior:
- On successful run completion, write RUN_RESULT.json.
- Include schema version and run ID.
- Include ship identity and git before/after fields when available.
- Include task outcomes and check outcomes when available.
- Include warnings for unavailable fields rather than omitting required sections.
- Write valid UTF-8 JSON.

Acceptance:
- Add tests proving RUN_RESULT.json is written for a successful fixture run.
- Add tests proving required top-level fields exist.
- Add tests proving JSON parses cleanly.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/02-standard-run-evidence/checkpoint.md.

Stop if:
- The checkpoint loop does not expose enough data for required fields. In that
  case, write a minimal supported result plus warnings and document gaps.
```

## Why It Matters

The fleet cannot make autonomous decisions until it has one reliable machine
record of each run.

## Done When

A successful run leaves a valid `RUN_RESULT.json`.

