# TIM_REQUIRED Relay Contract

TIM projection is derived from canonical lifecycle/queue evidence and binds mission, revision, run/result identity, expiry, reason, requested operation, access, network, repository/worktree, paths, evidence path, and SHA-256. The UI states that the original run stopped.

Supported projections are `APPROVAL_REQUIRED` and `AUTHORITY_DECISION_REQUIRED`; unknown actions fail closed. No app-server turn remains suspended and the original run is never silently resumed.

Synthetic coverage passed for approval, denial, clarification, replay, changed replay, cross-session response, and evidence mismatch boundaries. Real TIM prompting was not attempted.
