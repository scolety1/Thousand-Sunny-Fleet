$semanticRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (!(Get-Command Get-TsfContractJsonHash -ErrorAction SilentlyContinue)) {
    . (Join-Path $semanticRoot 'tools\TsfJsonContract.ps1')
}

$script:TsfAuthorityBearingOperations = @(
    'WORKSPACE_WRITE','FILE_CREATE','FILE_EDIT','FILE_DELETE','PATH_RENAME_MOVE',
    'GIT_WRITE','COMMIT','BRANCH_CREATE_MUTATE','PUSH','MERGE','DEPLOYMENT',
    'INSTALLATION','MIGRATION','CREDENTIAL_ACCESS','PLUGIN_OPERATION',
    'EXTERNAL_NETWORK','DESTRUCTIVE_PROCESS_ACTION'
)

function Get-TsfSemanticTextSha256 {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function ConvertTo-TsfSemanticNormalizedText {
    param([Parameter(Mandatory)][string]$Text)
    return ([regex]::Replace($Text.Trim(), '\s+', ' '))
}

function Test-TsfSemanticPositiveMatch {
    param([Parameter(Mandatory)][string]$Text,[Parameter(Mandatory)][string]$Pattern)
    foreach ($match in [regex]::Matches($Text, $Pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
        $prefixStart = [Math]::Max(0, $match.Index - 48)
        $prefix = $Text.Substring($prefixStart, $match.Index - $prefixStart)
        if ($prefix -notmatch '(?i)(?:\bdo\s+not\b|\bdon''t\b|\bnever\b|\bwithout\b|\bno\b)\s+(?:\w+\s+){0,4}$') { return $true }
    }
    return $false
}

function Get-TsfOriginalOperationAnalysis {
    param([Parameter(Mandatory)][string]$NaturalRequest)
    $rules = [ordered]@{
        FILE_DELETE = '\b(?:delete|remove)\b[^\r\n.!?]{0,80}\b(?:file|path|directory|folder)\b'
        PATH_RENAME_MOVE = '\b(?:rename|move)\b[^\r\n.!?]{0,80}\b(?:file|path|directory|folder|it)\b'
        FILE_CREATE = '\b(?:create|add|generate|write)\b[^\r\n.!?]{0,80}\b(?:file|documents?|docs?|source|code|artifacts?|index|report|tests?)\b'
        FILE_EDIT = '\b(?:edit|modify|update|fix|patch|change|implement)\b'
        WORKSPACE_WRITE = '\b(?:make\s+the\s+change|apply\s+the\s+change|update\s+this\s+repository|modify\s+code|write\s+the\s+change)\b'
        COMMIT = '\bcommit\b'
        BRANCH_CREATE_MUTATE = '\b(?:create|switch|checkout|update|mutate)\b[^\r\n.!?]{0,60}\bbranch\b'
        PUSH = '\bpush(?:\s+the)?\s+(?:branch|commit|changes|work|it)\b|\bgit\s+push\b'
        MERGE = '\bmerge(?:\s+the)?\s+(?:pr|pull\s+request|branch|changes|it)\b'
        DEPLOYMENT = '\bdeploy(?:ment|\s+the\s+(?:application|app|service|site))?\b'
        INSTALLATION = '\binstall(?:ation|\s+(?:a|the|this|that|an)?\s*(?:package|dependency|plugin|tool|software))\b'
        MIGRATION = '\b(?:migrate|migration)\b'
        CREDENTIAL_ACCESS = '\b(?:access|read|use|change|rotate)\b[^\r\n.!?]{0,60}\b(?:credential|secret|api[_ -]?key|password|token)\b|\b(?:credential|secret|api[_ -]?key|password|token)\b[^\r\n.!?]{0,30}\b(?:access|read|use|change|rotation)\b'
        PLUGIN_OPERATION = '\b(?:enable|disable|install|invoke|use|operate)\b[^\r\n.!?]{0,50}\bplugin\b'
        EXTERNAL_NETWORK = '\b(?:browse|download|upload|fetch\s+from|call)\b[^\r\n.!?]{0,60}\b(?:internet|network|api|url|website|service)\b'
        DESTRUCTIVE_PROCESS_ACTION = '\b(?:kill|terminate|stop)\b[^\r\n.!?]{0,60}\b(?:process|service|daemon|worker)\b'
        READ_FILE = '\b(?:read|inspect|open|analy[sz]e|review|audit)\b[^\r\n.!?]{0,100}\b(?:file|path|repository|worktree|source|document)\b'
        READ_ANALYSIS = '\b(?:analy[sz]e|review|audit|inspect|summari[sz]e|compare|explain|answer|list|report|return|respond|tell)\b'
        RETURN_RESULT = '\b(?:return|respond|answer|report|provide|show|list|summari[sz]e|explain|tell)\b'
    }
    $operations = [Collections.Generic.List[string]]::new()
    foreach ($entry in $rules.GetEnumerator()) {
        if (Test-TsfSemanticPositiveMatch -Text $NaturalRequest -Pattern ([string]$entry.Value)) { $operations.Add([string]$entry.Key) | Out-Null }
    }
    if ($operations -contains 'COMMIT' -or $operations -contains 'BRANCH_CREATE_MUTATE' -or $operations -contains 'PUSH' -or $operations -contains 'MERGE') {
        if ($operations -notcontains 'GIT_WRITE') { $operations.Add('GIT_WRITE') | Out-Null }
    }
    if (@($operations | Where-Object { $_ -in @('FILE_CREATE','FILE_EDIT','FILE_DELETE','PATH_RENAME_MOVE') }).Count -gt 0 -and $operations -notcontains 'WORKSPACE_WRITE') {
        $operations.Add('WORKSPACE_WRITE') | Out-Null
    }
    if ($operations.Count -eq 0 -and $NaturalRequest -match '(?i)\b(?:change|update|fix|make|prepare|handle|do\s+this|run\s+as\s+much)\b') {
        $ambiguity = 'AMBIGUOUS_AUTHORITY_INTENT'
    } elseif ($operations.Count -eq 0) {
        $ambiguity = 'AMBIGUOUS_REQUESTED_OPERATION'
    } else {
        $ambiguity = 'UNAMBIGUOUS'
    }
    $unique = @($operations | Sort-Object -Unique)
    $authority = @($unique | Where-Object { $_ -in $script:TsfAuthorityBearingOperations })
    [pscustomobject][ordered]@{
        schema_version = 'tsf_requested_operation_analysis_v1'
        requested_operations = @($unique)
        authority_bearing_operations = @($authority)
        ambiguity_status = $ambiguity
        requested_access = $(if ($authority.Count -eq 0) { 'READ_ONLY' } elseif (@($authority | Where-Object { $_ -in @('PUSH','MERGE','DEPLOYMENT','INSTALLATION','MIGRATION','CREDENTIAL_ACCESS','PLUGIN_OPERATION','EXTERNAL_NETWORK','DESTRUCTIVE_PROCESS_ACTION') }).Count -gt 0) { 'EXACT_ELEVATED_ACTION' } else { 'WORKSPACE_WRITE' })
        requested_network = $(if ($unique -contains 'EXTERNAL_NETWORK') { 'EXTERNAL_NETWORK_REQUESTED' } else { 'NO_NETWORK_REQUESTED' })
    }
}

function New-TsfOriginalOperatorIntentContract {
    param(
        [Parameter(Mandatory)][string]$NaturalRequest,
        [Parameter(Mandatory)][string]$PreviewId,
        [Parameter(Mandatory)][string]$RepositoryTarget,
        [Parameter(Mandatory)][string]$WorktreeTarget,
        [string[]]$ProhibitedOperations = @()
    )
    $normalized = ConvertTo-TsfSemanticNormalizedText $NaturalRequest
    $analysis = Get-TsfOriginalOperationAnalysis $NaturalRequest
    $evidence = [pscustomobject][ordered]@{ normalized_request=$normalized; requested_operations=@($analysis.requested_operations); requested_access=[string]$analysis.requested_access; requested_network=[string]$analysis.requested_network }
    $semantic = [pscustomobject][ordered]@{
        schema_version = 'tsf_original_operator_intent_v1'
        contract_version = 'ORIGINAL_OPERATOR_INTENT_V1'
        original_request_text_sha256 = Get-TsfSemanticTextSha256 $NaturalRequest
        normalized_request_evidence_sha256 = Get-TsfContractJsonHash $evidence
        requested_goal = $NaturalRequest.Trim()
        requested_output_or_deliverable = 'A response that performs the requested goal; transport-only or inability text is not a deliverable.'
        explicitly_requested_operations = @($analysis.requested_operations)
        authority_bearing_operations = @($analysis.authority_bearing_operations)
        repository_target = $RepositoryTarget
        worktree_target = $WorktreeTarget
        requested_access = [string]$analysis.requested_access
        requested_network = [string]$analysis.requested_network
        prohibited_operations = @($ProhibitedOperations | Sort-Object -Unique)
        ambiguity_status = [string]$analysis.ambiguity_status
        source_preview_identity = [pscustomobject][ordered]@{ preview_id=$PreviewId; record_kind='hq_dispatch_route_preview' }
    }
    $identity = Get-TsfContractJsonHash $semantic
    $semantic | Add-Member -NotePropertyName original_intent_identity_sha256 -NotePropertyValue $identity
    return $semantic
}

function Test-TsfOriginalOperatorIntentContract {
    param([Parameter(Mandatory)][object]$Contract,[Parameter(Mandatory)][string]$NaturalRequest,[Parameter(Mandatory)][string]$PreviewId,[Parameter(Mandatory)][string]$RepositoryTarget,[Parameter(Mandatory)][string]$WorktreeTarget,[string[]]$ProhibitedOperations=@())
    $expected = New-TsfOriginalOperatorIntentContract -NaturalRequest $NaturalRequest -PreviewId $PreviewId -RepositoryTarget $RepositoryTarget -WorktreeTarget $WorktreeTarget -ProhibitedOperations $ProhibitedOperations
    [pscustomobject]@{valid=((Get-TsfContractJsonHash $Contract) -eq (Get-TsfContractJsonHash $expected));expected=$expected}
}

function New-TsfScopeTransformationContract {
    param(
        [Parameter(Mandatory)][object]$OriginalIntent,
        [Parameter(Mandatory)][string]$AuthorizedMissionGoal,
        [Parameter(Mandatory)][string[]]$ProposedOperations,
        [Parameter(Mandatory)][string]$ProposedAccess,
        [Parameter(Mandatory)][string]$RepositoryTarget,
        [Parameter(Mandatory)][string]$WorktreeTarget,
        [bool]$DetachedHead = $false
    )
    $requested = @($OriginalIntent.explicitly_requested_operations)
    $proposed = @($ProposedOperations | Sort-Object -Unique)
    $authority = @($OriginalIntent.authority_bearing_operations)
    $denied = @($authority | Where-Object { $_ -notin $proposed })
    $goalSame = [string]::Equals((ConvertTo-TsfSemanticNormalizedText ([string]$OriginalIntent.requested_goal)),(ConvertTo-TsfSemanticNormalizedText $AuthorizedMissionGoal),[StringComparison]::Ordinal)
    if ([string]$OriginalIntent.ambiguity_status -ne 'UNAMBIGUOUS') {
        $classification = 'AMBIGUOUS_REQUIRES_TIM'
    } elseif ($denied.Count -gt 0) {
        $classification = 'AUTHORITY_REDUCTION_REQUIRES_OPERATOR_CONFIRMATION'
    } elseif ($requested -contains 'READ_FILE' -and $proposed -notcontains 'READ_FILE') {
        $classification = 'REQUEST_UNFULFILLABLE_UNDER_CURRENT_AUTHORITY'
    } elseif (!$goalSame) {
        $classification = 'GOAL_CHANGED'
    } elseif ((Get-TsfContractJsonHash @($requested)) -eq (Get-TsfContractJsonHash @($proposed))) {
        $classification = 'NO_MATERIAL_CHANGE'
    } else {
        $classification = 'SAFE_PRESENTATION_NORMALIZATION'
    }
    $requires = $classification -notin @('NO_MATERIAL_CHANGE','SAFE_PRESENTATION_NORMALIZATION')
    $semantic = [pscustomobject][ordered]@{
        schema_version = 'tsf_scope_transformation_v1'
        contract_version = 'SCOPE_TRANSFORMATION_V1'
        original_intent_identity_sha256 = [string]$OriginalIntent.original_intent_identity_sha256
        original_requested_goal = [string]$OriginalIntent.requested_goal
        original_requested_operations = @($requested)
        proposed_mission_goal = $AuthorizedMissionGoal
        proposed_operations = @($proposed)
        actual_mission_goal = $AuthorizedMissionGoal
        actual_operations = @($proposed)
        proposed_access = $ProposedAccess
        repository_target = $RepositoryTarget
        worktree_target = $WorktreeTarget
        detached_head = $DetachedHead
        classification = $classification
        material_scope_change = $requires
        operator_confirmation_required = $requires
        operator_confirmation_observed = $false
        queue_allowed = !$requires
        denied_authority = @($denied)
        what_will_not_be_performed = @($denied | ForEach-Object { "Requested operation $_ will not be performed by the proposed mission." })
        accepting_alternative_creates_different_mission = $requires
        exact_next_action = $(if ($classification -eq 'AUTHORITY_REDUCTION_REQUIRES_OPERATOR_CONFIRMATION' -and $DetachedHead) { 'Attach an approved branch, then create a new preview; no queue is created from this reduced read-only proposal.' } elseif ($requires) { 'TIM_REQUIRED: explicitly decide whether to create a different reduced mission; the original preview cannot be queued.' } else { 'The preview may proceed through normal submission revalidation.' })
    }
    $identity = Get-TsfContractJsonHash $semantic
    $semantic | Add-Member -NotePropertyName scope_transformation_identity_sha256 -NotePropertyValue $identity
    return $semantic
}

function New-TsfTaskCompletionContract {
    param([Parameter(Mandatory)][string]$RequiredTask,[Parameter(Mandatory)][object]$OriginalIntent,[Parameter(Mandatory)][object]$ScopeTransformation)
    $semantic = [pscustomobject][ordered]@{
        schema_version = 'tsf_task_completion_contract_v1'
        contract_version = 'TASK_COMPLETION_CONTRACT_V1'
        required_task = $RequiredTask
        required_task_sha256 = Get-TsfSemanticTextSha256 (ConvertTo-TsfSemanticNormalizedText $RequiredTask)
        required_deliverables = @([pscustomobject][ordered]@{ deliverable_id='requested_answer'; description='A substantive answer that performs the authorized requested task.'; evidence_rule='NONEMPTY_SUBSTANTIVE_TEXT_V1' })
        required_output_format = 'TSF_GENERAL_RESULT_V2_JSON'
        required_evidence = @('FINAL_RESPONSE_OBSERVED','TASK_IDENTITY_ECHO','INTENT_IDENTITY_ECHO','SCOPE_IDENTITY_ECHO','DELIVERABLE_ID_MATCH')
        optional_deliverables = @()
        partial_completion_allowed = $false
        accepted_dispositions = @('FULFILLED','FULFILLED_WITH_CAVEATS')
        success_criteria = @('Transport succeeded.','A closed structured worker claim was parsed.','The task, intent, and scope identities match.','Every required deliverable is present.','The answer is substantive and is not inability, refusal, policy-block, clarification, or generic acknowledgement text.')
        fail_closed_conditions = @('EMPTY_RESPONSE','GENERIC_ACKNOWLEDGEMENT','INABILITY_OR_REFUSAL','POLICY_BLOCK','NEEDS_CLARIFICATION','TASK_IDENTITY_MISMATCH','INTENT_IDENTITY_MISMATCH','SCOPE_IDENTITY_MISMATCH','MISSING_DELIVERABLE','UNKNOWN_LEGACY_OUTPUT')
        original_intent_identity_sha256 = [string]$OriginalIntent.original_intent_identity_sha256
        scope_transformation_identity_sha256 = [string]$ScopeTransformation.scope_transformation_identity_sha256
    }
    $identity = Get-TsfContractJsonHash $semantic
    $semantic | Add-Member -NotePropertyName task_completion_contract_identity_sha256 -NotePropertyValue $identity
    return $semantic
}

function Get-TsfGeneralLegacyDisposition {
    param([AllowEmptyString()][string]$Response)
    if ([string]::IsNullOrWhiteSpace($Response)) { return 'REQUIRED_DELIVERABLE_MISSING' }
    if ($Response -match '(?i)\b(?:cannot|can''t|could\s+not|unable\s+to|was\s+unable|do\s+not\s+have\s+access|lack\s+access)\b') { return 'UNABLE_TO_PERFORM' }
    if ($Response -match '(?i)\b(?:refuse|decline|will\s+not)\b') { return 'REFUSED' }
    if ($Response -match '(?i)\b(?:blocked\s+by\s+policy|policy\s+(?:blocks|prohibits|does\s+not\s+allow))\b') { return 'BLOCKED_BY_POLICY' }
    if ($Response -match '(?i)\b(?:need\s+(?:more\s+)?clarification|please\s+clarify|cannot\s+determine)\b') { return 'NEEDS_CLARIFICATION' }
    if ($Response -match '(?i)\b(?:unsupported|not\s+supported|not\s+available|outside\s+(?:my|the)\s+(?:capability|scope))\b') { return 'UNABLE_TO_PERFORM' }
    return 'UNCLASSIFIED_RESULT'
}

function Get-TsfGeneralResultV2Evidence {
    param(
        [Parameter(Mandatory)][string]$MissionId,
        [Parameter(Mandatory)][int]$MissionRevision,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][object]$Adapter,
        [AllowNull()][object]$TaskCompletionContract
    )
    $transport = if ($Adapter.PSObject.Properties.Name -contains 'transport_success') { [bool]$Adapter.transport_success } else { [bool]$Adapter.success }
    $raw = if ($Adapter.PSObject.Properties.Name -contains 'final_response') { [string]$Adapter.final_response } else { '' }
    $rawHash = Get-TsfSemanticTextSha256 $raw
    if ($null -eq $TaskCompletionContract) {
        $legacy = Get-TsfGeneralLegacyDisposition $raw
        return [pscustomobject][ordered]@{schema_version='tsf_general_result_v2';compatibility_mode='LEGACY_FAIL_CLOSED_V1';mission_id=$MissionId;mission_revision=$MissionRevision;run_id=$RunId;result_id=$RunId;original_intent_identity_sha256=$null;scope_transformation_identity_sha256=$null;task_completion_contract_identity_sha256=$null;raw_worker_response_sha256=$rawHash;worker_claim=$null;observed_deliverables=@();missing_deliverables=@('requested_answer');outcome_disposition=$legacy;outcome_evidence=@('Legacy worker output has no mission-bound completion envelope.');transport_status=$(if($transport){'SUCCEEDED'}else{'FAILED'});semantic_status='NOT_FULFILLED';semantic_success=$false;admissible=$false}
    }
    $errors = [Collections.Generic.List[string]]::new()
    $claim = $null
    try { $claim = $raw | ConvertFrom-Json -ErrorAction Stop } catch { $errors.Add('WORKER_CLAIM_INVALID_JSON') | Out-Null }
    $requiredFields = @('schema_version','mission_id','mission_revision','run_id','task_completion_contract_identity_sha256','original_intent_identity_sha256','scope_transformation_identity_sha256','attempted_task_sha256','outcome_disposition','completed_deliverables','missing_deliverables','answer','evidence','caveats')
    if ($null -ne $claim) {
        $names = @($claim.PSObject.Properties.Name)
        if (@($requiredFields | Where-Object { $_ -notin $names }).Count -gt 0 -or @($names | Where-Object { $_ -notin $requiredFields }).Count -gt 0) { $errors.Add('WORKER_CLAIM_NOT_CLOSED') | Out-Null }
        if ([string]$claim.schema_version -ne 'tsf_worker_outcome_claim_v1') { $errors.Add('WORKER_CLAIM_SCHEMA_INVALID') | Out-Null }
        if ([string]$claim.mission_id -ne $MissionId -or [int]$claim.mission_revision -ne $MissionRevision -or [string]$claim.run_id -ne $RunId) { $errors.Add('WORKER_CLAIM_IDENTITY_MISMATCH') | Out-Null }
        if ([string]$claim.task_completion_contract_identity_sha256 -ne [string]$TaskCompletionContract.task_completion_contract_identity_sha256) { $errors.Add('TASK_IDENTITY_MISMATCH') | Out-Null }
        if ([string]$claim.original_intent_identity_sha256 -ne [string]$TaskCompletionContract.original_intent_identity_sha256) { $errors.Add('INTENT_IDENTITY_MISMATCH') | Out-Null }
        if ([string]$claim.scope_transformation_identity_sha256 -ne [string]$TaskCompletionContract.scope_transformation_identity_sha256) { $errors.Add('SCOPE_IDENTITY_MISMATCH') | Out-Null }
        if ([string]$claim.attempted_task_sha256 -ne [string]$TaskCompletionContract.required_task_sha256) { $errors.Add('WRONG_TASK_PERFORMED') | Out-Null }
    }
    $workerDisposition = if ($null -ne $claim) { [string]$claim.outcome_disposition } else { 'UNCLASSIFIED_RESULT' }
    $allowedDispositions = @('FULFILLED','FULFILLED_WITH_CAVEATS','PARTIAL','UNABLE_TO_PERFORM','REFUSED','BLOCKED_BY_POLICY','NEEDS_CLARIFICATION','REQUIRED_DELIVERABLE_MISSING','WRONG_TASK_PERFORMED','FAILED','UNCLASSIFIED_RESULT')
    if ($workerDisposition -notin $allowedDispositions) { $errors.Add('WORKER_DISPOSITION_INVALID') | Out-Null; $workerDisposition='UNCLASSIFIED_RESULT' }
    $answer = if ($null -ne $claim) { [string]$claim.answer } else { '' }
    $legacyDisposition = Get-TsfGeneralLegacyDisposition $answer
    if ($workerDisposition -in @('FULFILLED','FULFILLED_WITH_CAVEATS') -and $legacyDisposition -ne 'UNCLASSIFIED_RESULT') { $workerDisposition=$legacyDisposition; $errors.Add('FULFILLMENT_CLAIM_CONTRADICTED_BY_RESPONSE') | Out-Null }
    if ($workerDisposition -in @('FULFILLED','FULFILLED_WITH_CAVEATS') -and ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().Length -lt 20 -or $answer.Trim() -match '(?i)^(?:ok(?:ay)?|done|completed|acknowledged|success|thank\s+you)[.!\s]*$')) { $workerDisposition='REQUIRED_DELIVERABLE_MISSING'; $errors.Add('ANSWER_NOT_SUBSTANTIVE') | Out-Null }
    $requiredIds = @($TaskCompletionContract.required_deliverables | ForEach-Object { [string]$_.deliverable_id })
    $completed = if ($null -ne $claim -and $claim.completed_deliverables -is [array]) { @($claim.completed_deliverables | ForEach-Object { [string]$_ } | Sort-Object -Unique) } else { @() }
    $reportedMissing = if ($null -ne $claim -and $claim.missing_deliverables -is [array]) { @($claim.missing_deliverables | ForEach-Object { [string]$_ } | Sort-Object -Unique) } else { @() }
    $missing = @((@($requiredIds | Where-Object { $_ -notin $completed }) + @($reportedMissing | Where-Object { $_ -in $requiredIds })) | Sort-Object -Unique)
    if ($missing.Count -gt 0 -and $workerDisposition -in @('FULFILLED','FULFILLED_WITH_CAVEATS')) { $workerDisposition='REQUIRED_DELIVERABLE_MISSING'; $errors.Add('REQUIRED_DELIVERABLE_MISSING') | Out-Null }
    if ($workerDisposition -eq 'PARTIAL' -and ![bool]$TaskCompletionContract.partial_completion_allowed) { $errors.Add('PARTIAL_NOT_ALLOWED') | Out-Null }
    $accepted = @($TaskCompletionContract.accepted_dispositions) -contains $workerDisposition
    $semantic = $transport -and $accepted -and $missing.Count -eq 0 -and $errors.Count -eq 0
    [pscustomobject][ordered]@{
        schema_version='tsf_general_result_v2';compatibility_mode='STRUCTURED_GENERAL_RESULT_V2';mission_id=$MissionId;mission_revision=$MissionRevision;run_id=$RunId;result_id=$RunId
        original_intent_identity_sha256=[string]$TaskCompletionContract.original_intent_identity_sha256;scope_transformation_identity_sha256=[string]$TaskCompletionContract.scope_transformation_identity_sha256;task_completion_contract_identity_sha256=[string]$TaskCompletionContract.task_completion_contract_identity_sha256
        raw_worker_response_sha256=$rawHash;worker_claim=$claim;observed_deliverables=@($completed);missing_deliverables=@($missing);outcome_disposition=$workerDisposition;outcome_evidence=@($errors);transport_status=$(if($transport){'SUCCEEDED'}else{'FAILED'});semantic_status=$(if($semantic){'FULFILLED'}else{'NOT_FULFILLED'});semantic_success=$semantic;admissible=$semantic
    }
}

