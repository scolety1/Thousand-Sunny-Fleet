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
    $structuredAnalysis = $RequiredTask -match '(?is)\bsummary\b' -and
        $RequiredTask -match '(?is)\bfindings?\b' -and
        $RequiredTask -match '(?is)\bevidence(?:[_ -]?references?)?\b' -and
        $RequiredTask -match '(?is)\blimitations?\b'
    $profile = if ($structuredAnalysis) { 'STRUCTURED_ANALYSIS_V2' } else { 'TEXT_RESPONSE_V2' }
    $contractClass = if ($structuredAnalysis) { 'STRUCTURED_DETERMINISTIC' } else { 'STRUCTURAL_TEXT_ONLY' }
    $admissionEligibility = if ($structuredAnalysis) { 'ADMISSIBLE_WHEN_VERIFIED' } else { 'INFORMATIONAL_NON_ADMISSIBLE' }
    $operatorConfirmationRequired = !$structuredAnalysis
    $nonAdmissionReason = if ($structuredAnalysis) { $null } else { 'GENERIC_TEXT_REQUIRES_PROSE_INTERPRETATION' }
    $exactNextAction = if ($structuredAnalysis) {
        'Return the closed GENERAL_RESULT_V2 worker claim with every required structured deliverable.'
    } else {
        'If admitted fulfillment is required, create a new mission with an exact or mechanically verifiable structured result contract.'
    }
    $deliverables = if ($structuredAnalysis) {
        @(
            [pscustomobject][ordered]@{deliverable_id='summary';description='A substantive analysis summary.';deliverable_type='STRING';minimum_cardinality=1;maximum_cardinality=1;structure_rule='NONEMPTY_SUBSTANTIVE_TEXT_V2';content_path='summary';evidence_references_required=$true},
            [pscustomobject][ordered]@{deliverable_id='findings';description='At least three substantive findings.';deliverable_type='STRING_ARRAY';minimum_cardinality=3;maximum_cardinality=20;structure_rule='BOUNDED_NONEMPTY_STRING_ARRAY_V2';content_path='findings';evidence_references_required=$true},
            [pscustomobject][ordered]@{deliverable_id='evidence_references';description='At least one bounded evidence reference.';deliverable_type='STRING_ARRAY';minimum_cardinality=1;maximum_cardinality=20;structure_rule='BOUNDED_NONEMPTY_STRING_ARRAY_V2';content_path='evidence_references';evidence_references_required=$false},
            [pscustomobject][ordered]@{deliverable_id='limitations';description='An explicit limitations statement.';deliverable_type='STRING';minimum_cardinality=1;maximum_cardinality=1;structure_rule='NONEMPTY_TEXT_V2';content_path='limitations';evidence_references_required=$false}
        )
    } else {
        @([pscustomobject][ordered]@{deliverable_id='requested_answer';description='A substantive answer that performs the authorized requested task.';deliverable_type='STRING';minimum_cardinality=1;maximum_cardinality=1;structure_rule='NONEMPTY_SUBSTANTIVE_TEXT_V2';content_path='substantive_answer';evidence_references_required=$true})
    }
    $semantic = [pscustomobject][ordered]@{
        schema_version = 'tsf_task_completion_contract_v2'
        contract_version = 'TASK_COMPLETION_CONTRACT_V2'
        required_task = $RequiredTask
        required_task_sha256 = Get-TsfSemanticTextSha256 (ConvertTo-TsfSemanticNormalizedText $RequiredTask)
        deliverable_profile = $profile
        result_contract_class = $contractClass
        admission_eligibility = $admissionEligibility
        operator_confirmation_required = $operatorConfirmationRequired
        non_admission_reason = $nonAdmissionReason
        exact_next_action = $exactNextAction
        required_deliverables = @($deliverables)
        required_output_format = 'TSF_GENERAL_RESULT_V2_JSON'
        required_evidence = @('FINAL_RESPONSE_OBSERVED','TASK_IDENTITY_ECHO','INTENT_IDENTITY_ECHO','SCOPE_IDENTITY_ECHO','DELIVERABLE_CONTENT_VERIFIED','EVIDENCE_REFERENCES_PRESENT')
        optional_deliverables = @()
        partial_completion_allowed = $false
        accepted_dispositions = @('FULFILLED','FULFILLED_WITH_CAVEATS')
        success_criteria = if ($structuredAnalysis) {
            @('Transport succeeded.','A closed V2 worker outcome claim was parsed.','The task, intent, scope, mission, revision, and run identities match.','The worker claims task_attempted and task_completed.','Every required deliverable is independently observed and satisfies type, cardinality, structure, and evidence rules.','The canonical verifier confirms the claim/content relationship without interpreting answer prose as worker status.')
        } else {
            @('Transport may succeed.','The raw response is preserved, displayed, and auditable.','The result remains informational and cannot establish fulfillment, verifier GREEN, admission, or a success receipt.')
        }
        fail_closed_conditions = @('EMPTY_RESPONSE','GENERIC_ACKNOWLEDGEMENT','GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE','WORKER_CLAIM_V1_LEGACY_NOT_ADMISSIBLE','WORKER_CLAIM_NOT_CLOSED','WORKER_OWN_OUTCOME_INCONSISTENT','TASK_IDENTITY_MISMATCH','INTENT_IDENTITY_MISMATCH','SCOPE_IDENTITY_MISMATCH','MISSING_DELIVERABLE','DELIVERABLE_CONTENT_INVALID','UNKNOWN_LEGACY_OUTPUT')
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
    return 'UNCLASSIFIED_RESULT'
}

