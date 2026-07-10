param(
    [Parameter(Mandatory = $true)]
    [string]$PlanPath,

    [Parameter(Mandatory = $true)]
    [string]$LaneId,

    [Parameter(Mandatory = $true)]
    [string]$ApprovalLedgerPath,

    [Parameter(Mandatory = $true)]
    [string]$OutDirectory,

    [string]$OutFile = "",

    [int]$WorkerTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $fleetRoot "tools\codex-fleet-enforcement-kernel.ps1")
. (Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1")

function Read-ParallelLaneJson {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { throw "Missing JSON file: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-ParallelLaneJson {
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $Value | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function ConvertTo-ParallelLaneArray {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [array]) { return @($Value) }
    return @($Value)
}

function Get-ParallelLaneExpectedArtifact {
    param([Parameter(Mandatory = $true)]$Lane)
    $artifacts = @(ConvertTo-ParallelLaneArray $Lane.expected_artifacts)
    if ($artifacts.Count -ne 1) { throw "Lane must define exactly one expected artifact for this fixture pilot." }
    $artifact = $artifacts[0]
    if ($artifact -is [string]) {
        return [pscustomobject]@{ path = [string]$artifact; expected_content = "" }
    }
    return [pscustomobject]@{
        path = [string]$artifact.path
        expected_content = [string]$artifact.expected_content
    }
}

function Get-ParallelLaneForbiddenActions {
    param([Parameter(Mandatory = $true)]$Lane)
    $actions = @(ConvertTo-ParallelLaneArray $Lane.forbidden_actions | ForEach-Object { [string]$_ } | Where-Object { $_ })
    if ($actions.Count -eq 0) {
        $actions = @(
            "push",
            "merge",
            "deploy",
            "install_packages",
            "migration",
            "secrets",
            "privatelens",
            "proof_run",
            "all_fleet",
            "background_runner",
            "persistent_runner",
            "canonical_nwr_inspection",
            "canonical_nwr_mutation",
            "normal_nwr_packet_read",
            "product_repo_inspection",
            "product_repo_mutation",
            "api_bridge",
            "open_network_port",
            "credential_change",
            "app_wiring",
            "ranking_formula_source_truth_promotion",
            "hidden_sort",
            "recommendation_behavior"
        )
    }
    return $actions
}

function New-ParallelLaneMission {
    param(
        [Parameter(Mandatory = $true)]$Lane,
        [Parameter(Mandatory = $true)]$Artifact
    )
    $role = [string]$Lane.worker_role
    $missionId = "parallel-lane-$($Lane.lane_id)-fixture"
    [pscustomobject]@{
        mission_id = $missionId
        project_id = "TSF_CONTROL_PLANE"
        repo_path = [string]$Lane.worktree_path
        required_branch = [string]$Lane.branch
        lane = "MASTER_TSF_CONTROL_PLANE"
        mission_type = "tsf_infrastructure"
        allowed_reads = @(ConvertTo-ParallelLaneArray $Lane.allowed_read_scope | ForEach-Object { [string]$_ })
        allowed_writes = @([string]$Artifact.path)
        forbidden_reads = @(ConvertTo-ParallelLaneArray $Lane.forbidden_paths | ForEach-Object { [string]$_ })
        forbidden_writes = @(ConvertTo-ParallelLaneArray $Lane.forbidden_paths | ForEach-Object { [string]$_ })
        forbidden_actions = @(Get-ParallelLaneForbiddenActions -Lane $Lane)
        expected_artifacts = @([string]$Artifact.path)
        required_preflight_checks = @(
            "mission_schema",
            "project_registration_or_tsf_internal",
            "git_status",
            "worker_role_permission",
            "approval_ledger_exact_action_match",
            "forbidden_actions_absent"
        )
        required_postrun_checks = @(
            "expected_artifacts",
            "allowed_write_scope",
            "restricted_actions_absent",
            "verifier_green"
        )
        stop_conditions = @(
            [pscustomobject]@{ id = "missing_exact_approval"; check_type = "approval_required" },
            [pscustomobject]@{ id = "unexpected_file_touch"; check_type = "manual" },
            [pscustomobject]@{ id = "codex_cli_auth_or_execution_unclear"; check_type = "manual" },
            [pscustomobject]@{ id = "verifier_red"; check_type = "manual" },
            [pscustomobject]@{ id = "forbidden_action_requested"; check_type = "forbidden_action_absent" }
        )
        approval_requirements = @(
            [pscustomobject]@{
                required = $true
                approval_id = "tim-approval-parallel-lane-pilot-20260709"
                exact_action = "codex_cli_parallel_lane_fixture_worker_invocation"
            }
        )
        hq_escalation_policy = "local_only_no_api"
        created_by = "Master TSF True Parallel Lane Worktree Pilot"
        created_at = (Get-Date).ToString("o")
        parallel_lane_fixture = [pscustomobject]@{
            lane_id = [string]$Lane.lane_id
            expected_content = [string]$Artifact.expected_content
        }
        role_extension = [pscustomobject]@{
            requested_by = "Tim"
            project_main_bot_id = "project-main-bot-tsf"
            worker_role = $role
            translator_used = $false
            context_capsule_id = "parallel-lane-pilot-context"
            lane_id = [string]$Lane.lane_id
            parent_mission_id = "true-parallel-lane-isolated-worktree-pilot-v1"
            sibling_lane_ids = @()
            role_permission_profile_id = $role
            role_output_contract = "Create exactly one bounded parallel lane fixture artifact."
            verifier_role = "verifier_worker"
            escalation_policy_id = "local_only_no_api"
        }
    }
}

function Get-ParallelLaneGitStatus {
    param([Parameter(Mandatory = $true)][string]$Path)
    $rows = @(git -C $Path status --short --untracked-files=all)
    return @($rows | ForEach-Object { if ($_.Length -ge 4) { $_.Substring(3).Trim() } else { $_.Trim() } } | Where-Object { $_ })
}

$plan = Read-ParallelLaneJson -Path $PlanPath
$lane = @(ConvertTo-ParallelLaneArray $plan.lanes | Where-Object { [string]$_.lane_id -eq $LaneId }) | Select-Object -First 1
if ($null -eq $lane) { throw "Lane not found in plan: $LaneId" }

$artifact = Get-ParallelLaneExpectedArtifact -Lane $lane
$worktreePath = [string]$lane.worktree_path
$branch = [string]$lane.branch
$role = [string]$lane.worker_role
$missionId = "parallel-lane-$LaneId-fixture"

New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null

$resultPath = if ([string]::IsNullOrWhiteSpace($OutFile)) { Join-Path $OutDirectory "parallel_lane_worker_result.json" } else { $OutFile }
$missionPath = Join-Path $OutDirectory "mission.json"
$preflightPath = Join-Path $OutDirectory "preflight_result.json"
$rolePreflightPath = Join-Path $OutDirectory "role_preflight_result.json"
$workerResultPath = Join-Path $OutDirectory "worker_result.json"
$verifierPath = Join-Path $OutDirectory "verifier_result.json"
$lastMessagePath = Join-Path $OutDirectory "codex_worker_last_message.txt"
$codexEventsPath = Join-Path $OutDirectory "codex_worker_events.jsonl"
$preservationRoot = Join-Path $OutDirectory "preservation"

$events = New-Object System.Collections.ArrayList
$blocked = New-Object System.Collections.ArrayList
$workerStatus = "NOT_RUN"
$codexInvoked = $false
$workerExitCode = $null
$workerTimedOut = $false
$filesTouched = @()

try {
    if (!(Test-Path -LiteralPath $worktreePath -PathType Container)) {
        throw "Worktree path does not exist: $worktreePath"
    }
    $actualBranch = (git -C $worktreePath branch --show-current).Trim()
    if ($actualBranch -ne $branch) {
        throw "Worktree branch mismatch: expected=$branch actual=$actualBranch"
    }
    $statusBefore = @(Get-ParallelLaneGitStatus -Path $worktreePath)
    if ($statusBefore.Count -gt 0) {
        throw "Worktree dirty before worker: $($statusBefore -join ', ')"
    }

    $mission = New-ParallelLaneMission -Lane $lane -Artifact $artifact
    Write-ParallelLaneJson -Value $mission -Path $missionPath

    $rolePreflight = & (Join-Path $fleetRoot "tools\Test-TsfWorkerRolePermission.ps1") -MissionDraftPath $missionPath -RegistryPath (Join-Path $worktreePath "fleet/control/worker-role-registry.v1.json") -PermissionProfilesPath (Join-Path $worktreePath "fleet/control/worker-permission-profiles.v1.json") -OutFile $rolePreflightPath
    if ([string]$rolePreflight.verdict -ne "GREEN") {
        throw "Role-aware preflight failed: $($rolePreflight.verdict)"
    }

    $preflight = Invoke-TsfKernelPreflight -MissionPath $missionPath -ApprovalLedgerPath $ApprovalLedgerPath -OutFile $preflightPath -StateRoot (Join-Path $OutDirectory "kernel_states")
    if (-not [bool]$preflight.preflight_approved) {
        throw "Kernel preflight failed: $($preflight.verdict)"
    }

    $prompt = @"
You are a foreground TSF parallel-lane fixture worker.

Mission ID: $missionId
Worker role: $role
Allowed write path: $($artifact.path)
Required content exactly:
$($artifact.expected_content)

Create exactly the allowed fixture file with exactly the required content. Do not touch any other file. Do not push, merge, deploy, install, migrate, access secrets, use APIs, start background runners, inspect product repos, inspect or mutate canonical NWR, read normal NWR packets, use danger-full-access, or use ignore-user-config.
"@
    $codexInvoked = $true
    $codexResult = Invoke-FleetProcess -FilePath "codex" -Arguments @("exec", "-c", "service_tier=fast", "--sandbox", "workspace-write", "--ephemeral", "--cd", $worktreePath, "--output-last-message", $lastMessagePath, "--json", "-") -InputText $prompt -WorkingDirectory $worktreePath -LogPath $codexEventsPath -TimeoutSeconds $WorkerTimeoutSeconds
    $workerTimedOut = [bool]$codexResult.timedOut
    $workerExitCode = $codexResult.exitCode
    if ($workerTimedOut) {
        $workerStatus = "CODEX_CLI_TIMEOUT"
        $blocked.Add("Codex CLI parallel lane worker timed out.") | Out-Null
    } else {
        if ($workerExitCode -ne 0) {
            $text = (($codexResult.output | ForEach-Object { [string]$_ }) -join "`n")
            if ($text -match "(?i)login|auth|credential|api key|permission|approval|danger-full-access") {
                $workerStatus = "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL"
            } else {
                $workerStatus = "CODEX_CLI_NONZERO"
            }
            $blocked.Add("Codex CLI parallel lane worker exited nonzero: $workerExitCode") | Out-Null
        }
    }

    $statusAfter = @(Get-ParallelLaneGitStatus -Path $worktreePath)
    $filesTouched = @($statusAfter)
    $allowedArtifact = ([string]$artifact.path).Replace("\", "/")
    $unexpected = @($statusAfter | ForEach-Object { ([string]$_).Replace("\", "/") } | Where-Object { $_ -ne $allowedArtifact })
    $artifactFullPath = Join-Path $worktreePath $artifact.path
    if ($workerStatus -eq "NOT_RUN") {
        if ($unexpected.Count -gt 0) {
            $workerStatus = "CODEX_CLI_TOUCHED_FORBIDDEN_PATH"
            $blocked.Add("Worker touched unexpected paths: $($unexpected -join ', ')") | Out-Null
        } elseif (!(Test-Path -LiteralPath $artifactFullPath)) {
            $workerStatus = "CODEX_CLI_EXPECTED_ARTIFACT_MISSING"
            $blocked.Add("Worker did not create expected artifact.") | Out-Null
        } elseif (((Get-Content -LiteralPath $artifactFullPath -Raw).Trim()) -ne [string]$artifact.expected_content) {
            $workerStatus = "CODEX_CLI_UNEXPECTED_ARTIFACT_CONTENT"
            $blocked.Add("Worker wrote unexpected artifact content.") | Out-Null
        } else {
            $workerStatus = "CODEX_CLI_PARALLEL_LANE_FIXTURE_GREEN"
        }
    }

    $workerResult = [pscustomobject]@{
        schema_version = "parallel_lane_fixture_worker_result_v1"
        generated_at = (Get-Date).ToString("o")
        mission_id = $missionId
        lane_id = $LaneId
        worker_role = $role
        role_output_contract_satisfied = ($workerStatus -eq "CODEX_CLI_PARALLEL_LANE_FIXTURE_GREEN")
        worker_status = $workerStatus
        codex_exit_code = $workerExitCode
        codex_timed_out = $workerTimedOut
        files_created = if (Test-Path -LiteralPath $artifactFullPath) { @([string]$artifact.path) } else { @() }
        files_touched = @($filesTouched)
        restricted_actions_attempted = @()
        background_runner_started = $false
        all_fleet_started = $false
        product_repos_mutated = $false
        canonical_nwr_mutated = $false
        push_merge_deploy_attempted = $false
    }
    Write-ParallelLaneJson -Value $workerResult -Path $workerResultPath

    $verifier = Invoke-TsfKernelPostRunVerify -MissionPath $missionPath -WorkerResultPath $workerResultPath -OutFile $verifierPath -StateRoot (Join-Path $OutDirectory "kernel_states")
    $preservation = Write-TsfKernelPreservationPacket -MissionPath $missionPath -PreflightResultPath $preflightPath -WorkerResultPath $workerResultPath -VerifierResultPath $verifierPath -OutputDirectory $preservationRoot -ExactNextAction "Collect parallel lane result in coordinator branch; do not merge lane branch."

    $finalDecision = if ($workerStatus -eq "CODEX_CLI_PARALLEL_LANE_FIXTURE_GREEN" -and [string]$verifier.verdict -eq "GREEN") {
        "GREEN_PARALLEL_LANE_WORKER_VERIFIED"
    } elseif ($workerStatus -eq "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL") {
        "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL"
    } else {
        "RED_PARALLEL_LANE_WORKER_FAILED_CLOSED"
    }

    $result = [pscustomobject]@{
        schema_version = "parallel_lane_fixture_worker_execution_v1"
        generated_at = (Get-Date).ToString("o")
        lane_id = $LaneId
        branch = $branch
        worktree_path = $worktreePath
        worker_role = $role
        final_decision = $finalDecision
        worker_status = $workerStatus
        worker_invocations_used = if ($codexInvoked) { 1 } else { 0 }
        codex_cli_worker_execution_invoked = $codexInvoked
        expected_artifact = [string]$artifact.path
        expected_content_matched = ((Test-Path -LiteralPath $artifactFullPath) -and (((Get-Content -LiteralPath $artifactFullPath -Raw).Trim()) -eq [string]$artifact.expected_content))
        files_touched = @($filesTouched)
        role_preflight_path = $rolePreflightPath
        preflight_path = $preflightPath
        worker_result_path = $workerResultPath
        verifier_path = $verifierPath
        verifier_verdict = [string]$verifier.verdict
        preservation_path = if ($null -ne $preservation) { [string]$preservation.packet_directory } else { "" }
        blocked_reasons = @($blocked)
        push_performed = $false
        merge_performed = $false
        api_called = $false
        background_runners_started = $false
        product_repos_mutated = $false
        canonical_nwr_mutated = $false
    }
} catch {
    $result = [pscustomobject]@{
        schema_version = "parallel_lane_fixture_worker_execution_v1"
        generated_at = (Get-Date).ToString("o")
        lane_id = $LaneId
        branch = $branch
        worktree_path = $worktreePath
        worker_role = $role
        final_decision = "RED_PARALLEL_LANE_WORKER_BLOCKED"
        worker_status = $workerStatus
        worker_invocations_used = if ($codexInvoked) { 1 } else { 0 }
        codex_cli_worker_execution_invoked = $codexInvoked
        expected_artifact = if ($null -ne $artifact) { [string]$artifact.path } else { "" }
        expected_content_matched = $false
        files_touched = @($filesTouched)
        role_preflight_path = $rolePreflightPath
        preflight_path = $preflightPath
        worker_result_path = $workerResultPath
        verifier_path = $verifierPath
        verifier_verdict = ""
        preservation_path = ""
        blocked_reasons = @(($_.Exception.Message))
        push_performed = $false
        merge_performed = $false
        api_called = $false
        background_runners_started = $false
        product_repos_mutated = $false
        canonical_nwr_mutated = $false
    }
}

Write-ParallelLaneJson -Value $result -Path $resultPath
$result
