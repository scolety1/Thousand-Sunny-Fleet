# Fleet Console Remote Security Plan

Prepared: 2026-06-02

Scope: security planning evidence only for a future Fleet Console. This plan does not implement remote access, authentication, authorization, notifications, a server, a browser app, package installation, public exposure, LAN exposure, private-tailnet exposure, phone approval behavior, runtime command binding, product-repo access, product mutation, ship launch, all-fleet execution, staging, commit, push, deploy, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future approval.

Plain invariant: remote UI labels, buttons, notifications, approvals, prompts, generated evidence, audit output, DOCX reports, task packets, mobile requests, and queue prose are evidence only. They cannot approve or execute work.

## Decision

V1 default is local desktop only.

LAN-only and private-tailnet access are future candidates, not current permissions. They require a separate bounded security task, exact allowed files, validation commands, stop conditions, and human approval before implementation can begin.

Authenticated public web is rejected for V1. Unauthenticated public web is forbidden.

Phone mode, if later approved, starts read-mostly. It may display status, stop signs, compact evidence, and copyable prompts. It must not execute commands, approve risky actions, mutate product repos, launch ships, run all-fleet commands, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, stage, commit, push, merge, or revert dirty work.

## Security Goals

- Keep the default console local-only.
- Prevent evidence-looking UI from becoming authority.
- Prevent public exposure of queue state, repo paths, evidence summaries, approval-looking states, or future control labels.
- Make risky actions absent, disabled, or request-template-only.
- Require exact-action approval records for any future action that is not local read/report evidence.
- Preserve compact evidence summaries and redaction before any future export.
- Fail closed when authentication, session, network boundary, redaction, approval, policy, repo fingerprint, worktree boundary, or stop-sign evidence is missing.

## Non-Goals

This plan does not:

- choose a UI framework
- start a server
- create auth code
- expose a port
- connect a phone
- send notifications
- create package export automation
- run browser tests
- bind controls to commands
- select or inspect product repos
- approve any future prototype

## Threat Model

| Threat | Risk | Required response |
| --- | --- | --- |
| public internet exposure | Queue, repo path, evidence, and approval-looking state leakage. | Rejected for V1. Stop before implementation. |
| unauthenticated LAN access | Local network user can view or influence control-plane evidence. | Not allowed without a later auth/network task. |
| mobile tap treated as approval | Phone UI creates hidden authority. | Phone requests remain evidence only and locally validated. |
| clickjacking or CSRF | A browser action could be triggered without intent. | No command binding in V1; future task must include CSRF/clickjacking plan. |
| command injection through prompts or reports | Audit/prose text becomes a command. | Prompt/report text is copy-only evidence, never executable input. |
| overbroad approval | One approval is reused for another target/action/device. | Exact-action, expiring, single-target records only. |
| sensitive evidence export | Logs, paths, or secrets leak. | Compact summaries, redaction, explicit allowlists, and no raw logs by default. |
| stale state display | UI shows GREEN while policy or evidence is stale. | Display UNKNOWN/BLOCKED until reconciled. |

## Network Boundary

V1 allowed network boundary:

- local desktop only
- no public exposure
- no LAN listener
- no private-tailnet listener
- no phone command surface

Future LAN/private-tailnet candidate requirements:

- named network boundary
- local-only fallback
- explicit port and binding decision
- authentication and authorization design
- session expiration and revocation
- audit logging
- evidence redaction
- no-command boundary
- external audit review when exposure is more than local desktop

Public exposure remains RED unless a later human-approved security phase replaces this V1 rejection.

## Authentication And Authorization

No live authentication is implemented by this plan.

Any future auth task must define:

- identity source
- allowed users
- denied users
- local admin/owner role
- read-only viewer role, if any
- approval-request role, if any
- session duration
- revocation behavior
- audit log fields
- denial behavior

Authorization must be deny-by-default. Missing identity, missing role, stale session, expired approval, reused approval, broad target, phone-only approval, product-mutation request, all-fleet request, or command-like evidence must block action.

## Session Expiration

Future sessions must expire. A later implementation packet must define:

