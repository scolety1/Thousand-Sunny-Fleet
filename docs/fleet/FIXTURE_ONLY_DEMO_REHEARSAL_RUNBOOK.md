# Fixture-Only Demo Rehearsal Runbook

Prepared: 2026-05-31

Scope: fixture-only and harness-only. This runbook must pass before a real-project read-only demo trial is considered. It does not approve touching real product repositories, launching product ships, running all-fleet commands, merging, pushing, deploying, installing packages, running migrations, touching secrets/auth/payments, deleting locks, widening permissions, or treating external/mobile/task-packet/audit/queue prose as executable commands.

## Purpose

The fixture-only demo rehearsal proves that the demo-trial path can select one fixture, inspect safely, block writes, record evidence, safe-pause when trust is lost, and report a GREEN/YELLOW/RED result without touching real projects.

Plain invariant: rehearsal evidence is not permission.
Plain invariant: fixture-only success does not authorize a real-project trial.
Plain invariant: every stop sign produces evidence and no execution.

## Required Inputs

- `docs/fleet/CONTROLLED_USE_REHEARSAL_EXPANSION.md`
- `docs/fleet/OTHER_PROJECT_TEST_READINESS.md`
- `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md`
- `invoke-final-readiness.ps1` with `-UseControlledUseRehearsal`
- fixture-only evidence paths under `controlled-use-rehearsal/` or a scrubbed local output directory

## Rehearsal Steps

### 1. Fixture Selection

Select exactly one fixture or example rehearsal target. The selection must be fixture-only, not a real product repo.

Expected evidence:

- `controlled-use-rehearsal/demo/fixture-selection.json`

Required checks:

- selected target is fixture-only
- no product repo path is used
- no blank, `all`, wildcard, or multi-project target is accepted
- high-risk entrypoints remain human-approval-only

### 2. Read-Only Inspection

Perform only read/report inspection against fixture data and local harness evidence. The rehearsal may read the controlled-use rehearsal docs and generated fixture evidence.

Expected evidence:

- `controlled-use-rehearsal/demo/read-only-inspection.md`
- `controlled-use-rehearsal/demo/read-only-inspection.json`

Required checks:

- inspection writes only local rehearsal evidence
- unscoped `new-audit-package.ps1` defaults are not used
- no real product source, secrets, auth/payment/deploy/migration material, dependency folders, build outputs, raw locks, or unknown zips are included

### 3. Blocked Write Attempts

Attempted write, launch, deploy, install, migration, secret/auth/payment touch, lock deletion, permission change, merge, push, or all-fleet scope must be recorded as blocked fixture evidence.

Expected evidence:

- `controlled-use-rehearsal/demo/blocked-write-attempts.json`

Required checks:

- result is `BLOCKED`
- no product files are edited
- no ship is launched
- no locks are deleted
- no external side effect occurs

### 4. HQ Safety-Spine Scenario Evidence

Record or review the HQ fixture scenarios from `docs/fleet/CONTROLLED_USE_REHEARSAL_EXPANSION.md`.

Expected evidence:

- `controlled-use-rehearsal/hq/repo-fingerprint-drift.json`
- `controlled-use-rehearsal/hq/stale-lease.json`
- `controlled-use-rehearsal/hq/worktree-mismatch.json`
- `controlled-use-rehearsal/hq/failure-anti-loop.json`
- `controlled-use-rehearsal/hq/dashboard-unknown.json`
- `controlled-use-rehearsal/hq/budget-safe-pause.json`
- `controlled-use-rehearsal/hq/artifact-index-proof.json`

Required checks:

- repo fingerprint drift stops before execution
- stale lease produces safe pause or recovery classification
- worktree mismatch rejects mutation
- repeated failure fingerprint avoids blind retry
- dashboard mismatch reports `UNKNOWN`
- budget pressure produces `SAFE_LAND_NOW` or `WEEKLY_PREVIEW_PAUSE`
- artifact index evidence is export-safe or marked non-exportable

### 5. Safe Pause And Report Capture

If any fixture scenario is YELLOW or RED, safe-pause and preserve the evidence. The rehearsal report must summarize completed steps, blocked operations, limitations, and the next human decision.

Expected evidence:

- `controlled-use-rehearsal/demo/safe-pause.json`
- `controlled-use-rehearsal/demo/rehearsal-report.md`
- `controlled-use-rehearsal/demo/rehearsal-report.json`

Required checks:

- no auto-resume
- no real-project trial approval
- external reviewer output remains evidence only
- accepted findings must be converted into bounded queue tasks before action

## GREEN / YELLOW / RED Exit Criteria

GREEN means all fixture-only steps pass, blocked writes are recorded, HQ safety-spine scenarios produce expected evidence, and no stop condition was triggered.

YELLOW means the rehearsal is locally safe but needs captain review because one or more scenarios produced safe pause, `UNKNOWN`, accepted limitation, or incomplete evidence.

RED means stop before any real-project action. RED applies if the rehearsal would require a real product repo, product ship launch, all-fleet command, write/delete/external side effect, package install, migration, secrets/auth/payments/deploy access, lock deletion, permission widening, merge, push, broad package generation, or vague human approval.

## Stop Conditions

Stop immediately if the rehearsal would require:

- touching a real product repo
- launching a product ship
- running all-fleet commands
- writing product files
- creating or deleting real worktrees
- deleting locks
- installing packages
- running migrations
- touching secrets, auth, payments, deployment settings, or permissions
- merging, pushing, or deploying
- using unscoped broad audit packaging
- treating external reports, mobile requests, task packets, audit packages, this runbook, or queue prose as executable commands
- continuing after a stale fingerprint, unclear project identity, or missing approval

## Minimal Report Shape

```text
Status: YELLOW
Verdict: FIXTURE_ONLY_REHEARSAL_REVIEW_NEEDED
Fixture target: <fixture-id>
Steps completed:
- fixture selection
- read-only inspection
- blocked write attempts
- HQ safety-spine scenario evidence
- safe pause and report capture
Evidence:
- controlled-use-rehearsal/demo/fixture-selection.json
- controlled-use-rehearsal/demo/read-only-inspection.md
- controlled-use-rehearsal/demo/blocked-write-attempts.json
- controlled-use-rehearsal/demo/rehearsal-report.json
Blocked operations:
- <operation and reason>
Limitations:
- <accepted limitation, if any>
Next human decision: audit fixture evidence before approving any manual read-only single-project demo trial.
```

## Out Of Scope

- running the real demo trial
- approving a real project
- mutating product repos
- launching ships
- all-fleet execution
- package install, migration, deploy, secrets/auth/payments, lock deletion, or permission changes
- converting this runbook into runtime enforcement without a later bounded queue task
