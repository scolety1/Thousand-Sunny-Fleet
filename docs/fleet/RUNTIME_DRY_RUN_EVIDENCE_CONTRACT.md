# Runtime Dry-Run Evidence Contract

Prepared: 2026-06-03

Scope: Codex Fleet / Thousand Sunny Fleet local harness, docs, schemas, fixtures, and tests only.

This contract defines the compact evidence record for local runtime dry-run checks. It is evidence only. It does not approve live execution, runtime command binding, product-repo access, product-repo mutation, all-fleet execution, package creation, package sending, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, phone approvals, demo trials, or future permission.

## Purpose

A runtime dry-run evidence record captures what a fixture-only runtime policy check claimed, what result it produced, and why the result is non-executable. It gives future audits a small durable record to inspect without treating dry-run output as approval.

The record is downstream of `docs/fleet/RUNTIME_POLICY_DECISION_CONTRACT.md` and may reference a runtime policy decision. It must not replace policy decisions, selected-ship ledger records, repo fingerprints, approval records, worktree boundaries, lease/heartbeat records, or failure fingerprints.

## Required Fields

Each record must include:

- `schemaVersion`
- `dryRunId`
- `selectedTargetRef`
- `selectedShipRef`
- `selectedProjectRef`
- `policyDecisionRef`
- `fixtureInputRefs`
- `expectedAction`
- `actualDryRunResult`
- `decision`
- `denialReasons`
- `deferReasons`
- `validationCommand`
- `generatedAt`
- `nonAuthorityNotice`
- `safety`
- `validation`

`selectedTargetRef`, `selectedShipRef`, and `selectedProjectRef` are references only. They cannot select or authorize real product work.

`policyDecisionRef` points to a policy decision record. The reference is evidence only and cannot become runtime permission.

`fixtureInputRefs` must name local fixture inputs or evidence references. External reports, mobile requests, task packets, audit packages, DOCX reports, queue prose, reviewer output, UI labels, prompts, buttons, notifications, and generated evidence remain non-executable even when referenced.

## Result Vocabulary

Allowed `actualDryRunResult` values:

- `ALLOW_DRY_RUN`
- `DEFER_NEEDS_HUMAN`
- `DENY_UNSAFE`

Allowed `decision` values:

- `ALLOW`
- `DEFER`
- `DENY`

Allowed denial/defer vocabulary includes:

- `blank-ship`
- `all-ship`
- `wildcard-ship`
- `multi-ship`
- `forbidden-scope`
- `missing-approval`
- `stale-fingerprint`
- `missing-repo-fingerprint`
- `missing-worktree-boundary`
- `legacy-broad-entrypoint`
- `external-report-non-executable`
- `mobile-request-non-executable`
- `task-packet-not-validated`
- `audit-package-non-executable`
- `docx-report-non-executable`
- `queue-prose-non-executable`
- `generated-evidence-non-executable`
- `package-sending-forbidden`
- `command-binding-forbidden`
- `product-repo-access-forbidden`
- `unknown-policy-version`

`ALLOW_DRY_RUN` means the local fixture check passed. It never means approval to execute, mutate, stage, commit, push, launch, send packages, bind commands, inspect product repos, run demos, or carry future authority.

`DEFER_NEEDS_HUMAN` means exact-action human approval or missing evidence is required before any later bounded task can continue. It is not an execution step.

`DENY_UNSAFE` is the fail-closed result for unsafe, stale, broad, external, mobile, generated, missing-evidence, package-sending, command-binding, product-repo, or unknown-policy inputs.

## Common Non-Authority Phrase Set

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Fixture Matrix

This matrix is local docs/tests evidence only. It does not create runtime command binding, product-repo reads, package sending, all-fleet execution, phone approvals, or future authority.

