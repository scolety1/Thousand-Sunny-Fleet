# Overnight Stage Run Prompt

Use this when the goal is to finish a bounded Golden Gameplan stage range while the captain is away.

This prompt is intentionally different from the single-phase prompt. It does not stop just because a phase is YELLOW or RED. It records the blocker, keeps moving inside the approved stage range, and leaves a repair list for the morning.

```text
Continue the Golden Gameplan through Stage 4 only.

Rules:
- Read docs/golden-gameplan/README.md first.
- Read docs/golden-gameplan/00-overview/dependency-map.md and safety-rules.md.
- Start at the earliest unfinished Golden Gameplan phase.
- Implement, test, patch, and document one phase at a time.
- Continue through Stage 1, Stage 2, Stage 3, and Stage 4 only.
- Do not begin Stage 5.
- Do not stop just because a phase is YELLOW or RED.
- If a phase is GREEN, mark it complete and continue.
- If a phase is YELLOW, record the warning, mark the phase YELLOW, add a morning repair note, and continue unless it blocks the next phase technically.
- If a phase is RED, record the failure, mark the phase RED, add a morning repair note, and continue unless it creates a safety risk or makes the next phase impossible.
- Only stop early for: possible user-work loss, destructive file operations, real product repo changes, unsafe lock deletion, secrets/auth/payments/deploy risk, missing required Golden Gameplan docs, or a test failure that prevents PowerShell from parsing/running the fleet at all.
- Do not touch real product repos.
- Do not launch product ships unless a phase explicitly requires a disposable fixture/safe test.
- Do not merge, push, deploy, delete user work, or manually delete locks.
- After each phase, update the phase/checkpoint docs with status, evidence, blockers, and morning repair notes.
- After each completed stage, run that stage checkpoint if it exists.
- If all phases through Stage 4 are attempted, create a Stage 1-4 audit package and audit prompt.

Report:
- Last attempted stage and phase
- Completed GREEN phases
- YELLOW phases and why
- RED phases and why
- Files changed
- Tests run
- Checkpoints completed
- Whether the Stage 1-4 audit package was created
- Morning repair list
- Next prompt I should send
```

## Captain Intent

For overnight runs, progress beats perfect stopping. The fleet should finish the approved stage range and leave an honest repair list, not stall at Stage 1 Phase 8 because one non-dangerous check went yellow.

