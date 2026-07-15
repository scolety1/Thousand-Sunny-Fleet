# Real Bounded Proof Evidence

One successful real proof used the actual loopback HQ server, current Milestone 2A operator session, canonical response writer, Project Main Bot revision preparation, foreground app-server adapter, canonical verifier, and durable admission. The initial clarification fixture intentionally ran without a worker; only revision 2 used the real app-server service.

- Command: `$env:TSF_NETWORK_MODE='CODEX_SERVICE_ONLY'; node tests/run-tsf-hq-dispatch-tim-relay-real-readonly-v1.mjs`
- Result: `PASS`, numeric exit `0`
- UTC window: `2026-07-16T00:00:26.0762830Z` to `2026-07-16T00:01:11.1854740Z`
- Stdout: 6622 bytes, SHA-256 `9870e6e8ed0df9af47069a8f512ab4af4ed89808654ff1706de5780db179f513`
- Stderr: 0 bytes, SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`
- Proof: `proof-a3ef758d-9e0e-4b3f-9520-f1b398c7f144`
- Submission: `hq-submission-43bcff96-067c-4d2c-8c27-13e0e47eb540`
- Mission: `hq2-mrmqtbv8-e54bb7`
- Original revision/run/result: `1` / `canonical-result-hq2-mrmqtbv8-e54bb7-1`
- Request: `timreq-33ee9f2902f3389c39b5da58442d6a7c`
- Request evidence SHA-256 before/after: `381668489a7784c7e42d919ad11f830bf937a23c0c35d52aebd3df7a9ca9d807` / identical
- Response: `hq-response-df9032e2-ee73-4ea2-abd2-c9f57152a291`
- Response-record SHA-256: `d03790afaf32e3601c5d1b812044fe531463a0a2427960926a6cc20398479310`
- Revised revision/run/result: `2` / `canonical-result-hq2-mrmqtbv8-e54bb7-2`
- Thread: `019f6839-dbc3-7580-be4a-29e6ebe25c09`
- Turn: `019f6839-f125-7af2-aa12-4c57c5c3d5e8`
- Queue document SHA-256: `3c1ad425b6977adc46a0cb671156a75c8286a2039915f78b1ef074a4a609c601`
- Durable result SHA-256: `dae1f9623d8087802c9c0c9c158582ebe9e286890e4ca8b54e19f8fc96bc64cc`
- Verifier: `GREEN`, result SHA-256 `1791a15fbe2d180cb7a2f0089a317ccb9faf643ec1a3afb02455158b663a3816`
- Admission: `ADMITTED_WITH_CAVEATS`, receipt `admission-jdnbh3zrnted66cbhl5nbocn`, receipt SHA-256 `1858cd55e9600b82f26985a5b441f9c064614c08a314c8051306aa4c744e1280`
- Exact expected/observed response SHA-256: `106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba` / identical

Observed boundaries: TSF-local fixture only; read-only access; `CODEX_SERVICE_ONLY` control plane; worker-tool network configured disabled; filesystem writes observed not used; plugins, credentials, product repository, push, merge, deployment, and production authority denied. The foreground child exited, no orphan remained, and the server listener was closed. The admission caveat correctly preserves `NOT_OBSERVED` limitations for protocol-level product/plugin/credential audit; no stronger claim is made.

Two earlier diagnostic attempts stopped before a service worker: the first used an invalid test fixture enum, and the second exposed that inactive-child flags live in canonical evidence rather than the UI projection. A provisional successful run then established the path but did not retain its stdout hash. The final published proof above repeated the same bounded path under an external hash-capture wrapper to correct that evidence-only defect. All runs created no approval, unsafe write, suspended-worker continuation, orphan, or persistent listener.
