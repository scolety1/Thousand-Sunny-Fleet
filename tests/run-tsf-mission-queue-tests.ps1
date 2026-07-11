$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'tools\codex-fleet-enforcement-kernel.ps1')
$workRoot = Join-Path $repoRoot ".codex-local\mission-queue-tests"
if (Test-Path -LiteralPath $workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force }
foreach ($state in @("inbox", "drafted", "preflight_pending", "blocked_needs_tim", "approved_for_worker", "worker_running", "postrun_pending", "complete_review_only", "complete_ready_for_gate", "stopped", "archived")) {
    New-Item -ItemType Directory -Force -Path (Join-Path $workRoot $state) | Out-Null
}

function Assert-Queue {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) { throw "FAIL: $Message" }
    Write-Host "PASS: $Message"
}

$sample = Join-Path $repoRoot "tests\fixtures\fleet\mission-queue\sample-mission.json"
$mission = Join-Path $workRoot "inbox\sample-mission.json"
Copy-Item -LiteralPath $sample -Destination $mission

$validOut = Join-Path $workRoot "valid-transition.json"
$valid = & (Join-Path $repoRoot "tools\Move-TsfMissionState.ps1") -MissionPath $mission -FromState "inbox" -ToState "drafted" -QueueRoot $workRoot -OutFile $validOut
Assert-Queue ($valid.verdict -eq "GREEN") "inbox to drafted transition passes"
Assert-Queue (Test-Path -LiteralPath (Join-Path $workRoot "drafted\sample-mission.json")) "mission moved to drafted"

$invalidOut = Join-Path $workRoot "invalid-transition.json"
$invalid = & (Join-Path $repoRoot "tools\Move-TsfMissionState.ps1") -MissionPath (Join-Path $workRoot "drafted\sample-mission.json") -FromState "drafted" -ToState "worker_running" -QueueRoot $workRoot -OutFile $invalidOut -DryRun
Assert-Queue ($invalid.verdict -eq "RED") "invalid transition fails closed"
Assert-Queue ($invalid.moved -eq $false) "invalid dry-run transition does not move"

