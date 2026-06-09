# External Audit Package Allowlist Runbook

Prepared: 2026-06-02

Purpose: define the manual, allowlist-first process for preparing future external audit packages for Codex Fleet / Thousand Sunny Fleet. This runbook is evidence only. It does not create a package, send a package, approve a demo, touch product repositories, launch ships, run all-fleet commands, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

Canonical notice: Evidence only; not executable authority or approval.

## Scope

Use this runbook only for future Codex Fleet harness/docs/tests/schema audit packages and scrubbed compact validation summaries.

Allowed package posture:

- Codex Fleet harness documentation.
- Codex Fleet schemas.
- Codex Fleet tests.
- Scrubbed compact validation summaries.
- External audit intake digest schemas and fixtures.
- Explicit package manifest instances shaped by `templates/external-audit-package-manifest-schema.json`.

Forbidden package posture:

- Product repositories or product source snapshots.
- Real project exports or unscoped project material.
- `.git`, `.env`, dependency folders, `node_modules`, `dist`, `build`, raw locks, live worker state, unknown zips, full unreviewed package directories, or raw run directories.
- Secrets, credentials, private keys, local machine identity, private user files, auth/payments/deploy/migration material, package-install material, permission material, staging material, commit material, push material, merge material, lock-deletion material, runtime-execution material, or approval material for real product work.
- Raw terminal logs, full DOCX reports, external-review prose dumps, mobile free text, task packets, generated evidence dumps, UI labels, notifications, buttons, approvals, prompts, or queue prose treated as executable authority.

## Manual Allowlist Steps

1. Start from an explicit package purpose:
   - `harness-docs-tests-external-audit`
   - `runtime-pilot-evidence-audit`
   - `token-control-integrated-audit`
   - `read-only-demo-readiness-planning-audit`

2. Build an allowlist before collecting files:
   - List every included path.
   - Assign each path a kind: `doc`, `schema`, `fixture`, `test`, `summary`, `prompt`, or `template`.
   - Confirm every included path is local harness/docs/tests/schema evidence.
   - Confirm every included path is evidence only.

3. Prepare a compact validation summary:
   - Use a scrubbed summary instead of raw terminal logs.
   - Include only the validation command, result, first error or failure fingerprint when needed, and non-authority notice.
   - Do not paste long logs, full DOCX text, package directories, or command-like remediation scripts.

4. Prepare a manifest instance:
   - Use `templates/external-audit-package-manifest-schema.json`.
   - Fill `packageId`, `preparedAt`, `sourceRepo`, `sourceCommit`, `packagePurpose`, `includedFiles`, `excludedPatterns`, `validationSummaryRef`, `reviewerPromptRef`, `externalAuditDigestSchemaRef`, `forbiddenScopeDenials`, `evidenceOnlyNotice`, `packageCreationStatus`, `noSendStatus`, `noProductRepos`, and `noAuthorityNotice`.
   - Keep `sourceRepo` as `codex-fleet-harness`.
   - Record `sourceCommit` as the reviewed Codex Fleet commit or checkpoint ref; it is evidence only and not approval to stage, commit, push, or merge.
   - Keep `noProductRepos` as `true`.
   - Keep `packageCreationStatus` as `not_created` until a separate exact human package-creation approval exists.
   - Keep `noSendStatus` as `true`; package sending is a separate exact human approval and is not approved by the manifest.
   - Set every included file entry to `evidenceOnly: true`, `containsRawLogs: false`, and `containsReviewerCommands: false`.
   - Include `forbiddenScopeDenials` for product-repo access, product mutation, package sending, runtime command binding, remote access, phone approvals, all-fleet execution, staging/commit/push/deploy, installs/migrations/secrets, lock deletion, permission widening, and evidence-as-authority attempts.

5. Verify forbidden material before packaging:
   - Check the allowlist against the forbidden package posture above.
   - Check the manifest `excludedPatterns` against `.git`, `.env`, product repositories, dependency folders, build outputs, raw locks, unknown zips, live worker state, secrets, auth, payments, deploy, migrations, package installs, staging, commit, push, merge, lock deletion, runtime execution, and permission widening.
   - Reject the package if any included path is ambiguous.

