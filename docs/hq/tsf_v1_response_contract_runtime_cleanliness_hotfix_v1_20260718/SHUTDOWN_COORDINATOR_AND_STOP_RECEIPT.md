# Shutdown coordinator and Stop receipt

All accepted shutdown causes converge on the existing idempotent awaited coordinator. It blocks submissions, snapshots the active mission and owned registry, requests cooperative Stop, performs bounded exact cleanup, records one terminal disposition per owned process, flushes the action ledger, persists `STOP_RECORD.json`, finalizes `READY_CLEANED`, archives owner evidence, removes the live owner, invalidates the session, closes the listener, finalizes the response, and only then permits server exit.

The authoritative interrupted-mission identity is the immutable canonical Stop record. A successful response may truthfully return `accepted.active_mission=null` after cleanup, but null is accepted only when owner/listener/owned children are absent and the Stop record binds the exact pre-Stop mission, revision, run/result, server instance, request identity, and cleanup outcome. Completion before Stop is not relabeled interruption.

## Fresh exact Stop evidence

Preserved failed proof `run-mrti1uip-34568-c6b70f96` exposed a harness race. The harness cached the barrier-ready owner snapshot; the immutable registry recorded a terminal disposition at `2026-07-20T17:30:35.229Z`; the Stop request then reused the cached evidence at `17:30:35.400Z` and received `403 EXACT_OWNER_STOP_AUTHENTICATION_FAILED`. A fresh failure-cleanup read authenticated and entered the production coordinator, proving the production authentication contract remained closed.

The harness now refreshes the existing owner authority immediately before Stop and verifies that mutable `evidence_hash` changes do not alter server instance, PID/start time, listener, mission/revision/run/result, token hash, or required proof-owned process identities. It never retries with weakened evidence. The 51-assertion adversarial Stop suite passed with stdout SHA-256 `f4cc79d7f3fffc072e8e53a6e166048322bf82bfb1414d45a87aecbc1eb5a1a7`.

The first post-correction real proof, `run-mrtir77w-5748-9834719a`, passed 186 assertions on one invocation. It preserved interrupted mission `hq2-mrtirorg-5803a5`, recovered as `hq2-mrtirorg-5803a5-retry-01f37b436e22f6bc`, admitted honestly, preserved receipt SHA-256 `968a0abf6b9f06938430107a2b7a952c4d3e094824b0debc4b0e9c7829990993`, and ended with no owner, listener, or proof-owned process.

## Stable Stop authentication identity

Preserved proof `run-mrtlvkr6-29824-611fdd54` exposed a production authentication race after authoritative spawn inspection was corrected. The Stop endpoint compared the request to the mutable whole-owner `evidence_hash`; owned-process registry and action-ledger updates changed that hash between an exact owner read and the request, producing `403 EXACT_OWNER_STOP_AUTHENTICATION_FAILED` even though server instance, PID/start time, executable, listener, session generation, and capability hash were unchanged. This is classified as `MUTABLE_OWNER_HASH_USED_AS_STOP_AUTHENTICATION_IDENTITY`.

The correction adds `stopAuthenticationHash(owner)`, derived only from immutable owner fields: schema, process ID/start time/executable, host/port, server instance, session generation, control-token SHA-256, and creation timestamp. The whole-owner hash remains required for registry and ledger integrity; no ownership, session, token, or process check was weakened. The CLI, direct real-proof Stop client, and Stop-contract verifier all use and independently recompute the stable hash. The final 51-assertion focused capture passed with stdout SHA-256 `9d02fd6fd9463a1e09f6737a7a67abbd30408a64ac99a522cdd37aa2b90daee4` and empty stderr SHA-256 `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

During failure cleanup, only exact revalidated proof-owned server PID `38012` was terminated after the canonical owner had already disappeared; no unattributed process was targeted. The complete recovery manifest SHA-256 is `e1c5df19a824f3e67f0d6c8f57b1f0f7b57f5bc120979340966bb4e96a80412e`.

The first real proof after the stable-hash correction, `run-mrtmll55-12356-50d07496`, passed 186 assertions in one invocation. It interrupted `hq2-mrtmm5xl-ddbe9e`, recovered as `hq2-mrtmm5xl-ddbe9e-retry-4c63f2a9114a223e`, recorded stable Stop authentication hash `9b67497...`, verified GREEN, admitted with caveats, preserved the recovery receipt, and finished with no owner, listener, or proof-owned process. Durable proof-result SHA-256: `0a79c2fe9b6aacec6f02a1ddaa1468e0147de5c070c658c6f283205d42a380bc`.
