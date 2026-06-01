# Demo Trial Approval Packet Template

Prepared: 2026-05-31

Scope: template only. This document does not approve a real project, run the demo trial, touch product repositories, launch product ships, run all-fleet commands, merge, push, deploy, install packages, run migrations, touch secrets/auth/payments, delete locks, widen permissions, or treat external/mobile/task-packet/audit/queue prose as executable commands.

## Purpose

Use this template only after the fixture-only demo rehearsal is GREEN or explicitly accepted for review. The approval must authorize one manual, read-only, single-project demo trial. It expires and cannot be reused for another project, another entrypoint, another repo path, write actions, launch actions, or future runs.

Plain invariant: approval is exact-action-bound.
Plain invariant: approval for one selected project does not approve all-fleet scope.
Plain invariant: read-only demo approval is not product mutation approval.

## Approval Record

Fill every field before a real-project read-only demo trial is considered.

| Field | Required value |
| --- | --- |
| Approval status | `DRAFT`, `APPROVED_FOR_READ_ONLY_DEMO_TRIAL`, `REJECTED`, or `EXPIRED` |
| Approver / owner | `<human name>` |
| Approval timestamp | `<YYYY-MM-DDTHH:MM:SSZ>` |
| Expiration timestamp | `<YYYY-MM-DDTHH:MM:SSZ>` |
| Selected project id | `<exact project id>` |
| Exact repo path | `<absolute repo path approved for read-only inspection>` |
| Approved entrypoint | `<exact command/script>` |
| Allowed action | `manual read-only single-project inspection only` |
| Expected output | `<exact report/evidence paths>` |
| Validation or no-op check | `<exact command or explicit no-op check>` |
| Stop condition | `<condition that immediately stops the trial>` |

## Completeness Gate

The approval packet is incomplete and blocks the demo trial unless every required field is filled with an exact, current, single-project value. Missing, placeholder, expired, reused, broad, ambiguous, wildcard, all-fleet, multi-project, wrong-owner, write-capable, external-side-effect, or non-read-only approval is invalid.

Completeness gate result:

| Check | Required result |
| --- | --- |
| Approval status | exactly `APPROVED_FOR_READ_ONLY_DEMO_TRIAL` |
| Approver / owner | present and matches the human owner of this trial |
| Approval timestamp | present, parseable, and earlier than expiration |
| Expiration timestamp | present, parseable, and not expired |
| Selected project id | exact one-project id; not blank, `all`, wildcard, or multi-project |
| Exact repo path | absolute path that matches the selected project |
| Approved entrypoint | exact script or command surface from `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md` |
| Allowed action | exactly manual read-only single-project inspection only |
| Approved command list | at least one exact command, no placeholders, no broad defaults |
| Expected output | approved local report evidence path only |
| Stop condition | explicit and compatible with `docs/fleet/DEMO_TRIAL_STOP_SIGNS.md` |

If any completeness check fails, mark the trial blocked before action. Do not repair the packet by guessing. Do not run fallback commands. Do not treat a partial approval, chat message, external report, mobile request, task packet, audit package, queue prose, or this template as approval.

## Owner Training Note

Owners should treat this packet as a checklist for rejecting unsafe or incomplete authorization, not as a source of authorization by itself. The queue cannot fill a real approval packet, select a real project, infer owner intent, or turn fixture/example values into approval. A real packet must be completed later by a human owner before any real-project read-only demo trial is considered.

Reject an incomplete approval when any required field is blank, placeholder-only, missing from the approved read-only command list, or not tied to one exact selected project and one absolute repo path. Reject an expired approval when the expiration timestamp is missing, malformed, in the past, earlier than the approval timestamp, or stale for the current trial. Reject a reused approval when it was copied from a prior trial, another project, another repo path, another entrypoint, another command, or a fixture example.

