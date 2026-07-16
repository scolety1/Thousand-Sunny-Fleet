$script:TsfLifecycleTerminalStatuses = @(
    'COMPLETED_GREEN',
    'COMPLETED_WITH_CAVEATS',
    'BLOCKED_PREFLIGHT',
    'BLOCKED_ROLE_PERMISSION',
    'BLOCKED_WORKER_START',
    'BLOCKED_WORKER_RESULT',
    'BLOCKED_VERIFIER',
    'BLOCKED_PRESERVATION',
    'TIM_REQUIRED',
    'INTERNAL_ERROR'
)

function New-TsfCanonicalTimRequiredRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$DurableMission,
        [Parameter(Mandatory)][object]$OperationalMission,
        [Parameter(Mandatory)][object]$Preflight,
        [Parameter(Mandatory)][string]$MissionId,
        [Parameter(Mandatory)][int]$MissionRevision,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$ResultId,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][string]$Worktree,
        [datetimeoffset]$CurrentTime = [datetimeoffset]::UtcNow
    )
    $approvals = @(Get-TsfKernelApprovalRequirements -Mission $OperationalMission)
    $clarifications = @(if ($DurableMission.PSObject.Properties.Name -contains 'clarification_requirements') { $DurableMission.clarification_requirements } elseif ($OperationalMission.PSObject.Properties.Name -contains 'clarification_requirements') { $OperationalMission.clarification_requirements })
    if ($approvals.Count -gt 0 -and $clarifications.Count -gt 0) { throw 'TIM_REQUEST_AMBIGUOUS_APPROVAL_AND_CLARIFICATION' }
    if ($approvals.Count -gt 1 -or $clarifications.Count -gt 1) { throw 'TIM_REQUEST_MULTIPLE_ACTIONS_NOT_SUPPORTED' }

    $kind = 'AUTHORITY_DECISION_REQUIRED'
    $operation = 'canonical_authority_decision'
    $question = $null
    $responseTypes = @('DENY_REQUEST')
    $reason = @($Preflight.tim_required_reasons) + @($Preflight.blocked_reasons) -join '; '
    $paths = if (@($OperationalMission.allowed_writes).Count -gt 0) { @($OperationalMission.allowed_writes) } else { @($OperationalMission.allowed_reads) }
    $expiresAt = if (![string]::IsNullOrWhiteSpace([string]$DurableMission.expires_at)) { [datetimeoffset]::Parse([string]$DurableMission.expires_at) } else { $CurrentTime.AddMinutes(15) }
    if ($approvals.Count -eq 1) {
        $kind = 'APPROVAL_REQUIRED'
        $operation = [string]$approvals[0].exact_action
        $responseTypes = @('APPROVE_EXACT_REQUEST','DENY_REQUEST')
        if ($DurableMission.PSObject.Properties.Name -contains 'approval_requirements' -and @($DurableMission.approval_requirements).Count -eq 1) {
            $requirement = @($DurableMission.approval_requirements)[0]
            $paths = @($requirement.exact_paths)
            $reason = [string]$requirement.reason
            $expiresAt = [datetimeoffset]::Parse([string]$requirement.expires_at)
        }
    } elseif ($clarifications.Count -eq 1) {
        $kind = 'CLARIFICATION_REQUIRED'
        $operation = 'provide_clarification'
        $responseTypes = @('PROVIDE_CLARIFICATION')
        $question = [string]$clarifications[0].question
        $reason = [string]$clarifications[0].reason
        $expiresAt = [datetimeoffset]::Parse([string]$clarifications[0].expires_at)
    }
    if (![string]::IsNullOrWhiteSpace([string]$Preflight.tim_request_kind) -and [string]$Preflight.tim_request_kind -ne $kind) { throw 'TIM_REQUIRED_REQUEST_KIND_DIVERGES_FROM_PREFLIGHT' }
    if ([string]::IsNullOrWhiteSpace($reason)) { $reason = 'Canonical runtime requires a bounded operator decision.' }
    $accessLevel = if ($DurableMission.PSObject.Properties.Name -contains 'permission_mode') { [string]$DurableMission.permission_mode } else { 'READ_ONLY' }
    $networkPolicy = if ($DurableMission.PSObject.Properties.Name -contains 'network_policy') { [string]$DurableMission.network_policy } else { 'PROHIBITED' }
    $controlPlanePolicy = if ($DurableMission.PSObject.Properties.Name -contains 'control_plane_service_network_policy') { [string]$DurableMission.control_plane_service_network_policy } else { 'NONE' }
    $workerToolPolicy = if ($DurableMission.PSObject.Properties.Name -contains 'worker_tool_network_policy') { [string]$DurableMission.worker_tool_network_policy } else { 'DISABLED' }
    $surface = if ($DurableMission.PSObject.Properties.Name -contains 'recommended_surface') { [string]$DurableMission.recommended_surface } else { 'CODEX' }
    $model = if ($DurableMission.PSObject.Properties.Name -contains 'resolved_model' -and ![string]::IsNullOrWhiteSpace([string]$DurableMission.resolved_model)) { [string]$DurableMission.resolved_model } else { $null }
    $identityText = @($MissionId,[string]$MissionRevision,$RunId,$ResultId,$kind,$operation,(@($paths) -join '|'),$accessLevel,$networkPolicy,$controlPlanePolicy,$workerToolPolicy,$expiresAt.ToUniversalTime().ToString('o')) -join "`n"
    $requestId = 'timreq-' + (Get-TsfRuntimeSha256Text $identityText).Substring(0,32)
    $request = [pscustomobject][ordered]@{
        schema_version = 'tsf_tim_required_request_v1'
        request_id = $requestId
        request_kind = $kind
        mission_id = $MissionId
        mission_revision = $MissionRevision
        run_id = $RunId
        result_id = $ResultId
        repository = Get-TsfKernelFullPath $Repository
        worktree = Get-TsfKernelFullPath $Worktree
        operation = $operation
        exact_paths = @($paths)
        access_level = $accessLevel
        network_scope = [pscustomobject][ordered]@{
            mission_policy = $networkPolicy
            control_plane = $controlPlanePolicy
            worker_tool = $workerToolPolicy
        }
        surface = $surface
        model = $model
        reason = $reason
        question = $question
        issued_at = $CurrentTime.ToUniversalTime().ToString('o')
        expires_at = $expiresAt.ToUniversalTime().ToString('o')
        usage_limit = [pscustomobject][ordered]@{ max_uses = 1; reuse_policy = 'SINGLE_USE' }
        response_types = @($responseTypes)
        authority_not_included = @('merge','push','deploy','production','plugins','credentials','product_repository','wildcard_paths','wider_network','wider_access')
        original_run_terminal = $true
        worker_active = $false
        app_server_child_active = $false
        superseded = $false
        invalidated = $false
    }
    $validation = Test-TsfJsonContract $request (Join-Path (Get-TsfKernelRoot) 'fleet\control\tim-required-request.schema.v1.json')
    if (!$validation.valid) { throw "TIM_REQUIRED_REQUEST_SCHEMA_MISMATCH: $($validation.errors -join '; ')" }
    return $request
}

function New-TsfLifecycleTerminalResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('COMPLETED_GREEN','COMPLETED_WITH_CAVEATS','BLOCKED_PREFLIGHT','BLOCKED_ROLE_PERMISSION','BLOCKED_WORKER_START','BLOCKED_WORKER_RESULT','BLOCKED_VERIFIER','BLOCKED_PRESERVATION','TIM_REQUIRED','INTERNAL_ERROR')][string]$TerminalStatus,
        [Parameter(Mandatory)][string]$MissionId,
        [Parameter(Mandatory)][int]$MissionRevision,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$QueueDocumentSha256,
        [Parameter(Mandatory)][string]$PolicyFingerprint,
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Branch,
        [Parameter(Mandatory)][string]$Worktree,
        [Parameter(Mandatory)][string]$ResultPath,
        [Parameter(Mandatory)][string]$ProducerRegistryPath,
        [Parameter(Mandatory)][string]$ProducerBindingIdentitySha256,
        [Parameter(Mandatory)][string]$OrchestratorInvocationIdentity,
        [Parameter(Mandatory)][string]$OutcomeStage,
        [AllowEmptyString()][string]$MissionPath = '',
        [AllowEmptyString()][string]$EffectiveMissionPath = '',
        [AllowEmptyString()][string]$QueueMissionPath = '',
        [AllowEmptyString()][string]$QueueState = '',
        [AllowEmptyString()][string]$PreflightVerdict = '',
        [bool]$PreflightApproved = $false,
        [ValidateSet('NO_APPROVAL_REQUIRED', 'APPROVAL_REQUIRED')][string]$ApprovalSemantics = 'NO_APPROVAL_REQUIRED',
        [bool]$ApprovalLedgerConsumed = $false,
        [AllowEmptyString()][string]$RolePreflightVerdict = '',
        [bool]$RolePreflightRequired = $false,
        [bool]$RolePreflightApproved = $false,
        [AllowEmptyString()][string]$WorkerStatus = '',
        [AllowEmptyString()][string]$VerifierVerdict = '',
        [AllowEmptyString()][string]$PreservationStatus = 'NOT_ATTEMPTED',
        [AllowEmptyString()][string]$PreservationPacketFile = '',
        [AllowEmptyString()][string]$PreservationManifestPath = '',
        [AllowEmptyString()][string]$AdapterResultPath = '',
        [AllowEmptyString()][string]$WorkerResultPath = '',
        [AllowEmptyString()][string]$VerifierResultPath = '',
        [bool]$WorkerLaunched = $false,
        [bool]$EvidencePreserved = $false,
        [int]$RuntimePathMaximum = 0,
        [object[]]$Events = @(),
        [string[]]$BlockedReasons = @(),
        [AllowNull()][object]$TimRequiredRequest = $null,
        [AllowEmptyString()][string]$InternalError = ''
    )

    $decision = switch ($TerminalStatus) {
        'COMPLETED_GREEN' { 'GREEN' }
        'COMPLETED_WITH_CAVEATS' { 'YELLOW' }
        'TIM_REQUIRED' { 'TIM_REQUIRED' }
        default { 'RED' }
    }
    [pscustomobject][ordered]@{
        schema_version = 'tsf_lifecycle_terminal_result_v1'
        generated_at = [datetimeoffset]::UtcNow.ToString('o')
        lifecycle_invoked = $true
        terminal_status = $TerminalStatus
        final_decision = $decision
        outcome_stage = $OutcomeStage
        mission_id = $MissionId
        mission_revision = $MissionRevision
        run_id = $RunId
        result_id = $RunId
        queue_document_sha256 = $QueueDocumentSha256
        policy_fingerprint = $PolicyFingerprint
        repository = Get-TsfKernelFullPath $Repository
        branch = $Branch
        worktree = Get-TsfKernelFullPath $Worktree
        result_path = Get-TsfKernelFullPath $ResultPath
        out_directory = Split-Path -Parent (Get-TsfKernelFullPath $ResultPath)
        producer_registry_path = Get-TsfKernelFullPath $ProducerRegistryPath
        producer_binding_identity_sha256 = $ProducerBindingIdentitySha256
        orchestrator_invocation_identity = $OrchestratorInvocationIdentity
        mission_path = $MissionPath
        effective_mission_path = $EffectiveMissionPath
        queue_mission_path = $QueueMissionPath
        queue_state = $QueueState
        preflight_verdict = $PreflightVerdict
        preflight_approved = $PreflightApproved
        approval_semantics = $ApprovalSemantics
        approval_ledger_consumed = $ApprovalLedgerConsumed
        role_preflight_verdict = $RolePreflightVerdict
        role_preflight_required = $RolePreflightRequired
        role_preflight_approved = $RolePreflightApproved
        worker_launched = $WorkerLaunched
        worker_status = $WorkerStatus
        verifier_verdict = $VerifierVerdict
        preservation_status = $PreservationStatus
        preservation_packet_file = $PreservationPacketFile
        preservation_packet_path = if($PreservationPacketFile){Split-Path -Parent $PreservationPacketFile}else{''}
        preservation_manifest_path = $PreservationManifestPath
        adapter_result_path = $AdapterResultPath
        worker_result_path = $WorkerResultPath
        verifier_result_path = $VerifierResultPath
        evidence_preserved = $EvidencePreserved
        runtime_path_maximum = $RuntimePathMaximum
        events = @($Events)
        blocked_reasons = @($BlockedReasons)
        internal_error = $InternalError
        background_runner_started = $false
        worker_tool_network_enabled = $false
        push_merge_deploy_attempted = $false
        tim_required_request = $TimRequiredRequest
    }
}

function Test-TsfLifecycleTerminalResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Result,
        [Parameter(Mandatory)][object]$PathPlan,
        [Parameter(Mandatory)][string]$QueueDocumentSha256,
        [Parameter(Mandatory)][string]$PolicyFingerprint,
        [switch]$RequireProducerProvenance
    )
    $errors = [Collections.Generic.List[string]]::new()
    $schema = Test-TsfJsonContract $Result (Join-Path (Get-TsfKernelRoot) 'fleet\control\lifecycle-terminal-result.schema.v1.json')
    foreach ($error in @($schema.errors)) { $errors.Add([string]$error) | Out-Null }
    if ([string]$Result.mission_id -ne [string]$PathPlan.mission_id -or [int]$Result.mission_revision -ne [int]$PathPlan.mission_revision -or [string]$Result.run_id -ne [string]$PathPlan.run_id) { $errors.Add('Lifecycle result mission/revision/run binding mismatch.') | Out-Null }
    if ([string]$Result.result_id -ne [string]$Result.run_id) { $errors.Add('Lifecycle result identity must equal the canonical run identity.') | Out-Null }
    if ([string]$Result.terminal_status -eq 'TIM_REQUIRED') {
        if ($null -eq $Result.tim_required_request) { $errors.Add('TIM_REQUIRED result is missing its canonical request.') | Out-Null }
        else {
            $requestValidation = Test-TsfJsonContract $Result.tim_required_request (Join-Path (Get-TsfKernelRoot) 'fleet\control\tim-required-request.schema.v1.json')
            foreach ($error in @($requestValidation.errors)) { $errors.Add([string]$error) | Out-Null }
            if ([string]$Result.tim_required_request.mission_id -ne [string]$Result.mission_id -or [int]$Result.tim_required_request.mission_revision -ne [int]$Result.mission_revision -or [string]$Result.tim_required_request.run_id -ne [string]$Result.run_id -or [string]$Result.tim_required_request.result_id -ne [string]$Result.result_id) { $errors.Add('TIM_REQUIRED request identity is not bound to its terminal result.') | Out-Null }
        }
    } elseif ($null -ne $Result.tim_required_request) { $errors.Add('Non-TIM terminal result must not carry a TIM_REQUIRED request.') | Out-Null }
    if ([string]$Result.queue_document_sha256 -ne $QueueDocumentSha256) { $errors.Add('Lifecycle result queue-document binding mismatch.') | Out-Null }
    if ([string]$Result.policy_fingerprint -ne $PolicyFingerprint) { $errors.Add('Lifecycle result policy binding mismatch.') | Out-Null }
    $expectedPath = Get-TsfKernelFullPath ([string]$PathPlan.lifecycle_plan.artifacts.lifecycle_result)
    if (![string]::Equals((Get-TsfKernelFullPath ([string]$Result.result_path)), $expectedPath, [StringComparison]::OrdinalIgnoreCase)) { $errors.Add('Lifecycle result canonical path mismatch.') | Out-Null }
    $expectedRegistry = Get-TsfKernelFullPath ([string]$PathPlan.lifecycle_plan.artifacts.producer_registry)
    if (![string]::Equals((Get-TsfKernelFullPath ([string]$Result.producer_registry_path)), $expectedRegistry, [StringComparison]::OrdinalIgnoreCase)) { $errors.Add('Lifecycle result producer-registry path mismatch.') | Out-Null }
    if ($RequireProducerProvenance) {
        if (!(Test-Path -LiteralPath $expectedPath -PathType Leaf)) { $errors.Add('Lifecycle terminal result is missing.') | Out-Null }
        if (!(Test-Path -LiteralPath $expectedRegistry -PathType Leaf)) { $errors.Add('Lifecycle producer registry is missing.') | Out-Null }
        if ($errors.Count -eq 0) {
            $registry = Read-TsfKernelJson $expectedRegistry
            if ([string]$registry.binding_identity_sha256 -ne [string]$Result.producer_binding_identity_sha256 -or [string]$registry.binding.orchestrator_invocation_identity -ne [string]$Result.orchestrator_invocation_identity) { $errors.Add('Lifecycle result producer binding mismatch.') | Out-Null }
            $records = @($registry.artifacts | Where-Object { [string]$_.logical_type -eq 'lifecycle_result' })
            if ($records.Count -ne 1) { $errors.Add('Lifecycle result producer provenance is missing or duplicated.') | Out-Null }
            elseif ([string]$records[0].sha256 -ne (Get-FileHash -LiteralPath $expectedPath -Algorithm SHA256).Hash.ToLowerInvariant()) { $errors.Add('Lifecycle result producer provenance hash mismatch.') | Out-Null }
        }
    }
    [pscustomobject]@{valid=($errors.Count -eq 0);errors=@($errors);result=$Result}
}
