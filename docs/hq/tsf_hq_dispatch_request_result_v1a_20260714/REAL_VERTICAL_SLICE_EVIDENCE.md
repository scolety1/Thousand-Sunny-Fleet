# Real Vertical-Slice Evidence

- UTC: `2026-07-14T23:55:22.2515533Z` through `2026-07-14T23:56:01.0601839Z`
- Command: `node .\tests\run-tsf-hq-dispatch-real-readonly-v1.mjs`
- Exit: `0`
- Outcome: `ADMITTED_WITH_CAVEATS`
- Submission ID: `NOT_RETAINED_BY_V1_RUNNER`; the runner retained the reviewed preview and all canonical mission bindings, and the authorized one-real-run limit prohibited a second mission solely to recover this presentation-only field
- Mission/revision: `hq2-mrlb70lk-dc5d7c` / `1`
- Run/result: `canonical-result-hq2-mrlb70lk-dc5d7c-1` / `canonical-result-hq2-mrlb70lk-dc5d7c-1`
- Mission SHA-256: `be7f2681eb2eab7fd9829b0a756d503829d10c9d0c7eedba6371a63a03d99666`
- Queue document SHA-256: `23c14691014a8d3dea64e32d9a671b45f2dee4c6c6080b0dffdfd0f281b0e1d0`
- Final queue state: `complete_ready_for_gate`
- Thread/turn: `019f630e-c474-75b1-8694-50add93653a0` / `019f630e-d96b-7e72-8485-637ca5d686f2`
- Model/effort: canonical alias `BALANCED`, resolved model `gpt-5.6-terra`; requested and canonical effort `MEDIUM`; the explicit turn request was acknowledged
- Worker verdict/final response: `GREEN` / `TSF_HQ_DISPATCH_READ_ONLY_GREEN`
- Verifier: `canonical-kernel-postrun`, verdict `GREEN`, identity SHA-256 `1c95c503cde82a3e3bc4c691b203335de65d490174e9264919dfd170f73c490e`
- Preservation packet/manifest identities: `cc9361376849de84b01b2f5520aed9570aeccaa3a6d911e009b1d4e64a509e2c` / `7aae30031e7bc257c3fb9c2b8df35b258df3f09027ee34d5b8cfe851cba0840e`
- Durable result identity: `86b12dd8b1d6fa7dfd9f5840bb1a93a542b4b7b4a98d9d5926a11342d0cda0a8`
- Admission receipt: `admission-bbzftxtpy4qf4fy4pdh3q7fc`
- Admission receipt identity/decision/file SHA-256: `087259de6fc7205e171c78cfb87ca2a560ec73520c1417fd028d454a2a241beb` / `add28c3f8335bfd061124e2f351a415cf657d846d592b18b5d0d7b9b6dbbf532` / `7665389c484bd6df469cd7ec93d1c4d6fa7a6067ecfe8123dc435492f46e89b6`
- Adapter instance/child: `76bd2252-5dea-4e2e-8bf2-1e6feb8d91b9` / PID `7396`
- Adapter/event-journal SHA-256: `c9eb64df82b46c62da8bb1f467a4e31b2289254c2026b55436e1b3b6c9f5c8dc` / `e5b4bb6df3c7505286c9b4087790f720b7df134b136d3c8c4a94e2dedd2f0dd3`
- Child cleanup: exited `true`; timed out `false`; orphan `false`; loopback listener `41737` absent after shutdown
- Control plane: `CODEX_SERVICE_ONLY`; worker-tool network `DISABLED`; direct/external worker API network `false`
- Files changed/created by the read-only worker: none
- Product repository/plugin/credential use: `false`
- Recorded stdout/stderr/combined SHA-256: `55b7ccc91aefdc9b3b393b56fc0744bc9815dcb594e8f97d5e21db736edcd992` / `a3639af5e23464fc391dae127fd5493f02c8178068a35866d9c7fdd35dcd623f` / `be6022d329b780a43b3f7e1690821fd1acc3530402c3473bf223c4d611ee3b87`

The caveats are evidence limitations, not an admission failure: effective effort was not exposed by the service and the service thread default was `xhigh`, while the explicit `MEDIUM` turn request was acknowledged. The real proof traversed HQ Dispatch submission, reviewed preview, canonical mission and queue, foreground executor, real Codex app-server worker, terminal result, verifier, preservation, admission, and final visible result/receipt.

## Deterministic canonical companion proof

- UTC: `2026-07-14T23:53:11.8193364Z` through `2026-07-14T23:53:34.7675718Z`
- Command: `node .\.codex-local\hq-dispatch\m2a-validation\run-deterministic-canonical-slice.mjs`
- Exit/assertions/outcome: `0` / `36` / `ADMITTED`
- Proof/submission/preview: `deterministic-360b004b-2b31-4b46-aefa-56e216b2e17d` / `hq-submission-627d1f71-3ed1-493e-983d-9a2fe3359dd7` / `hq-preview-e88a865613fa451a90309306e4b2891e`
- Mission/revision: `hq2-mrlb47w3-bfa3cf` / `1`
- Run/result: `canonical-result-hq2-mrlb47w3-bfa3cf-1` / `canonical-result-hq2-mrlb47w3-bfa3cf-1`
- Mission/queue SHA-256: `5014969685327fa4aa3a3a302c10af806bad4758bd2c7b1e2833745c0aef13ec` / `5d1eefd3011f7ab566514652847d90234569b894a7a95c5539c9136ec772f99d`
- Thread/turn: `thread-tsf-deterministic-m2a` / `turn-tsf-deterministic-m2a`
- Verifier: `canonical-kernel-postrun`, `GREEN`, SHA-256 `747da3548f680e3715bbc864cbd26643680c80bd2de415ebb3bd2e31c562e465`
- Preservation packet/manifest: `aca7e22b1ab62244e9948277396eef7a54bbb7f998c318c784c05f96864ae596` / `5e4f93716cddef57e5ef9299c7801c8558a1946b18b1eaad666abf8c2d8b6612`
- Admission receipt/identity/decision/file SHA-256: `admission-wnkkfjjbmqms2iuyqia32dqk` / `b354a2a52164192d22988201bd0e0a400cf18e025d9138586321fe6bdb38d9a7` / `915f61b4ddfdafa262664ff278d78b2097907513cf3e49d201e3069d219c989b` / `30fd5da4d47d403c5be841c1d82a82237007fcce137c5df527591768e57c25a9`
- Final queue/replay/authority/cleanup: `complete_ready_for_gate` / completed replay `true` / all denied / child exited and listener closed
- Recorded combined-output SHA-256: `6ca8e906dc419090a194b2ac518c0340fd8b1fadf52019ec5bbbcb33d682f07f`
