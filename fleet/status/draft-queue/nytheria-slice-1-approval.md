# Nytheria Slice 1 Approval Packet

Prepared: 2026-07-02

Draft only; not approved. The existing work order does not authorize implementation by itself.

## Proposed Toy Prototype

Build a TSF-local text-only Nytheria world clock toy prototype that proves a
tiny world can advance deterministically without becoming a full engine.

If approved, the implementation should live only under TSF-local toy paths such
as:

- `fleet/status/game-forge/prototypes/nytheria-text-world-clock.md`
- optional TSF-local fixture/test additions under `tests/fixtures/fleet/game-forge/`

## Slice 1 Scope

The toy prototype should include:

- deterministic tick 0 through tick 3 concept
- two regions
- two factions
- three scheduled events
- faction clocks
- doom/default timeline track
- event log with evidence/canon labels
- clear note that output is prototype evidence, not approved canon

## Tick Concept

- Tick 0: initial snapshot, no fired events yet.
- Tick 1: scheduled event 1 fires; faction clocks advance.
- Tick 2: scheduled event 2 fires; doom/default timeline warning appears.
- Tick 3: scheduled event 3 fires; default bad trajectory appears as prototype
  evidence only.

## Out Of Scope

- real Nytheria repo creation or mutation
- full engine
- AI game master
- lore rewriting
- canon migration from Nytheris to Nytheria
- graphics, combat, multiplayer, save/load production system
- deploy, install, migration, secrets, push, proof run, all-fleet command,
  remote access, background runner

## Exact Approval Language

```text
TIM_EXACT_APPROVAL:
action: implement Nytheria Slice 1 TSF-local text-only world clock toy prototype
repo/path: C:\Users\codex-agent\Documents\Vacation\Thousand-Sunny-Fleet
branch: current TSF main only
allowed command(s): edit TSF-local markdown/fixture/test files for Slice 1; git status --short; git diff --check; powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
max scope: TSF-local toy prototype only under fleet/status/game-forge/prototypes/ and focused TSF tests/fixtures if needed
stop conditions: real Nytheria repo needed, canon decision needed, full engine pressure, product repo access needed, install/migration/deploy/secrets/proof-run/all-fleet/background/push needed, validation fails after one safe repair
expires after: one Codex response
```

Implementation remains blocked until Tim sends exact approval.
