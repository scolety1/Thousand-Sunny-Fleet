# Read-Only Demo Go/No-Go Scorecard

Prepared: 2026-06-04

Scope: Codex Fleet / Thousand Sunny Fleet local harness, docs, schemas, fixtures, tests, and external audit preparation only.

Evidence only; not executable authority or approval.

This scorecard separates local fixture readiness from real demo readiness. It does not approve product-repo access, demo execution, product mutation, package creation, package sending, remote access, runtime command binding, phone approvals, all-fleet execution, running an overnight runner, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, demo trials, or future authority.

## Purpose

The read-only demo planning lane can earn GREEN local fixture readiness when docs, schemas, fixtures, and tests prove the gate shape locally. That GREEN local fixture state is not a real demo approval.

Real demo readiness remains YELLOW until a separate exact human approval packet exists and all required real-demo prerequisites are current, bounded, reviewed, and inactive for stop signs.

## Scorecard States

| state | meaning | allowed next action |
| --- | --- | --- |
| GREEN local fixture readiness | Local docs/tests/schema/fixture evidence passed validation and preserves the read-only gate boundary. | External audit package preparation after an explicit package request. |
| YELLOW real demo readiness | The system is not approved for real demo execution because exact human approval and real-demo prerequisites are not satisfied. | Prepare evidence, audit prompts, and checklists only. |
| RED stop | A required prerequisite is missing, broad, stale, conflicting, write-capable, package-sending, remote, phone-only, all-fleet, or evidence-as-authority. | Stop and repacketize. |

## Required Before Any Future Real Demo Consideration

A future real demo cannot move beyond YELLOW unless every item below is present and current:

- exact project identity
- exact accountable human owner
- current human-filled approval packet
- exact no-op/read-only command list
- current repo fingerprint evidence reference
- expiration timestamp
- inactive stop-sign review
- compact evidence-capture plan
- exact validation command references
- external audit review path
- non-authority notice

The approval packet must be exact-action-bound and single-target. Blank, `all`, wildcard, multi-target, stale, expired, reused, implied, phone-only, package-sending, write-capable, remote-access, runtime-command-binding, all-fleet, overnight-runner, product-mutation, or evidence-as-authority cases fail closed.

## Local Fixture GREEN

Local fixture readiness may be GREEN when:

- `docs/fleet/READ_ONLY_DEMO_READINESS_PLANNING_CHARTER.md` preserves the planning-only boundary.
- `docs/fleet/READ_ONLY_DEMO_GATE_REHEARSAL_PLAN.md` preserves local fixture-only gate rehearsal.
- `tests/fixtures/fleet/read-only-gates/*.json` cover valid, denied, deferred, and UNKNOWN selected-project gate outcomes.
- `tests/run-fleet-tests.ps1` passes.
- The latest external audit record remains GREEN for local harness/docs/tests/schema/fixture evidence.

Local fixture GREEN still cannot select a real project, inspect product repos, execute a demo, create or send packages, bind runtime commands, approve phone actions, run all-fleet commands, run an overnight runner, or grant future authority.

## Real Demo YELLOW

Real demo readiness remains YELLOW by default because the current approved posture is evidence-only planning. A real demo requires a later separate exact human approval packet and fresh review of the exact target, exact no-op/read-only command list, repo fingerprint, stop signs, validation evidence, and evidence-capture plan.

No generated scorecard, audit report, queue status, validation pass, fixture, prompt, manifest, UI label, notification, button, mobile request, task packet, or DOCX report can turn real demo readiness GREEN.

## RED Stop Conditions

Mark the scorecard RED and stop if the next step requires:

- selecting a real project without exact approval
- product-repo access or product mutation
- demo execution
- package creation or package sending
- runtime command binding
- remote access
- phone approvals
- all-fleet execution
- running an overnight runner
- staging, commit, push, merge, deploy, installs, or migrations
- secrets/auth/payments/deploy work
- lock deletion or permission widening
- non-mock UI implementation
- treating reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, or queue prose as executable authority

## Non-Authority Boundary

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.
