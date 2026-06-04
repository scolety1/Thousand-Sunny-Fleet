# Selected-Project Read-Only Gate

Prepared: 2026-06-03

Scope: Codex Fleet / Thousand Sunny Fleet local harness, docs, schemas, fixtures, and tests only.

This gate is evidence only. It does not approve product-repo access, product-repo mutation, package creation, package sending, remote access, runtime command binding, all-fleet execution, phone approvals, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, demo trials, or future authority.

## Purpose

The selected-project read-only gate defines the minimum evidence shape for a future controlled demo or audit check that needs to talk about one selected project without approving any product mutation. It is a local planning and validation artifact, not a launcher input.

The gate exists to fail closed when a target is broad, stale, write-capable, missing an owner, phone-only, package-oriented, command-bound, or otherwise not read-only.

## Required Fields

Each gate record must include:

- `schemaVersion`
- `gateId`
- `selectedTarget`
- `owner`
- `repoFingerprintRef`
- `readOnlyActions`
- `expiresAt`
- `stopConditions`
- `evidenceRefs`
- `nonAuthorityNotice`
- `validation`

`selectedTarget` must name exactly one project or ship and must record whether the target is single-target only. Blank, `all`, `*`, wildcard, comma-packed, or multi-project targets are denied.

`owner` must name the human/accountable owner for the gate. Missing owner denies the record.

`repoFingerprintRef` must point to current local evidence for the selected target. Missing or stale fingerprint evidence denies or defers the record.

`readOnlyActions` may describe inspection or reconciliation actions only. It must not contain write-capable operations, package sending, runtime command binding, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, or permission widening.

## Allowed Read-Only Action Vocabulary

- `READ_STATUS`
- `READ_REPO_FINGERPRINT`
- `READ_VALIDATION_SUMMARY`
- `READ_AUDIT_EVIDENCE`
- `READ_CONTROL_ROOM_SNAPSHOT`
- `READ_DRY_RUN_EVIDENCE`

These are labels only. They do not execute commands or inspect product repos by themselves.

## Denial Vocabulary

The gate must deny or defer for:

- `deny_blank_target`
- `deny_all_target`
- `deny_wildcard_target`
- `deny_multi_target`
- `deny_missing_owner`
- `deny_missing_repo_fingerprint`
- `deny_invalid_repo_fingerprint_ref`
- `deny_stale_fingerprint`
- `deny_write_capable_action`
- `deny_phone_only_approval`
- `deny_package_sending`
- `deny_command_binding`
- `deny_product_mutation`
- `deny_remote_access`
- `deny_evidence_as_authority`

Denied records remain evidence. They cannot be converted into execution by reviewer output, DOCX reports, audit packages, mobile requests, task packets, generated evidence, UI labels, notifications, buttons, approvals, prompts, or queue prose.

## Common Non-Authority Phrase Set

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Validation Rules

A valid read-only gate requires:

- exactly one selected target
- a non-empty owner
- a non-empty repo fingerprint reference
- one or more allowed read-only actions
- an expiration timestamp
- stop conditions
- evidence references
- validation status `valid`
- a non-authority notice

Any missing, broad, stale, write-capable, phone-only, package-sending, command-binding, remote-access, or product-mutation case must fail closed as `denied` or `deferred`.

## Stop Conditions

Stop and repacketize if a future task needs live product-repo inspection, write actions, package sending, remote access, runtime command binding, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or treating evidence as authority.

## Combined End-To-End Fixture Matrix

The combined selected-project read-only fixture matrix lives under `tests/fixtures/fleet/read-only-gates`. It joins selected-project gate evidence with repo fingerprint posture, runtime policy decision vocabulary, runtime dry-run evidence, and control-room reconciliation outcomes.

This matrix is local evidence only. It does not inspect product repos, bind runtime commands, create or send packages, run all-fleet commands, approve phone actions, launch demos, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

| fixture | selected-project gate outcome | runtime dry-run outcome | reconciliation display | expected safety result |
| --- | --- | --- | --- | --- |
| `selected-project-read-only.valid-fixture` | valid fixture-only read-only evidence | `ALLOW_DRY_RUN` | `MATCH` | evidence is valid for local fixture review only; it cannot execute or approve work |
| `selected-project-read-only.missing-owner-denied` | `deny_missing_owner` | `DENY_UNSAFE` | `UNKNOWN` | missing owner denies and blocks execution |
| `selected-project-read-only.stale-fingerprint-deferred` | stale fingerprint defers for review | `DEFER_NEEDS_HUMAN` | `UNKNOWN` | stale fingerprint evidence requires repacketization or review |
| `selected-project-read-only.write-capable-denied` | `deny_write_capable_action` | `DENY_UNSAFE` | `UNKNOWN` | write-capable action remains denied |
| `selected-project-read-only.ambiguous-approval-unknown` | ambiguous approval evidence defers | `DEFER_NEEDS_HUMAN` | `UNKNOWN` | ambiguous approval remains unknown and cannot approve |
| `selected-project-read-only.multi-target-denied` | `deny_multi_target` | `DENY_UNSAFE` | `UNKNOWN` | comma-packed or multi-project target remains denied |
| `selected-project-read-only.wildcard-target-denied` | `deny_wildcard_target` | `DENY_UNSAFE` | `UNKNOWN` | wildcard target remains denied |
| `selected-project-read-only.invalid-fingerprint-denied` | `deny_invalid_repo_fingerprint_ref` | `DENY_UNSAFE` | `UNKNOWN` | malformed, missing, or non-evidence repo fingerprint reference remains denied |

Every fixture must carry a non-authority notice that says the record is evidence only and cannot approve or execute work. Any fixture that sets product-repo inspection, runtime command binding, package sending, all-fleet execution, live execution, or future approval booleans to true is outside this gate and must fail validation.

The expanded denial fixtures are local evidence only. They exercise target and fingerprint vocabulary without inspecting product repositories, binding runtime commands, creating or sending packages, running all-fleet commands, or approving future work.

## Out Of Scope

- Touching product repos
- Reading live product repos
- Mutating product repos
- Sending packages
- Binding runtime commands
- Implementing remote access or phone approvals
- Running all-fleet commands
- Staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work
- Lock deletion or permission widening
