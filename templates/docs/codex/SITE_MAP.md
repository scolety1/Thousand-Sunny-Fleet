# Site Map

Use this file when the ship needs real pages/routes instead of one overloaded screen.

## Route Rules

- Keep `/` as the first page users should understand.
- Add or change frontend-only routes when doing so makes the product clearer.
- Keep page labels short and navigation obvious.
- Every important route should have a clear path back home or back to the main workspace.
- Prefer existing routing/framework patterns already in the repo.

## Planned Routes

- `/` - Home or primary workspace.

## Guardrails

- Do not add routing dependencies unless the task explicitly approves package/dependency changes.
- Do not add backend, auth, payments, APIs, analytics, tracking, secrets, deployment config, or real external integrations unless explicitly approved.
- Update `docs/codex/visual-routes.json` and fleet `visualPaths` when adding user-facing routes.
