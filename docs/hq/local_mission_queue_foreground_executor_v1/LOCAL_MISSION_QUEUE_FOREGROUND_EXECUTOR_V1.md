# Local Mission Queue Foreground Executor V1

Verdict: GREEN local implementation candidate, pending runway validation.

This lane adds a foreground-only queue executor for TSF mission packets. It reuses the existing mission queue state policy, kernel preflight, role-aware permission preflight, worker instruction generation, post-run verifier, and preservation writer.

The executor is intentionally not a daemon, scheduler, watchdog, overnight runner, persistent runner, all-fleet runner, or background worker pool.

## Flow

```text
mission in inbox/drafted
-> validate queue state
-> drafted
-> preflight_pending
-> kernel preflight
-> role permission preflight
-> approved_for_worker or blocked_needs_tim
-> worker_running only when -RunApprovedFixtureWorker is explicit
-> postrun_pending
-> complete_review_only / complete_ready_for_gate / blocked_needs_tim
```

## Safety Model

- Processes one mission packet at a time.
- Supports `-DryRun`.
- Requires explicit `-RunApprovedFixtureWorker` before Codex worker execution.
- Uses normal user config with `service_tier=fast` and `--sandbox workspace-write`.
- Does not use `--ignore-user-config`.
- Does not use `danger-full-access`.
- Requires exact approval action `codex_cli_queue_fixture_worker_invocation`.
- Restricts fixture worker output to `tests/fixtures/fleet/mission-queue/worker-output/`.
- Fails closed on invalid state transitions, missing approval, missing role permission, forbidden paths, verifier RED, and unclear Codex CLI execution.

## Reused Components

- `tools/Move-TsfMissionState.ps1`
- `tools/codex-fleet-enforcement-kernel.ps1`
- `tools/codex-fleet-runtime.ps1`
- `tools/Test-TsfWorkerRolePermission.ps1`
- kernel preflight / worker instruction / verifier / preservation functions
- `fleet/control/mission-queue-state-policy.v1.json`

## New Components

- `tools/Invoke-TsfMissionQueueForegroundExecutor.ps1`
- `fleet/control/mission-queue-foreground-executor-policy.v1.json`
- queue dogfood mission fixtures for Builder, Tester, and Auditor workers
- expanded queue tests in `tests/run-tsf-mission-queue-tests.ps1`
