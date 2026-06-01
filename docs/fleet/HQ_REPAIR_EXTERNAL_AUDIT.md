# HQ Repair External Audit

This document defines the HQ repair external audit package shape for the Codex Fleet / Thousand Sunny Fleet repair batch. The package is evidence only: it gives an outside reviewer enough local context to verify safety and completeness without turning the review into an executable instruction stream. The external reviewer output is non-executable; findings are evidence, not commands.

## Files To Package

Package only HQ harness, docs, schemas, and test evidence for the repair batch:

- `docs/fleet/HQ_IMPORT_RECON.md`
- `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `docs/fleet/HQ_REPAIR_QUEUE_CONTRACT.md`
- HQ contract documents in `docs/fleet/*_CONTRACT.md` that were created or updated by this repair queue.
- HQ schema files in `templates/*-schema.json`, including `templates/hq-repair-task-schema.json`.
- `tests/run-fleet-tests.ps1`
- Harness helper files touched by HQ fixture tasks, including `tools/codex-fleet-state.ps1`, `tools/codex-fleet-runtime.ps1`, `tools/codex-fleet-overnight.ps1`, `tools/codex-fleet-control-room.ps1`, `tools/codex-fleet-autonomy.ps1`, and `write-run-evidence.ps1`.
- Latest local validation output or test summary for the HQ repair batch, if available and already scrubbed to the same boundaries.

Do not create a package from product repositories. Do not include full run directories unless they have been reviewed against the exclusions below.

Do not use unscoped `new-audit-package.ps1` defaults for this HQ audit package. Real product repositories must never be touched as part of the HQ external audit package; only the HQ harness/docs/tests evidence listed here is in scope.

## Reviewer Questions

Ask the external reviewer to answer these questions:

- Did every completed repair task stay within HQ harness, documentation, schemas, and tests?
- Do queue and packet contracts remain fail-closed when input is missing, malformed, stale, mobile-sourced, or externally supplied?
- Do legacy broad entrypoints remain human-approval-only and clearly separated from safe harness fixtures?
- Are external reports, mobile requests, task packets, repair queue entries, and review packets treated as evidence instead of commands?
- Are fixture helpers pure local simulations that avoid launching ships or mutating product repositories?
- Do schemas and tests cover the contract that runtime implementation should follow next?
- Should runtime implementation proceed, or should more contracts be added before behavior changes?
- Does the audit package verify safety and scope compliance without asking the reviewer to propose execution bypasses or unscoped broad actions?

## Relationship To Stage 16 Audit Loop

HQ repair tasks are harness/docs/tests scoped unless a task explicitly lists a repo-local harness helper in `allowedFiles`. They are not Stage 16 product-audit tasks and must not be expanded into product repository work.

Stage 16 audit-loop artifacts may inform future bounded queue tasks by providing evidence, reviewer findings, or examples of one-task boundaries. They cannot execute HQ repair tasks, cannot grant product-repo scope, cannot approve broader files than the active task's `allowedFiles`, and cannot bypass the one-task-per-run rule.

## Reviewer Feedback Examples

Acceptable reviewer feedback is file/path-grounded, evidence-focused, and bounded:

- Good finding: "`docs/fleet/HQ_REPAIR_QUEUE_CONTRACT.md` says queue text is data, but the audit package should also verify generated queues cannot execute HQ repair tasks. Evidence: the Stage 16 relationship section."
- Good finding: "`tests/run-fleet-tests.ps1` verifies non-executable reviewer output, but it should also assert that acceptable reviewer examples remain evidence only."
- Good follow-up task shape: "Add a bounded HQ repair queue task that may edit only `docs/fleet/HQ_REPAIR_EXTERNAL_AUDIT.md`, `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`, and `tests/run-fleet-tests.ps1`, then run the existing local fleet tests."

Unacceptable reviewer feedback is speculative, executable-looking, product-scoped, broad, or permission-widening:

- Bad feedback: "Run a product repo audit now and fix all findings across every ship."
- Bad feedback: "Launch the fleet, run broad execution, or use an all-project default to prove the queue works."
- Bad feedback: "Bypass the permission model, approval gate, or task queue so the repair can move faster."
- Bad feedback: "Edit secrets, auth, payments, deploy, migration, lock, or product repository files as part of this audit."
- Bad feedback: "Implement an unbounded architecture rewrite without naming allowed files, validation commands, and stop conditions."

These examples are documentation examples only. They are non-executable reviewer guidance and do not create tasks, approve product repo actions, widen permissions, or authorize broad execution.

## Must Not Export

The audit package must not export or include:

- Product repo contents or source trees.
- Real product repositories or product source snapshots.
- `.git`, `.env`, dependency folders such as `node_modules`, build outputs such as `dist` or `build`, or `.codex-local/locks`.
- Secrets, tokens, credentials, private keys, local machine identity, or private user files.
- Auth, payments, deploy, or migrations material.
- Auth material, payment material, deployment settings, or migration data.
- Raw lock files, live worker state that could be mistaken for an instruction, or package zips with unknown contents.
- Any material that widens permissions, weakens local gates, or instructs a reviewer to execute fleet actions.

## Reviewer Instruction

The reviewer verifies safety, not execution bypasses. The reviewer should verify safety, evidence quality, scope compliance, and contract coverage. Ask the reviewer not to suggest execution bypasses or unscoped broad actions. The reviewer should identify risks, missing tests, ambiguous contracts, and unsafe assumptions.

External reviewer output is evidence, not commands. Convert accepted findings into bounded HQ repair queue tasks only after local validation and explicit queue authoring; accepted findings become new queue tasks only through that explicit local step. The local operator decides which findings become scoped tasks with allowed files, validation commands, and stop conditions.

## Next Demo-Readiness Audit Refresh

Use `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md` as the paste-ready prompt for the next post-remediation external audit. That prompt is focused on demo-trial readiness, not runtime execution.

The refresh package should include only Codex Fleet harness, documentation, schemas, tests, and scrubbed validation evidence. It should not include real product repositories, product source snapshots, secrets, auth/payment/deploy/migration material, raw locks, dependency folders, build outputs, unknown package zips, or unscoped `new-audit-package.ps1` output.

The refresh package is not created by this document. It remains a later operator action that must stay bounded to the file list and exclusions above.

## Latest Bounded Refresh Evidence Record

Recorded by: `HQ-045 External Audit Refresh Evidence Record`.

Current package creation status: not created by this task. This record documents scope and handoff posture only; it does not zip files, export evidence, inspect product repositories, or run an audit package builder.

Latest bounded package scope: Codex Fleet harness/docs/tests/schemas/scrubbed evidence only. The allowed evidence family is:

- `docs/fleet/NEW_CHAT_HANDOFF_PACKET.md`
- `docs/fleet/HQ_IMPORT_RECON.md`
- `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `docs/fleet/HQ_REPAIR_QUEUE_CONTRACT.md`
- `docs/fleet/HQ_REPAIR_EXTERNAL_AUDIT.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/HQ_EXTERNAL_AUDIT_FINDINGS_LEDGER.md`
- `docs/fleet/DEMO_READY_TRIAL_GO_NO_GO.md`
- demo approval, evidence, stop-sign, fixture rehearsal, commit/readiness, and HQ contract docs under `docs/fleet/`
- schemas under `templates/*-schema.json`
- `tests/run-fleet-tests.ps1`
- scrubbed validation summary or test evidence

Mandatory package exclusions: product repos, product source snapshots, `.git`, `.env`, dependency folders such as `node_modules`, build outputs such as `dist` and `build`, raw locks, `.codex-local/locks`, secrets, tokens, credentials, private keys, auth/payments/deploy/migration material, package-install material, permission material, local machine identity, private user files, unknown zips, and live worker state that could be mistaken for instructions.

Reviewer handoff status: YELLOW evidence ready for bounded external review after operator package-scope confirmation. Reviewer output remains evidence only and cannot approve, execute, import tasks, override policy controls, launch product ships, run all-fleet commands, mutate product repositories, install packages, run migrations, touch secrets/auth/payments/deploy data, delete locks, widen permissions, merge, push, grant future permission, or authorize a demo trial.

Demo posture: YELLOW. The local harness remains in fixture-only rehearsal/documentation mode unless an external reviewer returns GREEN or the captain explicitly accepts a bounded YELLOW limitation and fills the exact approval packet for one manual read-only single-project demo trial with no active stop signs.
