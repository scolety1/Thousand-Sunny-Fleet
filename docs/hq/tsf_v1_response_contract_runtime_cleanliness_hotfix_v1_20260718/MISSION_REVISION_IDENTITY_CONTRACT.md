# Mission/revision identity contract

## Architecture result

The independent read-only architecture review classified the preserved blocker as `HARNESS_INVALIDLY_REQUIRES_REVISION_IN_RAW_WORKER_RESULT`. The report SHA-256 is `33c32053ea19ade534cf198e1f79148ba1cb86b927a9d7c9dfaa57bff7fd4c72`.

The raw V1 worker-result payload is non-authoritative. It must identify the mission and may intentionally omit root `mission_revision`, `run_id`, and `result_id`; those omissions are classified as `NOT_PRESENT_IN_NONAUTHORITATIVE_WORKER_PAYLOAD` and `RUN_ID_REPRESENTED_BY_CANONICAL_RESULT_ID`, not filled with invented worker claims.

The authoritative binding chain is the canonical mission and queue record, executor invocation, worker-bound adapter result, producer registry, lifecycle wrapper, verifier, preservation manifest, durable canonical result, and admission record. Those artifacts bind mission ID, revision, run/result identity, queue hashes, repository/worktree identity where applicable, worker and adapter hashes, verifier identity, and result-contract mode. The preserved adapter copy must be byte-identical to the worker-bound adapter artifact even when the two canonical paths differ.

No verifier or admission decision derives revision solely from mission ID or caller-controlled natural-language content. Revision-1 evidence cannot satisfy revision 2; the same literal, same mission ID, stale run, changed filename, caller-supplied revision, or replayed result does not weaken that rule. Supported V1 raw payloads retain their intentionally narrow schema; unsupported schema versions fail closed.

## Validation

`node tests/test-tsf-hq-dispatch-recovery-result-contract-proof-v1.mjs` passed 36 adversarial cases with 90 exact-mode and 66 general/artifact-binding invariants. Stdout SHA-256 is `7696ca896d8ee8014898447b10aad82fb0a95fa17ea20510de87a9071a132517`.

Two consecutive real proofs then passed with distinct fixtures `run-mrtgml7i-41164-8c988311` and `run-mrtgqqth-23512-6126e595`; each exercised canonical recovery preparation, a distinct recovery mission/run, artifact-aware revision binding, verifier GREEN, preservation, admission, receipt, and cleanup. The later fresh-owner Stop proof `run-mrtir77w-5748-9834719a` passed 186 assertions and 72 recovery result-contract assertions.
