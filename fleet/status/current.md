# Fleet Remote Status

- Updated: 2026-05-06 23:22:49 Pacific Standard Time
- Fleet mode: PAUSED
- Mission hash: 368753b3d5eb
- Mission update: unchanged
- Emergency stop: none
- Supervisor cycle: 0
- Fleet branch: main
- Fleet HEAD: ebed049

## Projects
### Bottlelight
- Branch: master
- HEAD: b4edeed
- Working tree: clean
- Unchecked tasks: 1
- Phase: repair
- Next workflow: frontend-ui-engineering (inferred)

### EasyLife
- Branch: codex/product-EasyLife-20260504-231503
- HEAD: 3fadf3a8
- Working tree: clean
- Unchecked tasks: 8
- Phase: stage-0-ai-personal-assistant-reset
- Next workflow: incremental-implementation (inferred)

### EventBook
- Branch: master
- HEAD: 0046036
- Working tree: clean
- Unchecked tasks: 3
- Phase: repair
- Next workflow: debugging-and-error-recovery (inferred)

### LineupLab
- Branch: master
- HEAD: 3b04cff
- Working tree: clean
- Unchecked tasks: 4
- Phase: repair
- Next workflow: frontend-ui-engineering (inferred)

### OrderPilot
- Branch: master
- HEAD: f6b1e7f
- Working tree: clean
- Unchecked tasks: 0
- Phase: repair
- Next workflow: none

### RestaurantDemo
- Branch: codex/mission-RestaurantDemo-20260424-135732
- HEAD: 4cb865d
- Working tree: clean
- Unchecked tasks: 6
- Phase: phase-8-mobile-shift-mode
- Next workflow: incremental-implementation (inferred)

### ShiftLedger
- Branch: master
- HEAD: bd98577
- Working tree: clean
- Unchecked tasks: 1
- Phase: repair
- Next workflow: frontend-ui-engineering (inferred)

### UrbanKitchenSite
- Branch: master
- HEAD: f78d405
- Working tree: clean
- Unchecked tasks: 0
- Phase: shape
- Next workflow: none

## Supervisor Summary
- Bottlelight: LOOPING_QUALITY; b4edeed; clean; tasks 1; lock none; OK: commits 3, quarantines 1, quality 1
- EasyLife: LOOPING_QUALITY; 3fadf3a8; clean; tasks 8; lock none; OK: commits 0, quarantines 1, quality 0
- EventBook: LOOPING_QUALITY; 0046036; clean; tasks 3; lock none; OK: commits 1, quarantines 0, quality 1
- LineupLab: LOOPING_QUALITY; 3b04cff; clean; tasks 4; lock none; OK: commits 0, quarantines 1, quality 1
- OrderPilot: LOOPING_QUALITY; f6b1e7f; clean; tasks 0; lock none; OK: commits 4, quarantines 0, quality 0
- RestaurantDemo: LOOPING_QUALITY; 4cb865d; clean; tasks 6; lock idle shell PID 25640; OK: commits 0, quarantines 1, quality 1
- ShiftLedger: LOOPING_QUALITY; bd98577; clean; tasks 1; lock none; OK: commits 3, quarantines 1, quality 0
- UrbanKitchenSite: IDLE_READY; f78d405; clean; tasks 0; lock none; OK: commits 4, quarantines 0, quality 0

## Controls
- Edit `fleet/control/mission.md` to change mission goals.
- Edit `fleet/control/run-mode.json` to pause, resume, or change active projects.
- Set `Emergency: STOP_ALL` in `fleet/control/emergency.md` for an all-hours cooperative stop.
