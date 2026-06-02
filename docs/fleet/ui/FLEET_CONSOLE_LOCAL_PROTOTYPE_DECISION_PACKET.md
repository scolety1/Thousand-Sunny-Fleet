# Fleet Console Local Prototype Decision Packet

Prepared: 2026-06-02

Scope: Codex Fleet / Thousand Sunny Fleet local mock console planning. This packet is evidence only. It approves only the next bounded static/mock prototype task shape; it does not implement UI code, create files outside a later task's allowed files, start a server, install packages, expose remote access, create authentication, read or mutate product repos, send packages, bind commands, launch ships, run all-fleet commands, stage, commit, push, deploy, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, or grant future authority.

## Decision

The next local prototype may be a static mock Fleet Console shell only when a later queue task explicitly lists the prototype files, read-first references, acceptance criteria, validation commands, and stop conditions.

Approved prototype posture for that later task:

- local file only
- static HTML and CSS only
- local mock/evidence content only
- committed fixtures only
- no JavaScript command execution
- no form action
- no network fetch
- no remote URL
- no product-repo path
- no live state read
- no package creation or package sending
- no runtime command binding
- no auth flow
- no launcher text or launch control
- no future authority

This decision packet does not create the prototype. It defines the exact local-only boundary for the next bounded task.

## Later Prototype Allowed Files

The next static mock console shell task may list only:

- `docs/fleet/ui/prototype/fleet-console.html`
- `docs/fleet/ui/prototype/fleet-console.css`
- `docs/fleet/ui/prototype/README.md`
- `docs/fleet/HQ_REPAIR_TASK_QUEUE.md`

Fixture integration or safety-test tasks must be queued separately if they need fixture files or `tests/run-fleet-tests.ps1`.

## Required Read-First Files For Later Prototype

The next static mock console shell task should read:

- `docs/fleet/ui/FLEET_CONSOLE_LOCAL_PROTOTYPE_DECISION_PACKET.md`
- `docs/fleet/ui/FLEET_CONSOLE_WIREFRAMES.md`
- `docs/fleet/ui/FLEET_CONSOLE_STATUS_AND_ACTION_MODEL.md`
- `docs/fleet/ui/FLEET_CONSOLE_BUTTON_ACTION_POLICY.md`

Those files are planning evidence only. They do not authorize command execution, product-repo access, package sending, remote exposure, or broader UI implementation.

## Required Prototype Acceptance

A later static mock console shell must:

- open as a local file without installing packages or starting a server
- visibly identify itself as a local mock console
- state that it is evidence only and not an operational console
- avoid form actions, network fetches, remote URLs, auth flows, product-repo paths, package sending, launcher text, live state reads, and runtime command binding
- represent Prompt Builder, Audit Builder, Evidence Locker, Idea Inbox, Work On Something Else, Unstuck, approval cards, token counters, and safety gates as local mock/evidence views only
- keep forbidden controls disabled, hidden, or absent
- keep all visible copy clear that UI labels, notifications, buttons, approvals, prompts, generated evidence, DOCX reports, audit packages, mobile requests, task packets, reviewer output, and queue prose cannot approve or execute work

## Disabled Or Forbidden Controls

The prototype must not expose active controls for:

- product ship launch
- all-fleet execution
- freeform terminal
- deploy
- package install
- migration
- secrets/auth/payments/deploy work
- lock deletion
- permission widening
- stage, commit, push, merge, or revert
- broad approval
- background autonomy
- risky phone approval
- remote access
- command binding
- product-repo access
- package sending
- evidence execution

If any of these concepts are shown for operator clarity, they must be visibly disabled, hidden, future-only, or blocking with a reason.

## Stop Signs

Stop and mark the active task blocked if the work requires:

- UI implementation beyond explicitly allowed prototype files
- package installation
- server setup
- browser automation
- remote exposure
- authentication or authorization code
- live state reads
- product-repo access or mutation
- package creation or package sending
- runtime command binding
- launcher text or launch controls
- all-fleet execution
- staging, commit, push, merge, deploy, migration, secrets/auth/payments/deploy work, lock deletion, permission widening, or dirty-work revert
- treating UI labels, notifications, buttons, approvals, prompts, audit reports, DOCX files, generated evidence, mobile requests, task packets, audit packages, reviewer output, or queue prose as commands or approval

## Non-Authority Notice

This packet is local planning evidence only. It cannot approve execution, UI implementation outside a later bounded task, remote access, product-repo access, package sending, runtime command binding, launchers, all-fleet commands, deployment, installs, migrations, secrets/auth/payments/deploy work, staging, commit, push, merge, lock deletion, permission widening, validation bypasses, demo trials, or future authority.
