# Stage 3 Phase 1: Audit Manifest Schema

## Goal

Define the machine-readable `manifest.json` contract for audit packages.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 3 Phase 1 only: Audit manifest schema.

Do not implement any other Golden Gameplan phase.

Goal:
Create the schema/template for audit package manifest.json. This manifest should
describe the package, selected ships, included evidence, omitted evidence, safety
filters, and audit prompts.

Before editing:
- Run .\fleet-status.ps1.
- Confirm Stage 2 checkpoint is GREEN or explicitly approved to proceed.
- Inspect RUN_RESULT.json, RUN_SUMMARY.md, and EVIDENCE_INDEX.md contracts.

Scope:
- Add schema/template docs and tests only.
- Likely files: templates/audit-manifest-schema.json or equivalent,
  docs/golden-gameplan/03-audit-package-loop, tests/run-fleet-tests.ps1.
- Do not build the package script yet.

Required fields:
- schemaVersion
- auditId
- generatedAt
- fleetRoot
- fleetHead
- selectedShips
- packagePath
- zipPath
- includedFiles
- omittedFiles
- safetyFilters
- prompts
- sourceEvidence
- warnings
- errors

Acceptance:
- Add a manifest schema or documented template.
- Add a valid sample manifest fixture.
- Add tests that validate required field presence or template completeness.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/03-audit-package-loop/checkpoint.md.

Stop if:
- Stage 2 evidence fields are missing or unstable. Document the dependency and
  stop instead of inventing incompatible fields.
```

## Done When

There is a clear manifest contract that a package builder and external agent can
trust.

