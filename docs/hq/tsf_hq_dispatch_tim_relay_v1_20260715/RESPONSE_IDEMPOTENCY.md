# Response Idempotency

The canonical response identity is the tuple of exact request binding, server response ID, request-evidence SHA-256, and response-content SHA-256.

- The response writer takes an exclusive request-scoped mutex, checks the existing canonical response path, and atomically replaces only a newly created canonical record.
- Exact replay returns the existing response/ledger/revision outcome.
- A changed payload/type/confirmation under the same response ID fails closed.
- A second response ID for an already answered request resolves only to the canonical existing outcome or fails closed; it cannot create another authority record.
- Approval creation and consumption are single-entry/single-use.
- Mission preparation returns the exact existing same-revision record and permits only the immediate revision after terminal `blocked_needs_tim`.
- Queue preparation is content-addressed and refuses a changed same-revision replay.
- The relay's in-memory promise map only collapses concurrent HTTP double-clicks. It is neither durable nor authoritative.

Tests proved one approval/denial/clarification, no duplicate revision or queue, response after expiry/supersession rejection, changed replay rejection, cross-request/cross-mission rejection, and concurrent exact double-click reuse.
