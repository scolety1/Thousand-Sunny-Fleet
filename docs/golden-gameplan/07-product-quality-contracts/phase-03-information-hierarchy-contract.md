# Stage 7 Phase 3 Prompt: Information Hierarchy Contract

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 7 Phase 3 only: Information Hierarchy Contract.

Goal:
Define the rule that information should be staged, not dumped.

Create a contract that splits product content into:
- primary: must be visible first
- secondary: one click/tap away
- tertiary: deeper detail, drawer, modal, route, or expandable area
- hidden/admin: only visible when relevant

The contract should require:
- navigation plan
- disclosure pattern
- route/page split recommendation
- feature priority
- overload risks
- what should be removed from the first screen

Examples:
- Wine list: the list is primary; help-me-choose is secondary.
- Manager brief: today's shift summary is primary; edit/setup/history are secondary.
- Event intake: inquiry form is primary; internal tracker is secondary.
- Analytical model: recommendation and confidence are primary; formula receipts are secondary/tertiary.

Guardrails:
- Do not create routes yet.
- Do not modify product code.
- Do not treat hiding information as removing it.
- Keep accessibility in mind: hidden detail must still be reachable.

Acceptance:
- Information hierarchy contract exists.
- Examples reflect the user's stated wine-list and manager-brief issues.
- Contract includes pass/fail criteria.

Proof:
Show contract path and example hierarchy.
```

## Notes

This phase captures the breakthrough: not less information, better staging.

## Implementation Status

Status: GREEN

Evidence:
- `docs/templates/product-quality/INFORMATION_HIERARCHY_CONTRACT.md`
- `tests/run-fleet-tests.ps1`

Verification:
- The hierarchy contract splits content into primary, secondary, tertiary, and hidden/admin layers.
- Tests verify the wine-list and manager-brief examples reflect the staging issue: primary job first, helpers/setup/history secondary.
