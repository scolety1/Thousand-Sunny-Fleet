# Nytheria Slice 1 Implementation Work Order

Prepared: 2026-07-02

NOT APPROVED. Draft work order only. Do not implement unless Tim gives exact
approval for Nytheria Slice 1.

## Goal

Implement the TSF-local Text-Only World Clock Slice 1 described by:

- `fleet/status/game-forge/work-orders/nytheria-text-world-clock-work-order.md`
- `fleet/status/draft-queue/nytheria-slice-1-approval.md`

## Suggested TSF-Local Targets

- `fleet/status/game-forge/prototypes/nytheria-text-world-clock.md`
- optional fixture under `tests/fixtures/fleet/game-forge/nytheria-text-world-clock.fixture.json`
- focused regression coverage in `tests/run-fleet-tests.ps1` only if behavior is testable

## Build Requirements

- one initial world snapshot
- tick 0 through tick 3 deterministic advancement
- two regions
- two factions
- three scheduled events
- faction clocks
- doom/default timeline track
- event log with evidence/canon labels

## Acceptance Criteria

- Tick output is deterministic and readable.
- Scheduled events fire only on configured ticks.
- Faction clocks advance predictably.
- Doom/default timeline advances without player intervention.
- Event log names state changes and evidence/canon status.
- Prototype text does not claim canon approval.
- Final files stay TSF-local.

## Tests

Run:

```powershell
git status --short
git diff --check
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
```

If adding focused tests, cover:

- tick 0 through tick 3
- scheduled event firing
- faction clock changes
- doom/default timeline changes
- evidence/canon labels

## Out Of Scope

- real Nytheria repo
- full engine
- AI GM
- lore rewriting
- canon migration
- deploy/install/migration/secrets
- proof run
- all-fleet command
- background runner
- push

## Stop Conditions

Stop if:

- Tim has not approved Slice 1 implementation
- a real Nytheria repo is needed
- a canon/lore decision is needed
- scope expands toward a full engine
- install, migration, deploy, secrets, proof run, all-fleet, background, push, or
  external account action is requested
- validation fails after one safe TSF-local repair attempt

## Final Report Format

Return:

- verdict
- files changed
- prototype summary
- tests run
- evidence/canon boundary confirmation
- final git status
- commit hash if created
- confirmation that no real Nytheria repo, product repo, deploy, install,
  migration, secrets, proof run, all-fleet command, background runner, or push
  occurred
