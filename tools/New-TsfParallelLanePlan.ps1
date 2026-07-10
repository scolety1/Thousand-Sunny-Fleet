param(
    [string]$PlanId = "parallel-lane-isolated-worktree-pilot-v1-20260709",
    [string]$SourceBranch = "origin/main",
    [string]$WorktreeRoot = "C:\Users\codex-agent\Documents\Vacation\TSF_WORKTREES",
    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

function New-TsfLaneArtifact {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ExpectedContent
    )
    [pscustomobject]@{
        path = $Path
        expected_content = $ExpectedContent
    }
}

$builderWorktree = Join-Path $WorktreeRoot "parallel-lane-pilot-builder-v1-20260709"
$auditorWorktree = Join-Path $WorktreeRoot "parallel-lane-pilot-auditor-v1-20260709"

$plan = [pscustomobject]@{
    schema_version = "parallel_lane_plan_v1"
    plan_id = $PlanId
    pilot_mode = "real_isolated_worktree_fixture_pilot"
    require_true_lanes = $true
    source_branch = $SourceBranch
    requested_actions = @(
        "dry_run_validate",
        "local_worktree_pilot",
        "sequential_fixture_workers",
        "collect_lane_reports",
        "preserve_evidence",
        "stop_before_merge"
    )
    global_forbidden_actions = @(
        "push",
        "merge",
        "create_pr",
        "deploy",
        "install_packages",
        "migration",
        "secrets",
        "privatelens",
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
        "recommendation_behavior",
        "danger_full_access",
        "ignore_user_config"
    )
    merge_checkpoint_rules = @{
        merge_lane_branches = $false
        merge_recommendation = "recommend_only_after_green_collision_review"
        local_commit_only = $true
        push_allowed = $false
    }
    collision_detection_rules = @{
        branches_must_be_unique = $true
        worktrees_must_be_unique = $true
        owned_files_must_not_overlap = $true
        expected_artifacts_must_not_overlap = $true
        allowed_write_scope_must_not_overlap = $true
    }
    lanes = @(
        [pscustomobject]@{
            lane_id = "parallel-lane-builder"
            worker_role = "builder_worker"
            codex_agent_id = "codex-agent-parallel-builder-001"
            source_branch = $SourceBranch
            branch = "work/parallel-lane-pilot-builder-v1-20260709"
            target_branch = "work/parallel-lane-pilot-builder-v1-20260709"
            worktree_path = $builderWorktree
            allowed_read_scope = @(
                "fleet/control",
                "tools",
                "tests/fixtures/fleet/parallel-lanes"
            )
            allowed_write_scope = @(
                "tests/fixtures/fleet/parallel-lanes/worker-output/builder_lane_result.txt"
            )
            forbidden_paths = @(
                "C:\NWR\Niners-War-Room",
                "normal NWR packets",
                "product repos",
                "local_exports"
            )
            forbidden_actions = @(
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
            expected_artifacts = @(
                (New-TsfLaneArtifact -Path "tests/fixtures/fleet/parallel-lanes/worker-output/builder_lane_result.txt" -ExpectedContent "TSF parallel lane builder worker complete.")
            )
            owned_files = @(
                "tests/fixtures/fleet/parallel-lanes/worker-output/builder_lane_result.txt"
            )
            checkpoint_policy = "local_commit_after_validation"
            merge_recommendation_rule = "do_not_merge_lane_branch; coordinator_collects_evidence_only"
            stop_conditions = @(
                "worktree_branch_mismatch",
                "worktree_dirty_before_worker",
                "role_preflight_red_or_tim_required",
                "missing_exact_approval",
                "worker_budget_exceeded",
                "codex_cli_auth_or_execution_unclear",
                "unexpected_file_touch",
                "verifier_red",
                "collision_detected"
            )
        },
        [pscustomobject]@{
            lane_id = "parallel-lane-auditor"
            worker_role = "auditor_worker"
            codex_agent_id = "codex-agent-parallel-auditor-001"
            source_branch = $SourceBranch
            branch = "work/parallel-lane-pilot-auditor-v1-20260709"
            target_branch = "work/parallel-lane-pilot-auditor-v1-20260709"
            worktree_path = $auditorWorktree
            allowed_read_scope = @(
                "fleet/control",
                "tools",
                "tests/fixtures/fleet/parallel-lanes"
            )
            allowed_write_scope = @(
                "tests/fixtures/fleet/parallel-lanes/worker-output/auditor_lane_result.txt"
            )
            forbidden_paths = @(
                "C:\NWR\Niners-War-Room",
                "normal NWR packets",
                "product repos",
                "local_exports"
            )
            forbidden_actions = @(
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
            expected_artifacts = @(
                (New-TsfLaneArtifact -Path "tests/fixtures/fleet/parallel-lanes/worker-output/auditor_lane_result.txt" -ExpectedContent "TSF parallel lane auditor worker complete.")
            )
            owned_files = @(
                "tests/fixtures/fleet/parallel-lanes/worker-output/auditor_lane_result.txt"
            )
            checkpoint_policy = "local_commit_after_validation"
            merge_recommendation_rule = "do_not_merge_lane_branch; coordinator_collects_evidence_only"
            stop_conditions = @(
                "worktree_branch_mismatch",
                "worktree_dirty_before_worker",
                "role_preflight_red_or_tim_required",
                "missing_exact_approval",
                "worker_budget_exceeded",
                "codex_cli_auth_or_execution_unclear",
                "unexpected_file_touch",
                "verifier_red",
                "collision_detected"
            )
        }
    )
}

if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $plan | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}

$plan
