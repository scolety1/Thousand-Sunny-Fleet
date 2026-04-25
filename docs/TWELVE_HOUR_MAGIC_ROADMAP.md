# Twelve-Hour Magic Roadmap

This roadmap defines what has to be true before Codex Fleet can be trusted for long unattended product runs.

## Roadmap 1 - Product Direction

- [x] Add `prepare-magic-run.ps1` to check whether a ship has a real 12-hour mission, work packs, and scorecard memory before launch.
- [x] Add starter `MAGIC_MISSION.md`, `WORK_PACKS.md`, and `MAGIC_SCORECARD.md` templates.
- [x] Fill those files for each real ship before long runs.
- [ ] Teach morning review to summarize whether each ship advanced its active work pack.

## Roadmap 2 - Coherent Work Selection

- [x] Feed `MAGIC_MISSION.md`, `WORK_PACKS.md`, and `MAGIC_SCORECARD.md` into Nami planning.
- [x] Tell Nami to prefer one active work pack over isolated polish.
- [x] Add explicit work-pack completion markers so Nami can move to the next pack without guessing.
- [x] Add a planner validation gate that rejects vague tasks when a work pack is active.

## Roadmap 3 - Before/After Quality Memory

- [x] Append `MAGIC_SCORECARD.md` after checkpoint-loop task outcomes.
- [x] Add screenshot before/after links to scorecard entries.
- [x] Ask Simon to grade whether the latest task improved the active work pack.
- [x] Auto-quarantine weak quality loops that fail Simon's active-pack score.

## Roadmap 4 - Long-Run Supervision

- [x] Upgrade `fleet-supervisor.ps1` from a dashboard into a watchdog that can classify ships as progressing, idle, blocked, or looping.
- [x] Add a safe restart path for planner/build/preview failures that does not touch active dirty work.
- [x] Add progress budgets so one ship cannot burn the whole night on repeated weak tasks.
- [x] Add morning digest grouping results by ship, work pack, commits, screenshots, and blockers.

## Roadmap 5 - Sophisticated Software

- [x] Require architecture approval for larger feature packs, backend work, integrations, migrations, auth, payments, and external APIs.
- [x] Add approved "bigger-change mode" task contracts for multi-file feature slices with stricter acceptance checks.
- [x] Add runtime scenario tests for real workflows, not just builds and screenshots.
- [x] Add dependency and package-change proposal lanes for approved non-frontend work.

## Honest Readiness

The fleet can now run longer with a stronger spine, but the magic still depends on each ship having a filled mission and work packs. Without those, the planner can still make safe progress, but it will drift toward small local polish instead of meaningful product leaps.
