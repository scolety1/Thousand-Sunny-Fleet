# First Screen Contract

Purpose: make the first screen orient the user instead of dumping every feature.

Required fields:
- Audience
- Product type/lane
- First-screen promise
- Proof artifact
- Primary visible information
- Primary action
- Secondary actions and where they live
- Tertiary content and where it is deferred
- Forbidden clutter
- Mobile first-screen expectation
- Screenshot proof path

## Five-Second Questions

The first screen must answer these questions within about five seconds:

```text
What is this?
Who is it for?
What can I do next?
```

If the answer requires reading every card, opening a helper, or scrolling through
the whole page, the first screen is not done.

## Promise -> Proof -> Path

Use this structure for all visible demos:

```text
Promise: one outcome in user language.
Proof: one representative artifact that makes the promise credible.
Path: one primary CTA that starts the primary task.
```

The proof artifact can be a realistic output, live object, status card, sample
recommendation, preview result, or representative screenshot. It should prove the
promise more effectively than a feature list.

## Content Layers

Primary:
- first-screen promise
- proof artifact
- primary action
- one high-signal status or credibility cue

Secondary:
- one to three supporting routes, examples, or filters
- content most users need after they understand the promise

Tertiary:
- settings
- docs
- exports
- internal/admin tools
- rare workflows
- full feature inventory

Tertiary content must not appear as first-screen clutter.

Lane examples:
- Customer-facing hospitality: brand, place, mood, offer, one reservation/menu/list action.
- Manager-facing operations: today, status, priority, one next action.
- Analytical software: current answer, confidence, key drivers, audit/receipt link.
- Personal productivity: now, next, capture, undo.

Valid example:
```text
Wine list primary: visible list filters and featured pour.
Secondary: help-me-choose button opens a guided panel.
Forbidden: cellar admin notes and vendor controls above the fold.
```

Failure example:
```text
First screen shows full list, helper wizard, staff notes, vendor export, admin edit form,
pricing matrix, and marketing copy all at once.
```

Failure example:
```text
First screen has five equally loud CTAs, no proof artifact, vague "Explore"
labels, and tertiary settings mixed with the primary task.
```

Evidence that proves it:
- desktop screenshot
- mobile screenshot for customer-facing demos
- route or file path
- short reviewer note naming the primary action
