# Stage 3 Phase 6: Multi-Ship Audit Packages

## Goal

Support audit packages for selected groups of ships without mixing unrelated
state or unsafe content.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 3 Phase 6 only: Multi-ship audit packages.

Do not implement any other Golden Gameplan phase.

Goal:
Extend audit package generation to multiple selected ships while preserving
clear per-ship evidence boundaries.

Before editing:
- Run .\fleet-status.ps1.
- Confirm single-ship package generation works.

Scope:
- Likely files: package builder script, tests/run-fleet-tests.ps1.
- Do not package all ships by default.
- Do not include dirty product repo diffs beyond status/stat evidence unless
  explicitly selected and safe.

Required behavior:
- Accept multiple selected ships.
- Create one `ships/<ShipName>/` folder per selected ship.
- Include per-ship warnings and missing evidence separately.
- Include fleet-level summary across selected ships.
- Do not let one missing ship fail the whole package unless strict mode is set.

Acceptance:
- Add tests packaging two fixture ships.
- Add tests with one selected ship missing optional evidence.
- Add tests for unknown ship handling.
- Add tests that per-ship files do not overwrite each other.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/03-audit-package-loop/checkpoint.md.

Stop if:
- Safe-name collision handling is not complete. Defer until Stage 1 Phase 8 is
  green.
```

## Done When

The captain can generate one package for a selected fleet slice.

