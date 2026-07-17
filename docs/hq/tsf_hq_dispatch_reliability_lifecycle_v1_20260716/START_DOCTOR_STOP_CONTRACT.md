# Start, Doctor, Stop Contract

## Doctor

Doctor is read-only by default. It verifies repository ancestry and expected worktree, cleanliness where startup requires it, Node/PowerShell/Codex availability without launching app-server, fixed-port state, exact process ownership, stale PID/listener evidence, canonical roots and permissions, schema parsing, 225-character target path budget, queue consistency, interrupted/TIM_REQUIRED/duplicate records, owned-child evidence, and the reference-only plugin baseline. Every check has evidence and an exact next action.

Statuses are `GREEN`, `GREEN_WITH_CAVEATS`, `ACTION_REQUIRED`, `TIM_REQUIRED`, or `UNSAFE_TO_START`. Doctor never creates, deletes, resets, repairs, moves, resumes, answers, or terminates anything. Human and JSON formats are projections of the same report.

## Start

Start always runs Doctor, then the server repeats the gate immediately before ownership claim. It binds only `127.0.0.1:4317`, rejects an occupied port or valid existing owner, prints the URL and canonical/local roots, creates a fresh memory-only session generation, and remains in the foreground. It creates no service, task, startup item, daemon, detached worker, automatic submission, or automatic resumption.

## Stop

Stop accepts no arbitrary PID. It loads the ignored owner record, verifies evidence hash, PID start time, executable, exact repository/worktree, instance, listener, and local stop capability, then sends the authenticated local request. The server rejects submissions, invalidates sessions, cooperatively stops the relay, and if needed terminates only the exact verified owned process tree. It writes interruption evidence only after child exit and canonical artifacts settle, closes the loopback listener, and confirms process, child, listener, and owner-record removal.

An explicit stale-owner recovery is allowed only after Doctor proves `STALE_PROCESS_GONE` or `PID_REUSED_OR_IDENTITY_MISMATCH`; it removes stale local evidence and never kills the observed process.
