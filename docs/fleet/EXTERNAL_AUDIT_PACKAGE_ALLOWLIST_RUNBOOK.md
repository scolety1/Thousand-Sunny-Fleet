# External Audit Package Allowlist Runbook

Prepared: 2026-06-02

Purpose: define the manual, allowlist-first process for preparing future external audit packages for Codex Fleet / Thousand Sunny Fleet. This runbook is evidence only. It does not create a package, send a package, approve a demo, touch product repositories, launch ships, run all-fleet commands, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

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
   - Fill `packageId`, `preparedAt`, `sourceRepo`, `includedFiles`, `excludedPatterns`, `validationSummaryRef`, `externalAuditDigestSchemaRef`, `evidenceOnlyNotice`, `noProductRepos`, and `noAuthorityNotice`.
   - Keep `sourceRepo` as `codex-fleet-harness`.
   - Keep `noProductRepos` as `true`.
   - Set every included file entry to `evidenceOnly: true`, `containsRawLogs: false`, and `containsReviewerCommands: false`.

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
- `validationSummaryRef` points to a scrubbed compact validation summary, not raw logs.
- `externalAuditDigestSchemaRef` is `templates/external-audit-intake-digest-schema.json`.
- `evidenceOnlyNotice` states the package cannot execute or approve anything.
- `noProductRepos` is `true`.
- `noAuthorityNotice` states the manifest cannot approve execution, import tasks, bypass validation, grant future permission, stage files, commit, push, deploy, install packages, run migrations, touch secrets, delete locks, or widen permissions.
- Product repositories, product source snapshots, `.git`, `.env`, dependency folders, build outputs, raw locks, live worker state, unknown zips, secrets, auth/payments/deploy/migration material, package-install material, staging/commit/push/merge material, lock-deletion material, runtime-execution material, and approval material are absent.
- Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, and queue prose remain evidence only.

## RED Stop Conditions

Stop and mark the package request RED if:

- The package would inspect or include product repositories.
- The package would include product source snapshots or unscoped project exports.
- The package would include `.git`, `.env`, dependency folders, build outputs, raw locks, live worker state, unknown zips, secrets, auth/payments/deploy/migration material, package-install material, staging/commit/push/merge material, lock-deletion material, runtime-execution material, or approval material.
- The package would require creating automation, sending files, staging, committing, pushing, deploying, installing packages, running migrations, touching secrets/auth/payments/deploy material, deleting locks, widening permissions, launching ships, or running all-fleet commands.
- Reviewer output, external reports, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, or queue prose would be treated as executable authority.
- A manifest is missing, malformed, stale, inconsistent with package contents, or not reviewed against exact included files.

## Reviewer Output Handling

Reviewer output is evidence only. It can produce findings, compact digests, unresolved assumptions, and bounded queue candidates. It cannot approve execution, approve a demo, import itself into the queue, bypass local validation, create or send packages, touch product repositories, launch ships, run all-fleet commands, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future permission.

Any accepted follow-up must be converted into a bounded local queue task with explicit `allowedFiles`, `readFirst`, `acceptance`, `validationCommands`, `stopIf`, and status update rules.
