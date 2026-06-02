# HQ Commit Readiness Inventory

Prepared: 2026-05-31

Purpose: commit-prep inventory for Codex Fleet / Thousand Sunny Fleet HQ repair work. This document is evidence only. It does not stage, commit, push, delete, rewrite history, launch ships, touch product repositories, or approve broad execution.

## Current Posture

- Repo: `C:\Dev\codex-fleet`
- Working tree: intentionally dirty
- Scope: Codex Fleet harness/docs/tests/evidence only
- Product repos: not part of this inventory
- Audit packages: generated evidence, reviewed separately from source changes
- Commit scope decision packet: `docs/fleet/HQ_COMMIT_SCOPE_DECISION_PACKET.md`

## Commit Candidate Groups

Review these groups before creating any checkpoint commit. Do not use broad staging from this document.

### Source Docs

Candidate docs include:

- `docs/fleet/*_CONTRACT.md`
- `docs/fleet/HQ_IMPORT_RECON.md`
- `docs/fleet/HQ_REPAIR_QUEUE_CONTRACT.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `docs/fleet/HQ_REPAIR_EXTERNAL_AUDIT.md`
- `docs/fleet/OTHER_PROJECT_TEST_READINESS.md`
- `docs/fleet/CONTROL_PLANE_SPINE_DECISION.md`
- `docs/fleet/FLEET_CORE_MVP.md`
- `docs/fleet/FLEET_CORE_TEST_PLAN.md`
- `docs/fleet/CONTROLLED_USE_REHEARSAL_EXPANSION.md`
- `docs/fleet/HQ_REPAIR_BATCH_AUDIT_TEMPLATE.md`
- `docs/fleet/HQ_COMMIT_READINESS_INVENTORY.md`
- `docs/golden-gameplan/`
- `docs/templates/`

Review note: source docs are the primary checkpoint candidates because they define policy, contracts, task boundaries, and evidence expectations.

### Schemas

Candidate schemas include:

- `templates/*-schema.json`
- `templates/ship-state-transition-map.json`

Review note: schemas should be parsed before commit and paired with tests that assert fail-closed vocabulary where applicable.

### Tests

Candidate tests include:

- `tests/run-fleet-tests.ps1`

Review note: this is the primary validation runner. Confirm the latest full run passed before any checkpoint.

### Harness Scripts And Tools

Candidate harness scripts/tools include:

- root-level fleet scripts such as `fleet-decision.ps1`, `fleet-state.ps1`, `ingest-task-packet.ps1`, `invoke-*.ps1`, `new-*.ps1`, and `write-run-evidence.ps1`
- shared tools under `tools/codex-fleet-*.ps1`
- modified existing harness scripts such as `fleet-status.ps1`, `fleet-supervisor.ps1`, `run-checkpoint-loop.ps1`, `debug-checkpoint.ps1`, `fleet-experiment.ps1`, `tools/codex-fleet-launcher.ps1`, and `tools/codex-fleet-runtime.ps1`

Review note: scripts should be inspected separately from docs because they can affect runtime behavior. Do not run launchers or all-fleet commands as part of commit prep.

### Fleet State And Status Artifacts

Candidate local state/status files include:

- `fleet/state/ship-state.json`
- `fleet/status/current.md`
- `fleet/status/current.json`
- `fleet/status/decisions.md`
- `fleet/status/decisions.json`

Review note: these may be generated local state. Decide whether they are intended source artifacts or should remain uncommitted evidence.

### Codex Evidence Docs

Candidate evidence docs include:

- `docs/codex/CURRENT_STATE.md`
- `docs/codex/EVIDENCE_INDEX.md`
- `docs/codex/RUN_RESULT.json`
- `docs/codex/RUN_SUMMARY.md`
- `docs/codex/TASK_QUEUE.md`
- `docs/codex/test-summary.md`
- Stage-specific docs under `docs/codex/`

Review note: these are evidence artifacts, not policy source. Commit only if preserving the checkpoint evidence is desired.

### Generated Audit Packages

Generated audit packages are separate from source changes:

- `audit-packages/`
- `.zip` files inside audit package folders
- extracted external report text such as `audit-packages/external-report-extract.txt`

Review note: audit packages may be useful as review evidence but can contain generated snapshots. Review export safety and size before committing. Do not delete audit packages from this document.

### Intentionally Untracked Or Local Artifacts

Some untracked files may be intentionally local generated artifacts. Review before adding:

- local fixture outputs
- generated run evidence
- generated status snapshots
- generated audit package contents

Review note: untracked does not mean disposable. Do not delete or clean untracked files unless a separate approved cleanup task says exactly what to remove.

## Recommended Review Order

1. Review queue and contracts: `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`, `docs/fleet/HQ_REPAIR_QUEUE_CONTRACT.md`, and HQ contract docs.
2. Review schemas: `templates/*-schema.json`.
3. Review focused tests: `tests/run-fleet-tests.ps1`.
4. Review harness scripts and shared tools.
5. Review `docs/codex/` evidence docs.
6. Review fleet state/status artifacts.
7. Review generated audit packages last.

## No-Op Rollback Note

Commit prep should be a no-op review step. It should not:

- stage files
- create commits
- push branches
- delete generated evidence
- rewrite history
- run broad launchers
- run all-fleet commands
- touch product repos
- change secrets, auth, payments, deployment settings, migrations, locks, or permissions

If review finds an unsafe or unrelated file, record it as an unresolved risk and ask for a narrower follow-up task. Do not revert existing dirty work from this inventory.

## Staged-File Risk Guard

Use `docs/fleet/HQ_COMMIT_SCOPE_DECISION_PACKET.md` as the source of truth for staged-file risk review. The guard is no-op evidence only. It does not stage files, commit, push, delete, rewrite history, clean the tree, or approve broad git commands.

Before any future checkpoint commit, a human should inspect the staged-file list and confirm that every staged path maps to a reviewed candidate group. Excluded paths and classes must remain absent: product repos, product source snapshots, `.git`, `.env`, dependency folders, build outputs, raw locks, unknown zips, unreviewed package directories, secrets, tokens, credentials, private keys, local machine identity, auth/payments/deploy/migration material, package-install material, permission material, and live worker state that could be mistaken for instructions.

Staged-file risk outcomes:

- GREEN: explicit staged-file list, all paths reviewed, excluded classes absent, tests passed, and demo-trial docs still require exact human approval.
- YELLOW: generated evidence, audit packages, state/status artifacts, `docs/codex/` evidence, or harness scripts need human review before staging or commit.
- RED: any excluded class is staged, any path is ambiguous, or review would require broad staging, commit, push, delete, rewrite, product-repo work, lock deletion, permission widening, package install, migration, deploy, or secrets/auth/payments touch.

## Current Repair Evidence Vs Future Demo Evidence

Current repair evidence is the evidence already produced by the HQ repair and runtime-pilot hardening work. It includes Fleet policy docs, contract docs, schemas, focused tests, harness/runtime script changes, findings ledgers, generated audit-package plans, scrubbed validation summaries, `docs/codex` evidence, and fleet state/status artifacts. These items may be reviewed for a later checkpoint, but they are not a demo trial record and must not be treated as proof that a real project was selected, inspected, or safely exercised.

Generated audit packages, audit package manifests, package prompts, extracted external report text, and reviewer outputs are evidence-only review material. They should stay local by default unless a human explicitly selects them for a checkpoint scope after export-safety review. They do not approve staging, committing, pushing, product-repo access, demo execution, or future permission.

Future demo evidence is separate. It may be created only after a separate approval packet is filled with exact current values for one project, one absolute repo path, one no-op/read-only command list, expected local evidence paths, owner, approval timestamp, expiration timestamp, and stop conditions. Future demo evidence must not be mixed into the current repair checkpoint by accident.

Commit-scope posture remains YELLOW until a human chooses explicit dispositions for generated audit packages, `docs/codex` evidence, fleet state/status artifacts, runtime script changes, and any future demo evidence. If any path is ambiguous, generated, sensitive, product-repo-related, or likely to be mistaken for executable instructions, keep it out of the checkpoint or mark it `human_decision_needed`.

## Suggested Checkpoint Strategy

This section is advisory only, not a command.

- Prefer a human-reviewed checkpoint commit after tests are green.
- Consider separate commits for docs/contracts/schemas, tests/scripts, and generated evidence if the captain wants a cleaner audit trail.
- Avoid broad staging. Select files intentionally after review.
- Keep audit package zips separate unless the captain wants them preserved in git.

## Final Audit Report 5 Refresh

`C:\Users\codex-agent\Downloads\Codex Prompt Request (5).docx` keeps commit readiness YELLOW. The report is evidence only; it does not stage files, create commits, push branches, delete generated evidence, rewrite history, approve a demo trial, touch product repositories, or grant future permission.

`HQ-060` was completed locally after the report recommended completing it. That timing update means the final audit package plan is refreshed, but commit readiness remains unresolved until a human chooses an explicit commit scope.

Human decisions still needed before any checkpoint:

- whether generated audit packages stay local or become explicitly selected evidence
- whether source docs, schemas, and tests should be grouped into a policy checkpoint
- whether harness scripts and shared tools need a separate runtime review
- whether fleet state/status artifacts are checkpoint evidence or generated local state
- whether `docs/codex/` evidence should be committed with the HQ repair docs or kept local

No-op refresh rule: this inventory can support review only. It must not stage, commit, push, delete, rewrite, clean the working tree, touch product repos, approve a demo, run launchers, run all-fleet commands, delete locks, widen permissions, install packages, run migrations, or touch secrets/auth/payments/deploy material.

## Dry-Run Inventory Command Spec

This inventory defines a future dry-run-only commit-scope inventory command contract. The command is not implemented here. This section does not stage files, create commits, push branches, delete evidence, rewrite history, mutate files, touch product repositories, or approve broad git operations.

The future command may only list and classify current working-tree evidence for human review. It must produce an evidence-only report with these fields:

- `generatedAt`
- `repoRoot`
- `candidatePaths`
- `excludedPaths`
- `ambiguousPaths`
- `recommendedDispositions`
- `validationSummary`
- `posture`

The report may recommend dispositions such as `candidate_group`, `keep_local`, `review_needed`, `excluded`, and `human_decision_needed`. Recommendations are non-executable and do not approve staging or committing.

The command must remain no-op and non-mutating:

- must not stage files
- must not create commits
- must not push branches
- must not delete or clean generated evidence
- must not rewrite history
- must not mutate source files, schemas, tests, state, artifacts, product repositories, locks, permissions, secrets, auth/payments/deploy/migration material, dependency folders, or build outputs
- must not run product ships, all-fleet commands, package installs, migrations, deploys, supervisor repair flows, remote-control mutation, or child-worker launchers
- must not execute external reports, DOCX reports, mobile requests, task packets, audit packages, queue prose, or reviewer output

The future dry-run report should classify paths into candidate, excluded, and ambiguous groups. Any ambiguous path must keep the commit posture `YELLOW` or `RED` until a human chooses an explicit disposition.

## Open Commit Questions

- Should generated audit packages be committed or kept as local artifacts?
- Should fleet status/state JSON be committed as checkpoint evidence or regenerated later?
- Should `docs/codex/` evidence be committed with the HQ repair docs?
- Should script/runtime changes be reviewed in a separate commit from policy docs?
- Should the next checkpoint be policy-docs/schemas/tests only, runtime scripts separately, selected evidence only, or no commit yet?

## Status

Inventory status: YELLOW until a human reviews the dirty working tree and chooses an explicit commit scope. Use `docs/fleet/HQ_COMMIT_SCOPE_DECISION_PACKET.md` as the no-op decision packet; it does not stage, commit, push, delete evidence, rewrite history, or approve broad git commands.
