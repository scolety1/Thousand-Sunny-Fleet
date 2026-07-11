# Complete Recovery Identity

The public recovery path accepts one canonical `tsf_canonical_recovery_envelope_v1`. Loose recovery transaction parameters are rejected.

The envelope is created by the admission/transaction system and binds:

- mission ID, revision, content hash, policy fingerprint, queue-document hash, and translator version;
- result ID, canonical result path, and result SHA-256;
- preservation path and SHA-256;
- staged/canonical admission receipt paths and observed receipt SHA-256;
- transaction path, file SHA-256, stable identity SHA-256, and content SHA-256;
- admission status and recomputed decision hash;
- queue-authority identity;
- expected source/destination states;
- actual destination queue record and rollback destination.

Admission, exact replay, recovery reconciliation, rollback, and final COMMITTED verification use `Test-TsfAdmissionRelationship`. Recovery adds envelope-to-result/receipt/transaction comparisons and independently recomputes all file hashes and deterministic queue identity.

A substituted, stale, incomplete, wrong-authority, wrong-state, or wrong-path relationship returns RED before movement. Original evidence remains unchanged; an immutable compact `k-<key>.json` diagnostic is written separately. Valid exact replay is idempotent. Rollback moves only the exact bound destination queue record.
