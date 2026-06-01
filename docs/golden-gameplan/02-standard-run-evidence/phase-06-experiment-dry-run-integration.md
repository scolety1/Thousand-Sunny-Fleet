# Stage 2 Phase 6: Experiment and Dry-Run Integration

## Goal

Make experiment and dry-run paths produce canonical evidence compatible with
normal checkpoint runs.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 2 Phase 6 only: Experiment and dry-run integration.

Do not implement any other Golden Gameplan phase.

Goal:
Extend the Stage 2 canonical evidence pattern to fleet-experiment.ps1 and dry-run
paths so presentation experiments, fixture runs, and audits can rely on the same
evidence shape.

Before editing:
- Run .\fleet-status.ps1.
- Confirm Stage 1 Phase 2 evidence repair is complete.
- Confirm Stage 2 checkpoint-loop evidence exists.

Scope:
- Likely files: fleet-experiment.ps1, tests/run-fleet-tests.ps1, possibly shared
  evidence helper.
- Do not build Stage 3 audit packages.
- Do not launch real product ships.

Required behavior:
- Experiment dry runs write compatible RUN_RESULT-style JSON evidence.
- Experiment dry runs write compatible Markdown summary evidence.
- Experiment refresh can locate the evidence.
- Multi-ship experiments summarize per-ship results cleanly.
- Failed/blocked experiments still report why evidence is partial.

Acceptance:
- Add tests for dry-run experiment canonical evidence.
- Add tests for multi-ship experiment summary fields.
- Add tests for refresh reading the evidence.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/02-standard-run-evidence/checkpoint.md.

Stop if:
- Experiment evidence needs a separate schema. If so, define a compatibility
  adapter and document why.
```

## Why It Matters

Experiments are where the fleet proves itself. They should not be second-class
evidence citizens.

## Done When

Experiment evidence can feed the same later audit and decision machinery.

