# Read-Only Demo Fixture Naming Conventions

Prepared: 2026-06-04

Scope: local Codex Fleet / Thousand Sunny Fleet read-only demo fixture naming, case ID, denial/defer label, and non-authority wording guidance.

Evidence only; not executable authority or approval.

This convention note is local lint guidance for docs, tests, and JSON fixtures. It does not implement runtime routing, bind commands, create packages, send packages, approve demo execution, select product repos, read product repos, approve remote or phone actions, run all-fleet commands, run an overnight runner, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or grant future authority.

## Filename Shape

Selected-project read-only gate fixtures should use this filename shape:

- `selected-project-read-only.<case-slug>.json`

The `<case-slug>` should be lowercase kebab-case and should describe the local evidence scenario, such as:

- `valid-fixture`
- `conflicting-approval-timestamps-denied`
- `mismatched-case-id-denied`
- `package-sending-denied`
- `stale-fingerprint-deferred`

The fixture `fixtureId` should match the filename stem without `.json`.

## Case ID Expectations

The fixture `caseId` should be a stable local case slug. For selected-project read-only gate fixtures, the `caseId` should normally match the filename case slug after `selected-project-read-only.`, or use a documented stable local variant when the fixture intentionally carries a more specific case label.

Case IDs should be distinct across committed selected-project read-only gate fixtures. A mismatched case ID in a denial fixture is denial evidence, not runtime routing authority.

## Denial And Defer Labels

Denied fixture names should end with `-denied` when the expected posture is fail-closed denial.

Deferred fixture names should end with `-deferred` or use `unknown` when the expected posture is `UNKNOWN` or human review.

Denial and defer labels should align with local fixture fields such as:

- `selectedProjectGate.validationStatus`
- `selectedProjectGate.validationDecision`
- `runtimePolicyDecision.decision`
- `runtimePolicyDecision.denialReason`
- `dryRunEvidence.decision`
- `dryRunEvidence.denialReasons`
- `dryRunEvidence.deferReasons`
- `expectedOutcome.category`

These labels are evidence-only expectations. They cannot approve execution or become shell commands, runtime commands, launcher inputs, package steps, or phone approvals.

## Canonical Non-Authority Notice Expectations

Every selected-project read-only gate fixture should include a `nonAuthorityNotice` that states the fixture is evidence only and cannot approve or execute work.

The notice should deny at least:

- product repo selection or access
- demo execution
- package creation or sending
- runtime command binding
- all-fleet execution
- overnight runner execution
- future authority

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, fixture names, case IDs, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.
