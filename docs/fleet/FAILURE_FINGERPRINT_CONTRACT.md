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
| `wait-for-rate-reset` | Stop model-heavy work until reset evidence exists. |
| `non-retriable-policy-denial` | Do not retry because policy denied the action. |

`policy-denial`, `broad-unsafe-task`, `backend-sensitive-scope`, `invalid-task-packet`, `stale-task-packet`, `dirty-unowned-repo`, `invalid-run-result`, and `missing-evidence` must not map to blind retry.

## Anti-Loop Fixtures

The following fixture names are required for tests and later helper work:

- `same-hypothesis-twice-safe-pause`
- `same-hypothesis-twice-repair-task`
- `policy-denial-non-retriable`
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
- Installing packages
- Running migrations
- Touching secrets, auth, payments, or deployment settings

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
