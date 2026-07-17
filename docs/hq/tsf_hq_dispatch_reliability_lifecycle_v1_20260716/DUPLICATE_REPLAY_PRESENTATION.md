# Duplicate and Replay Presentation

HQ Dispatch projects existing canonical identity rules; it does not own a private UI registry.

- Same submission ID and same canonical content returns the existing mission (`IDEMPOTENT_REPLAY`).
- Same response ID and same content returns the existing response.
- Same identity with changed content returns `CONFLICTING_REPLAY` and stops reconciliation.
- A completed exact replay returns `EXISTING_COMPLETED_MISSION` and cannot execute again.
- An active exact replay returns `EXISTING_ACTIVE_MISSION`.
- An interrupted retry returns `NEW_RUN_REQUIRED` and creates a distinct run only through explicit recovery.
- Duplicate queue documents are compared by canonical identity and bytes/hashes; conflicting documents fail closed, while exact duplicates are idempotent.
- Recovery action replay is bound to source evidence, action, and confirmation; changed replay fails closed.

The 21-scenario matrix covers exact duplicate submission, changed-content conflict, duplicate response, completed replay, duplicate queue evidence, and new-run recovery. The real recovery proof additionally showed exact recovery replay returned its existing receipt while a changed confirmation returned HTTP 422.
