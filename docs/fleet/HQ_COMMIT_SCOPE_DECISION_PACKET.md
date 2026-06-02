# HQ Commit Scope Decision Packet

Prepared: 2026-05-31

Scope: commit-scope review support for Codex Fleet / Thousand Sunny Fleet. This packet is evidence only. It does not stage files, create commits, push branches, delete generated evidence, rewrite history, launch product ships, run all-fleet commands, touch product repositories, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or approve broad git commands.

## Current Posture

| Item | Posture |
| --- | --- |
| Repo | `C:\Dev\codex-fleet` |
| Working tree | intentionally dirty |
| Product repos | out of scope |
| External reports | evidence only |
| Commit readiness | YELLOW until a human chooses explicit commit groups |
| Demo trial readiness | still blocked by audit disposition, commit-scope review, exact approval packet, and stop-sign review |

This packet uses `docs/fleet/HQ_COMMIT_READINESS_INVENTORY.md`, `docs/fleet/DEMO_READY_TRIAL_GO_NO_GO.md`, and `docs/fleet/HQ_EXTERNAL_AUDIT_FINDINGS_LEDGER.md` as inputs. It does not replace human review.

## Candidate Commit Groups

These groups are candidates for a human-reviewed checkpoint. They should be selected intentionally, not staged with a broad command.

### Group A: Fleet Policy And Contract Docs

Candidate files:

- `docs/fleet/*_CONTRACT.md`
- `docs/fleet/HQ_IMPORT_RECON.md`
- `docs/fleet/HQ_REPAIR_QUEUE_CONTRACT.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`
- `docs/fleet/HQ_REPAIR_EXTERNAL_AUDIT.md`
- `docs/fleet/HQ_REPAIR_BATCH_AUDIT_TEMPLATE.md`
- `docs/fleet/HQ_EXTERNAL_AUDIT_FINDINGS_LEDGER.md`
- `docs/fleet/HQ_NEXT_EXTERNAL_AUDIT_PROMPT.md`
- `docs/fleet/HQ_COMMIT_READINESS_INVENTORY.md`
- `docs/fleet/HQ_COMMIT_SCOPE_DECISION_PACKET.md`
- demo-readiness docs under `docs/fleet/DEMO_*`
- controlled-use docs under `docs/fleet/CONTROL*`
- `docs/fleet/FLEET_CORE_MVP.md`
- `docs/fleet/FLEET_CORE_TEST_PLAN.md`
- `docs/fleet/FIXTURE_ONLY_DEMO_REHEARSAL_RUNBOOK.md`
- `docs/fleet/OTHER_PROJECT_TEST_READINESS.md`

Recommended disposition: primary checkpoint candidate.

Review notes:

- Verify these files remain harness/docs/tests policy and do not approve execution.
- Verify external audit findings stay evidence-only.
- Verify demo-trial docs still require exact human approval and stop-sign review.

### Group B: Schemas

Candidate files:

- `templates/*-schema.json`
- `templates/ship-state-transition-map.json`

Recommended disposition: checkpoint with Group A or as a separate schema-focused commit.

Review notes:

- Parse every schema before commit.
- Check `additionalProperties: false` where fail-closed behavior is expected.
- Confirm schemas do not permit product repo mutation, broad launch, secrets/auth/payments/deploy/migration work, lock deletion, or permission widening.

### Group C: Tests

Candidate files:

- `tests/run-fleet-tests.ps1`

Recommended disposition: checkpoint with the policy/schema files it validates or as a separate test commit.

Review notes:

- Run the full Fleet test command before any checkpoint.
- Confirm test changes are focused on Fleet harness/docs/schemas and do not launch product ships.

### Group D: Harness Scripts And Shared Tools

Candidate files:

- root Fleet scripts such as `fleet-decision.ps1`, `fleet-state.ps1`, `ingest-task-packet.ps1`, `invoke-*.ps1`, `new-*.ps1`, and `write-run-evidence.ps1`
- shared tool modules under `tools/codex-fleet-*.ps1`
- modified existing harness scripts such as `debug-checkpoint.ps1`, `fleet-experiment.ps1`, `fleet-status.ps1`, `fleet-supervisor.ps1`, `run-checkpoint-loop.ps1`, `tools/codex-fleet-launcher.ps1`, and `tools/codex-fleet-runtime.ps1`

