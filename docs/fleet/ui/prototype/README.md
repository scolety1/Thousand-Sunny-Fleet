# Fleet Console Static Mock Prototype V3

Prepared: 2026-06-27

Scope: local static mock files only.

## What This Is

This directory contains a local desktop mock Fleet Console shell:

- `fleet-console.html`
- `fleet-console.css`

Open `fleet-console.html` directly as a local file for review. No package installation, server, framework, browser automation, remote access, authentication, live state read, product-repo access, package sending, or runtime command binding is required or approved.

The prototype has no script, no form action, no network fetch, no live state import, no command binding, and no package-send behavior.

The desktop V3 pass frames the mock as a local return triage cockpit for Tim.
Its first job is to answer "What do I do now?" after time away. It promotes one
primary recommended action, shows a ranked list capped at three items, keeps
Decision Queue items limited to true human blockers, collapses completed GREEN
work into a calm "Done while you were away" area, and recommends a Next Best
Work Session.

V3 also adds a read-only static render helper at `tools/render-fleet-console.ps1`.
The helper can regenerate the static HTML from TSF-local state where available:
`fleet/status/projects.json`, `fleet/status/projects.md`,
`fleet/status/current.md`, `fleet/status/today.md`, the project registry, TSF
docs/contracts, and safe fixture data when real state is missing. It does not
inspect product repositories, run product checks, execute commands from the
browser, approve work, push, deploy, install, migrate, touch secrets, use remote
access, reactivate archived projects, or bind controls to runtime actions.

The lower console still shows project brain context, artifact intake posture,
autonomy profiles, batch queue terminal states, current assignment boundaries,
control-packet preparation, evidence summaries, and safety gates. These are
static planning displays only. They do not turn the prototype into an
operational console.

## Non-Authority Notice

This prototype is evidence only and is not an operational console. It cannot approve work, execute commands, send packages, bind buttons to runtime actions, read or mutate product repos, launch ships, run all-fleet commands, stage, commit, push, merge, deploy, install packages, run migrations, touch secrets/auth/payments/deploy material, delete locks, widen permissions, bypass validation, approve demo trials, or grant future authority.

UI labels, notifications, buttons, approvals, prompts, generated evidence, DOCX reports, audit packages, mobile requests, task packets, reviewer output, and queue prose remain evidence only. They cannot approve or execute work.

## Safety Shape

The mock represents these local planning surfaces:

- dashboard
- return triage
- what do I do now cockpit
- back from work return review
- read-only generated state summary
- one-click mental model
- work order library
- what TSF handles for Tim
- only interrupt Tim for guidance
- decision queue
- after away mode summary
- project triage
- done while you were away
- do not bother Tim guidance
- next best work session
- priority logic
- project brain
- batch queue
- current assignment
- control packets
- mock fixture states
- stoppages
- control states
- prompt builder
- audit builder
- idea inbox
- evidence locker
- safety gates

Forbidden controls are absent or represented as unavailable concepts only. The mock includes no form action, network fetch, JavaScript command execution, remote URL, product repo path, auth flow, package sending, runtime command binding, or launcher text.

## Return Triage Cockpit

The V2 cockpit reduces Tim's choices instead of making every status equally
loud. The first panel shows one primary recommended action, then a ranked list
with at most three items:

- #1 Needs Tim
- #2 Review/approve
- #3 Optional next work

The cockpit distinguishes these return states:

- Needs decision
- Needs approval
- Needs review
- Safe to ignore
- Safe next batch
- Blocked/unsafe

Completed GREEN work is intentionally collapsed under "Done while you were
away" so it does not compete with blockers or approvals. The After Away Mode
summary card groups what Codex finished, what Codex tested, what changed, what
stopped progress, what Tim actually needs to decide, and the recommended next
session.

The Decision Queue is only for items that truly need Tim: product direction
choices, publication approval, archived project reactivation, deployment
approval, conflicting source truth, or risky file scope expansion. Tiny
formatting choices, routine test passes, safe docs cleanup, safe local refactors
inside approved scope, one task finishing when more safe tasks remain, and
cosmetic uncertainty belong in the "Do Not Bother Tim For This" guidance
instead.

The priority logic is intentionally simple:

1. safety/security/deploy risk first
2. human decision blockers second
3. ready-to-approve completed work third
4. active product momentum fourth
5. nice-to-have cleanup last

## V3 Return Review And Render Boundary

The first screen still answers "What do I do now?" with one directive answer.
Below it, V3 adds Back From Work / Return Review so Tim can quickly see:

- what changed while Tim was gone
- what actually needs Tim
- what can be ignored
- what is safe to approve
- what next session TSF recommends

