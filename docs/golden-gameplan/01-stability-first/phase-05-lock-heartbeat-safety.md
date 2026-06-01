# Stage 1 Phase 5: Lock and Heartbeat Safety

## Goal

Reduce false stale-run cleanup and duplicate-run risk in lock and heartbeat
handling.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 1 Phase 5 only: Lock and heartbeat safety.

Do not implement any other Golden Gameplan phase.

Goal:
Make lock and heartbeat monitoring less likely to kill, unlock, or duplicate a
healthy run during slow startup, heavy I/O, or temporary heartbeat delay.

Before editing:
- Run .\fleet-status.ps1.
- Inspect fleet-runner-watchdog.ps1, run-checkpoint-loop.ps1, and any lock or
  heartbeat helpers.
- Identify where locks are created, refreshed, classified stale, and removed.

Scope:
- Likely files: fleet-runner-watchdog.ps1, run-checkpoint-loop.ps1,
  fleet-supervisor.ps1, tests/run-fleet-tests.ps1.
- This phase can add metadata to lock/heartbeat files if backward compatible.
- Do not manually delete existing locks.
- Do not implement the full state machine yet.

Required behavior:
- Watchdog should not remove or classify a fresh starting run as stale on the
  first check.
- Stale cleanup should require stronger evidence than a single timestamp check
  where practical.
- Lock files should include enough identifying information to explain ownership.
- Reports should distinguish stale, idle, active, and unknown lock states.

Acceptance:
- Add tests where a fresh heartbeat/lock is not removed.
- Add tests where an actually stale heartbeat can still be reported.
- Add tests for lock metadata parsing if metadata is added.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/01-stability-first/checkpoint.md.

Stop if:
- Correct locking requires a larger state-machine refactor. Document the minimal
  safe improvement and defer the rest to Stage 5.
```

## Why It Matters

False stale cleanup can cause duplicate runs, lost ownership, or mystery pauses.
That is exactly the kind of problem that ruins unattended work.

## Tests To Add

- fresh lock survives watchdog
- stale lock is reported safely
- lock ownership metadata is readable
- no cleanup occurs without sufficient stale evidence

## Done When

The watchdog is safer and less likely to interfere with active work.

