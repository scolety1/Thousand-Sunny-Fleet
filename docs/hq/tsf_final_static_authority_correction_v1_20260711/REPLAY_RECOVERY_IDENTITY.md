# Replay and Recovery Identity

Exact replay and recovery validate the complete stored relationship:

- mission ID/revision/content hash;
- policy fingerprint and deterministic queue-document hash;
- translator, result ID/hash, preservation path/hash;
- admission receipt path and observed file hash;
- transaction stable identity and content hash;
- admission status and decision hash;
- queue authority, source/destination states and paths;
- actual destination queue document and its complete canonical identity.

Rollback uses the same full queue-document identity through the bound recovery transaction. A stale, substituted, mismatched, incomplete, or wrong-authority record fails before receipt or transaction mutation. The preserved failed relationship is not rewritten as COMMITTED.
