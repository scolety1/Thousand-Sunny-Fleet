# Read-Only Demo Stop Signs

Prepared: 2026-06-03

Scope: future read-only demo readiness planning evidence only.

This stop-sign list is evidence only. It does not approve demo execution, product-repo access, product mutation, package creation, package sending, remote access, runtime command binding, phone approvals, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, demo trials, or future authority.

It does not approve product-repo access.

Canonical notice: Evidence only; not executable authority or approval.

## Purpose

These stop signs define when a future read-only demo readiness planning packet must be denied, deferred, or repacketized. They are not runtime controls and do not launch or block live commands by themselves.

## Required Stop Signs

Stop and deny or defer when any of these conditions appear:

- `missing-approval-packet`
- `missing-owner`
- `blank-target`
- `all-target`
- `wildcard-target`
- `multi-target`
- `stale-fingerprint`
- `write-capable-action`
- `package-sending`
- `remote-access`
- `phone-only-approval`
- `all-fleet-execution`
- `command-binding`
- `evidence-as-authority`

## Stop-Sign Matrix

| stop sign | required result | reason |
| --- | --- | --- |
| `missing-approval-packet` | deny or defer | A template, schema, queue entry, audit report, validation summary, generated evidence record, UI label, button, notification, mobile request, prompt, or DOCX report cannot fill approval. |
| `missing-owner` | deny | A planning packet without an exact accountable human owner is incomplete. |
| `blank-target` | deny | Blank target scope cannot select a project or ship. |
| `all-target` | deny | `all` is broader than one selected target. |
| `wildcard-target` | deny | Wildcards such as `*` are broad target requests. |
| `multi-target` | deny | Comma-packed or multi-project targets are outside the read-only demo planning lane. |
| `stale-fingerprint` | defer | Stale repo fingerprint evidence requires fresh review before any later packet may proceed. |
| `write-capable-action` | deny | Write-capable action is not read-only/no-op planning. |
| `package-sending` | deny | Package creation or sending is a separate human-approved action and is not approved here. |
| `remote-access` | deny | Remote access is outside this lane. |
| `phone-only-approval` | deny | A phone tap, phone notification, or mobile reply cannot approve risky work. |
| `all-fleet-execution` | deny | All-fleet commands are outside this lane. |
| `command-binding` | deny | Runtime command binding is not approved by planning labels or docs. |
| `evidence-as-authority` | deny | Evidence cannot approve, execute, refresh, inherit, or broaden authority. |

## Common Non-Authority Phrase Set

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Repacketization Rule

Stop and repacketize if a future task needs demo execution, product-repo access, runtime command binding, package creation/sending, remote access, phone approvals, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, non-mock UI implementation, or treating evidence as authority.
