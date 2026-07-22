# Fetch trace and durable result projection

Every proof-harness HTTP operation records a token-free fetch ID, stage, caller, method, loopback pathname, expected server/session identity, timeout, response status/content hash, error class/cause, abort state, and listener state. `PROOF_STAGE_TRACE.json`, `FETCH_TRACE.json`, `PROCESS_OWNERSHIP_TRACE.json`, and `PROOF_RESULT.json` are written on every attempt; `BLOCKER.json` is additionally written on failure. Final result serialization runs from the guaranteed terminal path.

HTTP is used only while the exact HQ Dispatch instance, listener, and operator session are live. Required live projections are captured before Stop. Once Stop invalidates the session and closes the listener, lifecycle, verifier, preservation, admission, recovery receipt, queue, and `STOP_RECORD.json` evidence are read through the existing canonical durable readers. A stopped listener is expected cleanup and is never queried merely to serialize proof results.

The earlier post-recovery `fetch failed` was made diagnosable by this contract: an endpoint can no longer be unknown, and durable evidence cannot be lost because a projection fetch throws. The native race correction complements this behavior by ordering response settlement and exact server close without changing the authoritative durable store.

Packet-seal Proof 2 interruption runs for candidate `57c0b873808c416c4c4d2d7d689c02f198ff7cbb`, tree `65e8639d08c5582549f89028f9614bff8e62c8ba`:

- `run-mrv5gdl4-19100-dbe73aea`: original mission `hq2-mrv5h0f3-44d946`, app-server PID `38920`, recovery mission `hq2-mrv5h0f3-44d946-retry-63f43037b59089b0`, recovery receipt `hq-recovery-receipt-0862f54ac5beda30b393237ffd98ae31`, 186 assertions, stdout SHA-256 `c758b85f7c22002f1b33309ba917ffefa52e6ee825b176c196d6571369b86ba0`.
- `run-mrv5jmwo-42152-8b20e401`: original mission `hq2-mrv5k226-d088c8`, app-server PID `20740`, recovery mission `hq2-mrv5k226-d088c8-retry-f0c70b73f0a75f49`, recovery receipt `hq-recovery-receipt-506b83095f9c35d71f3aded9cdf34e9a`, 186 assertions, stdout SHA-256 `75e54af16b9e5f807976c5c7553d3d74c3d712187fc5c6d415129623428818ef`.

Both proofs used distinct fixture/run/server identities, reached `READY_CLEANED`, preserved durable Stop and recovery evidence, admitted the distinct recovery honestly, serialized successfully, and ended with no owner, listener, or proof-owned process. Unattributed Codex processes were observed and not targeted. The successor commit containing this packet must repeat the exact detached runtime gates; the packet self-check rejects any supplied final acceptance, production, wrong-result, interruption, or responsive proof whose HEAD/tree differs from that successor.
