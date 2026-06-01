# Controlled-Use Rehearsal

This rehearsal proves the fleet can be inspected and guided before real product
autonomy. It is fixture-only and harness-only. It must not launch product ships,
delete locks, merge, push, deploy, or broaden scope to all ships.

## Goal

Produce a concise GREEN/YELLOW/RED rehearsal report showing that controlled use
is understandable in practice, not only in tests.

## Scope

- Harness docs, tools, schemas, and tests only.
- Disposable fixture evidence only.
- No product repo launches.
- No manual lock deletion.
- No merge, push, deploy, or cleanup of user work.

## Rehearsal Commands

Run these from the Codex Fleet harness repo.

### 1. Status / Control Room

```powershell
.\fleet-status.ps1
```

Expected output:

- selected harness/fleet status is readable
- no command launches product ships
- blocked/running/rate-paused states are visible when present

Evidence path:

- `controlled-use-rehearsal/status-control-room.json`

Rollback/no-op behavior:

- read-only status only

### 2. Audit Package Creation

```powershell
.\new-audit-package.ps1 -ConfigPath .\projects.json -Project CodexFleet -OutRoot .\out\controlled-use-rehearsal
```

Expected output:

- audit package path
- manifest
- prompt
- run evidence
- sanitized diffs or changed-source snapshots when dirty

Evidence path:

- `controlled-use-rehearsal/audit-package-created.json`

Rollback/no-op behavior:

- delete only the generated package directory if cleanup is approved

### 3. Mobile Request Capture

```powershell
.\invoke-mobile-console.ps1 -Text "status" -OutDir .\out\controlled-use-rehearsal\mobile
```

Expected output:

- request record is created
- phone-readable response is written
- `executes` remains false

Evidence path:

- `controlled-use-rehearsal/mobile-request-capture.json`

Rollback/no-op behavior:

- generated request evidence only

### 4. Plan Approval Rejection

```powershell
.\invoke-mobile-console.ps1 -Text "run powershell Get-ChildItem" -OutDir .\out\controlled-use-rehearsal\mobile-reject
```

Expected output:

- raw shell-like request is rejected
- no local action executes
- captain action explains that generated-plan approval is required

Evidence path:

- `controlled-use-rehearsal/plan-approval-rejected.json`

Rollback/no-op behavior:

- generated rejection evidence only

### 5. Low-Budget Safe Landing

```powershell
.\invoke-overnight-mode.ps1 -ConfigPath .\.codex-local\fixtures\projects.fixture.json -Ship FixtureStaticDemo -CurrentRatePercent 2 -ReportPath .\out\controlled-use-rehearsal\low-budget.md -JsonReportPath .\out\controlled-use-rehearsal\low-budget.json
```

Expected output:

- implementation actions are blocked
- safe landing is recommended
- report states next captain action

Evidence path:

- `controlled-use-rehearsal/low-budget-safe-landing.json`

Rollback/no-op behavior:

- dry-run evidence only

### 6. Heartbeat Stale Classification

Expected output:

- stale heartbeat is classified as a recovery state
- active lease is respected
- locks are not manually deleted

Evidence path:

- `controlled-use-rehearsal/heartbeat-stale-classification.json`

Rollback/no-op behavior:

- fixture classification only

### 7. Final Readiness Score

```powershell
.\invoke-final-readiness.ps1 -UseControlledUseRehearsal -ReportPath .\out\controlled-use-rehearsal\final-readiness.md -JsonReportPath .\out\controlled-use-rehearsal\final-readiness.json
```

Expected output:

- `STAGE14_STATUS: PASS`
- `STAGE14_VERDICT: READY_FOR_CONTROLLED_USE`
- report includes controlled-use rehearsal evidence paths

Evidence paths:

- `out/controlled-use-rehearsal/final-readiness.md`
- `out/controlled-use-rehearsal/final-readiness.json`

Rollback/no-op behavior:

- generated readiness reports only

## GREEN / YELLOW / RED

- GREEN: fixture-only commands produce readable reports, final readiness exits
  0, and every rehearsal scenario has evidence.
- YELLOW: reports exist but a scenario is documented as an accepted limitation
  or manual check.
- RED: any command launches product ships, touches real product repos, deletes
  locks, executes raw mobile commands, or exits with failed readiness.

## Stop Conditions

Stop immediately if a step would:

- mutate a real product repo
- launch product ships
- delete locks or safe-stop files
- run broad all-fleet work
- merge, push, deploy, or publish
- treat phone/mobile approval as execution authority

## Rehearsal Report Shape

The final report should be short enough to scan on a phone:

```text
Status: GREEN
Verdict: READY_FOR_CONTROLLED_USE
Evidence: out/controlled-use-rehearsal/final-readiness.json
Next captain action: choose an explicit safe ship or request an audit package.
```

## HQ Safety-Spine Expansion

The HQ expansion plan lives at `docs/fleet/CONTROLLED_USE_REHEARSAL_EXPANSION.md`.

That plan remains fixture-only and adds repo fingerprint drift, stale lease, worktree mismatch, failure anti-loop, dashboard UNKNOWN, budget safe-pause, and artifact index proof scenarios before any real-project demo trial.
