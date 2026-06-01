# Stage 7 Phase 4 Prompt: Simplicity And Overload Gate

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 7 Phase 4 only: Simplicity and Overload Gate.

Goal:
Define a gate that flags overwhelming product surfaces before they keep iterating.

The gate should flag:
- too many primary CTAs
- too many panels on first screen
- visible internal/admin tools on customer-facing first screen
- vague or trendy copy
- feature list presented as product experience
- unrelated workflows mixed on one route
- first screen requiring explanation to understand
- mobile screen that starts in the middle of a giant form/table

The gate should allow:
- rich depth below the first screen
- secondary routes
- drawers/modals for detail
- dashboard density in analytical tools when hierarchy is clear

Guardrails:
- Do not make this a generic minimalism rule.
- Do not force every app to look sparse.
- Do not implement automated screenshot scoring yet unless existing tooling makes it trivial.
- Do not edit product code.

Acceptance:
- Gate rules are documented.
- Examples include pass/fail cases.
- The gate can produce one of: PASS, PASS_WITH_NOTES, FAIL_OVERLOADED, NEEDS_TASTE_REVIEW.
- Decision engine integration notes are included.

Proof:
Show gate doc and sample verdicts.
```

## Notes

This gate should protect against the fleet building "all features, all at once."

## Implementation Status

Status: GREEN

Evidence:
- `docs/templates/product-quality/SIMPLICITY_OVERLOAD_GATE.md`
- `docs/templates/product-quality/examples/stage7-fixture-verdicts.md`
- `tests/run-fleet-tests.ps1`

Verification:
- The gate documents `PASS`, `PASS_WITH_NOTES`, `FAIL_OVERLOADED`, and `NEEDS_TASTE_REVIEW`.
- Tests verify it flags customer-facing admin tools, giant mobile forms/tables, and all-features-at-once layouts.