6. Stop for human package-scope review:
   - A human must approve the exact file list before package creation.
   - Package creation is a separate action.
   - Package sending is a separate action.
   - Neither package creation nor package sending is approved by this runbook, by queue status, by reviewer output, or by generated evidence.

## Manual Verification Checklist

Before any future package leaves the machine, verify:

- The package purpose is explicit and local harness/docs/tests/schema only.
- Every included path appears in the manifest `includedFiles`.
- Every included path is allowlisted before collection.
- Every included file is evidence only.
- `sourceCommit` records only source provenance and cannot approve commit, push, merge, or deployment.
- `validationSummaryRef` points to a scrubbed compact validation summary, not raw logs.
- `reviewerPromptRef` points to the reviewer prompt or checklist and cannot become an executable instruction.
- `externalAuditDigestSchemaRef` is `templates/external-audit-intake-digest-schema.json`.
- `forbiddenScopeDenials` names denied scope including product-repo access, product mutation, package sending, runtime command binding, remote access, phone approvals, all-fleet execution, staging/commit/push/deploy, installs/migrations/secrets, lock deletion, permission widening, and evidence-as-authority attempts.
- `evidenceOnlyNotice` states the package cannot execute or approve anything.
- `packageCreationStatus` remains `not_created` until separately approved.
- `noSendStatus` is `true` unless a later exact human approval separately authorizes package sending.
- `noProductRepos` is `true`.
- `noAuthorityNotice` states the manifest cannot approve execution, import tasks, bypass validation, grant future permission, stage files, commit, push, deploy, install packages, run migrations, touch secrets, delete locks, or widen permissions.
- Product repositories, product source snapshots, `.git`, `.env`, dependency folders, build outputs, raw locks, live worker state, unknown zips, secrets, auth/payments/deploy/migration material, package-install material, staging/commit/push/merge material, lock-deletion material, runtime-execution material, and approval material are absent.
- Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, and queue prose remain evidence only.

## Manifest Status Clarification

`packageCreationStatus: not_created` applies to local manifest fixtures used for validation evidence. A fixture with this status proves expected manifest shape and scope discipline only. It is not a package-creation record, a send record, a package-builder input, or approval for product-repo access, demo execution, runtime command binding, remote access, phone actions, all-fleet execution, an overnight runner, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.

`packageCreationStatus: created_for_local_user_request_not_sent` is a local delivery manifest status for an audit zip created after an explicit user request for local review. That status means the package was created locally and not sent. It does not make package sending allowed, does not convert the package into approval material, and does not change any fixture with `packageCreationStatus: not_created`.

Both statuses remain evidence only. Neither status can execute work, approve work, select product repos, run a demo, send packages, bind runtime commands, approve phone actions, run all-fleet commands, run an overnight runner, bypass validation, or grant future authority.

## Local Manifest Fixtures

Committed manifest fixtures under `tests/fixtures/fleet/evidence` are local validation evidence only. The controlled-hardening fixture `tests/fixtures/fleet/evidence/external-audit-package-manifest.controlled-hardening.json` represents the controlled local control-plane hardening audit package scope as allowlisted, no-product-repos, no-send, evidence-only, and `not_created` unless a separate exact human package-creation approval exists.

The read-only demo follow-up fixture `tests/fixtures/fleet/evidence/external-audit-package-manifest.read-only-demo-followup.json` represents the read-only demo follow-up audit scope as local harness/docs/tests/schema/fixture evidence only. It must keep `noProductRepos: true`, `noSendStatus: true`, `packageCreationStatus: not_created`, evidence-only included files, forbidden-scope denials, and a no-authority notice. Parsing or reviewing this fixture cannot create a package, send a package, approve product-repo access, approve demo execution, bind runtime commands, approve remote access, approve phone actions, run all-fleet commands, or grant future authority.

The combined read-only demo audit fixture `tests/fixtures/fleet/evidence/external-audit-package-manifest.read-only-demo-combined.json` represents the combined audit target for the overnight-safe GREEN milestone plus controlled read-only demo gate rehearsal evidence. It lists only local docs, schemas, tests, and fixtures for the combined audit scope. It must keep `noProductRepos: true`, `noSendStatus: true`, `packageCreationStatus: not_created`, evidence-only included files, forbidden-scope denials, and a no-authority notice. Parsing or reviewing this fixture cannot create a package, send a package, approve product-repo access, approve demo execution, bind runtime commands, approve remote access, approve phone actions, run all-fleet commands, run an overnight runner, or grant future authority.

