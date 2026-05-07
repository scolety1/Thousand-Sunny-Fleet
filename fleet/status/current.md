# Fleet Remote Status

- Updated: 2026-05-06 23:35:46 Pacific Standard Time
- Fleet mode: ACTIVE
- Mission hash: 4250045fc94c
- Mission update: accepted
- Emergency stop: none
- Supervisor cycle: 0
- Fleet branch: main
- Fleet HEAD: 0463193

## Projects
### Bottlelight
- Branch: master
- HEAD: 54b727e
- Working tree: clean
- Unchecked tasks: 2
- Phase: repair
- Next workflow: frontend-ui-engineering

### EasyLife
- Branch: codex/product-EasyLife-20260504-231503
- HEAD: 67d77e92
- Working tree: dirty (1 files)
- Unchecked tasks: 10
- Phase: stage-0-ai-personal-assistant-reset
- Next workflow: frontend-ui-engineering
- Changed:  M app-vNext/src/components/navigation/appProducts.ts

### EventBook
- Branch: master
- HEAD: d0be80b
- Working tree: clean
- Unchecked tasks: 4
- Phase: repair
- Next workflow: frontend-ui-engineering

### LineupLab
- Branch: master
- HEAD: cbba9d7
- Working tree: clean
- Unchecked tasks: 5
- Phase: repair
- Next workflow: frontend-ui-engineering

### OrderPilot
- Branch: master
- HEAD: 0f1bf64
- Working tree: clean
- Unchecked tasks: 1
- Phase: repair
- Next workflow: code-review-and-quality

### RestaurantDemo
- Branch: codex/mission-RestaurantDemo-20260424-135732
- HEAD: ebac0fd
- Working tree: clean
- Unchecked tasks: 8
- Phase: phase-8-mobile-shift-mode
- Next workflow: frontend-ui-engineering

### ShiftLedger
- Branch: master
- HEAD: 58989a3
- Working tree: clean
- Unchecked tasks: 2
- Phase: repair
- Next workflow: frontend-ui-engineering

### UrbanKitchenSite
- Branch: master
- HEAD: de18f07
- Working tree: clean
- Unchecked tasks: 1
- Phase: shape
- Next workflow: code-review-and-quality

## Supervisor Summary
- Bottlelight: LOOPING_QUALITY; 54b727e; clean; tasks 2; lock none; OK: commits 3, quarantines 1, quality 1
- EasyLife: LOOPING_QUALITY; 67d77e92; dirty 1; tasks 10; lock active PID 8380; OK: commits 0, quarantines 2, quality 0
- EventBook: LOOPING_QUALITY; d0be80b; clean; tasks 4; lock none; OK: commits 1, quarantines 0, quality 1
- LineupLab: LOOPING_QUALITY; cbba9d7; clean; tasks 5; lock none; OK: commits 0, quarantines 1, quality 1
- OrderPilot: LOOPING_QUALITY; 0f1bf64; clean; tasks 1; lock none; OK: commits 4, quarantines 0, quality 0
- RestaurantDemo: LOOPING_QUALITY; ebac0fd; clean; tasks 8; lock active PID 408; OK: commits 0, quarantines 2, quality 1
- ShiftLedger: LOOPING_QUALITY; 58989a3; clean; tasks 2; lock none; OK: commits 3, quarantines 1, quality 0
- UrbanKitchenSite: READY; de18f07; clean; tasks 1; lock none; OK: commits 4, quarantines 0, quality 0

## Controls
- Edit `fleet/control/mission.md` to change mission goals.
- Edit `fleet/control/run-mode.json` to pause, resume, or change active projects.
- Set `Emergency: STOP_ALL` in `fleet/control/emergency.md` for an all-hours cooperative stop.
