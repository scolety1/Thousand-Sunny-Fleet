# Stage 3 Phase 7: Package Validation and Size Guardrails

## Goal

Validate audit packages before handing them to a human or external agent.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 3 Phase 7 only: Package validation and size guardrails.

Do not implement any other Golden Gameplan phase.

Goal:
Add validation checks that make audit packages trustworthy: manifest references
must resolve, excluded files must stay excluded, package size must stay within
limits, and warnings must be explicit.

Before editing:
- Run .\fleet-status.ps1.
- Inspect package builder and tests from prior Stage 3 phases.

Scope:
- Likely files: package builder script, optional validation mode, tests.
- Do not build Stage 4 packet ingestion.

Required behavior:
- Validate manifest required fields.
- Validate every included file exists.
- Validate excluded patterns are absent.
- Validate package size against configurable limit.
- Validate zip can be opened.
- Write validation status into manifest and package README.

Acceptance:
- Add tests for valid package.
- Add tests for oversized file skipping or package warning.
- Add tests for excluded secret-like file not included.
- Add tests for broken manifest reference failure.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/03-audit-package-loop/checkpoint.md.

Stop if:
- Size limit needs product-specific policy. Add defaults and document override
  path instead of guessing.
```

## Done When

Audit packages can be checked before they leave the local machine.

