$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
$workRoot = Join-Path $repoRoot ".codex-local\controlled-multi-lane-tests"
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

function Assert-ControlledLane {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}

$policyPath = Join-Path $repoRoot "fleet\control\controlled-multi-lane-foreground-execution-policy.v1.json"
$policy = Get-Content -Raw -LiteralPath $policyPath | ConvertFrom-Json
Assert-ControlledLane ($policy.max_lane_count -eq 3) "controlled multi-lane policy caps lane count at three"
Assert-ControlledLane ($policy.max_worker_invocations -eq 3) "controlled multi-lane policy caps worker invocations at three"
Assert-ControlledLane ($policy.lane_rules.background_execution_allowed -eq $false) "controlled multi-lane policy blocks background execution"
Assert-ControlledLane ($policy.lane_rules.merge_lane_branches_allowed -eq $false) "controlled multi-lane policy blocks lane merges"

$validPlan = Join-Path $repoRoot "tests\fixtures\fleet\project-main-bot\controlled_multi_lane_plans\controlled-multi-lane-plan.valid.json"
$validOut = Join-Path $workRoot "valid-plan-check.json"
$valid = & (Join-Path $repoRoot "tools\Test-TsfParallelLanePlan.ps1") -PlanPath $validPlan -OutFile $validOut
Assert-ControlledLane ($valid.verdict -eq "GREEN") "controlled multi-lane valid plan passes dry-run check"
Assert-ControlledLane ($valid.collision_status -eq "NO_COLLISION") "controlled multi-lane valid plan has no collision"
Assert-ControlledLane ($valid.worktree_pilot_ready -eq $true) "controlled multi-lane valid plan is worktree-ready"

$collisionPlan = Join-Path $repoRoot "tests\fixtures\fleet\project-main-bot\controlled_multi_lane_plans\controlled-multi-lane-plan.collision.json"
$collisionOut = Join-Path $workRoot "collision-plan-check.json"
$collision = & (Join-Path $repoRoot "tools\Test-TsfParallelLanePlan.ps1") -PlanPath $collisionPlan -OutFile $collisionOut
Assert-ControlledLane ($collision.verdict -eq "RED") "controlled multi-lane collision plan fails"
Assert-ControlledLane ($collision.collision_status -eq "COLLISION_DETECTED") "controlled multi-lane collision records collision status"

$dryRunOut = Join-Path $workRoot "controlled-runner-dry-run.json"
$dryRun = & (Join-Path $repoRoot "tools\Invoke-TsfControlledMultiLaneForegroundExecution.ps1") -PlanPath $validPlan -DryRun -OutDirectory (Join-Path $workRoot "runner-dry-run") -OutFile $dryRunOut
Assert-ControlledLane ($dryRun.final_decision -eq "GREEN_CONTROLLED_MULTI_LANE_DRY_RUN_READY") "controlled multi-lane runner dry-run is green"
Assert-ControlledLane ($dryRun.worker_invocations_used -eq 0) "controlled multi-lane runner dry-run uses zero workers"
Assert-ControlledLane (@($dryRun.worktrees_created).Count -eq 0) "controlled multi-lane runner dry-run creates no worktrees"
Assert-ControlledLane ($dryRun.background_runners_started -eq $false) "controlled multi-lane runner does not start background runners"

Write-Host "Controlled multi-lane foreground execution tests passed."
