$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$workRoot = Join-Path $repoRoot ".codex-local\parallel-lane-dry-run-tests"
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

function Assert-Lane {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}

$validOut = Join-Path $workRoot "valid.json"
$valid = & (Join-Path $repoRoot "tools\Test-TsfParallelLanePlan.ps1") -PlanPath (Join-Path $repoRoot "tests\fixtures\fleet\project-main-bot\parallel_lane_plans\true-parallel-plan.valid.json") -OutFile $validOut
Assert-Lane ($valid.verdict -eq "GREEN") "true parallel dry-run valid plan passes"
Assert-Lane ($valid.worktrees_created -eq $false) "valid dry-run creates no worktrees"
Assert-Lane ($valid.workers_spawned -eq $false) "valid dry-run spawns no workers"

$collisionOut = Join-Path $workRoot "collision.json"
$collision = & (Join-Path $repoRoot "tools\Test-TsfParallelLanePlan.ps1") -PlanPath (Join-Path $repoRoot "tests\fixtures\fleet\project-main-bot\parallel_lane_plans\true-parallel-plan.collision.json") -OutFile $collisionOut
Assert-Lane ($collision.verdict -eq "RED") "true parallel dry-run collision fails"
Assert-Lane (@($collision.blocked_reasons).Count -gt 0) "collision result records blockers"

$generatedPlan = Join-Path $workRoot "generated-isolated-worktree-plan.json"
$generated = & (Join-Path $repoRoot "tools\New-TsfParallelLanePlan.ps1") -OutFile $generatedPlan
Assert-Lane ((Test-Path -LiteralPath $generatedPlan) -and @($generated.lanes).Count -eq 2) "isolated worktree planner writes a two-lane plan"

$isolatedOut = Join-Path $workRoot "isolated-valid.json"
$isolated = & (Join-Path $repoRoot "tools\Test-TsfParallelLanePlan.ps1") -PlanPath (Join-Path $repoRoot "tests\fixtures\fleet\project-main-bot\parallel_lane_plans\isolated-worktree-plan.valid.json") -OutFile $isolatedOut
Assert-Lane ($isolated.verdict -eq "GREEN") "isolated worktree valid plan passes"
Assert-Lane ($isolated.collision_status -eq "NO_COLLISION") "isolated worktree valid plan has no collision"
Assert-Lane ($isolated.worktree_pilot_ready -eq $true) "isolated worktree valid plan is pilot-ready"

$isolatedCollisionOut = Join-Path $workRoot "isolated-collision.json"
$isolatedCollision = & (Join-Path $repoRoot "tools\Test-TsfParallelLanePlan.ps1") -PlanPath (Join-Path $repoRoot "tests\fixtures\fleet\project-main-bot\parallel_lane_plans\isolated-worktree-plan.collision.json") -OutFile $isolatedCollisionOut
Assert-Lane ($isolatedCollision.verdict -eq "RED") "isolated worktree collision plan fails"
Assert-Lane ($isolatedCollision.collision_status -eq "COLLISION_DETECTED") "isolated worktree collision records collision status"

Write-Host "Parallel lane dry-run tests passed."
