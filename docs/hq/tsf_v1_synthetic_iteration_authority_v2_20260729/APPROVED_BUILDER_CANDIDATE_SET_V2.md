# Approved Builder Candidate Set V2

`APPROVED_BUILDER_CANDIDATE_SET_V2` is a derived record inside the existing
Synthetic Iteration Authority V2. It is not a second approval system.

The canonical authority contains immutable candidate templates keyed by exact
task, repository-relative path, and iteration. Each template member contains
its SHA-256, UTF-8 byte length, static provenance, generation-run identity, and
maximum candidate count. Duplicate task/path/iteration templates and duplicate
candidate members reject.

At task start, the runtime derives a candidate-set record that additionally
binds:

- canonical authority SHA-256;
- program and task;
- registration and preauthorization identities;
- repository root and Git top-level;
- branch;
- concrete baseline commit and tree;
- iteration and repository-relative path;
- candidate members, count limit, and expiry.

The derived identity is recorded in the preauthorized task binding. A writeset
may reference only one of those identities. Candidate-set self-identity proves
integrity; authorization comes only from exact reconstruction from the pinned
canonical authority.

A persisted candidate-set artifact is evidence. Recovery reloads the canonical
authority, reconstructs the expected set, and requires byte-for-byte canonical
equivalence. A persisted list, caller-created list, worker claim, `valid` flag,
or coherently recomputed descendant identity cannot add a candidate.

Historical V2 recovery records without this binding remain preserved and reject
as `RECOVERY_CANONICAL_CANDIDATE_BINDING_ABSENT` with disposition
`NEW_GOVERNED_RECOVERY_REQUIRED`.
