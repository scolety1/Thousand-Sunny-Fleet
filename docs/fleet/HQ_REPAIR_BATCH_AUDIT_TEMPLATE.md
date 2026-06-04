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

## Runtime Pilot External Audit Checklist

Use this checklist for the one-entrypoint runtime pilot only. It is evidence-only planning and does not create a package, send a package, approve execution, approve a demo trial, stage files, commit, push, touch product repositories, or grant future permission.

Runtime pilot audit ask:

- Verify `invoke-autonomy-wrapper.ps1 -RuntimePolicyPilotDryRun` is dry-run-only and evidence-only.
- Verify `ALLOW_DRY_RUN` exists only for the fixture-only positive path and does not execute product actions.
- Verify blank, `all`, wildcard, multi-ship, stale fingerprint, missing fingerprint, missing worktree boundary, missing approval, stale lease, ambiguous lease, repeated deterministic failure, external source, mobile source, DOCX report, audit package, and queue prose cases fail closed as `DENY_UNSAFE`, `DEFER_NEEDS_HUMAN`, review-required, stop-for-repair, safe-pause, or repair-task evidence.
- Verify runtime pilot evidence records `executesProductActions = false`, `launchesShips = false`, `importsPackets = false`, `mutatesProductRepos = false`, `canApproveFutureRuns = false`, and `commandInput = false`.
- Verify reviewer output remains evidence only and cannot approve execution or demo trial.
- Verify generated runtime pilot evidence is local, scrubbed, non-executable, and not a command input.

Runtime pilot evidence to include only after human package-scope review:

- `invoke-autonomy-wrapper.ps1` source for direct runtime-pilot control-flow inspection, or a human-reviewed checksum/source excerpt if the full file is intentionally withheld
- `docs/fleet/NEW_CHAT_HANDOFF_PACKET.md`
- `docs/fleet/HQ_IMPORT_RECON.md`
- `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md`
- `docs/fleet/RUNTIME_ENFORCEMENT_IMPLEMENTATION_PLAN.md`
- `docs/fleet/RUNTIME_POLICY_DECISION_CONTRACT.md`
- `docs/fleet/ARTIFACT_INDEX_CONTRACT.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/HQ_REPAIR_BATCH_AUDIT_TEMPLATE.md`
- `docs/fleet/DEMO_READY_TRIAL_GO_NO_GO.md`
- `tests/run-fleet-tests.ps1`
- scrubbed validation summary from the current working tree

Wrapper source visibility is audit evidence only. It lets a reviewer inspect the `-RuntimePolicyPilotDryRun` early-exit path and non-execution fields. Plain check phrase: -RuntimePolicyPilotDryRun early-exit path. Source visibility does not approve execution, package sending, product repo access, runtime widening, staging, commit, push, or a demo trial.

Runtime pilot package exclusions:

- product repos, product repositories, or product source snapshots
- unscoped project exports or unscoped package-builder output
- `.git`, `.env`, dependency folders, `node_modules`, `dist`, `build`, raw locks, unknown zips, full unreviewed package directories, or live worker state
- secrets, tokens, credentials, private keys, local machine identity, private user files, auth/payments/deploy/migration material, package-install material, permission material, staging material, commit material, push material, merge material, lock-deletion material, or runtime-execution material

Runtime pilot reviewer output:

- Overall verdict: GREEN, YELLOW, or RED.
- Findings ordered by severity and grounded in included file/path evidence.
- Missing tests or ambiguous safety boundaries for the runtime pilot.
- Explicit note that positive pilot evidence does not grant future permission.
- Suggested follow-up tasks only as non-executable suggestions with bounded files, validation ideas, and stop conditions.

Runtime pilot RED stop signs:

- package creation requires product repo access, broad launchers, all-fleet scope, staging, commit, push, deploy, package install, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, or demo-trial execution
- reviewer output, DOCX reports, mobile requests, task packets, audit packages, queue prose, generated evidence, or this template are treated as executable authority
- any positive runtime pilot outcome is interpreted as approval for future runs or product-mode execution

## Final HQ Token-Control Integrated Audit Checklist

