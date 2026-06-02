# Anti-Loop Test Plan

Prepared: 2026-06-02

Scope: Codex Fleet / Thousand Sunny Fleet harness, docs, schemas, fixtures, and tests. This is a planning document only. It does not edit tests, add runtime instrumentation, implement telemetry, approve product-repo access, launch ships, run all-fleet commands, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

## Purpose

Future validation should prove that Codex Fleet can detect goal drift, repeated no-progress loops, stale packets, and unsafe "helpful" behavior before a run broadens itself. This plan describes those tests without implementing them.

## Fixture Location Recommendation

Use committed fixtures under `tests/fixtures/fleet/anti-loop/` for deterministic anti-loop validation.

Do not use `.codex-local` as the primary fixture source unless tracking intent is explicitly confirmed in a later bounded task. `.codex-local` may remain suitable for disposable run evidence, but committed regression fixtures should live under `tests/fixtures/fleet/`.

## Future Test Groups

### Goal Lock Field Coverage

Intent: verify that bounded run packets or summaries preserve `projectGoal`, `currentPhaseGoal`, `oneTaskGoal`, `nonGoals`, and `definitionOfDone`.

Suggested fixtures:

- valid one-task packet with all goal fields
- rejected packet missing `oneTaskGoal`
- rejected packet with broad or conflicting `definitionOfDone`

Expected result: validation accepts only packets that preserve the one-task finish line.

### Unchanged Fingerprints

Intent: catch repeated validation failures where the same normalized `failureFingerprint` and same hypothesis appear twice.

Suggested fixtures:

- first failure with a new hypothesis
- second failure with same fingerprint and same hypothesis
- second failure with same fingerprint but a different bounded hypothesis

Expected result: same fingerprint plus same hypothesis maps to pause, blocked, or repacketization rather than another blind retry.

### Doc Churn

Intent: detect repeated edits to docs that do not satisfy a new acceptance bullet.

Suggested fixtures:

- patch summary with wording changes only
- patch summary that maps changed sections to acceptance bullets
- repeated same-file edits with no validation change

Expected result: wording-only churn is reported as no-progress unless tied to acceptance.

### No-Op Edits

Intent: reject runs that claim progress from whitespace, heading movement, timestamp-only updates, or queue status changes without validation.

Suggested fixtures:

- no-op doc diff with claimed GREEN
- queue status changed to done without validation
- valid doc diff plus passing validation

Expected result: no-op changes cannot produce GREEN.

### File-Open Overrun

Intent: detect broad context expansion after the selected task is already known.

Suggested fixtures:

- run ledger with only active queue and `readFirst` files
- run ledger with raw audit reports and unrelated docs opened after scope lock
- run ledger with a blocked reason explaining why extra context was required

Expected result: unrelated broad reads produce drift or repacketization unless justified by a blocked reason.

### Goal Change

Intent: catch mid-run shifts from one task into UI design, commit scope, audit packaging, product strategy, or runtime implementation.

Suggested fixtures:

- `goalChanged: false` with unchanged selected task
- `goalChanged: true` with a new human objective
- summary that blends old and new goals without repacketization

Expected result: changed goals produce `deferredDueToChangedGoal`, `needsHumanReview`, or `needsRepacketization`.

### Ambiguous Acceptance

Intent: stop tasks that lack clear acceptance, allowed files, validation commands, or stop conditions.

Suggested fixtures:

- complete bounded task packet
- task missing `allowedFiles`
- task missing `validationCommands`
- task with broad acceptance like "make it perfect"

Expected result: ambiguous tasks are blocked before implementation.

### Repeated Unstuck

Intent: detect repeated "continue" attempts against a blocked task when no new packet, file, command, approval, or evidence changed.

Suggested fixtures:

- blocked run with a stable missing-file reason
- second run with no changed packet
- second run with a new bounded packet that resolves the missing file

Expected result: repeated unstuck without a new packet remains blocked.

### Idea Inbox Behavior

Intent: keep new ideas from hijacking implementation tasks.

Suggested fixtures:

- idea captured in an allowed planning surface
- idea introduced during implementation without allowed queue authoring
- idea converted into a future bounded queue entry by a planning task

Expected result: ideas are either captured where allowed or deferred; they do not change the active task.

## Future Assertion Themes

Future tests should assert:

- evidence-only artifacts never become authority
- product-repo access remains forbidden without exact human approval
- second tasks are not started after validation passes
- queue status updates target only the selected task
- same-fingerprint repeated failures do not trigger blind retry loops
- drift patterns map to `blocked`, `needsHumanReview`, or `needsRepacketization`
- validation commands must come from the selected task, plus schema parse checks only for schemas created or edited by that task

## Non-Goals For The Test Plan

- No edits to `tests/run-fleet-tests.ps1` in this task.
- No runtime telemetry, database, dashboard, worker, or automatic retry implementation.
- No product-repo fixtures that require touching real product repos.
- No launch, all-fleet, deploy, staging, commit, push, install, migration, secret, lock deletion, permission widening, or dirty-work revert scenarios beyond forbidden-boundary text fixtures.

## Future Implementation Order

1. Add committed fixtures under `tests/fixtures/fleet/anti-loop/`.
2. Add parser helpers for compact post-run summaries and progress ledgers.
3. Add tests for unchanged fingerprints and no-op status changes.
4. Add tests for file-open overrun and goal-change repacketization.
5. Add tests for idea inbox deferral.
6. Only after docs/fixtures/tests pass, consider whether runtime storage is needed in a separate approved task.

## Evidence-Only Boundary

This plan is a queue-planning artifact. It cannot approve test edits, runtime work, product-repo access, or future execution. A later task must list exact allowed files and validation commands before any test implementation begins.
