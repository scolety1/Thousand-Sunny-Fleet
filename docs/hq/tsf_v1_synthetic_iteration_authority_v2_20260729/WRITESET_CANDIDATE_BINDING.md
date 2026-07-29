# Writeset Candidate Binding

Every `APPROVED_WRITESET_V2` binds the task, preauthorization, task binding,
registration, repository, branch, baseline commit/tree, iteration, and run.
Its single write binds:

- exact allowlisted path;
- actual before-file SHA-256;
- approved replacement SHA-256;
- approved candidate-set identity;
- replacement byte length;
- controlled replacement artifact path and SHA-256;
- `ATOMIC_REPLACE`;
- expected Git mode `100644`.

Validation reconstructs the canonical candidate set first. It then requires the
replacement SHA and byte length to be an exact member for that task, path, and
iteration. The actual controlled artifact bytes are hashed and length-checked.
The actual current file is hashed before writeset creation and again at the
replacement sink.

The writeset identity is an integrity checksum, not replacement authority.
Recomputing it after substituting the deterministic all-`a` SHA rejects as
`REPLACEMENT_SHA_NOT_IN_APPROVED_BUILDER_CANDIDATE_SET` before temporary-file
creation, source mutation, or command execution.
