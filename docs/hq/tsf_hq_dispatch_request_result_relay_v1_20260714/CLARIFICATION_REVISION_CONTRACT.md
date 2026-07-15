# Clarification Revision Contract

Clarification accepts 1–2000 bounded characters, rejects nulls and secret-like content, and binds the response to the exact mission/session/evidence hash. The wrapper creates a new durable revision with parent mission identity and includes the answer as typed mission context. A new queue document and governed run are required; the old revision remains terminal.

Replay uses a server-generated response ID. Identical replay returns the existing result; changed content or cross-mission/session use fails closed. Synthetic revision-2 coverage passed. A real revision run was not reached because the runtime path budget blocks execution first.
