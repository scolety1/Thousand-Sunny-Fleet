# Admission and Queue Integration

Admission requires an active fingerprint regeneration, unique durable mission lookup, exact durable revision/content binding, schema-valid observed evidence, canonical repository/path checks, filesystem artifact hashes, required observed tests, verifier evidence, and native approval-ledger resolution.

Receipts are mandatory under the supplied existing preservation packet directory at `admission/<result-id>.admission.json`. Exact replay returns the preserved decision. Reusing a result ID with different content is rejected.

Queue outcomes use the existing `postrun_pending` transitions:

| Admission outcome | Existing queue state |
|---|---|
| `ADMITTED` | `complete_ready_for_gate` |
| `TIM_REQUIRED` | `blocked_needs_tim` |
| All caveat, review, rejection, and untrusted outcomes | `complete_review_only` |

Tests use only temporary scratch queues and cannot mutate real mission records.
