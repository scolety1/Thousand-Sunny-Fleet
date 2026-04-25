# Codex Fleet Improvement Gameplan

This plan focuses on making Codex Fleet reliable enough for long school-day or overnight runs without turning it into an unsafe auto-merge system.

## Current State

The fleet can already:

- run small tasks one at a time
- build externally from PowerShell
- commit completed tasks on mission branches
- run checkpoint reviews
- run visual inspection
- run Simon design reviews
- run Joey security reviews
- feed Simon, visual bugs, and Joey back into Nami's next-task planning
- use per-ship and per-role fallback model chains
- use hard timeout watchdogs around Codex, build, planner, checkpoint, visual, Simon, Joey, debug, and guardrail steps
- detect likely Codex usage/rate-limit responses and wait for a configured cooldown before retrying
- write per-step watchdog logs under `.codex-logs/`
- use dynamic visual ports
- avoid `git add .`
- block unresolved P1/P2 review findings
- write a basic supervisor report
- write a merge-readiness report with one merge/no-merge answer per ship
- write a local visual screenshot gallery for faster morning inspection
- include visual, Simon, Joey, changed-file, completed-task, and next-batch guidance in checkpoint reviews
- run deterministic script-level tests against disposable fixture ships

The system is now useful, but it still needs stronger recovery and operator controls before it is truly comfortable for all-day unattended runs.

## Priority 1 - Reliability

### 1. Fallback model chain - done

Problem:
Codex Fleet can choose a model per ship and bot, but it does not automatically fall back when the configured model is unavailable, overloaded, or returns a transient failure.

Target:
Support config such as:

```json
"models": {
  "implement": ["gpt-5.5", "gpt-5.4", "gpt-5.3-codex"],
  "review": ["gpt-5.5", "gpt-5.4"],
  "planner": ["gpt-5.5", "gpt-5.4"]
}
```

Expected behavior:
Try the first model. If Codex exits without repo changes or useful output, retry with backoff, then try the fallback model.

### 2. Hard timeout watchdog - done

Problem:
A stuck Codex call, build, dev server, visual inspect, or Chrome process can waste hours.

Target:
Wrap long-running steps with timeouts:

- Codex implement/review: configurable, default 20-30 minutes
- build: configurable, default 10 minutes
- visual inspect: configurable, default 8-12 minutes
- Simon/checkpoint/Nami: configurable, default 10 minutes

Expected behavior:
Kill the process tree, write a clear report, retry if safe, otherwise stop cleanly.

### 3. Fleet doctor preflight

Problem:
Before launching, the captain needs one command that says which ships are safe to run.

Target:
Create `fleet-doctor.ps1`.

Checks:

- repo exists
- branch status
- dirty working tree
- untracked risky files
- build command configured
- profile exists
- visual paths configured
- last checkpoint verdict
- last Simon/Joey verdict
- current task count
- exact recommended next command

## Priority 2 - Review Quality

### 4. Merge readiness report - done

Problem:
Morning review still requires jumping between reports.

Target:
Create `merge-readiness.ps1`.

Output:

- SAFE TO INSPECT
- SAFE TO MERGE
- DO NOT MERGE

Reasons should include build result, dirty state, blocked files, Joey verdict, visual bugs, Simon verdict, checkpoint verdict, and branch divergence.

### 5. Screenshot gallery - done

Problem:
Visual artifacts exist, but reviewing them is clunky.

Target:
Generate `out/visual-gallery.html` or `docs/codex/VISUAL_GALLERY.md` with links/thumbnails for latest desktop and mobile screenshots per route.

Expected behavior:
One morning file shows the latest screenshots for each ship.

### 6. Better checkpoint summaries - done

Problem:
Checkpoint reports are useful but not always decisive.

Target:
Make checkpoint reports include:

- completed tasks in the batch
- files changed in the batch
- build status
- visual status
- Simon status
- Joey status
- recommended next batch size
- whether the next tasks are repair-first or mission-forward

## Priority 3 - Launch Experience

### 7. Launch presets - done

Problem:
The best commands are too long to remember.

Target:
Create preset scripts:

- `launch-proof-run.ps1`
- `launch-school-run.ps1`
- `launch-overnight-run.ps1`

Each preset should call `fleet-doctor.ps1` first and refuse unsafe launches unless explicitly overridden.

Implemented presets:

- `launch-proof-run.ps1`
- `launch-school-run.ps1`
- `launch-overnight-run.ps1`

Each preset launches checkpoint loops, not legacy ship-local loops, and passes rate-limit cooldown settings through to the loop.

### 8. Ship recovery helper

Problem:
Interrupted runs can leave a valid change unmarked and uncommitted.

Target:
Create `recover-interrupted-task.ps1`.

Behavior:

- detect dirty files
- identify first unchecked task
- run guardrails
- run build
- show changed files
- optionally mark task complete, append report, and commit

This should be interactive by default and unattended only with an explicit `-ConfirmRecovery` switch.

## Priority 4 - Test Harness

### 9. Script-level tests - done

Problem:
Fleet changes are getting complex enough that syntax checks are not enough.

Target:
Add lightweight tests for:

- task detection regex
- task completion marking
- model config resolution
- visual path config resolution
- safe staging logic
- review finding parser
- dirty-file guards for read-only bots

These can be PowerShell tests without adding heavy dependencies.

Implemented as:

```powershell
.\tests\run-fleet-tests.ps1
```

The suite validates task parsing, task completion regex, model-chain config, visual path config, rate-limit detection, watchdog process handling, review finding parsing, safe staging behavior, read-only dirty guards, doctor readiness, merge readiness, and checkpoint debugging.

### 10. Fixture ships - done

Problem:
Testing against real ships is useful but noisy.

Target:
Create tiny fixture repos under `.codex-local/fixtures/` or generated temp folders:

- static frontend fixture
- docs-only fixture
- real-product-like fixture

Use them to test fleet logic without risking real repos.

Implemented through `tests/new-fixture-ships.ps1`; generated repos live under ignored `.codex-local/fixtures/`.

## Recommended Build Order

1. `fleet-doctor.ps1` - done
2. timeout watchdog - done
3. fallback model chain - done
4. launch presets - done
5. recover interrupted task helper - done
6. merge readiness report
7. screenshot gallery
8. script-level tests - done
9. fixture ships - done

## Operating Rule

The fleet may automate work, review, and checkpoint pushes, but it should not merge to main without the captain.

All future upgrades should preserve that rule.
