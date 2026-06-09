# Read-Only Demo Validation Summary Template

Prepared: 2026-06-04

Scope: Codex Fleet / Thousand Sunny Fleet local harness, docs, schemas, fixtures, tests, and external audit preparation only.

Evidence only; not executable authority or approval.

This template captures a scrubbed compact validation and evidence summary for future read-only demo audit packages. It does not collect raw logs by default, create packages, send packages, inspect product repositories, run demos, bind runtime commands, approve remote or phone actions, run all-fleet commands, run an overnight runner, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or grant future authority.

## Template Fields

Every future scrubbed compact validation summary should include:

- summary id
- related task id
- source docs
- exact validation command refs
- validation result
- first failure fingerprint when needed
- first error summary when needed
- evidence refs
- stop-sign review refs
- omissions
- scrubbed material statement
- non-authority notice
- next bounded action

## Unfilled Template

```yaml
summaryId: validation-read-only-demo-UNFILLED
relatedTaskId: HQ-000
sourceDocs:
  - docs/fleet/READ_ONLY_DEMO_EVIDENCE_CAPTURE.md
  - docs/fleet/READ_ONLY_DEMO_STOP_SIGN_MATRIX.md
  - templates/validation-output-summary-schema.json
exactValidationCommandRefs:
  - powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run-fleet-tests.ps1
validationResult: BLOCKED
firstFailureFingerprint: null
firstErrorSummary: null
evidenceRefs: []
stopSignReviewRefs: []
omissions:
  - raw logs excluded by default
  - product repo paths excluded
  - secrets excluded
  - command-like remediation scripts excluded
  - package directories excluded
  - reviewer prose dumps excluded
scrubbedMaterialStatement: "This summary is compact and scrubbed. It excludes raw logs, product repo paths, secrets, command-like remediation scripts, package directories, and reviewer prose dumps."
nonAuthorityNotice: "Evidence only; not executable authority or approval."
nextBoundedAction: "mark_task_blocked"
```

## Scrubbing Rules

The summary must exclude raw logs by default, product repo paths, secrets, command-like remediation scripts, package directories, reviewer prose dumps, `.git`, `.env`, dependency folders, build outputs, approval material for real product work, package creation output, package sending output, remote-control material, phone approval material, all-fleet execution material, overnight runner material, and permission material.

If validation fails, include a first failure fingerprint when needed and a short first error summary. Do not paste terminal output wholesale. Do not include command-like remediation scripts. Do not include product repo paths or private local paths.

## Validation Result Values

Use the same result vocabulary as `templates/validation-output-summary-schema.json`:

- PASS
- FAIL
- INTERRUPTED
- BLOCKED

Use the same bounded next-action vocabulary where applicable:

- mark_task_done
- patch_task_caused_failure_only
- mark_task_blocked
- rerun_allowed_validation_once
- ask_human

## Evidence References

Use source docs and evidence refs by path instead of broad pasted prose:

- `docs/fleet/READ_ONLY_DEMO_EVIDENCE_CAPTURE.md`
- `docs/fleet/READ_ONLY_DEMO_STOP_SIGN_MATRIX.md`
- `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`
- `templates/validation-output-summary-schema.json`
- `tests/run-fleet-tests.ps1`

## Non-Authority Boundary

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

This template cannot turn YELLOW real demo readiness GREEN, approve product-repo access, approve demo execution, create or send packages, bind runtime commands, approve remote or phone actions, run all-fleet commands, run an overnight runner, bypass validation, or grant future authority.