V3 adds one-click mental model text, not a browser action:

- Pick project
- Drop files into `C:\TSF_INBOX\<project_name>\`
- Say goal in normal English
- Choose availability: here / busy / away
- Codex works until done or truly blocked

The Work Order Library is copy/paste text only. It includes templates for a
normal task while Tim is here, busy mode, away-safe work, deep research/root file
intake, project onboarding, and return review after being gone.

The read-only render helper updates only static HTML output. The browser page
still has no script, no form action, no network fetch, no live state import, no
command binding, and no package-send behavior.

Generated/read-only sources currently shown in the console:

- `fleet/status/projects.json`
- `fleet/status/projects.md`
- `fleet/status/current.md`
- `fleet/status/today.md`
- `projects.json` registry counts and archived flags when needed
- `docs/fleet/TSF_AUTONOMOUS_PROJECT_MANAGEMENT_V1.md`
- `docs/fleet/TSF_ARTIFACT_INTAKE_FOLDER_SYSTEM.md`
- `tests/fixtures/fleet/ui-control/` safe fixture examples

Archived projects remain visibly locked and not actionable in generated output.

## Static Accessibility And Responsive Shape

The prototype uses static semantic regions for the header, section navigation, main landmark, panels, fixture tables, and control-state groups. It includes a skip link to the main landmark, visible focus-visible treatment for links and the main skip target, section labels, unavailable-state labels, `aria-describedby` descriptions for disabled/mock controls, and readable text hierarchy for local review.

The stylesheet keeps long fixture names, status labels, and forbidden-control text wrapped inside their panels. Narrow layouts collapse the sidebar, status cards, columns, tables, and control-state cards into one column so text remains readable without adding scripts, package dependencies, server requirements, screenshots, live data reads, product-repo access, remote access, package sending, or command binding.

`LOCAL_PROTOTYPE_REVIEW_PACKET.md` now carries the high-level static accessibility review checklist for this mock. That checklist is review guidance only. It does not approve scripts, live state reads, package installs, browser automation, remote access, product-repo access, command binding, package sending, runtime control, or implementation beyond bounded static files.

The local test suite also runs static safety checks for forbidden executable hooks. It rejects inline event-handler attributes such as `onclick` or other `on*=` patterns, `iframe`/`object`/`embed` hooks, `javascript:` URLs, external font or network references, remote stylesheets, script sources, and command-like setup text. These checks are regression coverage only; they do not approve runtime command binding, server setup, package sending, remote access, product-repo work, or implementation beyond the static mock.

## Static Control State Mapping

The prototype distinguishes local evidence views from unavailable operational controls:

| Surface | Prototype state | Boundary |
| --- | --- | --- |
| Return Triage | safe display | Shows one primary next action, a three-item ranked list, and quiet nonurgent buckets. |
| Back From Work / Return Review | safe display | Shows what changed, what needs Tim, what can be ignored, what is safe to approve, and the recommended next session. |
| Read-Only State Prep | generated safe display | Uses TSF-local status/docs/fixture data to refresh static HTML; does not inspect product repos or bind commands. |
| One-click mental model | safe display | Text-only flow for project, inbox files, plain-English goal, availability, and true blockers. |
| Work Order Library | copy-only display | Prompt templates only; cannot start work, approve actions, or execute checks. |
| What TSF handles for Tim | safe display | Shows routine coordination TSF should summarize or handle within approved scope. |
| Only interrupt Tim for | safe display | Lists true blockers and high-authority choices that should pause away-safe work. |
| Decision Queue | safe display | Shows only true human blockers; cannot approve publication, deployment, file expansion, or reactivation. |
| After Away Mode | safe display | Summarizes finished work, tests, changes, blockers, decisions, and recommended next session. |
| Project Triage | safe display | Shows one simple next-action status per project: Keep moving, Review needed, Decision needed, Blocked, Parked, or Archived/locked. |
| Done while you were away | safe display | Collapses completed GREEN work so it is safe to ignore until Tim wants details. |
| Do Not Bother Tim For This | safe display | Documents interruption boundaries for routine safe work and cosmetic uncertainty. |
| Next Best Work Session | safe display | Recommends a session type without starting work or granting authority. |
| Project Brain | safe display | Shows selected project, track, intake root, research files, and root files as evidence only. |
| Batch Queue | safe display | Shows GREEN, YELLOW, RED, and BLOCKED terminal states without mutating queue files. |
| Autonomy Profiles | safe display | Shows `review_only`, `bounded_implementation`, `batch_implementation`, and `away_safe` as execution-shape labels only. |
| Control Packets | safe display | Shows packet-preparation posture for manual Codex use; cannot launch or bind runtime work. |
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