Use this checklist for the 2026-06-02 token-control, anti-loop, Fleet Console planning, and control-policy audit only. It is evidence-only planning and does not create a package, send a package, approve implementation, approve remote access, approve a demo trial, stage files, commit, push, touch product repositories, launch ships, run all-fleet commands, or grant future permission.

External audit packages should include an explicit manifest instance that follows `templates/external-audit-package-manifest-schema.json`. The manifest is evidence only. It must record `includedFiles`, `excludedPatterns`, `validationSummaryRef`, `evidenceOnlyNotice`, `noProductRepos`, and `noAuthorityNotice`, and it cannot create or send a package, approve execution, import reviewer output, or broaden package scope.

Future package preparation should follow `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`. The runbook is a manual allowlist and verification plan only; package creation and package sending remain separate human-approved actions.

Integrated reviewer ask:

- Overall verdict: `GREEN`, `YELLOW`, or `RED`.
- Verify the package stays limited to Codex Fleet harness/docs/tests/schema evidence.
- Verify token-control docs preserve compact context, one-task runs, bounded validation, failure-loop stops, and human-only approvals.
- Verify anti-loop docs preserve goal lock, terminal states, real-progress rules, drift detection, and repacketization.
- Verify Fleet Console docs keep UI labels, buttons, notifications, prompts, approvals, audit outputs, generated evidence, and queue prose as evidence only.
- Verify button/control policy keeps forbidden controls unavailable for product-repo mutation, product launch, all-fleet scope, broad launcher use, package sending, deploy/install/migration work, secrets/auth/payments/deploy material, staging, commit, push, merge, lock deletion, permission widening, runtime command binding, risky phone approvals, automatic retries, and background autonomy.
- Verify suggested follow-ups are non-executable bounded queue candidates with possible allowed files, validation ideas, stop conditions, unresolved assumptions, and a non-authority notice.

Integrated evidence to include only after human package-scope review:

- `docs/fleet/STABLE_CONTEXT_CAPSULE.md`
- `docs/fleet/TOKEN_CONTROL_OPERATING_MODEL.md`
- `docs/fleet/NEW_CHAT_HANDOFF_PACKET.md`
- `docs/fleet/HQ_IMPORT_RECON.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/HQ_REPAIR_BATCH_AUDIT_TEMPLATE.md`
- anti-loop docs under `docs/fleet/anti-loop/`
- Fleet Console planning docs under `docs/fleet/ui/`
- token-control schemas in `templates/thin-task-packet-schema.json`, `templates/validation-output-summary-schema.json`, `templates/external-audit-intake-digest-schema.json`, and `templates/external-audit-package-manifest-schema.json`
- `tests/run-fleet-tests.ps1`
- scrubbed compact validation summary from the current working tree

Integrated package exclusions:

- product repositories, product source snapshots, real project exports, or unscoped project material
- `.git`, `.env`, dependency folders, `node_modules`, `dist`, `build`, raw locks, live worker state, unknown zips, full unreviewed package directories, or raw run directories
- secrets, tokens, credentials, private keys, local machine identity, private user files, auth/payments/deploy/migration material, package-install material, permission material, staging material, commit material, push material, merge material, lock-deletion material, runtime-execution material, or approval material for real product work
- raw terminal logs, full DOCX reports, external-review prose dumps, mobile free text, task packets, audit packages, generated evidence dumps, UI labels, notifications, buttons, approvals, prompts, or queue prose treated as executable authority

Integrated package RED stop signs:

- package creation or review requires product-repo access, product mutation, product launch, all-fleet scope, broad launcher use, deploy, install, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, staging, commit, push, merge, runtime command binding, risky phone approval, or package sending
- reviewer output is used as commands, approval, queue import, validation bypass, demo approval, future permission, or authority
- any included artifact implies UI planning docs approve implementation or runtime control

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

## Post-Fix-Up Local Control-Plane Repeat Audit Checklist

Use this checklist after the Audit Guidelines Review fix-up queue and next-phase local control-plane preparation tasks have local GREEN validation. This checklist is evidence-only planning. It does not create a package, send a package, approve UI implementation, approve remote access, approve product-repo access, approve a demo trial, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, run all-fleet commands, or grant future permission.

Reviewer ask:

