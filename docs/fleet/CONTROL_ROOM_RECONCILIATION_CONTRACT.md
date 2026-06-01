# Control-Room Reconciliation Contract

This contract defines the reconciliation record that must exist before the dashboard/control-room layer is treated as authoritative. It is evidence, not permission, and it does not introduce SQLite, change live dashboard output, launch ships, or mutate product repos.

## Purpose

The control room currently renders read-only snapshots from supplied status input. HQ requires a future reconciliation layer that compares DB/state evidence, Git/repo fingerprint evidence, and run artifact evidence. When those sources disagree, the dashboard must show `UNKNOWN` instead of presenting stale or contradictory state as truth.

Plain invariant: dashboard must show UNKNOWN on DB/Git/run artifact mismatch.
Plain invariant: reconciliation evidence is data, never permission.
Plain invariant: the model cannot mark mismatched evidence as MATCH.

## Required Fields

Each reconciliation record must include:

- `schemaVersion`
- `reconciliationId`
- `shipId`
- `repoFingerprintRef`
- `runArtifactRef`
- `dbStateRef`
- `statusSnapshotRef`
- `reconciliationStatus`
- `mismatchReasons`
- `displayStatus`
- `generatedAt`
- `evidenceRefs`
- `validation`

`repoFingerprintRef` points to the selected-ship repo fingerprint evidence. `runArtifactRef` points to the run result or task evidence being summarized. `dbStateRef` points to durable DB/state evidence when such a store exists. `statusSnapshotRef` points to the dashboard input snapshot.

No live DB is required for this contract. Until a DB-backed control plane exists, fixture and JSON state refs are enough to validate the vocabulary.

## Reconciliation Status

| Status | Meaning | Display posture |
| --- | --- | --- |
| `MATCH` | DB/state, Git fingerprint, run artifact, and snapshot agree. | May display the matched state with evidence refs. |
| `MISMATCH` | At least two sources conflict. | Must display `UNKNOWN` until reviewed. |
| `UNKNOWN` | Required evidence is missing, stale, or not yet connected. | Must display `UNKNOWN`. |

## Mismatch Reasons

Stable mismatch vocabulary:

- `stale-artifact`
- `repo-fingerprint-drift`
- `missing-db-state-ref`
- `missing-run-artifact-ref`
- `missing-repo-fingerprint-ref`
- `status-snapshot-mismatch`
- `contradictory-lease`
- `dirty-state-conflict`
- `ship-id-mismatch`
- `unknown-source`

## Fixture Names

The following fixture names are required for tests and later helper work:

- `MATCH`
- `MISMATCH`
- `UNKNOWN`
- `stale-artifact`
- `repo-fingerprint-drift`
- `missing-db-state-ref`
- `contradictory-lease`

## Fixture-Safe Reconciliation Helper

`New-FleetControlRoomReconciliationFixture` is the fixture-only helper for this contract. It returns schema-shaped reconciliation records with `MATCH`, `MISMATCH`, or `UNKNOWN` and keeps the display status fail-closed when evidence does not agree.

Plain helper invariant: the helper does not introduce SQLite, change live dashboard output, launch ships, mutate product repos, or approve action. It classifies evidence only.

Required fixture mismatch reasons include:

- stale run artifact: `stale-artifact`
- repo fingerprint drift: `repo-fingerprint-drift`
- missing DB/state ref: `missing-db-state-ref`
- contradictory lease: `contradictory-lease`

Missing required evidence maps to `UNKNOWN`. Contradictory or stale evidence maps to `MISMATCH` and must display `UNKNOWN` until reviewed.

## Validation Rules

A valid reconciliation record must:

- bind to exactly one ship id
- include repo fingerprint ref, run artifact ref, DB/state ref, and status snapshot ref fields
- preserve mismatch reasons instead of hiding them
- set `displayStatus` to `UNKNOWN` when `reconciliationStatus` is `MISMATCH`
- set `displayStatus` to `UNKNOWN` when `reconciliationStatus` is `UNKNOWN`
- never convert missing or contradictory evidence into `MATCH`

## Out Of Scope

This contract intentionally does not perform or approve:

- Introducing SQLite
- Changing live dashboard output
- Mutating product repos
- Launching product ships
- Running all-fleet commands
- Deleting locks
- Installing packages
- Running migrations
- Touching secrets, auth, payments, or deployment settings

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
