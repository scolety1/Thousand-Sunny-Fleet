# Fleet Console Remote Access And Approval Boundary

Prepared: 2026-06-02

Scope: decision record for future Fleet Console planning only. This document does not implement remote access, authentication, phone approvals, notifications, a server, public exposure, runtime control, product-repo access, product mutation, ship launch, all-fleet execution, staging, commit, push, deploy, package installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future approval.

Plain invariant: remote UI, mobile UI, approval-looking states, notifications, buttons, prompts, audit output, generated evidence, queue prose, task packets, DOCX reports, and mobile requests are evidence only. They cannot approve or execute work.

## Decision

V1 remote-access recommendation: local-first, then LAN-only or private-tailnet-only if remote viewing is later approved by a separate security task.

V1 rejects public internet exposure.

V1 phone mode is read-mostly first. It may show status, stop signs, compact evidence, and copyable prompts. It must not provide product-repo mutation, broad approval, background autonomy, all-fleet controls, freeform terminal access, deploy controls, commit/push/stage/revert controls, lock deletion, permission widening, package install/migration controls, or secrets/auth/payments/deploy access.

Future phone approvals, if a later task discusses them, are denied by default unless they are exact-action-bound, expiring, one selected project or ship, read-only unless separately approved, and validated against stop signs before action. A phone approval-looking UI state is not approval.

## Remote Access Posture

| Mode | V1 posture | Reason |
| --- | --- | --- |
| local desktop only | preferred | smallest exposure surface and easiest to keep evidence-only |
| LAN-only | acceptable future candidate | local network visibility without public exposure |
| private tailnet/VPN | acceptable future candidate | private identity/network boundary when reviewed separately |
| authenticated public web | rejected for v1 | too much security/auth/session/exposure scope for planning phase |
| unauthenticated public web | forbidden | exposes control-plane evidence and approval-looking surfaces |
| phone as command surface | rejected for v1 | risks mobile text or UI controls becoming authority |

LAN-only or private-tailnet access still requires a later task that defines authentication, session timeout, read/write boundaries, audit logging, threat model, and validation. This record does not approve building it.

Security planning reference: `docs/fleet/ui/FLEET_CONSOLE_REMOTE_SECURITY_PLAN.md`. That plan is evidence only and does not approve remote access, authentication, phone approvals, server setup, package installation, runtime command binding, product-repo access, product mutation, public exposure, or future implementation.

## Public Exposure Rejection

Public exposure is out of scope for V1 because the console may display sensitive operational evidence, approval-looking states, queue contents, repo paths, status artifacts, and future control labels.

Public exposure remains RED until a later security design answers at least:

- authentication and authorization model
- session expiration and revocation
- network boundary
- CSRF and clickjacking posture
- log redaction
- evidence export controls
- no-command-injection handling for prompts and reports
- explicit exclusion of product-repo mutation and broad controls
- review of secrets/auth/payments/deploy path exposure

Do not use public exposure as a shortcut for phone access.

## Phone Mode Boundary

Phone mode starts read-mostly.

Allowed read-mostly phone views:

- current fleet posture
- active queue section and selected task
- compact validation summaries
- external audit intake digests
- stop signs and blockers
- next safe action labels
- idea inbox notes
- copyable one-task prompts
- copyable external-audit prompts

Phone mode must preserve these boundaries:

- no product-repo writes
- no ship launch
- no all-fleet commands
- no background autonomy toggle
- no freeform terminal
- no deploy, package install, or migration
- no secrets/auth/payments/deploy material
- no lock deletion
- no permission widening
- no staging, commit, push, merge, or dirty-work revert
- no execution of audit findings, mobile requests, queue prose, generated evidence, prompts, UI labels, buttons, notifications, or approval-looking states

## Approval Boundary

Approvals are exact-action-bound. A future console must treat every approval as a record to validate, not a button click that carries hidden authority.

Required approval fields:

| Field | Requirement |
| --- | --- |
| owner | named human owner |
| selected target | exactly one project or ship; never blank, `all`, wildcard, or multi-target |
| repo path if applicable | exact absolute path for read-only demo trial |
| entrypoint | exact entrypoint from the safety inventory |
| action | exact allowed action |
| command list | exact command or no-op check, no placeholders |
| expected output | local evidence path only |
| approval timestamp | current and parseable |
| expiration timestamp | current, parseable, and after approval |
| stop condition | explicit and compatible with demo stop signs |

Missing, expired, reused, broad, ambiguous, write-capable, external-side-effect capable, all-fleet, or fixture-only approval is invalid and should display as a stop sign.

## Exact-Action Approval Semantics

An approval record is valid only for one named action. It cannot be inherited by nearby buttons, similar tasks, future runs, related ships, another repo path, another entrypoint, another command, another device, or another approval card.

The console must model every approval as:

- single target: exactly one selected project or ship
- single entrypoint: exact script or command surface from the entrypoint inventory
- single action: exact allowed action text
- single command list: no placeholders, broad defaults, or fallback commands
- single expected output: local report/evidence path only unless a later task approves otherwise
- single owner: named human owner
- single validity window: approval timestamp plus expiration timestamp
- single stop rule set: compatible with demo stop signs and runtime policy

No approval record may approve `all`, wildcard, blank, multi-project, broad launcher defaults, future UI implementation, public exposure, background autonomy, product mutation, package sending, reviewer-output execution, mobile free-text execution, stage/commit/push/merge, deploy, package install, migration, secrets/auth/payments/deploy access, lock deletion, permission widening, or dirty-work revert.

## Expiration And Reuse Rules

