# Runtime Policy Decision Contract

Prepared: 2026-05-30

Scope: Codex Fleet harness, docs, schemas, and tests only. This contract defines the deterministic policy gate output for selected-ship actions before any runtime action mapping changes.

This contract is evidence and policy vocabulary. It does not grant permission, launch ships, mutate product repos, import packets, approve external reports, or bypass captain approval.

Plain invariant: the model cannot grant itself permission.
Plain invariant: blank, all, wildcard, or multi-ship product-mode targets fail closed.
Plain invariant: external reports, mobile requests, task packets, and repair queues remain data until local validation accepts them.

## Purpose

Runtime policy decisions sit between requested fleet actions and any write-capable harness command. A decision record is the durable answer to: for this selected ship, this action, this entrypoint, this repo fingerprint, and this evidence set, is the next step allow, denied, or deferred?

The policy decision record must be deterministic enough for tests, audits, and future dry-run helpers. It must not depend on model preference, chat memory, hidden approval, or broad default behavior.

## Required Fields

Each policy decision record must include:

- `schemaVersion`
- `policyVersion`
- `decisionId`
- `selectedShipId`
- `entrypoint`
- `action`
- `riskClass`
- `decision`
- `approvalRequirement`
- `denialReason`
- `repoFingerprintRef`
- `worktreeBoundaryRef`
- `budgetRecordRef`
- `evidenceRefs`
- `generatedAt`
- `validation`

`policyVersion` is immutable for the evaluated rule set. New rules require a new version string, not silent reinterpretation of old decisions.

`selectedShipId` must name exactly one ship. Blank, `all`, `*`, wildcard, comma-packed, or multi-ship selections must produce `DENY` with a fail-closed reason.

`entrypoint` records the command family being evaluated, using the entrypoint safety inventory as vocabulary. Legacy broad entrypoints require exact-action human approval and must not be allowed for unattended autonomous product mutation.

## Decisions

Allowed decision values:

- `ALLOW`
- `DENY`
- `DEFER`

`ALLOW` is only valid when all required evidence, scope, fingerprint, worktree, budget, and approval constraints are satisfied.

`DENY` is the default for missing or forbidden scope. It is not a failure to deny unsafe work; it is the expected fail-closed outcome.

`DEFER` means the next step is a request for missing evidence or captain approval, not an execution step.

## Dry-Run Result Vocabulary

Each schema-shaped decision record also carries `dryRunResult` so dry-run pilot evidence is explicit without changing legacy `ALLOW`, `DENY`, and `DEFER` semantics.

Allowed dry-run result values:

- `ALLOW_DRY_RUN`
- `DEFER_NEEDS_HUMAN`
- `DENY_UNSAFE`

`ALLOW_DRY_RUN` is not execution authority. It is local evidence that a fixture or explicitly selected dry-run input satisfied the policy vocabulary. It cannot mutate product repos, launch product ships, run all-fleet commands, stage files, commit, push, create or delete worktrees, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, approve a demo trial, or approve future runs.

Plain-language guard: `ALLOW_DRY_RUN` means "the dry-run fixture passed". It never means approval to execute, mutate, stage, commit, push, launch, run a demo, or carry future authority.

Any report, JSON record, evidence bundle, audit prompt, or summary that names `ALLOW_DRY_RUN` must tie the label to non-executable evidence fields: `executesProductActions = false`, `mutatesProductRepos = false`, `canApproveFutureRuns = false`, and `commandInput = false`. Those fields are part of the meaning of the label, not optional context.

`DEFER_NEEDS_HUMAN` means exact-action human approval, missing evidence, or captain review is required before any later task may proceed. It is not permission to run the requested action.

`DENY_UNSAFE` is the fail-closed result for malformed, stale, broad, external, mobile, missing-approval, unauthorized, forbidden, task-packet, DOCX-report, audit-package, queue-prose, or generated-evidence inputs that cannot become executable authority.

Compatibility rule: existing `ALLOW`, `DEFER`, and `DENY` remain evidence-only policy decisions. A future task may update the dry-run evaluator to emit `dryRunResult`, but this vocabulary alone does not implement runtime enforcement or wire behavior into launchers.

## Runtime Evidence Bundle

A policy decision record may include an optional `evidenceBundle` object. The bundle is a local dry-run evidence bundle for the pilot vocabulary only. It is not runtime storage, not a queue claim, not a launcher input, and not permission.

