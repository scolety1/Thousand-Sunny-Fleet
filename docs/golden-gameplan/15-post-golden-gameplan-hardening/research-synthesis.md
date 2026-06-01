# Stage 15 Research Synthesis

## Summary

The five deep-research reports agree on one operating principle: Codex Fleet
should become more autonomous by becoming more bounded, more evidence-driven,
and more selective about what appears on first screens.

This document converts those reports into durable fleet rules. It is planning
documentation only; it does not implement runtime behavior.

## Durable Fleet Laws

| Law | Meaning | Primary Owner |
|---|---|---|
| Workflow outer loop, agent inner loop | The deterministic harness owns state, retries, budget, approvals, evidence, and stopping. The coding model works only inside bounded tasks. | Stage 8, Stage 10, Stage 14, Stage 15 |
| Phone approves a server-generated plan, never a raw command | Mobile requests create structured records. The PC validates and generates plans before approval. | Stage 13, Stage 15 |
| Promise -> Proof -> Path | Product demos need one audience, one outcome, one proof artifact, and one next action before showing deeper surfaces. | Stage 7, Stage 11, Stage 15 |
| Manager tools use a shift cockpit | Manager-facing restaurant tools open on current shift context, exceptions, approvals, live operations, and actions. | Stage 11, Stage 15 |
| Hospitality sites borrow structure, not authored identity | Restaurant/customer websites may use reference patterns but must not copy brand identity, wording, layouts, or signature concepts. | Stage 11, Stage 15 |
| Trust artifacts and histories, not prose summaries | Audits and resumes depend on task packets, diffs, tests, logs, state, approvals, budgets, and evidence packages. | Stage 2, Stage 3, Stage 14, Stage 15 |

## Research-To-Rule Mapping

| Source report | Core takeaway | Durable fleet rule | Target docs or stage | Priority |
|---|---|---|---|---:|
| Manager/internal restaurant tools | The calmest tools start with the current shift, approvals, exceptions, and actionable cards. | Build a shift cockpit, not a blank analytics dashboard. | `docs/templates/product-quality/lane-profiles/manager-internal-restaurant-tool.md` | P0 |
| Hospitality customer websites | Great restaurant sites use mood first, then reservations/menu/hours/location, then story and secondary actions. | Use restrained hospitality archetypes and progressive disclosure. Borrow structure, not authored identity. | `docs/templates/product-quality/lane-profiles/hospitality-customer-website.md` | P0 |
| Mobile command and remote operations | Phones are strong for status, triage, approvals, rejection, idea intake, alerts, and recovery; not arbitrary execution. | Phone commands create requests. Phone approves a server-generated plan only after local validation. | `docs/golden-gameplan/13-mobile-captain-console/` | P0 |
| Product demo quality | Strong demos prove a promise quickly instead of dumping every feature. | Apply Promise -> Proof -> Path and primary/secondary/tertiary content layers to visible product work. | `docs/templates/product-quality/` | P0 |
| Bounded autonomy and audit loops | Reliable autonomy uses a workflow outer loop, artifact handoffs, evidence packages, leases, heartbeats, and budget-aware scheduling. | The agent never owns the outer loop; trust artifacts and histories, not prose summaries. | Stage 8, Stage 10, Stage 14, Stage 15 docs/tests | P0 |

## Product Quality Rules

Every visible product task should define:

- audience
- high-value outcome
- first-screen promise
- representative proof artifact
- primary CTA
- primary, secondary, and tertiary content layers
- mobile baseline
- done-enough condition
- taste-gate condition

The first screen should answer:

```text
What is this?
Who is it for?
What can I do next?
```

Reject product tasks that try to prove value by exposing every module, setting,
chart, menu item, or feature on the first screen.

## Hospitality Customer Website Rules

Customer-facing hospitality websites should use one of a small set of reusable
archetypes:

- quiet luxury tasting menu
- warm neighborhood bistro
- cocktail-bar theatrical
- wine-led editorial
- hotel-dining premium
- minimal cafe/location-first

The first screen should include:

- venue name as a clear first-viewport signal
- one emotional promise
- one primary action
- short top navigation
- immediate access to menu, reservations, hours, and location
- a clear hint that more content exists below

Story, private dining, gift cards, shop, press, newsletters, and deep menu
detail belong after the core customer tasks are solved.

## Manager/Internal Restaurant Tool Rules

Manager-facing restaurant tools should use a shift cockpit pattern.

Show first:

- location, date, and service period
- one shift pulse visual or metric
- attention queue for approvals and exceptions
- staffing, floor/service, order channel, stock, and task/log cards
- in-place actions for urgent items

Hide deeper:

- payroll exports
- permissions
- historical BI
- accounting
- integrations
- setup/configuration
- long reports

An alert should be actionable. A passive warning card that cannot be resolved,
assigned, snoozed, drilled into, or documented should be treated as incomplete.

## Mobile Captain Rules

Phone commands should use a small vocabulary:

- `status`
- `why`
- `submit idea`
- `approve plan`
- `reject plan`
- `resume safe`
- `audit package`
- `mute` or `snooze` notifications

Never allow phone requests to become:

- arbitrary shell
- raw command execution
- recursive delete/reset
- secret reveal or rotation
- policy bypass
- self-approval of high-risk actions
- blind replay after reset
- destructive swipe gestures

The mobile home view should start with:

```text
Running
Blocked
Needs Approval
Budget
Incidents
```

Approval cards should show a generated plan with scope, ship, action, risk,
evidence summary, budget impact, rollback path, expiration, and approve/reject
choices. The local PC must revalidate state, scope, budget, and safety before
execution.

## Autonomy Hardening Rules

The control loop should follow:

```text
detect -> classify -> recover -> learn
```

Failure classes:

- transient
- deterministic/code defect
- environment fault
- policy failure
- ambiguous state

Overnight and unattended runs should use:

- explicit ship scope
- lease owner
- heartbeat timestamp
- retry budget
- wall-clock budget
- model/rate budget
- checkpoint evidence
- safe landing behavior
- resume rules

If a run cannot produce new objective evidence within its budget, it should stop
and escalate instead of looping.

## Evidence Rules

Every meaningful run should preserve enough evidence for a reviewer to answer:

```text
What was asked?
What was allowed?
What happened?
What changed?
What passed?
What failed?
What should happen next?
```

Evidence should include:

- task packet or request
- admission/policy result
- state transition history
- budget record
- diff or changed-source snapshot
- test/build/runtime output
- approval card, if any
- audit package or evidence index
- final decision/status

Prose summaries are useful for humans, but they are not proof by themselves.

## Implementation Priority

1. Create product-quality and lane rules that prevent overloaded demos.
2. Harden mobile command language before any real remote control exists.
3. Strengthen heartbeat, lease, recovery, and budget state for overnight use.
4. Improve audit readability with summarized test reports.
5. Add a captain quick-start and controlled-use rehearsal.
6. Require a product-specific launch checklist before real product autonomy.

## Open Questions For Later Captain Review

- Which phone notification channel should be first: local file digest, email,
  chat bot, or hosted mini-control panel?
- Which product ship should be the first controlled-use launch after fixture
  rehearsal?
- Should hospitality customer websites and manager/internal tools be separate
  launch presets?
- Which actions, if any, should require desktop-only approval even after mobile
  review cards exist?

