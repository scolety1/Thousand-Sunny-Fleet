# Manager/Internal Restaurant Tool Lane Profile

Purpose: help Codex Fleet build calm, useful restaurant operations tools for
shift leads, owners, managers, and operators.

Core rule:

```text
Build a Shift Cockpit, not a generic dashboard.
```

A manager-facing restaurant tool should open on the current shift and the next
decision. It should not open on a broad analytics portal, a report warehouse, or
a giant binder of every operational detail.

## First-Screen Expectation

The first screen must show:

- location, date, and service period
- one shift pulse visual or metric
- attention queue for approvals and exceptions
- actionable cards for staffing, service, stock, order channels, or tasks
- one clear next action
- drill-down paths for proof and context

The first screen must hide:

- payroll exports
- permissions
- long historical BI
- accounting workflows
- integrations
- setup/configuration
- full reports
- raw admin tables

## Shift Cockpit Pattern

Use this information order:

```text
shift context
-> shift pulse
-> attention queue
-> live operation cards
-> one-tap controls
-> secondary reports/configuration
```

The cockpit should answer five questions quickly:

```text
Are we staffed correctly?
What needs approval?
What live service risk exists?
What lever can I pull now?
Where can I drill in for proof?
```

## Show First

Show current-shift information first:

- labor versus demand
- staffing gaps
- pending approvals
- failed or delayed orders
- floor, waitlist, pacing, or reservation risk
- low-stock or 86-item risk
- missed tasks, temperature exceptions, or handoff notes
- order-channel status
- manager log or action queue

## Hide Deeper

Move these to secondary tabs or details:

- payroll and export workflows
- staff permissions
- vendor setup
- POS/channel integration settings
- full inventory catalogs
- historical analytics
- accounting reports
- template authoring
- long activity logs

## Actionable Cards

Every alert card should offer at least one action:

- approve
- assign
- snooze
- 86 item
- pause channel
- adjust quote time
- add manager note
- open proof
- create follow-up task

Passive cards are incomplete. A card that only says "low stock" should become
something like:

```text
Salmon low: 8 portions left.
Actions: 86 item, add prep note, notify service team.
```

## Positive Example

```text
ShiftLedger opens on Dinner Service, Thursday. The shift pulse shows demand is
high and labor is slightly short. The attention queue has two approvals, one
stock risk, and one late prep task. The primary CTA is "Review attention queue."
Tabs for labor, service, stock, and logbook are available. Payroll export,
permissions, and historical reports are one level deeper.
```

## Negative Example

```text
ShiftLedger opens with sales charts, payroll exports, vendor setup, staff edit
forms, full inventory tables, event notes, historical reports, permissions, and
generic KPI cards. It looks powerful, but the manager cannot tell what to do
during the shift.
```

## Mobile Expectation

Mobile should be action-first:

```text
service period
-> urgent count
-> top attention card
-> approve/assign/snooze action
-> compact live cards
-> deeper tabs
```

Do not compress the desktop report warehouse onto a phone.

## Evidence Required

- desktop screenshot of the first screen
- mobile screenshot when floor use is expected
- route or file path
- reviewer note naming the current shift context
- reviewer note naming the top attention item and action
- proof that reports/configuration are secondary, not first-screen clutter

## Taste Gate Hint

Stop for human taste review when the deterministic workflow works and the
remaining choices are operator language, thresholds, priority ordering, density,
or which alerts feel most realistic for the restaurant.

