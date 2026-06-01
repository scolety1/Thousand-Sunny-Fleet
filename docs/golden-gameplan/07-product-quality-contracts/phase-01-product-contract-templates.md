# Stage 7 Phase 1 Prompt: Product Contract Templates

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 7 Phase 1 only: Product Contract Templates.

Goal:
Create reusable product-quality contract templates for Codex Fleet ships.

Create templates for:
- DEMO_PROMISE.md
- FIRST_SCREEN_CONTRACT.md
- PRODUCT_QUALITY_CONTRACT.md
- INFORMATION_HIERARCHY_CONTRACT.md
- MOBILE_CONTRACT.md
- DONE_CONTRACT.md
- TASTE_GATE_CONTRACT.md

Each template should include:
- purpose
- who fills it out
- required fields
- examples
- what fails the contract
- what evidence proves it

Required principles:
- one audience
- one primary job
- one primary first-screen action
- secondary features reachable but not dumped
- concrete copy
- mobile expectation
- realistic demo data
- clear done/taste gate boundary

Guardrails:
- Do not edit real product app code.
- Do not launch ships.
- Do not rewrite existing task queues.
- Do not make the templates bloated.

Acceptance:
- Templates exist in a predictable docs/templates location.
- Each template is short enough to be used.
- Each template includes at least one valid example and one failure example.
- Focused docs validation or file existence tests pass.

Proof:
Report created template paths and summarize the required fields.
```

## Notes

These templates should be useful by a tired human from a phone.

## Implementation Status

Status: GREEN

Evidence:
- `docs/templates/product-quality/DEMO_PROMISE.md`
- `docs/templates/product-quality/FIRST_SCREEN_CONTRACT.md`
- `docs/templates/product-quality/PRODUCT_QUALITY_CONTRACT.md`
- `docs/templates/product-quality/INFORMATION_HIERARCHY_CONTRACT.md`
- `docs/templates/product-quality/MOBILE_CONTRACT.md`
- `docs/templates/product-quality/DONE_CONTRACT.md`
- `docs/templates/product-quality/TASTE_GATE_CONTRACT.md`
- `docs/templates/product-quality/SIMPLICITY_OVERLOAD_GATE.md`
- `docs/templates/product-quality/PRODUCT_QUALITY_EVIDENCE.md`
- `tests/run-fleet-tests.ps1`

Verification:
- Tests prove each required template exists and includes usable contract content.
