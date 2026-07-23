# Security and authority review

The correction is localized inside the existing GENERAL_RESULT_V2 authority chain.

- No new semantic, verifier, admission, approval, or routing authority was created.
- No unconstrained LLM judge was added.
- No answer-wide regex decides worker status.
- The worker claim remains non-authoritative.
- Admission recomputes the structured assessment.
- Mission/revision/run, intent, scope, task contract, and attempted task remain bound.
- Exact-literal mechanics are unchanged.
- Replay and receipt identities remain unchanged.
- Legacy output fails closed.
- Malformed V2 array fields fail closed; the live follow-up makes required JSON array types explicit without coercion.
- UI fulfillment is conditioned on verifier and admission.

Boundaries retained:

- products: not accessed;
- plugins: not used;
- credentials/secrets: not accessed;
- installation: not performed;
- deployment/merge/auto-merge: not performed;
- worker-tool network: disabled;
- control-plane network: only bounded Codex service proof when explicitly run;
- persistent/background workers and remote listeners: not created;
- unattributed processes: not terminated;
- historical evidence: not rewritten or deleted.
