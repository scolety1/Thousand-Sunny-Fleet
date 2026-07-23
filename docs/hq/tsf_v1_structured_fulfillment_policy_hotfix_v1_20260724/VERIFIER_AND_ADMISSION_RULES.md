# Verifier and Admission Rules

The canonical evidence mapper and admission verifier independently derive the result from the mission-bound task-completion contract.

Generic structural-only results:

- validate against the closed general-result schema using `STRUCTURAL_TEXT_ONLY_V2`;
- verifier fulfillment is not GREEN;
- semantic status is `NOT_FULFILLED`;
- admission evidence is invalid;
- no success receipt is created.

Structured analytical results admit only if:

1. transport succeeds;
2. the V2 worker claim is closed;
3. mission, revision, run, task, intent, and scope identities match;
4. worker status is internally consistent;
5. every deliverable satisfies its declared type, cardinality, structure, and evidence requirements;
6. completed and missing lists exactly partition the required IDs;
7. the canonical result agrees with independent recomputation;
8. verifier, preservation, queue, policy, and admission gates pass.

Wrong-task, cross-mission, cross-revision, cross-run, missing-deliverable, contradictory, caller-authority, and result-contract substitution cases fail closed.

The canonical postrun verifier must reproduce generic evidence without a self-schema error. Its rejection basis is the structural-only non-admission policy, never a schema incompatibility.
