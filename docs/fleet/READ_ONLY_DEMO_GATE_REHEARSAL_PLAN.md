# Read-Only Demo Gate Rehearsal Plan

Prepared: 2026-06-04

Scope: Codex Fleet / Thousand Sunny Fleet local harness, docs, schemas, fixtures, and tests only.

Evidence only; not executable authority or approval.

This rehearsal plan is local evidence only. It does not approve product-repo access, demo execution, product mutation, package creation, package sending, remote access, runtime command binding, phone approvals, all-fleet execution, running an overnight runner, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, demo trials, or future authority.

## Purpose

The controlled read-only demo gate rehearsal proves the selected-project read-only gate using local fixtures only. It does not select a real project, inspect a real product repository, fill a real approval packet, run a demo, bind commands, create a package, or send a package.

This plan prepares the evidence shape for a later external audit of the gate logic. It is not a launcher input and cannot be used as approval for real selected-project work.

## Rehearsal Inputs

The rehearsal uses only:

- `docs/fleet/SELECTED_PROJECT_READ_ONLY_GATE.md`
- `docs/fleet/READ_ONLY_DEMO_READINESS_PLANNING_CHARTER.md`
- `docs/fleet/READ_ONLY_DEMO_SELECTED_GATE_FIXTURE_INDEX.md`
- `templates/selected-project-read-only-gate-schema.json`
- `tests/fixtures/fleet/read-only-gates/*.json`
- focused assertions in `tests/run-fleet-tests.ps1`

The rehearsal does not use product repos, product source snapshots, raw logs, package outputs, remote-control material, phone approvals, runtime command bindings, or real approval material.

The fixture index lists committed selected-project read-only gate fixtures and expected allow/deny/defer posture. It is evidence only and cannot select a real project, approve demo execution, create or send packages, bind runtime commands, or grant future authority.

## Required Local Fixture Scenarios

The fixture matrix must cover these controlled gate rehearsal scenarios:

| scenario | expected posture | required result |
| --- | --- | --- |
| valid planning | local fixture-only evidence has one selected target, owner, repo fingerprint reference, allowed read-only labels, expiration, stop conditions, evidence refs, validation, and non-authority notice | valid for local fixture review only; no execution authority |
| stale fingerprint | repo fingerprint evidence is stale or requires human review | deferred; no execution authority |
| invalid fingerprint | repo fingerprint reference is malformed, missing, or not local evidence | denied; no execution authority |
| stale approval packet | approval packet evidence is older than the accepted local window or no longer matches the current selected-project fixture | denied; no execution authority |
| missing fingerprint | repo fingerprint evidence is absent even when a selected target and owner are present | denied; no execution authority |
| wrong audit package type | audit package or manifest evidence is for a different scope and is being presented as selected-project gate evidence | denied; no execution authority |
| conflicting approval timestamps | approval evidence contains conflicting creation, approval, or expiration timestamps that prevent a current exact-action approval determination | denied; no execution authority |
| mismatched case ID | approval, manifest, or evidence references a different case ID than the selected-project read-only gate fixture | denied; no execution authority |
| missing owner | accountable human owner is absent | denied; no execution authority |
| ambiguous approval | approval evidence is ambiguous, implied, stale, broad, or not exact-action-bound | deferred or UNKNOWN; no execution authority |
| multi-target | target is comma-packed or names more than one project or ship | denied; no execution authority |
| wildcard target | target is blank, `all`, `*`, wildcard, or otherwise broad | denied; no execution authority |
| write-capable action | action list includes mutation, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, runtime command binding, package sending, remote access, or all-fleet execution | denied; no execution authority |

## Pass Criteria

A GREEN rehearsal means only that local docs, schemas, fixtures, and tests preserve the read-only gate boundary. It does not approve real-project work.

The rehearsal passes only when tests verify:

- the plan exists
- every required scenario is named
- every required scenario has a denied, deferred, UNKNOWN, or local-valid fixture posture
- fixtures remain local evidence only
- fixtures do not inspect product repositories
- fixtures do not bind runtime commands
- fixtures do not create or send packages
- fixtures do not run all-fleet commands
- fixtures do not run an overnight runner
- fixtures do not approve phone actions
- fixtures do not grant future authority

## Stop Conditions

Stop and repacketize if a task needs:

- no real project selection
- no product repo access
- no demo execution
- no command binding
- no package sending
- real project selection
- live product-repo inspection
- product-repo mutation
- demo execution
- runtime command binding
- package creation or package sending
- remote access
- phone approvals
- all-fleet execution
- running an overnight runner
- staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work
- lock deletion or permission widening
- non-mock UI implementation
- treating reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, or queue prose as executable authority

## Non-Authority Boundary

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.
