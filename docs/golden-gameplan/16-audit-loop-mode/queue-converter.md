# Audit Loop Queue Converter

`new-audit-loop-queue.ps1` converts a structured external audit report into a bounded queue document for optional Audit Loop Mode.

This script intentionally does not parse prose audit reports with an LLM. A captain or external agent must provide structured JSON. That keeps the converter deterministic, reviewable, and easy to test.

## Command

```powershell
.\new-audit-loop-queue.ps1 `
  -ReportPath .\out\audit-loop-report.json `
  -MetadataPath .\out\audit-loop-metadata.json `
  -OutPath .\out\audit-loop-queue.md
```

If metadata or a finding requires captain approval, add `-CaptainApproved` only after the captain has approved that specific packet.

## Input Shape

The report should contain a `findings` array. A finding may either be skipped as an accepted limitation or include a `task` object matching `templates/audit-loop-task-schema.json`.

The converter validates:

- `maxTasks`
- required task fields
- duplicate task IDs
- accepted limitations
- forbidden paths and sensitive domains
- captain approval requirements

## Stop Rules

The converter exits nonzero and writes `.validation.json` when:

- accepted tasks exceed `maxTasks`
- a task is missing required fields
- a task touches forbidden scope
- a task duplicates an earlier accepted task ID
- captain approval is required but missing

It writes a queue only when all accepted tasks pass validation.

## Non-Goals

- Does not edit `docs/codex/TASK_QUEUE.md` directly.
- Does not execute tasks.
- Does not launch ships.
- Does not parse unstructured prose.
- Does not make HouseOS/customer-website rules global.
