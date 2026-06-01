# Stage 1 Phase 1: Safe-Stop Scoping

## Goal

Make safe-stop requests block only the intended ships, not unrelated dry runs,
experiments, or fixture tests.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 1 Phase 1 only: Safe-stop scoping.

Do not implement any other Golden Gameplan phase.

Goal:
Fix safe-stop behavior so a stop request for EasyLife, RestaurantDemo, or any
other unrelated ship does not block a dry run, experiment, fixture run, or launch
that targets different ships.

Before editing:
- Run .\fleet-status.ps1.
- Inspect the existing safe-stop helpers and experiment runner.
- Identify where stop requests are gathered and where they are asserted.

Scope:
- Update only fleet control scripts and tests needed for safe-stop scoping.
- Likely files: fleet-experiment.ps1, request-safe-stop.ps1, fleet-status.ps1,
  codex-fleet-launcher.ps1 or shared safe-stop helper files, tests/run-fleet-tests.ps1.
- Do not touch product repos.
- Do not manually delete existing stop requests.

Required behavior:
- A stop request for a selected ship blocks that selected ship.
- A global/all-ships stop request blocks all selected ships.
- A stop request for an unrelated ship does not block a run for other selected ships.
- Dry-run experiments still report unrelated stop requests as context when useful,
  but they do not fail because of them.
- The behavior is deterministic and test-covered.

Acceptance:
- Add or update tests that create at least one unrelated stop request and prove a
  selected fixture dry run still writes expected evidence.
- Add or update tests that prove a selected ship's stop request still blocks.
- Add or update tests that prove a global stop request still blocks.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/01-stability-first/checkpoint.md.

Stop if:
- Fixing this requires deleting real stop-request files.
- The stop-request format is ambiguous enough that behavior cannot be changed
  safely without a migration plan.
- Tests expose broader evidence-generation failures that belong to Phase 2.
```

## Why It Matters

The fleet cannot become autonomous if one parked ship can accidentally stop an
unrelated experiment. Safe-stop is a safety feature, but global false positives
turn it into a stall generator.

## Tests To Add

- unrelated safe-stop does not block selected fixture experiment
- selected safe-stop blocks selected ship
- global safe-stop blocks selected ship
- status output remains understandable with unrelated safe stops present

## Done When

The safe-stop system protects targeted ships without freezing the rest of the
fleet.

