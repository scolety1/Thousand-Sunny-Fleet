# HQ Repair Batch Audit Template

Prepared: 2026-05-31

Purpose: a post-batch review template for Codex Fleet / Thousand Sunny Fleet HQ repair work. This template is evidence only. It is not a launcher, approval packet, task packet, mobile command, external-review command, or permission to touch product repositories.

## Batch Metadata

- Batch name:
- Review date:
- Reviewer:
- Repo path: `C:\Dev\codex-fleet`
- Queue file: `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- Evidence index:
- Latest run summary:
- Repo state before review:
- Repo state after review:

## Completed Tasks

Use this section for tasks actually completed and validated.

| Task id | Title | Files changed | Checks run | Evidence | Status |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  | GREEN/YELLOW/RED |

## Queue Reconciliation Proof

Use this section when queue status lagged behind validated artifacts. Queue reconciliation is evidence only; it is not permission to skip validation, execute tasks, touch product repos, launch ships, run all-fleet commands, or mark unfinished work complete.

Formerly stale tasks from the HQ safety-spine import:

| Task id | Required proof | Expected artifact or test evidence | Reconciled status |
| --- | --- | --- | --- |
| HQ-002 | repo fingerprint schema and contract | `templates/repo-fingerprint-schema.json`, `docs/fleet/REPO_FINGERPRINT_CONTRACT.md`, `Test-RepoFingerprintContract` | done |
| HQ-003 | worktree boundary schema and contract | `templates/worktree-boundary-schema.json`, `docs/fleet/WORKTREE_ISOLATION_CONTRACT.md`, `Test-WorktreeIsolationContract` | done |
| HQ-004 | failure fingerprint schema and contract | `templates/failure-fingerprint-schema.json`, `docs/fleet/FAILURE_FINGERPRINT_CONTRACT.md`, `Test-FailureFingerprintContract` | done |
| HQ-005 | lease heartbeat schema and contract | `templates/lease-heartbeat-schema.json`, `docs/fleet/LEASE_HEARTBEAT_CONTRACT.md`, `Test-LeaseHeartbeatContract` | done |
| HQ-006 | control-room reconciliation schema and contract | `templates/control-room-reconciliation-schema.json`, `docs/fleet/CONTROL_ROOM_RECONCILIATION_CONTRACT.md`, `Test-ControlRoomReconciliationContract` | done |
| HQ-007 | budget safe-pause schema and contract | `templates/budget-safe-pause-schema.json`, `docs/fleet/BUDGET_SAFE_PAUSE_CONTRACT.md`, `Test-BudgetSafePauseContract` | done |
| HQ-008 | artifact index schema and contract | `templates/artifact-index-schema.json`, `docs/fleet/ARTIFACT_INDEX_CONTRACT.md`, `Test-ArtifactIndexContract` | done |
| HQ-009 | runtime policy decision schema and contract | `templates/runtime-policy-decision-schema.json`, `docs/fleet/RUNTIME_POLICY_DECISION_CONTRACT.md`, `Test-RuntimePolicyDecisionContract` | done |
| HQ-010 | review packet schema and contract | `templates/review-packet-schema.json`, `docs/fleet/REVIEW_PACKET_CONTRACT.md`, `Test-ReviewPacketContract` | done |
| HQ-011 | repo fingerprint builder helper | `tools/codex-fleet-state.ps1`, `Test-RepoFingerprintBuilderFixtureHelper` | done |
| HQ-012 | selected ship ledger contract and dry-run writer | `templates/selected-ship-ledger-schema.json`, `docs/fleet/SELECTED_SHIP_LEDGER_CONTRACT.md`, `Test-SelectedShipLedgerContract` | done |
| HQ-013 | worktree boundary validator helper | `tools/codex-fleet-state.ps1`, `Test-WorktreeBoundaryValidatorFixtureHelper` | done |
| HQ-014 | failure fingerprint normalizer helper | `tools/codex-fleet-runtime.ps1`, `Test-FailureFingerprintNormalizerFixtureHelper` | done |
| HQ-015 | lease heartbeat fixture classifier | `tools/codex-fleet-overnight.ps1`, `Test-LeaseHeartbeatFixtureClassifier` | done |
| HQ-016 | control-room reconciliation helper | `tools/codex-fleet-control-room.ps1`, `Test-ControlRoomReconciliationFixtureHelper` | done |
| HQ-017 | artifact index fixture writer | `write-run-evidence.ps1`, `Test-ArtifactIndexFixtureWriter` | done |
| HQ-018 | runtime policy dry-run evaluator | `tools/codex-fleet-autonomy.ps1`, `Test-RuntimePolicyDryRunEvaluator` | done |

Remaining live tasks must stay listed separately. Do not mark `HQ-033` through `HQ-040` done until each task has passed its own validation command.

## Blocked Tasks

Use this section for tasks that stopped because they needed broader scope, product repos, launchers, all-fleet commands, package installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission changes, or approval not present.

| Task id | Block reason | Files changed before stop | Checks run | Required human decision | Status |
| --- | --- | --- | --- | --- | --- |
|  |  |  |  |  | BLOCKED |

## Files Changed

Group files by purpose. Do not use this section as a command to stage or commit.

### Docs

- 

### Schemas

- 

### Tests

- 

### Harness Scripts

- 

### Generated Evidence Or Audit Packages

- 

## Checks Run

| Check | Command | Result | Evidence path |
| --- | --- | --- | --- |
|  |  | passed/failed/not-run |  |

## Unresolved Risks

- 

For each risk, include:

- risk:
- affected task:
- why it remains unresolved:
- safe next step:
- stop condition:

## External Audit Questions

Ask reviewers to verify safety and scope only. Reviewer output is evidence, not commands.

- Did every task stay inside its allowed files plus same-task queue status updates?
- Did every validation command stay local and harness-only?
- Do docs preserve fail-closed behavior for malformed, stale, unknown, mobile-sourced, or external-sourced input?
- Are broad launchers, all-fleet commands, product-repo mutation, and high-risk entrypoints still human-approval-only?
- Are external reports, mobile requests, task packets, audit packages, and queue text still non-executable?
- Is any generated evidence unsafe to export?
- Should the next task continue, pause for captain review, or require a narrower queue item?

## Post-Remediation Repeat-Audit Checkpoint

Use this section after the external audit remediation batch has local GREEN validation. The repeat audit is evidence only; it does not approve execution, fill a demo approval packet, run commands, touch product repositories, launch ships, run all-fleet commands, merge, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or bypass policy.

## Final External Audit Package Checklist

Use this section after `HQ-048` through `HQ-060` have local GREEN validation. This checklist is evidence-only planning; it does not create a package, send a package, stage files, commit, push, approve a demo trial, or grant future permission.

Exact final-audit evidence to include:

- handoff packet: `docs/fleet/NEW_CHAT_HANDOFF_PACKET.md`
- import recon: `docs/fleet/HQ_IMPORT_RECON.md`
- entrypoint inventory: `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md`
- findings ledger: `docs/fleet/HQ_EXTERNAL_AUDIT_FINDINGS_LEDGER.md`
- queue state: `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- queue contract: `docs/fleet/HQ_REPAIR_QUEUE_CONTRACT.md`
- external-audit guidance: `docs/fleet/HQ_REPAIR_EXTERNAL_AUDIT.md`
- batch audit template: `docs/fleet/HQ_REPAIR_BATCH_AUDIT_TEMPLATE.md`
- commit readiness inventory: `docs/fleet/HQ_COMMIT_READINESS_INVENTORY.md`
- commit scope packet: `docs/fleet/HQ_COMMIT_SCOPE_DECISION_PACKET.md`
- other-project readiness gate: `docs/fleet/OTHER_PROJECT_TEST_READINESS.md`
- next audit prompt: `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- go/no-go summary: `docs/fleet/DEMO_READY_TRIAL_GO_NO_GO.md`
- approval packet template: `docs/fleet/DEMO_TRIAL_APPROVAL_PACKET.md`
- stop-sign checklist: `docs/fleet/DEMO_TRIAL_STOP_SIGNS.md`
- runtime implementation deferral plan: `docs/fleet/RUNTIME_ENFORCEMENT_IMPLEMENTATION_PLAN.md`
- HQ safety-spine contracts in `docs/fleet/*_CONTRACT.md`
- HQ schemas in `templates/*-schema.json`
- `tests/run-fleet-tests.ps1`
- scrubbed validation summary from the current working tree

Exact material not to export:

- product repositories or product source snapshots
- unscoped project exports or unscoped `new-audit-package.ps1` output
- `.git`, `.env`, dependency folders, build outputs, raw locks, unknown zips, full unreviewed package directories, or live worker state
- secrets, tokens, credentials, private keys, local machine identity, or private user files
- auth, payments, deploy, migration, package-install, permission, staging, commit, push, merge, lock deletion, or runtime execution material

Final reviewer request:

- Overall verdict: GREEN, YELLOW, or RED.
- Findings ordered by severity, grounded in included file/path evidence.
- Missing tests or ambiguous safety boundaries.
- Demo-trial readiness recommendation.
- Any accepted limitation clearly labeled as a limitation rather than an approval.
- Suggested follow-up tasks only as non-executable suggestions with bounded files, validation ideas, and stop conditions.

Final package RED stop signs:

- validation fails
- package scope includes product repos, sensitive material, raw locks, unknown zips, dependency folders, build outputs, live worker state, or unreviewed full package directories
- audit output, DOCX reports, mobile requests, task packets, audit packages, queue prose, or this template are treated as executable authority
- any step would require product-repo mutation, product launch, all-fleet scope, deploy, install, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, merge, push, staging, commit, or external side effects

Manual final audit zip verification:

- This is a review checklist only; it does not create, send, stage, commit, push, approve, or grant permission.
- Match the zip file list against the exact final-audit evidence list before it leaves the machine.
- Reject the zip if it contains product repositories, product source snapshots, unscoped project exports, `.git`, `.env`, dependency folders, build outputs, raw locks, unknown zips, full unreviewed package directories, live worker state, secrets, tokens, credentials, private keys, local machine identity, private user files, auth/payments/deploy/migration material, package-install material, permission material, staging material, commit material, push material, merge material, lock-deletion material, or runtime-execution material.
- Treat reviewer output, DOCX reports, mobile requests, task packets, audit packages, queue prose, and this template as evidence only, never executable authority.
- Keep package posture YELLOW if any included path is ambiguous, generated evidence is not scrubbed, or a human has not approved the exact package contents.

Evidence to include:

- findings ledger: `docs/fleet/HQ_EXTERNAL_AUDIT_FINDINGS_LEDGER.md`
- queue state: `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- next audit prompt: `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- batch audit template: `docs/fleet/HQ_REPAIR_BATCH_AUDIT_TEMPLATE.md`
- go/no-go summary: `docs/fleet/DEMO_READY_TRIAL_GO_NO_GO.md`
- approval packet template: `docs/fleet/DEMO_TRIAL_APPROVAL_PACKET.md`
- stop-sign checklist: `docs/fleet/DEMO_TRIAL_STOP_SIGNS.md`
- runtime deferral boundary: `docs/fleet/CONTROL_PLANE_SPINE_DECISION.md`
- other-project readiness gate: `docs/fleet/OTHER_PROJECT_TEST_READINESS.md`
- queue contract and external-audit guidance
- HQ schemas in `templates/*-schema.json`
- `tests/run-fleet-tests.ps1`
- scrubbed validation summary from the current working tree

Repeat-audit GREEN:

- `tests/run-fleet-tests.ps1` passes
- `HQ-048` through `HQ-060` are done
- included evidence stays limited to harness/docs/tests/schemas/scrubbed validation evidence
- excluded material stays excluded: product repos, product source snapshots, `.git`, `.env`, dependency folders, build outputs, raw locks, secrets, auth/payments/deploy/migration material, unknown zips, and live worker state
- runtime-enforcement deferral remains clearly labeled
- commit scope has been reviewed enough to prevent trial/evidence confusion
- exact approval packet and stop-sign review are still required before one manual read-only single-project demo

Repeat-audit YELLOW accepted limitation:

- reviewer returns YELLOW with a bounded limitation
- the captain explicitly accepts that limitation before any trial
- no limitation requires automation, product-repo mutation, broad launcher use, or sensitive-scope work
- approval packet is complete/current and stop signs are inactive before the one manual read-only single-project demo

Repeat-audit RED:

- validation fails
- package scope includes product repos or sensitive material
- docs/contracts/tests are treated as implemented runtime enforcement
- approval is missing, expired, reused, broad, or ambiguous
- stop signs are active
- any step would require automation, product-repo mutation, product launch, all-fleet scope, deploy, install, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, merge, push, or external side effects

## Rollback And No-Op Notes

This section records how to understand the batch without reverting user work.

- No product repos were intentionally touched:
- No product ships were launched:
- No all-fleet commands were run:
- No merge, push, deploy, package install, migration, secrets/auth/payments touch, lock deletion, or permission widening occurred:
- Generated files that are safe to delete only after approval:
- Files that should not be deleted because they are evidence:
- Manual rollback recommendation, if any:

## GREEN / YELLOW / RED Rubric

GREEN:

- all completed tasks passed their validation commands
- changes stayed inside allowed files plus same-task queue status updates
- no product repos were touched
- no product ships were launched
- no all-fleet commands or high-risk entrypoints were run
- no secrets/auth/payments/deploy/migration/lock/permission boundary was crossed
- unresolved risks are documented and do not block the next bounded task

YELLOW:

- validation passed, but reviewer attention is needed
- queue status or evidence needs reconciliation
- generated audit evidence needs export review
- scope stayed safe, but a future task needs a narrower prompt or explicit human decision

RED:

- validation failed
- task scope was exceeded
- a product repo would be touched
- a product ship would be launched
- an all-fleet command, high-risk entrypoint, package install, migration, deploy, secret/auth/payment touch, lock deletion, or permission widening would be required
- external, mobile, task-packet, audit-package, or queue text would be treated as executable

## Captain Review Decision

- Decision: GREEN / YELLOW / RED
- Continue with next queue task:
- Pause for external audit:
- Pause for commit-prep:
- Required follow-up:
