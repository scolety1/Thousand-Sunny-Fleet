# Golden Gameplan Stage 9.5: External Review Reliability Patch

## Purpose

Stage 9.5 is a focused patch between Stage 9 and Stage 10.

The Stage 8.5 + Stage 9 audit returned `PASS WITH FIXES`. The fixes are mostly about making external review easier to trust before the fleet enters overnight mode.

## Outcomes

Stage 9.5 is complete when:

- `LowTokenMode` is clearly documented as manual only
- Stage 9 can generate a captain summary from comparison JSON
- concrete comparison examples exist
- validation has broader negative tests
- taste disagreements route to `NEEDS_CAPTAIN`
- tests pass

## Non-Goals

Do not implement:

- Stage 10 overnight scheduling
- automatic rate-limit detection
- external agent API calls
- product ship launches
- task packet ingestion beyond validation/comparison outputs

## Acceptance

- `.\tests\run-fleet-tests.ps1` passes.
- Captain summary output is Markdown and phone-readable.
- Malformed JSON writes a validation result instead of crashing.
- Unknown role, invalid verdict, missing field, forbidden pattern, and stale commit are rejected.
- Taste/visual-direction disagreement lands in `NEEDS_CAPTAIN`.