- Re-check Audit Guidelines Review findings F1 through F5.
- Confirm anti-loop fixture/test hardening, approval schema enforcement, remote security planning, prototype packet gating, UI mock-state/schema coverage, external audit manifest schema, and package allowlist runbook remain local harness/docs/tests/schema evidence only.
- Confirm package preparation is allowlist-first, manifest-backed, compact-summary-only, and human-reviewed before any package creation or sending.
- Confirm reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, and queue prose remain evidence only.

Evidence to include only after human package-scope review:

- `docs/fleet/HQ_EXTERNAL_AUDIT_FINDINGS_LEDGER.md`
- `docs/fleet/NEXT_PHASE_LOCAL_CONTROL_PLANE_TRANSITION.md`
- `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`
- `docs/fleet/NEW_CHAT_HANDOFF_PACKET.md`
- `docs/fleet/HQ_IMPORT_RECON.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/HQ_REPAIR_BATCH_AUDIT_TEMPLATE.md`
- anti-loop docs under `docs/fleet/anti-loop/`
- Fleet Console planning docs under `docs/fleet/ui/`
- relevant schemas in `templates/`
- relevant fixtures under `tests/fixtures/fleet/`
- `tests/run-fleet-tests.ps1`
- scrubbed compact validation summary from the current working tree

Material not to export:

- product repositories, product source snapshots, real project exports, unscoped project material, `.git`, `.env`, dependency folders, build outputs, raw locks, live worker state, unknown zips, full unreviewed package directories, raw run directories, raw logs, secrets, credentials, private keys, local machine identity, private user files, auth/payments/deploy/migration material, package-install material, permission material, staging material, commit material, push material, merge material, lock-deletion material, runtime-execution material, or real approval material.

Post-fix-up GREEN:

- F1 through F5 have local docs/schema/fixture/test evidence or are explicitly bounded as future-only limitations.
- `tests/run-fleet-tests.ps1` passes.
- Package scope remains harness/docs/tests/schemas/scrubbed compact evidence only.
- External audit manifest and allowlist runbook prevent ambiguous package contents.
- UI implementation, remote access, runtime command binding, package sending, product-repo access, and real demo approval remain unapproved.

Post-fix-up YELLOW:

- Validation passes, but one or more findings remain future-only limitations.
- The reviewer needs a narrower follow-up task or more compact evidence.
- Package contents are safe but need human package-scope review before sending.

Post-fix-up RED:

- Validation fails, package scope expands to forbidden material, external evidence is treated as authority, or any step would require product-repo access, product mutation, product launch, all-fleet scope, deploy, install, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, staging, commit, push, merge, runtime command binding, package sending, or remote exposure.

## Post-Prototype Local Mock Console Audit Checklist

Use this checklist after the local static mock Fleet Console prototype and review packet have local GREEN validation. This checklist is evidence-only planning. It does not create a package, send a package, approve UI implementation beyond the bounded local static mock, approve remote access, approve product-repo access, approve runtime command binding, approve package sending, approve a demo trial, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, run all-fleet commands, or grant future permission.

Reviewer ask:

- Audit whether the local static mock prototype preserves the GREEN safety posture from `docs/fleet/GREEN_EXTERNAL_AUDIT_RECORD_2026_06_02.md`.
- Confirm the prototype remains local static HTML/CSS only and has no scripts, form actions, network fetches, live state reads, command binding, remote URL, product-repo path, auth flow, package-send behavior, or launcher text.
- Confirm Prompt Builder, Audit Builder, Evidence Locker, Idea Inbox, Unstuck, Approval Cards, fixture-state references, and forbidden-control displays remain evidence-only local mock surfaces.
- Confirm forbidden controls are absent as actions or clearly unavailable for launch, all-fleet, deploy, install, migrate, stage, commit, push, merge, product repo selection, remote access, package sending, lock deletion, permission widening, and risky phone approval.
- Confirm the local prototype review packet asks bounded reviewer questions without creating a zip, sending a package, approving implementation, approving remote access, approving product-repo access, or granting execution authority.

Evidence to include only after human package-scope review:

