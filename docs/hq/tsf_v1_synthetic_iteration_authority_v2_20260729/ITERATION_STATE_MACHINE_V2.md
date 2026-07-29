# Iteration State Machine V2

The closed state set is:

`PLANNED`, `PREAUTHORIZED`, `PREVIEWED`, `QUEUED`, `WORKER_RUNNING`,
`PATCH_PRODUCED`, `FOCUSED_TESTS_FAILED`, `ACCEPTANCE_TESTS_FAILED`,
`VERIFIER_REJECTED`, `CORRECTION_PLANNED`, `CORRECTION_APPROVED`, `VERIFIED`,
`COMMIT_AUTHORIZED`, `COMMITTED`, `ADMITTED`, `INTERRUPTED`,
`RECOVERY_REQUIRED`, `ROLLED_BACK`, `BLOCKED`, and `EXHAUSTED`.

The static authority enumerates every permitted edge. State events are
hash-linked in order. A failed iteration record and patch are written once and
never replaced. A correction increments the iteration and receives a new run
identity while retaining the task binding. The fourth attempt returns
`EXHAUSTED` before worker launch.

`ADMITTED`, `BLOCKED`, and `EXHAUSTED` are terminal. A commit cannot precede
`VERIFIED` and `COMMIT_AUTHORIZED`; admission cannot precede `COMMITTED`.
