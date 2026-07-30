# Adversarial Recovery Results

Working-tree correction evidence was observed on 2026-07-29.

| Probe | Required boundary | Observed result |
|---|---|---|
| all-`a` replacement with coherent writeset/recovery reidentity | before mutation or tests | `REPLACEMENT_SHA_NOT_IN_APPROVED_BUILDER_CANDIDATE_SET`; target hash, mtime, fixture HEAD, and status unchanged |
| persisted candidate-set replacement | canonical reconstruction | rejected; persisted data cannot redefine authority |
| cross-task candidate | candidate-set validation | rejected |
| cross-path candidate | candidate-set validation | rejected |
| iteration-1 candidate reused in iteration 2 | writeset construction | rejected |
| claimed approved SHA with different bytes | artifact byte validation | rejected |
| temporary/post-write/pre-test/post-test mismatch | next boundary | rejected |
| staged or committed blob mismatch | before commit/admission | rejected |
| missing canonical candidate evidence | writeset validation | rejected |
| duplicate JSON member | recovery parse | rejected |
| historical V2 record without candidate-set binding | before recovery lock/mutation | `RECOVERY_CANONICAL_CANDIDATE_BINDING_ABSENT` |
| persisted `valid=true`, `verified=false` | canonical recovery load | ignored; flags absent from rehydrated record |
| exact approved candidate | full pipeline | admitted |

The preserved coherent all-`a` attack copy is:
`C:\TSF_SYNTHETIC_ITERATION_V2\evidence\candidate-binding-all-a-reidentity-01`.

The source file remained at approved SHA-256
`88095e8a37ba3230b8e1c756b30613728e246ce2cac4f53c228f5c08b1fe7765`,
and the synthetic repository remained clean at
`5832ae20821924f37d7a826e2f395c41f1daf736`.