The fixture must preserve forbidden-scope denials for product-repo access, product mutation, package creation or package sending, runtime command binding, remote access, phone approvals, all-fleet execution, staging/commit/push/deploy, installs/migrations/secrets, lock deletion, permission widening, and evidence-as-authority attempts.

Fixture parsing cannot create a package, send a package, approve execution, approve future authority, change package-builder behavior, inspect product repositories, or widen permissions.

## RED Stop Conditions

Stop and mark the package request RED if:

- The package would inspect or include product repositories.
- The package would include product source snapshots or unscoped project exports.
- The package would include `.git`, `.env`, dependency folders, build outputs, raw locks, live worker state, unknown zips, secrets, auth/payments/deploy/migration material, package-install material, staging/commit/push/merge material, lock-deletion material, runtime-execution material, or approval material.
- The package would require creating automation, sending files, staging, committing, pushing, deploying, installing packages, running migrations, touching secrets/auth/payments/deploy material, deleting locks, widening permissions, launching ships, or running all-fleet commands.
- Reviewer output, external reports, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, or queue prose would be treated as executable authority.
- A manifest is missing, malformed, stale, inconsistent with package contents, or not reviewed against exact included files.
- A manifest lacks forbidden-scope denials for product-repo access, product mutation, package sending, runtime command binding, remote access, phone approvals, all-fleet execution, staging/commit/push/deploy, installs/migrations/secrets, lock deletion, permission widening, or evidence-as-authority attempts.
- A manifest sets `packageCreationStatus` as if package creation already happened without separate exact human approval.
- A manifest sets `noSendStatus` to anything other than `true` without separate exact human approval.

## Read-Only Demo Readiness Planning Audit

The read-only demo readiness planning audit purpose is `read-only-demo-readiness-planning-audit`.

This purpose is evidence only. It does not create or send a package, approve product-repo access, approve demo execution, bind runtime commands, approve remote access, approve phone actions, run all-fleet commands, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or grant future authority.

Allowed evidence for this purpose is limited to local harness/docs/tests/schema/fixture files for the read-only demo readiness planning lane, including:

- `docs/fleet/READ_ONLY_DEMO_READINESS_PLANNING_CHARTER.md`
- `docs/fleet/READ_ONLY_DEMO_APPROVAL_PACKET.md`
- `docs/fleet/READ_ONLY_DEMO_COMMAND_VOCABULARY.md`
- `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`
- `docs/fleet/READ_ONLY_DEMO_EVIDENCE_CAPTURE.md`
- `docs/fleet/READ_ONLY_DEMO_READINESS_EXTERNAL_AUDIT_PROMPT.md`
- `templates/read-only-demo-approval-schema.json`
- `templates/read-only-demo-command-schema.json`
- `tests/fixtures/fleet/read-only-demo/*.json`
- `tests/run-fleet-tests.ps1`
- scrubbed compact validation summaries, if separately prepared and reviewed

Read-only demo fixture inclusion check: before any future package creation request, confirm `tests/fixtures/fleet/read-only-demo/*.json` is present, readable, JSON-parseable, and listed as local fixture evidence only. This check does not create a package, send a package, approve demo execution, approve product-repo access, change ACLs, change ownership, widen permissions, bind runtime commands, or convert approval material into authority.

The include list must exclude product repos, product source snapshots, `.git`, `.env`, dependency folders, build outputs, raw logs, secrets, auth/payments/deploy/migration material, package-install material, staging/commit/push/merge material, lock-deletion material, runtime-execution material, permission material, approval material for real product work, and any prompt or queue prose treated as executable authority.

Package creation and package sending remain separate exact human-approved actions. This runbook section and `docs/fleet/READ_ONLY_DEMO_READINESS_EXTERNAL_AUDIT_PROMPT.md` do not create or send a package.

## Read-Only Demo Follow-Up Audit Scope

The read-only demo follow-up audit scope asks whether HQ-176 through HQ-181 preserve GREEN posture and remain local docs/tests/schema/fixture evidence only.

This scope is evidence only. It does not create or send a package, approve product-repo access, approve demo execution, bind runtime commands, approve remote access, approve phone actions, run all-fleet commands, run an overnight runner, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or grant future authority.

