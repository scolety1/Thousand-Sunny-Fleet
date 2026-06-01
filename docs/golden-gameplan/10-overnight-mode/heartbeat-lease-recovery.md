# Heartbeat, Lease, And Recovery Classes

Overnight autonomy needs a clear way to decide whether a ship is still working, safely recoverable, or too ambiguous to touch. The rule is:

```text
detect -> classify -> recover -> learn
```

## Evidence Inputs

- `heartbeatAt`: last time the worker proved it was alive.
- `leaseOwner`: worker/run that currently owns the ship.
- `leaseExpiresAt`: time when ownership expires if not renewed.
- `failureSignal`: optional class from logs/checkpoints.
- `staleHeartbeatMinutes`: default stale cutoff for unattended runs.

## Invariants

- A fresh heartbeat plus active lease means leave the active owner alone.
- A stale heartbeat plus active lease is ambiguous; do not delete locks.
- An expired lease plus stale heartbeat may get one bounded recovery attempt.
- Missing heartbeat and missing lease require review.
- Deterministic/code defects are not blindly retried.
- Policy failures require captain approval or scope correction.
- Environment faults wait for environment recovery.
- Ambiguous state requires review before resume.

## Recovery Classes

| Class | Decision | Meaning | Next action |
| --- | --- | --- | --- |
| transient | `RECOVER_WITH_BACKOFF` | lease expired or temporary issue | one bounded recovery attempt |
| deterministic/code defect | `STOP_FOR_REPAIR` | build/test/code failure repeats predictably | write repair task, no blind retry |
| environment fault | `WAIT_FOR_ENVIRONMENT` | dependency/provider/local environment problem | wait or fix environment |
| policy failure | `BLOCK_FOR_POLICY_REVIEW` | scope/safety/policy violation | captain review required |
| ambiguous state | `REQUIRE_REVIEW` | evidence conflicts or is missing | stop before touching locks |
| active with child work | `LEAVE_RUNNING` | heartbeat and lease show live ownership | leave it alone |

## Phone Digest Fields

Later mobile/status summaries should show:

- heartbeat age,
- lease owner,
- lease state,
- recovery class,
- decision,
- next captain action.

## Non-Goals

- No automatic lock deletion.
- No broad retry loop.
- No real lock mutation in tests.
- No product ship launch.
- No resuming ambiguous state without review.
