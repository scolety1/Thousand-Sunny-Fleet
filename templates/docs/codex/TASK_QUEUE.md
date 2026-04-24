# Codex Task Queue

## Mission

Describe the project goal here.

## Guardrails

Codex should implement one selected task at a time. PowerShell owns execution, build checks, task completion, reports, and commits.

Codex may:
- edit only approved project files
- make small reviewable changes
- use fake data when prototyping
- improve copy, layout, and docs

Codex may not:
- run build commands
- mark tasks complete
- edit `docs/codex/NIGHTLY_REPORT.md`
- add backend/auth/payment/secrets/deployment work unless explicitly approved
- touch blocked paths from the selected profile

## Tasks

- [ ] First safe task: replace this with a narrow task that includes explicit forbidden scope.
