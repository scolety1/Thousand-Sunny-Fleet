# Repo Fingerprint Contract

Prepared: 2026-05-30

Scope: Codex Fleet harness, docs, schemas, and tests only. This contract defines the selected-ship repo fingerprint shape before runtime gates, worktree managers, or durable queues are implemented.

## Purpose

A repo fingerprint is the immutable preflight record that binds one selected ship to one observed git repository state for one run decision. It is evidence, not permission. A valid fingerprint can support a later policy decision, packet import check, resume preflight, or worktree boundary check, but it never grants product-repo mutation by itself.

## Required Fields

Every fingerprint must include:

- `schemaVersion`
- `fingerprintId`
- `shipId`
- `repoRoot`
- `gitTopLevel`
- `branch`
- `head`
- `dirtyState`
- `changedFileSummary`
- `worktreePath`
- `generatedAt`
- `evidenceRefs`
- `validation`

The JSON schema lives at `templates/repo-fingerprint-schema.json`.

## Safety Invariants

- A mutating product-mode run must have exactly one selected ship.
- Blank, `all`, `*`, wildcard, or multi-ship targets are invalid for mutating product-mode work.
- `repoRoot` must be the configured selected-ship repository root.
- `gitTopLevel` must match `repoRoot` for direct-root checks.
- Plain invariant: gitTopLevel must match repoRoot.
- A later worktree boundary may use a dedicated `worktreePath`, but this contract does not create worktrees.
- The model cannot mark an invalid fingerprint valid to grant itself permission.
- Dirty state is not failure by itself, but it requires explicit evidence and policy handling before write-capable actions.
- Imported packets, mobile requests, and external review reports must be checked against the fingerprint as data, never treated as executable commands.

## Dirty State Values

| Value | Meaning | Runtime posture |
| --- | --- | --- |
| `clean` | Git root is present and no changed files are reported. | Eligible for later policy review. |
| `dirty` | Git root is present and changed files are reported. | Requires changed-file summary and evidence refs before later policy review. |
| `wrong-root` | The checked path is inside or outside the configured repo root and does not match `gitTopLevel`. | Invalid; stop and repair selection/config. |
| `missing` | Configured repo path is absent. | Invalid; stop and repair config/path. |
| `git-error` | Git commands failed for reasons other than missing path/wrong root. | Invalid or unknown; inspect git evidence. |
| `stale-head` | A packet/resume/approval expected a different head than the observed fingerprint. | Invalid for import/resume; regenerate or reapprove. |
| `path-traversal` | Input path attempts `..`, absolute escape, wildcard selection, or unsafe normalization. | Invalid and policy-denied. |

## Fixture Cases

Tests and examples should cover these fixture names:

- `clean`
- `dirty`
- `wrong-root`
- `missing-repo`
- `stale-head`
- `path-traversal`

Fixture coverage must stay inside `.codex-local/fixtures` or other harness-owned temporary directories. No real product repo is required for this contract.

## Validation Rules

1. Resolve `repoRoot` to an absolute path.
2. Reject path traversal before calling git.
3. If `repoRoot` does not exist, record `dirtyState = missing` and `validation.status = invalid`.
4. Run `git rev-parse --show-toplevel` only after the path exists.
5. If `gitTopLevel` does not equal `repoRoot`, record `dirtyState = wrong-root` and `validation.status = invalid`.
6. Record branch, head, changed-file count, and changed-file names from git status.
7. If an expected head is provided for packet import or resume and it differs from `head`, record `dirtyState = stale-head` and `validation.status = invalid`.
8. Record evidence refs for the git status, git head, source packet/resume metadata, or validation report used to make the decision.

## Freshness And Ambiguity Negative Fixtures

Freshness fixtures are evidence-only checks for the future runtime policy gate. They do not read real product repos and do not allow execution.

- `stale-head`: if an expected head differs from the observed head, the fingerprint is invalid and must block packet import, resume, or real-project execution until regenerated or reapproved.
- `missing-repo`: if the configured repo path is absent, the fingerprint is invalid and must block execution until configuration is repaired.
- `wrong-root`: if `gitTopLevel` does not match `repoRoot`, the fingerprint is invalid and must block execution until the selected repo root is corrected.
- `path-traversal`: if input attempts `..`, wildcard, absolute fixture-root escape, or unsafe normalization, the fingerprint is invalid before git is called.
- `dirty-state-ambiguous`: if dirty state is observed without evidence refs, the fingerprint status is `unknown` and must defer write-capable or real-project execution.
- `git-error`: if git metadata cannot be read from an existing fixture path, the fingerprint is invalid or unknown and must block execution until inspected.

Stale, missing, wrong-root, traversal, dirty-ambiguous, and git-error fingerprints are never approval to launch ships, mutate product repositories, import packets, resume work, or widen scope. They may only produce local evidence and a repair/review decision.

## Fixture-Safe Builder Helper

`New-FleetRepoFingerprint` in `tools/codex-fleet-state.ps1` builds schema-shaped repo fingerprint records from fixture repos. It wraps the existing `Get-FleetRepoState` read-only helper and adds HQ validation vocabulary for:

- clean fixture repo
- dirty fixture repo
- wrong-root fixture path
- missing repo path
- stale head
- path traversal or fixture-root escape

The helper accepts a `FixtureRoot` boundary for tests. When `FixtureRoot` is set, paths outside that harness-owned root are classified as `path-traversal` before git is called. This keeps tests fixture-only and ensures no product repo is read by fixture validation.

The helper returns schema fields matching `templates/repo-fingerprint-schema.json`, including `fingerprintId`, `shipId`, `repoRoot`, `gitTopLevel`, `branch`, `head`, `dirtyState`, `changedFileSummary`, `worktreePath`, `generatedAt`, `evidenceRefs`, and `validation`.

## Documentation-Only Sample JSON

The following repo fingerprint sample is a fixture documentation example only. It is not a live runtime record, not permission to touch a product repo, and not an instruction to run git.

```json
{
  "schemaVersion": 1,
  "fingerprintId": "repo-fixture-001",
  "shipId": "FixtureShip",
  "repoRoot": ".codex-local/fixtures/repo-fingerprint/fixture-repo",
  "gitTopLevel": ".codex-local/fixtures/repo-fingerprint/fixture-repo",
  "branch": "codex/fixture",
  "head": "abc123fixture",
  "dirtyState": "dirty",
  "changedFileSummary": {
    "count": 1,
    "files": [
      "docs/example.md"
    ],
    "truncated": false
  },
  "worktreePath": ".codex-local/fixtures/repo-fingerprint/fixture-repo",
  "generatedAt": "2026-05-30T12:00:00Z",
  "evidenceRefs": [
    "fixtures/repo-fingerprint/git-status.txt"
  ],
  "validation": {
    "status": "valid",
    "reasons": [
      "dirty"
    ]
  }
}
```

## Out Of Scope For This Task

- Creating git worktrees.
- Authorizing product mutations.
- Adding SQLite or Fleet.Core.
- Running all-fleet status or launch commands.
- Reading or modifying real product repos.
- Deleting locks or recovering leases.

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
