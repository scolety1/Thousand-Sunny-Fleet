# Stage 5 Phase 7 Prompt: Backward Compatibility

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 5 Phase 7 only: Backward Compatibility.

Goal:
Make the state machine work with existing ships that do not yet have perfect Stage 2-4 evidence.

The fleet has old projects and partially upgraded projects. Stage 5 should classify them safely without forcing a full migration in one step.

Required behavior:
- Missing RUN_RESULT.json should not crash classification.
- Missing CURRENT_STATE.md should be created from a template.
- Missing audit package should become a note, not a fatal error.
- Missing task packet should not imply failure.
- Unknown or conflicting evidence should produce UNKNOWN or BLOCKED with a reason.

Guardrails:
- Do not mass-edit downstream app code.
- Do not rewrite old task queues.
- Do not assume old stopped ships are finished.
- Do not delete old files.

Acceptance:
- At least three legacy/fixture conditions classify without crashing.
- Missing files produce clear warnings.
- The fleet remains compatible with existing commands.
- Focused tests pass.

Proof:
Show compatibility test cases and output.
```

## Notes

This phase matters because the fleet already has real history. The state machine has to meet reality where it is.

## Implementation Status

Status: GREEN

Evidence:

- missing legacy repo classifies as `UNKNOWN` without crashing
- missing state file initializes a valid empty fleet state
- missing audit/task packet evidence remains a note, not a fatal error
- `.\tests\run-fleet-tests.ps1` passed
