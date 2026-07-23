# Security and Authority Review

The hotfix narrows authority.

- No LLM or model judges semantic fulfillment.
- No whole-answer phrase scan grants or denies fulfillment.
- A worker `FULFILLED` field is non-authoritative.
- Generic prose cannot produce verifier GREEN, admission, or a receipt.
- Allowing `STRUCTURAL_TEXT_ONLY_V2` in the result schema validates representation only and grants no fulfillment or admission authority.
- Structured admission is mechanically checked against a mission-bound closed contract.
- Result-contract choice is previewed and independently recomputed at submission.
- Recovery clones the source mission's bound contract and cannot widen authority through a caller-supplied recovery contract.
- Caller-supplied contract type, verifier fields, admission fields, stale preview, changed replay, and identity substitution fail closed.
- Exact literal, original-intent, scope-reduction, detached-write, preservation, queue, receipt, and replay protections remain in force.

No product repository, plugin, credential, installation, deployment, external worker network, service, scheduled task, daemon, startup registration, remote listener, persistent process, or unattributed-process termination is needed by this program.

Merge and production authority remain absent.