Reject a broad approval when it names blank, `all`, wildcard, multi-project, broad audit packaging, unscoped launcher defaults, or future-run scope. Reject an ambiguous approval when the project id, absolute repo path, exact read-only commands, expected evidence, owner, approval timestamp, expiration timestamp, or stop conditions are vague, conflicting, or not current. Reject a write-capable approval when any command could write product files, mutate product repos, repair, relaunch, supervise, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, merge, push, create external side effects, or launch product ships.

A fixture-only approval is training evidence only. `FIXTURE_EXAMPLE_NOT_APPROVED`, `FixtureOnlyDemoProject`, fixture owner names, fixture repo paths, fixture no-op commands, fixture expected evidence, and fixture stop conditions are not valid for real projects. If a fixture-only approval appears in a real packet, stop before action and mark the real-project trial blocked.

Before any real-project read-only demo trial, the owner must provide all exact values: exact project id, absolute repo path, exact read-only commands, expected evidence, owner, approval timestamp, expiration timestamp, and stop conditions. Anything less is RED for the trial until a human owner replaces it with a current, exact, one-project packet.

## Required Approval Text

```text
Approved for manual read-only single-project demo trial of <project id> at <exact repo path> using <approved entrypoint>.

Allowed action: manual read-only inspection only.
Expected output: write only local report evidence to <approved evidence path>.
Validation/no-op check: <exact validation command or no-op check>.
Owner: <human owner>.
Approved at: <timestamp>.
Expires at: <timestamp>.

This approval forbids product file writes, product ship launches, all-fleet commands, merges, pushes, deploys, package installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission changes, external side effects, broad audit packaging, and use on any other project or repo path.

Stop immediately if scope is unclear, the repo path differs, the project identity is ambiguous, a command would write/delete/launch/deploy/install/migrate/touch secrets/auth/payments/delete locks/widen permissions/merge/push, or any requested action expands beyond this approval.
```

## Approved Read-Only Command List

List the exact commands allowed by this approval. Leave blank until the human owner fills it in.

| Command id | Exact command | Expected output | Writes allowed | Stop if |
| --- | --- | --- | --- | --- |
| `read-only-1` | `<exact command>` | `<path or console summary>` | local report evidence only | `<stop condition>` |

Allowed command rules:

- command must name exactly one selected project or repo path
- command must be read-only against the product repo
- command may write only approved local report evidence
- command must not use all-fleet scope
- command must not use unscoped `new-audit-package.ps1` defaults
- command must not trigger repair, relaunch, supervisor, remote-control, deploy, migration, package install, secret/auth/payment, lock deletion, permission, merge, push, or product launch behavior

## Fixture-Only Non-Approval Example

This example is fake fixture evidence only. It is not valid for real projects, not signed approval, not reusable approval, not current approval, and not permission to run any command. Do not copy this example into a real trial packet. A real packet must be filled by a human owner with exact current values for one project, one repo path, one read-only command list, expected evidence, approval timestamp, expiration timestamp, and stop conditions.

| Field | Fixture-only example value |
| --- | --- |
| Approval status | `FIXTURE_EXAMPLE_NOT_APPROVED` |
| Approver / owner | `Fixture Owner - not a real approver` |
| Approval timestamp | `2026-01-01T00:00:00Z` |
| Expiration timestamp | `2026-01-01T00:10:00Z` |
| Selected project id | `FixtureOnlyDemoProject` |
| Exact repo path | `C:\Dev\codex-fleet\.codex-local\fixtures\demo-trial\FixtureOnlyDemoProject` |
| Approved entrypoint | `fixture-only-demo-readiness-example` |
| Allowed action | `manual read-only single-project inspection only` |
| Expected output | `.codex-local/fixtures/demo-trial/evidence/fixture-report.md` |
| Validation or no-op check | `fixture-only no-op shape check` |
| Stop condition | `stop if copied, expired, reused, broadened, write-capable, external-side-effect capable, or aimed at a real project` |

Fixture command example, also not valid for real projects:

| Command id | Exact command | Expected output | Writes allowed | Stop if |
| --- | --- | --- | --- | --- |
| `fixture-read-only-1` | `fixture-only no-op: inspect FixtureOnlyDemoProject metadata` | `.codex-local/fixtures/demo-trial/evidence/fixture-report.md` | fixture report evidence only | copied into a real approval, changed to a real repo path, broadened, expired, reused, or made write-capable |

