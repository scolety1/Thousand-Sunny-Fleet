# Idempotency Contract

- Submission IDs are server-generated and bound to request, preview content, and operator session.
- Same ID/same content returns the same promise/result.
- Same ID/changed content or another session fails closed.
- Concurrent double-clicks invoke the execution adapter once.
- An identical new preview in the same process reuses the existing terminal mission and canonical terminal source.
- A different active mission is rejected.
- Completed replay does not create another mission or queue document in process memory.

The memory index prevents duplicate process execution; it grants no canonical authority and is cleared on process restart. Persistent restart/reconciliation remains deferred.
