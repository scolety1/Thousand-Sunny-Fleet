# Stage 8.5 Phase 4: Low-Token Documentation

## Goal

Clarify what `LowTokenMode` does in Stage 8.5.

## Contract

`LowTokenMode` is a manual safety override in Stage 8.5. It blocks implementation actions such as `RUN_ONE_BATCH`.

It is not automatic rate-limit detection. Automatic low-budget detection, safe landing at thresholds, and auto-resume after reset belong to Stage 10.

Captain warning: do not treat `LowTokenMode` as proof that the fleet knows the real remaining model/rate budget. Until Stage 10, it is only a manual switch you set when you already know the run should stop doing implementation work.

## Best Practices

Use `LowTokenMode` when:

- the captain already knows model/rate budget is low
- a run should produce status only instead of implementation changes
- an audit/package/report can still be useful but new code would be wasteful
- the fleet is close to a planned safe stop

Do not use `LowTokenMode` as:

- proof that the fleet detected the real account budget
- a replacement for Stage 10 safe landing
- permission to continue a long run without rate evidence
- a way to bypass task, state, scope, or packet validation

Stage 10 adds configured/manual budget levels and safe-landing decisions. Later
stages may display those signals more clearly, but Stage 8.5 and Stage 9.5
remain manual. If the budget is unknown and the requested action is
model-heavy, the safe default is status-only reporting.

## Acceptance

- Wrapper behavior blocks implementation runs in low-token mode.
- Docs do not claim automatic rate-limit detection before Stage 10.

## Implementation Status

Status: GREEN

Documented here and verified by existing Stage 8/8.5 tests.