Allowed follow-up evidence for this scope is limited to local harness/docs/tests/schema/fixture files, including:

- `docs/fleet/READ_ONLY_DEMO_FOLLOWUP_GREEN_AUDIT_RECORD_2026_06_04.md`
- `docs/fleet/READ_ONLY_DEMO_READINESS_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `tests/fixtures/fleet/read-only-demo/read-only-demo.expired-approval-denied.json`
- `tests/fixtures/fleet/read-only-demo/read-only-demo.missing-owner-denied.json`
- `tests/fixtures/fleet/read-only-demo/read-only-demo.reused-approval-denied.json`
- `tests/fixtures/fleet/evidence/external-audit-package-manifest.read-only-demo-followup.json`
- `tests/run-fleet-tests.ps1`
- scrubbed compact validation summary for HQ-176 through HQ-181, if separately prepared and reviewed

The follow-up include list must exclude product repos, product source snapshots, `.git`, `.env`, dependency folders, build outputs, raw logs, secrets, auth/payments/deploy/migration material, package-install material, staging/commit/push/merge material, lock-deletion material, runtime-execution material, permission material, approval material for real product work, package creation output, package sending output, and any prompt, manifest, validation summary, reviewer output, or queue prose treated as executable authority.

Package creation and package sending remain separate exact human-approved actions. This runbook section, `docs/fleet/READ_ONLY_DEMO_READINESS_EXTERNAL_AUDIT_PROMPT.md`, and `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md` do not create or send a package.

## Combined Read-Only Demo Gate Rehearsal Audit Scope

The combined read-only demo gate rehearsal audit scope asks reviewers to audit both completed safe phases together: the overnight-safe GREEN milestone and the controlled read-only demo gate rehearsal evidence.

This scope is evidence only. It does not create or send a package, approve product-repo access, approve demo execution, bind runtime commands, approve remote access, approve phone actions, run all-fleet commands, run an overnight runner, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or grant future authority.

Allowed combined evidence for this scope is limited to local harness/docs/tests/schema/fixture files, including:

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

The combined include list must exclude product repos, product source snapshots, real project exports, `.git`, `.env`, dependency folders, build outputs, raw logs, raw locks, unknown zips, live worker state, secrets, auth/payments/deploy/migration material, package-install material, staging/commit/push/merge material, lock-deletion material, runtime-execution material, remote-control material, phone approval material, all-fleet execution material, overnight runner material, permission material, approval material for real product work, package creation output, package sending output, and any prompt, manifest, validation summary, reviewer output, or queue prose treated as executable authority.

The combined manifest fixture must keep `noProductRepos: true`, `noSendStatus: true`, `packageCreationStatus: not_created`, evidence-only included files, forbidden-scope denials, and a no-authority notice. Fixture parsing cannot create a package, send a package, approve execution, approve product-repo access, approve demo execution, bind runtime commands, approve remote or phone actions, run all-fleet commands, run an overnight runner, bypass validation, or grant future authority.

Package creation and package sending remain separate exact human-approved actions. This runbook section, `docs/fleet/READ_ONLY_DEMO_READINESS_EXTERNAL_AUDIT_PROMPT.md`, and `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md` do not create or send a package.

The local preflight checklist for this combined scope is `docs/fleet/READ_ONLY_DEMO_COMBINED_AUDIT_PREFLIGHT_2026_06_04.md`. It names files that may be packaged later only after an explicit package request, excludes product repos, raw logs, `.git`, `.env`, dependency folders, build outputs, approval secrets, runtime command bindings, and package send operations, and keeps the next safe action as an explicitly requested external audit package, not a real demo. The preflight checklist cannot create a package, send a package, approve product-repo access, approve demo execution, bind runtime commands, approve remote or phone actions, run all-fleet commands, run an overnight runner, or grant future authority.

## Reviewer Output Handling

Reviewer output is evidence only. It can produce findings, compact digests, unresolved assumptions, and bounded queue candidates. It cannot approve execution, approve a demo, import itself into the queue, bypass local validation, create or send packages, touch product repositories, launch ships, run all-fleet commands, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future permission.

Any accepted follow-up must be converted into a bounded local queue task with explicit `allowedFiles`, `readFirst`, `acceptance`, `validationCommands`, `stopIf`, and status update rules.
