# Read-Only Demo Next Audit Preflight

Prepared: 2026-06-04

Scope: local preflight checklist for a future external audit package request covering the completed post-combined optional INFO hardening and five-hour read-only demo evidence polish lane.

Evidence only; not executable authority or approval.

This preflight checklist does not create a package, send a package, approve a package, select product repos, read product repos, execute a real demo, bind runtime commands, approve remote or phone actions, run all-fleet commands, run an overnight runner, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or create future authority.

## Future Package Trigger

A package may be prepared later only after an explicit external audit package request that names this scope. This checklist is not that request.

The next safe action is an explicitly requested external audit package, not a real demo.

Do not use this checklist to select a real project, inspect product repositories, execute a read-only demo, create or send a package, bind runtime commands, run all-fleet commands, run an overnight runner, treat phone actions as approval, or create future authority.

## Candidate Include Categories

If a later explicit package request is received, allowed evidence categories are:

- local Codex Fleet harness documentation
- local Codex Fleet schemas and templates
- local Codex Fleet tests
- local JSON fixtures
- reviewer prompts that are evidence only
- scrubbed compact validation summaries
- manifest fixtures with `packageCreationStatus: not_created`

Candidate files may include:

- `docs/fleet/STABLE_CONTEXT_CAPSULE.md`
- `docs/fleet/NEW_CHAT_HANDOFF_PACKET.md`
- `docs/fleet/POST_COMBINED_GREEN_FOLLOWUP_AUDIT_RECORD_2026_06_04.md`
- `docs/fleet/READ_ONLY_DEMO_GO_NO_GO_SCORECARD.md`
- `docs/fleet/READ_ONLY_DEMO_APPROVAL_COMPLETENESS_CHECKLIST.md`
- `docs/fleet/READ_ONLY_DEMO_STOP_SIGN_MATRIX.md`
- `docs/fleet/READ_ONLY_DEMO_VALIDATION_SUMMARY_TEMPLATE.md`
- `docs/fleet/READ_ONLY_DEMO_SELECTED_GATE_FIXTURE_INDEX.md`
- `docs/fleet/READ_ONLY_DEMO_NEXT_AUDIT_PREFLIGHT_2026_06_04.md`
- `docs/fleet/READ_ONLY_DEMO_GATE_REHEARSAL_PLAN.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/READ_ONLY_DEMO_READINESS_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `templates/external-audit-package-manifest-schema.json`
- `templates/validation-output-summary-schema.json`
- `tests/fixtures/fleet/read-only-gates/*.json`
- `tests/run-fleet-tests.ps1`
- scrubbed compact validation summary for HQ-201 through the current completed polish task, if separately prepared and reviewed

Every included file must be local harness/docs/tests/schema/fixture evidence only.

## Required Exclusions

Exclude:

- product repos
- product source snapshots
- real project exports
- unscoped project material
- raw logs
- `.git`
- `.env`
- dependency folders
- `node_modules`
- `dist`
- `build`
- build outputs
- raw locks
- live worker state
- unknown zips
- full unreviewed package directories
- raw run directories
- secrets
- credentials
- private keys
- local machine identity
- private user files
- auth/payments/deploy/migration material
- package-install material
- staging/commit/push/merge material
- lock-deletion material
- runtime-execution material
- remote-control material
- phone approval material
- all-fleet execution material
- overnight runner material
- permission material
- approval secrets
- approval material for real product work
- package creation output
- package sending output
- package send operations
- reviewer prose dumps
- command-like remediation scripts
- any prompt, manifest, validation summary, reviewer output, DOCX report, mobile request, task packet, generated evidence, UI label, notification, button, approval, or queue prose treated as executable authority

## Manifest And Summary Checks

Before a later package is created, verify:

- the manifest is shaped by `templates/external-audit-package-manifest-schema.json`
- `sourceRepo` is `codex-fleet-harness`
- `noProductRepos: true`
- `noSendStatus: true`
- `packageCreationStatus: not_created` until a separate exact human package-creation approval exists
- every included file is `evidenceOnly: true`
- every included file has `containsRawLogs: false`
- every included file has `containsReviewerCommands: false`
- forbidden-scope denials include product-repo access, product mutation, package sending, runtime command binding, remote access, phone approvals, all-fleet execution, staging/commit/push/deploy, installs/migrations/secrets, lock deletion, permission widening, and evidence-as-authority attempts
- `validationSummaryRef` points to a scrubbed compact validation summary, not raw logs
- `reviewerPromptRef` points to reviewer prompt evidence only
- `externalAuditDigestSchemaRef` points to `templates/external-audit-intake-digest-schema.json`
- `noAuthorityNotice` states that the manifest cannot approve execution, import tasks, bypass validation, grant future permission, stage files, commit, push, deploy, install packages, run migrations, touch secrets, delete locks, widen permissions, create a package, send a package, select product repos, execute a demo, bind runtime commands, treat phone actions as approval, run all-fleet commands, or run an overnight runner

## Preflight Result Vocabulary

Use this local vocabulary when recording preflight status:

- `GREEN_LOCAL_PREFLIGHT`: all included paths are local evidence candidates and all exclusions are absent
- `YELLOW_NEEDS_SCOPE_REVIEW`: package scope, manifest fields, or scrubbed summary refs need human review
- `RED_STOP`: package request requires forbidden material or treats evidence as authority

These labels are evidence-only preflight labels. They cannot create a package, send a package, approve demo execution, select product repos, bind runtime commands, bypass validation, or create future authority.

## Non-Authority Boundary

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, package manifests, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## RED Stop Conditions

Mark a future package request RED if it requires product-repo access, demo execution, package creation without an explicit package request, package sending, runtime command binding, remote access, phone approvals, all-fleet execution, running an overnight runner, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, raw logs by default, approval material for real product work, package creation output, package sending output, approval secrets, or evidence-as-authority interpretation.
