# Other-Project Test Readiness Gate

Prepared: 2026-05-31

Scope: Codex Fleet harness, docs, schemas, and tests only. This gate defines when it is locally reasonable to use the fleet around other projects. It does not grant permission to touch real product repos, launch product ships, run all-fleet commands, merge, push, deploy, install packages, run migrations, touch secrets/auth/payments, delete locks, widen permissions, or treat external/mobile/task-packet prose as executable.

## Purpose

Other-project testing must be explicit, local, and reversible. The fleet can be considered ready for progressively safer use only when the HQ remediation evidence is green, high-risk entrypoints remain human-approval-only, and product-repo launch automation stays out of scope.

Plain invariant: readiness is evidence, not permission.
Plain invariant: read-only inspection is different from write/delete/launch/external-side-effect work.
Plain invariant: no product-repo launch automation is approved by this gate.

## GREEN

GREEN means the local HQ harness is ready for controlled planning around other projects, not for autonomous product mutation.

GREEN requires all of the following:

- HQ-020 external audit remediation is complete.
- Fail-closed contracts are checked.
- Strict schemas are checked.
- Human approval gates are documented.
- The External Audit Remediation Batch is complete or every remaining item is intentionally blocked.
- `tests/run-fleet-tests.ps1` passes after the latest HQ repair task.
- Legacy broad entrypoints remain `legacy_broad_requires_human`.
- Mobile requests, external reports, task packets, audit packages, and queue prose remain non-executable.
- No product-repo launch automation is enabled or approved.

Allowed under GREEN:

- Local harness/docs/tests validation.
- Fixture-only rehearsal.
- Preparing a human-reviewed plan for one explicitly selected project.
- Read/report evidence review when paths and scope are explicit.

Not allowed under GREEN:

- Touching real product repos without a separate exact-action approval.
- Launching product ships.
- Running all-fleet commands.
- Deploy, migration, auth, payment, secret, lock deletion, package install, permission widening, merge, push, or broad automation work.

## YELLOW

YELLOW means only manual, read-only, single-project inspection may be considered, and only with explicit human approval naming the selected project, entrypoint, allowed action, expected evidence, and stop condition.

YELLOW is the correct status when:

- The HQ harness tests pass, but some runtime safety-spine contracts or helper work remain pending.
- The operator wants to inspect one other project without changing it.
- Boundaries are understood enough for local read/report work, but not enough for product mutation.

Allowed under YELLOW:

- Manual read-only inspection for one selected project with explicit human approval.
- Local report writing inside the Codex Fleet harness or an approved evidence directory.
- No-op planning, risk review, or audit package design that does not read broad product configs by default.

Not allowed under YELLOW:

- Product repo edits.
- Product ship launches.
- All-fleet commands.
- Unscoped `new-audit-package.ps1` defaults.
- Automated repair, relaunch, supervisor, remote-control, deploy, migration, auth, payment, secret, package install, lock deletion, or permission-widening actions.

## RED

RED means do not test other projects.

RED applies when:

- Validation fails.
- The current task requires broader scope than its `allowedFiles`.
- Product repo boundaries are unclear.
- Human approval is missing or vague.
- The requested action would touch real product repos, launch product ships, run all-fleet commands, deploy, install packages, run migrations, touch secrets/auth/payments, delete locks, widen permissions, merge, push, or treat external/mobile/task-packet/queue prose as executable.
- Dirty work would need to be reverted without explicit captain approval.

Required RED action:

- Stop.
- Preserve evidence.
- Mark the request blocked or ask for exact human approval, depending on the queue task.
- Do not expand scope to make progress.

## Minimum Approval Shape For YELLOW Read-Only Inspection

A YELLOW read-only inspection approval must name:

- selected project
- exact repo path
- entrypoint
- exact read-only command
- allowed action
- expected output
- read-only evidence paths
- human owner
- approval timestamp
- expiration timestamp
- validation command or no-op check
- stop condition

Use `docs/fleet/DEMO_TRIAL_APPROVAL_PACKET.md` as the exact approval packet template before any manual read-only single-project demo trial. The packet must name the selected project, exact repo path, exact read-only commands, expected output, owner, approval timestamp, expiration timestamp, and stop conditions.

The approval packet must be complete, current, and not reused. Missing, expired, reused, broad, ambiguous, wildcard, all-fleet, multi-project, write-capable, external-side-effect, wrong-owner, placeholder-only, or non-exact approvals are RED and block the trial before action. The exact command must appear in the approved read-only command list and must write only approved local report evidence.

Example shape:

```text
Approved for read-only single-project inspection of <project> using <entrypoint>. Do not edit product files. Write only local report evidence to <path>. Stop if the command would launch, mutate, deploy, install, migrate, touch secrets/auth/payments, delete locks, widen permissions, merge, push, or expand beyond this project.
```

## Out Of Scope

- Product-repo launch automation.
- Autonomous product mutation.
- All-fleet execution.
- Broad package generation from real product repos.
- Runtime approval bypasses.
- Treating this readiness gate as permission.

## Runtime Enforcement Deferral Boundary

Runtime enforcement remains deferred. Leases, repo fingerprints, worktree boundaries, runtime policy decisions, selected-ship ledgers, strict schemas, and fixture helpers are currently safety-spine contracts or local evidence unless a later bounded task explicitly implements enforcement.

Because of that deferral, automated or mutating work remains YELLOW-to-RED depending on scope. The only real-project path this gate can support before runtime enforcement exists is one explicitly approved manual read-only single-project demo or inspection, and only after the approval packet, stop-sign review, external audit disposition, and commit-scope review are complete.

This gate does not allow product repo edits, product ship launches, all-fleet commands, automated repair, supervisor/relaunch flows, Fleet.Core/SQLite enforcement implementation, worktree creation, durable lease enforcement, deploy, package install, migration, secrets/auth/payments/deploy access, lock deletion, permission widening, merge, push, or treating contracts/schemas/helpers as permission.
