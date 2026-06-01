# Stage 2 Phase 7: Failure and Partial-Run Evidence

## Goal

Make failed, interrupted, or blocked runs leave honest partial evidence.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 2 Phase 7 only: Failure and partial-run evidence.

Do not implement any other Golden Gameplan phase.

Goal:
Ensure runs that fail before normal completion still write useful canonical
evidence when safe. Failed evidence is better than mystery silence.

Before editing:
- Run .\fleet-status.ps1.
- Review all exit paths in normal checkpoint and experiment runs.
- Identify paths that can currently exit before writing canonical evidence.

Scope:
- Likely files: run-checkpoint-loop.ps1, fleet-experiment.ps1,
  codex-fleet-runtime.ps1, tests/run-fleet-tests.ps1.
- Do not suppress failures to make evidence look green.
- Do not classify final decisions beyond simple failure status and decisionHint.

Required behavior:
- Build/test failure writes partial RUN_RESULT with failed check.
- Runtime verification failure writes partial RUN_RESULT with failed check.
- Model/no-output timeout writes partial RUN_RESULT when repo context is known.
- Safe-stop or rate-limit pause writes partial evidence when context is known.
- If evidence cannot be written, the parent script reports why.

Acceptance:
- Add tests for at least two failure paths producing partial evidence.
- Add tests proving failure evidence status is not marked success.
- Add tests proving errors/warnings are present.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/02-standard-run-evidence/checkpoint.md.

Stop if:
- Writing evidence in a failure path risks modifying dirty user work. In that
  case, report to fleet-root `out/` instead and document the exception.
```

## Why It Matters

Autonomy cannot recover from a failure it cannot see.

## Done When

Common failure paths leave evidence that can be audited or repaired.

