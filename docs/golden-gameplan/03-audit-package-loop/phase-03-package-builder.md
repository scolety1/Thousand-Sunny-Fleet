# Stage 3 Phase 3: Audit Package Builder

## Goal

Create the first working audit package builder command.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 3 Phase 3 only: Audit package builder.

Do not implement any other Golden Gameplan phase.

Goal:
Add a command, likely make-audit-package.ps1 or new-audit-package.ps1, that
creates an audit package folder and zip for selected ships.

Before editing:
- Run .\fleet-status.ps1.
- Confirm Stage 3 Phases 1-2 are complete.
- Inspect existing manual package command history if available.

Scope:
- Add package builder script and tests.
- Likely files: new package script, tests/run-fleet-tests.ps1, README docs.
- Do not call external agents.
- Do not ingest returned tasks.
- Do not include full product repos by default.

Required behavior:
- Accept selected ship names.
- Read projects.json.
- Read fleet status and git status.
- Copy Stage 2 canonical evidence for each selected ship when present.
- Write manifest.json.
- Write README_AUDIT_PACKAGE.md.
- Create zip archive.
- Report missing optional evidence as warnings.

Acceptance:
- Add tests that package one fixture ship.
- Add tests that package a ship with missing optional evidence.
- Add tests that output folder and zip both exist.
- Add tests that manifest references files actually included.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/03-audit-package-loop/checkpoint.md.

Stop if:
- Stage 2 evidence is not available. In that case, package fleet-level evidence
  only and document the limitation.
```

## Done When

One command can produce a usable local audit package.

