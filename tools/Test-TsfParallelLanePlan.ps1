param(
    [Parameter(Mandatory = $true)]
    [string]$PlanPath,

    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

function Read-TsfLaneJson {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { throw "Missing lane plan: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Add-TsfLaneCheck {
    param(
        [System.Collections.ArrayList]$Checks,
        [string]$Name,
        [string]$Status,
        [string]$Message,
        [string]$Evidence = ""
    )
    $Checks.Add([pscustomobject]@{
        name = $Name
        status = $Status
        message = $Message
        evidence = $Evidence
    }) | Out-Null
}

function Test-TsfLanePathOverlap {
    param(
        [string]$Left,
        [string]$Right
    )
    if ([string]::IsNullOrWhiteSpace($Left) -or [string]::IsNullOrWhiteSpace($Right)) { return $false }
    $leftNorm = $Left.Replace("\", "/").Trim().TrimEnd("/").ToLowerInvariant()
    $rightNorm = $Right.Replace("\", "/").Trim().TrimEnd("/").ToLowerInvariant()
    if ($leftNorm -eq $rightNorm) { return $true }
    if ($leftNorm.StartsWith("$rightNorm/")) { return $true }
    if ($rightNorm.StartsWith("$leftNorm/")) { return $true }
    return $false
}

$plan = Read-TsfLaneJson -Path $PlanPath
$checks = New-Object System.Collections.ArrayList
$collisions = New-Object System.Collections.ArrayList
$blocked = New-Object System.Collections.ArrayList
$lanes = @($plan.lanes)

if ($lanes.Count -eq 0) {
    Add-TsfLaneCheck -Checks $checks -Name "lanes.present" -Status "FAIL" -Message "Lane plan has no lanes."
    $blocked.Add("Lane plan has no lanes.") | Out-Null
} else {
    Add-TsfLaneCheck -Checks $checks -Name "lanes.present" -Status "PASS" -Message "Lane plan contains lanes." -Evidence ([string]$lanes.Count)
}

$seenBranches = @{}
$seenWorktrees = @{}
$seenAgents = @{}
$seenFiles = @{}
$seenWriteScopes = @{}
$seenArtifacts = @{}
$requireTrueLanes = $false
if ($plan.PSObject.Properties.Name -contains "require_true_lanes") {
    $requireTrueLanes = [bool]$plan.require_true_lanes
}
$requireWorktreePilotFields = $false
if ($plan.PSObject.Properties.Name -contains "pilot_mode" -and [string]$plan.pilot_mode -in @("real_isolated_worktree_fixture_pilot", "controlled_multi_lane_foreground_execution")) {
    $requireWorktreePilotFields = $true
}
$maxWorkerInvocations = $null
if ($plan.PSObject.Properties.Name -contains "max_worker_invocations") {
    $maxWorkerInvocations = [int]$plan.max_worker_invocations
    if ($lanes.Count -gt $maxWorkerInvocations) {
        Add-TsfLaneCheck -Checks $checks -Name "worker_budget.within_limit" -Status "FAIL" -Message "Lane count exceeds worker invocation budget." -Evidence "lanes=$($lanes.Count); max_worker_invocations=$maxWorkerInvocations"
        $blocked.Add("Worker invocation budget exceeded.") | Out-Null
    } else {
        Add-TsfLaneCheck -Checks $checks -Name "worker_budget.within_limit" -Status "PASS" -Message "Lane count is within worker invocation budget." -Evidence "lanes=$($lanes.Count); max_worker_invocations=$maxWorkerInvocations"
    }
}
foreach ($lane in $lanes) {
    $laneId = [string]$lane.lane_id
    $branch = if ($lane.PSObject.Properties.Name -contains "target_branch" -and ![string]::IsNullOrWhiteSpace([string]$lane.target_branch)) { [string]$lane.target_branch } else { [string]$lane.branch }
    $worktree = [string]$lane.worktree_path
    $workerRole = if ($lane.PSObject.Properties.Name -contains "worker_role") { [string]$lane.worker_role } else { "" }
    $sourceBranch = if ($lane.PSObject.Properties.Name -contains "source_branch") { [string]$lane.source_branch } else { "" }
    $agentId = if ($lane.PSObject.Properties.Name -contains "codex_agent_id") { [string]$lane.codex_agent_id } else { "" }
    $ownedFiles = @($lane.owned_files | ForEach-Object { ([string]$_).Replace("\", "/").Trim().ToLowerInvariant() } | Where-Object { $_ })
    $writeScopes = @()
    if ($lane.PSObject.Properties.Name -contains "allowed_write_scope") {
        $writeScopes = @($lane.allowed_write_scope | ForEach-Object { ([string]$_).Replace("\", "/").Trim().ToLowerInvariant() } | Where-Object { $_ })
    }
    $expectedArtifacts = @()
    if ($lane.PSObject.Properties.Name -contains "expected_artifacts") {
        foreach ($artifact in @($lane.expected_artifacts)) {
            if ($artifact -is [string]) {
                $expectedArtifacts += ([string]$artifact).Replace("\", "/").Trim().ToLowerInvariant()
            } elseif ($artifact.PSObject.Properties.Name -contains "path") {
                $expectedArtifacts += ([string]$artifact.path).Replace("\", "/").Trim().ToLowerInvariant()
            }
        }
        $expectedArtifacts = @($expectedArtifacts | Where-Object { $_ })
    }

    if ([string]::IsNullOrWhiteSpace($laneId)) {
        Add-TsfLaneCheck -Checks $checks -Name "lane_id.present" -Status "FAIL" -Message "Lane is missing lane_id."
        $blocked.Add("A lane is missing lane_id.") | Out-Null
    }
    if ($lane.PSObject.Properties.Name -contains "simulated_worktree_state" -and [string]$lane.simulated_worktree_state -match "(?i)stale|dirty|missing") {
        Add-TsfLaneCheck -Checks $checks -Name "worktree.lifecycle.safe" -Status "FAIL" -Message "Lane fixture reports unsafe worktree lifecycle state." -Evidence "$laneId=$($lane.simulated_worktree_state)"
        $blocked.Add("Unsafe worktree lifecycle state: $laneId=$($lane.simulated_worktree_state)") | Out-Null
    }
    if ($lane.PSObject.Properties.Name -contains "simulated_lane_branch_state" -and [string]$lane.simulated_lane_branch_state -match "(?i)orphaned|diverged|unknown") {
        Add-TsfLaneCheck -Checks $checks -Name "branch.lifecycle.safe" -Status "FAIL" -Message "Lane fixture reports unsafe branch lifecycle state." -Evidence "$laneId=$($lane.simulated_lane_branch_state)"
        $blocked.Add("Unsafe branch lifecycle state: $laneId=$($lane.simulated_lane_branch_state)") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($workerRole) -and $requireWorktreePilotFields) {
        Add-TsfLaneCheck -Checks $checks -Name "worker_role.present" -Status "FAIL" -Message "True lane is missing worker_role." -Evidence $laneId
        $blocked.Add("True lane missing worker_role: $laneId") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($sourceBranch) -and $requireWorktreePilotFields) {
        Add-TsfLaneCheck -Checks $checks -Name "source_branch.present" -Status "FAIL" -Message "True lane is missing source_branch." -Evidence $laneId
        $blocked.Add("True lane missing source_branch: $laneId") | Out-Null
    }
    if ([string]::IsNullOrWhiteSpace($branch)) {
        Add-TsfLaneCheck -Checks $checks -Name "branch.present" -Status "FAIL" -Message "Lane is missing branch." -Evidence $laneId
        $blocked.Add("Lane missing branch: $laneId") | Out-Null
    } elseif ($seenBranches.ContainsKey($branch)) {
        Add-TsfLaneCheck -Checks $checks -Name "branch.unique" -Status "FAIL" -Message "Duplicate branch in lane plan." -Evidence $branch
        $blocked.Add("Duplicate branch: $branch") | Out-Null
    } else {
        $seenBranches[$branch] = $laneId
    }
    if ($worktree -match "(?i)^C:\\NWR\\Niners-War-Room|PrivateLens|product repo") {
        Add-TsfLaneCheck -Checks $checks -Name "protected_worktree.blocked" -Status "FAIL" -Message "Protected worktree path requested." -Evidence $worktree
        $blocked.Add("Protected worktree path: $worktree") | Out-Null
    }
    if ($worktree -match "(?i)\\Niners-War-Room|\\NWR\\|PrivateLens|product repo") {
        Add-TsfLaneCheck -Checks $checks -Name "protected_worktree.general_block" -Status "FAIL" -Message "Protected worktree path requested." -Evidence $worktree
        $blocked.Add("Protected worktree path: $worktree") | Out-Null
    }
    if ($requireTrueLanes) {
        if ([string]::IsNullOrWhiteSpace($worktree)) {
            Add-TsfLaneCheck -Checks $checks -Name "true_lane.worktree.present" -Status "FAIL" -Message "True lane is missing worktree_path." -Evidence $laneId
            $blocked.Add("True lane missing worktree_path: $laneId") | Out-Null
        } elseif ($seenWorktrees.ContainsKey($worktree)) {
            Add-TsfLaneCheck -Checks $checks -Name "true_lane.worktree.unique" -Status "FAIL" -Message "Duplicate worktree path in true lane plan." -Evidence $worktree
            $blocked.Add("Duplicate worktree path: $worktree") | Out-Null
        } else {
            $seenWorktrees[$worktree] = $laneId
        }
        if ([string]::IsNullOrWhiteSpace($agentId)) {
            Add-TsfLaneCheck -Checks $checks -Name "true_lane.agent.present" -Status "FAIL" -Message "True lane is missing codex_agent_id." -Evidence $laneId
            $blocked.Add("True lane missing codex_agent_id: $laneId") | Out-Null
        } elseif ($seenAgents.ContainsKey($agentId)) {
            Add-TsfLaneCheck -Checks $checks -Name "true_lane.agent.unique" -Status "FAIL" -Message "Duplicate Codex agent id in true lane plan." -Evidence $agentId
            $blocked.Add("Duplicate Codex agent id: $agentId") | Out-Null
        } else {
            $seenAgents[$agentId] = $laneId
        }
        if ($branch -notmatch "^work/[A-Za-z0-9._-]+-\d{8}$") {
            Add-TsfLaneCheck -Checks $checks -Name "true_lane.branch.name" -Status "FAIL" -Message "True lane branch must be a dated work/* branch." -Evidence $branch
            $blocked.Add("Invalid true lane branch name: $branch") | Out-Null
        }
    }
    foreach ($file in $ownedFiles) {
        foreach ($seen in $seenFiles.Keys) {
            if (Test-TsfLanePathOverlap -Left $file -Right $seen) {
                $collision = "$file overlaps $seen owned by $($seenFiles[$seen]) and $laneId"
                $collisions.Add($collision) | Out-Null
            }
        }
        if ($seenFiles.ContainsKey($file)) {
            $collision = "$file shared by $($seenFiles[$file]) and $laneId"
            $collisions.Add($collision) | Out-Null
        } else {
            $seenFiles[$file] = $laneId
        }
    }
    foreach ($scope in $writeScopes) {
        if ($scope -match "(?i)^c:/nwr/|niners-war-room|privatelens|product repo|local_exports") {
            Add-TsfLaneCheck -Checks $checks -Name "allowed_write_scope.protected" -Status "FAIL" -Message "Allowed write scope includes protected path." -Evidence $scope
            $blocked.Add("Protected write scope: $scope") | Out-Null
        }
        foreach ($seen in $seenWriteScopes.Keys) {
            if (Test-TsfLanePathOverlap -Left $scope -Right $seen) {
                $collision = "$scope write scope overlaps $seen owned by $($seenWriteScopes[$seen]) and $laneId"
                $collisions.Add($collision) | Out-Null
            }
        }
        if ($seenWriteScopes.ContainsKey($scope)) {
            $collision = "$scope write scope shared by $($seenWriteScopes[$scope]) and $laneId"
            $collisions.Add($collision) | Out-Null
        } else {
            $seenWriteScopes[$scope] = $laneId
        }
    }
    foreach ($artifact in $expectedArtifacts) {
        foreach ($seen in $seenArtifacts.Keys) {
            if (Test-TsfLanePathOverlap -Left $artifact -Right $seen) {
                $collision = "$artifact expected artifact overlaps $seen owned by $($seenArtifacts[$seen]) and $laneId"
                $collisions.Add($collision) | Out-Null
            }
        }
        if ($seenArtifacts.ContainsKey($artifact)) {
            $collision = "$artifact expected artifact shared by $($seenArtifacts[$artifact]) and $laneId"
            $collisions.Add($collision) | Out-Null
        } else {
            $seenArtifacts[$artifact] = $laneId
        }
    }
}

if ($collisions.Count -gt 0) {
    Add-TsfLaneCheck -Checks $checks -Name "file_ownership.no_collision" -Status "FAIL" -Message "Owned-file collision detected." -Evidence (@($collisions) -join "; ")
    $blocked.Add("Owned-file collision detected.") | Out-Null
} else {
    Add-TsfLaneCheck -Checks $checks -Name "file_ownership.no_collision" -Status "PASS" -Message "No owned-file collision detected."
}

$requestedActions = @($plan.requested_actions | ForEach-Object { [string]$_ })
$forbiddenRequested = @($requestedActions | Where-Object {
    $action = $_.Trim()
    $action -match "(?i)^(create[_ -]?worktree|delete[_ -]?worktree|push|merge|merge[_ -]?lane|background|all[_ -]?fleet|deploy|install|migration|secret)" -and
    $action -notmatch "(?i)^stop[_ -]?before[_ -]?merge$"
})
if ($forbiddenRequested.Count -gt 0) {
    Add-TsfLaneCheck -Checks $checks -Name "dry_run_only" -Status "FAIL" -Message "Lane plan requests forbidden non-dry-run action." -Evidence ($forbiddenRequested -join "; ")
    $blocked.Add("Forbidden lane action requested: $($forbiddenRequested -join ', ')") | Out-Null
} else {
    Add-TsfLaneCheck -Checks $checks -Name "dry_run_only" -Status "PASS" -Message "Lane plan is dry-run only."
}

$verdict = if ($blocked.Count -eq 0) { "GREEN" } else { "RED" }
$recommendation = if ($verdict -eq "GREEN") { "NO_COLLISION_DRY_RUN_READY" } else { "BLOCKED_CONFLICT" }

$result = [pscustomobject]@{
    schema_version = "parallel_lane_plan_dry_run_result_v1"
    plan_path = $PlanPath
    verdict = $verdict
    recommendation = $recommendation
    checks = @($checks)
    collisions = @($collisions)
    collision_status = if ($collisions.Count -eq 0) { "NO_COLLISION" } else { "COLLISION_DETECTED" }
    blocked_reasons = @($blocked)
    worktree_pilot_ready = ($verdict -eq "GREEN" -and $requireTrueLanes)
    branches_created = $false
    worktrees_created = $false
    workers_spawned = $false
    push_performed = $false
    merge_performed = $false
}

if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}

$result
