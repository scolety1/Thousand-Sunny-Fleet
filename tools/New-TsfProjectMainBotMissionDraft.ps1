param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectId,

    [Parameter(Mandatory = $true)]
    [string]$NaturalRequest,

    [ValidateSet("MASTER_TSF_CONTROL_PLANE", "TSF_NWR", "NORMAL_NWR", "PRODUCT_REPO", "PRIVATE_LENS", "OTHER")]
    [string]$Lane = "MASTER_TSF_CONTROL_PLANE",

    [string]$RequestedGoal = "",
    [string]$ProposedWorkerRole = "researcher_source_tracer_worker",
    [string[]]$AllowedReads = @("docs/hq", "docs/fleet", "fleet/control"),
    [string[]]$AllowedWrites = @("docs/hq"),
    [string[]]$ForbiddenActions = @(),
    [string[]]$ExpectedArtifacts = @("mission-draft-result"),
    [string[]]$StopConditions = @("scope-gate|approval_required|Stop if the request crosses a hard TSF gate."),
    [string[]]$ApprovalRequirements = @(),
    [string]$OutFile = "",
    [string]$RepoPath = "",
    [string]$ProjectMainBotId = "project_main_bot.default",
    [string]$ContextCapsuleId = "",
    [string]$LaneId = "",
    [string]$ParentMissionId = "",
    [string[]]$SiblingLaneIds = @(),
    [string]$RequestedBy = "tim",
    [string]$CreatedBy = "project_main_bot_mission_intake_adapter_v1"
)

$ErrorActionPreference = "Stop"

function ConvertTo-TsfDraftArray {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [array]) { return @($Value | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) }
    if ([string]::IsNullOrWhiteSpace([string]$Value)) { return @() }
    return @([string]$Value)
}

function ConvertFrom-TsfDraftStopCondition {
    param([string]$Spec)
    $parts = @($Spec -split "\|", 3)
    if ($parts.Count -ne 3) {
        throw "Stop condition must use 'id|check_type|description': $Spec"
    }
    [pscustomobject]@{
        id = $parts[0].Trim()
        check_type = $parts[1].Trim()
        description = $parts[2].Trim()
    }
}

function ConvertFrom-TsfDraftApprovalRequirement {
    param([string]$Spec)
    $parts = @($Spec -split "\|", 4)
    if ($parts.Count -lt 3) {
        throw "Approval requirement must use 'exact_action|required|reason|optional_approval_id': $Spec"
    }
    $required = $false
    if (![bool]::TryParse($parts[1].Trim(), [ref]$required)) {
        throw "Approval requirement required value must be true or false: $Spec"
    }
    $obj = [ordered]@{
        exact_action = $parts[0].Trim()
        required = $required
        reason = $parts[2].Trim()
    }
    if ($parts.Count -eq 4 -and ![string]::IsNullOrWhiteSpace($parts[3])) {
        $obj.approval_id = $parts[3].Trim()
    }
    [pscustomobject]$obj
}

