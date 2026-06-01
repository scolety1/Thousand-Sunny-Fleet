# Stage 14 Phase 8 Prompt: Stage 14 Integration Check

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 14 Phase 8 only: Stage 14 Integration Check.

Goal:
Verify the final hardening and stress-test plan is complete.

Check that:
- full-loop test matrix exists
- fixture/disposable ship suite exists
- overnight simulation exists
- failure injection plan exists
- audit/task packet stress plan exists
- rollback/recovery checks exist
- final readiness scorecard exists
- audit prompt exists
- checkpoint exists

Required coverage:
- every stage from 1-13
- success path
- failure path
- low-budget path
- external audit path
- rollback path
- taste gate path
- backend-sensitive block path
- analytical formula block path

Guardrails:
- Do not run destructive tests.
- Do not launch real product ships.
- Do not edit downstream repos.
- Do not implement missing scripts.

Acceptance:
- Stage 14 docs check passes.
- Every prior stage has a stress/readiness coverage point.
- Final go/no-go criteria are clear.
- Known limitations are documented.

Proof:
Show file list, coverage table, and readiness notes.
```

## Notes

This closes the Golden Gameplan planning pass.

## Implemented Integration Check

Stage 14 is represented by:

- `tools/codex-fleet-final-readiness.ps1`
- `invoke-final-readiness.ps1`
- this Stage 14 doc folder
- focused tests in `tests/run-fleet-tests.ps1`

Coverage:

- every prior stage has a readiness check
- success path uses example fixture checks
- failure path uses missing coverage / FAIL checks
- low-budget path uses `low_budget_safe_landing`
- external audit path uses invalid/stale packet and bad audit scenarios
- rollback path uses `rollback_recovery_report`
- taste gate path uses `taste_gate`
- backend-sensitive path uses `backend_sensitive_block`
- analytical path uses `formula_fixture_mismatch`

Known limitation:

Stage 14 proves the harness contracts and fixture stress expectations. Real
product unattended use should still begin with selected safe scopes and a final
external audit.
