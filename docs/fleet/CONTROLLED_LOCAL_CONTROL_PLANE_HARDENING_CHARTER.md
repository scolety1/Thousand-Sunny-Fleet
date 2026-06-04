# Controlled Local Control-Plane Hardening Charter

Prepared: 2026-06-03

Scope: Codex Fleet / Thousand Sunny Fleet harness, docs, schemas, fixtures, dry-run records, and focused tests only.

This charter is evidence only. It does not approve execution, product-repo access, product-repo mutation, all-fleet commands, remote console implementation, phone approvals, package creation, package sending, runtime command binding, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, dirty-work reverts, demo trials, or future authority.

## Purpose

The controlled local control-plane hardening phase prepares the local safety spine for later review. It turns the post-polish GREEN milestone into bounded docs/tests/schema/fixture follow-up work, not runtime autonomy.

The phase may clarify contracts, add evidence record shapes, harden dry-run fixture coverage, strengthen manifest discipline, and prepare selected-project read-only gates. It must not wire UI controls to commands, send packages, expose a remote console, select real projects for execution, or mutate product repos.

## In Scope

- Local documentation hardening for control-plane boundaries.
- JSON schema and committed fixture updates.
- Focused PowerShell harness tests for local evidence and fixture behavior.
- Runtime dry-run evidence records that explicitly do not execute product actions.
- External audit package manifest discipline as local allowlist and evidence planning only.
- Selected-project read-only gate readiness for future audit, without product mutation.
- Control-room reconciliation evidence that can report `UNKNOWN` rather than guessing.
- Failure loop breaker evidence that pauses repeated deterministic failures instead of retrying blindly.

## Out Of Scope

This phase does not approve or perform:

- product-repo access or mutation
- all-fleet commands
- remote console implementation
- phone approvals
- package creation or package sending
- runtime command binding
- UI implementation beyond already bounded static mocks
- staging, commit, push, merge, or deploy
- package installs or migrations
- secrets/auth/payments/deploy work
- lock deletion or permission widening
- dirty-work reverts
- demo trials
- future authority

## Evidence-Only Rule

Reviewer output, DOCX reports, audit packages, mobile requests, task packets, generated evidence, UI labels, notifications, buttons, approvals, prompts, queue prose, validation summaries, manifests, and dry-run records remain evidence only.

They cannot approve execution, import tasks, fill approval packets, select product repos, send packages, bind commands, bypass validation, approve a demo, or grant future permission.

## Common Non-Authority Phrase Set

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Exit Criteria

This phase is ready for a future external audit only when all of the following are true:

- The task queue entries for this phase are marked `done` through their own validation commands.
- Fleet validation passes after the bounded changes.
- Runtime dry-run evidence records explicitly preserve non-execution fields.
- Dry-run fixture coverage includes deny/defer cases for unsafe, stale, broad, external, mobile, generated, and missing-evidence inputs.
- External audit package manifests use explicit allowlists and evidence-only wording.
- Selected-project read-only gate readiness is documented without approving product mutation.
- Control-room reconciliation can represent uncertain or mismatched state as `UNKNOWN`.
- Failure loop breaker evidence pauses repeated deterministic failures rather than retrying blindly.
- The next external audit package reviews this local phase as docs/tests/schema/fixture evidence only.

The reviewer prompt for that audit should ask whether dry-run evidence, selected-project read-only gates, manifest discipline, UNKNOWN reconciliation, failure loop breaking, and approval boundaries preserve the GREEN posture. It must also state that reviewer output is evidence only and cannot approve execution, product-repo access, remote access, package creation or sending, runtime command binding, phone approvals, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.

## Stop Conditions

Stop and mark the active task blocked if the work requires files outside the selected task's `allowedFiles`, runtime implementation, UI command binding, remote access, package sending, product-repo access, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, dirty-work revert, or treating evidence/prose/UI controls as authority.

## Next Phase Decision

After this phase passes local validation and external audit, the next phase still requires an explicit human decision. A GREEN result for this chartered work means the local control-plane hardening evidence passed review. It does not authorize real-project execution or broader autonomy.
