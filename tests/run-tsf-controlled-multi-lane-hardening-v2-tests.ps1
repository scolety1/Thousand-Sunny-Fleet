$ErrorActionPreference = "Stop"

$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$tool = Join-Path $repo "tools/Test-TsfParallelLanePlan.ps1"
$fixtureRoot = Join-Path $repo "tests/fixtures/fleet/project-main-bot/controlled_multi_lane_hardening_v2"
$outRoot = Join-Path $repo ".codex-local/controlled-multi-lane-hardening-v2-tests"
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) { throw "FAIL: $Message" }
    Write-Output "PASS: $Message"
}

function Invoke-Plan {
    param([string]$Name)
    $outFile = Join-Path $outRoot "$Name.result.json"
    & $tool -PlanPath (Join-Path $fixtureRoot "$Name.json") -OutFile $outFile | Out-Null
    Get-Content -Raw -LiteralPath $outFile | ConvertFrom-Json
}

$valid = Invoke-Plan -Name "valid-hardening-plan"
Assert-True ($valid.verdict -eq "GREEN") "valid hardening plan passes"
Assert-True ($valid.collision_status -eq "NO_COLLISION") "valid hardening plan has no collision"

$sameFile = Invoke-Plan -Name "same-file-write-collision"
Assert-True ($sameFile.verdict -eq "RED") "same-file collision fails closed"
Assert-True ($sameFile.collision_status -eq "COLLISION_DETECTED") "same-file collision records collision"

$overlap = Invoke-Plan -Name "overlapping-directory-collision"
Assert-True ($overlap.verdict -eq "RED") "overlapping directory collision fails closed"
Assert-True (($overlap.collisions -join ";") -match "overlaps") "overlapping directory collision records overlap"

$stale = Invoke-Plan -Name "stale-worktree"
Assert-True ($stale.verdict -eq "RED") "stale worktree fails closed"
Assert-True (($stale.blocked_reasons -join ";") -match "Unsafe worktree lifecycle state") "stale worktree records lifecycle blocker"

$orphaned = Invoke-Plan -Name "orphaned-lane-branch"
Assert-True ($orphaned.verdict -eq "RED") "orphaned lane branch fails closed"
Assert-True (($orphaned.blocked_reasons -join ";") -match "Unsafe branch lifecycle state") "orphaned branch records branch blocker"

$budget = Invoke-Plan -Name "worker-budget-exceeded"
Assert-True ($budget.verdict -eq "RED") "worker budget exceeded fails closed"
Assert-True (($budget.blocked_reasons -join ";") -match "Worker invocation budget exceeded") "worker budget exceeded records blocker"

Write-Output "Controlled multi-lane hardening V2 tests passed."
