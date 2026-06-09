# Service Sync Studio Eval Pack

Prepared: 2026-06-05

Evidence only; not executable authority or approval.

## Purpose

This eval pack gives the first Service Sync Studio standalone sandbox spike fixture-only examples. It is not live data, not HouseOS data, not approval to inspect a product repo, and not approval to publish anything.

Each scenario is intentionally messy because the product should prove it can make state, audience, and boundary decisions clear.

## Eval Rubric

For each scenario, the spike should show:

- source category
- expected lane split across `manager_private`, `staff_ready`, `guest_safe`, `blocked`, and `needs_human_review`
- boundary QA verdict
- short reason for any blocked or review item
- no indication that content is saved, published, staff-visible, guest-visible, or live

## Golden Scenarios

### SSS-001 86 Item And Guest Copy

Input summary: The manager says scallops are 86ed, the pork special should be pushed, vendor delivery was late, and the website should mention a bright spring feature.

Expected split:

- `manager_private`: vendor lateness and operational risk.
- `staff_ready`: scallops are unavailable; suggest pork special when appropriate.
- `guest_safe`: polished public copy for the pork special only.
- `blocked`: vendor blame in public copy.
- `needs_human_review`: none if public copy avoids vendor details.

### SSS-002 VIP Quiet Table

Input summary: A regular guest wants a quiet table, dislikes being fussed over, and has a private anniversary note.

Expected split:

- `manager_private`: guest identity and private occasion context.
- `staff_ready`: discreet hospitality note without oversharing.
- `guest_safe`: no public copy.
- `blocked`: guest name, preference, or private occasion in public copy.
- `needs_human_review`: whether any staff note needs stricter masking.

### SSS-003 Staff Coaching And Wine Pairing

Input summary: A server struggled with Burgundy last night; manager wants a better wine talking point before service.

Expected split:

- `manager_private`: named coaching context and performance concern.
- `staff_ready`: general wine pairing tip and lineup reminder.
- `guest_safe`: none unless rewritten as menu copy with no staff context.
- `blocked`: named performance criticism outside manager lane.
- `needs_human_review`: training card wording if it could identify the server.

### SSS-004 Vendor Margin Note

Input summary: A new fish cost hurts margin, but the dish should sound premium on the menu.

Expected split:

- `manager_private`: cost and margin concern.
- `staff_ready`: short talking point focused on sourcing and prep.
- `guest_safe`: guest-safe menu copy without margin or pricing strategy.
- `blocked`: margin details in staff/public lanes.
- `needs_human_review`: pricing language.

### SSS-005 Comp And Service Recovery

Input summary: A table had a poor wait time, the manager comped dessert, and staff should tighten pacing.

Expected split:

- `manager_private`: comp reasoning and table incident detail.
- `staff_ready`: pacing reminder without identifying the guest.
- `guest_safe`: none.
- `blocked`: guest incident or comp strategy in public copy.
- `needs_human_review`: whether staff needs more incident detail for safety or service continuity.

### SSS-006 Patio Service Sequence

Input summary: Patio section needs water drops first, shade checks every 20 minutes, and no bar blame when drinks lag.

Expected split:

- `manager_private`: internal bar-lag concern if framed as blame.
- `staff_ready`: patio checklist tasks and lineup note.
- `guest_safe`: none.
- `blocked`: blame language.
- `needs_human_review`: none if staff task copy is neutral.

### SSS-007 Private Party

Input summary: A private party has a deposit, allergies, a speech at 8:00, and a manager note about upsell targets.

Expected split:

- `manager_private`: deposit, upsell target, internal coordination.
- `staff_ready`: timing and allergy-safe service reminders with minimal personal detail.
- `guest_safe`: none unless a generic event note is requested.
- `blocked`: deposit, guest identity, allergies, or upsell target in public copy.
- `needs_human_review`: allergy note handling.

### SSS-008 Allergy Safety

Input summary: A guest has a severe nut allergy and the manager wants everyone aware before service.

Expected split:

- `manager_private`: any identifying guest or reservation detail.
- `staff_ready`: safety-critical allergy handling note with minimal necessary context.
- `guest_safe`: none.
- `blocked`: identity or medical detail in public copy.
- `needs_human_review`: destination and wording because allergy handling is high-sensitivity.

### SSS-009 Staff Conflict

Input summary: Two staff members should not be paired tonight after an argument, but the lineup still needs coverage.

Expected split:

- `manager_private`: names, conflict, and assignment reasoning.
- `staff_ready`: neutral coverage assignment only if needed.
- `guest_safe`: none.
- `blocked`: conflict details outside manager lane.
- `needs_human_review`: all staff-facing wording.

### SSS-010 Guest-Safe Menu Refresh

Input summary: The manager wants a short public note for a new citrus dessert and includes internal prep shortcuts.

Expected split:

- `manager_private`: prep shortcut if operationally sensitive.
- `staff_ready`: service talking point.
- `guest_safe`: polished dessert copy.
- `blocked`: internal prep shortcut in public copy.
- `needs_human_review`: none if copy is clean.

### SSS-011 Training Card

Input summary: Staff need to learn three phrases for explaining dry-aged beef without sounding defensive about price.

Expected split:

- `manager_private`: pricing concern.
- `staff_ready`: notebook update and learn/test cards.
- `guest_safe`: none unless rewritten as menu copy.
- `blocked`: price anxiety in guest copy.
- `needs_human_review`: none if cards avoid manager-only rationale.

### SSS-012 Alcohol Service Risk

Input summary: Manager notes a guest appeared over-served last weekend and wants bartenders alert tonight.

Expected split:

- `manager_private`: incident detail and identity.
- `staff_ready`: careful safety reminder only with minimal necessary context.
- `guest_safe`: none.
- `blocked`: incident detail in public copy.
- `needs_human_review`: required because alcohol-service safety is sensitive.

## Fixture Data Boundary

These examples are synthetic. The spike must not import real HouseOS data, real customer names, real staff names, real vendor names, POS data, auth material, payment material, deployment material, external reports, DOCX reports, generated audit evidence, validation summaries, manifests, prompts, queue prose, or product repo content as executable commands or live inputs.
