# TSF Game Forge V1

Evidence only; not executable authority or approval.

## What Game Forge Is

TSF Game Forge V1 is a local planning cockpit for game engine and prototype
creation. It turns messy creative game ideas into architecture notes, system
maps, prototype slices, research prompts, risk reviews, and bounded Codex work
orders.

Game Forge is especially useful for simulation-heavy ideas like Nytheria, a
high-magic, low-tech, faction-driven living fantasy world RPG / AI-assisted
world simulator previously called Nytheris.

## What Game Forge Is Not

- It is not a real game engine.
- It does not create or mutate a Nytheria game repo.
- It does not inspect private product repos.
- It does not approve canon rewrites.
- It does not install packages, deploy, push, migrate, touch secrets, add remote
  access, run all-fleet commands, or add executable browser controls.

## How Tim Uses It

1. Fill out `fleet/status/game-forge/templates/game-project-intake.md`.
2. Put old lore/root files in a TSF-local intake folder or attach them to a
   future prompt when explicitly needed.
3. Generate the Game Forge pack.
4. Read the risk review first.
5. Pick one prototype slice.
6. Copy one bounded game work order into Codex.

## Nytheria / Nytheris Source Handling

Nytheris remains an old name and backbone context for Nytheria. Old lore/root
files must be preserved as evidence, not freely rewritten. Game Forge separates:

- Evidence: old root files, notes, research, and prior names.
- Approved canon: decisions Tim has explicitly approved.
- Adaptation proposal: suggested changes that may fit Nytheria but are not canon
  yet.

AI can propose summaries, rumors, memory snippets, and adaptation ideas. AI must
not overwrite root lore, approved canon, save-state truth, or the player action
ledger without Tim approval.

## Why Toy Simulations Come First

A living-world RPG can become too large quickly. Toy simulations prove the engine
shape before costly systems exist. For Nytheria, the safe first path is:

1. Text-only world clock.
2. Faction turn simulator.
3. Rumor propagation simulation.
4. NPC memory toy model.
5. Default Timeline / Doom Clock.
6. Origin-based opening state generator.
7. Lore canon registry.

These slices make save/load, world state, consequences, and tests visible before
combat, graphics, multiplayer, AI game-master behavior, or a full content
pipeline.

## Outputs

- Intake template: `fleet/status/game-forge/templates/game-project-intake.md`
- Engine blueprints: `fleet/status/game-forge/blueprints/`
- Systems maps: `fleet/status/game-forge/system-maps/`
- Prototype slices: `fleet/status/game-forge/prototype-slices/`
- Research prompts: `fleet/status/game-forge/research-prompts/`
- Risk reviews: `fleet/status/game-forge/risk-reviews/`
- Game work orders: `fleet/status/game-forge/work-orders/`

## Regeneration

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\write-game-forge-pack.ps1 -IntakePath tests\fixtures\fleet\game-forge\nytheria-intake.md
```

Individual generators are available for blueprint, systems map, prototype
slices, research prompts, risk review, and game work orders.

## Codex Handoff Rule

Hand Codex one Game Forge work order at a time. Good work orders name one
planning artifact or one toy simulation. Bad work orders ask Codex to create a
complete living-world RPG engine in one pass.

Stop if real Nytheria files are needed but not attached, canon authority is
unclear, product repo access is required, or a task stops being a bounded
planning/prototype slice.
