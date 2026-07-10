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
$requireTrueLanes = $false
if ($plan.PSObject.Properties.Name -contains "require_true_lanes") {
    $requireTrueLanes = [bool]$plan.require_true_lanes
}
foreach ($lane in $lanes) {
    $laneId = [string]$lane.lane_id
    $branch = [string]$lane.branch
    $worktree = [string]$lane.worktree_path
    $agentId = if ($lane.PSObject.Properties.Name -contains "codex_agent_id") { [string]$lane.codex_agent_id } else { "" }
    $ownedFiles = @($lane.owned_files | ForEach-Object { ([string]$_).Replace("\", "/").Trim().ToLowerInvariant() } | Where-Object { $_ })

    if ([string]::IsNullOrWhiteSpace($laneId)) {
        Add-TsfLaneCheck -Checks $checks -Name "lane_id.present" -Status "FAIL" -Message "Lane is missing lane_id."
        $blocked.Add("A lane is missing lane_id.") | Out-Null
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
        if ($seenFiles.ContainsKey($file)) {
            $collision = "$file shared by $($seenFiles[$file]) and $laneId"
            $collisions.Add($collision) | Out-Null
        } else {
            $seenFiles[$file] = $laneId
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
$forbiddenRequested = @($requestedActions | Where-Object { $_ -match "(?i)create[_ -]?worktree|delete[_ -]?worktree|push|merge|background|all[_ -]?fleet|deploy|install|migration|secret" })
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
    blocked_reasons = @($blocked)
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
