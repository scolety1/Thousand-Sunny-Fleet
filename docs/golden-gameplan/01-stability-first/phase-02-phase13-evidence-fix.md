# Stage 1 Phase 2: Phase 13 Evidence Fix

## Goal

Fix the current Phase 13 experiment-runner failure so experiments always write
the expected Markdown and JSON evidence, including dry runs and blocked runs.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 1 Phase 2 only: Phase 13 evidence fix.

Do not implement any other Golden Gameplan phase.

Goal:
Repair the experiment runner evidence path so valid dry-run manifests produce
both Markdown and JSON evidence. Failed or blocked experiments should still
produce useful failure evidence when safe.

Before editing:
- Run .\fleet-status.ps1.
- Run .\tests\run-fleet-tests.ps1 and confirm the Phase 13 failure still
  reproduces or identify whether Phase 1 already changed it.
- Inspect fleet-experiment.ps1 and the Phase 13 tests.

Scope:
- Focus on fleet-experiment.ps1 and tests/run-fleet-tests.ps1.
- Touch shared helpers only if evidence path resolution requires it.
- Do not create the full Stage 3 audit package system.
- Do not change product repos.

Required behavior:
- A valid dry-run manifest exits successfully.
- The experiment runner writes Markdown evidence.
- The experiment runner writes JSON evidence.
- Evidence paths resolve under the fleet root unless explicitly overridden.
- If a run cannot proceed, the runner writes a failure report instead of leaving
  no evidence.

Acceptance:
- The existing failing Phase 13 tests pass.
- Add or update tests for evidence written on valid dry run.
- Add or update tests for evidence written on blocked run when safe.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/01-stability-first/checkpoint.md.

Stop if:
- The fix requires inventing the full RUN_RESULT.json schema from Stage 2.
- The experiment runner cannot identify a safe output directory without a larger
  path-normalization change. If so, document the blocker and stop.
```

## Why It Matters

Autonomy depends on evidence. A failed experiment with no report leaves the user
and the fleet guessing.

## Tests To Add

- valid dry-run manifest writes `.md`
- valid dry-run manifest writes `.json`
- blocked run writes failure evidence where possible
- refresh mode can find the written evidence

## Done When

The Phase 13 evidence tests pass and a failed experiment no longer disappears
without proof.

