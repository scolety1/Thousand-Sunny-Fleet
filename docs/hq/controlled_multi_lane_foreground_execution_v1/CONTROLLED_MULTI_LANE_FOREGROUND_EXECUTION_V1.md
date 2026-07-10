# Controlled Multi-Lane Foreground Execution V1

## Verdict

Initial reusable layer pending dogfood.

## Reuse Note

This milestone adapts the existing TSF Project Main Bot, mission queue, role-aware lifecycle, approval ledger, parallel lane dry-run, isolated worktree pilot, verifier, preservation writer, context evidence, and collision review patterns. It does not create a second orchestration system.

## Target Flow

Tim-approved local request -> Project Main Bot scope -> mission queue foreground mode -> parallel lane coordinator -> isolated local worktrees -> bounded foreground fixture workers -> per-lane verifier -> collision and integration review -> preservation/context evidence -> stop before merge.

## Local Boundaries

- Foreground only.
- Sequential lane execution unless a later gate approves concurrency.
- Maximum three lanes.
- Maximum three fixture-only Codex worker invocations.
- No push, merge, PR creation, deploy, install, migration, secrets, PrivateLens, all-fleet, API, background runner, product repo mutation, canonical NWR mutation, danger-full-access, or ignore-user-config.

## Components Reused

- `tools/Test-TsfParallelLanePlan.ps1`
- `tools/Invoke-TsfParallelLaneFixtureWorker.ps1`
- TSF role-aware permission preflight
- TSF enforcement kernel preflight
- exact approval ledger matching
- TSF post-run verifier
- TSF preservation packet writer
- existing scoped TSF validation scripts

## New Components

- `fleet/control/controlled-multi-lane-foreground-execution-policy.v1.json`
- `tools/Invoke-TsfControlledMultiLaneForegroundExecution.ps1`
- controlled multi-lane plan fixtures
- controlled multi-lane regression tests

## Dogfood Status

Pending controlled three-lane foreground dogfood.
