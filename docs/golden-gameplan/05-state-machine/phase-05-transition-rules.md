# Stage 5 Phase 5 Prompt: Transition Rules

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 5 Phase 5 only: Transition Rules.

Goal:
Document and validate legal state transitions.

Create a transition map for the canonical states.

Examples:
- READY -> RUNNING
- RUNNING -> REVIEWING
- RUNNING -> REPAIRING
- RUNNING -> BLOCKED
- RUNNING -> RATE_LIMIT_PAUSED
- REVIEWING -> AUDIT_READY
- AUDIT_READY -> PACKET_READY
- PACKET_READY -> READY
- REPAIRING -> RUNNING
- REPAIRING -> BLOCKED
- TASTE_GATE -> READY after user-approved task packet
- RATE_LIMIT_PAUSED -> READY after reset or safe resume signal
- PARKED -> READY after new approved tasks
- any state -> ARCHIVED only by explicit human/approved command

Guardrails:
- Do not implement the decision engine.
- Do not automatically move ships between states based on policy.
- This phase may validate that a requested transition is legal, but should not decide whether to request it.
- Do not launch ships.

Acceptance:
- Transition map exists in docs and machine-readable form if useful.
- Illegal transitions are rejected by tests or validation.
- Legal transitions are accepted.
- The rules explain why RATE_LIMIT_PAUSED exists but defer reset behavior to overnight/rate-limit stages.

Proof:
Show transition validation examples and focused test output.
```

## Notes

The transition map should prevent accidental jumps like BLOCKED -> RUNNING without repair evidence.

## Implementation Status

Status: GREEN

Evidence:

- `templates/ship-state-transition-map.json`
- `Test-FleetShipStateTransition`
- `READY -> RUNNING` accepted
- `ARCHIVED -> RUNNING` rejected
- `.\tests\run-fleet-tests.ps1` passed
