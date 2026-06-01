# Rate Governor And Model Budget State

Rate limits and model budget are fleet state. They should never arrive as a surprise crash halfway through an overnight run.

## Signals

The governor separates three different budget warnings:

| Signal | Default | Meaning | Action |
| --- | ---: | --- | --- |
| forecast warning | `20%` | projected budget may run low before the next check | status and light repair only |
| actual threshold warning | `10%` | current budget is low | block implementation actions |
| hard-stop imminent | `0%` | budget is exhausted | wait for reset |
| safe landing | `3%` | budget is critically low | safe land now |
| weekly reset preview pause | `5%` | weekly budget is almost gone | pause unfinished work and hold preview |

## Threshold Choosing Rules

- Keep `safeLandingThresholdPercent` lower than `lowBudgetThresholdPercent`.
- Keep `weeklyResetPauseThresholdPercent` around `5` unless the captain chooses more buffer.
- Use a higher `forecastWarningThresholdPercent` for long overnight runs.
- Use conservative thresholds when multiple ships are active.
- If provider-side detection is not available, mark the signal as manual/configured and do not claim automatic detection.

## Model Tiering By Task Class

| Task class | Normal tier | Low budget behavior |
| --- | --- | --- |
| status | cheap-status | allowed |
| audit | cheap-status | allowed if package exists |
| maintenance | cheap-status | allowed for docs/status only |
| repair | cheap-repair | allowed only for light repair during forecast warning |
| implementation | balanced | blocked at low budget |
| taste | premium-review-only | review-only, no implementation |
| backend-sensitive | premium-review-only | review-only unless explicitly approved |

## Concurrency Caps

- Unknown, low, critical, weekly-low, and exhausted budget: `maxConcurrentShips = 1`.
- Healthy budget: at most `2` by default.
- Product work still requires explicit ship selection.
- No budget state may imply product launch permission.

## Resume After Reset

`resumeAfterReset` may become true only when reset is confirmed, but it is not enough by itself. Resume still requires:

- explicit ship selection,
- clean/owned repo state,
- valid resume metadata,
- bounded approval,
- state eligibility,
- no taste/policy/blocker gate.

## Manual Low-Token Mode

Manual low-token mode is a safety override. It blocks implementation actions and keeps status/audit reporting available. It is not automatic provider-side detection.

## Phone Digest Language

A phone-readable digest should distinguish:

- forecasted exhaustion,
- current budget threshold,
- hard stop,
- weekly reset preview pause,
- next captain action.
