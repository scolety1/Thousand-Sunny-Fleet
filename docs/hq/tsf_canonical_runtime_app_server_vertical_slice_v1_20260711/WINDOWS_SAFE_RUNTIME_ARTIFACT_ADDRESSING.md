# Windows-Safe Runtime Artifact Addressing V1

Superseded publication judgment: the follow-up runtime-authority correction enforces one exact normal V1 root, `<repo>/.codex-local/rt`, through `tools/TsfRuntimeArtifactAddressing.ps1`.

The canonical preservation layout is:

`<TSF repository>/.codex-local/rt/p/<mission-key>/<run-key>/`

Mission, run, receipt, and conflict keys are fixed 32-character lowercase Base32 values without padding. Each key encodes the first 160 bits of a canonical SHA-256 identity. The complete 256-bit identity remains in the runtime manifest or receipt body, and every existing short-key location is parsed and checked against that full identity before it is accepted.

New packet files use fixed compact names: `manifest.json`, `m.json`, `pf.json`, `rp.json`, `wi.json`, `wr.json`, `ar.json`, `vr.json`, `pp.json`, `dr.json`, `ej.jsonl`, `u.json`, and `se.log`. Logical mission IDs, result IDs, branches, worktrees, roles, and human-readable titles never become runtime directory or file names.

The canonical preservation writer stages a complete packet under the matching `x/<mission-key>/<run-key>` address, verifies JSON parsing, artifact hashes, sizes, manifest bindings, canonical containment, and the complete path budget, then moves the directory to its immutable `p/...` address. A complete interrupted staging packet is reconciled idempotently. Incomplete or identity-mismatched staging fails closed.

The hard path limit is 240 characters and the live target is 225 characters. Final, staging, manifest replacement, durable-result, admission, transaction, backup, recovery, and conflict paths are calculated before their corresponding state mutation. The successor worktree layout is designed to remain within the target even for arbitrarily long logical identifiers.

Admission and transaction receipts live beneath the verified compact packet in `r/`. They retain complete mission, revision, result, policy, preservation, decision, transition, and receipt identities in their bodies. Exact replay is idempotent; conflicting replay preserves the original receipt and writes an immutable, collision-checked conflict record.

Historical `preservation_packet.json` packets are not renamed. They remain readable through the explicit `LEGACY_READ_ONLY` descriptor. Durable-result, admission, transaction, conflict, preservation, and queue-mutating operations against that layout fail `LEGACY_PACKET_WRITE_PROHIBITED` before a write.

Normal queue-executor and lifecycle control outputs use compact `q/<mission-key>/<run-key>` and `l/<mission-key>/<run-key>` addresses. Durable queue records remain the one operational queue outside artifact storage; their state filenames are not runtime-artifact addresses.
