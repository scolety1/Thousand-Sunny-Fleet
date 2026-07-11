# Evidence Producer Authority Map

| Evidence class | Canonical producer | Final observations |
|---|---|---|
| NATIVE_OBSERVED | Exact app-server events bound to child/thread/turn | Read-only 36 events (`8c601fc2a0411f4a59bd3f7cd3953631b14d9fe8c0e5438e205e92410f14b51b`); workspace 123 events (`763106fef4ee20ba98e07ef1f4b2c3aff26def9a6b228173487c8c0e283f8d96`) |
| ADAPTER_OBSERVED | Foreground stable-protocol adapter | Native task identities, model, cwd, network-plane separation, cleanup |
| KERNEL_OBSERVED | Existing preflight, worker result, preservation, mapper, admission | Both flows GREEN with compact packet and committed receipts |
| VERIFIER_OBSERVED | Existing canonical post-run verifier | Read-only `3e465512e24dc3c55d33f36c3d34e062bc5d1d876e35cc18a353eb55a572430f`; workspace `c78ed41521787a027522967e22b4fd6f06d5f66d6dd4833d9100ef27a740c5ee` |
| FILESYSTEM_OBSERVED | Git/filesystem observation and independent hashes | No read-only mutation; exact workspace fixture output hash `582e3e7d854fa8970d2b9949f83224602ec72a59ce4b22712250004c4aa1c5ad` |
| AGENT_REPORTED | Narrative only | Never promoted to authority |
| UNVERIFIED | Stable protocol did not expose a turn-effective effort | `UNKNOWN` / `NOT_EXPOSED`; bounded RECOMMENDED_ONLY caveat |

Control-plane service use is not classified as worker network activity. Both results record `codex_service_connection_used: true`, `direct_openai_api_called_by_tsf: false`, `external_api_called: false`, and `worker_network_used: false`.
