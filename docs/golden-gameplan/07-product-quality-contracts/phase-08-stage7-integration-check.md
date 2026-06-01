# Stage 7 Phase 8 Prompt: Stage 7 Integration Check

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 7 Phase 8 only: Stage 7 Integration Check.

Goal:
Verify the product-quality contracts are complete and usable without editing product apps.

Run a focused docs/schema check that proves:
- all templates exist
- all lane profiles exist
- first-screen contract examples exist
- information hierarchy examples exist
- overload gate verdict examples exist
- done/taste gate examples exist
- product-quality evidence fields are documented

Fixture review cases should include:
- a wine list where the list is primary and helper is secondary
- a manager brief with today/status/action first
- an analytical model with recommendation/confidence/receipts
- a personal productivity tool with now/next/capture/undo
- an overloaded first screen that should fail

Guardrails:
- Do not launch ships.
- Do not edit real products.
- Do not implement Stage 8 autonomy wrapper.

Acceptance:
- Stage 7 focused checks pass.
- The contracts are specific enough to guide future tasks.
- The checkpoint explains what remains before Stage 8.

Proof:
Show file list, checks, and fixture verdict examples.
```

## Notes

This should prove the fleet has a better definition of quality before giving it more autonomy.

## Implementation Status

Status: GREEN

Evidence:
- `docs/templates/product-quality/*.md`
- `docs/templates/product-quality/lanes/*.md`
- `docs/templates/product-quality/examples/stage7-fixture-verdicts.md`
- `templates/product-quality-evidence-schema.json`
- `docs/golden-gameplan/07-product-quality-contracts/checkpoint.md`
- `tests/run-fleet-tests.ps1`

Verification:
- `.\tests\run-fleet-tests.ps1` passed.
- Fixture verdicts cover wine list, manager brief, analytical model, personal productivity, overloaded first screen, and taste gate after deterministic pass.
- No product apps were edited or launched.

Known limitation before Stage 8:
- Stage 7 defines and tests the contracts, but Stage 8 must decide how the autonomy wrapper consumes them during a bounded cycle.
