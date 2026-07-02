# Lane 7 Product Access Approval Packet

Prepared: 2026-07-02

Draft only; not approved. Product repos remain off-limits until Tim selects a project and gives exact approval.

## Approval Fields

- selected project:
- repo path:
- access mode: read-only | mutation
- branch:
- allowed files:
- off-limits files:
- allowed commands:
- validation expectations:
- commit boundary:
- push boundary:
- stop conditions:
- expiration:

## Read-Only Scope Example

Read-only may include:

- git status/log/HEAD
- top-level structure
- README/docs
- package/test metadata
- selected files named by Tim

Read-only may not include:

- file edits
- staging
- commits
- push
- installs
- migrations
- secrets/auth/payments/deploy material
- proof runs
- all-fleet commands
- background runners
- external account changes

## Mutation Scope Example

Mutation approval must name exact allowed files or directories and exact
validation commands. If exact files are not named, Codex must stop before
editing.

## Commit / Push Boundaries

- Local commit requires clean scope, exact staged files, and passing validation.
- Push requires a separate exact push approval after final checks.
- Product repo mutation does not imply product repo push.

## Archived Projects

Archived projects stay locked. Any archived project reactivation needs exact Tim
approval naming the archived project and reactivation scope.

## Exact Tim Approval Language

```text
TIM_EXACT_APPROVAL:
action: <read-only inspection | bounded mutation | local commit>
selected project:
repo/path:
branch:
allowed files:
off-limits files:
allowed command(s):
validation:
max scope:
stop conditions:
expires after:
```

## Final Report Format

Return:

- verdict
- repo/path
- branch/HEAD/status
- files read or changed
- validation
- commit hash if created
- blockers
- next safe action
- confirmation no push/deploy/install/migration/secrets/proof-run/all-fleet/background/external-account/archived-reactivation work occurred unless separately approved
