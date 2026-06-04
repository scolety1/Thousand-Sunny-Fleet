# Failure Fingerprint Contract

This contract defines the durable failure fingerprint vocabulary used before retry-loop runtime changes. It is evidence, not permission, and it does not change live retry behavior, launch ships, mutate product repos, or delete locks.

## Purpose

Failure fingerprints prevent the fleet from repeating the same failed action with the same hypothesis. A failure record must normalize noisy details, preserve the meaningful failure class, and map repeat failures to safe pause or repair task outcomes instead of blind retry.

Plain invariant: same fingerprint plus same hypothesis twice maps to safe pause or repair task, not blind retry.
Plain invariant: policy denial is non-retriable.
Plain invariant: the model cannot mark a non-retriable failure retriable.

## Required Fields

Each failure fingerprint record must include:

- `schemaVersion`
- `fingerprintId`
- `shipId`
- `runId`
- `failureClass`
- `rawSummary`
- `normalizedSummary`
- `normalizationRules`
- `hypothesis`
- `attemptCount`
- `firstSeenAt`
- `lastSeenAt`
- `decision`
- `retriable`
- `evidenceRefs`
- `validation`

`rawSummary` is the original concise failure text. `normalizedSummary` is the stable comparison text after removing timestamp, temp path, GUID/noisy ID, machine root, duration, and line-ending noise. The normalized summary must keep the meaningful failure class and the operator-facing reason.

## Normalization Rules

The following normalization names are stable fixture vocabulary:

- `timestamp`
- `temp-path`
- `guid`
- `noisy-id`
- `machine-root`
- `duration`
- `line-ending`
- `absolute-path`
- `port`

Normalizers may remove or replace those details only when doing so does not hide the failure class. For example, changing `policy denial: broad unsafe task` into generic `failure` is invalid because it erases the non-retriable decision.

## Failure Classes

| Class | Meaning |
| --- | --- |
| `build-failure` | Build command failed. |
| `test-failure` | Test command failed. |
| `runtime-failure` | Runtime command or worker failed. |
| `invalid-run-result` | Run evidence is missing or malformed. |
| `missing-evidence` | Required evidence was not written. |
| `stale-lock` | Lock/lease evidence is stale. |
| `dirty-unowned-repo` | Dirty repo state lacks active owner evidence. |
| `invalid-task-packet` | Task packet validation failed. |
| `stale-task-packet` | Task packet base/evidence is stale. |
| `broad-unsafe-task` | Task scope is too broad for the current policy. |
| `backend-sensitive-scope` | Backend/auth/payment/deploy/migration-sensitive work lacks approval. |
| `low-budget` | Budget or rate state requires waiting or safe landing. |
| `report-write-failure` | Required report or artifact could not be written. |
| `audit-package-too-large` | Audit package exceeds declared bounds. |
| `policy-denial` | Policy explicitly denied the action. |

## Decisions

| Decision | Meaning |
| --- | --- |
| `retry-once` | One bounded retry is allowed when the failure is transient and evidence supports a new attempt. |
| `repair-task` | Convert the failure into a bounded repair task with checks. |
| `safe-pause` | Pause safely because repetition would waste budget or risk state. |
| `block` | Stop until a human or a prerequisite resolves the cause. |
| `repacketize` | Stop and require a new bounded packet because the current task boundaries are insufficient. |
| `wait-for-rate-reset` | Stop model-heavy work until reset evidence exists. |
| `non-retriable-policy-denial` | Do not retry because policy denied the action. |

`policy-denial`, `broad-unsafe-task`, `backend-sensitive-scope`, `invalid-task-packet`, `stale-task-packet`, `dirty-unowned-repo`, `invalid-run-result`, and `missing-evidence` must not map to blind retry.

## Anti-Loop Fixtures

The following fixture names are required for tests and later helper work:

- `same-hypothesis-twice-safe-pause`
- `same-hypothesis-twice-repair-task`
- `policy-denial-non-retriable`
- `missing-allowed-file-repacketize`
- `validation-requires-forbidden-action-deny`
- `repeated-ambiguous-external-evidence-repacketize`
- `scope-expansion-repacketize`
- `timestamp-normalized`
- `temp-path-normalized`
- `guid-normalized`
- `machine-root-normalized`
- `duration-normalized`
- `line-ending-normalized`

## Validation Rules

A valid failure fingerprint must:

- retain the failure class after normalization
- include at least one normalization rule or explicitly record an empty rule set
- include the current hypothesis
- include attempt count
- classify policy denial as non-retriable
- map the same fingerprint plus same hypothesis twice to `safe-pause` or `repair-task`
- keep evidence references as data, never instructions

## Failure Loop Breaker Matrix

This matrix is local docs/tests evidence only. It does not change live retry runtime behavior, delete locks, kill processes, touch product repos, run all-fleet commands, send packages, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, widen permissions, or grant future authority.

