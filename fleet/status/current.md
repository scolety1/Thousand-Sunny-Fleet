# Fleet Remote Status

- Updated: 2026-05-07 01:00:04 Pacific Standard Time
- Fleet mode: ACTIVE
- Mission hash: 4250045fc94c
- Mission update: unchanged
- Emergency stop: none
- Supervisor cycle: 0
- Fleet branch: main
- Fleet HEAD: 443bf71

## Projects
### Bottlelight
- Branch: master
- HEAD: c3127e7
- Working tree: clean
- Unchecked tasks: 2
- Phase: repair
- Next workflow: frontend-ui-engineering (inferred)

### EasyLife
- Branch: codex/product-EasyLife-20260504-231503
- HEAD: a2420e49
- Working tree: clean
- Unchecked tasks: 9
- Phase: stage-0-ai-personal-assistant-reset
- Next workflow: planning-and-task-breakdown (inferred)

### EventBook
- Branch: master
- HEAD: 093cd32
- Working tree: clean
- Unchecked tasks: 4
- Phase: repair
- Next workflow: debugging-and-error-recovery (inferred)

### LineupLab
- Branch: master
- HEAD: eedd55b
- Working tree: clean
- Unchecked tasks: 5
- Phase: repair
- Next workflow: frontend-ui-engineering (inferred)

### OrderPilot
- Branch: master
- HEAD: 4dfe9be
- Working tree: dirty (5 files)
- Unchecked tasks: 1
- Phase: repair
- Next workflow: debugging-and-error-recovery
- Changed:  M docs/codex/MAGIC_SCORECARD.md;  M docs/codex/NIGHTLY_REPORT.md; M  docs/codex/PRODUCT_TRUTH_REVIEW.md; A  docs/codex/RUNTIME_VERIFICATION.md

### RestaurantDemo
- Branch: codex/mission-RestaurantDemo-20260424-135732
- HEAD: 847717d
- Working tree: clean
- Unchecked tasks: 7
- Phase: phase-8-mobile-shift-mode
- Next workflow: planning-and-task-breakdown (inferred)

### ShiftLedger
- Branch: master
- HEAD: 8bb0f2d
- Working tree: clean
- Unchecked tasks: 2
- Phase: repair
- Next workflow: frontend-ui-engineering (inferred)

### UrbanKitchenSite
- Branch: master
- HEAD: 52c3dc1
- Working tree: clean
- Unchecked tasks: 0
- Phase: shape
- Next workflow: none

## Supervisor Summary
- Bottlelight: LOOPING_QUALITY; c3127e7; clean; tasks 2; lock none; OK: commits 3, quarantines 3, quality 3
- EasyLife: LOOPING_QUALITY; a2420e49; clean; tasks 9; lock none; OK: commits 1, quarantines 4, quality 0
- EventBook: LOOPING_QUALITY; 093cd32; clean; tasks 4; lock none; OK: commits 2, quarantines 1, quality 3
- LineupLab: LOOPING_QUALITY; eedd55b; clean; tasks 5; lock none; OK: commits 1, quarantines 2, quality 2
- OrderPilot: BLOCKED_DIRTY; 4dfe9be; dirty 5; tasks 1; lock stale PID 12868; OK: commits 4, quarantines 1, quality 1
- RestaurantDemo: LOOPING_QUALITY; 847717d; clean; tasks 7; lock none; OK: commits 2, quarantines 2, quality 1
- ShiftLedger: LOOPING_QUALITY; 8bb0f2d; clean; tasks 2; lock none; OK: commits 3, quarantines 3, quality 2
- UrbanKitchenSite: LOOPING_QUALITY; 52c3dc1; clean; tasks 0; lock none; OK: commits 5, quarantines 2, quality 1

## Controls
- Edit `fleet/control/mission.md` to change mission goals.
- Edit `fleet/control/run-mode.json` to pause, resume, or change active projects.
- Set `Emergency: STOP_ALL` in `fleet/control/emergency.md` for an all-hours cooperative stop.