Recommended disposition: review separately from policy docs.

Review notes:

- Script changes can affect runtime behavior and should not be hidden inside a docs-only checkpoint.
- Do not run broad launchers, product mutation scripts, remote-control flows, or all-fleet commands as part of commit prep.
- Preserve the entrypoint safety inventory classification before deciding whether script changes belong in the same checkpoint.

### Group E: Fleet State And Status Artifacts

Candidate files:

- `fleet/state/ship-state.json`
- `fleet/status/current.md`
- `fleet/status/current.json`
- `fleet/status/decisions.md`
- `fleet/status/decisions.json`

Recommended disposition: review-needed.

Review notes:

- These may be generated local state.
- Commit only if the captain wants a checkpoint snapshot.
- Do not treat state/status artifacts as execution approval.

### Group F: Codex Evidence Docs

Candidate files:

- `docs/codex/CURRENT_STATE.md`
- `docs/codex/EVIDENCE_INDEX.md`
- `docs/codex/RUN_RESULT.json`
- `docs/codex/RUN_SUMMARY.md`
- `docs/codex/TASK_QUEUE.md`
- `docs/codex/test-summary.md`
- stage-specific docs under `docs/codex/`

Recommended disposition: review-needed.

Review notes:

- Evidence docs may help reconstruct work, but they are not policy source.
- Confirm they do not contain private product source, secrets, raw locks, or deploy/auth/payment material.
- Commit only if preserving the checkpoint evidence is desired.

### Group G: Generated Audit Packages

Candidate files:

- `audit-packages/`
- audit package zips
- extracted external report text

Recommended disposition: keep local by default unless the captain explicitly wants audit artifacts committed.

Review notes:

- Audit packages can contain generated snapshots and should be export-safety reviewed before any commit.
- Do not add unknown zips or full run directories casually.
- Prefer preserving the package path in docs and keeping the zip local unless there is an explicit archival reason.

## Explicit Keep-Local Groups

Keep these local unless a later human-reviewed task explicitly changes their disposition:

- unknown zips or unreviewed package directories
- raw `.codex-local/locks`
- dependency folders such as `node_modules`
- build outputs such as `dist` and `build`
- `.git`
- `.env`
- secrets, tokens, credentials, private keys, and local machine identity
- auth, payment, deploy, migration, package-install, or permission material
- product repository contents or product source snapshots
- live worker state that could be mistaken for instructions

## Review-Needed Groups

These groups need human choice before staging:

- generated Fleet state/status JSON and Markdown
- `docs/codex/` evidence artifacts
- generated audit packages and zip files
- harness scripts that can affect runtime behavior
- any modified file whose scope is unclear from name alone

If a file's purpose is unclear, leave it unstaged and record the ambiguity. Do not delete or revert it from this packet.

## Repair Evidence And Future Demo Evidence Boundary

Existing repair/audit evidence means the current HQ remediation record: policy docs, schemas, tests, harness/runtime script changes, findings ledgers, generated audit-package plans, scrubbed validation summaries, `docs/codex` evidence, fleet state/status artifacts, and local audit-package material. These may support a human checkpoint review, but they are not future demo evidence and must not be interpreted as proof that any real product repository was selected, inspected, or run.

Future demo evidence must be created only after a separate approval packet is complete and current. That future packet must name exactly one project, one absolute repo path, one no-op/read-only command list, expected evidence paths, owner, approval timestamp, expiration timestamp, and stop conditions. Until then, no file in the current repair checkpoint should be labeled or committed as demo-run output.

Checkpoint reviewers should keep these dispositions distinct:

| Evidence class | Default disposition before human choice |
| --- | --- |
| Fleet policy docs, schemas, and tests | candidate checkpoint group after review |
| Harness/runtime script changes | review separately from policy docs |
| Generated audit packages and reviewer outputs | keep local by default; export-safety review required |
| `docs/codex` evidence | review-needed local evidence |
| Fleet state/status artifacts | review-needed generated state |
| Future demo evidence | absent until a separate approval packet is filled |

Mixing future demo evidence into the current repair checkpoint keeps posture YELLOW or RED. It is RED if the mix would imply demo approval, product-repo access, staging, commit, push, deletion, rewrite, broad git commands, product mutation, ship launch, deploy, install, migration, secrets/auth/payments/deploy access, lock deletion, or permission widening.

