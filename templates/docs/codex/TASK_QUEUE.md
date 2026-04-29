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
- add frontend-only pages/routes when the selected task asks for real pages and the route is documented in `docs/codex/SITE_MAP.md`

Codex may not:
- run build commands
- mark tasks complete
- edit `docs/codex/NIGHTLY_REPORT.md`
- add backend/auth/payment/secrets/deployment work unless explicitly approved
- touch blocked paths from the selected profile
- add route dependencies unless dependency/package changes are explicitly approved

## Tasks

- [ ] User pain: replace with the concrete pain this task addresses. Target: replace with the route, screen, component, module, docs file, formula, test, or evaluator. Change: replace with the specific change to make. Remove/simplify: replace with what to remove, demote, combine, shorten, hide, or preserve. Guardrails: include explicit forbidden scope and risky systems not to touch. Acceptance: replace with documented build/check/test command or docs-only acceptance. Check: replace with visual, manual, fixture, formula, or report check. [class:feature risk:low mode:single impact:standard scope:docs/codex/]
