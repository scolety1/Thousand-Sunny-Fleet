# Read-Only Demo Evidence Capture

Prepared: 2026-06-03

Scope: future read-only demo readiness planning evidence only.

This evidence-capture guide is evidence only. It does not approve demo execution, product-repo access, product mutation, package creation, package sending, remote access, runtime command binding, phone approvals, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, demo trials, or future authority.

It does not approve product-repo access.

Canonical notice: Evidence only; not executable authority or approval.

## Purpose

The read-only demo readiness planning lane needs compact, reviewable evidence that proves what was checked without importing raw logs, broad prose, or external output as authority. Evidence capture is for later review. It is not command execution.

## Required Evidence Fields

Every future read-only demo readiness evidence record must include:

- exact selected target reference
- exact human owner reference
- exact approval packet reference
- exact read-only/no-op action labels
- current repo fingerprint reference
- source docs
- stop signs reviewed
- compact summaries
- exact validation command refs
- evidence refs
- validation result
- non-authority notice
- no raw logs by default

## Compact Summary Rules

Capture compact summaries instead of raw logs by default. A compact summary should state:

- what local docs, schemas, fixtures, or evidence records were reviewed
- which validation commands were referenced or run by a bounded task
- whether validation passed, failed, or was not run
- which stop signs were inactive or active
- which evidence refs support the decision
- why the record remains evidence only

Raw logs are excluded by default. If a later human-approved task requires raw log excerpts, the task must explicitly list the allowed file, reason, maximum excerpt size, and redaction expectations. Raw logs cannot contain secrets, auth/payments/deploy material, product-repo paths, command tokens, package-sending instructions, or approval material.

## Source Docs

Future evidence records should reference source docs by path instead of pasting broad prose:

- `docs/fleet/READ_ONLY_DEMO_READINESS_PLANNING_CHARTER.md`
- `docs/fleet/READ_ONLY_DEMO_APPROVAL_PACKET.md`
- `docs/fleet/READ_ONLY_DEMO_COMMAND_VOCABULARY.md`
- `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`
- `docs/fleet/POST_CONTROLLED_HARDENING_NEXT_PHASE_DECISION.md`
- `docs/fleet/STABLE_CONTEXT_CAPSULE.md`
- `docs/fleet/NEW_CHAT_HANDOFF_PACKET.md`

## Validation Command References

Validation command refs must be exact strings from the bounded task or queue entry. They cannot be broadened into all-fleet commands, demo commands, package-sending commands, remote access commands, staging/commit/push/deploy commands, install/migration commands, or command-binding instructions.

## Evidence-As-Authority Guard

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Stop Conditions

Stop and repacketize if evidence capture requires demo execution, product-repo access, runtime command binding, package creation/sending, remote access, phone approvals, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, raw logs by default, or treating evidence as authority.
