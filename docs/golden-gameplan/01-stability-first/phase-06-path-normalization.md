# Stage 1 Phase 6: Project Path and Output Path Normalization

## Goal

Reduce hardcoded path and relative-output failures by resolving paths from the
fleet root and project configuration.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 1 Phase 6 only: Project path and output path normalization.

Do not implement any other Golden Gameplan phase.

Goal:
Make fleet scripts resolve project paths, manifest paths, and output paths from
the fleet root or projects.json instead of relying on hardcoded local paths or
the caller's current working directory.

Before editing:
- Run .\fleet-status.ps1.
- Search for hardcoded C:\Dev paths.
- Search for default output paths that are relative to the caller's working directory.
- Search for path strings with embedded backslashes where Join-Path should be used.

Scope:
- Likely files: watch-easylife-phase-autopilot.ps1, fleet-experiment.ps1,
  launch scripts, path helper functions, tests/run-fleet-tests.ps1.
- Prefer backwards-compatible parameters with config-derived defaults.
- Do not attempt full Linux portability in this phase unless the local tests
  already support it.

Required behavior:
- Scripts with project-specific behavior can resolve the repo from projects.json
  or an explicit parameter.
- Experiment default output paths land under the fleet root.
- Running key scripts from a different current directory does not scatter output.
- Path changes preserve existing Windows behavior.

Acceptance:
- Add tests that invoke relevant scripts from outside the fleet root and verify
  outputs still land under the fleet root.
- Add tests or static checks for removed hardcoded C:\Dev path where feasible.
- Run .\tests\run-fleet-tests.ps1.
- Update docs/golden-gameplan/01-stability-first/checkpoint.md.

Stop if:
- A script is intentionally one-off and hardcoded. Document it in the checkpoint
  rather than broadening scope.
```

## Why It Matters

Autonomy should not depend on which terminal directory happened to launch a
script.

## Tests To Add

- experiment outputs resolve under fleet root from external cwd
- configured project path is used instead of hardcoded path
- explicit path parameters still work

## Done When

Fleet paths are predictable and evidence does not scatter into random folders.

