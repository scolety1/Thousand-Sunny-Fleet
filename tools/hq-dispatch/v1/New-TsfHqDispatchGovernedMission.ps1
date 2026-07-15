[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$TestOnlyQueueRoot = '',
    [ValidateSet('NONE','APPROVAL','CLARIFICATION')][string]$TestOnlyInitialTimKind = 'NONE',
    [switch]$UnsupportedDevelopmentMode
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
. (Join-Path $repoRoot 'tools\codex-fleet-enforcement-kernel.ps1')
Import-Module (Join-Path $repoRoot 'tools\TsfDurableContract.psm1') -Force

function Get-ClosedInput {
    $raw = [Console]::In.ReadToEnd()
    if ([Text.Encoding]::UTF8.GetByteCount($raw) -gt 16384) { throw 'HQ_SUBMISSION_INPUT_TOO_LARGE' }
    try { $value = $raw | ConvertFrom-Json -ErrorAction Stop } catch { throw 'HQ_SUBMISSION_INPUT_INVALID_JSON' }
    $allowed = @('mission_id','mission_revision','natural_request','parent_mission_revision','source_result_id','tim_required_request_id','response_id','response_record_sha256')
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
$isRevision = $inputValue.PSObject.Properties.Name -contains 'parent_mission_revision'
$naturalRequest = if ($inputValue.PSObject.Properties.Name -contains 'natural_request') { ([string]$inputValue.natural_request).Trim() } else { '' }
Assert-BoundedText $missionId 160 'mission_id'
if ($missionId -notmatch '^[A-Za-z0-9._:-]{8,160}$' -or $revision -lt 1) { throw 'HQ_SUBMISSION_INVALID_IDENTITY' }
if (!$isRevision) {
    Assert-BoundedText $naturalRequest 4000 'natural_request'
    if ($revision -ne 1) { throw 'HQ_INITIAL_MISSION_REVISION_MUST_BE_ONE' }
} else {
    $revisionFields = @('parent_mission_revision','source_result_id','tim_required_request_id','response_id','response_record_sha256')
    $missingRevisionFields = @($revisionFields | Where-Object { !($inputValue.PSObject.Properties.Name -contains $_) })
    if ($missingRevisionFields.Count -or $inputValue.PSObject.Properties.Name -contains 'natural_request') { throw 'HQ_REVISION_INPUT_CONTRACT_INVALID' }
    if ([int]$inputValue.parent_mission_revision -lt 1 -or $revision -ne ([int]$inputValue.parent_mission_revision + 1)) { throw 'HQ_REVISION_SEQUENCE_INVALID' }
    if ([string]$inputValue.source_result_id -ne "canonical-result-$missionId-$([int]$inputValue.parent_mission_revision)") { throw 'HQ_REVISION_SOURCE_RESULT_MISMATCH' }
    if ([string]$inputValue.tim_required_request_id -notmatch '^timreq-[a-f0-9]{32}$' -or [string]$inputValue.response_id -notmatch '^hq-response-[A-Za-z0-9-]{16,80}$' -or [string]$inputValue.response_record_sha256 -notmatch '^[a-f0-9]{64}$') { throw 'HQ_REVISION_RESPONSE_BINDING_INVALID' }
}
if ($TestOnlyInitialTimKind -ne 'NONE') {
    if ($isRevision -or !$TestOnlyQueueRoot) { throw 'HQ_TEST_TIM_KIND_REQUIRES_INITIAL_ISOLATED_FIXTURE' }
    $fixtureRoot = Get-TsfKernelFullPath (Join-Path $repoRoot '.codex-local\fixtures')
    if (!(Test-TsfKernelPathInside (Get-TsfKernelFullPath $TestOnlyQueueRoot) $fixtureRoot)) { throw 'HQ_TEST_QUEUE_ROOT_OUTSIDE_FIXTURES' }
}
if ($UnsupportedDevelopmentMode -and !$TestOnlyQueueRoot) { throw 'HQ_DEVELOPMENT_MODE_REQUIRES_ISOLATED_FIXTURE' }

$responseRecord = $null
$responseRecordPath = ''
$responseRecordHash = ''
$sourceMission = $null
$sourceRequest = $null
if ($isRevision) {
    $parentRevision = [int]$inputValue.parent_mission_revision
    $sourcePlan = New-TsfCompleteRuntimePathPlan -MissionId $missionId -MissionRevision $parentRevision -RunId ([string]$inputValue.source_result_id)
    $sourceMissionPath = [string]$sourcePlan.registry_mission_path
    $responseRecordPath = [string]$sourcePlan.queue_plan.artifacts.context_update
    if (!(Test-Path -LiteralPath $sourceMissionPath -PathType Leaf) -or !(Test-Path -LiteralPath $responseRecordPath -PathType Leaf)) { throw 'HQ_REVISION_CANONICAL_SOURCE_MISSING' }
    $responseRecordHash = (Get-FileHash -LiteralPath $responseRecordPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($responseRecordHash -ne [string]$inputValue.response_record_sha256) { throw 'HQ_REVISION_RESPONSE_RECORD_HASH_MISMATCH' }
    $responseRecord = Read-TsfKernelJson $responseRecordPath
    $responseValidation = Test-TsfJsonContract $responseRecord (Join-Path $repoRoot 'fleet\control\tim-required-response.schema.v1.json')
    if (!$responseValidation.valid) { throw "HQ_REVISION_RESPONSE_RECORD_INVALID: $($responseValidation.errors -join '; ')" }
    if ([string]$responseRecord.response_id -ne [string]$inputValue.response_id -or [string]$responseRecord.source_request.request_id -ne [string]$inputValue.tim_required_request_id -or [int]$responseRecord.source_request.mission_revision -ne $parentRevision -or [string]$responseRecord.source_request.result_id -ne [string]$inputValue.source_result_id) { throw 'HQ_REVISION_RESPONSE_IDENTITY_MISMATCH' }
    if ([string]$responseRecord.response_type -eq 'DENY_REQUEST' -or $null -eq $responseRecord.revision -or [int]$responseRecord.revision.mission_revision -ne $revision) { throw 'HQ_REVISION_NOT_AUTHORIZED_BY_RESPONSE' }
    $sourceMission = Read-TsfKernelJson $sourceMissionPath
    $sourceLifecycle = Read-TsfKernelJson ([string]$sourcePlan.lifecycle_plan.artifacts.lifecycle_result)
    $sourceRequest = $sourceLifecycle.tim_required_request
    if ([string]$sourceLifecycle.terminal_status -ne 'TIM_REQUIRED' -or [string]$sourceRequest.request_id -ne [string]$inputValue.tim_required_request_id) { throw 'HQ_REVISION_SOURCE_NOT_TERMINAL_TIM_REQUIRED' }
    $naturalRequest = [string]$sourceMission.original_request
}

$draftRequest = if ($isRevision -and [string]$responseRecord.response_type -eq 'PROVIDE_CLARIFICATION') { "$naturalRequest`nOperator clarification: $([string]$responseRecord.response_payload)" } else { $naturalRequest }
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
    -ParentMissionId $(if($isRevision){$missionId}else{''}) `
    -CreatedBy 'tsf_hq_dispatch_tim_relay_v1'

$authorityRelevantChange = $isRevision -and [string]$responseRecord.response_type -eq 'PROVIDE_CLARIFICATION' -and [string]$draft.classification -ne 'SAFE_LOCAL_MISSION'
if (!$isRevision -and [string]$draft.classification -ne 'SAFE_LOCAL_MISSION') { throw "HQ_SUBMISSION_CLASSIFICATION_REJECTED: $($draft.classification)" }
if ($isRevision -and [string]$draft.classification -eq 'BLOCKED_UNSAFE') { throw 'HQ_REVISION_CLARIFICATION_CLASSIFIED_UNSAFE' }
$git = Get-TsfKernelGitState $repoRoot
if (!$git.can_capture) { throw 'HQ_SUBMISSION_GIT_STATE_UNAVAILABLE' }
$policy = Get-TsfPolicyFingerprint (Join-Path $repoRoot 'fleet\control\policy-manifest.v1.json') $repoRoot -UnsupportedDevelopmentMode:$UnsupportedDevelopmentMode
$route = Resolve-TsfModelRouting 'BALANCED' 'CODEX'
$created = if($isRevision){[datetimeoffset]::Parse([string]$responseRecord.recorded_at)}else{[datetimeoffset]::UtcNow}
$forbidden = @(
    'push','merge','deploy','install','install_packages','migration','network','open_network_port','api_bridge',
    'product_repo_inspection','product_repo_mutation','canonical_nwr_inspection','canonical_nwr_mutation',
    'normal_nwr_packet_read','background_runner','persistent_runner','all_fleet','secrets','credential_change',
    'privatelens','proof_run','app_wiring','ranking_formula_source_truth_promotion','hidden_sort','recommendation_behavior'
) | Sort-Object -Unique
$approvalRequirements = @()
$approvalReferences = @()
$clarificationRequirements = @()
$clarificationReferences = @()
$revisionContext = $null
$missionExpiry = $created.AddMinutes(30)
if ($TestOnlyInitialTimKind -eq 'APPROVAL') {
    $approvalRequirements = @([pscustomobject][ordered]@{
        exact_action='tsf_hq_dispatch_safe_fixture_execution';exact_paths=@('fleet/control/policy-manifest.v1.json');access_level='READ_ONLY';network_policy='PROHIBITED';control_plane_service_network_policy='CODEX_SERVICE_ONLY';worker_tool_network_policy='DISABLED';reason='A deterministic TSF-local fixture requires one exact operator approval before its read-only worker may run.';expires_at=$missionExpiry.ToString('o');max_uses=1;reuse_policy='SINGLE_USE'
    })
} elseif ($TestOnlyInitialTimKind -eq 'CLARIFICATION') {
    $clarificationRequirements = @([pscustomobject][ordered]@{
        question='Confirm that the bounded proof should read only fleet/control/policy-manifest.v1.json and return the exact fixture response.';scope='TSF-local read-only policy manifest fixture only.';reason='The deterministic proof requires one bounded operator clarification before a governed revision is created.';expires_at=$missionExpiry.ToString('o')
    })
}
if ($isRevision) {
    $revisionContext = [pscustomobject][ordered]@{
        parent_mission_revision=[int]$inputValue.parent_mission_revision;supersedes_result_id=[string]$inputValue.source_result_id;tim_request_id=[string]$inputValue.tim_required_request_id;response_type=[string]$responseRecord.response_type;response_id=[string]$responseRecord.response_id;response_record_sha256=$responseRecordHash;route_classification=[string]$draft.classification;authority_relevant_change=$authorityRelevantChange;approval_id=if($null-ne$responseRecord.approval){[string]$responseRecord.approval.approval_id}else{$null}
    }
    if ([string]$responseRecord.response_type -eq 'APPROVE_EXACT_REQUEST') {
        if ([string]$sourceRequest.request_kind -ne 'APPROVAL_REQUIRED' -or $null -eq $responseRecord.approval) { throw 'HQ_REVISION_APPROVAL_SOURCE_INVALID' }
        $approvalReferences = @([pscustomobject][ordered]@{
            approval_id=[string]$responseRecord.approval.approval_id;exact_action=[string]$sourceRequest.operation;request_id=[string]$sourceRequest.request_id;request_evidence_sha256=[string]$responseRecord.request_evidence_sha256;source_mission_revision=[int]$sourceRequest.mission_revision;source_run_id=[string]$sourceRequest.run_id;source_result_id=[string]$sourceRequest.result_id;response_id=[string]$responseRecord.response_id
        })
        $missionExpiry = [datetimeoffset]::Parse([string]$sourceRequest.expires_at)
    } elseif ([string]$responseRecord.response_type -eq 'PROVIDE_CLARIFICATION') {
        if ([string]$sourceRequest.request_kind -ne 'CLARIFICATION_REQUIRED') { throw 'HQ_REVISION_CLARIFICATION_SOURCE_INVALID' }
        $clarificationReferences = @([pscustomobject][ordered]@{
            request_id=[string]$sourceRequest.request_id;response_id=[string]$responseRecord.response_id;response_sha256=[string]$responseRecord.response_payload_sha256;response_record_path=$responseRecordPath;response_record_sha256=$responseRecordHash
        })
        if ($authorityRelevantChange) {
            $approvalRequirements = @([pscustomobject][ordered]@{
                exact_action='hq_dispatch_authority_relevant_revision';exact_paths=@('fleet/control/policy-manifest.v1.json');access_level='READ_ONLY';network_policy='PROHIBITED';control_plane_service_network_policy='CODEX_SERVICE_ONLY';worker_tool_network_policy='DISABLED';reason='Project Main Bot detected an authority-relevant route change in the clarification; a fresh exact approval is required before execution.';expires_at=$created.AddMinutes(15).ToString('o');max_uses=1;reuse_policy='SINGLE_USE'
            })
            $missionExpiry = $created.AddMinutes(15)
        }
    }
}
$mission = [pscustomobject][ordered]@{
    schema_version = 'tsf_mission_envelope_v1'
    mission_id = $missionId
    mission_revision = $revision
    parent_mission_id = if($isRevision){$missionId}else{$null}
    project_id = 'TSF_CONTROL_PLANE'
    original_request = $naturalRequest
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
    approval_requirements = @($approvalRequirements)
    approval_references = @($approvalReferences)
    clarification_requirements = @($clarificationRequirements)
    clarification_references = @($clarificationReferences)
    revision_context = $revisionContext
    policy = [pscustomobject]@{
        policy_commit = [string]$policy.policy_commit
        manifest_version = 'tsf_policy_manifest_v1'
        fingerprint = [string]$policy.fingerprint
        mission_schema_version = 'tsf_mission_envelope_v1'
        expected_result_schema_version = 'tsf_result_envelope_v1'
    }
    created_at = $created.ToString('o')
    expires_at = $missionExpiry.ToString('o')
    stale_state_behavior = 'TIM_REQUIRED'
    required_result_envelope_version = 'tsf_result_envelope_v1'
}

$validation = Test-TsfMissionEnvelope $mission
if (!$validation.valid) { throw "HQ_SUBMISSION_DURABLE_MISSION_INVALID: $($validation.errors -join '; ')" }
$runId = "canonical-result-$missionId-$revision"
$plan = New-TsfCompleteRuntimePathPlan $missionId $revision $runId
$missionPath = [string]$plan.registry_mission_path
$missionReplay = $false
if (Test-Path -LiteralPath $missionPath -PathType Leaf) {
    $existingMission = Read-TsfKernelJson $missionPath
    if ((Get-TsfContractJsonHash $existingMission) -ne (Get-TsfContractJsonHash $mission)) { throw 'HQ_CANONICAL_MISSION_CHANGED_REPLAY' }
    $missionReplay = $true
} else {
    Write-TsfKernelAtomicJson -Value $mission -Path $missionPath | Out-Null
}

$prepareParams = @{ DurableMissionPath = $missionPath }
if ($TestOnlyQueueRoot) {
    $fixtureRoot = Get-TsfKernelFullPath (Join-Path $repoRoot '.codex-local\fixtures')
    $queueFull = Get-TsfKernelFullPath $TestOnlyQueueRoot
    if (!(Test-TsfKernelPathInside $queueFull $fixtureRoot)) { throw 'HQ_TEST_QUEUE_ROOT_OUTSIDE_FIXTURES' }
    $prepareParams.QueueRoot = $queueFull
    $prepareParams.TestOnlyAllowAlternateQueueRoot = $true
}
$preparation = & (Join-Path $repoRoot 'tools\New-TsfCanonicalQueueMission.ps1') @prepareParams
if ([string]$preparation.status -ne 'PREPARED' -or [string]::IsNullOrWhiteSpace([string]$preparation.queue_record_path)) { throw 'HQ_CANONICAL_QUEUE_PREPARATION_FAILED' }

[Console]::Out.WriteLine(([pscustomobject][ordered]@{
    schema_version = 'tsf_hq_dispatch_canonical_submission_result_v1'
    mission_id = $missionId
    mission_revision = $revision
    parent_mission_id = if($isRevision){$missionId}else{$null}
    parent_mission_revision = if($isRevision){[int]$inputValue.parent_mission_revision}else{$null}
    source_result_id = if($isRevision){[string]$inputValue.source_result_id}else{$null}
    tim_required_request_id = if($isRevision){[string]$inputValue.tim_required_request_id}else{$null}
    response_id = if($isRevision){[string]$inputValue.response_id}else{$null}
    response_record_path = if($isRevision){$responseRecordPath}else{$null}
    response_record_sha256 = if($isRevision){$responseRecordHash}else{$null}
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
    context_update_path = [string]$plan.queue_plan.artifacts.context_update
    approval_ledger_path = if($isRevision -and $null-ne$responseRecord.approval){[string]$responseRecord.approval.ledger_path}else{[string]$plan.queue_plan.artifacts.approval_ledger}
    idempotent_replay = [bool]($missionReplay -or [bool]$preparation.idempotent_replay)
    policy_fingerprint = [string]$policy.fingerprint
    route = [pscustomobject]@{ worker_role=$mission.worker_role; model_alias=$mission.model_policy_alias; resolved_model=$mission.resolved_model; effort=$mission.reasoning_effort; assurance=$mission.model_selection_assurance }
    access = [pscustomobject]@{ permission_mode=$mission.permission_mode; network_policy=$mission.network_policy; control_plane_service_network_policy=$mission.control_plane_service_network_policy; worker_tool_network_policy=$mission.worker_tool_network_policy; allowed_reads=@($mission.allowed_reads); allowed_writes=@($mission.allowed_writes) }
    source_bindings = @('tools/New-TsfProjectMainBotMissionDraft.ps1','tools/TsfDurableContract.Canonical.ps1','tools/New-TsfCanonicalQueueMission.ps1')
    authority = [pscustomobject]@{ approval_granted=$false; merge_granted=$false; deployment_granted=$false; production_granted=$false }
} | ConvertTo-Json -Depth 30 -Compress))
