# Service Sync Studio Model Contract

Prepared: 2026-06-05

Evidence only; not executable authority or approval.

## Purpose

Service Sync Studio is a standalone local sandbox product spike concept. It is not HouseOS, not a product repo, and not a ship.

The product question is:

> Can one messy manager service update be safely split into a private manager version, a staff-ready version, and a guest-safe public version, with boundary checks before anything leaves the draft state?

The first spike should prove the boundary model and workflow clarity before any HouseOS integration is considered.

## Non-Authority Boundary

This contract does not approve HouseOS repo access, product-repo access, real customer/staff/vendor data, live service data, real demo execution, package creation or package sending, runtime command binding, remote access, phone approvals, all-fleet execution, running an overnight runner, staging, commit, push, deploy, installs, migrations, secrets/auth/payments/deploy work, lock deletion, permission widening, or future authority.

The only approved future implementation target from this contract is a separately requested standalone local sandbox spike using fixture data.

## Input Taxonomy

The model must expect messy manager updates that mix multiple operational intents:

- menu update
- inventory or 86 update
- staffing note
- VIP or reservation context
- training or coaching note
- incident or service recovery detail
- event or private party detail
- policy, opening, closing, or service-sequence change
- customer-facing menu or hospitality copy
- manager-only margin, vendor, comp, labor, or performance context

## Output Lanes

Every input is split into these lanes:

- `manager_private`: notes that may remain visible only to the manager or owner context.
- `staff_ready`: staff-facing service instructions, lineup notes, checklist tasks, notebook updates, or training prompts.
- `guest_safe`: public or customer-facing copy that avoids private operations, staff details, guest identity, and sensitive context.
- `blocked`: content that should not be published to staff or guests without removal or rewrite.
- `needs_human_review`: ambiguous or sensitive content that may be valid but requires manager confirmation.

The spike UI should show the lane assignment and a boundary explanation for each transformation.

## State Language

Allowed state labels:

- `draft`
- `manager_review`
- `staff_publishable`
- `guest_publishable`
- `blocked`
- `needs_human_review`

Forbidden state implications:

- A generated lane is not saved.
- A generated lane is not published.
- A generated lane is not visible to staff or guests.
- A green local boundary result does not approve real product execution.
- A public lane preview does not update a live website, menu, POS, or HouseOS surface.

## Allowed Transformations

The standalone spike may demonstrate these transformations using fixtures only:

- summarize
- sanitize
- split by audience
- rewrite for staff clarity
- rewrite for guest-safe public copy
- taskify into checklist items
- extract notebook updates
- create short learn/test cards
- label risks
- produce a boundary diff

## Forbidden Data Movement

The model must block or require review when content would move across unsafe boundaries:

- staff performance, discipline, scheduling conflict, coaching, pay, or private HR context into guest-safe copy
- guest identity, contact details, reservation notes, allergies, VIP preferences, or incident context into public copy
- manager-only margin, vendor pricing, comp strategy, labor concern, refund reasoning, or owner context into staff-ready or guest-safe copy unless explicitly sanitized
- sensitive incident, safety, medical, legal, alcohol-service, harassment, discrimination, or security context into staff or public copy without human review
- secrets, credentials, payment details, auth material, deployment material, or private system details into any generated lane
- live commands, links, buttons, approvals, prompts, queue prose, generated evidence, validation summaries, manifests, or external reports into executable authority

## Boundary QA Expectations

Boundary QA should produce:

- lane-level verdict: `pass`, `needs_human_review`, or `blocked`
- concise reason
- source phrase or topic category, not long verbatim excerpts
- destination lane affected
- suggested safe rewrite or removal
- confirmation that no product action was executed

## First Spike Scope

The first Service Sync Studio spike should be a local static prototype under `.codex-local/service-sync-studio-spike/`.

It should use only scenarios from `docs/fleet/SERVICE_SYNC_STUDIO_EVAL_PACK.md`, require no package installs, expose no server by default, touch no product repo, and include no real restaurant, customer, staff, vendor, auth, payment, secret, deployment, or HouseOS data.
