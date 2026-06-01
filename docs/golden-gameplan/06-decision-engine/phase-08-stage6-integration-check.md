# Stage 6 Phase 8 Prompt: Stage 6 Integration Check

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 6 Phase 8 only: Stage 6 Integration Check.

Goal:
Verify the decision engine end to end without executing decisions.

Run a focused integration check that:
- loads fixture ship state
- normalizes decision input
- computes a decision
- writes decision reports
- validates all canonical decisions
- proves no ship launches or task queue mutations occur

Required decision coverage:
- NOOP
- RUN_AGAIN
- REPAIR
- PACKAGE_AUDIT
- WAIT_FOR_EXTERNAL_AUDIT
- WAIT_FOR_TASK_PACKET
- USER_TASTE_GATE
- WAIT_FOR_RATE_RESET
- PARK
- BLOCK
- ARCHIVE

Guardrails:
- Do not run real product ships.
- Do not mutate downstream app code.
- Do not implement Stage 7 product quality contracts.
- Do not implement Stage 8 autonomy wrapper.

Acceptance:
- Stage 6 focused tests pass.
- Decision reports are produced.
- Every decision path has at least one test fixture.
- No execution side effects occur.

Proof:
Provide:
- test command output
- decision matrix
- generated report paths
- known limitations before Stage 7
```

## Notes

This is the final proof that the fleet can decide before it is allowed to act.

## Implementation Status

Status: GREEN

Evidence:
- `templates/decision-schema.json`
- `templates/decision-input-schema.json`
- `tools/codex-fleet-decision.ps1`
- `fleet-decision.ps1`
- `fleet/status/decisions.md`
- `fleet/status/decisions.json`
- `tests/run-fleet-tests.ps1`
- `docs/golden-gameplan/06-decision-engine/checkpoint.md`

Verification:
- `.\tests\run-fleet-tests.ps1` passed.
- `.\fleet-decision.ps1 -Action Report` passed.
- Every canonical decision path has a fixture test.
- Stage 6 does not run product ships, mutate product repos, delete locks, merge, push, deploy, or implement Stage 7/8 behavior.

Known limitation before Stage 7:
- Product quality readiness is still generic. Stage 7 should add product-quality contracts so taste gates and done-enough decisions can be based on stronger website/app evidence.
