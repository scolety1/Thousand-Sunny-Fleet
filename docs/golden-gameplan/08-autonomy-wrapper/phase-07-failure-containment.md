# Stage 8 Phase 7 Prompt: Failure Containment

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 8 Phase 7 only: Failure Containment.

Goal:
Make sure wrapper failures are contained to the selected ship and selected action.

Failure containment rules:
- one ship failure must not corrupt other ship reports
- failed action records BLOCK or REPAIR recommendation
- partial report is still written
- selected scope is preserved
- no manual lock deletion
- no process killing unless an existing approved safe process owns it
- no cleanup of user work

Failure cases to cover:
- missing state file
- invalid decision output
- audit package failure
- task packet validation failure
- run batch failure
- report write failure
- stale lock ambiguity
- dirty repo without active owner

Guardrails:
- Do not broaden scope after failure.
- Do not rerun repeatedly inside this phase.
- Do not hide failure behind PARK.

Acceptance:
- Fixture failure cases produce contained reports.
- Other selected ships continue only if safe.
- Wrapper exits with useful status code.

Proof:
Show failure-case report examples and tests.
```

## Notes

This phase prevents one messy ship from sinking the whole run.

## Implementation Status

Status: GREEN

Scope/config failures produce contained RED reports. Per-ship action failures become YELLOW with `failed-contained` status and do not broaden scope, delete locks, clean repos, or hide behind PARK.
