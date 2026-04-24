# Urban Kitchen Wine List Run Policy

## Profile

Use:
`frontend-static-demo`

This is a frontend-only wine list site intended for in-person showing.

## Build

Build directory:
`.`

Build command:

```powershell
npm.cmd run build
```

## First Proof Run

```powershell
cd C:\Dev\codex-fleet
.\run-checkpoint-loop.ps1 -Project UrbanKitchenWineList -BatchSize 1 -MaxBatches 1 -VisualEvery 1
```

## School Run

After the first proof passes:

```powershell
.\run-checkpoint-loop.ps1 -Project UrbanKitchenWineList -BatchSize 2 -MaxBatches 4 -VisualEvery 2
```

## Stop Conditions

Stop if:

- build fails
- visual smoke fails
- repo is dirty after a run
- forbidden files change
- package/dependency files change
- backend/auth/payment/API/analytics/tracking appears
- wine copy becomes generic or misleading
- Help Me Decide becomes confusing

## Human Review

Before merging, inspect:

- mobile first screen
- wine list cards
- wine filters/search
- Help Me Decide flow
- selected wine detail
- no-results state
- contact or restaurant info area if present

This ship should not merge until it feels good enough to show wine people.
