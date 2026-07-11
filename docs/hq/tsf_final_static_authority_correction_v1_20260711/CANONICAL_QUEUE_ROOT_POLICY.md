# Canonical Queue Root Policy

There is one production queue: the queue_root declared by fleet/control/mission-queue-state-policy.v1.json, resolved internally from the verified repository top-level.

Operational queue records remain outside runtime artifact storage and retain mission-oriented filenames. Transition evidence is written under compact runtime storage.

Normal entry points reject an alternate physical QueueRoot. Tests require the explicit TestOnlyAllowAlternateQueueRoot capability and an isolated root under .codex-local/fixtures or the canonical runtime scratch hierarchy.

Admission and transactions record queue-authority kind, root, policy hash-derived identity, and whether the admission is production. Test-queue receipts are marked TEST_ONLY and production_admission false; a queue-authority mismatch fails before transition or replay mutation.
