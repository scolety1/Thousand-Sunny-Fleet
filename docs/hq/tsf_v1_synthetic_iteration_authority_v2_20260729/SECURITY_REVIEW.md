# Security Review

The implementation treats Builder output as an untrusted patch proposal.
Authority is derived from the checked-in closed record, never from the Builder,
caller, test fixture, or recovery request. The canonical writer and admission
extension independently revalidate identity, path, Git, test, verifier, and
authority relationships.

Primary abuse cases and controls:

- path alias/escape: strict grammar, exact allowlist, canonical containment,
  realpath/reparse inspection;
- command injection: shell-free launch, exact executable and token templates;
- replay/substitution: content identities, task/run/baseline binding, distinct
  correction and recovery identities;
- false success: visible plus acceptance tests and separate verifier evidence;
- premature/extra commit: exact staged path inspection and single-use authority;
- recovery widening: pre-write immutable envelope and exact hash dispositions;
- authority laundering: admission grants all authority flags as false;
- network/product impact: zero-remotes invariant and static prohibitions.

## Final audit correction

A fresh publication audit correctly blocked the earlier candidate. The
localized correction closes every reported high-severity issue:

- caller self-hash trust is removed by an exact static-authority digest and
  canonical recomputation of every admission artifact identity;
- admission consumes a path-bound immutable bundle containing exact artifact
  file hashes and rejects replay, cross-run evidence, forged valid SHA values,
  stale commits, and shape-compatible GREEN substitutions;
- Node and Git are absolute-path and file-hash pinned, and spawned processes
  use a closed environment rather than inheriting `process.env`;
- Task 1 interruption is a real writer-process exit followed by a separate
  persisted-state recovery process, not an after-write check in the same
  process;
- the final review packet generator requires detached, clean, exact-candidate
  acceptance evidence and writes an identity-bound `correction-01` packet,
  while retaining the stale parent packet as historical evidence.

Focused and adversarial tests include exact-authority mutation, registration
key substitution, valid-SHA writeset substitution, executable/environment
containment, and recovery cross-link rejection. The real working-tree replay
`working-tree-candidate-04c` completed all three admissions and three commits
with Task 1 terminated and resumed across separate processes and canonical
Node/Git subprocesses running under the closed PowerShell environment.

The design deliberately does not claim OS-level proof of network non-use beyond
the closed executable/environment/command surface and zero-remotes checks. That
limitation is recorded as a nonblocking evidence caveat, not represented as
stronger fact.

## Persisted candidate-binding correction

A subsequent fresh Tester and Auditor correctly found that a coherently
reidentified writeset and recovery record could substitute a SHA outside the
task-wide Builder list. The earlier GREEN pilot proved deterministic behavior,
not recovery authorization safety.

The correction remains inside the existing V2 systems:

- canonical authority now defines exact task/path/iteration candidate
  templates with SHA-256, byte length, provenance, and generation identity;
- runtime derives a baseline- and preauthorization-bound candidate-set record;
- writeset and recovery validation require exact membership in that canonical
  set;
- persisted candidate sets are compared with independently reconstructed
  authority and cannot redefine it;
- replacement, temporary, written, pre/post-test, pre-stage, staged,
  pre-commit, committed, and postcommit bytes are rehashed;
- raw Git staged and committed blobs and modes are recorded;
- the existing verifier emits linked precommit and postcommit phases;
- canonical admission requires all candidate-set, writeset, byte, and blob
  artifacts and independently rereads the committed blob.

Focused tests passed 25/25. The working pilot
`candidate-binding-working-01` completed task iterations 1/2/2, three
admissions, three local commits, fresh-process recovery, and zero remotes or
pushes. Its manifest SHA-256 is
`0dcafea7617c6bc376a5d5aa041c35a14f828adf3b87772c1714db3c201c1864`.

Correction-01 is preserved but is not publication-authoritative.
Correction-02 supersedes it only for candidate-binding and recovery safety.

## Post-crash acceptance integrity

The interrupted acceptance root remains unchanged and is not represented as
GREEN. It contains a genuine localized targeted-soak failure: the ordinary
Doctor returned exit 4 because the candidate correction was intentionally
uncommitted. The run later ended abruptly during M3 canonical regression due to
the PC crash and produced neither an acceptance summary nor a numeric wrapper
exit.

The localized harness correction consumes the second of eight authorized
correction cycles. It does not weaken Doctor. Dirty working-candidate acceptance
requires an external exact HEAD/tree/branch, an empty index, an allowed dirty
scope, and a digest over the status plus SHA-256, length, and kind of every
dirty path. The digest is checked before and after all tests. Doctor exit 4 is
conditionally accepted only when live runtime ownership is clean and
`worktree_cleanliness` is the sole unsafe start condition.

The fresh acceptance-02 result is PASS with numeric exit 0, 37 checks, 1,275
criteria/assertions, zero failed checks, and an unchanged dirty binding. Its
canonical final cleanup reports owner absent, listeners 0, and owned children
0. A wrapper-only observer false positive is preserved in the original receipt
and resolved by a separate append-only reconciliation; neither historical
receipt was rewritten.