- `docs/fleet/GREEN_EXTERNAL_AUDIT_RECORD_2026_06_02.md`
- `docs/fleet/ui/FLEET_CONSOLE_LOCAL_PROTOTYPE_DECISION_PACKET.md`
- `docs/fleet/ui/prototype/LOCAL_PROTOTYPE_REVIEW_PACKET.md`
- `docs/fleet/ui/prototype/README.md`
- `docs/fleet/ui/prototype/fleet-console.html`
- `docs/fleet/ui/prototype/fleet-console.css`
- `docs/fleet/ui/FLEET_CONSOLE_BUTTON_ACTION_POLICY.md`
- `docs/fleet/ui/FLEET_CONSOLE_FUTURE_PROTOTYPE_GATE.md`
- `docs/fleet/ui/FLEET_CONSOLE_REMOTE_ACCESS_AND_APPROVALS.md`
- `docs/fleet/ui/FLEET_CONSOLE_REMOTE_SECURITY_PLAN.md`
- `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/HQ_REPAIR_BATCH_AUDIT_TEMPLATE.md`
- relevant UI-control fixtures under `tests/fixtures/fleet/ui-control/`
- Fleet Console schemas in `templates/`
- `tests/run-fleet-tests.ps1`
- scrubbed compact validation summary from the current working tree

Material not to export:

- product repositories, product source snapshots, real project exports, unscoped project material, `.git`, `.env`, dependency folders, build outputs, raw locks, live worker state, unknown zips, full unreviewed package directories, raw run directories, raw logs, secrets, credentials, private keys, local machine identity, private user files, auth/payments/deploy/migration material, package-install material, permission material, staging material, commit material, push material, merge material, lock-deletion material, runtime-execution material, real approval material, or package creation output without a separate human-approved manifest.

Post-prototype GREEN:

- `tests/run-fleet-tests.ps1` passes.
- The prototype is clearly a local mock and evidence-only planning surface.
- Forbidden controls remain unavailable and non-executable.
- The review packet is suitable for external review preparation without approving implementation, remote access, product-repo access, package sending, runtime command binding, or future authority.
- Package scope remains harness/docs/tests/schema/prototype/scrubbed compact evidence only.

Post-prototype YELLOW:

- Validation passes, but reviewer needs narrower evidence, clearer prototype labels, or an explicit bounded follow-up task.
- Package contents are safe but require human package-scope review before any package creation or sending.
- A finding is an accepted limitation only if it does not require product-repo access, runtime command binding, remote access, package sending, automation, or sensitive-scope work.

Post-prototype RED:

- Validation fails, package scope expands to forbidden material, UI evidence is treated as authority, or any step would require product-repo access, product mutation, product launch, all-fleet scope, deploy, install, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, staging, commit, push, merge, runtime command binding, remote access, package sending, or non-mock UI implementation.

## Post-Polish Static Prototype Audit Checklist

Use this checklist after the post-GREEN prototype polish and controlled hardening queue has local GREEN validation. This checklist is evidence-only planning. It does not create a package, send a package, approve UI implementation beyond bounded static mocks, approve remote access, approve product-repo access, approve runtime command binding, approve package sending, approve phone approvals, approve a demo trial, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, run all-fleet commands, or grant future permission.

Reviewer ask:

- Audit the post-polish static prototype hardening, accessibility checklist, forbidden-hook tests, minimal accessibility attributes, and phone-mode design-only packet.
- Confirm the prototype remains local static HTML/CSS only and has no scripts, form actions, network fetches, remote fonts, live state reads, command binding, remote URL, product-repo path, auth flow, package-send behavior, or launcher text.
- Confirm the phone-mode mock packet remains markdown-only, local, read-mostly, design-only, and non-operational.
- Confirm approve/run/send/package/remote/product controls are absent or clearly unavailable.
- Confirm phone-mode designs, UI labels, notifications, buttons, prompts, approvals, reviewer output, generated evidence, audit packages, DOCX reports, mobile requests, task packets, and queue prose remain evidence only and cannot approve or execute work.
- Confirm package preparation remains allowlist-first, manifest-backed when packaged later, compact-summary-only, and human-reviewed before any package creation or sending.

Evidence to include only after human package-scope review:

