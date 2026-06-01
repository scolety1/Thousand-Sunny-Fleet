# Lease And Heartbeat Contract

This contract defines the durable lease and heartbeat vocabulary used before any runtime lease manager or durable queue claim logic exists. It is evidence, not permission, and it does not delete locks, kill processes, resume ships, or mutate product repos.

## Purpose

Leases and heartbeats protect active work from accidental takeover. A recovery decision must use owner, fence token, heartbeat age, lease expiry, recovery class, stale state, expired state, ambiguous state, and deterministic failure evidence before any later runtime manager can act.

Plain invariant: do not delete locks as recovery.
Plain invariant: a fresh heartbeat plus active lease means leave the active owner alone.
Plain invariant: a stale heartbeat plus active lease is ambiguous state.
Plain invariant: deterministic failure is not blindly retried.

## Required Fields

Each lease heartbeat record must include:

- `schemaVersion`
- `leaseId`
- `shipId`
- `owner`
- `fenceToken`
- `heartbeatAt`
- `heartbeatAgeMinutes`
- `heartbeatState`
- `leaseCreatedAt`
- `leaseExpiresAt`
- `leaseState`
- `recoveryClass`
- `decision`
- `deletesLocks`
- `evidenceRefs`
- `validation`

`owner` identifies the worker or run that currently owns the selected ship. `fenceToken` is the monotonic token or opaque claim value that prevents stale owners from writing as if they still own the lease.

`heartbeatAgeMinutes` is measured from the last heartbeat evidence to the validation time. It must be visible in reports so stale state is not hidden.

## Heartbeat States

| State | Meaning |
| --- | --- |
| `fresh` | Heartbeat age is within the configured stale cutoff. |
| `stale` | Heartbeat age is past the stale cutoff. |
| `missing` | No heartbeat evidence exists. |
| `ambiguous` | Heartbeat evidence conflicts with lease or owner evidence. |

## Lease States

| State | Meaning |
| --- | --- |
| `active` | Lease has not expired. |
| `expired` | Lease expiry time has passed. |
| `missing` | No lease evidence exists. |
| `ambiguous` | Lease evidence conflicts with owner or fence-token evidence. |

## Recovery Classes

| Class | Decision | Meaning |
| --- | --- | --- |
| `fresh` | `LEAVE_RUNNING` | Fresh heartbeat and active lease show live ownership. |
| `stale` | `REQUIRE_REVIEW` | Stale evidence is not enough to safely take ownership. |
| `expired` | `RECOVER_WITH_BACKOFF` | Expired lease plus stale heartbeat may get one bounded recovery attempt. |
| `ambiguous` | `REQUIRE_REVIEW` | Conflicting or missing evidence blocks resume. |
| `deterministic-failure` | `STOP_FOR_REPAIR` | Repeated deterministic failure becomes repair work, not retry. |
| `environment-fault` | `WAIT_FOR_ENVIRONMENT` | External/local environment issue waits for recovery. |
| `policy-failure` | `BLOCK_FOR_POLICY_REVIEW` | Scope or safety policy blocks action until approval or correction. |

## Fixture Names

The following fixture names are required for tests and later helper work:

- `fresh-active-owner`
- `stale-active-ambiguous`
- `expired-stale-recoverable`
- `missing-ambiguous-review`
- `ambiguous-owner-review`
- `fence-token-mismatch`
- `clock-skew-suspicion-review`
- `deterministic-failure-stop-for-repair`
- `policy-failure-blocked`

## Validation Rules

A valid lease heartbeat record must:

- include a non-empty owner
- include a non-empty fence token
- include heartbeat age
- classify fresh, stale, expired, ambiguous, and deterministic failure states
- set `deletesLocks` to `false`
- reject lock deletion as a recovery path
- treat future heartbeat evidence, future lease creation evidence, or lease expiry before creation as `clock-skew-suspicion` requiring review
- preserve ambiguous state until human review or a later approved manager resolves it

## Fixture-Safe Classifier Helper

`New-FleetLeaseHeartbeatClassification` in `tools/codex-fleet-overnight.ps1` creates schema-shaped lease heartbeat fixture records from supplied timestamps, owner, fence-token, and failure-signal values. It is a pure classifier for tests and local evidence only.

The helper does not delete locks, rewrite lock files, kill processes, create a durable lease manager, launch ships, mutate product repos, or resume work.

The helper classifies:

- fresh heartbeat plus active lease as `fresh` with `LEAVE_RUNNING`
- stale heartbeat plus active lease as `stale` with `REQUIRE_REVIEW`
- expired lease plus stale heartbeat as `expired` with `RECOVER_WITH_BACKOFF`
- missing or conflicting owner/fence evidence as `ambiguous` with `REQUIRE_REVIEW`
- fence-token mismatch as `fence-token-mismatch` with review required
- clock-skew suspicion as `ambiguous` with `REQUIRE_REVIEW`
- deterministic failure as `deterministic-failure` with `STOP_FOR_REPAIR`
- environment failure as `environment-fault` with `WAIT_FOR_ENVIRONMENT`
- policy failure as `policy-failure` with `BLOCK_FOR_POLICY_REVIEW`

Plain helper invariant: `deletesLocks` is always `false`.
Plain helper invariant: deletesLocks is always false.
Plain helper invariant: stale active leases and ambiguous owners require review.
Plain helper invariant: clock-skew suspicion requires review.

## Negative Fixture Expectations

Fixture tests must assert that stale leases, expired leases, ambiguous owners, fence-token mismatches, clock-skew suspicion, and deterministic failures stay fixture-only and fail closed through review, bounded recovery, or repair decisions. These tests must not delete locks, kill processes, rewrite live worker state, launch ships, or mutate product repositories.

## Documentation-Only Sample JSON

The following lease heartbeat sample is a fixture documentation example only. It is not a live runtime record, not permission to recover a worker, and not an instruction to delete locks.

```json
{
  "schemaVersion": 1,
  "leaseId": "lease-fixture-001",
  "shipId": "FixtureShip",
  "owner": "worker-fixture-1",
  "fenceToken": "fence-fixture-1",
  "heartbeatAt": "2026-05-30T11:58:00Z",
  "heartbeatAgeMinutes": 2,
  "heartbeatState": "fresh",
  "leaseCreatedAt": "2026-05-30T11:40:00Z",
  "leaseExpiresAt": "2026-05-30T12:20:00Z",
  "leaseState": "active",
  "recoveryClass": "fresh",
  "decision": "LEAVE_RUNNING",
  "deletesLocks": false,
  "evidenceRefs": [
    "fixtures/lease-heartbeat/heartbeat.json"
  ],
  "validation": {
    "status": "valid",
    "reasons": [
      "fresh"
    ]
  }
}
```

## Out Of Scope

This contract intentionally does not perform or approve:

- Deleting locks
- Killing processes
- Creating a durable lease manager
- Creating SQLite or Fleet.Core tables
- Launching product ships
- Mutating product repos
- Running all-fleet commands
- Installing packages
- Running migrations
- Touching secrets, auth, payments, or deployment settings

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
