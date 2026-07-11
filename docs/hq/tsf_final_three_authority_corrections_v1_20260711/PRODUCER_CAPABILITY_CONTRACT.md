# Producer Capability Contract

Normal runtime authority is `ORCHESTRATOR_HELD_RUN_CAPABILITY`.

`Invoke-TsfMissionLifecycle.ps1` is the sole canonical producer-capability minting call site. It creates a new object reference at run start. The object and its context are held only in a fresh, unguessable per-orchestrator AppDomain slot whose name exists only in the orchestrator script scope. The capability is not a string, GUID, JSON field, command-line value, registry field, mission field, result field, or filesystem artifact.

Registration requires reference equality with the held object. The held context binds the canonical orchestrator invocation, registry binding hash, run nonce, mission/revision, run/result ID, policy fingerprint, queue-document hash, repository, branch, and worktree. Producer, logical type, maximum evidence class, and canonical compact path come from the internal artifact contract. Hash and size are recomputed after the component completes, and sequence numbers are unique and strictly increasing.

Validation rejects missing or caller-created capabilities, test capabilities on the normal path, invocation or binding mismatch, duplicate or regressing sequences, changed bytes, and producer/type/class/path/mission/run/repository mismatch.

Tests have a separate `TEST_ONLY_PRODUCER_CAPABILITY` minting entry point. It is accepted only with explicit synthetic-test switches and an isolated test registry, and cannot validate as normal runtime authority.

This is local run-scoped producer provenance. It is not cryptographic producer attestation.
