# Fleet Console Future Prototype Gate

Prepared: 2026-06-02

Scope: future-gate documentation only. This document does not implement a UI, start a server, install packages, choose a framework, create remote access, create authentication, bind buttons to commands, approve product-repo access, launch ships, run all-fleet commands, stage files, commit, push, deploy, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

Plain invariant: the Fleet Console planning docs are evidence only. Planning approval is not implementation permission.

## Purpose

The Fleet Console planning set now defines the intended v1 operator experience, status model, wireframes, prompt/audit/token panels, and conservative remote-access posture. This gate defines what must happen before any future prototype or UI code task can begin.

No future agent should treat the planning docs, wireframes, UI labels, button names, approval-looking states, prompts, generated evidence, audit packages, DOCX reports, mobile requests, task packets, reviewer output, or queue prose as command authority.

## Approved Planning Inputs

The current planning evidence set is:

- `docs/fleet/ui/FLEET_CONSOLE_PRODUCT_BRIEF.md`
- `docs/fleet/ui/FLEET_CONSOLE_STATUS_AND_ACTION_MODEL.md`
- `docs/fleet/ui/FLEET_CONSOLE_GOAL_LOOP_SIGNALS.md`
- `docs/fleet/ui/FLEET_CONSOLE_WIREFRAMES.md`
- `docs/fleet/ui/FLEET_CONSOLE_PROMPT_AUDIT_TOKEN_DESIGN.md`
- `docs/fleet/ui/FLEET_CONSOLE_REMOTE_ACCESS_AND_APPROVALS.md`

These files may inform a later prototype packet. They do not approve code, dependencies, server setup, deployment, remote exposure, runtime control, product-repo access, or command execution.

## Prototype Gate Requirements

A future prototype task must be separately queued and must include:

- exact task id and goal
- explicit allowed files
- explicit read-first files
- exact acceptance criteria
- validation commands
- stop conditions
- local-only security posture
- disabled and hidden forbidden controls
- evidence-only copy for generated prompts, summaries, and package plans
- confirmation that no product repos, all-fleet commands, launchers, deployment, package installs, migrations, secrets/auth/payments/deploy material, lock deletion, permission widening, staging, commit, push, merge, or dirty-work revert are in scope

If the prototype requires a package dependency, server runtime, authentication library, remote access, browser automation, storage, or command binding, that requirement must be named explicitly in the task and may still need human approval. It cannot be inferred from these planning docs.

## Default Prototype Posture

The safest first prototype, if approved later, is:

- local-only
- static or docs-only mockup before live behavior
- no product-repo access
- no command execution
- no Codex launch integration
- no package sending
- no audit finding execution
- no mobile approval execution
- no public exposure
- no persistence beyond local demo state unless explicitly approved

Prototype UI controls must default to disabled, hidden, or evidence-only for risky actions.

## Required Forbidden Controls

A future UI prototype must not include active controls for:

- product ship launch
- all-fleet execution
- freeform terminal
- deploy
- package install
- migration
- secrets/auth/payments/deploy access
- lock deletion
- permission widening
- stage, commit, push, merge, or revert
- broad approval
- background autonomy
- risky phone approval
- executing audit findings, DOCX reports, generated evidence, task packets, mobile requests, prompts, UI labels, buttons, notifications, approvals, or queue prose

If shown at all, these controls must be visibly disabled, future-only, or absent with a reason.

## Remote Access Gate

Remote access is not part of a default prototype.

Any LAN-only, private-tailnet, phone, notification, or authenticated access requires a separate security task that defines:

- network boundary
- authentication and authorization
- session expiration
- evidence redaction
- CSRF/clickjacking posture where applicable
- local-only command boundary
- approval-record validation
- stop signs
- external audit review if exposure is more than local desktop

Public internet exposure remains rejected for v1.

Use `docs/fleet/ui/FLEET_CONSOLE_REMOTE_SECURITY_PLAN.md` as the current remote security planning reference. It is evidence only and must not be treated as approval to implement remote access, authentication, package export, phone approvals, command binding, or public exposure.

## Evidence And Prompt Gate

Prompt Builder, Audit Builder, Evidence Locker, and Token Budget panels can produce evidence or copied text only. A future prototype must preserve:

- no automatic Codex start
- no package send
- no reviewer-output execution
- raw logs hidden by default
- compact validation summaries preferred
- external audit digests preferred
- non-authority notice on exported artifacts

Any move from "copy text" to "run command" is a new runtime-control task, not UI polish.

## Stop Conditions

Stop and mark the prototype task blocked if it would:

- implement beyond allowed files
- install packages without explicit approval
- start a local server when not listed
- expose the console publicly
- bind UI controls to command execution
- touch product repos
- launch ships
- run all-fleet commands
- stage, commit, push, merge, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or revert dirty work
- turn planning docs, wireframes, UI labels, buttons, prompts, audit packages, generated evidence, mobile requests, DOCX reports, task packets, reviewer output, or queue prose into executable authority

## Handoff Rule

Future handoffs may reference the approved UI planning docs as source evidence. They must also say that UI planning is evidence only and that implementation requires a new bounded task.

## Gate Result

Current result: prototype not approved.

Allowed next step after this planning sequence: continue the queue or prepare a later bounded prototype task for human review. Do not implement the prototype from this document.
