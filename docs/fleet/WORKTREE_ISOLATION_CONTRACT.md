# Worktree Isolation Contract

This contract defines the boundary record used before autonomous product-mode work can be considered. It is evidence, not permission, and it does not launch ships, create worktrees, mutate product repos, or authorize cleanup.

## Core Rule

Autonomous product mode has no implicit direct product-root mutation. A valid boundary must bind exactly one selected ship to one dedicated worktree before any product-mode task can be treated as runnable.

Plain invariant: one selected ship must map to one dedicated worktree.
Plain invariant: no implicit direct product-root mutation is allowed.
Plain invariant: this contract does not grant execution permission.

## Required Boundary Fields

Each boundary record must include:

- `schemaVersion`
- `boundaryId`
- `shipId`
- `sourceRepoRoot`
- `sourceGitTopLevel`
- `worktreePath`
- `branch`
- `owner`
- `leaseId`
- `cleanupPosture`
- `boundaryState`
- `generatedAt`
- `evidenceRefs`
- `validation`

`sourceGitTopLevel` records the observed Git top-level path for the source repository. `sourceRepoRoot` records the configured source root. They must describe the same intended source repository before a boundary can be valid.

`worktreePath` is the proposed or observed isolated worktree path for the selected ship. It is not a command to create that path.

`branch`, `owner`, and `leaseId` make the boundary attributable and auditable.

## Boundary States

| State | Meaning |
| --- | --- |
| `fixture-only` | Boundary is for local fixtures or schema tests only. |
| `planned` | Boundary has been described but not observed active. |
| `active` | Boundary has enough evidence for a single selected ship and dedicated worktree. |
| `stale` | Boundary evidence is old or no longer matches current repo facts. |
| `blocked` | Boundary cannot be validated without broader scope or human input. |
| `invalid` | Boundary violates one or more isolation rules. |

## Cleanup Posture

Cleanup posture records what may happen later. It is not cleanup permission.

- `preserve`: keep boundary artifacts for review.
- `manual-review`: require a human review before cleanup.
- `safe-dispose-fixture-only`: fixture-only exception for disposable test data.
- `do-not-delete-locks`: preserve locks and leases.

Plain invariant: do not delete locks.

## Fixture-Only Exceptions

A fixture-only exception may use synthetic paths, synthetic branch names, and disposable fixture worktree paths when the record is explicitly marked `fixture-only`. Fixture-only records must not be promoted to product-mode execution evidence.

No real product repo is required for this contract. Fixture records exist to validate schema behavior, parser behavior, and boundary rejection cases without reading or modifying product repositories.

## Rejected Cases

| Reason | Rejection |
| --- | --- |
| `missing-worktree` | The selected ship has no dedicated worktree evidence. |
| `broad-ship-selection` | The boundary covers more than one selected ship or uses all-fleet scope. |
| `direct-product-root-mutation` | The task would edit the source product root instead of an isolated worktree. |
| `ship-mismatch` | The ship id in the boundary does not match the selected ship. |
| `source-root-mismatch` | The configured source root and observed Git top-level do not match. |
| `fixture-root-escape` | A fixture path resolves outside the supplied fixture root, including traversal-like paths. |
| `ambiguous-boundary` | Required boundary evidence is missing, stale, blocked, planned-only, or otherwise not enough to prove one ship to one worktree. |
| `lock-deletion-forbidden` | The workflow asks to delete locks or widen cleanup permissions. |

## Validation Rules

A valid boundary requires:

- exactly one selected ship
- one dedicated worktree
- a non-empty branch
- a non-empty owner
- a non-empty lease id
- source root evidence
- worktree path evidence
- validation status `valid`

The validator must reject missing-worktree, broad-ship-selection, direct-product-root-mutation, ship-mismatch, source-root-mismatch, and fixture-root-escape cases. Ambiguous-boundary records must fail closed as invalid or unknown, never as runnable product evidence. Fixture-only exception records may be accepted only as fixture evidence and only when the boundary state is `fixture-only`.

## Fixture-Safe Validator Helper

`Test-FleetWorktreeBoundary` in `tools/codex-fleet-state.ps1` validates schema-shaped worktree boundary records without creating git worktrees, deleting locks, launching ships, or reading product repositories.

The helper is fixture-safe and accepts synthetic paths. It returns validation status and reasons for local evidence only. It is not a runtime worktree manager and it does not grant mutation permission.

The helper accepts:

- one non-wildcard selected ship
- one non-empty `worktreePath`
- matching `sourceRepoRoot` and `sourceGitTopLevel`
- a `worktreePath` that is separate from `sourceRepoRoot`
- optional `FixtureRoot` confinement for fixture tests

Plain validator invariant: worktreePath that is separate from sourceRepoRoot.

The helper rejects:

- missing worktree path as `missing-worktree`
- blank, `all`, `*`, wildcard, or comma-packed ship scope as `broad-ship-selection`
- direct product-root mutation where `worktreePath` equals `sourceRepoRoot` as `direct-product-root-mutation`
- selected ship mismatch as `ship-mismatch`
- source root and Git top-level mismatch as `source-root-mismatch`
- traversal-like fixture paths that escape FixtureRoot as `fixture-root-escape`
- missing branch, owner, lease id, evidence refs, or planned/stale/blocked boundary states as `ambiguous-boundary`

Fixture-only records may include `fixture-only-exception` as evidence, but that reason does not promote the record to product-mode execution.

## Negative Fixture Expectations

Fixture tests must assert that missing worktree evidence, a direct product-root marker, mismatched ship id, traversal path escape, and ambiguous boundary records fail closed. These tests must not create or delete git worktrees; they only pass schema-shaped records to the fixture-safe validator.

## Out Of Scope

This contract intentionally does not perform or approve:

- Creating git worktrees
- Deleting locks
- Launching product ships
- Mutating product repos
- Running all-fleet commands
- Installing packages
- Running migrations
- Adding SQLite or Fleet.Core
- Touching secrets, auth, or payments

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
