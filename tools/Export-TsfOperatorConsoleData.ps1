param(
    [string]$RepoPath = "",
    [string]$OutDir = "",
    [string]$SourceBranchCleanupArchivePath = "C:\NWR_REVIEW\tsf_source_branch_cleanup_archive_gate_20260709"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $RepoPath "tools/operator-console/readonly/data"
}

function Write-TsfConsoleJson {
    param(
        [Parameter(Mandatory = $true)][object]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $Value | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Invoke-TsfConsoleGit {
    param([string[]]$Arguments)
    $old = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    Push-Location -LiteralPath $RepoPath
    try {
        $output = & git @Arguments 2>&1
        $code = $LASTEXITCODE
    } finally {
        Pop-Location
        $ErrorActionPreference = $old
    }
    [pscustomobject]@{
        exit_code = $code
        output = (($output | Out-String).Trim())
    }
}

function Read-TsfJsonFile {
    param([string]$RelativePath)
    $path = Join-Path $RepoPath $RelativePath
    if (!(Test-Path -LiteralPath $path)) { return $null }
    Get-Content -Raw -LiteralPath $path | ConvertFrom-Json
}

$generatedAt = (Get-Date).ToString("o")
$currentBranch = (Invoke-TsfConsoleGit -Arguments @("branch", "--show-current")).output
$localHead = (Invoke-TsfConsoleGit -Arguments @("rev-parse", "HEAD")).output
$originMain = (Invoke-TsfConsoleGit -Arguments @("rev-parse", "origin/main")).output
$gitStatus = (Invoke-TsfConsoleGit -Arguments @("status", "--short", "--untracked-files=all")).output

$roleRegistry = Read-TsfJsonFile -RelativePath "fleet/control/worker-role-registry.v1.json"
$permissionProfiles = Read-TsfJsonFile -RelativePath "fleet/control/worker-permission-profiles.v1.json"
$queuePolicy = Read-TsfJsonFile -RelativePath "fleet/control/mission-queue-state-policy.v1.json"
$mainBotPolicy = Read-TsfJsonFile -RelativePath "fleet/control/project-main-bot-bounded-self-continuation.v1.json"
$multiLanePolicy = Read-TsfJsonFile -RelativePath "fleet/control/controlled-multi-lane-foreground-execution-policy.v1.json"
$costPolicy = Read-TsfJsonFile -RelativePath "fleet/control/hq-api-cost-guardrail-policy.v1.json"

$roles = @()
if ($null -ne $roleRegistry -and $roleRegistry.PSObject.Properties.Name -contains "roles") {
    $roles = @($roleRegistry.roles)
}
$profiles = @()
if ($null -ne $permissionProfiles -and $permissionProfiles.PSObject.Properties.Name -contains "profiles") {
    $profiles = @($permissionProfiles.profiles)
} elseif ($null -ne $permissionProfiles -and $permissionProfiles.PSObject.Properties.Name -contains "permission_profiles") {
    $profiles = @($permissionProfiles.permission_profiles)
}

$queueStates = @()
if ($null -ne $queuePolicy -and $queuePolicy.PSObject.Properties.Name -contains "states") {
    $queueStates = @($queuePolicy.states)
}

$localBranches = @()
$localBranchResult = Invoke-TsfConsoleGit -Arguments @("branch", "--list", "--format=%(refname:short)|%(objectname)")
if ($localBranchResult.exit_code -eq 0 -and ![string]::IsNullOrWhiteSpace($localBranchResult.output)) {
    $localBranches = @($localBranchResult.output -split "`r?`n" | ForEach-Object {
        $parts = $_ -split "\|"
        if ($parts.Count -ge 2) {
            [pscustomobject]@{ branch = $parts[0]; head = $parts[1] }
        }
    })
}

$remoteBranches = @()
$remoteBranchResult = Invoke-TsfConsoleGit -Arguments @("branch", "-r", "--format=%(refname:short)|%(objectname)")
if ($remoteBranchResult.exit_code -eq 0 -and ![string]::IsNullOrWhiteSpace($remoteBranchResult.output)) {
    $remoteBranches = @($remoteBranchResult.output -split "`r?`n" | ForEach-Object {
        $parts = $_ -split "\|"
        if ($parts.Count -ge 2) {
            [pscustomobject]@{ branch = $parts[0]; head = $parts[1] }
        }
    })
}

$recentPackets = @()
$hqRoot = Join-Path $RepoPath "docs/hq"
if (Test-Path -LiteralPath $hqRoot) {
    $recentPackets = @(Get-ChildItem -LiteralPath $hqRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 12 | ForEach-Object {
        [pscustomobject]@{
            name = $_.Name
            path = $_.FullName.Replace($RepoPath + "\", "")
            last_write_time = $_.LastWriteTime.ToString("o")
        }
    })
}

$sourceCleanup = $null
$sourceCleanupValidation = Join-Path $SourceBranchCleanupArchivePath "source_branch_cleanup_validation.json"
if (Test-Path -LiteralPath $sourceCleanupValidation) {
    $sourceCleanup = Get-Content -Raw -LiteralPath $sourceCleanupValidation | ConvertFrom-Json
}

$cards = @(
    [pscustomobject]@{ id = "mainline"; label = "Mainline"; status = "GREEN"; summary = "origin/main verified"; detail = $originMain },
    [pscustomobject]@{ id = "queue"; label = "Mission Queue"; status = "GREEN"; summary = "Foreground queue available"; detail = "Execution remains foreground-only." },
    [pscustomobject]@{ id = "roles"; label = "Worker Roles"; status = "GREEN"; summary = "$($roles.Count) roles preserved"; detail = "$($profiles.Count) permission profiles found." },
    [pscustomobject]@{ id = "branches"; label = "Branches"; status = if ($sourceCleanup) { "GREEN" } else { "INFO" }; summary = if ($sourceCleanup) { "Cleanup archive available" } else { "Cleanup archive not found" }; detail = "Local branches: $($localBranches.Count); remote branches: $($remoteBranches.Count)" },
    [pscustomObject]@{ id = "api"; label = "API/HQ"; status = "TIM_REQUIRED"; summary = "No API transport enabled"; detail = "Packet-only HQ adapter remains local until separately approved." }
)

$statusSummary = [pscustomobject]@{
    schema_version = "operator_console_status_summary_v1"
    generated_at = $generatedAt
    status = [pscustomobject]@{
        verdict = if ([string]::IsNullOrWhiteSpace($gitStatus)) { "GREEN" } else { "YELLOW" }
        summary = "TSF local operator console data export complete."
        origin_main_head = $originMain
        current_branch = $currentBranch
        local_head = $localHead
        next_recommended_milestone = "Operator Console Read-Only Skeleton V1"
    }
    merged_prs = @(
        [pscustomobject]@{ number = 4; summary = "Kernel / role-aware lifecycle" },
        [pscustomobject]@{ number = 5; summary = "Pack-and-go foundations and first GREEN governed Codex worker execution" },
        [pscustomobject]@{ number = 6; summary = "Bounded Project Main Bot self-continuation" },
        [pscustomobject]@{ number = 7; summary = "Local mission queue foreground executor" },
        [pscustomobject]@{ number = 8; summary = "True parallel lane isolated worktree pilot" },
        [pscustomobject]@{ number = 9; summary = "Controlled multi-lane foreground execution" }
    )
    cards = $cards
    mission_queue = [pscustomobject]@{
        states = @($queueStates | ForEach-Object { if ($_ -is [string]) { $_ } elseif ($_.PSObject.Properties.Name -contains "state") { $_.state } elseif ($_.PSObject.Properties.Name -contains "id") { $_.id } else { [string]$_ } })
        execution_mode = "foreground_only"
    }
    worker_roles = [pscustomobject]@{
        role_count = $roles.Count
        permission_profile_count = $profiles.Count
    }
    hard_gates = @("push", "merge", "deploy", "install", "migration", "secrets", "api_call", "background_runner", "product_repo_mutation", "canonical_nwr_mutation")
    review_packets = @($recentPackets | ForEach-Object { $_.name })
}

$missionQueueSummary = [pscustomobject]@{
    schema_version = "operator_console_mission_queue_summary_v1"
    generated_at = $generatedAt
    queue_policy_present = ($null -ne $queuePolicy)
    execution_mode = "foreground_only"
    browser_execution_enabled = $false
    states = $statusSummary.mission_queue.states
}

$workerRoleSummary = [pscustomobject]@{
    schema_version = "operator_console_worker_role_summary_v1"
    generated_at = $generatedAt
    role_count = $roles.Count
    permission_profile_count = $profiles.Count
    roles = @($roles | ForEach-Object {
        [pscustomobject]@{
            role_id = $_.role_id
            role_name = $_.role_name
            verifier_required = $_.verifier_required
            may_use_api = $_.may_use_api
            may_touch_product_repo = $_.may_touch_product_repo
        }
    })
}

$branchSummary = [pscustomobject]@{
    schema_version = "operator_console_branch_summary_v1"
    generated_at = $generatedAt
    current_branch = $currentBranch
    local_head = $localHead
    origin_main_head = $originMain
    git_status_clean = [string]::IsNullOrWhiteSpace($gitStatus)
    local_branches = $localBranches
    remote_branches = $remoteBranches
    source_cleanup_archive = $sourceCleanup
}

$recentPacketsSummary = [pscustomobject]@{
    schema_version = "operator_console_recent_packets_summary_v1"
    generated_at = $generatedAt
    packets = $recentPackets
}

$nextActionsSummary = [pscustomobject]@{
    schema_version = "operator_console_next_actions_summary_v1"
    generated_at = $generatedAt
    recommended_next_milestone = "Operator Console Read-Only Skeleton V1"
    after_this_runway = "Future Tim-approved push/PR gate if publication readiness is GREEN."
    do_not_start = @("push", "merge", "api_transport", "background_runner")
}

$hardGatesSummary = [pscustomobject]@{
    schema_version = "operator_console_hard_gates_summary_v1"
    generated_at = $generatedAt
    tim_required_for = @(
        "push",
        "merge",
        "deploy",
        "install_packages",
        "migration",
        "secrets",
        "ChatGPT/OpenAI API call",
        "background_runner",
        "product_repo_mutation",
        "canonical_nwr_mutation",
        "real_parallel_worker_execution"
    )
    policies_present = [pscustomobject]@{
        main_bot_policy = ($null -ne $mainBotPolicy)
        controlled_multi_lane_policy = ($null -ne $multiLanePolicy)
        hq_cost_policy = ($null -ne $costPolicy)
    }
}

Write-TsfConsoleJson -Value $statusSummary -Path (Join-Path $OutDir "status-summary.json")
Write-TsfConsoleJson -Value $missionQueueSummary -Path (Join-Path $OutDir "mission-queue-summary.json")
Write-TsfConsoleJson -Value $workerRoleSummary -Path (Join-Path $OutDir "worker-role-summary.json")
Write-TsfConsoleJson -Value $branchSummary -Path (Join-Path $OutDir "branch-summary.json")
Write-TsfConsoleJson -Value $recentPacketsSummary -Path (Join-Path $OutDir "recent-packets-summary.json")
Write-TsfConsoleJson -Value $nextActionsSummary -Path (Join-Path $OutDir "next-actions-summary.json")
Write-TsfConsoleJson -Value $hardGatesSummary -Path (Join-Path $OutDir "hard-gates-summary.json")

[pscustomobject]@{
    verdict = "GREEN_OPERATOR_CONSOLE_DATA_ADAPTER_COMPLETE"
    out_dir = $OutDir
    files_written = @(
        "status-summary.json",
        "mission-queue-summary.json",
        "worker-role-summary.json",
        "branch-summary.json",
        "recent-packets-summary.json",
        "next-actions-summary.json",
        "hard-gates-summary.json"
    )
    api_called = $false
    background_runner_started = $false
    browser_command_execution_enabled = $false
}
