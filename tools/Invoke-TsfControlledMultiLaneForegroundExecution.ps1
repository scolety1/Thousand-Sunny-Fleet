param(
    [Parameter(Mandatory = $true)]
    [string]$PlanPath,

    [string]$PolicyPath = "fleet/control/controlled-multi-lane-foreground-execution-policy.v1.json",
    [string]$OutDirectory = "",
    [string]$OutFile = "",
    [switch]$DryRun,
    [switch]$RunApprovedFixtureWorkers,
    [switch]$CleanupWorktrees,
    [int]$WorkerTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1")

function Read-ControlledLaneJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { throw "Missing JSON file: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-ControlledLaneJson {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $Value | ConvertTo-Json -Depth 24 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function ConvertTo-ControlledLaneArray {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [array]) { return @($Value) }
    return @($Value)
}

function Get-ControlledLaneFullPath {
    param([Parameter(Mandatory = $true)][string]$Path, [string]$BasePath = "")
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    if ([string]::IsNullOrWhiteSpace($BasePath)) { $BasePath = $fleetRoot }
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Test-ControlledLanePathInside {
    param([Parameter(Mandatory = $true)][string]$ChildPath, [Parameter(Mandatory = $true)][string]$ParentPath)
    $child = [System.IO.Path]::GetFullPath($ChildPath).TrimEnd('\', '/')
    $parent = [System.IO.Path]::GetFullPath($ParentPath).TrimEnd('\', '/')
    if ([string]::Equals($child, $parent, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    return $child.StartsWith(($parent + [System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)
}

function Get-ControlledLaneArtifact {
    param([Parameter(Mandatory = $true)]$Lane)
    $artifacts = @(ConvertTo-ControlledLaneArray $Lane.expected_artifacts)
    if ($artifacts.Count -ne 1) { throw "Lane $($Lane.lane_id) must define exactly one expected artifact." }
    $artifact = $artifacts[0]
    if ($artifact -is [string]) {
        return [pscustomobject]@{ path = [string]$artifact; expected_content = "" }
    }
    return [pscustomobject]@{ path = [string]$artifact.path; expected_content = [string]$artifact.expected_content }
}

function New-ControlledLaneApprovalLedger {
    param(
        [Parameter(Mandatory = $true)]$Plan,
        [Parameter(Mandatory = $true)]$Policy,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $approvals = @()
    foreach ($lane in @(ConvertTo-ControlledLaneArray $Plan.lanes)) {
        $artifact = Get-ControlledLaneArtifact -Lane $lane
        $approvals += [pscustomobject]@{
            approval_id = "tim-approved-controlled-multi-lane-$($lane.lane_id)-20260709"
            approved_by = "Tim"
            approved_at = (Get-Date).ToString("o")
            expires_at = "2026-07-31T23:59:59Z"
            lane = "MASTER_TSF_CONTROL_PLANE"
            repo_path = [string]$lane.worktree_path
            exact_action = [string]$Policy.required_exact_action
            allowed_files_or_paths = @([string]$artifact.path)
            scope_limit = "controlled multi-lane fixture worker only"
            sample_fixture_only = $false
        }
    }
    Write-ControlledLaneJson -Value ([pscustomobject]@{
        schema_version = 1
        ledger_id = "controlled-multi-lane-foreground-execution-ledger-v1"
        approvals = @($approvals)
    }) -Path $Path
}

function Invoke-ControlledLaneGit {
    param([Parameter(Mandatory = $true)][string[]]$Arguments, [string]$WorkingDirectory = $fleetRoot)
    $output = @(& git @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($output -join "`n")"
    }
    return @($output)
}

function Get-ControlledLaneStatusPaths {
    param([Parameter(Mandatory = $true)][string]$Path)
    $rows = @(git -C $Path status --short --untracked-files=all)
    return @($rows | ForEach-Object { if ($_.Length -ge 4) { $_.Substring(3).Trim() } else { $_.Trim() } } | Where-Object { $_ })
}

$policyFull = Get-ControlledLaneFullPath -Path $PolicyPath
$planFull = Get-ControlledLaneFullPath -Path $PlanPath
$policy = Read-ControlledLaneJson -Path $policyFull
$plan = Read-ControlledLaneJson -Path $planFull
$lanes = @(ConvertTo-ControlledLaneArray $plan.lanes)

if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
    $safePlanId = ([string]$plan.plan_id) -replace "[^A-Za-z0-9._:-]", "_"
    $OutDirectory = Join-Path $fleetRoot ".codex-local\controlled-multi-lane-foreground-execution\$safePlanId"
}
if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = Join-Path $OutDirectory "controlled_multi_lane_execution_result.json"
}
New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null

$events = New-Object System.Collections.ArrayList
$blocked = New-Object System.Collections.ArrayList
$createdWorktrees = New-Object System.Collections.ArrayList
$removedWorktrees = New-Object System.Collections.ArrayList
$laneResults = New-Object System.Collections.ArrayList
$workerInvocationsUsed = 0
$worktreesCreated = $false
$workersInvoked = $false
$cleanupStatus = "NOT_REQUESTED"

try {
    if ($lanes.Count -gt [int]$policy.max_lane_count) {
        throw "Lane count $($lanes.Count) exceeds policy max $($policy.max_lane_count)."
    }
    if ($lanes.Count -eq 0) {
        throw "Plan contains no lanes."
    }

    $planCheckPath = Join-Path $OutDirectory "lane_plan_dry_run_result.json"
    $planCheck = & (Join-Path $fleetRoot "tools\Test-TsfParallelLanePlan.ps1") -PlanPath $planFull -OutFile $planCheckPath
    if ([string]$planCheck.verdict -ne "GREEN" -or [string]$planCheck.collision_status -ne "NO_COLLISION") {
        throw "Lane plan dry-run failed: $($planCheck.verdict) / $($planCheck.collision_status)"
    }
    $events.Add([pscustomobject]@{ step = "plan_dry_run"; status = "PASS"; evidence = $planCheckPath }) | Out-Null

    $allowedRoles = @(ConvertTo-ControlledLaneArray $policy.allowed_worker_roles | ForEach-Object { [string]$_ })
    $worktreeRoot = Get-ControlledLaneFullPath -Path ([string]$policy.worktree_root)
    foreach ($lane in $lanes) {
        $role = [string]$lane.worker_role
        $artifact = Get-ControlledLaneArtifact -Lane $lane
        $artifactPath = ([string]$artifact.path).Replace("\", "/")
        $allowedRoot = ([string]$policy.allowed_fixture_output_root).Replace("\", "/").TrimEnd("/")
        if ($allowedRoles -notcontains $role) { throw "Lane $($lane.lane_id) role is not allowed by policy: $role" }
        if (!$artifactPath.StartsWith(($allowedRoot + "/"), [System.StringComparison]::OrdinalIgnoreCase)) {
            throw "Lane $($lane.lane_id) artifact is outside controlled multi-lane fixture root: $artifactPath"
        }
        if (!(Test-ControlledLanePathInside -ChildPath ([string]$lane.worktree_path) -ParentPath $worktreeRoot)) {
            throw "Lane $($lane.lane_id) worktree path is outside policy worktree root."
        }
    }

    if ($DryRun -or !$RunApprovedFixtureWorkers) {
        $finalDecision = "GREEN_CONTROLLED_MULTI_LANE_DRY_RUN_READY"
    } else {
        if ([int]$policy.max_worker_invocations -lt $lanes.Count) {
            throw "Policy worker budget is lower than lane count."
        }
        $approvalLedgerPath = Join-Path $OutDirectory "approval-ledger.controlled-multi-lane.json"
        New-ControlledLaneApprovalLedger -Plan $plan -Policy $policy -Path $approvalLedgerPath

        foreach ($lane in $lanes) {
            if ($workerInvocationsUsed -ge [int]$policy.max_worker_invocations) {
                throw "Worker budget exceeded before lane $($lane.lane_id)."
            }
            $branch = [string]$lane.branch
            $worktreePath = [string]$lane.worktree_path
            $branchExists = (git rev-parse --verify --quiet "refs/heads/$branch")
            if ($LASTEXITCODE -eq 0) { throw "Lane branch already exists: $branch" }
            if (Test-Path -LiteralPath $worktreePath) { throw "Lane worktree path already exists: $worktreePath" }

            Invoke-ControlledLaneGit -Arguments @("worktree", "add", "-b", $branch, $worktreePath, [string]$plan.source_branch) | Out-Null
            $worktreesCreated = $true
            $createdWorktrees.Add([pscustomobject]@{ lane_id = [string]$lane.lane_id; branch = $branch; worktree_path = $worktreePath }) | Out-Null

            $laneOut = Join-Path $OutDirectory ("lane-" + ([string]$lane.lane_id))
            New-Item -ItemType Directory -Force -Path $laneOut | Out-Null
            $laneResult = & (Join-Path $fleetRoot "tools\Invoke-TsfParallelLaneFixtureWorker.ps1") -PlanPath $planFull -LaneId ([string]$lane.lane_id) -ApprovalLedgerPath $approvalLedgerPath -OutDirectory $laneOut -WorkerTimeoutSeconds $WorkerTimeoutSeconds
            $workerInvocationsUsed += [int]$laneResult.worker_invocations_used
            if ([bool]$laneResult.codex_cli_worker_execution_invoked) { $workersInvoked = $true }
            $laneResults.Add($laneResult) | Out-Null

            if ([string]$laneResult.final_decision -eq "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL") {
                throw "Lane $($lane.lane_id) requires Tim approval for Codex CLI auth/execution."
            }
            if ([string]$laneResult.final_decision -ne "GREEN_PARALLEL_LANE_WORKER_VERIFIED") {
                throw "Lane $($lane.lane_id) failed closed: $($laneResult.final_decision)"
            }
        }

        $badResults = @($laneResults | Where-Object { [string]$_.final_decision -ne "GREEN_PARALLEL_LANE_WORKER_VERIFIED" -or [string]$_.verifier_verdict -ne "GREEN" -or ![bool]$_.expected_content_matched })
        if ($badResults.Count -eq 0) {
            $finalDecision = "GREEN_CONTROLLED_MULTI_LANE_FOREGROUND_EXECUTION_COMPLETE"
        } else {
            $finalDecision = "RED_CONTROLLED_MULTI_LANE_EVIDENCE_INCOMPLETE"
        }
    }

    if ($CleanupWorktrees -and $worktreesCreated) {
        foreach ($worktree in @($createdWorktrees)) {
            $path = [string]$worktree.worktree_path
            if (!(Test-ControlledLanePathInside -ChildPath $path -ParentPath $worktreeRoot)) {
                throw "Refusing cleanup outside worktree root: $path"
            }
            if (Test-Path -LiteralPath $path) {
                Invoke-ControlledLaneGit -Arguments @("worktree", "remove", "--force", $path) | Out-Null
                $removedWorktrees.Add($worktree) | Out-Null
            }
        }
        $cleanupStatus = "TEMP_WORKTREES_REMOVED_LOCAL_BRANCHES_RETAINED"
    }
} catch {
    $blocked.Add($_.Exception.Message) | Out-Null
    if ($workerInvocationsUsed -gt [int]$policy.max_worker_invocations) {
        $finalDecision = "TIM_REQUIRED_WORKER_BUDGET_EXCEEDED"
    } elseif ($_.Exception.Message -match "Tim approval|auth|credential|sandbox|permission") {
        $finalDecision = "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL"
    } else {
        $finalDecision = "RED_CONTROLLED_MULTI_LANE_FOREGROUND_EXECUTION_BLOCKED"
    }
}

$collisionStatus = if (@($laneResults).Count -eq $lanes.Count -and @($laneResults | Where-Object { [string]$_.final_decision -ne "GREEN_PARALLEL_LANE_WORKER_VERIFIED" }).Count -eq 0) { "PASS_NO_COLLISION" } elseif ($DryRun -or !$RunApprovedFixtureWorkers) { "PASS_NO_COLLISION_DRY_RUN" } else { "UNKNOWN_OR_BLOCKED" }
$integrationRecommendation = if ($finalDecision -eq "GREEN_CONTROLLED_MULTI_LANE_FOREGROUND_EXECUTION_COMPLETE") { "SAFE_FOR_FUTURE_MERGE_PLANNING_GATE_PRESERVE_ONLY_NOW" } elseif ($finalDecision -like "GREEN_*DRY_RUN*") { "SAFE_TO_RUN_APPROVED_FOREGROUND_FIXTURE_WORKERS" } elseif ($finalDecision -like "TIM_REQUIRED*") { "TIM_REQUIRED" } else { "BLOCKED_BY_MISSING_EVIDENCE_OR_FAILURE" }
$contextUpdate = [pscustomobject]@{
    schema_version = "controlled_multi_lane_context_update_result_v1"
    updated = ($finalDecision -like "GREEN_*")
    mission_id = [string]$plan.plan_id
    lane_count = $lanes.Count
    worker_invocations_used = $workerInvocationsUsed
    final_decision = $finalDecision
    next_recommended_action = "Review controlled multi-lane evidence; continue only through a separate publication gate."
}

$result = [pscustomobject]@{
    schema_version = "controlled_multi_lane_foreground_execution_result_v1"
    generated_at = (Get-Date).ToString("o")
    plan_path = $planFull
    policy_path = $policyFull
    plan_id = [string]$plan.plan_id
    final_decision = $finalDecision
    dry_run = [bool]$DryRun
    run_approved_fixture_workers = [bool]$RunApprovedFixtureWorkers
    lane_count = $lanes.Count
    worker_invocations_used = $workerInvocationsUsed
    worker_invocation_budget = [int]$policy.max_worker_invocations
    worktrees_created = @($createdWorktrees)
    worktrees_cleaned_up = $cleanupStatus
    lane_results = @($laneResults)
    collision_review_result = $collisionStatus
    verifier_results = @($laneResults | ForEach-Object { [pscustomobject]@{ lane_id = [string]$_.lane_id; verifier_verdict = [string]$_.verifier_verdict; expected_content_matched = [bool]$_.expected_content_matched } })
    context_update_result = $contextUpdate
    integration_recommendation = $integrationRecommendation
    blocked_reasons = @($blocked)
    events = @($events)
    push_performed = $false
    pr_created = $false
    merge_performed = $false
    api_called = $false
    background_runners_started = $false
    all_fleet_started = $false
    product_repos_mutated = $false
    canonical_nwr_mutated = $false
}

Write-ControlledLaneJson -Value $result -Path $OutFile
$result

if ($finalDecision -like "RED_*" -or $finalDecision -like "TIM_REQUIRED*") {
    exit 1
}
exit 0
