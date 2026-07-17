# Ownership and Recovery Contract

## Process ownership

The ignored local `owner.json` binds process ID, UTC process start time, executable, exact repository/worktree, branch/commit, fixed loopback host/port, server instance, operator-session generation, owned child identities, active mission, timestamps, a stop-capability hash, and an evidence hash. Writes are staged and atomically renamed. The stop capability is stored separately with a hash binding.

An owner is active only when PID, start time, executable, repository/worktree, instance evidence, and listener agree. PID reuse, changed hashes, a different worktree, stale process, occupied unowned port, or an already-active valid owner blocks Start. Doctor reports a disposition and never deletes or kills anything. `Stop-TsfHqDispatchV1.ps1 -RecoverVerifiedStaleOwnership` removes stale files only after an explicit stale/PID-reuse disposition; it never terminates the observed unrelated process.

Only the exact owner removes a valid active record. Stop authenticates instance ID, current evidence hash, process ID, process start/executable evidence, listener ownership, and the local stop capability. It stops submissions, invalidates sessions, requests cooperative child exit, bounds the wait, and may terminate only the exact verified owned child tree. It then closes the listener and confirms the server, children, listener, and owner record are gone.

## Restart reconciliation

Doctor scans canonical queue and compact runtime records read-only. It distinguishes all required V1 classifications:

- `COMPLETED_ADMITTED`
- `COMPLETED_ADMITTED_WITH_CAVEATS`
- `COMPLETED_REJECTED`
- `TIM_REQUIRED_PENDING_RESPONSE`
- `TIM_REQUIRED_RESPONDED_REVISION_EXISTS`
- `RUNNING_PROCESS_CONFIRMED`
- `INTERRUPTED_PROCESS_GONE`
- `QUEUED_NOT_STARTED`
- `DISPATCHING_WITHOUT_OWNER`
- `RESULT_WITHOUT_ADMISSION`
- `ADMISSION_WITH_QUEUE_MISMATCH`
- `DUPLICATE_EXACT_REPLAY`
- `CONFLICTING_REPLAY`
- `STALE_OR_UNKNOWN`

Each item includes mission/revision/run/result identity, paths and hashes, queue/admission/verifier/process/replay evidence, safe actions, exact recommendation, required authority, and an immutable-history warning. Conflicting receipts or changed-content duplicates stop reconciliation. Exact duplicates are projected idempotently.

## Recovery actions

The UI sends the recovery item ID, evidence hash, action, and an exact confirmation equal to the action. The server reloads canonical state before acting; changed evidence returns a conflict and requires a new decision.

- `ACKNOWLEDGE_COMPLETED` and `DECLINE_RECOVERY` create an idempotent, non-authoritative audit receipt.
- `VIEW_CANONICAL_RECEIPT` is read-only.
- `RESPOND_TO_TIM_REQUIRED` rehydrates the terminal request into the current memory-only session and delegates to the existing exact response path. It never resumes the prior thread or turn.
- `MARK_PROCESS_INTERRUPTED` writes an immutable stop record and byte-exact queue snapshot. It never writes completed state.
- `RETRY_AS_NEW_RUN` uses canonical mission drafting, validation/routing, queue creation, executor, verifier, and admission paths with a new mission/run/result/thread/turn/verifier/admission identity. Existing or expired authority is not inferred.
- `RECONCILE_QUEUE_FROM_CANONICAL_RECEIPT` validates the durable result, preservation packet, admission receipt, transaction hashes/identity, queue document hash, queue authority, and exact source/destination, then delegates the move to `Move-TsfMissionState.ps1`.
- `TIM_REQUIRED` performs no mutation.

Recovery receipts are append-only evidence, not an approval, replay, admission, queue, or recovery database. Their idempotency identity is source evidence plus action, so a server/session restart cannot repeat a recovery mutation.
