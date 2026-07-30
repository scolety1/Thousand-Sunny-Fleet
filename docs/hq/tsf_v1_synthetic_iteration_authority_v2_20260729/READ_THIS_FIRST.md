# TSF V1 Synthetic Iteration Authority V2

This directory specifies and records a closed, test-only extension that permits
three bounded coding tasks in exactly one disposable synthetic repository:
`C:\TSF_SYNTHETIC_ITERATION_V2\fixture-repo`.

The extension does not replace, weaken, or supersede the V1 single-file
readiness packet. It adds no general automatic-approval authority. Each task is
preauthorized by an immutable template, bound to the exact predecessor
commit/tree, and limited to three Builder proposals. Every proposal must be an
exact member of a canonical task/path/iteration candidate set. Replacement
artifact bytes, temporary bytes, written bytes, pre/post-test bytes, staged Git
blob bytes, and committed Git blob bytes must all match that member.

The existing verifier and canonical admission extension independently recheck
the candidate set, writeset, byte proof, staged blob, committed blob, and
commit. Persisted recovery reloads canonical authority and cannot redefine a
candidate through a self-hash or a serialized `valid` field. Historical records
without this binding fail closed and remain preserved.

Synthetic remotes, pushes, product repositories, packages, plugins,
credentials, deployments, services, scheduled tasks, daemons, and persistent
workers remain prohibited.

Start with `ARCHITECTURAL_DECISION_RECORD.md`, then read
`APPROVED_BUILDER_CANDIDATE_SET_V2.md`,
`WRITESET_CANDIDATE_BINDING.md`,
`PERSISTED_RECOVERY_REHYDRATION.md`,
`BYTE_AND_GIT_BLOB_VERIFICATION.md`, and
`VERIFIER_AND_ADMISSION_BINDING.md`. Generated candidate facts appear in
`VALIDATION.json`; `SHA256SUMS.txt` is generated last.

## Post-crash validation state

The first broad working-tree acceptance evidence root, `synthetic-v2-candidate-
binding-working-acceptance-01`, is preserved as incomplete. It contains a
durable targeted-soak `final-doctor` failure caused by the intentionally dirty
candidate worktree and then ends abruptly during the M3 canonical regression
without an acceptance summary or numeric wrapper exit. It is not GREEN.

The localized acceptance-harness correction retains Doctor's normal fail-closed
behavior and permits a dirty candidate only when an external caller supplies
the exact HEAD, tree, branch, empty-index state, allowed dirty-path set, and a
SHA-256 binding over every dirty path and byte. That binding must remain exact
through final cleanup. The fresh `synthetic-v2-candidate-binding-working-
acceptance-02` run completed with numeric exit 0, 37/37 checks PASS, 1,275
criteria/assertions, and zero failed checks.

This is working-tree evidence only. Publication still requires a new detached,
clean proof of the amended candidate, a fresh exact-candidate pilot and full
acceptance, correction-02 packet verification, and fresh independent GREEN
Tester and Auditor reviews.
