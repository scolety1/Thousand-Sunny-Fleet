[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$TestOnlyQueueRoot = '',
    [ValidateSet('NONE','APPROVAL','CLARIFICATION')][string]$TestOnlyInitialTimKind = 'NONE',
    [switch]$UnsupportedDevelopmentMode
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
. (Join-Path $repoRoot 'tools\codex-fleet-enforcement-kernel.ps1')
. (Join-Path $repoRoot 'tools\TsfSemanticIntegrity.ps1')
Import-Module (Join-Path $repoRoot 'tools\TsfDurableContract.psm1') -Force

function Get-ClosedInput {
    $raw = [Console]::In.ReadToEnd()
    if ([Text.Encoding]::UTF8.GetByteCount($raw) -gt 16384) { throw 'HQ_SUBMISSION_INPUT_TOO_LARGE' }
    try { $value = $raw | ConvertFrom-Json -ErrorAction Stop } catch { throw 'HQ_SUBMISSION_INPUT_INVALID_JSON' }
    $allowed = @(
        'mission_id','mission_revision','natural_request','preview_id','preview_sha256','request_hash','submission_id','reviewed_exact_response_contract','parent_mission_revision','source_result_id','tim_required_request_id','response_id','response_record_sha256',
        'recovery_parent_mission_id','recovery_parent_mission_revision','recovery_parent_run_id','recovery_source_evidence_sha256','recovery_evidence_directory'
    )
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
$isRecovery = $inputValue.PSObject.Properties.Name -contains 'recovery_parent_mission_id'
$naturalRequest = if ($inputValue.PSObject.Properties.Name -contains 'natural_request') { ([string]$inputValue.natural_request).Trim() } else { '' }
Assert-BoundedText $missionId 160 'mission_id'
if ($missionId -notmatch '^[A-Za-z0-9._:-]{8,160}$' -or $revision -lt 1) { throw 'HQ_SUBMISSION_INVALID_IDENTITY' }
if ($isRevision -and $isRecovery) { throw 'HQ_SUBMISSION_REVISION_AND_RECOVERY_CONFLICT' }
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
$recoveryParentId = ''
$recoveryParentRevision = 0
$recoveryParentRunId = ''
$recoveryEvidenceDirectory = ''
$recoverySourceEvidenceSha256 = ''
if ($isRecovery) {
    $requiredRecoveryFields = @('recovery_parent_mission_id','recovery_parent_mission_revision','recovery_parent_run_id','recovery_source_evidence_sha256','recovery_evidence_directory')
    $missingRecoveryFields = @($requiredRecoveryFields | Where-Object { !($inputValue.PSObject.Properties.Name -contains $_) })
    if ($missingRecoveryFields.Count) { throw "HQ_RECOVERY_INPUT_MISSING_FIELD: $($missingRecoveryFields -join ',')" }
    $recoveryParentId = [string]$inputValue.recovery_parent_mission_id
    $recoveryParentRevision = [int]$inputValue.recovery_parent_mission_revision
    $recoveryParentRunId = [string]$inputValue.recovery_parent_run_id
    $recoverySourceEvidenceSha256 = [string]$inputValue.recovery_source_evidence_sha256
    $recoveryEvidenceDirectory = Get-TsfKernelFullPath ([string]$inputValue.recovery_evidence_directory)
    Assert-BoundedText $recoveryParentId 160 'recovery_parent_mission_id'
    if ($recoveryParentId -eq $missionId -or $recoveryParentRevision -lt 1 -or $recoveryParentRunId -ne "canonical-result-$recoveryParentId-$recoveryParentRevision" -or $recoverySourceEvidenceSha256 -notmatch '^[a-f0-9]{64}$') { throw 'HQ_RECOVERY_IDENTITY_INVALID' }
    $runtimeRoot = Get-TsfCanonicalRuntimeRoot
    if (!(Test-TsfKernelPathInside $recoveryEvidenceDirectory $runtimeRoot) -or !(Test-TsfKernelReparseContained $recoveryEvidenceDirectory $repoRoot)) { throw 'HQ_RECOVERY_EVIDENCE_OUTSIDE_CANONICAL_RUNTIME' }
    $stopPath = Join-Path $recoveryEvidenceDirectory 'STOP_RECORD.json'
    $snapshotPath = Join-Path $recoveryEvidenceDirectory 'queue-record-preflight-pending.json'
    if (!(Test-Path -LiteralPath $stopPath -PathType Leaf) -or !(Test-Path -LiteralPath $snapshotPath -PathType Leaf)) { throw 'HQ_RECOVERY_EVIDENCE_MISSING' }
    $stopRecord = Read-TsfKernelJson $stopPath
    if ([string]$stopRecord.schema_version -ne 'tsf_hq_dispatch_interruption_evidence_v1' -or [string]$stopRecord.mission_id -ne $recoveryParentId -or [int]$stopRecord.mission_revision -ne $recoveryParentRevision -or [string]$stopRecord.run_id -ne $recoveryParentRunId -or [string]$stopRecord.source_evidence_hash -ne $recoverySourceEvidenceSha256 -or [bool]$stopRecord.original_attempt_completed -or [bool]$stopRecord.original_attempt_resumable) { throw 'HQ_RECOVERY_STOP_RECORD_INVALID' }
    $snapshotHash = (Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($snapshotHash -ne [string]$stopRecord.queue_snapshot_sha256) { throw 'HQ_RECOVERY_QUEUE_SNAPSHOT_HASH_MISMATCH' }
    $sourcePlan = New-TsfCompleteRuntimePathPlan -MissionId $recoveryParentId -MissionRevision $recoveryParentRevision -RunId $recoveryParentRunId
    if (!(Test-Path -LiteralPath ([string]$sourcePlan.registry_mission_path) -PathType Leaf)) { throw 'HQ_RECOVERY_SOURCE_MISSION_MISSING' }
    $sourceLifecyclePath = [string]$sourcePlan.lifecycle_plan.artifacts.lifecycle_result
    if (Test-Path -LiteralPath $sourceLifecyclePath -PathType Leaf) {
        $sourceLifecycle = Read-TsfKernelJson $sourceLifecyclePath
        if ([string]$sourceLifecycle.terminal_status -eq 'TIM_REQUIRED' -or [string]$sourceLifecycle.terminal_status -like 'COMPLETED*') { throw 'HQ_RECOVERY_TERMINAL_SOURCE_REJECTED' }
    }
    $sourceAdmission = @(Get-ChildItem -LiteralPath ([string]$sourcePlan.preservation_plan.receipt_root) -Filter 'a-*.json' -File -ErrorAction SilentlyContinue)
    if ($sourceAdmission.Count) { throw 'HQ_RECOVERY_COMPLETED_OR_ADMITTED_SOURCE_REJECTED' }
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
$recoverySourceMission = $null
$sourceRequest = $null
$originalIntent = $null
$scopeTransformation = $null
$taskCompletionContract = $null
$resultValidationMode = 'GENERAL_RESULT_V2'
$storedPreview = $null
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

$exactResponseContract = $null
if ($isRevision) {
    if ($sourceMission.PSObject.Properties.Name -contains 'exact_response_contract' -and $null -ne $sourceMission.exact_response_contract) {
        $sourceContract = $sourceMission.exact_response_contract
        $exactResponseContract = New-TsfExactResponseContract -NaturalRequest $naturalRequest -PreviewId ([string]$sourceContract.preview_binding.preview_id) -PreviewArtifactSha256 ([string]$sourceContract.preview_binding.preview_artifact_sha256) -MissionId $missionId -MissionRevision $revision
        if ([string]$exactResponseContract.semantic_contract_sha256 -ne [string]$sourceContract.semantic_contract_sha256) { throw 'HQ_REVISION_EXACT_RESPONSE_CONTRACT_CHANGED' }
    }
    $originalIntent = $sourceMission.original_operator_intent
    $scopeTransformation = $sourceMission.scope_transformation
    $taskCompletionContract = $sourceMission.task_completion_contract
    $resultValidationMode = [string]$sourceMission.result_validation_mode
} elseif ($isRecovery) {
    $recoverySourceMission = Read-TsfKernelJson ([string]$sourcePlan.registry_mission_path)
    if ($recoverySourceMission.PSObject.Properties.Name -contains 'exact_response_contract' -and $null -ne $recoverySourceMission.exact_response_contract) {
        $sourceContract = $recoverySourceMission.exact_response_contract
        $exactResponseContract = New-TsfExactResponseContract -NaturalRequest $naturalRequest -PreviewId ([string]$sourceContract.preview_binding.preview_id) -PreviewArtifactSha256 ([string]$sourceContract.preview_binding.preview_artifact_sha256) -MissionId $missionId -MissionRevision $revision
        if ([string]$exactResponseContract.semantic_contract_sha256 -ne [string]$sourceContract.semantic_contract_sha256) { throw 'HQ_RECOVERY_EXACT_RESPONSE_CONTRACT_CHANGED' }
    }
    $originalIntent = $recoverySourceMission.original_operator_intent
    $scopeTransformation = $recoverySourceMission.scope_transformation
    $taskCompletionContract = $recoverySourceMission.task_completion_contract
    $resultValidationMode = [string]$recoverySourceMission.result_validation_mode
} else {
    $previewFields = @('preview_id','preview_sha256','request_hash','submission_id','reviewed_exact_response_contract')
    $presentPreviewFieldCount = @($previewFields | Where-Object { $inputValue.PSObject.Properties.Name -contains $_ }).Count
    if ($presentPreviewFieldCount -gt 0 -and $presentPreviewFieldCount -lt $previewFields.Count) { throw 'HQ_SUBMISSION_PARTIAL_PREVIEW_BINDING_REJECTED' }
    $hasPreviewBinding = $presentPreviewFieldCount -eq $previewFields.Count
    if (!$hasPreviewBinding -and !$TestOnlyQueueRoot) { throw 'HQ_SUBMISSION_REVIEWED_PREVIEW_BINDING_REQUIRED' }
    if ($hasPreviewBinding) {
        $previewId = [string]$inputValue.preview_id
        $previewSha256 = [string]$inputValue.preview_sha256
        $requestHash = [string]$inputValue.request_hash
        if ($previewId -notmatch '^hq-preview-[a-f0-9]{32}$' -or $previewSha256 -notmatch '^[a-f0-9]{64}$' -or $requestHash -notmatch '^[a-f0-9]{64}$' -or [string]$inputValue.submission_id -notmatch '^hq-submission-[0-9a-f-]{36}$') { throw 'HQ_SUBMISSION_PREVIEW_BINDING_INVALID' }
        if ((Get-TsfExactResponseLiteralSha256 $naturalRequest) -ne $requestHash) { throw 'HQ_SUBMISSION_REQUEST_HASH_MISMATCH' }
        $previewPath = Join-Path $repoRoot ".codex-local\hq-dispatch\preview\$previewId.route-preview.json"
        if (!(Test-Path -LiteralPath $previewPath -PathType Leaf) -or (Get-FileHash -LiteralPath $previewPath -Algorithm SHA256).Hash.ToLowerInvariant() -ne $previewSha256) { throw 'HQ_SUBMISSION_PREVIEW_STALE_OR_CHANGED' }
        $storedPreview = Read-TsfKernelJson $previewPath
        if ([string]$storedPreview.preview_id -ne $previewId -or [string]$storedPreview.record_kind -ne 'hq_dispatch_route_preview') { throw 'HQ_SUBMISSION_PREVIEW_IDENTITY_MISMATCH' }
        $recomputedUnbound = New-TsfExactResponseContract -NaturalRequest $naturalRequest -PreviewId $previewId
        $storedContract = $storedPreview.exact_response_contract
        if (($null -eq $storedContract) -ne ($null -eq $recomputedUnbound)) { throw 'HQ_SUBMISSION_STORED_RESPONSE_CONTRACT_MISMATCH' }
        if ($null -ne $storedContract -and (Get-TsfContractJsonHash $storedContract) -ne (Get-TsfContractJsonHash $recomputedUnbound)) { throw 'HQ_SUBMISSION_STORED_RESPONSE_CONTRACT_MISMATCH' }
        if ($null -eq $recomputedUnbound) {
            if ($null -ne $inputValue.reviewed_exact_response_contract -or [string]$storedPreview.result_validation_mode -ne 'GENERAL_RESULT_V2') { throw 'HQ_SUBMISSION_GENERAL_RESPONSE_CONTRACT_CHANGED' }
            $resultValidationMode = 'GENERAL_RESULT_V2'
        } else {
            $reviewedCheck = Test-TsfExactResponseContract -Contract $inputValue.reviewed_exact_response_contract -NaturalRequest $naturalRequest -PreviewId $previewId -PreviewArtifactSha256 $previewSha256
            if (!$reviewedCheck.valid) { throw "HQ_SUBMISSION_REVIEWED_RESPONSE_CONTRACT_INVALID: $($reviewedCheck.errors -join '; ')" }
            $exactResponseContract = New-TsfExactResponseContract -NaturalRequest $naturalRequest -PreviewId $previewId -PreviewArtifactSha256 $previewSha256 -MissionId $missionId -MissionRevision $revision
            $resultValidationMode = 'EXACT_LITERAL_V1'
        }
        foreach ($contractSpec in @(
            [pscustomobject]@{value=$storedPreview.original_operator_intent;schema='fleet\control\original-operator-intent.schema.v1.json';name='ORIGINAL_INTENT'},
            [pscustomobject]@{value=$storedPreview.scope_transformation;schema='fleet\control\scope-transformation.schema.v1.json';name='SCOPE_TRANSFORMATION'}
        )) { $contractValidation=Test-TsfJsonContract $contractSpec.value (Join-Path $repoRoot $contractSpec.schema);if(!$contractValidation.valid){throw "HQ_SUBMISSION_$($contractSpec.name)_INVALID: $($contractValidation.errors -join '; ')"} }
        $intentCheck = Test-TsfOriginalOperatorIntentContract -Contract $storedPreview.original_operator_intent -NaturalRequest $naturalRequest -PreviewId $previewId -RepositoryTarget $repoRoot -WorktreeTarget $repoRoot -ProhibitedOperations @($storedPreview.forbidden_actions)
        if (!$intentCheck.valid) { throw 'HQ_SUBMISSION_ORIGINAL_INTENT_CHANGED' }
        $originalIntent = $storedPreview.original_operator_intent
        $scopeTransformation = $storedPreview.scope_transformation
        $taskCompletionContract = $storedPreview.task_completion_contract
        if ([string]$storedPreview.submission_gate -ne 'SUBMITTABLE_AFTER_REVALIDATION' -or ![bool]$scopeTransformation.queue_allowed -or [bool]$scopeTransformation.operator_confirmation_required) { throw 'HQ_SUBMISSION_SCOPE_REDUCTION_REQUIRES_OPERATOR_DECISION_NO_QUEUE' }
    } elseif ($null -ne (Get-TsfExactResponseLiteralFromRequest -NaturalRequest $naturalRequest)) {
        throw 'HQ_TEST_EXACT_RESPONSE_REQUIRES_REVIEWED_PREVIEW'
    }
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
if (![bool]$git.branch_identity_available) { throw 'HQ_SUBMISSION_BRANCH_IDENTITY_UNAVAILABLE' }
if (![bool]$git.detached_head -and [string]::IsNullOrWhiteSpace([string]$git.branch)) { throw 'HQ_SUBMISSION_ATTACHED_BRANCH_IDENTITY_UNAVAILABLE' }
if ($null -ne $storedPreview) {
    $expectedScope = New-TsfScopeTransformationContract -OriginalIntent $originalIntent -AuthorizedMissionGoal $naturalRequest -ProposedOperations @($storedPreview.proposed_operations) -ProposedAccess 'READ_ONLY' -RepositoryTarget $repoRoot -WorktreeTarget $repoRoot -DetachedHead:([bool]$git.detached_head)
    if ((Get-TsfContractJsonHash $expectedScope) -ne (Get-TsfContractJsonHash $scopeTransformation)) { throw 'HQ_SUBMISSION_SCOPE_TRANSFORMATION_CHANGED' }
    if ($resultValidationMode -eq 'GENERAL_RESULT_V2') {
        $expectedCompletion = New-TsfTaskCompletionContract -RequiredTask $naturalRequest -OriginalIntent $originalIntent -ScopeTransformation $scopeTransformation
        if ($null -eq $taskCompletionContract -or (Get-TsfContractJsonHash $expectedCompletion) -ne (Get-TsfContractJsonHash $taskCompletionContract)) { throw 'HQ_SUBMISSION_TASK_COMPLETION_CONTRACT_CHANGED' }
        $completionValidation=Test-TsfJsonContract $taskCompletionContract (Join-Path $repoRoot 'fleet\control\task-completion-contract.schema.v1.json')
        if(!$completionValidation.valid){throw "HQ_SUBMISSION_TASK_COMPLETION_CONTRACT_INVALID: $($completionValidation.errors -join '; ')"}
    } elseif ($null -ne $taskCompletionContract) { throw 'HQ_SUBMISSION_EXACT_LITERAL_TASK_CONTRACT_SUBSTITUTED' }
}
$policy = Get-TsfPolicyFingerprint (Join-Path $repoRoot 'fleet\control\policy-manifest.v1.json') $repoRoot -UnsupportedDevelopmentMode:$UnsupportedDevelopmentMode
$route = Resolve-TsfModelRouting 'BALANCED' 'CODEX'
$created = if($isRevision){[datetimeoffset]::Parse([string]$responseRecord.recorded_at)}else{[datetimeoffset]::UtcNow}
$forbidden = @(
    'push','merge','deploy','install','install_packages','migration','network','open_network_port','api_bridge',
    'product_repo_inspection','product_repo_mutation','canonical_nwr_inspection','canonical_nwr_mutation',
    'normal_nwr_packet_read','background_runner','persistent_runner','all_fleet','secrets','credential_change',
    'privatelens','proof_run','app_wiring','ranking_formula_source_truth_promotion','hidden_sort','recommendation_behavior'
) | Sort-Object -Unique
if (!$isRevision -and !$isRecovery -and $null -eq $storedPreview -and $TestOnlyQueueRoot -and $resultValidationMode -eq 'GENERAL_RESULT_V2') {
    # Isolated TIM fixtures predate reviewed-preview submission. Keep them on
    # the same closed semantic contracts as production without granting them
    # a production submission bypass.
    $syntheticPreviewId = 'hq-preview-' + (Get-TsfContractJsonHash ([pscustomobject]@{ fixture_mission_id = $missionId })).Substring(0, 32)
    $originalIntent = New-TsfOriginalOperatorIntentContract -NaturalRequest $naturalRequest -PreviewId $syntheticPreviewId -RepositoryTarget $repoRoot -WorktreeTarget $repoRoot -ProhibitedOperations $forbidden
    $scopeTransformation = New-TsfScopeTransformationContract -OriginalIntent $originalIntent -AuthorizedMissionGoal $naturalRequest -ProposedOperations @($originalIntent.explicitly_requested_operations) -ProposedAccess 'READ_ONLY' -RepositoryTarget $repoRoot -WorktreeTarget $repoRoot -DetachedHead:([bool]$git.detached_head)
    if (![bool]$scopeTransformation.queue_allowed) { throw 'HQ_TEST_FIXTURE_SCOPE_TRANSFORMATION_NOT_QUEUEABLE' }
    $taskCompletionContract = New-TsfTaskCompletionContract -RequiredTask $naturalRequest -OriginalIntent $originalIntent -ScopeTransformation $scopeTransformation
}
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
$requiredResultTests = [object[]]$(if ($null -ne $exactResponseContract) { @([pscustomobject]@{ test_id = 'hq-dispatch-read-only-exact-response'; required = $true; command = "exact-response-sha256:$([string]$exactResponseContract.expected_literal_sha256)" }) } elseif ($null -ne $taskCompletionContract) { @([pscustomobject]@{ test_id = 'hq-dispatch-general-result-v2'; required = $true; command = "general-result-v2:$([string]$taskCompletionContract.task_completion_contract_identity_sha256)" }) } else { @([pscustomobject]@{ test_id = 'hq-dispatch-legacy-general-result-fail-closed'; required = $true; command = 'legacy-general-result-fail-closed-v1' }) })
$mission = [pscustomobject][ordered]@{
    schema_version = 'tsf_mission_envelope_v1'
    mission_id = $missionId
    mission_revision = $revision
    parent_mission_id = if($isRevision){$missionId}elseif($isRecovery){$recoveryParentId}else{$null}
    project_id = 'TSF_CONTROL_PLANE'
    original_request = $naturalRequest
    normalized_goal = $naturalRequest
    exact_response_contract = $exactResponseContract
    result_validation_mode = $resultValidationMode
    original_operator_intent = $originalIntent
    scope_transformation = $scopeTransformation
    task_completion_contract = $taskCompletionContract
    mission_type = $(if($resultValidationMode -eq 'GENERAL_RESULT_V2'){'hq_dispatch_general_result_v2'}else{'hq_dispatch_read_only_vertical_slice'})
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
        branch_required = ![bool]$git.detached_head
        worktree_required = $true
        expected_branch = if([bool]$git.detached_head){$null}else{[string]$git.branch}
        expected_worktree = $repoRoot
        starting_head = [string]$git.head
        unexpected_advance_behavior = 'REJECT'
    }
    allowed_reads = @('fleet/control/policy-manifest.v1.json')
    allowed_writes = @()
    forbidden_actions = @($forbidden)
    completion_criteria = $(if($null-ne$taskCompletionContract){@($taskCompletionContract.success_criteria)}else{@('The exact mission-bound literal is returned.','Independent canonical verifier passes.','Canonical admission receipt is written.')})
    required_tests = $requiredResultTests
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
if ($isRecovery) {
    $prepareParams.RecoveryFromMissionId = $recoveryParentId
    $prepareParams.RecoveryEvidenceDirectory = $recoveryEvidenceDirectory
}
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
    recovery_parent_mission_id = if($isRecovery){$recoveryParentId}else{$null}
    recovery_parent_mission_revision = if($isRecovery){$recoveryParentRevision}else{$null}
    recovery_parent_run_id = if($isRecovery){$recoveryParentRunId}else{$null}
    recovery_source_evidence_sha256 = if($isRecovery){$recoverySourceEvidenceSha256}else{$null}
    recovery_evidence_directory = if($isRecovery){$recoveryEvidenceDirectory}else{$null}
    old_thread_or_turn_resumed = $false
    mission_path = $missionPath
    mission_sha256 = (Get-FileHash $missionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    exact_response_contract = $exactResponseContract
    result_validation_mode = $resultValidationMode
    original_operator_intent = $originalIntent
    scope_transformation = $scopeTransformation
    task_completion_contract = $taskCompletionContract
    original_intent_identity_sha256 = if($null-ne$originalIntent){[string]$originalIntent.original_intent_identity_sha256}else{$null}
    scope_transformation_identity_sha256 = if($null-ne$scopeTransformation){[string]$scopeTransformation.scope_transformation_identity_sha256}else{$null}
    task_completion_contract_identity_sha256 = if($null-ne$taskCompletionContract){[string]$taskCompletionContract.task_completion_contract_identity_sha256}else{$null}
    queue_record_path = [string]$preparation.queue_record_path
    queue_document_sha256 = [string]$preparation.queue_document_sha256
    queue_state = 'inbox'
    run_id = $runId
    queue_result_path = [string]$plan.queue_plan.artifacts.queue_result
    lifecycle_result_path = [string]$plan.lifecycle_plan.artifacts.lifecycle_result
    adapter_result_path = [string]$plan.adapter_plan.artifacts.adapter_result
    adapter_event_path = [string]$plan.adapter_plan.artifacts.event_journal
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
