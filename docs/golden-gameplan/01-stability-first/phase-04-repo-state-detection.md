# Stage 1 Phase 4: Repo State Detection

## Goal

Distinguish clean, dirty, missing, and git-error repository states instead of
treating everything unusual as "dirty."

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 1 Phase 4 only: Repo state detection.

Do not implement any other Golden Gameplan phase.

Goal:
Refactor repo-state checks so missing repos, git command errors, clean repos, and
dirty repos are separate states with separate messages and decisions.

Before editing:
- Run .\fleet-status.ps1.
- Search for helpers like Test-RepoDirty or direct git status calls.
- Identify call sites that currently treat missing paths or git errors as dirty.

Scope:
- Likely files: fleet-experiment.ps1, fleet-status.ps1, fleet-doctor.ps1,
  fleet-supervisor.ps1, fleet-runner-watchdog.ps1, tests/run-fleet-tests.ps1.
- Add a small shared helper if the existing duplication is high, but keep the
  change focused.
- Do not clone missing repos automatically in this phase.
- Do not clean dirty repos.

Required behavior:
- Clean repo: reported as clean.
- Dirty repo: reported as dirty with changed files when available.
- Missing repo path: reported as missing, not dirty.
- Git error: reported as git-error with command context.
- Scripts that must block on dirty repos should block on dirty, missing, and
  git-error states with different explanations.

Acceptance:
- Add tests for clean, dirty, missing, and git-error repo states.
- Fleet status remains readable.
- Experiment runner and doctor use the more precise states where relevant.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/01-stability-first/checkpoint.md.

Stop if:
- Existing scripts depend on boolean dirty behavior in too many places. In that
  case, add compatibility output and document the migration path.
```

## Why It Matters

"Dirty" means user work exists. "Missing" means configuration or setup is wrong.
Those are different problems and should not trigger the same behavior.

## Tests To Add

- clean repo classification
- dirty repo classification
- missing repo classification
- git failure classification
- call sites preserve user work

## Done When

The fleet can explain repository state precisely enough to choose the right next
action.

