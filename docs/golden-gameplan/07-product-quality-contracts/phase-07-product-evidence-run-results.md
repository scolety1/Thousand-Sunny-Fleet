# Stage 7 Phase 7 Prompt: Product Evidence In Run Results

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 7 Phase 7 only: Product Evidence in Run Results.

Goal:
Define a contract for how product-quality evidence should appear in Stage 2
RUN_RESULT.json and related reports. This phase is a schema/specification phase;
it should not change runtime writers unless a later implementation phase
explicitly asks for that wiring.

Define fields for:
- demoPromiseStatus
- firstScreenStatus
- informationHierarchyStatus
- simplicityGateStatus
- mobileStatus
- doneContractStatus
- tasteGateStatus
- screenshots
- reviewerNotes
- productQualityDecisionHint

Suggested statuses:
- PASS
- PASS_WITH_NOTES
- FAIL
- UNKNOWN
- NOT_APPLICABLE

Guardrails:
- Do not modify run-result scripts in this phase.
- Do not run screenshots.
- Do not edit products.
- This prompt should define the integration plan and expected schema additions.

Acceptance:
- Product-quality evidence fields are specified.
- The fields can be consumed by the Stage 6 decision engine.
- Unknown product-quality evidence does not automatically block analytical/backend-only ships.

Proof:
Show proposed schema additions and sample RUN_RESULT fragment.
```

## Notes

This bridges product taste with the decision engine without letting subjective review take over everything.

## Implementation Status

Status: GREEN

Evidence:
- `docs/templates/product-quality/PRODUCT_QUALITY_EVIDENCE.md`
- `templates/product-quality-evidence-schema.json`
- `tests/run-fleet-tests.ps1`

Verification:
- Product-quality evidence fields are documented and represented in schema form.
- Tests verify `firstScreenStatus`, `simplicityGateStatus`, and `USER_TASTE_GATE` decision hint support exist.
- Runtime writers were not changed in this phase; this remains a schema/specification bridge for later stages.
