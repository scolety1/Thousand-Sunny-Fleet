# Budget Ledger And Safe-Pause Contract

This contract defines the durable budget and safe-pause record vocabulary used before provider-side rate automation exists. It is evidence, not permission, and it does not auto-resume ships, launch ships, call provider APIs, or mutate product repos.

## Purpose

Budget state must be explicit and auditable. A budget ledger record separates manual budget signal, provider budget signal, weekly reset preview pause, safe landing, resume eligibility, and review-note evidence so low-budget behavior fails closed instead of continuing model-heavy work.

Plain invariant: no auto-resume until approved.
Plain invariant: no budget state grants product launch permission.
Plain invariant: provider budget signal is optional and must not be invented.
Plain invariant: safe pause is a successful landing state, not failure hiding.

## Required Fields

Each budget safe-pause record must include:

- `schemaVersion`
- `budgetRecordId`
- `shipId`
- `budgetLevel`
- `decision`
- `manualBudgetSignal`
- `providerBudgetSignal`
- `thresholds`
- `resetAt`
- `pausedAt`
- `resumableShips`
- `nonResumableShips`
- `resumeEligibility`
- `reviewNotePath`
- `evidenceRefs`
- `validation`

`manualBudgetSignal` records user/operator-supplied budget state. `providerBudgetSignal` records provider-derived evidence only when it exists. Missing provider evidence must be represented as unknown, not guessed.

`reviewNotePath` points to the captain review note used during weekly reset preview pause. The default path is `docs/codex/WEEKLY_RESET_REVIEW_NOTES.md`.

## Budget Levels

| Level | Meaning |
| --- | --- |
| `unknown` | No reliable budget evidence exists. |
| `healthy` | Bounded work may be considered by later policy gates. |
| `cautious` | Status and light repair posture only. |
| `low` | Implementation is blocked. |
| `critical` | Safe landing is required. |
| `exhausted` | Wait for reset. |
| `reset_pending` | Reset is expected but not confirmed. |
| `recovered` | Budget recovered, but resume still needs eligibility and approval. |
| `weekly_low` | Weekly reset preview pause is required. |

## Decisions

| Decision | Meaning |
| --- | --- |
| `ALLOW_STATUS_ONLY` | Keep reporting available while blocking model-heavy work. |
| `ALLOW_BOUNDED_RUN` | Budget alone does not block, but product policy still must approve. |
| `BLOCK_NEW_WORK` | Stop new implementation work. |
| `SAFE_LAND_NOW` | Write evidence, preserve state, and pause safely. |
| `WAIT_FOR_RESET` | Stop model-heavy work until reset evidence exists. |
| `WEEKLY_PREVIEW_PAUSE` | Hold unfinished preview/evidence for captain review near weekly reset. |

## Thresholds

Stable threshold fields:

- `forecastWarningPercent`
- `lowBudgetPercent`
- `safeLandingPercent`
- `weeklyResetPausePercent`

Threshold values are evidence fields. Changing them does not by itself approve any action.

## Resume Eligibility

Resume eligibility must include:

- explicit selected ship
- clean or owned repo state
- valid resume metadata
- bounded approval
- state eligibility
- no taste, policy, or blocker gate
- reset confirmation when waiting for reset

`resumeEligibility` may be `eligible`, `ineligible`, or `unknown`. A recovered budget does not auto-resume ships.

## Fixture Names

The following fixture names are required for tests and later helper work:

- `SAFE_LAND_NOW`
- `WAIT_FOR_RESET`
- `WEEKLY_PREVIEW_PAUSE`
- `ALLOW_STATUS_ONLY`
- `manual-budget-signal`
- `provider-budget-signal`
- `resume-eligibility-required`
- `no-auto-resume-until-approved`

## Validation Rules

A valid budget safe-pause record must:

- include budget level and decision
- include manual budget signal
- include provider budget signal, even when it is `unknown`
- include thresholds
- include reset and pause timestamps or explicit empty values
- include resumable ships and evidence refs
- keep review-note path visible for weekly reset preview pause
- reject automatic resume without explicit approval and eligibility

## Documentation-Only Sample JSON

The following budget safe-pause sample is a fixture documentation example only. It is not a live runtime record, not permission to resume, and not an instruction to launch ships.

```json
{
  "schemaVersion": 1,
  "budgetRecordId": "budget-fixture-001",
  "shipId": "FixtureShip",
  "budgetLevel": "weekly_low",
  "decision": "WEEKLY_PREVIEW_PAUSE",
  "manualBudgetSignal": {
    "level": "weekly_low",
    "source": "manual",
    "capturedAt": "2026-05-30T12:00:00Z"
  },
  "providerBudgetSignal": {
    "status": "unknown",
    "remainingPercent": null,
    "weeklyRemainingPercent": null,
    "capturedAt": "unknown"
  },
  "thresholds": {
    "forecastWarningPercent": 20,
    "lowBudgetPercent": 10,
    "safeLandingPercent": 5,
    "weeklyResetPausePercent": 5
  },
  "resetAt": "2026-06-01T00:00:00Z",
  "pausedAt": "2026-05-30T12:00:00Z",
  "resumableShips": [],
  "nonResumableShips": [
    "FixtureShip"
  ],
  "resumeEligibility": "ineligible",
  "reviewNotePath": "docs/codex/WEEKLY_RESET_REVIEW_NOTES.md",
  "evidenceRefs": [
    "fixtures/budget-safe-pause/weekly-preview.json"
  ],
  "validation": {
    "status": "valid",
    "reasons": [
      "WEEKLY_PREVIEW_PAUSE",
      "no-auto-resume-until-approved"
    ]
  }
}
```

## Out Of Scope

This contract intentionally does not perform or approve:

- Provider API integration
- Auto-resume behavior
- Launching product ships
- Mutating product repos
- Running all-fleet commands
- Deleting locks
- Installing packages
- Running migrations
- Touching secrets, auth, payments, or deployment settings

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