function New-QueueExecutorMission {
    param(
        [string]$MissionId,
        [string]$WorkerRole,
        [string]$ArtifactPath,
        [string]$ExpectedContent,
        [string]$Path
    )

    $forbidden = @(
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

    $mission = [pscustomobject]@{
        mission_id = $MissionId
        project_id = "TSF_CONTROL_PLANE"
        repo_path = $repoRoot
        lane = "MASTER_TSF_CONTROL_PLANE"
        mission_type = "tsf_infrastructure"
        allowed_reads = @("fleet/control", "tools", "tests/fixtures/fleet/mission-queue")
        allowed_writes = @($ArtifactPath)
        forbidden_reads = @("C:\NWR\Niners-War-Room", "normal NWR packets", "product repos")
        forbidden_writes = @("C:\NWR\Niners-War-Room", "product repos", "main")
        forbidden_actions = $forbidden
        expected_artifacts = @($ArtifactPath)
        required_preflight_checks = @("mission_schema", "project_registration_or_tsf_internal", "git_status", "worker_role_permission", "approval_ledger_exact_action_match", "forbidden_actions_absent")
        required_postrun_checks = @("expected_artifacts", "allowed_write_scope", "restricted_actions_absent", "verifier_green")
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
                approval_id = "test-approval-queue-executor"
                exact_action = "codex_cli_queue_fixture_worker_invocation"
            }
        )
        hq_escalation_policy = "local_only_no_api"
        created_by = "queue-executor-test"
        created_at = "2026-07-09T00:00:00-06:00"
        queue_final_state = "complete_review_only"
        queue_executor_fixture = [pscustomobject]@{
            expected_content = $ExpectedContent
        }
        role_extension = [pscustomobject]@{
            requested_by = "test"
            project_main_bot_id = "project-main-bot-tsf"
            worker_role = $WorkerRole
            translator_used = $false
            context_capsule_id = "queue-test-context"
            lane_id = "MASTER_TSF_CONTROL_PLANE"
            parent_mission_id = "queue-executor-test"
            sibling_lane_ids = @()
            role_permission_profile_id = $WorkerRole
            role_output_contract = "Create exactly one bounded mission queue fixture artifact."
            verifier_role = "verifier_worker"
            escalation_policy_id = "local_only_no_api"
        }
    }

    $mission | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-QueueExecutorApprovalLedger {
    param([string]$Path, [string]$AllowedPath)

    $ledger = [pscustomobject]@{
        schema_version = 1
        ledger_id = "queue-executor-test-ledger"
        notes = "Test-only queue executor ledger."
        approvals = @(
            [pscustomobject]@{
                approval_id = "test-approval-queue-executor"
                approved_by = "test"
                approved_at = "2026-07-09T00:00:00-06:00"
                expires_at = "2099-01-01T00:00:00Z"
                repo_path = $repoRoot
                lane = "MASTER_TSF_CONTROL_PLANE"
                exact_action = "codex_cli_queue_fixture_worker_invocation"
                allowed_files_or_paths = @($AllowedPath)
                required_verifier = "Invoke-TsfKernelPostRunVerify"
                scope_limit = "Queue executor test fixture only."
                sample_fixture_only = $false
                notes = "Synthetic queue executor regression approval."
            }
        )
    }
    $ledger | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

$executorMission = Join-Path $workRoot "inbox\queue-executor-dry-run.json"
$executorArtifact = "tests/fixtures/fleet/mission-queue/worker-output/queue_executor_test_result.txt"
New-QueueExecutorMission -MissionId "queue-executor-dry-run-001" -WorkerRole "builder_worker" -ArtifactPath $executorArtifact -ExpectedContent "TSF queue executor dry-run fixture." -Path $executorMission
$ledgerPath = Join-Path $workRoot "approval-ledger.queue-executor.json"
New-QueueExecutorApprovalLedger -Path $ledgerPath -AllowedPath $executorArtifact
$executorDoc=Get-Content $executorMission -Raw|ConvertFrom-Json;$executorRun=Get-TsfRuntimeSha256Text "$($executorDoc.mission_id)|1|$((Get-FileHash $executorMission -Algorithm SHA256).Hash.ToLowerInvariant())";$executorPlan=New-TsfRuntimeStoragePlan (Get-TsfCanonicalRuntimeRoot) $executorDoc.mission_id 1 $executorRun -Layout queue_control;$executorOut=[string]$executorPlan.artifacts.queue_result
$executor = & (Join-Path $repoRoot "tools\Invoke-TsfMissionQueueForegroundExecutor.ps1") -MissionPath $executorMission -QueueRoot $workRoot -ApprovalLedgerPath $ledgerPath -OutDirectory $executorPlan.directory -OutFile $executorOut -DryRun
Assert-Queue ($executor.final_decision -eq "YELLOW_QUEUE_DRY_RUN_APPROVED") "queue executor dry-run reaches approved state"
Assert-Queue ($executor.codex_cli_worker_execution_invoked -eq $false) "queue executor dry-run invokes no Codex worker"

$missingApprovalMission = Join-Path $workRoot "inbox\queue-executor-missing-approval.json"
New-QueueExecutorMission -MissionId "queue-executor-missing-approval-001" -WorkerRole "builder_worker" -ArtifactPath "tests/fixtures/fleet/mission-queue/worker-output/missing_approval.txt" -ExpectedContent "not used" -Path $missingApprovalMission
$missingDoc=Get-Content $missingApprovalMission -Raw|ConvertFrom-Json;$missingRun=Get-TsfRuntimeSha256Text "$($missingDoc.mission_id)|1|$((Get-FileHash $missingApprovalMission -Algorithm SHA256).Hash.ToLowerInvariant())";$missingPlan=New-TsfRuntimeStoragePlan (Get-TsfCanonicalRuntimeRoot) $missingDoc.mission_id 1 $missingRun -Layout queue_control;$missingApprovalOut=[string]$missingPlan.artifacts.queue_result
$missingApproval = & (Join-Path $repoRoot "tools\Invoke-TsfMissionQueueForegroundExecutor.ps1") -MissionPath $missingApprovalMission -QueueRoot $workRoot -OutDirectory $missingPlan.directory -OutFile $missingApprovalOut -DryRun
Assert-Queue ($missingApproval.final_decision -eq "TIM_REQUIRED_QUEUE_PREFLIGHT_BLOCKED") "queue executor blocks missing approval"
Assert-Queue ($missingApproval.codex_cli_worker_execution_invoked -eq $false) "missing approval invokes no Codex worker"

Write-Host "Mission queue tests passed."
