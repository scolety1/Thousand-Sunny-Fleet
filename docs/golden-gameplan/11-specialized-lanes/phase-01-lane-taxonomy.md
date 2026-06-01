# Stage 11 Phase 1 Prompt: Lane Taxonomy

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 11 Phase 1 only: Lane Taxonomy.

Goal:
Define the canonical specialized lanes for Codex Fleet.

Required lanes:
- hospitality_website
- manager_internal_tool
- analytical_software
- backend_sensitive
- maintenance

For each lane define:
- display name
- purpose
- typical ships
- allowed task classes
- forbidden task classes
- default review gates
- evidence requirements
- default budget mode
- overnight eligibility
- taste/approval triggers

Guardrails:
- Do not implement lane routing yet.
- Do not edit real ship task queues.
- Do not launch ships.
- Do not modify product repos.

Acceptance:
- Lane taxonomy doc exists.
- Lane IDs are stable and machine-friendly.
- Examples include Bottlelight, ShiftLedger, NinersWarRoom, EasyLife, and maintenance fixtures.
- The taxonomy explains when a task should escalate lanes.

Proof:
Show taxonomy path and lane summary table.
```

## Notes

This phase names the lanes before any routing depends on them.

## Implementation Status

Status: GREEN

Implemented by `Get-FleetLaneProfiles` in `tools/codex-fleet-lanes.ps1` and
documented in `docs/templates/specialized-lanes/lane-taxonomy.md`.
