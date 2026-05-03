# Fleet Parked Handoff - 2026-05-03

## Current Parked State

- Global safe stop is active: `.codex-local/stop-requests/ALL.stop.json`
- Heartbeat automation `whole-fleet-overnight-run` is not installed.
- Preview stop was requested with `.\stop-ship-previews.ps1`.
- `.\fleet-status.ps1` showed every configured ship clean, with no run locks and no unchecked tasks.

## Clean Ships At Park Time

- Bottlelight
- CursorPets
- EasyLife
- EventBook
- FinanceDecisionLab
- ForecastLab
- LifeCapacity
- LineupLab
- NinersWarRoom
- OrderPilot
- RestaurantDemo
- RestaurantProfitLab
- ShiftLedger
- ShiftPlate
- Tree
- UrbanKitchenSite

## Next Restart Order

0. Token Efficiency System: add per-ship `CURRENT_STATE.md`, `RUNBOOK.md`, task packet templates, visual QA checklists, decision defaults, and focused squad launch presets so normal coding uses fewer tokens without lowering quality.
1. EasyLife: phone-first polish, command/email flow, real daily-use usefulness.
2. Formula-heavy labs: ForecastLab, LifeCapacity, RestaurantProfitLab, FinanceDecisionLab.
3. Cellar fleet: depth passes and visual proof only, especially guest-facing hospitality pages.
4. NinersWarRoom: high-value formula/data refinements.
5. Remaining demos only after the above are stable.

## Restart Checklist

Run this before any launch:

```powershell
Set-Location C:\Dev\codex-fleet
.\fleet-status.ps1
```

Only relaunch if:

- No user rate-limit warning is active.
- No dirty stopped ship exists.
- The user explicitly wants the fleet running again.

If restarting a focused run, prefer targeted ships over the full fleet:

```powershell
# Example: only when rate limits are healthy again
.\launch-overnight-run.ps1
```

## Do Not Spend Rate On

- Broad status polling when no launch is planned.
- Re-reading full logs unless a ship is dirty or failed.
- Re-running visual checks for every ship by default.
- Creating new docs unless they become launch instructions or gates.
- Rebuilding clean ships without changed files.
