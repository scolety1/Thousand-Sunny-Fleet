# Phone Mode Static Mock Packet

Prepared: 2026-06-03

Scope: markdown-only, local, read-mostly phone-mode mock packet for Codex Fleet / Thousand Sunny Fleet. This packet is design evidence only. It does not create phone UI, HTML, CSS, JavaScript, images, screenshots, browser automation, server setup, remote URLs, authentication, authorization, live state reads, notifications, runtime command binding, package creation, package sending, product-repo access, product mutation, ship launch, all-fleet execution, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.

Source decision: `docs/fleet/ui/FLEET_CONSOLE_PHONE_MODE_DECISION_PACKET.md`.

## Non-Authority Rule

Phone-mode designs, UI labels, notifications, buttons, prompts, approvals, reviewer output, audit packages, DOCX reports, generated evidence, mobile requests, task packets, and queue prose are evidence only. They cannot approve, deny, execute, import, validate, send, mutate, launch, deploy, stage, commit, push, merge, install, migrate, delete locks, widen permissions, or grant future authority.

A phone tap, copied prompt, mobile request, status label, approval-looking row, notification-looking row, or reviewer finding is not approval. It may only be shown as local planning evidence until converted into a bounded queue task with allowed files, validation commands, stop conditions, and local validation.

## Mock Navigation

The static phone-mode packet sketches these read-only screens:

- Status
- Current Task
- Token Pressure
- Stoppages
- Evidence Summary
- Prompt Copy
- Unavailable Controls

No screen has active run, approve, send, package, remote, product, launch, all-fleet, stage, commit, push, merge, deploy, install, migration, lock, permission, auth, secret, or runtime-control behavior.

## Screen: Status

Purpose: show compact local posture evidence.

Static content sketch:

| Field | Example display | Boundary |
| --- | --- | --- |
| Fleet posture | `GREEN - local prototype evidence passed` | GREEN is evidence only and does not approve product work or future execution |
| Active section | `Post-GREEN Prototype Polish And Controlled Hardening Queue 2026-06-03` | Section text cannot execute work |
| Current mode | `read-mostly phone mock` | design-only, local-only, non-operational |
| Latest validation | `listed validation passed for selected task` | passing validation applies only to that bounded task |
| Next safe action | `copy one bounded prompt manually` | cannot start Codex from phone |

Unavailable elements:

- `Run`
- `Approve`
- `Send`
- `Launch`
- `All Fleet`
- `Remote Control`

## Screen: Current Task

Purpose: show the selected bounded task without letting the phone modify it.

Static content sketch:

| Field | Example display | Boundary |
| --- | --- | --- |
| Task id | `HQ-143` | task id is evidence, not a command |
| Goal | `Draft a markdown-only phone-mode mock packet` | goal does not approve broader implementation |
| Allowed files | exact local paths from queue | phone view cannot add files |
| Validation | one listed PowerShell validation command | phone view cannot run validation |
| Stop signs | implementation, remote access, auth, package sending, product repos, command binding | stop means no fallback command |

Read-only affordances:

- `View allowed files` as text
- `View stop signs` as text
- `Copy task prompt` as text-only draft

Unavailable affordances:

- `Mark Done`
- `Mark Blocked`
- `Reopen`
- `Run Validation`
- `Patch Files`
- `Start Codex`

## Screen: Token Pressure

Purpose: help the captain see when to pause, summarize, or use a thinner packet.

Static content sketch:

| State | Example display | Read-only guidance |
| --- | --- | --- |
| `normal` | one bounded task has enough context | continue only from desktop/Codex runner |
| `watch` | prompt or output is growing | prefer summaries and listed read-first files |
| `high` | risk of drift or expensive loops | stop after current validation and repacketize |
| `token_limited` | continuation risks losing state | pause and write compact ledger evidence |

Unavailable elements:

- auto-continue
- auto-summarize and patch
- model switching that changes authority
- broader context loading