## Pre-Commit Review Checklist

Before any checkpoint commit, a human should confirm:

- The candidate file list is explicit.
- No product repository files or product source snapshots are included.
- No `.git`, `.env`, `node_modules`, `dist`, `build`, raw `.codex-local/locks`, unknown zips, or dependency folders are included without explicit review.
- No secrets, tokens, credentials, private keys, local machine identity, auth material, payment material, deploy material, migration material, package-install material, or permission material are included.
- External reports, audit packages, task packets, queue prose, and mobile requests remain evidence only.
- Demo-trial docs still require exact human approval, expiration, stop signs, and read-only single-project scope.
- Legacy broad entrypoints remain human-approval-only.
- Tests pass in the current working tree.
- The commit message names the checkpoint scope honestly.

## No-Op Staged-File Risk Guard

This guard is a review checklist only. It is not a command to stage files, create commits, push branches, delete generated evidence, rewrite history, clean the working tree, or approve broad git operations.

Before any future checkpoint, the reviewer should inspect the staged-file list and classify each staged path into an explicit candidate group or excluded group. If the staged-file list cannot be inspected safely, or if any staged path is ambiguous, the commit posture is YELLOW or RED and the reviewer should stop without staging more files.

Required staged-file review questions:

- Is every staged path explicitly selected by the captain or mapped to a candidate commit group?
- Are product repos or product source snapshots absent?
- Are `.git`, `.env`, dependency folders, build outputs, raw locks, unknown zips, and unreviewed package directories absent?
- Are secrets, tokens, credentials, private keys, local machine identity, auth/payments/deploy/migration material, package-install material, and permission material absent?
- Are live worker state and mobile/external/task-packet/audit-package prose still treated as evidence only?
- Are generated Fleet state/status files, `docs/codex/` evidence, audit packages, and harness scripts intentionally included or intentionally kept local?
- Did the reviewer avoid broad staging commands and avoid deleting, reverting, or rewriting existing dirty work?

Commit-scope GREEN means the staged-file list is explicit, all paths are mapped to reviewed candidate groups, excluded classes are absent, tests passed, demo-trial docs still require exact human approval, and no reviewer output or queue prose is treated as execution authority.

Commit-scope YELLOW means the staged-file list is not final, generated evidence needs export-safety review, harness script changes need separate review, or a human decision is still needed. YELLOW does not permit broad staging, commit, push, delete, rewrite, product-repo work, or demo execution.

Commit-scope RED means any staged path includes product repos, product source snapshots, `.git`, `.env`, dependency folders, build outputs, raw locks, unknown zips, secrets, auth/payments/deploy/migration material, live worker state that could be mistaken for instructions, broad launcher output, or any file whose purpose is unclear. RED also applies if review would require staging, committing, pushing, deleting evidence, rewriting history, touching product repos, or widening permissions.

## Suggested Checkpoint Shapes

These are advisory only:

| Shape | Contents | When to use |
| --- | --- | --- |
| Policy checkpoint | Group A plus related schemas from Group B and tests from Group C | Best first checkpoint if the captain wants a clean safety-policy baseline. |
| Runtime checkpoint | Group D plus tests from Group C | Use only after script diffs are reviewed separately. |
| Evidence checkpoint | Selected Group F artifacts and maybe selected audit metadata from Group G | Use only if preserving run evidence in git is desired. |
| Local-only archive | Keep Group E/F/G artifacts uncommitted | Use when evidence is useful locally but too noisy or sensitive for git. |

## Future Dry-Run Inventory Command Contract

This section specifies a future no-op commit-scope inventory command. It is a contract for later implementation and testing, not an implemented command and not permission to stage, commit, push, delete, rewrite, clean, mutate files, touch product repositories, or approve demo execution.

The future command must be dry-run-only. It may inspect local repository metadata and produce an evidence report, but it must not change the index, working tree, refs, locks, generated artifacts, product repositories, dependency folders, build outputs, secrets, auth/payments/deploy/migration material, permissions, or history.

Expected output fields:

