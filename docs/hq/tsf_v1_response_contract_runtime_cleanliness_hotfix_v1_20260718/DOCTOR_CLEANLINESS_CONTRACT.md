# Doctor cleanliness contract

Doctor separates source status from queue inventory and now delegates every candidate generated record to the authoritative `Test-TsfCanonicalQueueDocument` contract through `Test-TsfCanonicalQueueRecordFile`.

The source check excludes only Git-ignored canonical generated records. It still reports tracked modifications and unrelated untracked files. The queue check walks every non-`.gitkeep` file beneath the canonical queue root and validates:

- known direct state directory;
- exact `<mission-id>.r<positive-revision>.json` filename;
- normalized containment beneath the one production queue root;
- a regular file reached through no symbolic link, junction, mount point, or other reparse component;
- parseable JSON;
- the complete closed canonical queue-document schema, deterministic hashes, repository/worktree identity, packet/lifecycle/integrity bindings, and durable/source identity;
- case-sensitive document mission/revision identity matching the filename;
- parent-directory state authority matching the exact canonical state directory;
- exactly one path for each mission revision;
- no unknown, invalid, stale, or conflicting record.

Queue documents are immutable and intentionally contain no mutable `queue_state` member. The existing transition policy makes the exact parent state directory the canonical state authority; adding a document field would invalidate the document and packet hashes on every move. The file validator therefore binds the validated immutable document to the caller-observed exact parent directory as `CANONICAL_PARENT_DIRECTORY_V1`.

Doctor reports the canonical queue root, per-state counts, generated-record count, validation authority, and unknown/invalid count. Approved generated evidence alone is GREEN. Malformed, incomplete, schema-invalid, misnamed, wrong-state, duplicated, unreadable, reparse-backed, unknown protected, tracked, staged, and unrelated untracked inputs fail closed with the exact path. The 87-assertion adversarial suite executed real Windows file symlink and junction branches in this environment, never followed the targets, and proved every target hash unchanged.

The production CLI and server do not expose an alternate-root option. Deterministic demo and reliability tests must opt in explicitly, and that capability accepts only roots contained by `.codex-local/fixtures`; those records still pass the same complete canonical document validator. This fixture capability is not a second production queue authority.
