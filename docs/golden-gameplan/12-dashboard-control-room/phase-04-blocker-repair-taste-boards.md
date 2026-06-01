# Stage 12 Phase 4 Prompt: Blocker, Repair, And Taste Boards

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 12 Phase 4 only: Blocker, Repair, and Taste Boards.

Goal:
Define focused boards for the things that should stop autonomy.

Create specs for:
- Blocker Board
- Repair Board
- Taste Gate Board

Blocker Board should show:
- ship
- blocker type
- severity
- evidence
- required human input
- forbidden action

Repair Board should show:
- ship
- failed gate
- repair task status
- attempt count
- next safe repair action

Taste Gate Board should show:
- ship
- what passed
- what is subjective
- screenshots/evidence
- captain question

Guardrails:
- Blocked ships must not appear as runnable.
- Taste gate must not be treated as failure.
- Repair attempts must show limits.
- Do not implement UI code.

Acceptance:
- Board specs exist.
- Examples include backend-sensitive block, formula block, broken build repair, and visual taste gate.

Proof:
Show board spec paths and examples.
```

## Notes

This is where the dashboard protects the user's attention and the fleet's safety.

## Implemented Boards

### Blocker Board

Fields:

```text
ship, state, blocker, suggested action, evidence
```

Backend-sensitive example:

```text
Ship: AuthLedger
State: BLOCKED
Blocker: touches auth/payment/deploy scope
Suggested action: Request approval / write blocker note
Forbidden action: run bounded batch before approval evidence exists
```

Analytical formula example:

```text
Ship: FrankyModel
State: BLOCKED
Blocker: formula fixture expectation missing
Suggested action: Write repair task
Forbidden action: claim model confidence without deterministic proof
```

### Repair Board

Fields:

```text
ship, failed gate, repair task status, attempt count, next safe repair action
```

Broken build example:

```text
State: REPAIRING
Action: Continue bounded repair if attempts remain
Forbidden if: repair attempt budget is exhausted
```

### Taste Gate Board

Fields:

```text
ship, what passed, subjective question, screenshots/evidence
```

Visual taste example:

```text
State: TASTE_GATE
Question: Is this refined enough for the restaurant brand?
Action: Request taste review
Forbidden action: keep polishing without captain taste input
```
