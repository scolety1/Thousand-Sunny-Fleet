# Stage 1 Phase 7: Base Branch Configuration

## Goal

Stop assuming every project uses `main` as its base branch.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 1 Phase 7 only: Base branch configuration.

Do not implement any other Golden Gameplan phase.

Goal:
Add or honor per-project base branch configuration so fleet scripts do not
silently assume `main` for repositories that use `master`, feature branches, or
project-specific bases.

Before editing:
- Run .\fleet-status.ps1.
- Inspect projects.json for existing branch fields.
- Search for BaseBranch defaults and hardcoded main assumptions.

Scope:
- Likely files: projects.json, run-checkpoint-loop.ps1, launch scripts,
  fleet-doctor.ps1, tests/run-fleet-tests.ps1.
- Add config support in a backwards-compatible way.
- Do not rewrite project branches.
- Do not merge, rebase, reset, or checkout product repos.

Required behavior:
- Projects can define a base branch.
- Scripts use the configured base branch when available.
- Scripts validate that the branch exists before doing branch-sensitive work.
- If branch state is unsafe or unclear, scripts stop with a clear message.

Acceptance:
- Add tests for a project using a non-main base branch.
- Add tests for missing configured base branch.
- Existing tests still pass.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/01-stability-first/checkpoint.md.

Stop if:
- Existing project config has conflicting branch concepts. Document the conflict
  and propose a Stage 1 follow-up instead of guessing.
```

## Why It Matters

A wrong base branch can lead to confusing diffs, bad merge assumptions, or lost
trust in the fleet.

## Tests To Add

- configured non-main branch is respected
- missing branch blocks with clear error
- default behavior remains compatible for projects without config

## Done When

Branch-sensitive scripts stop guessing and start reading project configuration.

