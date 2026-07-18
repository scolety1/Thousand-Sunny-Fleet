# Optional exact-response recovery proof

## Root cause

The real interruption barrier reached `READY_CLEANED`, proved the exact owned app-server process was stopped, and left no owner or listener. The recovery mission was then canonically re-prepared without an exact-response contract. Its mission, mission packet, worker instruction, result, and verifier truthfully contained no exact-response requirement or evidence. The proof nevertheless dereferenced `recoveryVerifier.exact_response_evidence.mission_revision` unconditionally. That invalid universal assumption caused the TypeError at the former line 555; the production records were correct.

The original managed-wrapper failure is preserved beneath `.codex-local/recovery/optional-exact-response-proof-fix/20260718T190648477Z-pre-edit`. Its numeric exit was not reliably observed and is recorded as `EXIT_NOT_RELIABLY_OBSERVED`. The blocker JSON SHA-256 is `2e9e7819b6cf93a240e049ac5cf74f9cf795b2a21ebc3fe8e02d267de2b01574`, stderr SHA-256 is `ab0392ecf5b1dba2ef6b98bdb96a0e049c12712039f39bb26e25993871feaeae`, barrier-ready SHA-256 is `57ccbab83dfadb0bd54c62c97b06700f2ee78ee93458d34a452796823d6f3097`, and barrier-diagnostic SHA-256 is `cca815be66f39403c40ea620423d4c17b69cc590f162251b088834cd65c7255e`.

## Corrected invariant

For `EXACT_LITERAL_V1`, the proof requires equal contracts at every canonical boundary, recomputes expected and observed hashes, binds mission/revision/run/result identities, requires verifier exact evidence and independent GREEN, and validates admission. Missing, substituted, stale, cross-run, wrong-revision, wrong-hash, normalization, case, or whitespace evidence fails closed.

For a recovery revision with no exact-response contract, the proof requires null/absence at every upstream and downstream boundary, rejects a default M2A literal, still binds the ordinary worker/verifier/admission mission/revision/run/result identities, and rejects fabricated or stale exact evidence. Proof output uses `NOT_APPLICABLE_NO_EXACT_RESPONSE_CONTRACT`; this is a test-evidence classification, not a production mission state.

## Adversarial and real proof results

`node tests/test-tsf-hq-dispatch-recovery-result-contract-proof-v1.mjs` passed 36 adversarial cases: 90 exact-mode invariant assertions and 66 no-exact-contract and artifact-binding invariant assertions. Stdout SHA-256 is `7696ca896d8ee8014898447b10aad82fb0a95fa17ea20510de87a9071a132517`; the cycle-4 focused summary SHA-256 is `aadf37c9133fadb303cb75b357d3a7a1c1b328cb2f0da79bcc25b26551578cdf`.

Two consecutive artifact-aware working-tree proofs passed:

- `run-mrtgml7i-41164-8c988311`: mission `hq2-mrtgncyd-f64e5e`, recovery `hq2-mrtgncyd-f64e5e-retry-d29637998530376a`, disposition `NOT_APPLICABLE_NO_EXACT_RESPONSE_CONTRACT`, 185 assertions, stdout SHA-256 `c15602a5156e8cb2a6ac81fc77e0e8ca59820e55d2d60d181f3a58c701e35083`.
- `run-mrtgqqth-23512-6126e595`: mission `hq2-mrtgrdch-271ae9`, recovery `hq2-mrtgrdch-271ae9-retry-143d1b2b9cceade6`, disposition `NOT_APPLICABLE_NO_EXACT_RESPONSE_CONTRACT`, 185 assertions, stdout SHA-256 `f6751470f9279c847bbf46879233dd90e4e46822c9039aa6d36c8ade1f3264a5`.

Both ended with no owner, listener, or proof-owned process. A later 186-assertion focused proof (`run-mrtir77w-5748-9834719a`) also passed after fresh exact Stop-owner evidence validation; its stdout SHA-256 is `3253751802a7d58b0c16cd5ac5d9e64f7cbd9ff268560bf8ff34bded598a6657`. Final-candidate proof identities must be generated separately from the detached amended candidate and are not preclaimed here.