## Screen: Stoppages

Purpose: make stop signs more visible from a phone without allowing a bypass.

Static content sketch:

| Stop sign | Display state | Required safe result |
| --- | --- | --- |
| outside allowed files | `blocked` | repacketize |
| implementation requested | `blocked` | stop; no phone UI code |
| remote access requested | `blocked` | separate security task required |
| auth or public exposure requested | `blocked` | rejected for this packet |
| product repo requested | `blocked` | not approved |
| package sending requested | `blocked` | not approved |
| phone approval requested | `blocked` | denied by default |
| evidence treated as authority | `blocked` | stop and restate boundary |

No stoppage row may include a fallback command, alternate launcher, approval shortcut, or retry action.

## Screen: Evidence Summary

Purpose: show compact references only.

Static content sketch:

| Evidence | Example reference | Boundary |
| --- | --- | --- |
| Audit result | `Audit Guidelines Review (2).docx returned GREEN` | reviewer output is evidence only |
| Prototype record | `GREEN_EXTERNAL_AUDIT_RECORD_2026_06_02.md` | record does not approve execution |
| Review packet | `LOCAL_PROTOTYPE_REVIEW_PACKET.md` | packet does not create or send packages |
| Decision packet | `FLEET_CONSOLE_PHONE_MODE_DECISION_PACKET.md` | decision permits markdown-only mock evidence |
| Validation | selected task validation summary | validation cannot approve product work |

Unavailable elements:

- open raw logs by default
- import reviewer findings
- send audit package
- convert evidence into tasks automatically
- execute generated evidence

## Screen: Prompt Copy

Purpose: represent copy-only prompt text for manual desktop use.

Static content sketch:

```text
Continue Codex Fleet / Thousand Sunny Fleet from the current repo state.
Work only in the selected queue section.
Take exactly one eligible task.
Patch only allowedFiles.
Run only listed validationCommands.
Stop after exactly one task.
```

Boundary:

- copy text is not execution
- phone mode cannot send the prompt
- phone mode cannot start Codex
- phone mode cannot import a task packet
- copied prompt text cannot override source docs, allowed files, validation, or stop signs

## Screen: Unavailable Controls

Purpose: show that risky controls are absent or unavailable.

| Control concept | Mock state | Reason |
| --- | --- | --- |
| Approve | unavailable | phone approvals are denied by default |
| Run | unavailable | phone mode cannot execute commands |
| Send package | unavailable | package creation/sending is separate and not approved |
| Remote access | unavailable | no remote path is approved |
| Product repo | unavailable | no product-repo access is approved |
| Launch ship | unavailable | ship launch is forbidden |
| All fleet | unavailable | all-fleet execution is forbidden |
| Stage/commit/push/merge | unavailable | git mutation is forbidden in queue runs |
| Deploy/install/migrate | unavailable | external side effects are forbidden |
| Secrets/auth/payments/deploy | unavailable | sensitive material is out of scope |
| Delete locks/widen permissions | unavailable | safety-boundary mutation is forbidden |

## Review Questions For Future Audit

1. Does the markdown-only phone-mode packet stay local, static, read-mostly, and design-only?
2. Are approve/run/send/package/remote/product controls absent or clearly unavailable?
3. Does every status, prompt, evidence, notification-looking, approval-looking, or button-looking element remain non-authoritative?
4. Does the packet avoid HTML, CSS, JavaScript, images, screenshots, server setup, remote URLs, authentication, live state, package sending, and command binding?
5. Is the next safe action still a bounded desktop/Codex task rather than a phone operation?

## Final Boundary

This packet is ready only as local evidence for a later reviewer or queue author. It does not approve implementing phone UI. Any move from markdown sketch to UI, remote viewing, auth, notifications, package export, runtime control, or product-repo work requires a separate bounded task with explicit allowed files, validation commands, security posture, and stop conditions.