function Test-TsfGeneralResultV2AdmissionEvidence {
    param(
        [Parameter(Mandatory)][object]$Mission,
        [Parameter(Mandatory)][object]$Result
    )
    $errors = [Collections.Generic.List[string]]::new()
    $contract = if ($Mission.PSObject.Properties.Name -contains 'task_completion_contract') { $Mission.task_completion_contract } else { $null }
    $claim = if ($Result.PSObject.Properties.Name -contains 'worker_claim') { $Result.worker_claim } else { $null }
    if ([string]$Mission.result_validation_mode -ne 'GENERAL_RESULT_V2' -or [string]$Result.result_validation_mode -ne 'GENERAL_RESULT_V2') { $errors.Add('GENERAL_RESULT_MODE_MISMATCH') | Out-Null }
    if ($null -eq $contract) { $errors.Add('TASK_COMPLETION_CONTRACT_MISSING') | Out-Null }
    if ($null -eq $claim) { $errors.Add('WORKER_CLAIM_MISSING') | Out-Null }
    if ($null -ne $contract) {
        if ([string]$Result.original_intent_identity_sha256 -ne [string]$contract.original_intent_identity_sha256) { $errors.Add('INTENT_IDENTITY_MISMATCH') | Out-Null }
        if ([string]$Result.scope_transformation_identity_sha256 -ne [string]$contract.scope_transformation_identity_sha256) { $errors.Add('SCOPE_IDENTITY_MISMATCH') | Out-Null }
        if ([string]$Result.task_completion_contract_identity_sha256 -ne [string]$contract.task_completion_contract_identity_sha256) { $errors.Add('TASK_IDENTITY_MISMATCH') | Out-Null }
    }
    if ([string]$Result.transport_status -ne 'SUCCEEDED') { $errors.Add('TRANSPORT_NOT_SUCCEEDED') | Out-Null }
    if ([string]$Result.semantic_status -ne 'FULFILLED') { $errors.Add('SEMANTIC_STATUS_NOT_FULFILLED') | Out-Null }
    if (@($Result.outcome_evidence).Count -ne 0) { $errors.Add('OUTCOME_ERRORS_PRESENT') | Out-Null }
    if (@($Result.missing_deliverables).Count -ne 0) { $errors.Add('REQUIRED_DELIVERABLE_MISSING') | Out-Null }
    if ([string]::IsNullOrWhiteSpace([string]$Result.raw_worker_response_sha256)) { $errors.Add('RAW_WORKER_RESPONSE_HASH_MISSING') | Out-Null }
    if ($null -ne $contract -and [string]$Result.outcome_disposition -notin @($contract.accepted_dispositions)) { $errors.Add('OUTCOME_DISPOSITION_NOT_ACCEPTED') | Out-Null }
    if ([string]$Result.outcome_disposition -eq 'PARTIAL' -and ($null -eq $contract -or ![bool]$contract.partial_completion_allowed)) { $errors.Add('PARTIAL_NOT_ALLOWED') | Out-Null }
    if ($null -ne $claim -and $null -ne $contract) {
        $requiredClaimFields = @('schema_version','mission_id','mission_revision','run_id','task_completion_contract_identity_sha256','original_intent_identity_sha256','scope_transformation_identity_sha256','attempted_task_sha256','outcome_disposition','completed_deliverables','missing_deliverables','answer','evidence','caveats')
        $claimNames = @($claim.PSObject.Properties.Name)
        $claimClosed = @($requiredClaimFields | Where-Object { $_ -notin $claimNames }).Count -eq 0 -and @($claimNames | Where-Object { $_ -notin $requiredClaimFields }).Count -eq 0
        if (!$claimClosed) { $errors.Add('WORKER_CLAIM_NOT_CLOSED') | Out-Null }
        else {
            if ([string]$claim.schema_version -ne 'tsf_worker_outcome_claim_v1') { $errors.Add('WORKER_CLAIM_SCHEMA_INVALID') | Out-Null }
            if ([string]$claim.mission_id -ne [string]$Result.mission_id -or [int]$claim.mission_revision -ne [int]$Result.mission_revision -or [string]$claim.run_id -ne [string]$Result.result_id) { $errors.Add('WORKER_CLAIM_IDENTITY_MISMATCH') | Out-Null }
            if ([string]$claim.original_intent_identity_sha256 -ne [string]$Result.original_intent_identity_sha256 -or [string]$claim.scope_transformation_identity_sha256 -ne [string]$Result.scope_transformation_identity_sha256 -or [string]$claim.task_completion_contract_identity_sha256 -ne [string]$Result.task_completion_contract_identity_sha256) { $errors.Add('WORKER_CLAIM_CONTRACT_MISMATCH') | Out-Null }
            if ([string]$claim.attempted_task_sha256 -ne [string]$contract.required_task_sha256) { $errors.Add('WRONG_TASK_PERFORMED') | Out-Null }
            if ([string]$claim.outcome_disposition -ne [string]$Result.outcome_disposition) { $errors.Add('WORKER_CLAIM_DISPOSITION_MISMATCH') | Out-Null }
            $claimCompleted = @($claim.completed_deliverables | ForEach-Object { [string]$_ } | Sort-Object -Unique)
            $resultCompleted = @($Result.observed_deliverables | ForEach-Object { [string]$_ } | Sort-Object -Unique)
            $claimMissing = @($claim.missing_deliverables | ForEach-Object { [string]$_ } | Sort-Object -Unique)
            $resultMissing = @($Result.missing_deliverables | ForEach-Object { [string]$_ } | Sort-Object -Unique)
            if (($claimCompleted -join "`n") -cne ($resultCompleted -join "`n")) { $errors.Add('WORKER_CLAIM_DELIVERABLE_MISMATCH') | Out-Null }
            if (($claimMissing -join "`n") -cne ($resultMissing -join "`n")) { $errors.Add('WORKER_CLAIM_MISSING_DELIVERABLE_MISMATCH') | Out-Null }
            foreach ($required in @($contract.required_deliverables | ForEach-Object { [string]$_.deliverable_id })) { if ($required -notin $resultCompleted) { $errors.Add("REQUIRED_DELIVERABLE_NOT_OBSERVED:$required") | Out-Null } }
            $answer = [string]$claim.answer
            if ([string]::IsNullOrWhiteSpace($answer) -or $answer.Trim().Length -lt 20 -or (Get-TsfGeneralLegacyDisposition $answer) -ne 'UNCLASSIFIED_RESULT') { $errors.Add('ANSWER_NOT_SUBSTANTIVE') | Out-Null }
        }
    }
    return [pscustomobject]@{valid=$errors.Count -eq 0;errors=@($errors)}
}
