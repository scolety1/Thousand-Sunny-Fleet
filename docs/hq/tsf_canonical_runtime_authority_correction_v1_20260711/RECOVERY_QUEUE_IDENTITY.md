# Recovery Queue Identity

Admission and transaction receipts retain mission content hash, policy fingerprint, canonical queue-document hash, and translator version in addition to mission, revision, result, preservation, receipt, and transition identities.

Exact replay and `RECOVERY_REQUIRED -> COMMITTED` reconciliation reread the actual destination queue document. The document must be the deterministic translation of the registered durable mission, occupy the recorded destination state/path, and agree with the original receipt and transaction. Missing, substituted, stale, or conflicting records fail before receipt or transaction mutation.
