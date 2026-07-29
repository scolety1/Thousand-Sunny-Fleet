# Authority and Threat Model

## Authority

The only automatic action is the closed program
`tsf-v1-synthetic-iteration-authority-v2-20260729`, action
`tsf_synthetic_workspace_iteration_v2`, before
`2026-07-31T23:59:59Z`. It covers three named tasks, thirteen fixture files,
thirteen command templates, three Builder attempts per task, one accepted
commit per task, and one active write mission.

The original advance-reviewed authorization is bound by SHA-256 in the static
authority record. The later Git/GitHub exception applies only to canonical
Phase 0 reads and Phase 16 publication; it never authorizes synthetic network,
remote creation, or push.

The complete static authority is accepted only at canonical SHA-256
`1721d6f9ac4380c22b8bad2d753432978d55f35f2f2cbcb1c9c9cce362471222`.
Shape-compatible changes to expiry, provenance, repository identity, paths,
transitions, commands, Builder candidates, or executable identities are not
authority. The approved Node and Git executables are absolute paths with
checked file hashes; runtime process creation does not resolve them through
`PATH`.

## Assets and adversaries

Protected assets are the canonical TSF repository, all product repositories,
the V1 readiness packets, Git metadata, credentials, host processes, and the
truthfulness of evidence. Adversarial inputs include path aliases, reparse
points, command-token injection, replay under a reused identity, result
substitution, stale baselines, widened task templates, forged verifier evidence,
premature commits, recovery replay, candidate-set substitution, self-signed
writeset authority, staged/committed blob substitution, TOCTOU mutation, and
iteration-budget escalation.

## Security invariants

- Only the exact fixture root may be seeded or modified.
- The fixture has no remote and synthetic Git never performs network I/O.
- Every write is an exact allowlisted source replacement.
- Each deterministic Builder candidate is pinned by content hash and byte
  length for one exact task, path, and iteration. Runtime binds it to the
  concrete preauthorization and baseline commit/tree.
- Child processes receive a closed environment with an empty `PATH`, fixed
  platform directories, disabled Git prompting/global configuration/hooks, and
  no inherited credential-like variables.
- Actual replacement bytes are hashed before and after mutation and around
  every test command. Tests cannot authorize an unapproved candidate.
- The precommit verifier must be GREEN before commit authority exists.
- Commit authority verifies raw staged bytes and mode; the postcommit verifier
  verifies raw committed bytes and mode.
- Commit authority is single-use, non-amend, non-push, and exact-subject.
- Failed iterations and patches remain immutable.
- Recovery is bound to the exact preimage, replacement, writeset, task, branch,
  baseline, registration, authorization, iteration, and run identity.
- Admission reloads an immutable bundle, reconstructs canonical candidate
  membership, verifies each artifact's file hash and self-identity, checks all
  cross-artifact relationships, and reads the exact committed blob with the
  pinned executable. Caller-provided hashes, persisted validity flags, or a
  shape-compatible GREEN verifier are insufficient.
- Admission is single-consumption, cannot grant authority, and cannot
  substitute for merge approval.
- Working-tree acceptance cannot authorize source. Its explicit dirty-candidate
  mode requires an external exact HEAD/tree/branch and full dirty-byte binding,
  an empty index, allowed paths only, and unchanged binding through final
  cleanup. The default clean-candidate behavior remains unchanged.
- Product access, credentials, plugins, installations, deployment, services,
  persistent processes, and unattributed-process termination are prohibited.