function Get-TsfStructuredClaimContradictionDisposition {
    param([AllowEmptyString()][string]$Response)
    # Retained as a compatibility API only. V2 never interprets arbitrary
    # answer prose as the worker's own outcome.
    return 'UNCLASSIFIED_RESULT'
}

function Test-TsfSemanticArrayValue {
    param([AllowNull()][object]$Value)
    return $null -ne $Value -and $Value -is [System.Array]
}

function Test-TsfSubstantiveTextValue {
    param([AllowNull()][object]$Value)
    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$Value)) { return $false }
    $trimmed = ([string]$Value).Trim()
    return $trimmed.Length -ge 20 -and $trimmed.Length -le 50000 -and $trimmed -notmatch '(?i)^(?:ok(?:ay)?|done|completed|acknowledged|success|thank\s+you)[.!\s]*$'
}

function Get-TsfTaskDeliverableObservation {
    param([Parameter(Mandatory)][object]$Contract,[Parameter(Mandatory)][object]$Claim)
    $errors = [Collections.Generic.List[string]]::new()
    $observed = [Collections.Generic.List[string]]::new()
    $answer = if ($Claim.PSObject.Properties.Name -contains 'substantive_answer') { [string]$Claim.substantive_answer } else { '' }
    $profile = if ($Contract.PSObject.Properties.Name -contains 'deliverable_profile') { [string]$Contract.deliverable_profile } else { 'LEGACY_V1' }
    $content = $null

    if ($profile -eq 'STRUCTURED_ANALYSIS_V2') {
        try { $content = $answer | ConvertFrom-Json -ErrorAction Stop } catch { $errors.Add('SUBSTANTIVE_ANSWER_STRUCTURE_INVALID') | Out-Null }
        if ($null -ne $content -and $content -isnot [pscustomobject]) { $errors.Add('SUBSTANTIVE_ANSWER_STRUCTURE_INVALID') | Out-Null; $content=$null }
    }

    foreach ($deliverable in @($Contract.required_deliverables)) {
        $id = [string]$deliverable.deliverable_id
        $valid = $false
        if ($profile -eq 'TEXT_RESPONSE_V2' -and $id -eq 'requested_answer') {
            $valid = Test-TsfSubstantiveTextValue $answer
        } elseif ($profile -eq 'STRUCTURED_ANALYSIS_V2' -and $null -ne $content) {
            $path = [string]$deliverable.content_path
            if ($content.PSObject.Properties.Name -contains $path) {
                $value = $content.$path
                if ([string]$deliverable.deliverable_type -eq 'STRING') {
                    if ([string]$deliverable.structure_rule -eq 'NONEMPTY_SUBSTANTIVE_TEXT_V2') { $valid = Test-TsfSubstantiveTextValue $value }
                    else { $valid = $value -is [string] -and ![string]::IsNullOrWhiteSpace([string]$value) -and ([string]$value).Length -le 20000 }
                } elseif ([string]$deliverable.deliverable_type -eq 'STRING_ARRAY' -and (Test-TsfSemanticArrayValue $value)) {
                    $items = @($value)
                    $valid = $items.Count -ge [int]$deliverable.minimum_cardinality -and $items.Count -le [int]$deliverable.maximum_cardinality -and
                        @($items | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$_) -or ([string]$_).Length -gt 4000 }).Count -eq 0
                }
            }
        }
        if ($valid) { $observed.Add($id) | Out-Null }
        else { $errors.Add("DELIVERABLE_CONTENT_INVALID:$id") | Out-Null }
    }

    if (!(Test-TsfSemanticArrayValue $Claim.evidence) -or @($Claim.evidence | Where-Object { $_ -is [string] -and ![string]::IsNullOrWhiteSpace([string]$_) }).Count -eq 0) {
        $errors.Add('EVIDENCE_REFERENCES_MISSING') | Out-Null
    } elseif (@($Claim.evidence).Count -gt 50 -or @($Claim.evidence | Where-Object { $_ -isnot [string] -or ([string]$_).Length -gt 2000 }).Count -gt 0) {
        $errors.Add('EVIDENCE_REFERENCES_OUT_OF_BOUNDS') | Out-Null
    }
    return [pscustomobject]@{observed=@($observed | Sort-Object -Unique);errors=@($errors)}
}

