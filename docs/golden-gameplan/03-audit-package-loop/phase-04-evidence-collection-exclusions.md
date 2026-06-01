# Stage 3 Phase 4: Evidence Collection and Exclusions

## Goal

Make audit packages useful without leaking secrets or becoming huge.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 3 Phase 4 only: Evidence collection and exclusions.

Do not implement any other Golden Gameplan phase.

Goal:
Harden the audit package builder so it collects the right evidence and excludes
unsafe or oversized content.

Before editing:
- Run .\fleet-status.ps1.
- Inspect the package builder from Stage 3 Phase 3.
- Identify common evidence files and unsafe files.

Scope:
- Likely files: package builder script, tests/run-fleet-tests.ps1, docs.
- Do not upload packages.
- Do not include full repo archives by default.

Include when available:
- RUN_RESULT.json
- RUN_SUMMARY.md
- EVIDENCE_INDEX.md
- TASK_QUEUE.md
- recent fleet status
- recent test output
- git status/diff stat
- runtime verification
- visual/design/copy/security/formula/accessibility/performance reports
- screenshots referenced by evidence files

Exclude always unless explicitly whitelisted:
- .env and secret files
- node_modules
- build/dist output
- .git internals
- large media not referenced by evidence
- private keys, tokens, credentials
- production customer data

Acceptance:
- Add tests that excluded files are not packaged.
- Add tests that referenced screenshots/reports are packaged when present.
- Add tests for missing optional evidence warnings.
- Add tests for size guardrails or oversized file skipping.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/03-audit-package-loop/checkpoint.md.

Stop if:
- A package would include data whose sensitivity is unclear. Exclude it and write
  a warning rather than guessing.
```

## Done When

Packages are safe enough to share with an external auditor by default.

