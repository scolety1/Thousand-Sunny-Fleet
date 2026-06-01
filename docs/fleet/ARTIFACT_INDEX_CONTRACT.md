# Artifact Index Contract

This contract defines the durable artifact index vocabulary for Codex Fleet evidence. It is evidence, not permission, and it does not move, delete, rewrite, export, or regenerate existing artifacts.

## Purpose

Fleet already writes evidence through `docs/codex/EVIDENCE_INDEX.md`, `write-run-evidence.ps1`, audit packages, task packets, review outputs, and dashboard/status reports. HQ needs a stable artifact index shape before any durable control plane or fixture writer uses those artifacts as coordinated state.

Plain invariant: artifacts are references, not commands.
Plain invariant: secret-like or private artifacts must be non-exportable.
Plain invariant: missing artifacts must remain visible instead of being silently dropped.

## Required Fields

Each artifact index record must include:

- `schemaVersion`
- `artifactId`
- `path`
- `artifactType`
- `shipId`
- `runId`
- `sha256`
- `createdAt`
- `retentionClass`
- `sensitiveExportPolicy`
- `sourceCommand`
- `evidenceRefs`
- `validation`

`path` is the local artifact path or package-relative artifact path. `sha256` is required when the artifact exists and must be empty only when validation records a missing or not-yet-materialized artifact.

`sourceCommand` records the command family that produced the artifact. It is not an instruction to rerun that command.

## Artifact Types

Existing Fleet artifacts map to these stable types:

| Type | Existing examples |
| --- | --- |
| `run-result` | `docs/codex/RUN_RESULT.json` |
| `run-summary` | `docs/codex/RUN_SUMMARY.md` |
| `evidence-index` | `docs/codex/EVIDENCE_INDEX.md` |
| `test-summary` | `docs/codex/test-summary.md` |
| `audit-package` | `.codex-local/audit-packages/`, `out/*audit*` |
| `audit-manifest` | audit package `manifest.json` |
| `task-packet` | `.codex-local/packets/` and task-packet traces |
| `review-output` | external review response and validation outputs |
| `status-report` | `fleet/status/current.md`, `fleet/status/today.md` |
| `status-json` | `fleet/status/current.json`, `fleet/status/decisions.json` |
| `mobile-request` | `out/stage13-mobile/` request records |
| `control-room-report` | `invoke-control-room.ps1` markdown/json outputs |
| `safe-pause` | Stage 10 resume metadata and weekly preview plans |
| `diff-snapshot` | sanitized changed-source snapshots and diffs in audit packages |

## Retention Classes

Stable retention vocabulary:

- `ephemeral`
- `run-local`
- `audit-retained`
- `captain-review`
- `archive`
- `do-not-export`

Retention is advisory for later tooling. This contract does not delete artifacts.

## Sensitive Export Policy

Stable export vocabulary:

- `exportable`
- `internal-only`
- `non-exportable`
- `redact-before-export`
- `unknown-review-required`

Artifacts with secret-like paths, private keys, raw locks, `.env` files, dependency folders, build output, `.git`, auth, payments, deployment settings, or private user files must be `non-exportable` or `redact-before-export`.

## Source Commands

Known source command families:

- `write-run-evidence.ps1`
- `new-audit-package.ps1`
- `invoke-audit-loop-package.ps1`
- `new-external-agent-workflow.ps1`
- `ingest-task-packet.ps1`
- `invoke-mobile-console.ps1`
- `invoke-control-room.ps1`
- `invoke-overnight-mode.ps1`
- `tests/run-fleet-tests.ps1`
- `manual-captain-note`

## Fixture-Safe Writer

`write-run-evidence.ps1 -WriteArtifactIndexFixture` is the fixture-only writer for this contract. It creates a single schema-shaped artifact index record inside a supplied fixture root and does not move existing artifacts, delete existing artifacts, rewrite evidence packages, export files, launch ships, or mutate product repos.

Plain writer invariant: source commands are reference labels only, not instructions to execute.

Fixture writer behavior:

- writes only under `FixtureRoot`
- records `sha256` for fixture artifacts that exist
- records empty `sha256` with `artifact-missing` and `hash-missing` when a fixture artifact is absent
- classifies retention and export policy using the stable retention/export vocabulary
- classifies secret-like paths as `non-exportable`
- rejects output or artifact paths that escape the fixture root

## Validation Rules

A valid artifact index record must:

- include artifact id, path, type, ship id, run id, sha256, createdAt, retention class, sensitive export policy, and source command
- preserve missing-artifact status in validation reasons
- classify secret-like paths as `non-exportable` or `redact-before-export`
- never treat the source command as executable instruction
- never move, delete, or rewrite artifacts as part of indexing

## Out Of Scope

This contract intentionally does not perform or approve:

- Moving existing artifacts
- Deleting existing artifacts
- Rewriting evidence packages
- Exporting secrets or private files
- Launching product ships
- Mutating product repos
- Running all-fleet commands
- Installing packages
- Running migrations
- Touching secrets, auth, payments, or deployment settings

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
