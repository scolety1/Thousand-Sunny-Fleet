# Golden Gameplan Stage 10: Overnight Mode

## Purpose

Stage 10 makes long unattended runs safer.

The user wants the fleet to work while they sleep or travel, but not waste rate limits, stall forever, or keep running after the useful work is done.

Stage 10 adds three core capabilities:

```text
Rate governor
Safe landing at low budget
Auto-resume after reset
```

This stage does not make the fleet reckless. It makes unattended work bounded, observable, and recoverable.

## Why This Matters

Past overnight-style runs had predictable problems:

- ships failed early and nobody noticed
- loops continued too long
- rate limits were drained without useful progress
- the fleet could not safely stop near limit exhaustion
- reset timing was not represented
- the user had to manually restart everything later

Stage 10 should give the fleet a sleep-safe mode:

```text
Run while useful.
Pause before limits get dangerous.
Save evidence.
Resume when allowed.
Stop for taste, blockers, or low-value churn.
```

## Stage 10 Outcome

At the end of Stage 10, the fleet should have:

- overnight run mode contract
- rate governor policy
- low-budget safe landing flow
- reset-window tracking
- auto-resume eligibility rules
- scheduled check cadence
- stale/failed ship handling
- final morning report
- strict limits to avoid infinite restarts

## Non-Goals

Do not implement these in Stage 10:

- mobile captain console
- production deployment
- automatic merge/push
- bypassing approval gates
- direct access to private account/rate-limit internals unless exposed by local status
- full self-directed product strategy

If rate-limit reset cannot be detected directly, Stage 10 should support configured reset windows and conservative manual overrides.

Configured reset windows are hints, not proof. Auto-resume must still check the
current local budget signal when one exists, the selected ship state, stop
requests, locks, and resume attempt count before launching more work.

## Core Concepts

### Rate Governor

The rate governor decides whether the fleet may start or continue model-heavy work.

It should consider:

- budget mode
- estimated remaining model budget
- low-budget threshold
- current run duration
- number of active ships
- model tier
- retry count
- whether useful work is still happening

### Safe Landing

Safe landing is the process of closing down cleanly before limits run out.

It should:

- stop launching new work
- let active safe units reach a checkpoint if possible
- request safe stop
- write state
- write run evidence
- package audit if useful
- mark ships `RATE_LIMIT_PAUSED`
- report exactly what can resume later

### Auto-Resume After Reset

Auto-resume should only happen when:

- reset time has passed or budget is confirmed recovered
- ship was paused safely
- repo is clean or active state is understood
- previous action was resumable
- max resume attempts are not exceeded
- no human taste gate, blocker, or explicit stop exists

If reset time is only configured manually, auto-resume should use conservative
mode and write a pre-resume report before taking action.

## Phase List

1. Overnight Mode Contract
2. Rate Governor Policy
3. Low-Budget Safe Landing
4. Reset Window and Resume Metadata
5. Auto-Resume Eligibility
6. Scheduled Check Cadence
7. Morning Report and Evidence
8. Stage 10 Integration Check

## Acceptance For Stage 10

Stage 10 is complete when:

- overnight mode has explicit budgets and stop rules
- rate governor can block new work near low budget
- safe landing writes evidence before stopping
- reset/resume metadata is recorded
- auto-resume requires eligibility checks
- stale failures do not restart forever
- final morning report is clear
- no hidden unbounded loop is introduced

## Hand-Off To Stage 11

Stage 11 will split the fleet into specialized lanes for websites, analytical software, deep coding, and personal apps.

## Implementation Notes

Status: GREEN as of 2026-05-27.

Implemented artifacts:
- `tools/codex-fleet-overnight.ps1` contains the Stage 10 contract, rate governor, safe-landing plan, resume eligibility check, and morning report formatter.
- `invoke-overnight-mode.ps1` runs a selected-scope dry-run or execute-plan pass and writes Markdown/JSON reports plus resume metadata when safe landing or reset wait is triggered.
- `tests/run-fleet-tests.ps1` contains focused Stage 10 fixture coverage.

Stage 10 intentionally does not create real recurring automations, phone commands, product launches, merges, pushes, deploys, or lock cleanup. Those remain outside this stage.
