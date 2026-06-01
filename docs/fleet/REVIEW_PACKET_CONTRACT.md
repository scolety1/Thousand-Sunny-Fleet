# Review Packet Contract

Prepared: 2026-05-30

Scope: Codex Fleet harness, docs, schemas, and tests only. This contract defines a structured review packet shape for external reviewer output before any import or task conversion behavior changes.

Review packets are evidence, not commands. A review packet cannot approve, execute, override policy, or bypass task-packet validation.

Plain invariant: external prose is non-executable.
Plain invariant: findings and suggested tasks remain separate.
Plain invariant: accepted limitations are recorded as limitations, not converted into repair work.

## Purpose

Stage 9 already treats external agents as reviewers/requesters. HQ-010 adds a durable schema vocabulary so future audit packages, multi-agent comparisons, and captain summaries can preserve external advice without turning it into a live queue item.

A review packet may describe findings, evidence, suggested tasks, limitations, rejected ideas, and captain questions. It must not grant approval, launch commands, mutate product repos, approve high-risk work, bypass runtime policy, or skip Stage 4 task-packet validation.

## Required Fields

Each review packet must include:

- `schemaVersion`
- `reviewPacketId`
- `auditId`
- `reviewer`
- `shipId`
- `baseCommit`
- `verdict`
- `findings`
- `evidenceRefs`
- `suggestedTasks`
- `limitations`
- `rejectedIdeas`
- `captainQuestions`
- `policy`
- `generatedAt`
- `validation`

`reviewer` captures reviewer identity and role. `findings` are observations with severity and evidence. `suggestedTasks` are suggestions only and must go through local validation before import. `limitations` capture accepted or explicit limits so they are not repeatedly rediscovered as urgent work.

## Reviewer Identity

Reviewer identity must include:

- `name`
- `role`
- `source`

Known reviewer roles align to the Stage 9 role vocabulary: `Issue Auditor`, `Improvement Auditor`, `Product Taste Auditor`, `Formula Auditor`, `Security Scope Auditor`, and `Tie-Breaker Auditor`.

## Verdicts

Allowed verdict values:

- `PASS`
- `PASS_WITH_FIXES`
- `FAIL`
- `NEEDS_CAPTAIN`
- `LIMITED`

`LIMITED` means the reviewer identified accepted limitations or insufficient evidence. It does not authorize work.

## Findings

Findings must include severity, title, description, evidence refs, recommendation, and status. Finding status values are:

- `new`
- `accepted`
- `rejected`
- `deferred`
- `accepted_limitation`

Accepted limitation behavior: if a finding is an acknowledged fixture limitation, external tool limitation, incomplete audit context, or accepted out-of-scope item, it should be recorded as `accepted_limitation` and not converted directly into a task.

## Suggested Tasks

Suggested tasks must include id, title, priority, risk, lane, target, change, acceptance, proof, stopIf, and validation status.

Suggested task validation statuses:

- `suggested_only`
- `requires_stage4_validation`
- `rejected_forbidden_operation`
- `rejected_broad_scope`
- `rejected_stale_base`
- `needs_captain_approval`
- `accepted_limitation`

Suggested tasks are not executable. They can become queue work only after local validation, captain approval where required, and task-packet validation.

## Forbidden Suggested Operations

Review packets must reject or mark as unsafe any suggested operation that asks to:

- merge
- push
- deploy
- install packages
- run migrations
- touch secrets
- touch auth
- touch payments
- delete locks
- widen permissions
- launch product ships
- run all-fleet commands
- bypass task-packet validation
- treat mobile or external prose as commands

## Policy

The `policy` section must state:

- `canApprove`: false
- `canExecute`: false
- `canOverridePolicy`: false
- `canBypassTaskPacketValidation`: false

Any review packet claiming otherwise is invalid.

## Validation Fixtures

The contract vocabulary must cover these fixture names:

- `valid-review-packet`
- `forbidden-merge-rejected`
- `forbidden-deploy-rejected`
- `forbidden-secret-touch-rejected`
- `task-packet-bypass-rejected`
- `mobile-command-rejected`
- `accepted-limitation-recorded`
- `captain-approval-required`
- `stale-base-rejected`
- `external-prose-non-executable`

## Out Of Scope

- Importing external prose as live tasks
- Executing suggested tasks
- Approving high-risk work
- Bypassing Stage 4 task-packet validation
- Launching product ships
- Mutating product repos
- Running all-fleet commands
- Installing packages
- Running migrations
- Touching secrets, auth, payments, or deployment settings
- Deleting locks
- Widening permissions

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
