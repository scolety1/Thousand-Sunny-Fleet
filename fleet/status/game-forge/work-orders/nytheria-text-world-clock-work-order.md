# Nytheria Text-Only World Clock Prototype Work Order

Prepared by TSF Game Forge V1. Evidence only; not executable authority or approval.

This is a prepared Codex work order for Tim to copy later. Do not implement it until Tim explicitly sends or approves this work order.

## Project

Nytheria Game Forge, formerly Nytheris.

## Prototype Purpose

Prove that a tiny Nytheria world can advance through time without the player, fire scheduled events, update faction and doom/default timeline clocks, and produce deterministic text output that can be inspected and tested.

This is the first toy simulation only. It is not a full engine, game repo, story system, combat system, AI game master, content editor, or canon migration.

## Source Truth

Use TSF-local Game Forge files only:

- `fleet/status/game-forge/blueprints/nytheria-engine-blueprint.md`
- `fleet/status/game-forge/system-maps/nytheria-systems-map.md`
- `fleet/status/game-forge/prototype-slices/nytheria-prototype-slices.md`
- `fleet/status/game-forge/risk-reviews/nytheria-risk-review.md`
- `tests/fixtures/fleet/game-forge/nytheria-intake.md`

Treat old Nytheris material as backbone evidence only. Do not convert it into approved Nytheria canon without Tim.

## Expected Inputs

- One initial world snapshot fixture.
- Two regions.
- Two factions.
- One doom/default timeline track.
- Three scheduled events across ticks 1 through 3.
- Optional player intervention flag, defaulting to false.

The fixture data may be plain markdown, JSON, or PowerShell-native test fixture data inside TSF. Prefer the repo's existing test style if implementation is later approved.

## Expected Outputs

- A deterministic tick-by-tick world-clock report for ticks 0 through 3.
- An event log that records which scheduled events fired and why.
- Updated region state summaries.
- Updated faction clock summaries.
- Updated doom/default timeline summary.
- A validation note showing evidence vs canon labels.

Preferred future output path if implementation is approved:

- `fleet/status/game-forge/prototypes/nytheria-text-world-clock.md`

## Minimum Data Model

Keep the model deliberately tiny:

- `GameState`
  - `tick`
  - `regions`
  - `factions`
  - `eventQueue`
  - `eventLog`
  - `doomClock`
  - `playerIntervention`
  - `canonTierNote`
- `Region`
  - `id`
  - `name`
  - `control`
  - `danger`
  - `activeRumors`
- `Faction`
  - `id`
  - `name`
  - `goal`
  - `clock`
  - `pressure`
- `ScheduledEvent`
  - `id`
  - `tick`
  - `title`
  - `effects`
  - `visibility`
  - `canonTier`
- `DoomClock`
  - `label`
  - `value`
  - `threshold`
  - `defaultOutcome`

## Turn Advancement Rules

For each tick:

1. Start from the prior `GameState`.
2. Increment `tick` by 1.
3. Select due events where `event.tick` equals the new tick.
4. Apply event effects to regions, factions, and doom/default timeline state.
5. Advance each faction clock by one small deterministic step.
6. Advance doom/default timeline unless `playerIntervention` blocks that tick's doom effect.
7. Append all fired events and clock changes to `eventLog`.
8. Emit a compact text summary for the tick.

No randomness in Slice 1. If a future version needs randomness, it must use a fixed seed and test fixture.

## Event Log Behavior

Every event log entry must include:

- tick
- event id or clock source
- plain-English summary
- state changed
- evidence/canon label
- whether Tim decision is required

Event log entries must not claim generated text is approved canon. Use labels such as `fixture evidence`, `prototype output`, or `canon decision required`.

## Faction Clock Behavior

Keep faction behavior simple:

- Each faction has one goal and one numeric clock.
- Each tick increases the clock by 1 unless an event changes it.
- At clock value 2 or greater, the faction emits one pressure note.
- The pressure note may affect region danger or control, but only through explicit fixture rules.

