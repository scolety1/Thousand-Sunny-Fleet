# Stage 5 Phase 2 Prompt: Current State Files

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 5 Phase 2 only: Current State Files.

Goal:
Create the file layout and templates for fleet-level and per-ship current state.

Required outputs:
- fleet/state/ship-state.json
- per-ship docs/codex/CURRENT_STATE.md template
- optional per-ship docs/codex/CURRENT_STATE.json if it makes implementation cleaner

The fleet-level file should summarize all active ships.
The per-ship file should be readable by a human captain from a phone.

CURRENT_STATE.md should include:
- Current status
- Previous status
- Last updated
- Current phase or lane
- Last run result
- Latest audit package
- Latest accepted task packet
- Active blockers
- Taste gate notes
- Rate-limit pause notes
- Next safe human action

Guardrails:
- Do not launch ships.
- Do not make state decisions beyond writing templates.
- Do not overwrite existing project-specific notes without preserving them.
- Do not touch real downstream app code.

Acceptance:
- Templates exist.
- A fixture ship can receive a generated CURRENT_STATE.md without breaking existing docs.
- The fleet-level file can represent multiple ships.
- Paths are normalized for Windows.

Proof:
Show created files and a sample generated fixture state.
```

## Notes

The human-readable state file is important because the user often asks status questions from the phone.

## Implementation Status

Status: GREEN

Evidence:

- `fleet/state/ship-state.json`
- `docs/codex/CURRENT_STATE.md`
- `fleet/status/current.md`
- `.\tests\run-fleet-tests.ps1` passed
