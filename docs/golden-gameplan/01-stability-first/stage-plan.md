# Stage 1: Stability First

Stage 1 removes the reliability problems that can make later autonomy unsafe.
Do not build audit-package ingestion, decision automation, dashboard features, or
mobile control yet. This stage is the runway.

## Goal

Make the fleet stop failing for false reasons.

The fleet should be able to run dry experiments, tests, and bounded launch checks
without unrelated safe-stop requests, stale paths, missing evidence, infinite
loops, ambiguous dirty states, or lock races causing random stalls.

## Why This Stage Comes First

The long-term autonomy loop depends on trustable basics:

- safe-stop requests must be scoped
- failed runs must still write evidence
- loops must have retry caps
- repo state must distinguish missing, clean, dirty, and git-error states
- locks and heartbeats must avoid false stale cleanup
- project paths and base branches must come from config
- generated safe names must not collide

If these are wrong, later stages will only automate confusion faster.

## Phase Order

1. Safe-stop scoping
2. Phase 13 evidence repair
3. Loop timeout and retry caps
4. Repo state detection
5. Heartbeat and lock safety
6. Project path and output path normalization
7. Base branch configuration
8. Safe-name uniqueness
9. Stage 1 integration test and checkpoint

## Files Likely Touched During Implementation

Planning only in this document. When implementation begins, likely files include:

- `fleet-experiment.ps1`
- `run-checkpoint-loop.ps1`
- `fleet-status.ps1`
- `fleet-runner-watchdog.ps1`
- `fleet-supervisor.ps1`
- `fleet-remote-control.ps1`
- `codex-fleet-runtime.ps1`
- `projects.json`
- `tests/run-fleet-tests.ps1`
- helper scripts that read stop requests, locks, paths, or branch state

## Stage Exit Criteria

Stage 1 is complete when:

- unrelated safe-stop requests do not block unrelated dry runs
- Phase 13 experiment runner writes expected Markdown and JSON evidence
- long-running loops have bounded retry or time caps
- missing repos are not reported as dirty repos
- watchdog behavior cannot remove healthy fresh locks on first sight
- default output paths resolve under the fleet root
- configured project base branches are respected
- safe-name collisions are prevented or detected
- `.\tests\run-fleet-tests.ps1` passes

## Do Not Do

- Do not add external task packet ingestion.
- Do not create the full audit package system.
- Do not create the final decision engine.
- Do not change downstream product repos.
- Do not delete locks or stop requests manually as part of implementation.
- Do not rewrite the fleet architecture.
- Do not merge, push, deploy, or clean dirty product repositories.

## Implementation Rule

Implement one phase at a time. Each phase must end with:

1. tests added or updated
2. tests run
3. checkpoint updated
4. a short explanation of what changed and what remains