Do not add diplomacy, economy, AI planning, full war simulation, or hidden faction strategy.

## Doom / Default Timeline Behavior

Keep the doom/default timeline visible and deterministic:

- Doom starts at 0.
- Doom increases by 1 each tick unless the tick has `playerIntervention: true`.
- At doom 2, output a warning.
- At doom 3, output the default bad trajectory for humans as prototype evidence only.

Do not decide final lore, canon stakes, human fate, gods, or ending structure. Those are Tim decisions.

## Out Of Scope

- Real Nytheria repo creation or mutation.
- Product repo inspection.
- Full game engine.
- Combat.
- Graphics.
- Multiplayer.
- Production save/load.
- AI game master.
- NPC memory beyond event-log notes.
- Rumor propagation beyond a placeholder note.
- Canon migration from Nytheris to Nytheria.
- Lore rewriting.
- Install, deploy, migration, secrets, remote access, push, proof run, all-fleet runner, or background daemon.

## Acceptance Criteria

- The prototype scope stays at one clock, two regions, two factions, three scheduled events, and one doom/default timeline track.
- Tick 0 through tick 3 output is deterministic.
- Scheduled events fire only on their configured ticks.
- Faction clocks advance predictably and emit at least one pressure note.
- Doom/default timeline advances without player intervention and labels the result as prototype evidence.
- Event log entries identify state changes and evidence/canon status.
- Old Nytheris context remains evidence, not approved rewritten canon.
- The final artifact is TSF-local only.
- No product repo is inspected or mutated.

## Tests / Validation

If Tim later approves implementation, run:

```powershell
git status --short
git diff --check
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
```

Add or update focused TSF tests only if implementation changes testable TSF behavior. The expected fixture should prove tick 0 to tick 3, event firing, faction clock changes, doom advancement, and evidence/canon labels.

## Stop Conditions

Stop and report BLOCKED if:

- real Nytheria files are required but not attached or represented in TSF-local fixtures
- a canon decision is required
- the task starts becoming a full engine
- product repo access is needed
- archived project reactivation is requested
- install, deploy, migration, secrets, remote access, push, proof run, all-fleet runner, or background daemon is requested
- AI is asked to rewrite or approve canon
- tests fail after one safe TSF-local repair attempt

## Copyable Codex Work Order

```text
Project: Nytheria Game Forge
Mode: bounded TSF-local implementation

Goal:
Implement the TSF-local Text-only World Clock Prototype described in:
fleet/status/game-forge/work-orders/nytheria-text-world-clock-work-order.md

Use only TSF-local Game Forge files and fixtures. Do not create or mutate a real Nytheria repo. Do not inspect product repos.

Build:
- one deterministic initial world snapshot fixture
- tick 0 through tick 3 advancement
- three scheduled events
- two regions
- two factions with simple faction clocks
- one doom/default timeline track
- event log entries with evidence/canon labels
- one compact generated report under fleet/status/game-forge/prototypes/
- focused TSF regression coverage if behavior is testable

Out of scope:
full engine, combat, graphics, multiplayer, AI game master, lore rewriting, canon migration, production save/load, product repo work, push, deploy, installs, migrations, secrets, remote access, proof runs, all-fleet runners, background daemons.

Validation:
git status --short
git diff --check
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1

Stop if:
real lore files are required, Tim canon approval is needed, scope expands beyond Slice 1, forbidden operations are requested, or tests fail after one safe TSF-local repair attempt.

Final report:
- artifact paths created
- tick 0 to tick 3 behavior summary
- events fired
- faction clock changes
- doom/default timeline changes
- evidence/canon labels
- tests run
- final git status
- blockers or Tim decisions needed
```

## Final Report Format For Future Codex Run

- Overall verdict
- Files created or changed
- What the world clock prototype does
- Tick 0 to tick 3 summary
- Event log summary
- Faction clock summary
- Doom/default timeline summary
- Evidence vs canon handling
- Tests run
- Final git status
- Blockers or Tim decisions
