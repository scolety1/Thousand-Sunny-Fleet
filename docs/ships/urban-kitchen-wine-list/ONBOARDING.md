# Urban Kitchen Wine List Ship Onboarding

## Assumed Ship

Ship name:
`UrbanKitchenWineList`

Expected repo path:
`C:\Dev\urban-kitchen-wine-list`

Profile:
`frontend-static-demo`

Build directory:
`.`

Build command:
`npm.cmd run build`

## Add To Fleet

After the repo exists locally and is clean:

```powershell
cd C:\Dev\codex-fleet
.\add-project.ps1 -Name UrbanKitchenWineList -Repo C:\Dev\urban-kitchen-wine-list -Profile frontend-static-demo -BuildDirectory . -BuildCommand "npm.cmd run build"
```

Copy these files into the repo:

```txt
docs/codex/MISSION.md
docs/codex/TASK_QUEUE.md
docs/codex/RUN_POLICY.md
```

Then prove the ship:

```powershell
.\run-checkpoint-loop.ps1 -Project UrbanKitchenWineList -BatchSize 1 -MaxBatches 1 -VisualEvery 1
```

If clean:

```powershell
.\run-checkpoint-loop.ps1 -Project UrbanKitchenWineList -BatchSize 2 -MaxBatches 4 -VisualEvery 2
```

## Priority

This ship is meant to be shown to wine people. The standard is higher than a rough demo:

- mobile-first
- fast to understand
- wine descriptions polished
- Help Me Decide flow excellent
- no broken UI
- no fake claims
- no backend, auth, payment, analytics, tracking, or secrets