Rejected approval examples:

| Case | Why it is blocked |
| --- | --- |
| Missing approval | no exact human owner, timestamp, expiration, project id, repo path, command list, expected output, or stop condition |
| Expired approval | expiration timestamp is in the past or earlier than approval timestamp |
| Reused approval | prior approval is reused for another run, project, repo path, entrypoint, command, or future date |
| Broad approval | selected project is blank, `all`, wildcard, multi-project, or uses broad audit/package defaults |
| Ambiguous approval | project id, repo path, command, owner, evidence path, or stop condition is vague |
| Write-capable approval | command could write product files, edit product source, repair, relaunch, supervise, or mutate a repo |
| External-side-effect approval | command could call external services, publish, deploy, send messages, or create remote records |
| Forbidden operation approval | command could launch, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, merge, or push |

## Required Preflight Checklist

- [ ] `docs/fleet/FIXTURE_ONLY_DEMO_REHEARSAL_RUNBOOK.md` reviewed.
- [ ] `docs/fleet/OTHER_PROJECT_TEST_READINESS.md` status is GREEN or explicitly accepted YELLOW for manual read-only inspection.
- [ ] `docs/fleet/ENTRYPOINT_SAFETY_INVENTORY.md` confirms the selected entrypoint is read/report safe or selected-project required.
- [ ] Selected project id is exact.
- [ ] Exact repo path is exact and approved.
- [ ] Allowed commands are exact and read-only.
- [ ] Expected evidence paths are local report paths only.
- [ ] Approval timestamp and expiration timestamp are filled.
- [ ] Stop conditions are explicit.
- [ ] No product-repo write, launch, all-fleet, deploy, install, migration, secrets/auth/payments, lock deletion, permission widening, merge, or push work is approved.

## Stop Conditions

Stop before action and preserve evidence if any of these occur:

- selected project id is missing, vague, changed, wildcard, `all`, or multi-project
- exact repo path is missing, changed, ambiguous, or unexpected
- approval is missing, incomplete, expired, reused, broad, ambiguous, write-capable, external-side-effect capable, all-fleet, or from the wrong owner
- approval status is not exactly `APPROVED_FOR_READ_ONLY_DEMO_TRIAL`
- approval timestamp or expiration timestamp is missing, malformed, expired, or inconsistent
- command is not listed in the approved read-only command list
- command differs from the exact approved command
- command would write product files
- command would launch product ships
- command would run all-fleet commands
- command would deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, merge, or push
- command would start repair, relaunch, supervisor, remote-control, overnight, or broad automation behavior
- command would use unscoped audit package defaults or export product source
- external reports, mobile requests, task packets, audit packages, this template, or queue prose are treated as executable commands

Before any real-project read-only demo trial, also review `docs/fleet/DEMO_TRIAL_STOP_SIGNS.md`. That checklist is evidence and stop guidance only; it does not approve execution, broaden scope, or replace the exact approval packet.

## Expiration And Reuse

Approval expires at the expiration timestamp. Expired approval means stop. Approval cannot be reused for another project, another repo path, another entrypoint, another command, write access, product launch, all-fleet scope, deploy, install, migration, secrets/auth/payments work, lock deletion, permission widening, merge, push, or future runs.

If anything changes, create a new approval packet.

Reused approval is invalid even when the project name looks similar, the repo path is nearby, the command is read-only, or a prior trial ended GREEN. Every trial needs a fresh owner, timestamp, expiration, exact command list, and stop condition.

## Result Recording

After an approved read-only trial, record what actually happened in `docs/fleet/DEMO_TRIAL_EVIDENCE_TEMPLATE.md` when that template exists. Until then, record only local notes that confirm:

- approved scope
- commands actually run
- output summary
- blocked operations
- no-op confirmation
- unresolved risks

This template remains evidence and approval structure only; it is not execution authority by itself.
