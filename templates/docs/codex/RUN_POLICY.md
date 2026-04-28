# Codex Run Policy

This repo uses the reusable `codex-fleet` harness.

## Execution Model

PowerShell is the supervisor. Codex may inspect files, edit files, and review its own diff, but the outer script owns task selection, builds, reports, task completion, and commits.

For each round, the loop:
1. Selects the first unchecked task in `docs/codex/TASK_QUEUE.md`.
2. Asks Codex to implement only that task.
3. Runs guardrails against the diff.
4. Runs the configured build command externally.
5. Asks Codex to review and fix only issues in the current diff.
6. Runs guardrails again.
7. Runs the final external build.
8. Marks the task complete, appends `docs/codex/NIGHTLY_REPORT.md`, and commits only after the final build passes.

## Planner Handoff

After a run, generate a planner request, then either:
- paste it into ChatGPT Pro manually, or
- run the Codex CLI planner.

Always validate proposed tasks before importing them into `TASK_QUEUE.md`.

## Pages And Routes

Ships may define intended user-facing pages in `docs/codex/SITE_MAP.md` and visual QA routes in `docs/codex/visual-routes.json`.

Codex may add or change frontend-only pages/routes when the selected task asks for real pages, page splits, or route work, as long as it follows the repo's existing routing pattern and does not add package dependencies without explicit approval.

When adding a user-facing route, update the site map and visual route config so the fleet can screenshot and review that page on future runs.
