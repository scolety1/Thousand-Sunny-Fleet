# Stage 11 Phase 7 Prompt: Lane Selection And Escalation Rules

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 11 Phase 7 only: Lane Selection and Escalation Rules.

Goal:
Define how tasks and ships choose lanes, and when work escalates to a safer lane.

Selection inputs:
- ship type
- task contract metadata
- touched file paths
- risk tier
- product quality contract
- formula/data contract
- package/dependency changes
- auth/payment/deploy/migration keywords

Escalation examples:
- hospitality website task touches auth -> backend_sensitive
- manager tool task adds package -> backend_sensitive or approval required
- analytical task changes formula weights -> analytical_software + formula audit
- maintenance task grows into redesign -> hospitality_website or manager_internal_tool
- website task becomes only subjective -> taste gate

Required outputs:
- selected lane
- reason
- required gates
- blocked/escalated status
- captain approval needed

Guardrails:
- If lane is uncertain, choose safer lane.
- Backend-sensitive escalation overrides normal lanes.
- Formula correctness overrides visual polish for analytical software.
- Do not implement routing yet unless explicitly running this phase later.

Acceptance:
- Lane selection rules exist.
- Escalation matrix exists.
- Examples cover all five lanes.
- Uncertain lane behavior is conservative.

Proof:
Show selection rules and examples.
```

## Notes

Lane selection is where the fleet starts acting less generic.

## Implementation Status

Status: GREEN

Implemented by `Resolve-FleetSpecializedLane`. It emits selected lane, reasons,
required gates, evidence requirements, budget mode, overnight eligibility,
escalation status, and captain-approval requirement.
