# Process Ownership Contract

The ignored local owner record binds:

- process ID, UTC process start time, and executable;
- exact repository/worktree, branch, and commit;
- fixed host/port and server-instance ID;
- operator-session generation;
- owned child process IDs, start times, and executables;
- active mission/run evidence when present;
- creation/update timestamps, stop-capability hash, and record evidence hash.

Writes use a same-directory temporary file and atomic rename. The stop capability is separate and its value is never emitted by Doctor, UI, logs, or the validation packet.

A record is authoritative for local lifecycle control only when live PID, start time, executable, worktree, instance, evidence hash, and listener all agree. A stale PID, reused PID, wrong executable/start/worktree/instance, changed hash, or unowned listener fails closed. A valid second instance is rejected. A stale record produces an explicit Doctor disposition and is never used to terminate a process.

The record grants no mission approval, queue, verifier, preservation, result, admission, response, merge, deployment, or production authority.
