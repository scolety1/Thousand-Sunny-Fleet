# Stage 2 Phase 1: RUN_RESULT Schema

## Goal

Define the canonical `RUN_RESULT.json` shape before writing or integrating it.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 2 Phase 1 only: RUN_RESULT schema.

Do not implement any other Golden Gameplan phase.

Goal:
Create the canonical schema and documentation for docs/codex/RUN_RESULT.json.
This file will become the machine-readable summary of the latest run for a ship.

Before editing:
- Run .\fleet-status.ps1.
- Confirm Stage 1 checkpoint is GREEN or explicitly approved to proceed.
- Inspect existing reports to identify fields already available.

Scope:
- Add schema/template docs only plus tests that validate sample data.
- Likely files: docs/golden-gameplan/02-standard-run-evidence, templates or
  docs/codex schema location, tests/run-fleet-tests.ps1.
- Do not integrate the writer yet.
- Do not change run-checkpoint-loop.ps1 yet unless absolutely needed for tests.

Required schema concepts:
- schemaVersion
- runId
- generatedAt
- ship
- projectPath
- branch
- headBefore
- headAfter
- dirtyAtStart
- dirtyAtEnd
- startedAt
- endedAt
- runtimeSeconds
- taskBatch
- tasksAttempted
- tasksCompleted
- tasksQuarantined
- tasksBlocked
- checks
- evidence
- materialChanges
- decisionHint
- stopReason
- errors
- warnings

Acceptance:
- Add a schema or documented template for RUN_RESULT.json.
- Add at least one valid sample RUN_RESULT fixture.
- Add tests that validate required field presence or template completeness.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/02-standard-run-evidence/checkpoint.md.

Stop if:
- Field naming conflicts with existing fleet report conventions. Document the
  conflict and propose a compatibility name.
```

## Why It Matters

If the schema is vague, every later stage will invent its own interpretation of
what happened in a run.

## Done When

The fleet has a clear, test-backed contract for the machine-readable run result.

