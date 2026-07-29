# Persisted Recovery Rehydration

Persisted recovery is evidence, never authority.

The loader:

1. accepts only an evidence root below the fixed offline evidence parent;
2. rejects reparse aliases and duplicate JSON members;
3. reloads the exact pinned canonical authority;
4. resolves the task, registration, preauthorization, and task binding;
5. reconstructs the canonical candidate set for the exact task/path/iteration;
6. compares the persisted candidate-set copy with that reconstruction;
7. revalidates the writeset and recovery identities and cross-links;
8. rehashes the preimage and replacement artifacts;
9. verifies replacement SHA and byte length against canonical membership;
10. classifies the actual repository as exact preimage, exact replacement, or
    ambiguous before continuing.

Serialized `valid` and `verified` fields are removed before validation and have
no effect. Unknown authority-bearing fields reject. The original recovery run
remains immutable; continuation receives a distinct recovery identity and a
single-use receipt.

Historical records lacking the candidate-set artifact are not upgraded. They
fail before lock or temporary-file creation with
`RECOVERY_CANONICAL_CANDIDATE_BINDING_ABSENT`.
