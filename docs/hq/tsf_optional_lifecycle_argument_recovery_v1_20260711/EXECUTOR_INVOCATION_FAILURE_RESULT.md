# Executor lifecycle invocation-failure result

`BLOCKED_LIFECYCLE_INVOCATION` covers failures before a lifecycle terminal result exists.

Its schema requires mission and revision, canonical queue hash, policy fingerprint, repository/branch/worktree, intended lifecycle entry point, included and omitted argument names, approval semantics, sanitized invocation error, queue state, canonical result and producer-registry paths, and producer binding identities.

The invariant fields are `worker_started: false`, `lifecycle_started: false`, and `app_server_started: false`.

The queue executor writes `if.json` through the compact queue-control plan, mints a queue-executor-held producer capability, registers the evidence as `executor_invocation_failure`, and leaves the queue record in a recoverable non-worker state.
