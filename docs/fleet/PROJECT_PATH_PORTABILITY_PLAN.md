# Project Path Portability Plan

Prepared: 2026-06-12

Evidence only; not executable authority or approval.

## Purpose

This plan describes how Codex Fleet should handle project repo paths across laptops without leaking public absolute paths or silently using stale machine-specific locations. It is design guidance only. It does not approve project repo mutation, PrivateLens changes, proof runs, all-fleet execution, overnight runners, installs, migrations, remote access configuration, secrets handling, phone approvals, runtime command binding, staging, commit, push, merge, deploy, or future authority.

## Problem

`projects.json` currently stores concrete local repo paths because Fleet runners need local paths to inspect task queues and run validation. Those paths are machine-specific. A path that was valid on one machine may be missing on a new laptop, especially when it points at a generated agent output directory.

Missing project paths must fail closed. Fleet must not infer a replacement path, scan unrelated directories, touch product repos, or treat a dashboard/phone request as permission to remap a project.

## Design Goals

- Keep `projects.json` as the source of truth for the registered project id and default local path.
- Add a future per-machine local override layer only after a separate exact task approves implementation.
- Keep local absolute paths out of public status surfaces and generated phone/dashboard summaries.
- Require proof-run preflight to report missing paths as blocked or not-ready evidence.
- Require exact human approval before changing a registered project path.
- Preserve one-project, one-task proof-run boundaries.

## Proposed Local Override Model

A future implementation may allow a gitignored local file such as:

```text
.codex-local/project-paths.local.json
```

The local override file would map project ids to repo paths on the current laptop only. It would be ignored by git and treated as local environment configuration, not Fleet authority.

Example shape:

```json
{
  "PrivateLens": "C:\\Users\\<you>\\Documents\\Projects\\PrivateLens"
}
```

The file must not contain secrets, tokens, credentials, remote access details, or private service endpoints. It must not be published, copied into docs, embedded in phone/dashboard HTML, or treated as approval to run product work.

## Resolution Order

Future path resolution should be explicit and auditable:

1. Read the registered project from `projects.json`.
2. If an approved local override file exists, use only the exact project id match.
3. Normalize the candidate path for local checks.
4. If the path is missing, fail closed with a clear warning.
5. If the path exists, verify it is the expected project repo before any proof-run readiness can turn GREEN.

No fallback search should walk broad user directories, infer by folder name alone, or select the first matching repo. Ambiguity must stay YELLOW or RED until Tim gives an exact path.

## Proof-Run Preflight Requirements

Before an actual proof run can be GREEN, preflight must confirm:

- the resolved project path exists on the current laptop
- the path is a git repo when repo state is required
- the expected task queue exists
- the selected task matches exactly one unchecked task when `-RequireSelectedTask` is used
- the build directory exists
- the configured validation command is present
- Codex CLI is runnable from the same shell

If any required item is missing, proof-run readiness remains false. Passing Fleet tests or a valid Codex CLI shim does not override missing product context.

## Public Output Boundary

Generated status for phone/dashboard or public docs should identify projects by project id and readiness status, not by full local user paths. Public-facing output may say `path missing`, `path configured locally`, or `project context unavailable`, but it must not print private absolute paths such as user profile directories.

Local diagnostic commands may print paths inside a human-controlled local shell when explicitly requested, but those diagnostics remain evidence only.

## Safe Repair Options

When a project path is missing on a new laptop, use one of these exact human-approved repairs:

- update the Fleet project path to a stable local clone path
- clone or copy the product repo to the currently configured path
- add a future gitignored local override for this laptop
- defer product proof-runs to the machine where the product context already exists

The safest default for a new laptop is to choose a stable local path and update Fleet only after read-only verification confirms the repo identity, branch, accepted commit, task queue, and validation scripts.

## Stop Conditions

Stop and report BLOCKED if path repair would require:

- touching PrivateLens or another product repo without exact approval
- running product builds or proof runs
- installing dependencies
- running migrations
- configuring remote access
- storing secrets or private credentials
- scanning broad user folders for repos
- exposing local absolute paths in public docs or dashboards
- treating phone/dashboard UI as execution authority
- widening Fleet permissions

## Status

This plan is documentation and test coverage only. It does not implement local path overrides or change existing project resolution behavior.
