# Stage 3: Audit Package Loop

Stage 3 turns canonical run evidence into compact, repeatable audit packages for
humans and external ChatGPT agents.

Stage 2 creates standard evidence. Stage 3 packages that evidence safely.

## Goal

Create a deterministic audit-package workflow that can answer:

- What happened in the latest run?
- What evidence supports that?
- What screenshots, logs, reports, and diffs should an auditor inspect?
- What should the external agent be asked to do?
- What should be excluded for safety and size?

## Why This Stage Matters

The fleet cannot rely on outside agents unless it can give them a consistent,
safe, and focused evidence bundle. The package should be small enough to upload,
complete enough to audit, and structured enough for later task-packet ingestion.

## Phase Order

1. Audit manifest schema
2. Audit package directory layout
3. Audit package builder
4. Evidence collection and exclusions
5. Prompt generation
6. Multi-ship audit packages
7. Package validation and size guardrails
8. Stage 3 integration check

## Target Output

Example package:

```text
out/audit-packages/<audit-id>/
  manifest.json
  README_AUDIT_PACKAGE.md
  prompts/
    issues-audit.md
    improvement-audit.md
    decision-architect.md
  fleet/
    fleet-status.txt
    git-status-short.txt
    latest-tests.txt
    projects.json
  ships/
    <ShipName>/
      RUN_RESULT.json
      RUN_SUMMARY.md
      EVIDENCE_INDEX.md
      TASK_QUEUE.md
      git-status.txt
      git-diff-stat.txt
      evidence/
        ...
```

The zip should live beside the folder:

```text
out/audit-packages/<audit-id>.zip
```

## Files Likely Touched During Implementation

Planning only in this document. When implementation begins, likely files include:

- new `make-audit-package.ps1` or `new-audit-package.ps1`
- `tests/run-fleet-tests.ps1`
- `FLEET_REPORTS_README.md`
- `README.md`
- templates or schemas under `templates/`
- optional helpers for evidence path normalization and secret exclusions

## Stage Exit Criteria

Stage 3 is complete when:

- one command creates a valid audit package folder and zip
- package manifest is machine-readable
- package includes Stage 2 canonical evidence when present
- package includes appropriate prompts
- package excludes secrets, dependency folders, build output, and oversized junk
- missing optional evidence is reported without breaking the package
- multi-ship packages work for selected ships
- tests cover contents, exclusions, and size guardrails
- `.\tests\run-fleet-tests.ps1` passes

## Do Not Do

- Do not ingest external task packets. That is Stage 4.
- Do not call external agents automatically.
- Do not upload packages anywhere.
- Do not include `.env`, secrets, `node_modules`, build directories, or private
  data packs unless explicitly whitelisted.
- Do not package full downstream repositories by default.
- Do not decide next actions beyond package-level recommendations.

## Implementation Rule

Audit packages should be evidence bundles, not new planners. They may include
prompts that ask external agents for tasks, but they should not apply those tasks
in Stage 3.

