# Stage 13 Phase 6 Prompt: Mobile Digest

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 13 Phase 6 only: Mobile Digest.

Goal:
Define the compact digest the user receives after a run window or on request.

Digest sections:
- headline
- wins
- failures
- blockers
- taste decisions needed
- rate/budget status
- safe next commands
- links/paths to full reports

Digest variants:
- quick digest
- overnight digest
- ship-specific digest
- audit-ready digest
- low-budget digest

Guardrails:
- No giant pasted logs.
- No fake certainty.
- No "all good" if there are blockers.
- Do not implement delivery.

Acceptance:
- Mobile digest template exists.
- Examples exist for successful, partially failed, taste-gated, and low-budget nights.
- Digest is short enough to read on a phone.

Proof:
Show digest template and examples.
```

## Notes

This should be what the user reads between classes, meetings, or trips.

## Implemented Digest Template

```text
Digest: Running: 1 | Needs captain: 2 | Blocked/repair: 1 | Safe to inspect: 1 | Budget: critical -> SAFE_LAND_NOW
Wins: Bottlelight is safe to inspect.
Failures: 1 blocker/repair item(s)
Taste: 1 decision(s)
Budget: critical -> SAFE_LAND_NOW
Next: Review blocker/repair board first.
Full report: out/stage12/control-room.json
```

Variants:

- Quick digest: generated from Stage 12 snapshot.
- Overnight digest: includes Stage 10 budget/safe landing state.
- Ship-specific digest: use the ship detail fields from Stage 12.
- Audit-ready digest: highlights latest audit package.
- Low-budget digest: leads with budget action and avoids new work.

Digest rule: never say "all good" when blocker, taste, packet, or budget boards
need attention.
