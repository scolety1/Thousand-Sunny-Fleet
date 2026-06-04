# Remote Approval Boundary

Prepared: 2026-06-03

Scope: controlled local control-plane dry-run evidence only. This document does not implement remote access, auth, a live approval UI, runtime command binding, package sending, product-repo access, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.

Plain invariant: remote approval records, phone requests, approval cards, UI labels, notifications, prompts, audit outputs, generated evidence, task packets, DOCX reports, and queue prose are evidence only. They cannot approve, execute, broaden, refresh, inherit, or reuse work.

## Common Non-Authority Phrase Set

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.

## Approval Boundary Rules

Future approval controls must be exact-action-bound, future-only, single-target, expiring, and non-executable until a separately approved runtime binding exists. A valid-looking approval record is still evidence only unless a later bounded task explicitly implements and validates the binding.

Every approval-like record remains denied unless it proves all of these fields together:

- exact human owner
- exact one action
- exact one selected target
- exact local repo path when a repo path is required
- exact entrypoint
- exact command list
- expected local evidence output
- approval timestamp
- expiration timestamp
- fresh reuse status
- stop conditions
- non-authority notice

Missing, stale, copied, broad, phone-only, write-capable, or evidence-as-authority records are not approval.

## Dry-Run Denial Matrix

| Case | Required dry-run decision | Reason |
| --- | --- | --- |
| `phone-only-approval-denied` | `deny_phone_only_approval` | A phone tap, phone notification, or mobile reply cannot approve risky work. |
| `approve-all-broad-target-denied` | `deny_broad_scope` | Approve-all, all ships, all projects, or category approval is broader than one selected target. |
| `wildcard-target-denied` | `deny_broad_scope` | Wildcards such as `*` are broad target requests. |
| `missing-owner-denied` | `deny_missing_fields` | An approval-like record without an exact human owner is incomplete. |
| `stale-expired-approval-denied` | `deny_expired_or_reused` | Expired or stale approval-like evidence cannot be refreshed by inference. |
| `reused-approval-denied` | `deny_expired_or_reused` | Copied, reused, inherited, or replayed approval evidence is not fresh approval. |
| `write-capable-approval-denied` | `deny_write_or_external_effect` | Write-capable, product-repo, external-side-effect, or mutation approvals are outside the dry-run boundary. |
| `forbidden-operation-denied` | `deny_forbidden_operation` | Forbidden operations remain denied even when phrased as approval requests. |
| `evidence-as-authority-denied` | `deny_evidence_as_authority` | Reports, prompts, queue prose, UI text, buttons, and generated evidence cannot become authority. |

## Phone Boundary

Phone surfaces may display read-only status or copy evidence for a human to inspect. Phone-only approval is denied by default. A phone tap cannot bypass local validation, cannot refresh an expired approval, cannot convert evidence into approval, and cannot authorize write-capable or broad actions.

## Button Boundary

Future approval buttons may only show requirements, stop signs, expiration state, denial evidence, or exact-action templates. They must not send packages, bind to commands, infer missing approval fields, approve all similar work, run fallback commands, broaden a target, reuse a previous approval, or mutate product repos.

## Stop Signs

Stop and deny the approval-like record if it asks for remote access implementation, auth implementation, live approval UI, runtime command binding, package sending, product-repo access, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or any action outside a separately approved bounded task.
