# Combined Approval-Reconciliation Fixture Plan

Prepared: 2026-06-03

Scope: Codex Fleet / Thousand Sunny Fleet local harness, docs, schemas, fixtures, and tests only.

This plan defines future local fixture coverage for approval records combined with runtime policy decisions, failure fingerprints, and control-room reconciliation outcomes. It is evidence only. It does not approve execution, implement runtime behavior, inspect product repositories, create or send packages, bind runtime commands, run all-fleet commands, approve phone actions, launch demos, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

Plain boundary: this plan does not implement runtime behavior, does not inspect product repositories, and does not approve runtime command binding.

## Purpose

The combined fixture lane should prove that approval-like evidence does not become execution authority when other control-plane records disagree, go stale, repeat failures, or display `UNKNOWN`.

The fixtures described here are planned local JSON evidence only. They are not created by this task, and the plan is not a command input.

## Source Contracts

- `docs/fleet/REMOTE_APPROVAL_BOUNDARY.md`
- `docs/fleet/RUNTIME_POLICY_DECISION_CONTRACT.md`
- `docs/fleet/FAILURE_FINGERPRINT_CONTRACT.md`
- `docs/fleet/CONTROL_ROOM_RECONCILIATION_CONTRACT.md`
- `docs/fleet/SELECTED_PROJECT_READ_ONLY_GATE.md`

## Planned Combined Fixture Cases

| fixture case | approval boundary evidence | runtime decision | failure fingerprint posture | reconciliation posture | expected outcome |
| --- | --- | --- | --- | --- | --- |
| `valid-exact-action-read-only-evidence` | exact human owner, one target, one read-only/no-op action, fresh expiration | `ALLOW` with `ALLOW_DRY_RUN` | no repeated failure | `MATCH` | local planning evidence only; cannot execute or approve future work |
| `phone-only-denied` | phone-only approval-like evidence | `DENY` with `DENY_UNSAFE` | `policy-denial` or empty failure evidence | `UNKNOWN` | deny phone-only approval and block execution |
| `broad-target-denied` | approve-all, wildcard, comma-packed, or multi-target approval-like evidence | `DENY` with `DENY_UNSAFE` | `policy-denial` | `UNKNOWN` | deny broad scope and block execution |
| `reused-approval-denied` | copied, inherited, replayed, stale, or expired approval-like evidence | `DENY` with `DENY_UNSAFE` | `policy-denial` | `UNKNOWN` | deny reused approval and require fresh exact evidence |
| `write-capable-denied` | write-capable, package-sending, command-binding, product-repo, or external-side-effect action | `DENY` with `DENY_UNSAFE` | `policy-denial` | `UNKNOWN` | deny write-capable action and block execution |
| `failure-fingerprint-safe-pause` | otherwise plausible evidence paired with same normalized failure and same hypothesis twice | `DEFER` with `DEFER_NEEDS_HUMAN` | `safe-pause` with `blind-retry-forbidden` | `UNKNOWN` | safe-pause instead of retrying or approving |
| `reconciliation-unknown` | approval-like evidence conflicts with missing, stale, or mismatched DB/Git/run/snapshot evidence | `DEFER` with `DEFER_NEEDS_HUMAN` | optional `repair-task` or `safe-pause` | `UNKNOWN` | display `UNKNOWN` and block execution |

## Required Denial And Defer Vocabulary

Future fixtures should preserve this vocabulary without widening schemas unless a later bounded task explicitly allows that schema change:

- `deny_phone_only_approval`
- `deny_broad_scope`
- `deny_expired_or_reused`
- `deny_write_or_external_effect`
- `deny_forbidden_operation`
- `deny_evidence_as_authority`
- `missing-approval`
- `forbidden-scope`
- `policy-denial`
- `non-retriable-policy-denial`
- `safe-pause`
- `blind-retry-forbidden`
- `UNKNOWN`

## Fixture Safety Requirements

Every planned fixture must keep these booleans or equivalent posture fields false:

- `executesProductActions`
- `mutatesProductRepos`
- `readsProductRepos`
- `bindsRuntimeCommands`
- `createsOrSendsPackages`
- `runsAllFleet`
- `canApproveFutureRuns`
- `commandInput`

Every fixture must include a non-authority notice stating that the record is evidence only and cannot approve or execute work.

## Non-Authority Boundary

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Stop Conditions

Stop and repacketize if a future task needs runtime behavior, product-repo access, live repo inspection, package creation or sending, remote access, command binding, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, demo execution, or approval authority.

## Out Of Scope

- Creating the combined fixtures in this task.
- Implementing runtime behavior.
- Changing runtime policy evaluators.
- Widening schemas.
- Reading or touching product repositories.
- Creating or sending external audit packages.
- Turning approval-like evidence into command input.
