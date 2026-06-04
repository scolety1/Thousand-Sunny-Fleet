# Read-Only Demo Readiness Planning Charter

Prepared: 2026-06-03

Scope: Codex Fleet / Thousand Sunny Fleet local harness, docs, schemas, fixtures, approval templates, stop signs, no-op/read-only vocabulary, evidence capture, and external audit preparation only.

This charter is evidence only. It does not approve product-repo access, live demo execution, product mutation, package creation, package sending, remote access, runtime command binding, phone approvals, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, demo trials, or future authority.

Canonical notice: Evidence only; not executable authority or approval.

## Purpose

The read-only demo readiness planning lane prepares the evidence shape for a future human-reviewed, single-target, read-only/no-op demo readiness decision. It does not perform a demo and does not inspect product repositories.

The lane exists to make future review safer by defining what a valid planning package would need before any later, separate approval packet could even be considered.

## In Scope

- Documentation for future read-only demo readiness requirements.
- JSON schemas for future approval packets, no-op/read-only command vocabulary, and planning-only evidence records.
- Local fixtures that prove denied, deferred, and planning-only outcomes.
- Approval packet templates that remain unfilled and non-authoritative.
- Stop signs for broad, stale, reused, missing-owner, phone-only, package-sending, command-binding, write-capable, remote-access, or evidence-as-authority cases.
- Compact evidence capture requirements that avoid raw logs by default.
- External audit prompt/checklist preparation for the planning lane.

## Out Of Scope

- Product-repo access.
- Live demo execution.
- Product mutation.
- Package creation or package sending.
- Remote access.
- Runtime command binding.
- Phone approvals.
- All-fleet execution.
- Staging, commit, push, merge, or deploy.
- Installs or migrations.
- Secrets/auth/payments/deploy work.
- Lock deletion or permission widening.
- Non-mock UI implementation.
- Future authority.

## Required Planning Evidence

A future read-only demo readiness planning packet must require:

- exact single selected target
- exact accountable human owner
- current repo fingerprint evidence reference
- exact read-only/no-op action list
- expiration timestamp
- stop signs
- evidence references
- validation command references
- non-authority notice
- external audit review path

Missing, broad, wildcard, multi-target, stale, reused, phone-only, write-capable, package-sending, command-binding, remote-access, product-mutation, or evidence-as-authority cases must fail closed as denied, deferred, or `UNKNOWN`.

## Allowed Planning Vocabulary

The lane may define labels for planning-only actions such as:

- `READ_STATUS`
- `READ_REPO_FINGERPRINT`
- `READ_VALIDATION_SUMMARY`
- `READ_AUDIT_EVIDENCE`
- `READ_DRY_RUN_EVIDENCE`
- `READ_CONTROL_ROOM_SNAPSHOT`
- `NO_OP_READINESS_CHECK`

These are labels only. They do not execute commands, inspect product repositories, bind runtime behavior, send packages, approve phone actions, run all-fleet commands, or approve a demo.

## Approval Boundary

Any future approval packet must be exact-action-bound, single-target, current, expiring, and human-filled. A template, schema, audit report, validation summary, queue entry, generated evidence record, UI label, button, notification, mobile request, prompt, or DOCX report cannot fill or approve that packet.

The planning lane may define the packet shape. It must not fill it for a real product, infer missing fields, reuse prior approvals, refresh expired approvals, or approve write-capable actions.

## Stop Conditions

Stop and repacketize if any task in this lane requires product-repo access, demo execution, package creation/sending, remote access, runtime command binding, phone approvals, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, or treating audit output as authority.

## Common Non-Authority Phrase Set

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Exit Criteria For This Planning Lane

The planning lane is ready for external audit only when bounded tasks have produced:

- this charter
- an unfilled read-only demo approval packet template
- a no-op/read-only command vocabulary contract
- read-only demo stop signs
- compact evidence capture guidance
- local fixtures for valid planning-only, denied, and deferred outcomes
- an evidence-only external audit prompt/checklist
- passing local validation

Even if all exit criteria pass, the result remains planning evidence only. It does not approve product-repo access, demo execution, runtime command binding, package sending, phone approvals, all-fleet execution, non-mock UI implementation, or future authority.
