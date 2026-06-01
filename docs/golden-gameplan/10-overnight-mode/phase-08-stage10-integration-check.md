# Stage 10 Phase 8 Prompt: Stage 10 Integration Check

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 10 Phase 8 only: Stage 10 Integration Check.

Goal:
Verify overnight mode rules without launching real overnight work.

Use fixture scenarios to prove:
- healthy budget allows bounded work
- low budget blocks new work
- 3% critical budget triggers safe landing
- exhausted budget waits for reset
- configured reset window creates resume metadata
- recovered budget allows eligible resume
- blocked/taste-gated ships do not resume
- max resume attempts stop retry loops
- morning report can be generated

Guardrails:
- Do not launch real product ships.
- Do not schedule actual overnight automations.
- Do not touch downstream product repos.
- Do not implement Stage 11 specialized lanes.

Acceptance:
- Stage 10 focused tests pass.
- Safe landing and resume eligibility are proven with fixtures.
- Reports are generated.
- No unbounded schedule is created.

Proof:
Provide:
- test command output
- safe landing fixture report
- resume metadata example
- morning report example
- known limitations before Stage 11
```

## Notes

This check proves the sleep-safe logic without risking an actual night.

## Implementation Status

Status: GREEN

Focused Stage 10 tests live in `Test-GoldenGameplanStageTenSupport` inside
`tests/run-fleet-tests.ps1`. They use disposable fixtures only and do not
schedule real overnight work.
