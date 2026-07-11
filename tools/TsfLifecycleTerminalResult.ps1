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
