[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$TestOnlyQueueRoot = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
. (Join-Path $repoRoot 'tools\codex-fleet-enforcement-kernel.ps1')
Import-Module (Join-Path $repoRoot 'tools\TsfDurableContract.psm1') -Force

function Get-ClosedInput {
    $raw = [Console]::In.ReadToEnd()
    if ([Text.Encoding]::UTF8.GetByteCount($raw) -gt 16384) { throw 'HQ_SUBMISSION_INPUT_TOO_LARGE' }
    try { $value = $raw | ConvertFrom-Json -ErrorAction Stop } catch { throw 'HQ_SUBMISSION_INPUT_INVALID_JSON' }
    $allowed = @('mission_id','mission_revision','natural_request')
    $unknown = @($value.PSObject.Properties.Name | Where-Object { $allowed -notcontains $_ })
    if ($unknown.Count) { throw "HQ_SUBMISSION_UNKNOWN_FIELD: $($unknown -join ',')" }
    return $value
}

function Assert-BoundedText([string]$Value, [int]$Maximum, [string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -gt $Maximum -or $Value.IndexOf([char]0) -ge 0) {
        throw "HQ_SUBMISSION_INVALID_$($Name.ToUpperInvariant())"
    }
}

$inputValue = Get-ClosedInput
$missionId = [string]$inputValue.mission_id
$revision = [int]$inputValue.mission_revision
$naturalRequest = ([string]$inputValue.natural_request).Trim()
Assert-BoundedText $missionId 160 'mission_id'
Assert-BoundedText $naturalRequest 4000 'natural_request'
if ($missionId -notmatch '^[A-Za-z0-9._:-]{8,160}$' -or $revision -lt 1) { throw 'HQ_SUBMISSION_INVALID_IDENTITY' }

$draftRequest = $naturalRequest
$draft = & (Join-Path $repoRoot 'tools\New-TsfProjectMainBotMissionDraft.ps1') `
    -ProjectId 'thousand-sunny-fleet' `
    -NaturalRequest $draftRequest `
    -Lane 'MASTER_TSF_CONTROL_PLANE' `
    -RequestedGoal $draftRequest `
    -ProposedWorkerRole 'researcher_source_tracer_worker' `
    -AllowedReads @('fleet/control/policy-manifest.v1.json') `
    -AllowedWrites @() `
    -ExpectedArtifacts @('fleet/control/policy-manifest.v1.json') `
    -StopConditions @('scope-gate|approval_required|Stop if scope, access, network, path, model, effort, or authority changes.','fixture-only|manual|Stop after the bounded read-only fixture result.') `
    -RepoPath $repoRoot `
    -ParentMissionId '' `
    -CreatedBy 'tsf_hq_dispatch_request_result_relay_v1'

if ([string]$draft.classification -ne 'SAFE_LOCAL_MISSION') { throw "HQ_SUBMISSION_CLASSIFICATION_REJECTED: $($draft.classification)" }
$git = Get-TsfKernelGitState $repoRoot
if (!$git.can_capture) { throw 'HQ_SUBMISSION_GIT_STATE_UNAVAILABLE' }
$policy = Get-TsfPolicyFingerprint (Join-Path $repoRoot 'fleet\control\policy-manifest.v1.json') $repoRoot
$route = Resolve-TsfModelRouting 'BALANCED' 'CODEX'
$created = [datetimeoffset]::UtcNow
$forbidden = @(
    'push','merge','deploy','install','install_packages','migration','network','open_network_port','api_bridge',
    'product_repo_inspection','product_repo_mutation','canonical_nwr_inspection','canonical_nwr_mutation',
    'normal_nwr_packet_read','background_runner','persistent_runner','all_fleet','secrets','credential_change',
    'privatelens','proof_run','app_wiring','ranking_formula_source_truth_promotion','hidden_sort','recommendation_behavior'
) | Sort-Object -Unique
$mission = [pscustomobject][ordered]@{
    schema_version = 'tsf_mission_envelope_v1'
    mission_id = $missionId
    mission_revision = $revision
    parent_mission_id = $null
    project_id = 'TSF_CONTROL_PLANE'
    original_request = $draftRequest
    normalized_goal = 'Read the TSF-local fleet/control/policy-manifest.v1.json fixture and return exactly TSF_HQ_DISPATCH_READ_ONLY_GREEN. Do not use tools, modify files, access another repository, or use worker-tool network.'
    mission_type = 'hq_dispatch_read_only_vertical_slice'
    worker_role = [string]$draft.normalized_intent.proposed_worker_role
    recommended_surface = 'CODEX'
    model_policy_alias = [string]$route.stable_alias
    resolved_model = [string]$route.resolved_model
    reasoning_effort = [string]$route.reasoning_effort
    model_selection_assurance = 'RECOMMENDED_ONLY'
    permission_mode = 'READ_ONLY'
    network_policy = 'PROHIBITED'
    control_plane_service_network_policy = 'CODEX_SERVICE_ONLY'
    worker_tool_network_policy = 'DISABLED'
    repository_allowlist = @($repoRoot)
    forbidden_repositories = @('PRODUCT_REPOS','NORMAL_NWR_REPOSITORY')
    source_allowlist = @('fleet/control/policy-manifest.v1.json')
    forbidden_sources = @('NORMAL_NWR_PACKETS','SECRETS','CREDENTIALS','PRIVATELENS','PRODUCT_REPOS')
    branch_worktree_policy = [pscustomobject]@{
        branch_required = $true
        worktree_required = $true
        expected_branch = [string]$git.branch
        expected_worktree = $repoRoot
        starting_head = [string]$git.head
        unexpected_advance_behavior = 'REJECT'
    }
    allowed_reads = @('fleet/control/policy-manifest.v1.json')
    allowed_writes = @()
    forbidden_actions = @($forbidden)
    completion_criteria = @('Bound foreground app-server read-only turn completes.','Independent canonical verifier passes.','Canonical admission receipt is written.')
    required_tests = @([pscustomobject]@{ test_id = 'hq-dispatch-read-only-exact-response'; required = $true; command = 'exact-response-sha256:106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba' })
    required_artifacts = @([pscustomobject]@{ path = 'fleet/control/policy-manifest.v1.json'; hash_required = $true })
    required_verifier_independence = 'SEPARATE_ROLE'
    stop_conditions = @('Unexpected file touch.','Worker-tool network request.','Native identity mismatch.','Timeout.','Verifier failure.','TIM_REQUIRED request.')
    approval_references = @()
    policy = [pscustomobject]@{
        policy_commit = [string]$policy.policy_commit
        manifest_version = 'tsf_policy_manifest_v1'
        fingerprint = [string]$policy.fingerprint
        mission_schema_version = 'tsf_mission_envelope_v1'
        expected_result_schema_version = 'tsf_result_envelope_v1'
    }
    created_at = $created.ToString('o')
    expires_at = $created.AddMinutes(30).ToString('o')
    stale_state_behavior = 'TIM_REQUIRED'
    required_result_envelope_version = 'tsf_result_envelope_v1'
}

$validation = Test-TsfMissionEnvelope $mission
if (!$validation.valid) { throw "HQ_SUBMISSION_DURABLE_MISSION_INVALID: $($validation.errors -join '; ')" }
$runId = "canonical-result-$missionId-$revision"
$plan = New-TsfCompleteRuntimePathPlan $missionId $revision $runId
$missionPath = [string]$plan.registry_mission_path
Write-TsfKernelJson $mission $missionPath

$prepareParams = @{ DurableMissionPath = $missionPath }
if ($TestOnlyQueueRoot) {
    $fixtureRoot = Get-TsfKernelFullPath (Join-Path $repoRoot '.codex-local\fixtures')
    $queueFull = Get-TsfKernelFullPath $TestOnlyQueueRoot
    if (!(Test-TsfKernelPathInside $queueFull $fixtureRoot)) { throw 'HQ_TEST_QUEUE_ROOT_OUTSIDE_FIXTURES' }
    $prepareParams.QueueRoot = $queueFull
    $prepareParams.TestOnlyAllowAlternateQueueRoot = $true
}
$preparation = & (Join-Path $repoRoot 'tools\New-TsfCanonicalQueueMission.ps1') @prepareParams
if ([string]$preparation.status -ne 'PREPARED' -or ![bool]$preparation.queue_record_created) { throw 'HQ_CANONICAL_QUEUE_PREPARATION_FAILED' }

[Console]::Out.WriteLine(([pscustomobject][ordered]@{
    schema_version = 'tsf_hq_dispatch_canonical_submission_result_v1'
    mission_id = $missionId
    mission_revision = $revision
    parent_mission_id = $null
    mission_path = $missionPath
    mission_sha256 = (Get-FileHash $missionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    queue_record_path = [string]$preparation.queue_record_path
    queue_document_sha256 = [string]$preparation.queue_document_sha256
    queue_state = 'inbox'
    run_id = $runId
    queue_result_path = [string]$plan.queue_plan.artifacts.queue_result
    lifecycle_result_path = [string]$plan.lifecycle_plan.artifacts.lifecycle_result
    adapter_result_path = [string]$plan.adapter_plan.artifacts.adapter_result
    verifier_result_path = [string]$plan.lifecycle_plan.artifacts.verifier_result
    preservation_packet_path = [string]$plan.preservation_plan.artifacts.preservation_packet
    approval_ledger_path = [string]$plan.queue_plan.artifacts.approval_ledger
    policy_fingerprint = [string]$policy.fingerprint
    route = [pscustomobject]@{ worker_role=$mission.worker_role; model_alias=$mission.model_policy_alias; resolved_model=$mission.resolved_model; effort=$mission.reasoning_effort; assurance=$mission.model_selection_assurance }
    access = [pscustomobject]@{ permission_mode=$mission.permission_mode; network_policy=$mission.network_policy; control_plane_service_network_policy=$mission.control_plane_service_network_policy; worker_tool_network_policy=$mission.worker_tool_network_policy; allowed_reads=@($mission.allowed_reads); allowed_writes=@($mission.allowed_writes) }
    source_bindings = @('tools/New-TsfProjectMainBotMissionDraft.ps1','tools/TsfDurableContract.Canonical.ps1','tools/New-TsfCanonicalQueueMission.ps1')
    authority = [pscustomobject]@{ approval_granted=$false; merge_granted=$false; deployment_granted=$false; production_granted=$false }
} | ConvertTo-Json -Depth 30 -Compress))
