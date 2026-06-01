# Stage 7 Phase 6 Prompt: Done Contract And Taste Gate

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 7 Phase 6 only: Done Contract and Taste Gate.

Goal:
Define when a product ship should stop coding and ask for human taste.

DONE_CONTRACT should answer:
- What must work?
- What must be visible?
- What must be hidden/deferred?
- What build/test/runtime proof is required?
- What screenshots are required?
- What copy/design standards must be met?

TASTE_GATE_CONTRACT should answer:
- What has already passed?
- What is now subjective?
- What should the human inspect?
- What should the fleet not keep changing without feedback?

Taste gate examples:
- Hospitality site has good structure, but final mood/copy needs owner taste.
- Wine list works, but bottle styling/brand vibe needs human preference.
- Manager brief works, but workflow labels need a real operator.
- Niners formulas pass tests, but strategy weights need owner judgment.

Guardrails:
- Do not mark broken products done.
- Do not park products that fail deterministic gates.
- Do not let agents over-polish after taste gate.
- Do not edit product code.

Acceptance:
- DONE_CONTRACT and TASTE_GATE_CONTRACT templates exist.
- Examples cover at least three lanes.
- The distinction between done, parked, and taste-gated is clear.

Proof:
Show template paths and example contract snippets.
```

## Notes

This is the budget saver. Once taste is the blocker, stop spending loops.

## Implementation Status

Status: GREEN

Evidence:
- `docs/templates/product-quality/DONE_CONTRACT.md`
- `docs/templates/product-quality/TASTE_GATE_CONTRACT.md`
- `docs/templates/product-quality/examples/stage7-fixture-verdicts.md`
- `tests/run-fleet-tests.ps1`

Verification:
- Tests verify done is not treated as taste-approved.
- Tests verify taste-gate language blocks continued subjective churn after deterministic product checks pass.
