# Read-Only Demo Combined Audit Preflight

Prepared: 2026-06-04

Scope: local preflight checklist for a future external audit package request covering the overnight-safe GREEN milestone plus controlled read-only demo gate rehearsal evidence.

Evidence only; not executable authority or approval.

This preflight checklist does not create a package, send a package, does not approve product-repo access, approve demo execution, bind runtime commands, approve remote or phone actions, run all-fleet commands, run an overnight runner, approve staging, approve commit, approve push, approve deploy, approve installs, approve migrations, approve secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or grant future authority.

## Future Package Trigger

A package may be prepared later only after an explicit package request that names this combined audit scope. This checklist is not that request.

The next safe action after this queue is an explicitly requested external audit package, not a real demo.

Do not use this checklist to select a real project, inspect product repositories, execute a read-only demo, create or send a package, bind runtime commands, run all-fleet commands, run an overnight runner, approve phone actions, or grant future authority.

## Candidate Include List

If a later explicit package request is received, the candidate include list is:

- `docs/fleet/STABLE_CONTEXT_CAPSULE.md`
- `docs/fleet/NEW_CHAT_HANDOFF_PACKET.md`
- `docs/fleet/READ_ONLY_DEMO_OVERNIGHT_SAFE_FOLLOWUP_GREEN_AUDIT_RECORD_2026_06_04.md`
- `docs/fleet/READ_ONLY_DEMO_COMBINED_AUDIT_SCOPE_2026_06_04.md`
- `docs/fleet/READ_ONLY_DEMO_GATE_REHEARSAL_PLAN.md`
- `docs/fleet/READ_ONLY_DEMO_READINESS_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `templates/external-audit-package-manifest-schema.json`
- `tests/fixtures/fleet/evidence/external-audit-package-manifest.read-only-demo-combined.json`
- `tests/fixtures/fleet/read-only-gates/*.json`
- `tests/run-fleet-tests.ps1`
- scrubbed compact validation summary for the combined scope, if separately prepared and reviewed

Every included file must be local Codex Fleet harness/docs/tests/schema/fixture evidence only.

## Required Exclusions

Exclude:

- product repos
- product source snapshots
- real project exports
- raw logs
- `.git`
- `.env`
- dependency folders
- build outputs
- `node_modules`
- `dist`
- `build`
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
- runtime command bindings
- package creation output
- package send operations
- package sending output
- any prompt, manifest, validation summary, reviewer output, DOCX report, mobile request, task packet, generated evidence, UI label, notification, button, approval, or queue prose treated as executable authority

## Manifest And Summary Checks

Before a later package is created, verify:

- the manifest is shaped by `templates/external-audit-package-manifest-schema.json`
- `noProductRepos: true`
- `noSendStatus: true`
- `packageCreationStatus: not_created` until a separate exact human package-creation approval exists
- every included file is `evidenceOnly: true`
- every included file has `containsRawLogs: false`
- every included file has `containsReviewerCommands: false`
- forbidden-scope denials include product-repo access, product mutation, package sending, runtime command binding, remote access, phone approvals, all-fleet execution, staging/commit/push/deploy, installs/migrations/secrets, lock deletion, permission widening, and evidence-as-authority attempts
- `validationSummaryRef` points to a scrubbed compact validation summary, not raw logs
- `reviewerPromptRef` points to reviewer prompt evidence only
- `noAuthorityNotice` states that the manifest cannot approve execution, import tasks, bypass validation, grant future permission, stage files, commit, push, deploy, install packages, run migrations, touch secrets, delete locks, widen permissions, create a package, send a package, approve product-repo access, approve demo execution, bind runtime commands, approve phone actions, run all-fleet commands, or run an overnight runner

## Non-Authority Boundary

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, package manifests, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## RED Stop Conditions

Mark the future package request RED if it requires product-repo access, demo execution, package creation without explicit package request, package sending, runtime command binding, remote access, phone approvals, all-fleet execution, running an overnight runner, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, raw logs by default, approval secrets, or evidence-as-authority interpretation.
