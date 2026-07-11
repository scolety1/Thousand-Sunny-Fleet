# Lifecycle terminal-result contract

`fleet/control/lifecycle-terminal-result.schema.v1.json` defines the terminal lifecycle result. The canonical leaf is `lc.json` in the lifecycle-control compact runtime plan. The executor and lifecycle both obtain this path from the same `New-TsfCompleteRuntimePathPlan` object; neither constructs it independently.

Terminal statuses are:

- `COMPLETED_GREEN`
- `COMPLETED_WITH_CAVEATS`
- `BLOCKED_PREFLIGHT`
- `BLOCKED_ROLE_PERMISSION`
- `BLOCKED_WORKER_START`
- `BLOCKED_WORKER_RESULT`
- `BLOCKED_VERIFIER`
- `BLOCKED_PRESERVATION`
- `TIM_REQUIRED`
- `INTERNAL_ERROR`

Every result binds mission ID, revision, run ID, canonical queue-document identity, policy fingerprint, repository, branch, worktree, canonical result path, producer-registry path, producer binding identity, and orchestrator invocation identity. It also records stage, queue location, worker launch state, verifier state, preservation state, evidence paths, and blockers.

The lifecycle validates the schema, writes `lc.json`, registers it as `lifecycle_result` with producer `mission_lifecycle` and classification `KERNEL_OBSERVED`, and verifies that provenance before returning. The synchronous executor validates schema, all canonical bindings, the exact planned path, producer binding, and registered file hash before it proceeds to durable mapping or admission.

Canonical queue evidence is validated in its canonical JSON identity domain. File-byte hashes remain separately recorded by producer and preservation manifests.
