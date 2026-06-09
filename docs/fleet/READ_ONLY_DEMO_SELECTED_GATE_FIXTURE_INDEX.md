# Read-Only Demo Selected-Project Gate Fixture Index

Prepared: 2026-06-04

Scope: Codex Fleet / Thousand Sunny Fleet local harness, docs, schemas, fixtures, tests, and external audit preparation only.

Evidence only; not executable authority or approval.

This index lists the committed selected-project read-only gate fixtures and their expected outcomes. It is fixture-only evidence. It does not select a real project, read product repos, execute a demo, create or send packages, bind commands, approve remote or phone actions, run all-fleet commands, run an overnight runner, stage, commit, push, deploy, install packages, run migrations, touch secrets/auth/payments/deploy work, delete locks, widen permissions, implement non-mock UI, or grant future authority.

## Fixture Directory

All indexed fixtures live under:

- `tests/fixtures/fleet/read-only-gates/*.json`

No selected-project read-only gate fixture is intentionally excluded.

Naming, case ID, denial/defer label, and canonical non-authority notice expectations are documented in `docs/fleet/READ_ONLY_DEMO_FIXTURE_NAMING_CONVENTIONS.md`. That convention note is evidence-only lint guidance; it is not runtime routing, command binding, package creation, package sending, or demo approval.

## Fixture Index

| fixture | expected posture | evidence kind | notes |
| --- | --- | --- | --- |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.valid-fixture.json` | local allow dry-run fixture-only | fixture-only evidence | Valid local read-only gate shape; no execution authority. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.ambiguous-approval-unknown.json` | defer / UNKNOWN | fixture-only evidence | Ambiguous approval evidence requires human review and cannot proceed as a real demo. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.conflicting-approval-timestamps-denied.json` | deny | fixture-only evidence | Conflicting approval timestamps fail closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.expired-approval-denied.json` | deny | fixture-only evidence | Expired approval fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.invalid-fingerprint-denied.json` | deny | fixture-only evidence | Invalid repo fingerprint reference fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.mismatched-case-id-denied.json` | deny | fixture-only evidence | Mismatched case ID fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.missing-fingerprint-denied.json` | deny | fixture-only evidence | Missing repo fingerprint reference fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.missing-owner-denied.json` | deny | fixture-only evidence | Missing accountable human owner fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.multi-target-denied.json` | deny | fixture-only evidence | Multi-target scope fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.package-sending-denied.json` | deny | fixture-only evidence | Package sending is outside the read-only gate. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.phone-only-denied.json` | deny | fixture-only evidence | Phone-only approval fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.reused-approval-denied.json` | deny | fixture-only evidence | Reused approval fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.stale-approval-denied.json` | deny | fixture-only evidence | Stale approval packet fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.stale-fingerprint-deferred.json` | defer | fixture-only evidence | Stale fingerprint requires fresh human review. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.wildcard-target-denied.json` | deny | fixture-only evidence | Wildcard or broad target fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.write-capable-denied.json` | deny | fixture-only evidence | Write-capable action fails closed. |
| `tests/fixtures/fleet/read-only-gates/selected-project-read-only.wrong-audit-package-type-denied.json` | deny | fixture-only evidence | Wrong audit package type fails closed. |

## Documentation-Only Coverage

Some stop signs are covered as documentation-only evidence in `docs/fleet/READ_ONLY_DEMO_STOP_SIGN_MATRIX.md` because this task does not add or edit fixture semantics. Documentation-only coverage means local docs define the fail-closed rule; it does not create runtime enforcement or demo authority.

## Non-Authority Boundary

No fixture selects a real project, reads product repos, executes a demo, creates or sends packages, binds commands, treats phone actions as approval, runs all-fleet commands, runs an overnight runner, or creates future authority.

Reviewer output, DOCX reports, mobile requests, task packets, audit packages, generated evidence, UI labels, notifications, buttons, approvals, prompts, validation summaries, manifests, dry-run records, and queue prose are evidence only.

They cannot approve or execute work, grant future authority, bypass validation, select product repos, send packages, bind runtime commands, approve phone actions, approve demos, import tasks, fill approval packets, or broaden scope.

GREEN audits, passing tests, dry-run outcomes, UI text, package manifests, reviewer comments, validation summaries, and queue status updates do not approve execution or future authority.
