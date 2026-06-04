# Read-Only Demo Command Vocabulary

Prepared: 2026-06-03

Scope: future read-only demo readiness planning evidence only.

This vocabulary is evidence only. It does not bind commands, run commands, approve product-repo access, execute a demo, mutate product repos, create packages, send packages, implement remote access, approve phone actions, run all-fleet commands, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, implement non-mock UI, or grant future authority.

Canonical notice: Evidence only; not executable authority or approval.

## Purpose

This document defines the only allowed labels for a future read-only/no-op demo readiness planning lane. These labels describe evidence that may be reviewed. They are not shell commands, runtime commands, launcher inputs, button actions, phone approvals, package steps, or product-repo operations.

## Allowed Planning Labels

| label | meaning | boundary |
| --- | --- | --- |
| `READ_STATUS` | Read a local status summary already produced by the harness. | No product-repo inspection and no runtime execution. |
| `READ_REPO_FINGERPRINT` | Read a committed/local repo fingerprint evidence reference. | Does not create a fingerprint from a real product repo in this lane. |
| `READ_VALIDATION_SUMMARY` | Read a compact validation summary. | Does not run validation unless a later bounded task lists the command. |
| `READ_AUDIT_EVIDENCE` | Read evidence-only audit findings or audit records. | Reviewer output and DOCX reports remain non-executable. |
| `READ_DRY_RUN_EVIDENCE` | Read local dry-run evidence records. | `ALLOW_DRY_RUN` remains evidence only and does not approve execution. |
| `READ_CONTROL_ROOM_SNAPSHOT` | Read a local control-room or reconciliation snapshot. | UNKNOWN mismatches stay UNKNOWN and do not become approval. |
| `READ_SCHEMA` | Parse or inspect a local schema artifact. | Does not widen schemas to approve execution. |
| `READ_FIXTURE` | Parse or inspect a committed local fixture. | Does not inspect product repos or create runtime behavior. |
| `NO_OP_READINESS_CHECK` | Record that a planning-only readiness checklist was reviewed. | No command execution, package sending, or demo execution. |

## Explicitly Denied Vocabulary

The vocabulary must deny:

- write-capable commands
- product mutation
- package creation or package sending
- runtime command binding
- remote access
- all-fleet execution
- staging, commit, push, merge, or deploy
- installs or migrations
- secrets/auth/payments/deploy work
- lock deletion or permission widening
- phone approvals
- non-mock UI implementation
- demo execution
- future authority

Denied labels include:

- `WRITE_PRODUCT_REPO`
- `MUTATE_PRODUCT_REPO`
- `CREATE_PACKAGE`
- `SEND_PACKAGE`
- `BIND_RUNTIME_COMMAND`
- `REMOTE_ACCESS`
- `APPROVE_BY_PHONE`
- `RUN_ALL_FLEET`
- `STAGE_COMMIT_PUSH_DEPLOY`
- `INSTALL_OR_MIGRATE`
- `TOUCH_SECRETS_AUTH_PAYMENTS_DEPLOY`
- `DELETE_LOCKS_OR_WIDEN_PERMISSIONS`
- `EXECUTE_DEMO`
- `GRANT_FUTURE_AUTHORITY`

## Schema Expectations

`templates/read-only-demo-command-schema.json` records the same allowed labels and forbidden labels as strict local planning vocabulary. The schema is for parsing and audit review. It is not a command runner, and the vocabulary cannot become a command input.

Any future record using this vocabulary must carry:

- `schemaVersion`
- `vocabularyId`
- `allowedLabels`
- `deniedLabels`
- `forbiddenCapabilities`
- `nonAuthorityNotice`
- `validation`

## Common Non-Authority Phrase Set

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Stop Conditions

Stop and repacketize if a future task asks to run demo commands, bind commands, touch product repos, create packages, send packages, implement remote access, approve phone actions, run all-fleet commands, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or treat this vocabulary as a command input.
