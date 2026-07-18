# Real interruption and recovery proof

This document records pre-amend stabilization evidence only; final-candidate identities must come from the fresh detached proof worktree.

Two consecutive mission/revision proofs passed:

- `run-mrtgml7i-41164-8c988311`: 185 assertions, interrupted mission `hq2-mrtgncyd-f64e5e`, recovery `hq2-mrtgncyd-f64e5e-retry-d29637998530376a`, stdout SHA-256 `c15602a5156e8cb2a6ac81fc77e0e8ca59820e55d2d60d181f3a58c701e35083`.
- `run-mrtgqqth-23512-6126e595`: 185 assertions, interrupted mission `hq2-mrtgrdch-271ae9`, recovery `hq2-mrtgrdch-271ae9-retry-143d1b2b9cceade6`, stdout SHA-256 `f6751470f9279c847bbf46879233dd90e4e46822c9039aa6d36c8ade1f3264a5`.

After correcting the stale cached Stop-owner evidence in the proof harness, `run-mrtir77w-5748-9834719a` passed 186 assertions on its first invocation. It established exact executor/app-server ownership, reached the authoritative barrier, used a fresh exact owner binding, recorded causal cleanup with no unattributed target, persisted the Stop record, reconciled interruption without automatic rerun, created a distinct recovery mission/run, independently verified GREEN, preserved evidence, admitted with caveats, preserved the receipt, performed idempotent replay, and finalized with no owner, listener, or proof-owned child.

Key hashes: stdout `3253751802a7d58b0c16cd5ac5d9e64f7cbd9ff268560bf8ff34bded598a6657`; barrier `82f2b5533d8b42d7c1c5120b7be79b18fe55a90a1fa03f7bc01f3f81cf692926`; process ledger `d41fc6be138ab66a5542843e20078d45cf5ab929d3af7614e0ac55c16ef245f8`; verifier `67aa0f19d96094e6678587d3db580f2fce9a69497e2667ec539b135647ca8ceb`; recovery receipt `968a0abf6b9f06938430107a2b7a952c4d3e094824b0debc4b0e9c7829990993`; stderr was the empty SHA-256.

## Deep-recovery cycles 5 and 6

The first detached exact-candidate attempt, `run-mrtk9b5b-33500-93d7abc7`, remains a preserved failure. It stopped at `CHILD_COMPLETED_BEFORE_BARRIER` after `APP_SERVER_SPAWN_PARENT_IDENTITY_MISMATCH`; durable proof-result SHA-256 is `f2b24370840ce128af1b293c2ff6fa74adde9112309eca570fee2180a848464f`. Recovery manifest SHA-256 is `dc1937ee07825d52fb3270f58bd9a0c3545711c5525fbf9e11a44cc6cf1d55e3`. It is not final-candidate success evidence.

After authoritative spawn inspection was corrected, working-tree proof `run-mrtlvkr6-29824-611fdd54` reached the real barrier and recovery path but failed exact Stop authentication because the endpoint used a mutable whole-owner hash. It remains failed. Exact revalidation permitted cleanup of only proof-owned PID `38012`; no unattributed process was touched. Complete cycle-6 recovery manifest SHA-256 is `e1c5df19a824f3e67f0d6c8f57b1f0f7b57f5bc120979340966bb4e96a80412e`.

After the stable immutable Stop-authentication hash correction, `run-mrtmll55-12356-50d07496` passed 186 assertions on its first invocation. It interrupted mission `hq2-mrtmm5xl-ddbe9e`, recovered as `hq2-mrtmm5xl-ddbe9e-retry-4c63f2a9114a223e`, and classified the recovery exact-response evidence truthfully from the new revision. Verifier SHA-256 was `a1e7c195d73558c6339fd265f8e5e38c157a38e6b20b5a5828bf0e9a6ddfc0b6`; admission receipt SHA-256 was `f74e16ddc14d19adc914060ba6a8196753c2556b334c708b7a9f1ae84c8b1d1c`; recovery receipt SHA-256 was `dca8426ff1d4f5b8a770ebbf65baf27737a1ec8e4dc616b85d27a9e20b11b455`; barrier SHA-256 was `c9e824ff8b81b81df4baa7a16e1927c492b83801c3053c18f0be0f7de253214e`; process-ledger SHA-256 was `8ee501abfc4cd181a9fb245e02fb21034cbe6cf4b600f9442f96705084c96454`; durable proof-result SHA-256 was `0a79c2fe9b6aacec6f02a1ddaa1468e0147de5c070c658c6f283205d42a380bc`. Final cleanup found no owner, listener, or proof-owned process.

The complete cycle-6 pre-amend matrix passed 71 of 71 checks. Validation-summary SHA-256: `87f9680bdc85bb9f27ab163d8439ccaa29fdd58d57f52d1bfd49056d5c43371d`. These records are pre-amend evidence only; the fresh detached candidate must still pass two consecutive real proofs.
