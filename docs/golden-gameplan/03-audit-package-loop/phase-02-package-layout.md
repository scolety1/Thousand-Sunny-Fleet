# Stage 3 Phase 2: Audit Package Directory Layout

## Goal

Define and test the audit package folder/zip layout before collecting evidence.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 3 Phase 2 only: Audit package directory layout.

Do not implement any other Golden Gameplan phase.

Goal:
Create the standard folder layout and naming convention for audit packages.

Before editing:
- Run .\fleet-status.ps1.
- Read the Stage 3 Phase 1 manifest schema.

Scope:
- Add templates/docs/tests for layout.
- Likely files: tests/run-fleet-tests.ps1, FLEET_REPORTS_README.md, optional
  template folder under templates/.
- Do not collect real evidence yet.
- Do not build external-task ingestion.

Required layout:
- out/audit-packages/<audit-id>/
- out/audit-packages/<audit-id>.zip
- manifest.json
- README_AUDIT_PACKAGE.md
- prompts/
- fleet/
- ships/<ShipName>/
- ships/<ShipName>/evidence/

Required naming:
- audit IDs should include timestamp and optional mission slug.
- ship folder names should use collision-safe names from Stage 1.
- zip and folder names should match.

Acceptance:
- Add tests that construct or validate the target layout.
- Add tests that reject path traversal or unsafe audit IDs.
- Add tests that confirm zip path and folder path match.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/03-audit-package-loop/checkpoint.md.

Stop if:
- Safe ship names are not stable enough yet. Defer to Stage 1 Phase 8.
```

## Done When

The package shape is predictable before the builder starts filling it.