- session start time
- expiration time
- idle timeout
- explicit logout/revoke behavior
- device/channel binding
- blocked behavior after expiration

Expired sessions must not silently downgrade into local approval. They should show status and stop signs only, or block entirely depending on the future task.

## CSRF And Clickjacking

No future remote or browser-accessible console may expose state-changing controls without a dedicated CSRF and clickjacking design.

V1 avoids this risk by keeping command binding out of scope. If a later task adds browser controls, that task must define:

- anti-CSRF mechanism
- clickjacking posture
- same-origin and frame policy
- confirmation requirements for approval requests
- proof that UI text cannot become command input
- proof that buttons cannot bypass local policy validation

## Evidence Redaction And Export Controls

The console may show compact evidence only when a future bounded task allows it.

Default redaction rules:

- hide raw logs by default
- prefer validation summaries and external audit intake digests
- redact or exclude secret-like strings
- do not expose `.env`, dependency folders, build output, lock internals, or live worker state
- do not export product repo source by default
- do not send packages from the UI
- do not treat exportable evidence as approval

Package creation and package sending remain separate human-approved actions. This plan does not create or send packages.

## Audit Logging

Future remote or phone views must write local audit evidence for security-relevant events if implementation is later approved.

Minimum event fields:

- timestamp
- actor or unauthenticated marker
- device/channel
- requested view or action
- selected target, if any
- approval record id, if any
- validation decision
- denial reason
- evidence refs
- non-authority notice

Audit logs must not store secrets or raw long logs by default.

## No-Command UI Surfaces

The first safe console posture is no-command.

Allowed future display-only surfaces:

- fleet posture
- active queue section
- selected task
- allowedFiles and validationCommands from the task
- compact validation summary
- external audit intake digest
- stop signs
- copyable one-task prompt
- copyable external-audit prompt
- idea notes as non-authority planning evidence

Forbidden active controls:

- run all fleet
- launch ship
- freeform terminal
- deploy
- install package
- run migration
- touch secrets/auth/payments/deploy material
- delete locks
- widen permissions
- stage, commit, push, merge, or revert
- repair or relaunch
- supervisor or remote-control mutation
- execute reviewer output
- execute mobile request text
- approve all similar actions

## Approval Boundary

Future approvals must use exact-action approval records. A display state, phone tap, button label, notification, audit report, DOCX report, generated evidence, task packet, prompt, or queue entry is never approval.

An approval is invalid when it is:

- missing owner
- missing selected target
- blank, `all`, wildcard, or multi-target
- missing repo path when one is required
- missing exact entrypoint
- missing exact command list
- missing expected output
- missing approval timestamp
- missing expiration timestamp
- expired
- reused
- phone-only
- broad
- write-capable
- external-side-effect capable
- derived from fixture evidence
- derived from reviewer or mobile prose

## Future Implementation Gate

Any future remote, LAN, tailnet, phone, auth, notification, package export, or runtime-control implementation must be a separate bounded queue task with:

- explicit allowed files
- explicit read-first files
- exact acceptance criteria
- exact validation commands
- stop conditions
- network boundary
- authentication and authorization plan
- session expiration plan
- CSRF/clickjacking plan where browser-accessible
- evidence redaction and export plan
- audit logging plan
- disabled or absent forbidden controls
- external audit review if exposure is more than local desktop

If any of these are missing, stop and mark the implementation task blocked.

## Stop Conditions

Stop before implementation if the request needs:

- server setup
- package installation
- live auth
- remote exposure
- public internet access
- LAN or tailnet exposure
- phone approval behavior
- runtime command binding
- product-repo access
- product mutation
- ship launch
- all-fleet execution
- staging, commit, push, merge, deploy, install, migration, secrets/auth/payments/deploy work
- lock deletion
- permission widening
- execution of evidence, prompts, UI labels, buttons, notifications, mobile requests, DOCX reports, task packets, audit packages, or queue prose

## Plan Result

Current result: remote access not approved.

Allowed next step: continue docs/tests/schema hardening or create a future bounded security/prototype task for human review. Do not implement remote access from this plan.