function Get-TsfWorkerOutcomeClaimV2Assessment {
    param(
        [AllowNull()][object]$Claim,
        [Parameter(Mandatory)][object]$Contract,
        [Parameter(Mandatory)][string]$MissionId,
        [Parameter(Mandatory)][int]$MissionRevision,
        [Parameter(Mandatory)][string]$RunId
    )
    $errors = [Collections.Generic.List[string]]::new()
    $requiredIds = @($Contract.required_deliverables | ForEach-Object { [string]$_.deliverable_id } | Sort-Object -Unique)
    $missing = @($requiredIds)
    $observed = @()
    $disposition = 'UNCLASSIFIED_RESULT'
    $compatibility = 'STRUCTURED_OUTCOME_CLAIM_V2'

    if ($null -eq $Claim) {
        $errors.Add('WORKER_CLAIM_MISSING') | Out-Null
        return [pscustomobject]@{compatibility_mode=$compatibility;outcome_disposition=$disposition;observed_deliverables=$observed;missing_deliverables=$missing;errors=@($errors)}
    }
    $names = @($Claim.PSObject.Properties.Name)
    if (($names -contains 'schema_version') -and [string]$Claim.schema_version -eq 'tsf_worker_outcome_claim_v1') {
        $errors.Add('WORKER_CLAIM_V1_LEGACY_NOT_ADMISSIBLE') | Out-Null
        return [pscustomobject]@{compatibility_mode='LEGACY_STRUCTURED_CLAIM_V1_FAIL_CLOSED';outcome_disposition=$disposition;observed_deliverables=$observed;missing_deliverables=$missing;errors=@($errors)}
    }

    $requiredFields = @('schema_version','mission_id','mission_revision','run_id','task_completion_contract_identity_sha256','original_intent_identity_sha256','scope_transformation_identity_sha256','attempted_task_sha256','task_attempted','task_completed','outcome_disposition','completed_deliverables','missing_deliverables','blocked_reason','substantive_answer','evidence','caveats')
    if (@($requiredFields | Where-Object { $_ -notin $names }).Count -gt 0 -or @($names | Where-Object { $_ -notin $requiredFields }).Count -gt 0) {
        $errors.Add('WORKER_CLAIM_NOT_CLOSED') | Out-Null
        return [pscustomobject]@{compatibility_mode=$compatibility;outcome_disposition=$disposition;observed_deliverables=$observed;missing_deliverables=$missing;errors=@($errors)}
    }
    if ([string]$Claim.schema_version -ne 'tsf_worker_outcome_claim_v2') { $errors.Add('WORKER_CLAIM_SCHEMA_INVALID') | Out-Null }
    if ([string]$Claim.mission_id -ne $MissionId -or [int]$Claim.mission_revision -ne $MissionRevision -or [string]$Claim.run_id -ne $RunId) { $errors.Add('WORKER_CLAIM_IDENTITY_MISMATCH') | Out-Null }
    if ([string]$Claim.task_completion_contract_identity_sha256 -ne [string]$Contract.task_completion_contract_identity_sha256) { $errors.Add('TASK_IDENTITY_MISMATCH') | Out-Null }
    if ([string]$Claim.original_intent_identity_sha256 -ne [string]$Contract.original_intent_identity_sha256) { $errors.Add('INTENT_IDENTITY_MISMATCH') | Out-Null }
    if ([string]$Claim.scope_transformation_identity_sha256 -ne [string]$Contract.scope_transformation_identity_sha256) { $errors.Add('SCOPE_IDENTITY_MISMATCH') | Out-Null }
    if ([string]$Claim.attempted_task_sha256 -ne [string]$Contract.required_task_sha256) { $errors.Add('WRONG_TASK_PERFORMED') | Out-Null }
    if ($Claim.task_attempted -isnot [bool] -or $Claim.task_completed -isnot [bool]) { $errors.Add('WORKER_OWN_OUTCOME_TYPE_INVALID') | Out-Null }
    if (!(Test-TsfSemanticArrayValue $Claim.completed_deliverables) -or !(Test-TsfSemanticArrayValue $Claim.missing_deliverables) -or !(Test-TsfSemanticArrayValue $Claim.evidence) -or !(Test-TsfSemanticArrayValue $Claim.caveats)) { $errors.Add('WORKER_CLAIM_ARRAY_TYPE_INVALID') | Out-Null }
    elseif (@($Claim.caveats).Count -gt 20 -or @($Claim.caveats | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace([string]$_) -or ([string]$_).Length -gt 2000 }).Count -gt 0) { $errors.Add('CAVEATS_OUT_OF_BOUNDS') | Out-Null }

    $allowedDispositions = @('FULFILLED','FULFILLED_WITH_CAVEATS','PARTIAL','UNABLE_TO_PERFORM','REFUSED','BLOCKED_BY_POLICY','NEEDS_CLARIFICATION','REQUIRED_DELIVERABLE_MISSING','WRONG_TASK_PERFORMED','FAILED','UNCLASSIFIED_RESULT')
    $disposition = [string]$Claim.outcome_disposition
    if ($disposition -notin $allowedDispositions) { $errors.Add('WORKER_DISPOSITION_INVALID') | Out-Null; $disposition='UNCLASSIFIED_RESULT' }
    $allowedBlockedReasons = @('NONE','REQUIRED_INPUT_UNAVAILABLE','ACCESS_UNAVAILABLE','POLICY_BLOCK','REFUSED','NEEDS_CLARIFICATION','TASK_INCOMPLETE','REQUIRED_DELIVERABLE_MISSING','WRONG_TASK','EXECUTION_FAILED','UNSPECIFIED')
    $blockedReason = [string]$Claim.blocked_reason
    if ($blockedReason -notin $allowedBlockedReasons) { $errors.Add('BLOCKED_REASON_INVALID') | Out-Null }

    if ([bool]$Claim.task_completed -and ![bool]$Claim.task_attempted) { $errors.Add('COMPLETED_WITHOUT_ATTEMPT') | Out-Null }
    if ($disposition -in @('FULFILLED','FULFILLED_WITH_CAVEATS')) {
        if (![bool]$Claim.task_attempted -or ![bool]$Claim.task_completed -or $blockedReason -ne 'NONE') { $errors.Add('WORKER_OWN_OUTCOME_INCONSISTENT') | Out-Null }
    } elseif ([bool]$Claim.task_completed -or $blockedReason -eq 'NONE') {
        $errors.Add('WORKER_OWN_OUTCOME_INCONSISTENT') | Out-Null
    }
    $reasonMap = @{
        UNABLE_TO_PERFORM=@('REQUIRED_INPUT_UNAVAILABLE','ACCESS_UNAVAILABLE','TASK_INCOMPLETE')
        REFUSED=@('REFUSED')
        BLOCKED_BY_POLICY=@('POLICY_BLOCK')
        NEEDS_CLARIFICATION=@('NEEDS_CLARIFICATION')
        REQUIRED_DELIVERABLE_MISSING=@('REQUIRED_DELIVERABLE_MISSING','TASK_INCOMPLETE')
        WRONG_TASK_PERFORMED=@('WRONG_TASK')
        FAILED=@('EXECUTION_FAILED','TASK_INCOMPLETE')
        UNCLASSIFIED_RESULT=@('UNSPECIFIED')
        PARTIAL=@('TASK_INCOMPLETE','REQUIRED_DELIVERABLE_MISSING')
    }
    if ($reasonMap.ContainsKey($disposition) -and $blockedReason -notin @($reasonMap[$disposition])) { $errors.Add('BLOCKED_REASON_DISPOSITION_MISMATCH') | Out-Null }
    if ($disposition -eq 'FULFILLED_WITH_CAVEATS' -and @($Claim.caveats).Count -eq 0) { $errors.Add('CAVEATS_REQUIRED') | Out-Null }

    $observation = Get-TsfTaskDeliverableObservation -Contract $Contract -Claim $Claim
    $observed = @($observation.observed)
    foreach ($entry in @($observation.errors)) { $errors.Add([string]$entry) | Out-Null }
    $missing = @($requiredIds | Where-Object { $_ -notin $observed })

    $completed = if (Test-TsfSemanticArrayValue $Claim.completed_deliverables) { @($Claim.completed_deliverables | ForEach-Object { [string]$_ } | Sort-Object -Unique) } else { @() }
    $reportedMissing = if (Test-TsfSemanticArrayValue $Claim.missing_deliverables) { @($Claim.missing_deliverables | ForEach-Object { [string]$_ } | Sort-Object -Unique) } else { @() }
    if (@($completed | Where-Object { $_ -notin $requiredIds }).Count -gt 0 -or @($reportedMissing | Where-Object { $_ -notin $requiredIds }).Count -gt 0 -or @($completed | Where-Object { $_ -in $reportedMissing }).Count -gt 0) { $errors.Add('DELIVERABLE_SET_INVALID') | Out-Null }
    $partition = @(($completed + $reportedMissing) | Sort-Object -Unique)
    if (($partition -join "`n") -cne ($requiredIds -join "`n")) { $errors.Add('DELIVERABLE_PARTITION_INCOMPLETE') | Out-Null }
    if (($completed -join "`n") -cne ($observed -join "`n")) { $errors.Add('WORKER_CLAIM_DELIVERABLE_MISMATCH') | Out-Null }
    if (($reportedMissing -join "`n") -cne ($missing -join "`n")) { $errors.Add('WORKER_CLAIM_MISSING_DELIVERABLE_MISMATCH') | Out-Null }
    if ($disposition -eq 'PARTIAL' -and ![bool]$Contract.partial_completion_allowed) { $errors.Add('PARTIAL_NOT_ALLOWED') | Out-Null }
    if ($disposition -eq 'PARTIAL' -and $missing.Count -eq 0) { $errors.Add('PARTIAL_HAS_ALL_DELIVERABLES') | Out-Null }

    if ($errors -contains 'WRONG_TASK_PERFORMED') { $disposition='WRONG_TASK_PERFORMED' }
    elseif ($missing.Count -gt 0 -and $disposition -in @('FULFILLED','FULFILLED_WITH_CAVEATS')) { $disposition='REQUIRED_DELIVERABLE_MISSING' }
    elseif (@($errors | Where-Object { $_ -in @('WORKER_CLAIM_SCHEMA_INVALID','WORKER_CLAIM_NOT_CLOSED','WORKER_OWN_OUTCOME_TYPE_INVALID','WORKER_OWN_OUTCOME_INCONSISTENT','BLOCKED_REASON_INVALID','BLOCKED_REASON_DISPOSITION_MISMATCH','COMPLETED_WITHOUT_ATTEMPT','WORKER_DISPOSITION_INVALID') }).Count -gt 0) { $disposition='UNCLASSIFIED_RESULT' }

    return [pscustomobject]@{compatibility_mode=$compatibility;outcome_disposition=$disposition;observed_deliverables=$observed;missing_deliverables=$missing;errors=@($errors | Sort-Object -Unique)}
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
    $claim = $null
    $parseError = $false
    try { $claim = $raw | ConvertFrom-Json -ErrorAction Stop } catch { $parseError=$true }
    $assessment = Get-TsfWorkerOutcomeClaimV2Assessment -Claim $claim -Contract $TaskCompletionContract -MissionId $MissionId -MissionRevision $MissionRevision -RunId $RunId
    $errors = [Collections.Generic.List[string]]::new()
    foreach ($entry in @($assessment.errors)) { $errors.Add([string]$entry) | Out-Null }
    if ($parseError) { $errors.Add('WORKER_CLAIM_INVALID_JSON') | Out-Null }
    $workerDisposition = [string]$assessment.outcome_disposition
    $missing = @($assessment.missing_deliverables)
    $completed = @($assessment.observed_deliverables)
    $contractClass = if ($TaskCompletionContract.PSObject.Properties.Name -contains 'result_contract_class') { [string]$TaskCompletionContract.result_contract_class } else { 'LEGACY_UNCLASSIFIED' }
    $admissionEligibility = if ($TaskCompletionContract.PSObject.Properties.Name -contains 'admission_eligibility') { [string]$TaskCompletionContract.admission_eligibility } else { 'INFORMATIONAL_NON_ADMISSIBLE' }
    $structuralTextOnly = $contractClass -eq 'STRUCTURAL_TEXT_ONLY' -or [string]$TaskCompletionContract.deliverable_profile -eq 'TEXT_RESPONSE_V2'
    if ($structuralTextOnly -or $admissionEligibility -ne 'ADMISSIBLE_WHEN_VERIFIED') {
        $errors.Add('GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE') | Out-Null
        if ($workerDisposition -in @('FULFILLED','FULFILLED_WITH_CAVEATS')) { $workerDisposition = 'UNCLASSIFIED_RESULT' }
    }
    $accepted = @($TaskCompletionContract.accepted_dispositions) -contains $workerDisposition
    $semantic = $transport -and !$structuralTextOnly -and $admissionEligibility -eq 'ADMISSIBLE_WHEN_VERIFIED' -and $accepted -and $missing.Count -eq 0 -and $errors.Count -eq 0
    [pscustomobject][ordered]@{
        schema_version='tsf_general_result_v2';compatibility_mode=$(if($structuralTextOnly-and[string]$assessment.compatibility_mode-eq'STRUCTURED_OUTCOME_CLAIM_V2'){'STRUCTURAL_TEXT_ONLY_V2'}else{[string]$assessment.compatibility_mode});mission_id=$MissionId;mission_revision=$MissionRevision;run_id=$RunId;result_id=$RunId
        original_intent_identity_sha256=[string]$TaskCompletionContract.original_intent_identity_sha256;scope_transformation_identity_sha256=[string]$TaskCompletionContract.scope_transformation_identity_sha256;task_completion_contract_identity_sha256=[string]$TaskCompletionContract.task_completion_contract_identity_sha256
        raw_worker_response_sha256=$rawHash;worker_claim=$claim;observed_deliverables=@($completed);missing_deliverables=@($missing);outcome_disposition=$workerDisposition;outcome_evidence=@($errors | Sort-Object -Unique);transport_status=$(if($transport){'SUCCEEDED'}else{'FAILED'});semantic_status=$(if($semantic){'FULFILLED'}else{'NOT_FULFILLED'});semantic_success=$semantic;admissible=$semantic
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
        $contractClass = if ($contract.PSObject.Properties.Name -contains 'result_contract_class') { [string]$contract.result_contract_class } else { 'LEGACY_UNCLASSIFIED' }
        $admissionEligibility = if ($contract.PSObject.Properties.Name -contains 'admission_eligibility') { [string]$contract.admission_eligibility } else { 'INFORMATIONAL_NON_ADMISSIBLE' }
        $structuralTextOnly = $contractClass -eq 'STRUCTURAL_TEXT_ONLY' -or [string]$contract.deliverable_profile -eq 'TEXT_RESPONSE_V2'
        if ([string]$Result.original_intent_identity_sha256 -ne [string]$contract.original_intent_identity_sha256) { $errors.Add('INTENT_IDENTITY_MISMATCH') | Out-Null }
        if ([string]$Result.scope_transformation_identity_sha256 -ne [string]$contract.scope_transformation_identity_sha256) { $errors.Add('SCOPE_IDENTITY_MISMATCH') | Out-Null }
        if ([string]$Result.task_completion_contract_identity_sha256 -ne [string]$contract.task_completion_contract_identity_sha256) { $errors.Add('TASK_IDENTITY_MISMATCH') | Out-Null }
        if ($structuralTextOnly -or $admissionEligibility -ne 'ADMISSIBLE_WHEN_VERIFIED') {
            $errors.Add('GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE') | Out-Null
        }
    }
    if ([string]$Result.transport_status -ne 'SUCCEEDED') { $errors.Add('TRANSPORT_NOT_SUCCEEDED') | Out-Null }
    if ([string]::IsNullOrWhiteSpace([string]$Result.raw_worker_response_sha256)) { $errors.Add('RAW_WORKER_RESPONSE_HASH_MISSING') | Out-Null }
    if ($null -ne $claim -and $null -ne $contract) {
        $assessment = Get-TsfWorkerOutcomeClaimV2Assessment -Claim $claim -Contract $contract -MissionId ([string]$Result.mission_id) -MissionRevision ([int]$Result.mission_revision) -RunId ([string]$Result.result_id)
        foreach ($entry in @($assessment.errors)) { $errors.Add([string]$entry) | Out-Null }
        $resultObserved = @($Result.observed_deliverables | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        $resultMissing = @($Result.missing_deliverables | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        $canonicalDisposition = [string]$assessment.outcome_disposition
        $canonicalEvidence = [Collections.Generic.List[string]]::new()
        foreach ($entry in @($assessment.errors)) { $canonicalEvidence.Add([string]$entry) | Out-Null }
        if ($structuralTextOnly -or $admissionEligibility -ne 'ADMISSIBLE_WHEN_VERIFIED') {
            if ($canonicalDisposition -in @('FULFILLED','FULFILLED_WITH_CAVEATS')) { $canonicalDisposition = 'UNCLASSIFIED_RESULT' }
            $canonicalEvidence.Add('GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE') | Out-Null
        }
        if ((@($assessment.observed_deliverables) -join "`n") -cne ($resultObserved -join "`n")) { $errors.Add('CANONICAL_OBSERVED_DELIVERABLE_MISMATCH') | Out-Null }
        if ((@($assessment.missing_deliverables) -join "`n") -cne ($resultMissing -join "`n")) { $errors.Add('CANONICAL_MISSING_DELIVERABLE_MISMATCH') | Out-Null }
        if ($canonicalDisposition -ne [string]$Result.outcome_disposition) { $errors.Add('CANONICAL_OUTCOME_DISPOSITION_MISMATCH') | Out-Null }
        $resultEvidence = @($Result.outcome_evidence | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        if ((@($canonicalEvidence | Sort-Object -Unique) -join "`n") -cne ($resultEvidence -join "`n")) { $errors.Add('CANONICAL_OUTCOME_EVIDENCE_MISMATCH') | Out-Null }
    }
    if ([string]$Result.semantic_status -ne 'FULFILLED') { $errors.Add('SEMANTIC_STATUS_NOT_FULFILLED') | Out-Null }
    if (@($Result.outcome_evidence).Count -ne 0) { $errors.Add('OUTCOME_ERRORS_PRESENT') | Out-Null }
    if (@($Result.missing_deliverables).Count -ne 0) { $errors.Add('REQUIRED_DELIVERABLE_MISSING') | Out-Null }
    if ($null -ne $contract -and [string]$Result.outcome_disposition -notin @($contract.accepted_dispositions)) { $errors.Add('OUTCOME_DISPOSITION_NOT_ACCEPTED') | Out-Null }
    return [pscustomobject]@{valid=$errors.Count -eq 0;errors=@($errors)}
}
