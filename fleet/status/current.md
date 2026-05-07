# Fleet Remote Status

- Updated: 2026-05-06 21:00:49 Pacific Standard Time
- Fleet mode: ACTIVE
- Mission hash: e7504dbeb3c0
- Mission update: accepted
- Emergency stop: none
- Supervisor cycle: 0
- Fleet branch: main
- Fleet HEAD: 902731f

## Projects
### Bottlelight
- Branch: master
- HEAD: 24cb828
- Working tree: clean
- Unchecked tasks: 4
- Phase: repair

### EasyLife
- Branch: codex/product-EasyLife-20260504-231503
- HEAD: 0e4d370b
- Working tree: clean
- Unchecked tasks: 8
- Phase: stage-0-ai-personal-assistant-reset

### EventBook
- Branch: master
- HEAD: 3918ecb
- Working tree: dirty (3 files)
- Unchecked tasks: 4
- Phase: repair
- Changed:  M docs/codex/INFORMATION_STAGING.md;  M index.html;  M src/styles.css

### LineupLab
- Branch: master
- HEAD: fb9ae61
- Working tree: dirty (4 files)
- Unchecked tasks: 4
- Phase: repair
- Changed:  M docs/codex/INFORMATION_STAGING.md;  M docs/codex/SITE_MAP.md;  M docs/codex/visual-routes.json;  M src/styles.css

### OrderPilot
- Branch: master
- HEAD: bded2e9
- Working tree: dirty (3 files)
- Unchecked tasks: 4
- Phase: repair
- Changed:  M docs/codex/INFORMATION_STAGING.md;  M index.html;  M src/styles.css

### RestaurantDemo
- Branch: codex/mission-RestaurantDemo-20260424-135732
- HEAD: 43ac198
- Working tree: clean
- Unchecked tasks: 6
- Phase: phase-8-mobile-shift-mode

### ShiftLedger
- Branch: master
- HEAD: 5bc6c02
- Working tree: clean
- Unchecked tasks: 4
- Phase: repair

### UrbanKitchenSite
- Branch: master
- HEAD: 7cd5824
- Working tree: dirty (1 files)
- Unchecked tasks: 4
- Phase: shape
- Changed:  M index.html

## Supervisor Summary
- Bottlelight: LOOPING_QUALITY; 24cb828; clean; tasks 4; lock active PID 21408; OK: commits 0, quarantines 0, quality 0
- EasyLife: LOOPING_QUALITY; 0e4d370b; clean; tasks 8; lock active PID 24204; OK: commits 0, quarantines 1, quality 0
- EventBook: LOOPING_QUALITY; 3918ecb; dirty 3; tasks 4; lock active PID 23548; OK: commits 0, quarantines 0, quality 0
- LineupLab: LOOPING_QUALITY; fb9ae61; dirty 4; tasks 4; lock active PID 20064; OK: commits 0, quarantines 0, quality 0
- OrderPilot: LOOPING_QUALITY; bded2e9; dirty 3; tasks 4; lock active PID 22812; OK: commits 0, quarantines 0, quality 0
- RestaurantDemo: LOOPING_QUALITY; 43ac198; clean; tasks 6; lock active PID 25640; OK: commits 0, quarantines 1, quality 0
- ShiftLedger: LOOPING_QUALITY; 5bc6c02; clean; tasks 4; lock active PID 14316; OK: commits 0, quarantines 0, quality 0
- UrbanKitchenSite: PROGRESSING; 7cd5824; dirty 1; tasks 4; lock active PID 14216; OK: commits 0, quarantines 0, quality 0

## Controls
- Edit `fleet/control/mission.md` to change mission goals.
- Edit `fleet/control/run-mode.json` to pause, resume, or change active projects.
- Set `Emergency: STOP_ALL` in `fleet/control/emergency.md` for an all-hours cooperative stop.
