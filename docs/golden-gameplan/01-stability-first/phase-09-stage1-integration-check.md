# Stage 1 Phase 9: Stage 1 Integration Check

## Goal

Verify that all Stage 1 stability repairs work together and the fleet is ready
for Stage 2.

## Implementation Prompt

```text
Begin implementing Golden Gameplan Stage 1 Phase 9 only: Stage 1 integration check.

Do not implement any new fleet features.

Goal:
Run a full Stage 1 stability verification pass, patch only Stage 1 regressions,
and update the Stage 1 checkpoint with a clear ready/not-ready verdict.

Before editing:
- Run .\fleet-status.ps1.
- Review docs/golden-gameplan/01-stability-first/checkpoint.md.
- Confirm Phases 1-8 are marked complete or explicitly deferred.

Scope:
- Only patch regressions caused by Stage 1 work.
- Do not start Stage 2.
- Do not touch product repos.
- Do not add new architecture beyond Stage 1.

Required checks:
- .\tests\run-fleet-tests.ps1
- a targeted safe-stop isolation check
- a targeted experiment dry-run evidence check
- a targeted bounded-loop or timeout check if available
- a status check showing no accidental fleet launch

Acceptance:
- Stage 1 checkpoint has final status: GREEN, YELLOW, or RED.
- Any YELLOW items have explicit follow-up owner and stage.
- No RED item remains unless the user approves moving forward with known risk.
- The final response summarizes what is safe to do next.

Stop if:
- Tests fail in a way that is not clearly Stage 1 scope.
- A product repo is dirty and tempting to clean. Do not clean it.
```

## Why It Matters

Stage 2 will build canonical evidence. It should not start until the fleet's
basic stability path is trustworthy.

## Done When

Stage 1 has a clear integration verdict and a clean handoff to Stage 2.