function ConvertTo-TsfDraftSlug {
    param([string]$Value)
    $slug = ($Value.ToLowerInvariant() -replace "[^a-z0-9._:-]+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($slug)) { return "mission" }
    return $slug
}

function Resolve-TsfDraftClassification {
    param(
        [string]$Request,
        [string]$WorkerRole,
        [string[]]$Actions,
        [string[]]$Writes
    )
    $allText = (($Request, $WorkerRole) + $Actions + $Writes) -join " "
    if ($allText -match "(?i)\b(bypass|ignore guardrails|force push|force merge|disable checks|delete safety|drop approval)\b") {
        return "BLOCKED_UNSAFE"
    }
    if ($allText -match "(?i)\b(push|merge|deploy|install|migration|migrate|secret|auth|payment|credential|privatelens|proof run|all-fleet|background|daemon|scheduler|watchdog|persistent|codex cli|codex exec|api|open network|canonical nwr|normal nwr|product repo)\b") {
        return "NEEDS_TIM_APPROVAL"
    }
    if ($allText -match "(?i)\b(architecture switch|conflicting worker|conflicting reports|repeated blocker|ambiguous yellow|source[- ]truth|ranking|formula|model promotion|app wiring|hidden sort|recommendation)\b") {
        return "NEEDS_CHATGPT_HQ"
    }
    if ([string]::IsNullOrWhiteSpace($WorkerRole) -or [string]::IsNullOrWhiteSpace($Request)) {
        return "NEEDS_MAIN_BOT_REVIEW"
    }
    return "SAFE_LOCAL_MISSION"
}

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

$defaultForbidden = @(
    "push", "merge", "deploy", "install_packages", "migration", "secrets",
    "privatelens", "proof_run", "all_fleet", "background_runner",
    "persistent_runner", "canonical_nwr_inspection", "canonical_nwr_mutation",
    "normal_nwr_packet_read", "product_repo_inspection", "product_repo_mutation",
    "api_bridge", "open_network_port", "credential_change", "app_wiring",
    "ranking_formula_source_truth_promotion", "hidden_sort",
    "recommendation_behavior"
)

$explicitForbiddenActions = @(ConvertTo-TsfDraftArray $ForbiddenActions)
$forbidden = @($explicitForbiddenActions + $defaultForbidden | Sort-Object -Unique)
$classification = Resolve-TsfDraftClassification -Request $NaturalRequest -WorkerRole $ProposedWorkerRole -Actions $explicitForbiddenActions -Writes $AllowedWrites
$missionId = "$(ConvertTo-TsfDraftSlug -Value $ProjectId)-$(Get-Date -Format 'yyyyMMddHHmmss')"
$goal = if ([string]::IsNullOrWhiteSpace($RequestedGoal)) { $NaturalRequest } else { $RequestedGoal }

$stopObjects = @(ConvertTo-TsfDraftArray $StopConditions | ForEach-Object { ConvertFrom-TsfDraftStopCondition -Spec $_ })
if ($stopObjects.Count -eq 0) {
    $stopObjects = @([pscustomobject]@{ id = "scope-gate"; check_type = "approval_required"; description = "Stop if scope crosses a hard TSF gate." })
}

$approvalObjects = @(ConvertTo-TsfDraftArray $ApprovalRequirements | ForEach-Object { ConvertFrom-TsfDraftApprovalRequirement -Spec $_ })

$missionPacket = [pscustomobject]@{
    mission_id = $missionId
    project_id = $ProjectId
    repo_path = $RepoPath
    lane = $Lane
    mission_type = "docs_control_plane"
    allowed_reads = @(ConvertTo-TsfDraftArray $AllowedReads)
    allowed_writes = @(ConvertTo-TsfDraftArray $AllowedWrites)
    forbidden_reads = @("C:\NWR\Niners-War-Room", "normal NWR packets", "product repos")
    forbidden_writes = @("C:\NWR\Niners-War-Room", "product repos")
    forbidden_actions = @($forbidden)
    expected_artifacts = @(ConvertTo-TsfDraftArray $ExpectedArtifacts)
    required_preflight_checks = @("schema", "repo_exists", "path_scope", "restricted_action_coverage", "git_status_capture", "approval_ledger", "worker_role_permission")
    required_postrun_checks = @("expected_artifacts", "forbidden_actions_absent", "worker_role_contract")
    stop_conditions = @($stopObjects)
    approval_requirements = @($approvalObjects)
    hq_escalation_policy = [pscustomobject]@{
        default = if ($classification -eq "NEEDS_CHATGPT_HQ") { "hq_packet_required" } else { "local_only_no_api" }
        escalate_on = @("RED", "TIM_REQUIRED", "scope_conflict", "source_truth_promotion")
        notes = "No API call is approved by this draft."
    }
    created_by = $CreatedBy
    created_at = (Get-Date).ToString("o")
}

$roleExtension = [pscustomobject]@{
    requested_by = $RequestedBy
    project_main_bot_id = $ProjectMainBotId
    worker_role = $ProposedWorkerRole
    translator_used = $true
    context_capsule_id = $ContextCapsuleId
    lane_id = if ([string]::IsNullOrWhiteSpace($LaneId)) { "$(ConvertTo-TsfDraftSlug -Value $ProjectId)-lane" } else { $LaneId }
    parent_mission_id = $ParentMissionId
    sibling_lane_ids = @(ConvertTo-TsfDraftArray $SiblingLaneIds)
    role_permission_profile_id = $ProposedWorkerRole
    role_output_contract = "Use worker role registry output contract for $ProposedWorkerRole."
    verifier_role = "verifier_worker"
    escalation_policy_id = if ($classification -eq "NEEDS_CHATGPT_HQ") { "hq_packet_required" } else { "local_only_no_api" }
}

$draft = [pscustomobject]@{
    draft_schema = "project_main_bot_mission_draft_v1"
    classification = $classification
    natural_request = $NaturalRequest
    normalized_intent = [pscustomobject]@{
        requested_goal = $goal
        proposed_worker_role = $ProposedWorkerRole
        lane = $Lane
        hard_gate_detected = ($classification -in @("NEEDS_TIM_APPROVAL", "BLOCKED_UNSAFE"))
    }
    mission_packet = $missionPacket
    role_extension = $roleExtension
    adapter_notes = @(
        "Draft only; does not execute missions.",
        "Existing mission packet stays compatible with mission_schema_v1.",
        "Run Test-TsfWorkerRolePermission before worker handoff."
    )
}

if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $draft | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}

$draft
