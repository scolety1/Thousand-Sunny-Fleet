# Final self-hosted audit evidence routing

One new audit is authorized only after the repair commit and committed-blob fingerprint are fixed.

The mission ID format is `tsf-foundation-publication-audit-<repair-short-head>-20260711`. It must use Auditor, Codex app-server, DEEP resolving to `gpt-5.6-sol`, HIGH effort, read-only access, `CODEX_SERVICE_ONLY` control-plane network, and disabled worker-tool network. `ApprovalLedgerPath` must be omitted because this audit requires no approval.

Accepted verdicts are `GREEN_TSF_FINAL_AUTHORITY_BOUNDARIES_ACCEPTED` and `GREEN_TSF_FINAL_AUTHORITY_BOUNDARIES_ACCEPTED_WITH_NONBLOCKING_CAVEATS` only.

The post-commit runtime evidence of native thread/turn, lifecycle terminal result, verifier, preservation packet, durable result, admission and transaction receipts, final queue state, and child cleanup is stored under canonical compact `.codex-local/rt` paths. Publication must stop on any other verdict or missing artifact. No correction after this audit is authorized.