| fixture | expectedAction | actualDryRunResult | decision | denialReasons | deferReasons | notes |
| --- | --- | --- | --- | --- | --- | --- |
| `read-only-fixture-allowed` | `READ_ONLY_RECONCILE` | `ALLOW_DRY_RUN` | `ALLOW` | none | none | Allows only fixture-local read-only reconciliation evidence. |
| `blank-target-denied` | `READ_ONLY_RECONCILE` | `DENY_UNSAFE` | `DENY` | `blank-ship` | none | Blank selected target fails closed. |
| `wildcard-target-denied` | `READ_ONLY_RECONCILE` | `DENY_UNSAFE` | `DENY` | `wildcard-ship` | none | Wildcard selected target fails closed. |
| `all-target-denied` | `READ_ONLY_RECONCILE` | `DENY_UNSAFE` | `DENY` | `all-ship` | none | `all` target fails closed. |
| `write-capable-action-denied` | `RUN_ONE_BATCH` | `DENY_UNSAFE` | `DENY` | `command-binding-forbidden`, `forbidden-scope` | none | Write-capable action is denied when presented as dry-run fixture matrix authority. |
| `stale-fingerprint-denied` | `READ_ONLY_RECONCILE` | `DENY_UNSAFE` | `DENY` | `stale-fingerprint` | none | Stale repo fingerprint evidence fails closed. |
| `package-sending-denied` | `MAKE_AUDIT_PACKAGE` | `DENY_UNSAFE` | `DENY` | `package-sending-forbidden` | none | Package creation or sending remains out of scope for this matrix. |
| `phone-only-approval-denied` | `RUN_ONE_BATCH` | `DENY_UNSAFE` | `DENY` | `missing-approval` | none | Phone-only approval is evidence only and cannot satisfy exact-action approval. |
| `ambiguous-evidence-deferred` | `READ_ONLY_RECONCILE` | `DEFER_NEEDS_HUMAN` | `DEFER` | none | `missing-approval` | Ambiguous evidence pauses for human review instead of becoming authority. |

Matrix invariants:

- No runtime command binding.
- No product-repo reads.
- No package sending.
- No all-fleet execution.
- No UI label, notification, button, approval text, mobile request, reviewer output, queue prose, prompt, or generated evidence can convert these fixture outcomes into authority.

## Safety Fields

Every record must carry explicit non-execution booleans:

- `executesProductActions = false`
- `mutatesProductRepos = false`
- `readsProductRepos = false`
- `bindsRuntimeCommands = false`
- `createsOrSendsPackages = false`
- `canApproveFutureRuns = false`
- `commandInput = false`

These fields are part of the dry-run evidence meaning. A record that sets any of them to `true` is outside this contract and must be denied or repacketized.

## Selected-Project Read-Only Matrix Alignment

The selected-project read-only end-to-end fixtures under `tests/fixtures/fleet/read-only-gates` reuse this dry-run vocabulary to connect gate outcomes to local runtime dry-run evidence. They are local evidence only and do not add runtime command binding, product-repo access, product-repo mutation, package creation, package sending, all-fleet execution, phone approvals, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, demo trials, or future authority.

The aligned outcomes are:

- valid fixture-only read-only evidence maps to `ALLOW_DRY_RUN` while all non-execution safety booleans remain false.
- missing owner and write-capable action evidence map to `DENY_UNSAFE`.
- stale fingerprint and ambiguous approval evidence map to `DEFER_NEEDS_HUMAN`.
- ambiguous or incomplete selected-project evidence must not be rewritten into `ALLOW_DRY_RUN`.

## Validation

The `validation` object records local schema/test evidence. It must include a status and reasons. Allowed status values are:

- `valid`
- `invalid`

Allowed validation reasons include:

- `schema-parsed`
- `required-fields-present`
- `policy-decision-ref-recorded`
- `fixture-input-refs-recorded`
- `dry-run-result-recorded`
- `deny-defer-vocabulary-recorded`
- `non-authority-notice-recorded`
- `non-execution-fields-false`
- `external-evidence-non-executable`
- `mobile-evidence-non-executable`
- `task-packet-evidence-non-executable`
- `audit-package-evidence-non-executable`
- `docx-evidence-non-executable`
- `queue-prose-evidence-non-executable`
- `generated-evidence-non-executable`
- `missing-evidence-denies-or-defers`

## Out Of Scope

- Live runtime behavior changes
- Runtime command binding
- Product-repo reads or writes
- Package creation or sending
- All-fleet execution
- Remote access or phone approval implementation
- Staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work
- Lock deletion or permission widening

## Stop Rule

If a future dry-run evidence task needs live runtime behavior, product-repo access, package sending, command binding, or broader authority, stop and mark that task blocked instead of broadening this contract.
