# Exact Result Evidence — Vertical-Slice Proofs

## Real read-only app-server proof

- UTC: `2026-07-15T18:33:50.4807899Z` through `2026-07-15T18:34:35.9109341Z`
- Command: `node .\tests\run-tsf-hq-dispatch-real-readonly-v1.mjs`
- Exit/HTTP/outcome: `0` / `200` / `ADMITTED_WITH_CAVEATS`
- Submission: `hq-submission-b7bf111a-5c1a-4324-90e6-27d2eb8657b3`
- Mission/revision: `hq2-mrmf5exo-4ee60b` / `1`
- Run/result: `canonical-result-hq2-mrmf5exo-4ee60b-1` / `canonical-result-hq2-mrmf5exo-4ee60b-1`
- Thread/turn: `019f670e-de5f-7bc0-8d99-fa0b37c62fda` / `019f670e-f2df-7bf3-ae68-f522757bb067`
- Mission/queue/durable SHA-256: `ec8f5ccaa6e78ecd223d62c889012436ea9d7a5d636b3fa78a93d4e88ff9311c` / `be88d5ffc8f6a9270386ab3d8ab3ee88634a407667a66e369dd3023fcf3285ec` / `9ccaac651d549fe01ecb00d5c1c6c56d1c88f00c009dc626ec7cd99804e7486a`
- Required/observed response SHA-256: `106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba` / `106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba`
- Worker exact match / verifier exact match / independently recomputed: `true` / `true` / `true`
- Worker/verifier: `CODEX_APP_SERVER_WORKER_GREEN` / `GREEN`
- Verifier/preservation packet/manifest SHA-256: `6a2e93a9258970fdc2ef66f0f179c92297b9513795f0d9e3bd7406c22d4e6f7f` / `2450563b996781ca9155e62b9cb8f7e7edd8bb57f752e209127b361ce7d75865` / `25b6f54d36726aa4fa81809bc6eb9ad6797f15b9be99dc13ba73b169768c03ac`
- Admission receipt: `admission-pdok2ipkyhywevhgibqumlma`
- Receipt identity/decision/file SHA-256: `78dcad21eac1f16254e64061462d80085b0c4cb9385a4c86e195efbcc5f4b8bf` / `355fa4f63ff876a10060e290272db2ba1075b69ab74b7134bc256c0cab294c0e` / `d6ac2f2633c40716d6b5af0e6a7aef2ac7bfa2cfb731676a86e692235ef347ca`
- Cleanup: owned child exited `true`; detached/unowned child `OBSERVED_NOT_USED`; listener remaining `OBSERVED_NOT_USED`; one terminal queue record
- Worker filesystem writes: `OBSERVED_NOT_USED`
- Product repository/plugin/credential/external-network runtime use: `NOT_OBSERVED`, value `null`
- Worker-tool network: `CONFIGURED_DISABLED`, value `false`
- Recorded stdout/stderr/combined SHA-256: `9860c3eace405df561f2bc7b26fc3f59ffceeeb27c1d23277cc6df7c85d3dd3c` / `a3639af5e23464fc391dae127fd5493f02c8178068a35866d9c7fdd35dcd623f` / `d4b95289f7f700e7ccc2714317768c1358c9d76e2d504809a21a77a844e721be`
- Written-path inventory SHA-256/count: `c7468aec7241cb0cfcc8bfeca590bc650fa193d1105597dd7ca765f1e0814111` / `49`
- Raw record: `.codex-local/hq-dispatch/m2a-validation/commands/correction-real-readonly/`

The caveat is evidence truth, not an exact-response failure: runtime non-use is not asserted where the app-server protocol provides no authoritative audit.

## Deterministic canonical companion proof

- UTC: `2026-07-15T18:34:52.8839659Z` through `2026-07-15T18:35:21.1516323Z`
- Command: `node .\.codex-local\hq-dispatch\m2a-validation\run-deterministic-canonical-slice.mjs`
- Exit/assertions/outcome: `0` / `59` / `ADMITTED_WITH_CAVEATS`
- Proof/submission/preview: `deterministic-d5402815-728b-43c9-bb1a-6506d48a4a6b` / `hq-submission-580738af-7105-46b7-8b08-0a588f70ce08` / `hq-preview-b6c0583afdaa41fea9a0be2a4bbab31c`
- Mission/revision: `hq2-mrmf6qx4-5c6a90` / `1`
- Run/result: `canonical-result-hq2-mrmf6qx4-5c6a90-1` / `canonical-result-hq2-mrmf6qx4-5c6a90-1`
- Mission/queue SHA-256: `5b413c9455d3cdba6d897698079ce8be2cc1675a77c6cd2a104dd441705e9511` / `2ff18f066866cfc47ede076e8fcd9682373b5202157c70907dd145e7a7ce9a07`
- Thread/turn: `thread-tsf-deterministic-m2a` / `turn-tsf-deterministic-m2a`
- Required/observed response SHA-256: `106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba` / `106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba`
- Worker exact match / verifier exact match / independently recomputed: `true` / `true` / `true`
- Verifier/preservation packet/manifest SHA-256: `f35601790f88ff5e9569604dbc8cb32ea5d66b878fb901151bdd9f009fe08aed` / `617858e48275fc5c0d42d2f0c23438b871ac13ba52bc664daa6b5abdf1e60488` / `880973859c38e2bf75acd74707fbd2ffcc05a09085bf41cf57bec866524d46f4`
- Admission receipt/identity/decision/file SHA-256: `admission-itxbbsfsnjzpugkiri5f2oyz` / `44ee10c8b26a72fa19488a3a5d3b19edafcf5ee1dd04e36ee53f66c9d8e7b29b` / `040899ee7de7d6f1a442e10b3b8e585fb578e2899f21c5f8386bd9e8590b52c4` / `d70e9876567430beb4faab12e744402861743c810d2440cb242a5641a0bd4c97`
- Final queue/replay/authority/cleanup: `complete_ready_for_gate` / identical replay reused terminal result / all elevated authority denied / child exited and listener closed
- Recorded stdout/stderr/combined SHA-256: `2117677a66515e84e13d9b728fe9e18ec749cbda5cb0b6e32c546a84f82fbcdd` / `a3639af5e23464fc391dae127fd5493f02c8178068a35866d9c7fdd35dcd623f` / `67402e77384330cc23d5aae276075a9c88129ff17918f53cbe19d4be554b1400`
- Written-path inventory SHA-256/count: `7e885a3fc31424acb64214b426d5ae5842a31d6c1917cc34d040a2d1ff0e8651` / `51`
- Raw record: `.codex-local/hq-dispatch/m2a-validation/commands/correction-deterministic/`

Both recorded runs began and ended with the same clean validation-mirror candidate identity `e28bffdcbf7983725dfd61ecd38a308505299d9f822323a5b2f26cc001c971e8`; the tracked patch was empty and the candidate identity was unchanged by each run. The disposable mirror commit was validation-only and is not part of the target branch history.