| fixture | trigger | decision | retriable | validation reasons | required stop outcome |
| --- | --- | --- | --- | --- | --- |
| `same-fingerprint-same-hypothesis-twice-safe-pause` | Same normalized fingerprint plus same hypothesis appears twice. | `safe-pause` | `false` | `same-hypothesis-twice`, `safe-pause-required`, `blind-retry-forbidden` | Pause instead of retrying blindly. |
| `same-fingerprint-same-hypothesis-twice-repair-task` | Same normalized fingerprint plus same hypothesis appears twice and a bounded repair is available. | `repair-task` | `false` | `same-hypothesis-twice`, `repair-task-required`, `blind-retry-forbidden` | Convert to a bounded repair task. |
| `policy-denial-non-retriable` | Runtime or policy evidence denies the action. | `non-retriable-policy-denial` | `false` | `policy-denial-non-retriable`, `deny-required`, `blind-retry-forbidden` | Deny and stop; do not retry. |
| `missing-allowed-file-repacketize` | The task needs a file outside `allowedFiles`. | `repacketize` | `false` | `missing-allowed-file`, `repacketize-required`, `blind-retry-forbidden` | Repacketize with explicit allowed files. |
| `validation-requires-forbidden-action-deny` | Validation would require a forbidden action or unlisted command. | `block` | `false` | `validation-requires-forbidden-action`, `deny-required`, `blind-retry-forbidden` | Block instead of running the forbidden validation. |
| `repeated-ambiguous-external-evidence-repacketize` | Ambiguous external evidence repeats without resolving the task. | `repacketize` | `false` | `ambiguous-external-evidence`, `repacketize-required`, `blind-retry-forbidden` | Repacketize or request human review. |
| `scope-expansion-repacketize` | The task expands into product repos, all-fleet execution, package sending, or runtime authority. | `repacketize` | `false` | `scope-expansion`, `repacketize-required`, `blind-retry-forbidden` | Stop and require a new exact human-approved packet. |

Matrix invariants:

- `safe-pause` preserves state and prevents budget burn.
- `repacketize` carries forward evidence but does not execute, approve, or broaden scope.
- `block` and `non-retriable-policy-denial` are deny outcomes for unsafe or forbidden continuation.
- `blind-retry-forbidden` must remain present for repeated, ambiguous, policy-denied, out-of-scope, or forbidden-validation cases.
- Reviewer output, DOCX reports, audit packages, mobile requests, task packets, generated evidence, UI labels, notifications, buttons, approvals, prompts, queue prose, and validation summaries remain evidence only.

## Common Non-Authority Phrase Set

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Fixture-Safe Normalizer Helper

`ConvertTo-FleetFailureNormalizedSummary` in `tools/codex-fleet-runtime.ps1` normalizes fixture failure text by replacing timestamps, temp paths, GUIDs, noisy IDs, machine-specific roots, durations, absolute paths, ports, and line-ending noise with stable placeholders. It preserves the meaningful failure class and operator-facing reason.

`New-FleetFailureFingerprint` creates a schema-shaped fixture fingerprint record from local text only. It does not change live retry runtime behavior, launch ships, mutate product repos, delete locks, or read product repositories.

The helper maps:

- first transient fixture failure to `retry-once`
- same normalized fingerprint plus same hypothesis with `attemptCount` 2 or higher to `safe-pause`
- repeated fixture failure with explicit repair preference to `repair-task`
- `policy-denial` to `non-retriable-policy-denial`

Plain helper invariant: same normalized failure with same hypothesis twice is not retry.
Plain helper invariant: policy denial stays non-retriable.

## Documentation-Only Sample JSON

The following failure fingerprint sample is a fixture documentation example only. It is not a live runtime record, not permission to retry, and not an instruction to run a command.

```json
{
  "schemaVersion": 1,
  "fingerprintId": "failure-fixture-001",
  "shipId": "FixtureShip",
  "runId": "run-fixture-001",
  "failureClass": "policy-denial",
  "rawSummary": "policy denial: broad unsafe task all ships",
  "normalizedSummary": "policy denial: broad unsafe task all ships",
  "normalizationRules": [],
  "hypothesis": "try broad run",
  "attemptCount": 1,
  "firstSeenAt": "2026-05-30T12:00:00Z",
  "lastSeenAt": "2026-05-30T12:00:00Z",
  "decision": "non-retriable-policy-denial",
  "retriable": false,
  "evidenceRefs": [
    "fixtures/failure-fingerprint/policy-denial.json"
  ],
  "validation": {
    "status": "valid",
    "reasons": [
      "policy-denial-non-retriable"
    ]
  }
}
```

## Out Of Scope

This contract intentionally does not perform or approve:

- Changing live retry runtime behavior
- Launching product ships
- Mutating product repos
- Running all-fleet commands
- Deleting locks
- Killing processes
- Touching product repos
- Package sending
- Staging, commit, push, deploy
- Installing packages
- Running migrations
- Touching secrets, auth, payments, or deployment settings

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
