# Golden Gameplan Stage 12 Audit Prompt

Use this prompt after Stage 12 is implemented and tested.

```text
You are auditing Codex Fleet Golden Gameplan Stage 12: Dashboard and Control Room.

Goal of Stage 12:
The fleet should have a clear control-room design that lets the captain understand ship state, decisions, lanes, blockers, budgets, audit packages, task packets, and next safe commands without digging through terminals.

Please review the docs, view specs, examples, fixture mappings, and checkpoint.

Audit questions:

1. Does the first screen answer what is running, blocked, needs user input, and safe to run next?
2. Are running, blocked, parked, taste-gated, audit-ready, packet-ready, and rate-paused ships clearly distinct?
3. Does each view map to real Stage 2-11 artifacts?
4. Is the overview concise rather than overwhelming?
5. Does the Ship Detail view explain why a ship is in its state?
6. Are blockers, repairs, and taste gates separated correctly?
7. Is rate/budget/overnight status honest and conservative?
8. Are audit packages and task packets traceable?
9. Are safe command suggestions helpful without being dangerous?
10. Is the design usable from a phone as a summary?

Return:

- Overall verdict: PASS, PASS WITH FIXES, or FAIL.
- Top 5 issues, ordered by severity.
- Any missing view.
- Any confusing status language.
- Any unsafe command suggestion.
- Recommended fixes before Stage 13.

Do not recommend implementing a full web UI unless the specs are clear enough.
```

