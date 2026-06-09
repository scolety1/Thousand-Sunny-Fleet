# Read-Only Demo Stop-Sign Coverage Matrix

Prepared: 2026-06-04

Scope: Codex Fleet / Thousand Sunny Fleet local harness, docs, schemas, fixtures, tests, and external audit preparation only.

Evidence only; not executable authority or approval.

This matrix maps read-only demo stop signs to local denial, defer, UNKNOWN, or documentation-only evidence. It does not add runtime enforcement, does not approve demo execution, select product repos, create or send packages, bind runtime commands, approve remote or phone actions, run all-fleet commands, run an overnight runner, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or grant future authority.

## Purpose

Use this matrix to check whether each stop sign has local coverage before preparing future external audit evidence. Coverage means a committed local fixture, source doc, schema, or test records that the condition must deny, defer, or remain UNKNOWN. Coverage does not mean the system may execute a real demo.

## Coverage Matrix

| stop sign | expected posture | local evidence |
| --- | --- | --- |
| missing approval | deny or defer | `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`; `docs/fleet/READ_ONLY_DEMO_APPROVAL_PACKET.md`; documentation-only coverage |
| missing owner | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.missing-owner-denied.json`; `docs/fleet/READ_ONLY_DEMO_GATE_REHEARSAL_PLAN.md` |
| broad target | deny | `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`; `docs/fleet/READ_ONLY_DEMO_APPROVAL_COMPLETENESS_CHECKLIST.md`; documentation-only coverage |
| blank target | deny | `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`; documentation-only coverage |
| all target | deny | `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`; documentation-only coverage |
| wildcard target | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.wildcard-target-denied.json`; `docs/fleet/READ_ONLY_DEMO_GATE_REHEARSAL_PLAN.md` |
| multi-target | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.multi-target-denied.json`; `docs/fleet/READ_ONLY_DEMO_GATE_REHEARSAL_PLAN.md` |
| stale approval | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.stale-approval-denied.json` |
| expired approval | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.expired-approval-denied.json` |
| reused approval | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.reused-approval-denied.json` |
| stale fingerprint | defer | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.stale-fingerprint-deferred.json`; `docs/fleet/READ_ONLY_DEMO_GATE_REHEARSAL_PLAN.md` |
| missing fingerprint | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.missing-fingerprint-denied.json` |
| invalid fingerprint | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.invalid-fingerprint-denied.json` |
| package sending | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.package-sending-denied.json`; `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md` |
| write-capable action | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.write-capable-denied.json`; `docs/fleet/READ_ONLY_DEMO_GATE_REHEARSAL_PLAN.md` |
| remote access | deny | `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`; documentation-only coverage |
| phone-only approval | deny | `tests/fixtures/fleet/read-only-gates/selected-project-read-only.phone-only-denied.json`; `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md` |
| all-fleet execution | deny | `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`; documentation-only coverage |
| command binding | deny | `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`; documentation-only coverage |
| evidence-as-authority | deny | `docs/fleet/READ_ONLY_DEMO_STOP_SIGNS.md`; `docs/fleet/READ_ONLY_DEMO_GO_NO_GO_SCORECARD.md`; documentation-only coverage |

## Expected Outcomes

- Deny means the packet or fixture must remain blocked from live execution.
- Defer means the packet or fixture requires fresh human review and cannot proceed as a real demo.
- UNKNOWN means reconciliation evidence is incomplete or mismatched and cannot be treated as approval.
- Documentation-only coverage means current local docs define the fail-closed rule, but no additional fixture is required in this task.

## Boundary

The matrix is local coverage evidence only. It cannot fill approval packets, import reviewer suggestions, turn YELLOW real demo readiness GREEN, run validation by itself, create or send packages, inspect product repositories, bind runtime commands, approve phone actions, run all-fleet commands, run an overnight runner, or broaden scope.

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.
