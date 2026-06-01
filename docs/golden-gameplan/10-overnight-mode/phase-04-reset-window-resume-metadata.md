# Stage 10 Phase 4 Prompt: Reset Window And Resume Metadata

## Prompt To Send To Codex

```text
Implement Golden Gameplan Stage 10 Phase 4 only: Reset Window and Resume Metadata.

Goal:
Define how the fleet records when it may resume after limits reset.

Support two reset modes:
- configured reset window
- confirmed recovered budget signal

Resume metadata should include:
- pausedAt
- pauseReason
- budgetLevelAtPause
- estimatedResetAt
- resetSource
- selectedShips
- resumableShips
- nonResumableShips
- lastDecision
- lastSafeAction
- lastEvidencePath
- maxResumeAttempts
- resumeAttemptsUsed

Reset source values:
- manual_config
- local_status_signal
- user_confirmed
- unknown

Guardrails:
- Do not pretend exact reset times are known if they are not.
- Do not resume from unknown state.
- Do not overwrite old resume records.
- Do not launch ships.

Acceptance:
- Resume metadata schema is documented.
- Examples cover configured reset, unknown reset, and confirmed recovered budget.
- The metadata supports morning review.

Proof:
Show schema/example paths and sample records.
```

## Notes

This is how we avoid "it stopped and I have no idea when or why."

## Implementation Status

Status: GREEN

Implemented by Stage 10 resume metadata output in `invoke-overnight-mode.ps1`.
The metadata records pause reason, selected/resumable ships, evidence path,
resume attempts, and reset status without pretending a configured reset window
is proof of recovered model budget.