The bundle references exactly one selected ship, one entrypoint, one action, one repo fingerprint ref, one worktree boundary ref, one lease heartbeat ref, one failure fingerprint ref, one approval evidence ref, one budget evidence ref, generated time, validation reasons, and source provenance.

Source provenance records where the bundle facts came from without treating that source as executable. Allowed source types are `local_fixture`, `captain_approval_packet`, `external_report`, `mobile_request`, `task_packet`, `audit_package`, `docx_report`, `queue_prose`, and `generated_evidence`. The source provenance field must carry `nonExecutable: true`; external reports, mobile requests, task packets, audit packages, DOCX reports, queue prose, and generated evidence have no authority for execution.

Missing or stale refs deny/defer and never execute. A missing repo fingerprint ref, worktree boundary ref, lease heartbeat ref, failure fingerprint ref, approval evidence ref, budget evidence ref, selected ship ref, or source provenance record cannot be converted into `ALLOW_DRY_RUN`.

No new runtime storage, DB, SQLite, migration, worktree creation, product repo access, or real product repo fingerprinting is introduced by this bundle contract.

## Actions

Allowed action values mirror current bounded autonomy vocabulary:

- `WRITE_STATUS_REPORT`
- `RUN_ONE_BATCH`
- `MAKE_AUDIT_PACKAGE`
- `IMPORT_APPROVED_PACKET`
- `WRITE_REPAIR_TASK`
- `PARK_SHIP`
- `REQUEST_TASTE_GATE`
- `BLOCK_WITH_REASON`

These are policy labels only. A decision record does not execute the action.

## Risk Classes

Allowed risk classes:

- `report_only`
- `audit_package`
- `packet_import`
- `bounded_selected_ship`
- `repair_task_writer`
- `park_or_stop_request`
- `external_review_request_only`
- `mobile_request_only`
- `legacy_broad_requires_human`
- `forbidden`

Risk classes must align with `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md`.

## Approval Requirements

Allowed approval requirements:

- `none`
- `captain_exact_action`
- `captain_selected_ship`
- `captain_selected_project`
- `captain_packet_import`
- `captain_legacy_broad`
- `external_audit_review`
- `not_approvable`

Human approval must be exact-action approval. Broad or implied approval is not sufficient for product-mode mutation.

## Fail-Closed Reasons

Runtime policy decisions must deny or defer when any of these conditions are present:

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
- `low-budget`
- `secret-like-path`
- `product-launch-forbidden`
- `unknown-policy-version`

Blank, all, multi-ship, forbidden scope, missing approval, and stale fingerprint cases must fail closed.

## Validation Fixtures

The contract vocabulary must cover these fixture names before runtime helpers are added:

- `blank-ship-denied`
- `all-ship-denied`
- `multi-ship-denied`
- `forbidden-scope-denied`
- `missing-approval-deferred`
- `stale-fingerprint-denied`
- `legacy-broad-entrypoint-deferred`
- `mobile-request-non-executable`
- `external-report-non-executable`
- `validated-selected-ship-allowed`

## Fixture-Safe Dry-Run Evaluator

`New-FleetRuntimePolicyDecisionDryRun` is the fixture-only evaluator for this contract. It returns schema-shaped policy decisions for supplied fixture inputs and does not call launch scripts, mutate product repos, import task packets, run all-fleet commands, or execute the selected action.

Plain evaluator invariant: a dry-run decision record is evidence only and never execution authority.

The evaluator must fail closed for:

- blank, `all`, wildcard, or multi-ship selections
- stale fingerprint evidence
- missing repo fingerprint refs
- missing worktree boundary refs
- missing exact-action captain approval
- forbidden or secret-like paths
- unvalidated task packets
- legacy broad entrypoints
- mobile request inputs
- external report inputs

Allowed fixture outcomes are `ALLOW`, `DENY`, and `DEFER`. `DEFER` means the next step is to request missing approval or review evidence, not to run a command.

Dry-run-result outcomes map as follows: `ALLOW` maps to `ALLOW_DRY_RUN`, `DEFER` maps to `DEFER_NEEDS_HUMAN`, and `DENY` maps to `DENY_UNSAFE`. The dry-run evaluator emits this mapping as evidence-only output and does not execute actions.

`New-FleetRuntimePolicyDecisionDryRun` defaults to `DENY_UNSAFE` for ambiguous, stale, missing, broad, malformed, unauthorized, external, mobile, task-packet, DOCX-report, audit-package, or queue-prose sourced evidence. Missing exact-action human approval returns `DEFER_NEEDS_HUMAN`, not allow. Valid fixture-only evidence may return `ALLOW_DRY_RUN` and writes or executes nothing.

