# Fleet Remote Status

- Updated: 2026-05-06 20:21:36 Pacific Standard Time
- Fleet mode: PAUSED
- Mission hash: eceee7a8e41d
- Mission update: unchanged
- Emergency stop: none
- Supervisor cycle: 0
- Fleet branch: main
- Fleet HEAD: dbfc09c

## Projects
### EasyLife
- Branch: codex/product-EasyLife-20260504-231503
- HEAD: 6c3f62ff
- Working tree: dirty (1 files)
- Unchecked tasks: 5
- Phase: stage-0-ai-personal-assistant-reset
- Changed: ?? docs/codex/AI_ASSISTANT_STAGE_0_AUDIT.md

### RestaurantDemo
- Branch: codex/mission-RestaurantDemo-20260424-135732
- HEAD: c88229e
- Working tree: clean
- Unchecked tasks: 0
- Phase: phase-8-mobile-shift-mode

## Supervisor Summary
- EasyLife: BLOCKED_DIRTY; 6c3f62ff; dirty 1; tasks 5; lock stale PID 27236; OK: commits 0, quarantines 0, quality 0
- RestaurantDemo: LOOPING_QUALITY; c88229e; clean; tasks 0; lock stale PID 25072; OK: commits 0, quarantines 0, quality 0

## Controls
- Edit `fleet/control/mission.md` to change mission goals.
- Edit `fleet/control/run-mode.json` to pause, resume, or change active projects.
- Set `Emergency: STOP_ALL` in `fleet/control/emergency.md` for an all-hours cooperative stop.