- `docs/fleet/GREEN_EXTERNAL_AUDIT_RECORD_2026_06_02.md`
- `docs/fleet/ui/FLEET_CONSOLE_LOCAL_PROTOTYPE_DECISION_PACKET.md`
- `docs/fleet/ui/prototype/LOCAL_PROTOTYPE_REVIEW_PACKET.md`
- `docs/fleet/ui/prototype/README.md`
- `docs/fleet/ui/prototype/fleet-console.html`
- `docs/fleet/ui/prototype/fleet-console.css`
- `docs/fleet/ui/FLEET_CONSOLE_BUTTON_ACTION_POLICY.md`
- `docs/fleet/ui/FLEET_CONSOLE_FUTURE_PROTOTYPE_GATE.md`
- `docs/fleet/ui/FLEET_CONSOLE_REMOTE_ACCESS_AND_APPROVALS.md`
- `docs/fleet/ui/FLEET_CONSOLE_REMOTE_SECURITY_PLAN.md`
- `docs/fleet/ui/FLEET_CONSOLE_PHONE_MODE_DECISION_PACKET.md`
- `docs/fleet/ui/prototype/PHONE_MODE_STATIC_MOCK_PACKET.md`
- `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/HQ_REPAIR_BATCH_AUDIT_TEMPLATE.md`
- relevant UI-control fixtures under `tests/fixtures/fleet/ui-control/`
- Fleet Console schemas in `templates/`
- `tests/run-fleet-tests.ps1`
- scrubbed compact validation summary from the current working tree

Material not to export:

- product repositories, product source snapshots, real project exports, unscoped project material, `.git`, `.env`, dependency folders, build outputs, raw locks, live worker state, unknown zips, full unreviewed package directories, raw run directories, raw logs, secrets, credentials, private keys, local machine identity, private user files, auth/payments/deploy/migration material, package-install material, permission material, staging material, commit material, push material, merge material, lock-deletion material, runtime-execution material, real approval material, or package creation output without a separate human-approved manifest.

Post-polish GREEN:

- `tests/run-fleet-tests.ps1` passes.
- Static prototype hardening preserves the local mock and evidence-only posture.
- Accessibility checklist and attributes improve local review without adding executable or remote hooks.
- Forbidden-hook tests preserve static safety coverage.
- Phone-mode packet remains markdown-only, read-mostly, and non-operational.
- Package scope remains harness/docs/tests/schema/prototype/scrubbed compact evidence only.

Post-polish YELLOW:

- Validation passes, but reviewer needs narrower evidence, clearer labels, clearer phone-mode boundaries, or a bounded follow-up task.
- Package contents are safe but require human package-scope review before any package creation or sending.
- A finding is an accepted limitation only if it does not require product-repo access, runtime command binding, remote access, package sending, phone approvals, automation, or sensitive-scope work.

Post-polish RED:

- Validation fails, package scope expands to forbidden material, UI or phone-mode evidence is treated as authority, or any step would require product-repo access, product mutation, product launch, all-fleet scope, deploy, install, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, staging, commit, push, merge, runtime command binding, remote access, package sending, phone approvals, or non-mock UI implementation.

## Controlled Local Control-Plane Hardening Audit Checklist

Use this checklist after the `Controlled Local Control-Plane Hardening Queue 2026-06-03` has local GREEN validation. This checklist is evidence-only planning. It does not create a package, send a package, approve product-repo access, approve product mutation, approve remote access, approve package sending, approve runtime command binding, approve phone approvals, approve all-fleet execution, approve a demo trial, stage files, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

Reviewer ask:

- Audit only the controlled local control-plane hardening artifacts completed in the queue.
- Confirm runtime dry-run evidence records remain local, non-executing, fixture-backed evidence and cannot approve live execution, product-repo access, command binding, package sending, or future permission.
- Confirm selected-project read-only gates deny wildcard/all-project targets, write-capable actions, missing owner, stale fingerprint, phone-only approval, package sending, command binding, and product mutation.
- Confirm external audit manifest discipline remains allowlist-first, compact-summary-only, no-send, no-product-repo, and evidence-only until separate exact human package-scope approval exists.
- Confirm control-room reconciliation keeps stale, missing, mismatched, contradictory, and ambiguous evidence as `UNKNOWN`, and that `UNKNOWN` blocks execution rather than becoming approval.
- Confirm failure loop breaking pauses or repacketizes repeated deterministic failures rather than retrying blindly or broadening scope.
- Confirm approval boundaries deny phone-only, approve-all/broad targets, wildcard targets, missing owner, stale or expired approvals, reused approvals, write-capable approvals, forbidden operations, and evidence-as-authority attempts.
- Confirm reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose remain evidence only.

