# Interruption and Recovery V2

Before every replacement, `SYNTHETIC_WRITE_RECOVERY_STATE_V2` records the exact
task, repository, branch, predecessor commit, registration, binding, writeset,
iteration, original run, distinct recovery run, preimage, expected replacement,
and allowed disposition. It is immutable and written before mutation.

The pilot deliberately interrupts Task 1 in a dedicated writer process after
the approved atomic replacement and before tests. That process exits with the
test-only interruption code `86`; no in-memory continuation state is used. A
separate process reloads the persisted registration, preauthorization, binding,
writeset, preimage, replacement, and recovery state from disk. Recovery
revalidates their self-identities and cross-links, registration file hashes,
branch, baseline, budget, command surface, exact file state, and zero remotes.
It emits one single-use recovery receipt under the distinct recovery run
identity.

Only after the recovery process completes does the normal continuation run
focused and acceptance tests, create separate verifier evidence, consume
single-use commit authority, commit, construct the immutable admission bundle,
and request canonical admission. Recovery itself does not silently test,
commit, or admit.

Recovery may only complete the exact approved replacement or restore the
recorded pre-iteration bytes. Changed-resume, widened scope, exhausted budget,
ambiguous state, automatic rerun, and automatic admission fail closed.

The failed `working-tree-candidate-04` evidence is preserved: canonical
admission rejected a Windows PowerShell UTF-8 decode mismatch and singleton
path-set scalarization. `working-tree-candidate-04b` proves those corrections;
`working-tree-candidate-04c` additionally proves the closed PowerShell child
environment end to end without weakening either check.
