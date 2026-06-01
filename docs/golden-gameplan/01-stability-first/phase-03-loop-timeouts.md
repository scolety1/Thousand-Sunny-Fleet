# Stage 1 Phase 3: Loop Timeout and Retry Caps

## Goal

Add bounded retry and timeout controls to fleet loops that can otherwise run
forever or burn model limits.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 1 Phase 3 only: Loop timeout and retry caps.

Do not implement any other Golden Gameplan phase.

Goal:
Identify fleet loops that use while ($true), do/while forever, or repeated model
calls without hard caps. Add conservative retry/time limits and clear failure
reports where missing.

Before editing:
- Run .\fleet-status.ps1.
- Search for while ($true), do { } while ($true), repeated Codex invocation loops,
  and supervisor/watchdog loops.
- Identify which loops already have a safe exit and which do not.

Scope:
- Likely files: codex-fleet-runtime.ps1, fleet-supervisor.ps1,
  fleet-runner-watchdog.ps1, run-checkpoint-loop.ps1, tests/run-fleet-tests.ps1.
- Prefer adding optional parameters with defaults rather than changing normal
  user-facing behavior abruptly.
- Do not change model selection policy beyond stopping runaway loops.

Required behavior:
- Read-only Codex/model loops exit after a configured max retry or max elapsed
  time when no usable output appears.
- Supervisor/watchdog loops can be run with a bounded iteration count for tests
  and controlled monitoring.
- Timeouts are reported clearly and do not masquerade as successful runs.
- Rate-limit pauses remain supported; this phase does not implement auto-resume.

Acceptance:
- Add tests with a stubbed command that produces no output and verify bounded exit.
- Add tests for bounded supervisor/watchdog iteration when supported.
- Existing tests still pass.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/01-stability-first/checkpoint.md.

Stop if:
- A loop cannot be bounded without changing public launcher semantics.
- Timeout handling requires the Stage 10 rate governor. Document the dependency
  and stop instead of building Stage 10 early.
```

## Why It Matters

An overnight fleet should never spin forever because one command failed to write
output.

## Tests To Add

- empty model output exits after max retries
- timeout reports are non-successful and human-readable
- bounded supervisor/watchdog mode exits after configured intervals

## Done When

Known fleet loops have a safe boundary and testable exit behavior.

