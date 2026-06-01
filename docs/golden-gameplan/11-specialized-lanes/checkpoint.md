# Stage 11 Checkpoint

Use this checklist before moving to Stage 12.

## Required Docs

- [x] `stage-plan.md`
- [x] `phase-01-lane-taxonomy.md`
- [x] `phase-02-hospitality-website-lane.md`
- [x] `phase-03-manager-internal-tool-lane.md`
- [x] `phase-04-analytical-software-lane.md`
- [x] `phase-05-backend-sensitive-lane.md`
- [x] `phase-06-maintenance-lane.md`
- [x] `phase-07-lane-selection-escalation.md`
- [x] `phase-08-stage11-integration-check.md`
- [x] `audit-prompt.md`
- [x] `checkpoint.md`

## Implementation Completion Criteria

- [x] Lane taxonomy exists.
- [x] Hospitality website lane exists.
- [x] Manager/internal tool lane exists.
- [x] Analytical software lane exists.
- [x] Backend-sensitive lane exists.
- [x] Maintenance lane exists.
- [x] Lane selection rules exist.
- [x] Escalation rules exist.
- [x] Evidence requirements differ by lane.
- [x] Overnight eligibility differs by lane.

## Scenarios To Prove

- [x] Restaurant website maps to hospitality_website.
- [x] Wine list maps to hospitality_website.
- [x] Manager brief maps to manager_internal_tool.
- [x] Order sheet maps to manager_internal_tool.
- [x] Niners formula task maps to analytical_software.
- [x] Margin simulator formula task maps to analytical_software.
- [x] Auth/payment/deployment task maps to backend_sensitive.
- [x] Dependency update escalates to backend_sensitive or explicit approval.
- [x] Small bug patch maps to maintenance.
- [x] Ambiguous risky task chooses the safer lane.

## Red Flags

Do not move to Stage 12 if:

- All lanes still feel like generic web tasks.
- Hospitality and manager-facing demos have the same first-screen rules.
- Analytical software can skip formula tests.
- Backend-sensitive work can run without approval.
- Maintenance can mutate into broad redesign.
- Lane escalation is vague.
- Overnight eligibility is identical for all lanes.

## Stage 12 Readiness Statement

Before Stage 12 begins, write a short note answering:

```text
Can the fleet tell what kind of work it is doing?
Which lanes are safe for autonomy?
Which lanes require captain approval?
What should the dashboard show about lane health?
```

## Implementation Status

Status: GREEN

Completed on 2026-05-27.

Evidence:
- `tools/codex-fleet-lanes.ps1`
- `invoke-specialized-lane.ps1`
- `docs/templates/specialized-lanes/`
- `tests/run-fleet-tests.ps1`

Verification:
- `.\tests\run-fleet-tests.ps1` passed.
- Tests prove all five lane IDs exist with gates and evidence requirements.
- Tests prove restaurant/wine work routes to `hospitality_website`.
- Tests prove manager brief/order sheet work routes to `manager_internal_tool`.
- Tests prove Niners/margin formula work routes to `analytical_software`.
- Tests prove auth/payment/deployment/package/dependency work routes to `backend_sensitive`.
- Tests prove small bug work routes to `maintenance`.
- Tests prove backend-sensitive scope overrides normal requested lanes.
- Tests prove broad redesign escapes the maintenance lane.

Stage 12 readiness:
- The fleet can tell what kind of work it is doing at the policy layer.
- Safe autonomy lanes are `maintenance`, `hospitality_website`, `manager_internal_tool`, and `analytical_software` when their lane-specific evidence gates are satisfied.
- `backend_sensitive` requires captain approval by default.
- The dashboard should show each ship/task lane, escalation status, required gates, evidence gaps, overnight eligibility, and whether captain approval is needed.

## Post-Golden Hardening Note

Stage 15 adds a deeper customer-facing hospitality profile at
`docs/templates/product-quality/lane-profiles/hospitality-customer-website.md`.
That profile keeps `hospitality_website` from collapsing into a generic
small-business landing page by requiring:

- hospitality archetype selection
- venue name and emotional promise on the first screen
- short navigation
- one primary CTA
- immediate menu/reservation/hours/location access
- progressive disclosure for story, private dining, shop, press, and other
  secondary material
- anti-copy guidance: borrow structure, not authored identity

Stage 15 also adds a deeper manager/internal restaurant tool profile at
`docs/templates/product-quality/lane-profiles/manager-internal-restaurant-tool.md`.
That profile keeps `manager_internal_tool` from becoming a generic dashboard by
requiring:

- Shift Cockpit structure
- current shift context
- one shift pulse visual
- attention queue
- actionable exception and approval cards
- live operations cards
- secondary placement for reports, setup, permissions, exports, and historical BI