Evidence to include only after human package-scope review:

- `docs/fleet/STABLE_CONTEXT_CAPSULE.md`
- `docs/fleet/NEW_CHAT_HANDOFF_PACKET.md`
- `docs/fleet/POST_POLISH_GREEN_AUDIT_RECORD_2026_06_03.md`
- `docs/fleet/CONTROLLED_LOCAL_CONTROL_PLANE_HARDENING_CHARTER.md`
- `docs/fleet/RUNTIME_DRY_RUN_EVIDENCE_CONTRACT.md`
- `docs/fleet/RUNTIME_POLICY_DECISION_CONTRACT.md`
- `docs/fleet/SELECTED_PROJECT_READ_ONLY_GATE.md`
- `docs/fleet/EXTERNAL_AUDIT_PACKAGE_ALLOWLIST_RUNBOOK.md`
- `docs/fleet/CONTROL_ROOM_RECONCILIATION_CONTRACT.md`
- `docs/fleet/FAILURE_FINGERPRINT_CONTRACT.md`
- `docs/fleet/REMOTE_APPROVAL_BOUNDARY.md`
- `docs/fleet/ui/FLEET_CONSOLE_BUTTON_ACTION_POLICY.md`
- `docs/fleet/ui/FLEET_CONSOLE_REMOTE_ACCESS_AND_APPROVALS.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/HQ_REPAIR_BATCH_AUDIT_TEMPLATE.md`
- controlled-hardening schemas in `templates/`
- relevant fixture directories under `tests/fixtures/fleet/`
- `tests/run-fleet-tests.ps1`
- scrubbed compact validation summary from the current working tree

Material not to export:

- product repositories, product source snapshots, real project exports, unscoped project material, `.git`, `.env`, dependency folders, build outputs, raw locks, live worker state, unknown zips, full unreviewed package directories, raw run directories, raw logs, secrets, credentials, private keys, local machine identity, private user files, auth/payments/deploy/migration material, package-install material, permission material, staging material, commit material, push material, merge material, lock-deletion material, runtime-execution material, real approval material, package creation output, or package sending output without a separate human-approved manifest and package action.

Controlled-hardening GREEN:

- `tests/run-fleet-tests.ps1` passes.
- Dry-run evidence remains non-executing and non-authoritative.
- Selected-project gates remain read-only and deny-by-default.
- Manifest discipline prevents ambiguous package contents, package creation, package sending, product-repo access, or execution approval.
- `UNKNOWN` reconciliation blocks execution and cannot become approval.
- Failure loop breaking pauses or repacketizes repeated deterministic failures.
- Approval boundaries deny phone-only, broad, stale, reused, write-capable, forbidden-operation, and evidence-as-authority attempts.
- Package scope remains harness/docs/tests/schema/fixture/scrubbed compact evidence only.

Controlled-hardening YELLOW:

- Validation passes, but reviewer needs narrower evidence, clearer dry-run wording, clearer selected-project gate boundaries, or an explicit bounded follow-up task.
- Package contents are safe but require human package-scope review before any package creation or sending.
- A finding is an accepted limitation only if it does not require product-repo access, runtime command binding, remote access, package creation, package sending, phone approvals, automation, all-fleet execution, or sensitive-scope work.

Controlled-hardening RED:

- Validation fails, package scope expands to forbidden material, evidence is treated as authority, `UNKNOWN` is converted into approval, dry-run evidence is treated as runtime permission, or any step would require product-repo access, product mutation, product launch, all-fleet scope, deploy, install, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, staging, commit, push, merge, runtime command binding, remote access, package creation, package sending, phone approvals, or non-mock UI implementation.
