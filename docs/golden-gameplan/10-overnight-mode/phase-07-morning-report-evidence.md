# Stage 10 Phase 7 Prompt: Morning Report And Evidence

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 10 Phase 7 only: Morning Report and Evidence.

Goal:
Define the report the user gets after an overnight run.

The morning report should include:
- run window
- selected ships
- starting state
- ending state
- budget events
- safe landings
- resumes
- tasks completed
- audits packaged
- failures
- repairs attempted
- ships parked
- ships taste-gated
- ships blocked
- screenshots or preview links when available
- next recommended action

Report formats:
- human-readable Markdown
- machine-readable JSON
- short captain summary

The short captain summary should answer:
- What worked?
- What failed?
- What needs my taste?
- What can run again?
- Did we save limits safely?

Guardrails:
- Do not exaggerate success.
- Do not hide empty outputs.
- Do not call parked ships finished unless done contract is met.
- Do not overwrite previous reports.

Acceptance:
- Morning report template exists.
- Example report exists for successful, partially failed, and low-budget paused nights.
- Evidence paths are included.

Proof:
Show template and examples.
```

## Notes

This is what the user should be able to read with coffee and know exactly where things stand.

## Implementation Status

Status: GREEN

Implemented by `New-FleetOvernightMorningReport` and the JSON/Markdown outputs
from `invoke-overnight-mode.ps1`. Reports include captain summary, selected
ships, governor decision, resume readiness, evidence paths, and next action.
