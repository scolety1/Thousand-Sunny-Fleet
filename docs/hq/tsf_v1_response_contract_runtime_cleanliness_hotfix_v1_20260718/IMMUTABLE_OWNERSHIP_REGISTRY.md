# Immutable ownership registry

Owned-process registration is atomic with its causal ledger event. A registration is usable only after the immutable registry event and matching ledger event are both durable. Descendant enrichment preserves the root registration, exact parent chain, mission/run identity, candidate worktree/commit, proof capability, and launch/ownership hashes.

The registry is generation-stabilized before cleanup finalization. New registrations are blocked during closing; terminal observations are reconciled by PID and start time; PID reuse never inherits ownership. Each committed registration must have exactly one terminal disposition before the barrier can become `READY_CLEANED`.

The real proof barrier binds the authoritative executor and app-server spawn. Pre-amend proof `run-mrtir77w-5748-9834719a` recorded barrier SHA-256 `82f2b5533d8b42d7c1c5120b7be79b18fe55a90a1fa03f7bc01f3f81cf692926`, ownership evidence SHA-256 `648995896b6afac779e4110092e3cbf0924026a7576d092659a5d36bd7bda6b9`, and a durable action ledger with zero unattributed termination targets.
