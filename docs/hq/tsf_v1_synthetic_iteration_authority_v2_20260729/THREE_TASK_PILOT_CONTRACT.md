# Three-Task Pilot Contract

The fixture contains exactly thirteen files and no remote. The local history is
one setup commit followed by exactly three accepted task commits.

1. `synthetic-path-containment-v2` changes only
   `src/path-containment.mjs`, proves mixed-separator and parent traversal
   containment, and exercises interrupted-write recovery.
2. `synthetic-idempotency-replay-v2` changes only
   `src/job-admission.mjs`. Its first proposal must pass visible focused tests
   but fail the independent changed-content replay invariant. The rejected patch
   and diagnosis are preserved; the second proposal must pass and commit.
3. `synthetic-result-identity-v2` changes only
   `src/result-parser.mjs`. Its first correction must fail duplicate-member
   acceptance, remain preserved, and be followed by a successful bounded
   correction and commit.

Every task requires its exact chained baseline, fresh run identities, complete
immutable evidence, focused and acceptance tests, independent verifier GREEN,
canonical admission, and one local exact-subject commit. No task may widen
scope, create a remote, push, or access a product repository.
