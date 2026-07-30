# Architectural Decision Record

## Decision

Proceed with a canonical V2 extension and no new authority system.

`ARCHITECTURE_VERDICT:
PROCEED_WITH_CANONICAL_V2_EXTENSION_NO_NEW_ARCHITECTURAL_BLOCKER`

The fresh read-only Architect classified:

- `EXISTING_V1_FIXTURE_AUTHORITY_TOO_NARROW`: YES
- `VERSIONED_SYNTHETIC_ITERATION_AUTHORITY_REQUIRED`: YES
- `CLOSED_TASK_PREAUTHORIZATION_REQUIRED`: YES
- `ITERATION_STATE_MACHINE_EXTENSION_REQUIRED`: YES
- `MULTIFILE_ALLOWLIST_EXTENSION_REQUIRED`: YES
- `LOCAL_COMMIT_AUTHORITY_EXTENSION_REQUIRED`: YES
- `RECOVERY_WRITESET_BINDING_REQUIRED`: YES
- `MULTIPLE_LOCALIZED_CORRECTIONS_REQUIRED`: YES
- `NEW_ARCHITECTURAL_BLOCKER`: NO

The persisted-candidate correction review used primary classification
`MULTIPLE_LOCALIZED_CORRECTIONS_REQUIRED` and returned `PROCEED`. Its root
cause was a descendant writeset/recovery chain that proved self-consistency but
had no canonical task/path/iteration candidate-set parent.

## Canonical reuse

The design retains the existing enforcement kernel, durable contract module,
mission/queue lifecycle, verifier separation, admission boundary, preservation
semantics, ownership checks, and Doctor/Start/Stop surfaces. The only admission
change is `Get-TsfSyntheticIterationAdmissionDecisionV2`, exported by the
existing `TsfDurableContract.psm1`; it validates the closed V2 candidate and
observed local Git state but grants no approval, push, merge, product, or
production authority.

The Builder adapter only proposes deterministic candidate content. The
canonical authority defines immutable per-task/path/iteration candidate
templates. Runtime derives `APPROVED_BUILDER_CANDIDATE_SET_V2` for the concrete
preauthorization and baseline commit/tree. A canonical writer validates an
`APPROVED_WRITESET_V2` against that record, creates immutable recovery evidence,
and performs the exact atomic replacement. The Builder has no arbitrary tool or
direct workspace-write surface.

The publication audit did not require another authority system. Its correction
strengthens this same extension: exact static-authority identity, pinned
executables and closed child environments, immutable admission bundles with
canonical cross-artifact validation, and a persisted recovery continuation
started in a new process. These are enforcement details inside the approved
canonical writer/admission boundary. The same systems are extended to rehash
pre/post-test bytes, raw staged blobs, and raw committed blobs. The postcommit
verifier envelope is a second phase of the existing verifier, not another
authority.

The post-crash acceptance correction also remains inside the existing
acceptance boundary. It does not make a dirty worktree safe or weaken Doctor.
An explicit working-candidate mode is fail-closed unless an external caller
binds the exact committed HEAD/tree/branch, empty index, allowed dirty paths,
and the exact SHA-256/length/kind inventory for every dirty file. The same
binding is recomputed after all checks. Doctor exit 4 is accepted only when
`worktree_cleanliness` is the sole `UNSAFE_TO_START` check and owner, listener,
and owned-child state are clean.

## Binding rule

Task 1 binds to the seeded baseline. Task 2 binds to the accepted Task 1 commit.
Task 3 binds to the accepted Task 2 commit. Corrections retain the task and
authorization identities but receive new iteration and run identities.

## Containment rule

Authority paths use exact, case-sensitive, forward-slash repository-relative
spelling. Backslashes are rejected, not normalized. Absolute, UNC, device, ADS,
wildcard, encoded, short-name, trailing-dot/space, traversal, `.git`, and
reparse escapes fail closed.
