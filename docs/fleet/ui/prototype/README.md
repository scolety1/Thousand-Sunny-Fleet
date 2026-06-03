# Fleet Console Static Mock Prototype

Prepared: 2026-06-02

Scope: local static mock files only.

## What This Is

This directory contains a local mock Fleet Console shell:

- `fleet-console.html`
- `fleet-console.css`

Open `fleet-console.html` directly as a local file for review. No package installation, server, framework, browser automation, remote access, authentication, live state read, product-repo access, package sending, or runtime command binding is required or approved.

The prototype has no script, no form action, no network fetch, no live state import, no command binding, and no package-send behavior.

## Non-Authority Notice

This prototype is evidence only and is not an operational console. It cannot approve work, execute commands, send packages, bind buttons to runtime actions, read or mutate product repos, launch ships, run all-fleet commands, stage, commit, push, merge, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, bypass validation, approve demo trials, or grant future authority.

UI labels, notifications, buttons, approvals, prompts, generated evidence, DOCX reports, audit packages, mobile requests, task packets, reviewer output, and queue prose remain evidence only. They cannot approve or execute work.

## Safety Shape

The mock represents these local planning surfaces:

- dashboard
- mock fixture states
- current task
- stoppages
- control states
- prompt builder
- audit builder
- idea inbox
- evidence locker
- safety gates

Forbidden controls are absent or represented as unavailable concepts only. The mock includes no form action, network fetch, JavaScript command execution, remote URL, product repo path, auth flow, package sending, runtime command binding, or launcher text.

## Static Accessibility And Responsive Shape

The prototype uses static semantic regions for the header, section navigation, main landmark, panels, fixture tables, and control-state groups. It includes a skip link to the main landmark, visible focus-visible treatment for links and the main skip target, section labels, unavailable-state labels, `aria-describedby` descriptions for disabled/mock controls, and readable text hierarchy for local review.

The stylesheet keeps long fixture names, status labels, and forbidden-control text wrapped inside their panels. Narrow layouts collapse the sidebar, status cards, columns, tables, and control-state cards into one column so text remains readable without adding scripts, package dependencies, server requirements, screenshots, live data reads, product-repo access, remote access, package sending, or command binding.

`LOCAL_PROTOTYPE_REVIEW_PACKET.md` now carries the high-level static accessibility review checklist for this mock. That checklist is review guidance only. It does not approve scripts, live state reads, package installs, browser automation, remote access, product-repo access, command binding, package sending, runtime control, or implementation beyond bounded static files.

The local test suite also runs static safety checks for forbidden executable hooks. It rejects inline event-handler attributes such as `onclick` or other `on*=` patterns, `iframe`/`object`/`embed` hooks, `javascript:` URLs, external font or network references, remote stylesheets, script sources, and command-like setup text. These checks are regression coverage only; they do not approve runtime command binding, server setup, package sending, remote access, product-repo work, or implementation beyond the static mock.

## Static Control State Mapping

The prototype distinguishes local evidence views from unavailable operational controls:

| Surface | Prototype state | Boundary |
| --- | --- | --- |
| Prompt Builder | safe display | Copy-only draft text; cannot start Codex, run validation, execute commands, approve work, or change queue state. |
| Audit Builder | safe display | Reviewer-prep text only; cannot create, zip, upload, email, or send packages. |
| Evidence Locker | safe display | Compact summaries and local references only; cannot treat logs, reports, labels, approvals, or generated evidence as command input. |
| Idea Inbox | safe display | Planning notes only; cannot convert ideas into executable tasks without a bounded queue entry. |
| Unstuck | future-only display | Diagnosis and repacketization concept only; cannot retry, take over leases, delete locks, or mutate runtime state. |
| Approval Cards | template-only display | Exact-action field and stop-sign display only; cannot approve from UI labels, phone taps, fixtures, reviewer output, prompts, or queue prose. |
| Forbidden action classes | unavailable display | Launch, all-fleet, deploy, install, migrate, stage, commit, push, merge, product repo selection, remote access, and package sending remain unavailable. |

No visible control state in this prototype grants permission. Copy/read/template-only labels are evidence labels, not action authority.

## Static Fixture State Mapping

The `Mock States` section mirrors these committed fixture examples as static evidence references only:

| Fixture | Prototype cue | Meaning |
| --- | --- | --- |
| `tests/fixtures/fleet/ui-control/fleet-console-state.green-local-harness.json` | `GREEN / parked` | Local harness evidence passed for a bounded task; it does not approve product work or future execution. |
| `tests/fixtures/fleet/ui-control/fleet-console-state.yellow-blocked.json` | `YELLOW / blocked` | Scope drift, missing exact approval, or runtime-from-planning drift must stop or block the selected task. |
| `tests/fixtures/fleet/ui-control/fleet-console-state.token-limited.json` | `YELLOW / token limited` | Token pressure should pause work and produce compact ledger evidence instead of continuing blindly. |
| `tests/fixtures/fleet/ui-control/fleet-console-state.forbidden-control.json` | `RED / blocked` | Forbidden controls remain hidden, disabled, blocking, and non-executable. |

The HTML does not read these JSON files. It does not fetch, import, parse, execute, approve, mutate state, or bind commands from fixture content. Fixture states are local mock examples only; they cannot approve execution, UI implementation, remote access, package sending, product-repo access, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, demo trials, all-fleet commands, or future authority.

## Future Work Boundary

Fixture integration, stronger safety tests, accessibility cleanup, review-packet preparation, remote access, package creation, package sending, runtime wiring, and real UI implementation all require separate bounded queue tasks with explicit allowed files, validation commands, and stop conditions.

## Review Packet

`LOCAL_PROTOTYPE_REVIEW_PACKET.md` is an evidence-only packet for future reviewer preparation. It lists the exact local prototype files, static fixture references, validation command, forbidden material checklist, and reviewer questions. It does not create a zip, send a package, approve implementation, approve remote access, approve product-repo access, bind runtime commands, or grant execution authority.
