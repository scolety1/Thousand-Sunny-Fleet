# Exact Approval Relay

Approval requires the literal confirmation `APPROVE EXACT REQUEST`. That phrase is confirmation input, not authority. `Invoke-TsfHqDispatchTimResponse.ps1` calls `New-TsfKernelExactApprovalLedger`; the resulting canonical ledger record is the sole authority.

The record binds approval, mission/revision, source run/result, request/evidence, response/content hash, repository/worktree, exact operation/paths, access, control-plane and worker-tool network scopes, surface/model, issue/expiry, single-use policy, approver, required verifier, authorized next revision, and excluded authority. The canonical matcher rechecks those fields before execution, and `Use-TsfKernelApproval` atomically consumes the entry for exactly the authorized new run.

The deterministic approval proof produced:

- mission: `m2b-contract-approval-approval-0001-mrmrdc5w-27204`
- source run/result: `canonical-result-m2b-contract-approval-approval-0001-mrmrdc5w-27204-1`
- request: `timreq-2729cfc96baa8de8a69676cce5578f14`
- request evidence: `92e189af48551d2477e132134ee10d486cd8766e48bb460f27c839e8747c5741`
- response: `hq-response-contract-20260715-0001`
- response-record SHA-256: `aca8153e2c3a399d622fe802f54b992f04153db17a5b8d1f28fe68e4c764cbb3`
- approval: `approval-cad04778c72135391269b7464c87e338`
- authorized revision/run: `2` / `canonical-result-m2b-contract-approval-approval-0001-mrmrdc5w-27204-2`
- final ledger state: `EXHAUSTED`, usage `1/1`, consumed by the revision-2 run
- final ledger SHA-256: `a28f6f3152db6a8caa4eb783250730f84f8f0fa52107928d9512945460053efc`
- revision-2 queue SHA-256: `5a03ec3a4aaa575b0c772ecd23d96f2d685eced89de3b073a26aa144bf890e75`

The proof rejected extra/parent paths, broader access/network, changed operation/expiry/reuse, wrong repository/worktree, changed request hash, cross-mission bindings, and caller authority fields. In addition to the closed response boundary, direct canonical matcher probes mutated operation, repository, worktree, path set, reuse, and mission identity; a direct writer probe changed the request object from its evidence. Every mutation failed authority matching/writing. Exact replay returned the same record; changed replay failed. The original revision stayed terminal and immutable. The deterministic approval proof intentionally used no real worker; the bounded real proof exercised the clarification path instead of manufacturing an unsafe approval request.
