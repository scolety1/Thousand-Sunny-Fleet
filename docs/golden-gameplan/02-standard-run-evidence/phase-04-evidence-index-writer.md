# Stage 2 Phase 4: EVIDENCE_INDEX Writer

## Goal

Write `docs/codex/EVIDENCE_INDEX.md` so reports, logs, screenshots, and generated
evidence can be found from one file.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 2 Phase 4 only: EVIDENCE_INDEX writer.

Do not implement any other Golden Gameplan phase.

Goal:
Create docs/codex/EVIDENCE_INDEX.md after each run. It should list the evidence
files relevant to the latest run and categorize them by type.

Before editing:
- Run .\fleet-status.ps1.
- Confirm RUN_RESULT.json and RUN_SUMMARY.md writers exist.
- Inspect report names produced by checkpoint, runtime, visual, Simon, Robin,
  Joey, Franky, accessibility, and performance reviewers.

Scope:
- Likely files: run-checkpoint-loop.ps1, reviewer scripts if they expose paths,
  tests/run-fleet-tests.ps1.
- Do not build the Stage 3 audit package zip.
- Do not move evidence files yet unless necessary.

Required categories:
- run result
- run summary
- task reports
- build/test logs
- runtime verification
- visual evidence/screenshots
- design/copy/security/formula/accessibility/performance review reports
- git/diff evidence
- warnings and missing expected evidence

Acceptance:
- Add tests proving EVIDENCE_INDEX.md is written.
- Add tests proving known generated reports are indexed.
- Add tests proving missing optional evidence is recorded as missing/skipped
  rather than causing failure.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/02-standard-run-evidence/checkpoint.md.

Stop if:
- Existing reports do not expose stable paths. Index what is stable and document
  unstable evidence for Stage 3.
```

## Why It Matters

Audit packages, external agents, and phone summaries all need a single map of
what evidence exists.

## Done When

The latest run's evidence can be discovered from one Markdown file.

