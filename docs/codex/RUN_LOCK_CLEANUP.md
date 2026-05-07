# Fleet Run Lock Cleanup

Fleet status and launch preflight may clean stale run locks under `.codex-local/locks`.

## Removal Rules

A lock may be removed when:

- the recorded `pid` no longer exists, or
- the recorded `pid` exists but has no active child process other than `conhost.exe` for at least the configured idle-shell timeout.

A lock must be preserved when:

- the recorded `pid` has active child work such as Codex, PowerShell, build, review, browser, or test processes, or
- the lock file cannot be read safely.

The cleanup never kills processes. It only removes stale lock files after classifying the process tree.

## Logging

Every cleanup writes to `out/fleet-lock-cleanup.md` with project, lock path, PID, reason, and whether the file was removed.

## Config

`fleet-remote-control.ps1` and `fleet-launch-gate.ps1` accept `-IdleShellStaleMinutes`, defaulting to `45`.
