# Stage 9 Phase 8 Prompt: Stage 9 Integration Check

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 9 Phase 8 only: Stage 9 Integration Check.

Goal:
Verify the external agent workflow docs/prompts are complete and ready for implementation later.

Check that:
- external roles exist
- handoff prompt exists
- role-specific prompts exist
- structured response format exists
- multi-agent comparison process exists
- ingest review rules exist
- captain summary template exists
- audit prompt exists
- checkpoint exists

Fixture scenarios:
- website product taste audit
- analytical formula audit
- security/scope audit
- three-agent disagreement
- stale task packet
- valid task packet
- rejected broad redesign packet

Guardrails:
- Do not call external agents.
- Do not ingest packets.
- Do not implement scripts.
- Do not touch product repos.

Acceptance:
- Stage 9 focused docs check passes.
- The workflow is clear enough for a user to send audit packages manually.
- The stage identifies what implementation is needed later.

Proof:
Show file list, fixture scenarios, and readiness notes.
```

## Notes

This stage should make external audits repeatable, not magical.

## Implementation Status

Status: GREEN

`.\tests\run-fleet-tests.ps1` passes with Stage 9 checks for prompt generation, response validation, stale response rejection, unsafe response rejection, role prompts, and multi-agent comparison.
