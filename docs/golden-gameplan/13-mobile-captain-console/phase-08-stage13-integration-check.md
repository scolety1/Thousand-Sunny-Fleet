# Stage 13 Phase 8 Prompt: Stage 13 Integration Check

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 13 Phase 8 only: Stage 13 Integration Check.

Goal:
Verify the Mobile Captain Console docs are complete and safe.

Check that:
- mobile status contract exists
- command inbox protocol exists
- safe remote actions matrix exists
- idea intake spec exists
- rate-limit alert spec exists
- mobile digest template exists
- approval/rejection rules exist
- audit prompt exists
- checkpoint exists

Fixture scenarios:
- user asks "how is the fleet?"
- user asks to stop one ship
- user sends a vague idea
- user approves a taste direction
- user asks to run everything
- budget is critical
- resume after reset is requested
- backend-sensitive command is requested

Guardrails:
- Do not implement messaging integration.
- Do not execute commands.
- Do not launch ships.
- Do not edit downstream repos.
- Do not implement Stage 14 hardening.

Acceptance:
- Stage 13 docs check passes.
- Every fixture scenario has a safe response.
- Unsafe commands are rejected or require clarification.
- Readiness notes identify what Stage 14 needs.

Proof:
Show file list, fixture response table, and readiness notes.
```

## Notes

This proves the mobile layer is safe before any real remote interface exists.

## Implemented Integration Check

Stage 13 is represented by:

- `tools/codex-fleet-mobile.ps1`
- `invoke-mobile-console.ps1`
- this Stage 13 doc folder
- focused tests in `tests/run-fleet-tests.ps1`

Fixture response table:

| Scenario | Response |
| --- | --- |
| `How is the fleet?` | `STATUS`, accepted, phone summary from Stage 12 snapshot. |
| `Stop Bottlelight safely.` | `REQUEST_SAFE_STOP`, scoped request, does not execute. |
| vague idea | `CAPTURE_IDEA`, idea only, clarification if vague. |
| taste approval | approval-required request, no execution. |
| `run everything` | rejected implicit all-fleet request. |
| critical budget | alert recommends safe landing/status-only behavior. |
| resume after reset | approval-required and Stage 10 evidence required later. |
| backend-sensitive command | rejected or approval-required; never casual execution. |

Stage 14 needs to stress-test the full path from mobile request to local
validation, including rejection, audit evidence, rate budget, dry-run, and
fixture-only execution boundaries.
