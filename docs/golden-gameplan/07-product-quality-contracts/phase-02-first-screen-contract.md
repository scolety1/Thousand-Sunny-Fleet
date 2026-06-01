# Stage 7 Phase 2 Prompt: First-Screen Contract

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 7 Phase 2 only: First-Screen Contract.

Goal:
Define how the fleet evaluates whether the first screen makes sense.

The first screen should answer:
- What is this?
- Who is it for?
- What can I do here?
- What is the one primary action?
- Where do I go for secondary actions?

Required contract fields:
- audience
- product type
- first-screen promise
- primary action
- secondary actions
- forbidden clutter
- required visible evidence
- mobile first-screen notes
- screenshot proof path

Lane-specific expectations:
- Customer-facing hospitality: brand/place/mood/action
- Manager-facing operations: today/status/priority/action
- Analytical software: current answer/confidence/drivers/audit
- Personal productivity: now/next/capture/undo

Guardrails:
- Do not require every feature to appear on the first screen.
- Do not reward feature dumping.
- Do not implement visual checks yet beyond defining the contract.
- Do not edit product code.

Acceptance:
- First-screen contract template exists.
- Examples cover customer-facing, manager-facing, analytical, and personal-productivity lanes.
- The contract clearly flags overwhelming first screens as failures.

Proof:
Show template path and examples.
```

## Notes

This is the direct fix for "everything is immediately displayed right in front of you."

## Implementation Status

Status: GREEN

Evidence:
- `docs/templates/product-quality/FIRST_SCREEN_CONTRACT.md`
- `tests/run-fleet-tests.ps1`

Verification:
- The first-screen contract covers customer-facing hospitality, manager operations, analytical software, and personal productivity lanes.
- Tests verify the contract flags dumped all-at-once information as a failure.