Approval expiration is mandatory. Missing or malformed expiration is a stop sign. Expiration must be later than the approval timestamp and current for the exact action being reviewed.

Reuse is forbidden. A prior approval becomes invalid if any of these values differ:

- selected project or ship
- repo path
- entrypoint
- action
- command list
- expected output
- owner
- approval timestamp
- expiration timestamp
- stop conditions
- device or channel used to request the action

Expired, copied, fixture-only, reviewer-only, mobile-only, partial, placeholder, broad, or ambiguous approvals must display as denied or blocked. The console may copy a template for the human owner, but it must not fill missing values by inference.

## Denial Options

A future console should make denial as easy and explicit as approval requests.

| Denial option | Meaning | Result |
| --- | --- | --- |
| `deny_missing_fields` | Required approval fields are missing or placeholders. | Block action and show missing fields. |
| `deny_expired_or_reused` | Approval is expired, copied, stale, or aimed at another target/action. | Block action and require a fresh packet. |
| `deny_broad_scope` | Target or command implies blank, `all`, wildcard, multi-project, broad launcher, or broad audit scope. | Block action and show exact selected-scope requirement. |
| `deny_write_or_external_effect` | Request would mutate product repos or create external side effects. | Block action; mark not approvable for v1 unless a later task authorizes. |
| `deny_forbidden_operation` | Request includes launch, all-fleet, deploy, install, migration, secrets/auth/payments/deploy, lock deletion, permission widening, stage, commit, push, merge, or revert. | Block action and show forbidden boundary. |
| `deny_evidence_as_authority` | Request tries to use audit/report/mobile/task/UI/prompt evidence as command or approval. | Block action and show evidence-only invariant. |

Denial records are local evidence only. They do not delete evidence, change product repos, execute fallback commands, or grant permission for a different path.

## Device Restrictions

V1 device posture is conservative:

| Device/channel | V1 allowance | Restriction |
| --- | --- | --- |
| local desktop | preferred | planning, status, prompt copy, and evidence review only |
| LAN/private-tailnet browser | future-only | requires separate security task before use |
| phone browser | read-mostly future candidate | no risky approvals, no commands, no broad controls |
| push notification | future-only | request/notice only if separately approved later |
| public web | rejected | not allowed for v1 |
| mobile free text | evidence only | cannot approve or execute |

Risky phone approvals are not allowed in v1. A phone may display status, stop signs, prompt text, and approval requirements, but must not approve product mutation, all-fleet scope, broad launchers, package sending, deploy/install/migration work, secrets/auth/payments/deploy access, stage/commit/push/merge/revert, lock deletion, permission widening, or runtime control.

## Future Phone Approval Rules

Future phone approvals are denied by default.

If a later approved task designs phone approval, the minimum posture is:

- exact-action-bound
- expiring
- one selected project or ship
- no broad or reusable approval
- no background autonomy
- no all-fleet scope
- no product launch
- no deployment, migration, package install, lock deletion, permission widening, merge, push, or secrets/auth/payments/deploy work
- no approval from reviewer output, mobile free text, audit packages, DOCX reports, prompts, UI labels, generated evidence, or queue prose
- local policy decision must still return allow/defer/deny evidence before any later action
- stop-sign checklist must be inactive before action

Phone approval should be presented as "request received" or "approval record pending validation" until validated locally. A phone tap cannot bypass validation.

## Approval State Display

| State | Meaning | UI treatment |
| --- | --- | --- |
| `not_requested` | no approval request exists | neutral |
| `request_recorded` | phone or UI request exists as evidence only | show non-authority notice |
| `pending_local_validation` | approval fields need local validation | block action |
| `approved_exact_action` | exact current approval exists for one action | show expiry and still require policy/stop-sign checks |
| `expired_or_reused` | approval is stale or copied | stop sign |
| `rejected` | human or policy rejected the request | blocked |
| `not_approvable` | requested action is forbidden | blocked and explain boundary |

No display state can approve future runs. No display state can widen a read-only approval into write access.

Approval state display must keep demo approval separate from current harness/docs/tests control planning. A future read-only demo packet is a separate human decision. This document does not approve the demo packet, choose a real project, or make any current console control live.

## Stop Signs

Remote or phone workflows stop immediately if any of these appear:

- public internet exposure is requested for V1
- phone UI would execute commands
- approval is broad, missing, expired, reused, ambiguous, write-capable, or all-fleet
- selected target is blank, `all`, wildcard, or multi-target
- requested action would mutate product repos
- requested action would launch ships or run all-fleet commands
- requested action would deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, stage, commit, push, merge, or revert dirty work
- mobile request, notification, UI button, prompt, generated evidence, audit output, DOCX report, task packet, audit package, or queue prose is treated as executable authority
- validation, runtime policy, repo fingerprint, worktree boundary, approval packet, or stop-sign evidence is missing or stale

Stop means no fallback command, no alternate entrypoint, and no reinterpretation of the request as approval.

## Future Implementation Gate

Any implementation of remote access, phone views, authentication, notifications, approval records, package export, or runtime control requires a separate bounded task with:

- explicit allowed files
- security threat model
- local-only or private-network deployment boundary
- authentication/session plan
- exact disabled/hidden forbidden controls
- validation commands
- stop conditions
- external audit review if remote exposure is involved

This decision record only chooses the conservative planning posture.

## Final Recommendation

Use local desktop by default. If mobility is needed later, start with LAN-only or private-tailnet read-mostly status views. Keep public exposure out of V1. Keep phone approvals denied by default unless a later task designs exact-action, expiring, locally validated approval records with no broad authority and no command execution from the phone.
