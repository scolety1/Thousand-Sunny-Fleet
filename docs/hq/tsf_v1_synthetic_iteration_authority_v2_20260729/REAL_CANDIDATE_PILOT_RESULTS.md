# Real Candidate Pilot Results

## Working-tree candidate

Run `candidate-binding-working-01` completed GREEN against the persisted
Builder-candidate binding correction.

| Task | Bound baseline | Iterations | Result | Commit |
|---|---|---:|---|---|
| `synthetic-path-containment-v2` | `59765f4282fd0a8b0af2480b2f1b0c1aab26dcb5` | 1 | writer exit 86; canonical recovery; candidate/staged/committed SHA `88095e8a…7765`; admitted | `35baf9a5004b18e61ee0d4d437d4fbe08b58796c` |
| `synthetic-idempotency-replay-v2` | `35baf9a5004b18e61ee0d4d437d4fbe08b58796c` | 2 | iteration 1 acceptance-rejected; iteration 2 candidate/staged/committed SHA `e970edb4…6778`; admitted | `11824f6484330c5788b6deb730cf49a9e5daae1a` |
| `synthetic-result-identity-v2` | `11824f6484330c5788b6deb730cf49a9e5daae1a` | 2 | iteration 1 acceptance-rejected; iteration 2 candidate/staged/committed SHA `5294ac5c…77b9`; admitted | `5832ae20821924f37d7a826e2f395c41f1daf736` |

Final fixture tree:
`606e0c2c9b06f089fa20d8092ae1fe29203f8094`.

Evidence manifest SHA-256:
`0dcafea7617c6bc376a5d5aa041c35a14f828adf3b87772c1714db3c201c1864`.

The fixture ended clean with four total commits (one setup plus three tasks),
zero remotes, and no push. Its manifest contains 76 entries and passed a
76/76 file-hash and byte-count self-check.

The exact coherent all-`a` recovery attack was then replayed from a preserved
evidence copy. It rejected before mutation or test execution as
`REPLACEMENT_SHA_NOT_IN_APPROVED_BUILDER_CANDIDATE_SET`; the target hash and
mtime, fixture HEAD, and clean status were unchanged. A historical recovery
record without candidate-set binding rejected as
`RECOVERY_CANONICAL_CANDIDATE_BINDING_ABSENT`. Persisted `valid` and `verified`
fields were ignored while the canonical candidate set was reloaded.

## Post-crash working-tree acceptance

The first broad run at `synthetic-v2-candidate-binding-working-acceptance-01`
is immutable incomplete evidence. It recorded one targeted-soak failure when
the ordinary Doctor correctly rejected the intentionally dirty worktree, then
the PC crash ended the later M3 canonical regression before any summary or
numeric wrapper exit. It is not a failed full acceptance and is not GREEN.

The corrected harness retained the normal Doctor policy and added an explicit
external binding over the exact committed identity and all dirty bytes. The
fresh run at `synthetic-v2-candidate-binding-working-acceptance-02` completed:

- numeric exit: 0;
- checks: 37/37 PASS;
- criteria/assertions: 1,275;
- failed checks: 0;
- dirty binding unchanged:
  `83e751d33b915c34c4c3f79f9862cd48d18c20b99b1266bae0160111c5bbab56`;
- acceptance summary SHA-256:
  `a7cbf0ecbf951234aff374c10f314d3f344b975ab518cba850b22ca10015c735`;
- evidence-index SHA-256:
  `0524120d6150cecdb5efd88dd2164e827838cd362e8d0536940a84f27eb3967f`;
- final owner/listener/owned-child counts: absent/0/0.

The wrapper truthfully retained a false cleanup flag because it observed the
read-only poll command whose command line named the evidence path. That process
ended naturally. The separate append-only reconciliation at
`synthetic-v2-candidate-binding-working-acceptance-02-post-run-
reconciliation-02` passed with result SHA-256
`956f9efdfb3eb1b148760dd24c37e6791b86ac1f6d82c57b3adeb505fa193013`.

Earlier detached proofs remain immutable historical evidence but do not qualify
the candidate-binding correction. A new detached, clean exact-candidate proof
must be created only after the single candidate is amended.
