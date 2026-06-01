# Stage 7 Phase 5 Prompt: Demo Lane Profiles

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 7 Phase 5 only: Demo Lane Profiles.

Goal:
Define product-quality profiles for different kinds of ships.

Create lane profiles for:
- Customer-Facing Hospitality
- Manager-Facing Operations
- Analytical Software
- Personal Productivity
- Website Generator / Local Business Site

Each profile should define:
- audience
- first-screen expectation
- primary action style
- acceptable density
- copy voice
- mobile expectation
- screenshot evidence
- common failure modes
- done contract hints
- taste gate hints

Required examples:
- Bottlelight / wine list style customer-facing demo
- ShiftLedger / manager brief operations demo
- Niners War Room analytical software
- EasyLife personal productivity
- restaurant website public-facing site

Guardrails:
- Do not edit those products.
- Do not assume one design style fits every lane.
- Do not make the hospitality lane copy another website.
- Make inspiration about principles, not cloning.

Acceptance:
- Lane profile docs exist.
- Each lane has clear pass/fail examples.
- The profiles explain how customer-facing and manager-facing restaurant demos differ.

Proof:
Show lane profile paths and summaries.
```

## Notes

This is how the fleet stops treating a wine list, a manager board, and Niners War Room as the same kind of product.

## Implementation Status

Status: GREEN

Evidence:
- `docs/templates/product-quality/lanes/customer-facing-hospitality.md`
- `docs/templates/product-quality/lanes/manager-facing-operations.md`
- `docs/templates/product-quality/lanes/analytical-software.md`
- `docs/templates/product-quality/lanes/personal-productivity.md`
- `docs/templates/product-quality/lanes/local-business-website.md`
- `tests/run-fleet-tests.ps1`

Verification:
- Tests prove each lane profile exists and includes first-screen expectations, common failures, and taste gate hints.
- Hospitality and manager-facing restaurant tools are separated instead of treated as the same surface.