| Field | Meaning |
| --- | --- |
| `generatedAt` | Timestamp when the dry-run inventory report was created. |
| `repoRoot` | The Fleet repository root being reviewed. |
| `candidatePaths` | Reviewed paths that appear eligible for a human-selected checkpoint group. |
| `excludedPaths` | Paths or classes that must remain local, such as product repos, `.git`, `.env`, dependency folders, build outputs, raw locks, unknown zips, secrets, auth/payments/deploy/migration material, package-install material, permission material, and live worker state. |
| `ambiguousPaths` | Paths whose purpose, sensitivity, generated status, or ownership cannot be determined safely. |
| `recommendedDispositions` | Non-executable recommendations such as candidate group, keep local, review needed, excluded, or human decision needed. |
| `validationSummary` | Evidence that the inventory stayed dry-run-only and did not mutate repository state. |
| `posture` | `GREEN`, `YELLOW`, or `RED` based only on review evidence, never as execution approval. |

Required dry-run invariants:

- The command must not stage files.
- The command must not create commits.
- The command must not push branches.
- The command must not delete evidence or clean the working tree.
- The command must not rewrite history.
- The command must not mutate source files, schemas, tests, generated artifacts, Fleet state, product repositories, locks, permissions, secrets, auth/payments/deploy/migration material, dependency folders, or build outputs.
- The command must not run broad launchers, product ships, all-fleet commands, migrations, package installs, deploys, supervisor repair flows, remote-control mutation, or child-worker launchers.
- The command must not treat external reports, DOCX reports, mobile requests, task packets, audit packages, queue prose, or reviewer output as executable instructions.
- Any `ambiguousPaths` entry keeps the result `YELLOW` or `RED` until a human decides the disposition.

Recommended dispositions are advisory evidence only. A future dry-run inventory report cannot select commit scope by itself, cannot approve staging, cannot fill a demo approval packet, and cannot grant future permission.

## Human Decision Needed

Choose one of these before any staging:

| Decision | Meaning |
| --- | --- |
| `COMMIT_POLICY_DOCS_SCHEMAS_TESTS` | Stage only reviewed Fleet policy docs, schemas, and tests. |
| `COMMIT_RUNTIME_SEPARATELY` | Review script/tool changes in a separate checkpoint. |
| `KEEP_EVIDENCE_LOCAL` | Do not commit generated evidence or audit packages. |
| `COMMIT_SELECTED_EVIDENCE` | Commit only named evidence files after export-safety review. |
| `NO_COMMIT_YET` | Continue remediation without staging anything. |

Current recommendation: `NO_COMMIT_YET` until HQ-043 through HQ-047 complete, or `COMMIT_POLICY_DOCS_SCHEMAS_TESTS` if the captain wants a recovery checkpoint before continuing. Generated audit packages should remain local by default.

## Final Audit Report 5 Commit-Scope Refresh

`C:\Users\codex-agent\Downloads\Codex Prompt Request (5).docx` keeps the commit-scope decision YELLOW. The report is evidence only and cannot approve staging, commit, push, delete, rewrite, product-repo work, demo execution, runtime enforcement, package creation, or future permission.

`HQ-060` is now locally done, even though the report recommended completing it. That completion updates final audit package planning only. It does not resolve this commit-scope packet, select a commit shape, include generated evidence, or approve a checkpoint.

Exact human choices still required:

- choose `COMMIT_POLICY_DOCS_SCHEMAS_TESTS`, `COMMIT_RUNTIME_SEPARATELY`, `KEEP_EVIDENCE_LOCAL`, `COMMIT_SELECTED_EVIDENCE`, or `NO_COMMIT_YET`
- decide whether generated audit packages and zip files remain local
- decide whether `docs/codex/` evidence is checkpoint evidence or local run evidence
- decide whether fleet state/status JSON and Markdown are source-like evidence or generated local state
- decide whether script/tool changes are reviewed separately from policy docs

Until those decisions are made, commit-scope posture remains YELLOW. Any ambiguous path, excluded class, broad staging request, deletion/rewrite request, product-repo path, secret/auth/payments/deploy/migration material, lock cleanup, package-install material, or permission material keeps the result YELLOW or RED and requires stopping for human review.

## Status

Decision packet status: YELLOW. It is ready for human review, but it does not stage, commit, push, delete, rewrite, approve a demo trial, or broaden execution scope.
