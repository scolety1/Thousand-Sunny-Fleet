# Mission Schema V1

`mission_schema_v1.json` defines the minimum machine-readable packet accepted by the foreground TSF enforcement kernel.

The packet must declare:

- mission identity, project identity, repo path, lane, and mission type
- allowed reads and writes
- forbidden reads and writes
- forbidden actions
- expected artifacts
- required preflight and post-run checks
- machine-checkable stop conditions
- approval requirements
- HQ escalation policy
- creator and timestamp

The V1 validator uses dependency-free PowerShell shape checks rather than a package-based JSON Schema engine. The JSON Schema remains the contract for tooling, review, and future validator hardening.

## Authority Rule

A mission packet is not approval. It is a request for local validation. Restricted actions are blocked unless they are explicitly approval-gated and matched by an active local approval ledger entry.