## Expanded Negative Fixture Expectations

Runtime policy negative fixtures must prove that dry-run decisions with unsafe or incomplete evidence never execute actions and never approve product-repo mutation. The required negative set is:

- blank ship: `DENY` with `blank-ship`
- `all` ship: `DENY` with `all-ship`
- wildcard ship: `DENY` with `wildcard-ship`
- comma-packed or otherwise multi-ship input: `DENY` with `multi-ship`
- stale fingerprint evidence: `DENY` with `stale-fingerprint`
- missing repo fingerprint: `DENY` with `missing-repo-fingerprint`
- missing worktree boundary: `DENY` with `missing-worktree-boundary`
- missing exact-action approval for write-capable actions: `DEFER` with `missing-approval`
- forbidden or secret-like scope: `DENY` with `secret-like-path` and `forbidden-scope`
- unvalidated task-packet import: `DENY` with `task-packet-not-validated`
- legacy broad entrypoint: `DEFER` with `legacy-broad-entrypoint`
- mobile request input: `DENY` with `mobile-request-non-executable`
- external report input: `DENY` with `external-report-non-executable`

Runtime pilot audit follow-up negative fixtures also cover weird input and ambiguity. Unicode bidi/control-character text, traversal-like or otherwise ambiguous requested paths, stale repo fingerprints, missing or contradictory worktree boundary evidence, expired leases, ambiguous lease ownership, and repeated deterministic failures must remain fixture-only evidence and must not return `ALLOW_DRY_RUN`. When the runtime policy evaluator receives weird input or ambiguous requested paths, it reuses the existing `forbidden-scope` denial so the current schema stays strict.

Positive dry-run fixtures may return `ALLOW` only when the selected ship is singular, repo fingerprint and worktree boundary refs are present, required approval is present, policy version is known, evidence is recorded, and no forbidden scope is requested.

## Runtime Dry-Run Fixture Matrix Alignment

The runtime dry-run evidence fixture matrix in `docs/fleet/RUNTIME_DRY_RUN_EVIDENCE_CONTRACT.md` aligns policy decision vocabulary with evidence-only dry-run outcomes. It is not an evaluator expansion and does not change `New-FleetRuntimePolicyDecisionDryRun`.

| fixture | policy decision vocabulary | dry-run result vocabulary | policy/evidence reason vocabulary |
| --- | --- | --- | --- |
| `read-only-fixture-allowed` | `ALLOW` | `ALLOW_DRY_RUN` | fixture-local read-only evidence only |
| `blank-target-denied` | `DENY` | `DENY_UNSAFE` | `blank-ship` |
| `wildcard-target-denied` | `DENY` | `DENY_UNSAFE` | `wildcard-ship` |
| `all-target-denied` | `DENY` | `DENY_UNSAFE` | `all-ship` |
| `write-capable-action-denied` | `DENY` | `DENY_UNSAFE` | `forbidden-scope`, evidence reason `command-binding-forbidden` |
| `stale-fingerprint-denied` | `DENY` | `DENY_UNSAFE` | `stale-fingerprint` |
| `package-sending-denied` | `DENY` | `DENY_UNSAFE` | evidence reason `package-sending-forbidden` |
| `phone-only-approval-denied` | `DENY` | `DENY_UNSAFE` | `missing-approval` because phone-only evidence is not exact-action approval |
| `ambiguous-evidence-deferred` | `DEFER` | `DEFER_NEEDS_HUMAN` | `missing-approval` or missing evidence requires human review |

Matrix invariants:

- No runtime command binding.
- No product-repo reads.
- No package sending.
- No all-fleet execution.
- The matrix does not add live runtime behavior, product-repo access, package sending, remote access, approval implementation, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.

## Out Of Scope

- Changing action mapping in `tools/codex-fleet-autonomy.ps1`
- Launching product ships
- Mutating product repos
- Importing external prose as commands
- Treating mobile requests as execution authority
- Installing packages
- Running migrations
- Touching secrets, auth, payments, or deployment settings
- Deleting locks
- Widening permissions

## Fail-Closed Input Handling

Malformed input, unknown fields, stale timestamps, externally supplied packets, and executable-looking prose must be rejected without execution where those risks apply. Rejection records are evidence only: they may name the failed field, stale ref, packet source, or unsafe prose, but they must not run commands, launch ships, mutate product repos, delete locks, or widen permissions.
