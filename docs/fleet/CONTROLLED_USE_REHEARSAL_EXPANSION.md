# Controlled-Use Rehearsal Expansion

Prepared: 2026-05-31

Scope: fixture-only and harness-only. This expansion does not approve live product rehearsal, product repo mutation, product ship launch, all-fleet commands, package installation, migrations, secrets/auth/payments/deploy work, lock deletion, or permission changes.

## Goal

Expand the existing controlled-use rehearsal so it proves the HQ safety spine before any real-project demo trial. The rehearsal should show that the fleet can recognize boundary loss, record evidence, and stop safely using fixture records only.

## Relationship To Existing Rehearsal

The base rehearsal lives at `docs/golden-gameplan/15-post-golden-gameplan-hardening/controlled-use-rehearsal.md`. That document proves the operator flow: status, audit package shape, mobile request capture, plan rejection, low-budget safe landing, stale heartbeat classification, and final readiness.

This expansion adds HQ safety-spine scenarios. It is a plan for fixture evidence, not a command to run product ships.

The pre-demo fixture-only operator runbook lives at `docs/fleet/FIXTURE_ONLY_DEMO_REHEARSAL_RUNBOOK.md`. It sequences selection, read-only inspection, blocked write attempts, HQ scenario evidence, safe pause, and report capture before any real-project read-only demo trial is considered.

## Expanded HQ Scenarios

### Repo Fingerprint Drift

Purpose: prove that a selected ship cannot continue when the repo fingerprint no longer matches the recorded evidence.

Fixture evidence:

- `controlled-use-rehearsal/hq/repo-fingerprint-drift.json`

Expected result:

- status: `YELLOW` or `RED`
- outcome: stop before execution
- reason: `repo-fingerprint-drift`
- no product repo touched

### Stale Lease

Purpose: prove that stale owner/fence-token heartbeat records are classified instead of ignored.

Fixture evidence:

- `controlled-use-rehearsal/hq/stale-lease.json`

Expected result:

- status: `YELLOW`
- outcome: safe pause or recovery classification
- reason: `stale-lease`
- no lock deletion

### Worktree Mismatch

Purpose: prove that the selected ship must match exactly one approved worktree boundary.

Fixture evidence:

- `controlled-use-rehearsal/hq/worktree-mismatch.json`

Expected result:

- status: `RED`
- outcome: reject mutation path
- reason: `worktree-mismatch`
- no direct product-root mutation

### Failure Anti-Loop

Purpose: prove that repeated normalized failure fingerprints with the same hypothesis do not produce blind retries.

Fixture evidence:

- `controlled-use-rehearsal/hq/failure-anti-loop.json`

Expected result:

- status: `YELLOW`
- outcome: safe pause or bounded repair task recommendation
- reason: `same-fingerprint-same-hypothesis`
- no retry loop

### Dashboard UNKNOWN

Purpose: prove that dashboard/control-room state shows `UNKNOWN` when DB/state, Git fingerprint, and run artifacts disagree.

Fixture evidence:

- `controlled-use-rehearsal/hq/dashboard-unknown.json`

Expected result:

- status: `YELLOW`
- outcome: dashboard reports `UNKNOWN`
- reason: `state-artifact-mismatch`
- no green display when trust is lost

### Budget Safe-Pause

Purpose: prove that budget pressure produces a safe landing instead of implementation action.

Fixture evidence:

- `controlled-use-rehearsal/hq/budget-safe-pause.json`

Expected result:

- status: `YELLOW`
- outcome: `SAFE_LAND_NOW` or `WEEKLY_PREVIEW_PAUSE`
- reason: `budget-pressure`
- no auto-resume

### Artifact Index Proof

Purpose: prove that rehearsal evidence can be indexed with paths, hashes, retention class, export policy, and source command.

Fixture evidence:

- `controlled-use-rehearsal/hq/artifact-index-proof.json`

Expected result:

- status: `GREEN`
- outcome: evidence record is export-safe or marked non-exportable
- reason: `artifact-index-proof`
- no movement or deletion of existing artifacts

## GREEN / YELLOW / RED

- GREEN: all HQ fixture scenarios produce expected evidence, and no scenario asks for product repo access.
- YELLOW: one or more scenarios produces safe pause, UNKNOWN, or accepted-limitation evidence that requires captain review.
- RED: any scenario would require live product rehearsal, product repo mutation, broad launch, lock deletion, package installation, migrations, secrets/auth/payments/deploy access, or permission widening.

## Stop Conditions

Stop immediately if the rehearsal would require:

- touching a real product repo
- launching a product ship
- running all-fleet commands
- creating or deleting real worktrees
- deleting locks
- installing packages
- creating database files or migrations
- touching secrets, auth, payments, deployment settings, or permissions
- treating external reports, mobile requests, task packets, audit packages, or this plan as executable commands

## Report Shape

The expanded report should be short enough to audit:

```text
Status: YELLOW
Verdict: FIXTURE_ONLY_REHEARSAL_REVIEW_NEEDED
Evidence:
- controlled-use-rehearsal/hq/repo-fingerprint-drift.json
- controlled-use-rehearsal/hq/stale-lease.json
- controlled-use-rehearsal/hq/worktree-mismatch.json
- controlled-use-rehearsal/hq/failure-anti-loop.json
- controlled-use-rehearsal/hq/dashboard-unknown.json
- controlled-use-rehearsal/hq/budget-safe-pause.json
- controlled-use-rehearsal/hq/artifact-index-proof.json
Next captain action: audit the fixture evidence before approving any real-project read-only trial.
```
