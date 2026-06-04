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
- `missing-dry-run-evidence`
- `ambiguous-approval-evidence`
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
- `missing-dry-run-evidence`
- `ambiguous-approval-evidence`

## Fixture-Safe Reconciliation Helper

`New-FleetControlRoomReconciliationFixture` is the fixture-only helper for this contract. It returns schema-shaped reconciliation records with `MATCH`, `MISMATCH`, or `UNKNOWN` and keeps the display status fail-closed when evidence does not agree.

Plain helper invariant: the helper does not introduce SQLite, change live dashboard output, launch ships, mutate product repos, or approve action. It classifies evidence only.

Required fixture mismatch reasons include:

- stale run artifact: `stale-artifact`
- repo fingerprint drift: `repo-fingerprint-drift`
- missing DB/state ref: `missing-db-state-ref`
- contradictory lease: `contradictory-lease`

Missing required evidence maps to `UNKNOWN`. Contradictory or stale evidence maps to `MISMATCH` and must display `UNKNOWN` until reviewed.

## UNKNOWN Evidence Matrix

The following matrix is local reconciliation evidence only. It does not introduce a live dashboard integration, SQLite integration, remote UI implementation, runtime command binding, product-repo access, product-repo mutation, package sending, all-fleet execution, phone approvals, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.

| fixture | reconciliationStatus | displayStatus | mismatchReasons | meaning |
| --- | --- | --- | --- | --- |
| `stale-run-artifact-unknown` | `MISMATCH` | `UNKNOWN` | `stale-artifact` | A stale run artifact cannot be displayed as current truth. |
| `missing-repo-fingerprint-unknown` | `UNKNOWN` | `UNKNOWN` | `missing-repo-fingerprint-ref` | Missing repo fingerprint evidence blocks confident display. |
| `mismatched-selected-target-unknown` | `MISMATCH` | `UNKNOWN` | `ship-id-mismatch` | Selected target mismatch cannot be converted into approval. |
| `contradictory-lease-unknown` | `MISMATCH` | `UNKNOWN` | `contradictory-lease` | Contradictory lease evidence blocks execution posture. |
| `missing-dry-run-evidence-unknown` | `UNKNOWN` | `UNKNOWN` | `missing-dry-run-evidence` | Missing dry-run evidence remains unknown instead of assumed safe. |
| `ambiguous-approval-evidence-unknown` | `UNKNOWN` | `UNKNOWN` | `ambiguous-approval-evidence` | Ambiguous approval evidence requires review and cannot approve action. |

UNKNOWN blocks execution. UI labels, generated evidence, reviewer output, mobile requests, queue prose, prompts, buttons, notifications, DOCX reports, audit packages, or task packets cannot convert `UNKNOWN` or `MISMATCH` reconciliation evidence into `MATCH`, approval, or execution authority.

## Common Non-Authority Phrase Set

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Selected-Project Read-Only Matrix Alignment

The selected-project read-only end-to-end fixtures under `tests/fixtures/fleet/read-only-gates` use reconciliation outcomes to prove that missing, stale, write-capable, or ambiguous selected-project evidence stays fail-closed.

This alignment is local fixture evidence only. It does not inspect product repos, add live dashboard integration, introduce SQLite integration, bind runtime commands, create or send packages, approve phone actions, run all-fleet commands, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, launch demos, or grant future authority.

| selected-project fixture | reconciliationStatus | displayStatus | required posture |
| --- | --- | --- | --- |
| `selected-project-read-only.valid-fixture` | `MATCH` | `MATCH` | all evidence agrees for local fixture review only |
| `selected-project-read-only.missing-owner-denied` | `UNKNOWN` | `UNKNOWN` | missing owner blocks confident display |
| `selected-project-read-only.stale-fingerprint-deferred` | `UNKNOWN` | `UNKNOWN` | stale fingerprint requires review |
| `selected-project-read-only.write-capable-denied` | `UNKNOWN` | `UNKNOWN` | write-capable request cannot display as safe |
| `selected-project-read-only.ambiguous-approval-unknown` | `UNKNOWN` | `UNKNOWN` | ambiguous approval cannot become `MATCH` |

## Validation Rules

A valid reconciliation record must:

- bind to exactly one ship id
- include repo fingerprint ref, run artifact ref, DB/state ref, and status snapshot ref fields
- preserve mismatch reasons instead of hiding them
- set `displayStatus` to `UNKNOWN` when `reconciliationStatus` is `MISMATCH`
- set `displayStatus` to `UNKNOWN` when `reconciliationStatus` is `UNKNOWN`
- never convert missing or contradictory evidence into `MATCH`
- never convert UI labels, generated evidence, reviewer output, mobile requests, or queue prose into approval

## Out Of Scope

This contract intentionally does not perform or approve:

- Introducing SQLite
- Changing live dashboard output
- Mutating product repos
- Launching product ships
- Running all-fleet commands
- Live dashboard integration
- SQLite integration
- Remote UI implementation
- Runtime command binding
- Product-repo access
- Package sending
- Deleting locks
- Installing packages
- Running migrations
- Touching secrets, auth, payments, or deployment settings

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
