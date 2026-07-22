# Process ownership and causal safety

The immutable owned-process registry is the sole process-ownership authority. Registration binds PID, process start time, executable, parent identity, launch event, server instance, proof capability, mission/run identity, worktree/candidate identity, registry generation, and evidence hash. PID alone, executable name, timing, port history, or family resemblance never establishes ownership.

The append-only process-action ledger is an audit projection of that registry. Every terminating action must reference the exact owned registration and PID/start-time identity. Cleanup rejects PID reuse, unbounded process-tree traversal, name-only matching, missing ownership evidence, missing terminal dispositions, and conflicting dispositions. Each owned process receives exactly one cooperative, forced, already-gone, or unconfirmed terminal disposition; unconfirmed cleanup fails closed.

Unattributed processes are observed separately and never targeted. In pre-amend proof `run-mrtir77w-5748-9834719a`, two unrelated Codex processes remained unattributed, appeared in no termination target, received no owned disposition, and were left running. The causal process-safety result was PASS with `targeted_count=0`; the owned-process ledger SHA-256 was `d41fc6be138ab66a5542843e20078d45cf5ab929d3af7614e0ac55c16ef245f8`.

Root-independent descendant cleanup uses committed registry entries, not a live root snapshot. Owner evidence is archived only after terminal cleanup evidence is durable; the live owner is then removed, the listener is closed, and no persistent proof process remains.

## Closed authoritative spawn inspection

Preserved exact-candidate proof `run-mrtk9b5b-33500-93d7abc7` failed at `CHILD_COMPLETED_BEFORE_BARRIER` after the adapter emitted `APP_SERVER_SPAWN_PARENT_IDENTITY_MISMATCH`. The inspector had used nullable CIM `ExecutablePath` values and collapsed missing fields, PID mismatches, and parent mismatches into that one generic classification. The proof therefore could neither establish ownership nor identify the actual failed invariant.

The correction centralizes spawn identity inspection in `validateAuthoritativeSpawnIdentity` and `inspectAuthoritativeSpawnIdentity`. `Get-Process` is authoritative for live PID, start time, and executable; CIM supplies parent PID and corroborating executable identity. Structured diagnostics distinguish absent process, wrong PID, wrong start time, wrong executable, wrong parent, and inconsistent sources. Nullable corroborating fields no longer manufacture a mismatch. A seven-case adversarial check, the 24-assertion registration suite, the 49-assertion app-server adapter suite, and a controlled same-binary stdio-only Codex app-server probe all passed. The probe terminated only its exact child.

Cycle-6 real proof `run-mrtmll55-12356-50d07496` registered exact app-server PID `15460`, reached the barrier, and produced process-ledger SHA-256 `8ee501abfc4cd181a9fb245e02fb21034cbe6cf4b600f9442f96705084c96454`. Five observed unattributed Codex processes appeared in no termination target and were left untouched.
