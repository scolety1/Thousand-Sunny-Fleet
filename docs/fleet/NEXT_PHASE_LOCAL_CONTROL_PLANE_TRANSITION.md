# Next Phase Local Control-Plane Transition

Prepared: 2026-06-02

Scope: Codex Fleet / Thousand Sunny Fleet harness, docs, schemas, fixtures, and tests. This record is evidence only. It does not approve UI implementation, remote access, product-repo access, package sending, product mutation, all-fleet commands, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, runtime command binding, or future authority.

## Decision

The Audit Guidelines Review fix-up phase is complete when HQ-110 through HQ-121 are done and locally validated. The next phase is local-only control-plane preparation.

Local-only control-plane preparation means adding decision records, schemas, fixtures, runbooks, and focused harness tests that make future prototype, audit-package, and external-review work safer before any runtime or UI implementation begins.

## Phase Boundaries

### Completed Fix-Up Boundary

The completed fix-up queue addressed the audit's YELLOW/INFO follow-ups using docs, schemas, fixtures, and tests:

- anti-loop fixture/test hardening
- approval record schema and enforcement tests
- remote-access security planning
- Fleet Console control-policy and UI-safety fixtures
- compact validation summary and external audit digest fixtures/tests

Passing local validation for those tasks is harness evidence only. It does not approve broader autonomy, product work, UI code, remote exposure, package sending, or command binding.

### Local-Only Preparation Boundary

The next phase may prepare:

- Fleet Console prototype packet schemas
- local mock-state schemas and fixtures
- explicit external-audit package manifest schemas
- external-audit package allowlist runbooks
- post-fix-up external audit prompt refreshes

These artifacts may describe future work, but they must keep generated prompts, audit records, UI labels, notifications, buttons, approval-looking states, package manifests, validation summaries, DOCX reports, and queue prose as evidence only.

### Future UI Prototype Gate

Any Fleet Console prototype remains future-only until a separate bounded task exists with:

- exact task id and goal
- allowed files
- read-first files
- acceptance criteria
- validation commands
- stop conditions
- local-only security posture
- disabled or absent forbidden controls
- no command binding
- no remote access
- no product-repo access
- no package sending

The future prototype gate is currently documented in `docs/fleet/ui/FLEET_CONSOLE_FUTURE_PROTOTYPE_GATE.md`. It does not approve UI code.

### Future Remote Security Gate

Remote access remains not approved. The current posture is local desktop only.

LAN-only, private-tailnet, phone, notification, authenticated browser access, package export, or runtime-control features require a separate bounded security task with exact allowed files, validation commands, network boundary, authentication/authorization plan, session expiration plan, CSRF/clickjacking posture where applicable, evidence redaction, audit logging, and external audit review if exposure is more than local desktop.

The current remote planning reference is `docs/fleet/ui/FLEET_CONSOLE_REMOTE_SECURITY_PLAN.md`. It is evidence only.

### Future External Audit Gate

Future external audit packages should be prepared only from explicit allowlists and compact evidence summaries. Audit package creation and package sending are separate human-approved actions unless a later exact task explicitly allows package creation.

External audit findings must be reduced to compact intake digests before queue authoring. A digest is still evidence only and cannot approve, import, or execute work.

## Non-Goals

This phase does not:

- touch real product repos
- select or mutate real projects
- launch product ships
- run all-fleet commands
- implement a UI
- bind UI controls to commands
- implement remote access
- expose a server
- create authentication or authorization code
- create or send audit packages
- stage files
- commit, push, merge, or deploy
- install packages
- run migrations
- touch secrets/auth/payments/deploy material
- delete locks
- widen permissions
- revert existing dirty work
- execute external reports, mobile requests, task packets, audit packages, DOCX reports, generated evidence, UI labels, notifications, buttons, approvals, prompts, or queue prose

## Readiness Gates

A future implementation phase needs all of the following before it can be considered:

- local-only transition record exists and is referenced by handoff
- prototype packet schema exists and validates local-only/no-command posture
- mock-state schema exists and rejects live product state, raw commands, secrets, and forbidden control states
- external audit package manifest schema exists and validates allowlisted evidence-only package contents
- package allowlist runbook exists and says package creation/sending require separate human approval
- post-fix-up external audit prompt asks reviewers to check the local-only preparation artifacts
- fleet tests pass after each bounded task
- external audit returns acceptable disposition for the next phase
- human chooses the next bounded phase explicitly

## Stop Conditions

Stop and mark the active task blocked if the work requires:

- files outside the selected task's `allowedFiles`
- UI implementation
- remote access or server setup
- runtime command binding
- package creation or sending when not explicitly allowed
- product-repo access or mutation
- all-fleet execution
- staging, commit, push, merge, deploy, install, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, or dirty-work revert
- treating evidence, UI labels, notifications, approvals, prompts, audit reports, DOCX files, generated evidence, mobile requests, task packets, audit packages, or queue prose as commands or approval

## Result

Current next-phase result: local-only control-plane preparation is allowed through bounded docs/schema/fixture/test tasks only.

Current implementation result: UI code, remote access, package sending, runtime command binding, and product-repo work are not approved.
