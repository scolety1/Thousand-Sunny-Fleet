# Operator Console Read-Only Skeleton V1

Verdict: GREEN_OPERATOR_CONSOLE_READONLY_SKELETON_COMPLETE

## Purpose

The read-only Operator Console gives Tim a local visual entry point into TSF status without adding a server, background runner, command bridge, API call, or mission execution path.

## Scope

- Static HTML, CSS, and JavaScript only.
- Reads local static JSON when available.
- Falls back to embedded sample status data when opened directly from disk.
- Displays status, branches, worker roles, queue states, review packets, gates, and next action.
- Does not mutate the repository or execute commands.

## Files

- `tools/operator-console/readonly/index.html`
- `tools/operator-console/readonly/app.js`
- `tools/operator-console/readonly/style.css`
- `tools/operator-console/readonly/sample-status.json`
- `tools/operator-console/readonly/README.md`

## Read-Only Attestation

The console has no write API, no shell bridge, no network transport, no Codex worker invocation, no queue execution button, and no background process.
