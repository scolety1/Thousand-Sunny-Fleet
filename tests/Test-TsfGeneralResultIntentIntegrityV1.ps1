[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'tools\TsfJsonContract.ps1')
. (Join-Path $root 'tools\TsfSemanticIntegrity.ps1')

$script:assertions = 0
function Assert-Tsf {
    param([Parameter(Mandatory)][bool]$Condition,[Parameter(Mandatory)][string]$Message)
    $script:assertions++
    if (!$Condition) { throw "ASSERTION_FAILED: $Message" }
}

function New-TestContracts {
    param([string]$Request = 'Return a concise summary: the fleet is idle.')
    $intent = New-TsfOriginalOperatorIntentContract -NaturalRequest $Request -PreviewId 'hq-preview-00000000000000000000000000000000' -RepositoryTarget $root -WorktreeTarget $root
    $operations = @((Get-TsfOriginalOperationAnalysis $Request).requested_operations)
    $scope = New-TsfScopeTransformationContract -OriginalIntent $intent -AuthorizedMissionGoal $Request -ProposedOperations $operations -ProposedAccess ([string]$intent.requested_access) -RepositoryTarget $root -WorktreeTarget $root
    $task = New-TsfTaskCompletionContract -RequiredTask $Request -OriginalIntent $intent -ScopeTransformation $scope
    return [pscustomobject]@{intent=$intent;scope=$scope;task=$task}
}

function New-TestClaim {
    param(
        [Parameter(Mandatory)][object]$Contracts,
        [string]$Disposition = 'FULFILLED',
        [string]$Answer = 'The fleet is idle, stated concisely as requested.',
        [string[]]$Completed = @('requested_answer'),
        [string[]]$Missing = @(),
        [string]$AttemptedTaskSha256 = ''
    )
    if ([string]::IsNullOrWhiteSpace($AttemptedTaskSha256)) { $AttemptedTaskSha256 = [string]$Contracts.task.required_task_sha256 }
    [pscustomobject][ordered]@{
        schema_version='tsf_worker_outcome_claim_v1';mission_id='semantic-test';mission_revision=1;run_id='canonical-result-semantic-test-1'
        task_completion_contract_identity_sha256=[string]$Contracts.task.task_completion_contract_identity_sha256
        original_intent_identity_sha256=[string]$Contracts.task.original_intent_identity_sha256
        scope_transformation_identity_sha256=[string]$Contracts.task.scope_transformation_identity_sha256
        attempted_task_sha256=$AttemptedTaskSha256;outcome_disposition=$Disposition;completed_deliverables=@($Completed);missing_deliverables=@($Missing)
        answer=$Answer;evidence=@('worker final response');caveats=@()
    }
}

function Get-TestEvidence {
    param([Parameter(Mandatory)][object]$Contracts,[AllowEmptyString()][string]$Raw,[bool]$Transport=$true,[AllowNull()][object]$TaskContract=$Contracts.task)
    $adapter=[pscustomobject]@{transport_success=$Transport;final_response=$Raw}
    Get-TsfGeneralResultV2Evidence -MissionId 'semantic-test' -MissionRevision 1 -RunId 'canonical-result-semantic-test-1' -Adapter $adapter -TaskCompletionContract $TaskContract
}

$operationMatrix = @(
    [pscustomobject]@{request='Edit the configuration file.';required=@('FILE_EDIT','WORKSPACE_WRITE');authority=$true},
    [pscustomobject]@{request='Add a source file, commit the changes, and push the branch.';required=@('FILE_CREATE','WORKSPACE_WRITE','COMMIT','GIT_WRITE','PUSH');authority=$true},
    [pscustomobject]@{request='Delete the generated file and commit the change.';required=@('FILE_DELETE','WORKSPACE_WRITE','COMMIT','GIT_WRITE');authority=$true},
    [pscustomobject]@{request='Rename the file and move it into the archive folder.';required=@('PATH_RENAME_MOVE','WORKSPACE_WRITE');authority=$true},
    [pscustomobject]@{request='Modify code.';required=@('FILE_EDIT','WORKSPACE_WRITE');authority=$true},
    [pscustomobject]@{request='Merge the PR.';required=@('MERGE','GIT_WRITE');authority=$true},
    [pscustomobject]@{request='Install a package.';required=@('INSTALLATION');authority=$true},
    [pscustomobject]@{request='Deploy the application.';required=@('DEPLOYMENT');authority=$true},
    [pscustomobject]@{request='Fix this but only inspect it if you cannot write.';required=@('FILE_EDIT','WORKSPACE_WRITE');authority=$true},
    [pscustomobject]@{request='Make the change.';required=@('WORKSPACE_WRITE');authority=$true},
    [pscustomobject]@{request='Prepare and commit.';required=@('COMMIT','GIT_WRITE');authority=$true},
    [pscustomobject]@{request='Update this repository.';required=@('WORKSPACE_WRITE');authority=$true},
    [pscustomobject]@{request='Review the source and then edit it.';required=@('FILE_EDIT','WORKSPACE_WRITE','READ_ANALYSIS');authority=$true},
    [pscustomobject]@{request='Use the plugin to inspect status.';required=@('PLUGIN_OPERATION');authority=$true},
    [pscustomobject]@{request='Read and use the API key credential.';required=@('CREDENTIAL_ACCESS');authority=$true},
    [pscustomobject]@{request='Return exactly TSF_GREEN.';required=@('RETURN_RESULT');authority=$false},
    [pscustomobject]@{request='Analyze this self-contained statement and return a summary.';required=@('READ_ANALYSIS','RETURN_RESULT');authority=$false},
    [pscustomobject]@{request='Read the local source file and explain it.';required=@('READ_FILE','READ_ANALYSIS','RETURN_RESULT');authority=$false}
)
foreach($case in $operationMatrix){
    $analysis=Get-TsfOriginalOperationAnalysis $case.request
    foreach($required in $case.required){Assert-Tsf ($analysis.requested_operations -contains $required) "Operation $required retained for: $($case.request)"}
    Assert-Tsf ((@($analysis.authority_bearing_operations).Count -gt 0) -eq $case.authority) "Authority classification for: $($case.request)"
}

$ambiguous=Get-TsfOriginalOperationAnalysis 'Do this safely.'
Assert-Tsf ([string]$ambiguous.ambiguity_status -eq 'AMBIGUOUS_AUTHORITY_INTENT') 'Ambiguous modification intent fails closed for TIM review.'

$writeContracts=New-TestContracts 'Edit the configuration file.'
$writeScope=New-TsfScopeTransformationContract -OriginalIntent $writeContracts.intent -AuthorizedMissionGoal $writeContracts.intent.requested_goal -ProposedOperations @('READ_ANALYSIS','RETURN_RESULT') -ProposedAccess 'READ_ONLY' -RepositoryTarget $root -WorktreeTarget $root -DetachedHead:$true
Assert-Tsf (!$writeScope.queue_allowed) 'Write request cannot queue through a read-only substitute.'
Assert-Tsf $writeScope.operator_confirmation_required 'Write authority reduction requires operator confirmation.'
Assert-Tsf ([string]$writeScope.classification -eq 'AUTHORITY_REDUCTION_REQUIRES_OPERATOR_CONFIRMATION') 'Write authority reduction is explicit.'

$fileContracts=New-TestContracts 'Read the local source file and explain it.'
$fileScope=New-TsfScopeTransformationContract -OriginalIntent $fileContracts.intent -AuthorizedMissionGoal $fileContracts.intent.requested_goal -ProposedOperations @('READ_ANALYSIS','RETURN_RESULT') -ProposedAccess 'READ_ONLY' -RepositoryTarget $root -WorktreeTarget $root
Assert-Tsf (!$fileScope.queue_allowed) 'A local-file request cannot queue when proposed operations omit READ_FILE.'
Assert-Tsf ([string]$fileScope.classification -eq 'REQUEST_UNFULFILLABLE_UNDER_CURRENT_AUTHORITY') 'Unavailable file authority is explicit.'

$contracts=New-TestContracts
$successClaim=New-TestClaim $contracts
$success=Get-TestEvidence $contracts ($successClaim|ConvertTo-Json -Compress -Depth 20)
Assert-Tsf $success.semantic_success 'Substantive, identity-bound fulfilled claim succeeds.'
Assert-Tsf ([string]$success.outcome_disposition -eq 'FULFILLED') 'Successful disposition is retained.'
Assert-Tsf ((Test-TsfJsonContract $success (Join-Path $root 'fleet\control\general-result-v2.schema.v1.json')).valid) 'General result evidence validates against schema.'
$admissionMission=[pscustomobject]@{result_validation_mode='GENERAL_RESULT_V2';task_completion_contract=$contracts.task}
$admissionResult=[pscustomobject]@{result_validation_mode='GENERAL_RESULT_V2';mission_id=$success.mission_id;mission_revision=$success.mission_revision;result_id=$success.result_id;original_intent_identity_sha256=$success.original_intent_identity_sha256;scope_transformation_identity_sha256=$success.scope_transformation_identity_sha256;task_completion_contract_identity_sha256=$success.task_completion_contract_identity_sha256;transport_status=$success.transport_status;semantic_status=$success.semantic_status;outcome_disposition=$success.outcome_disposition;worker_claim=$success.worker_claim;observed_deliverables=@($success.observed_deliverables);missing_deliverables=@($success.missing_deliverables);outcome_evidence=@($success.outcome_evidence);raw_worker_response_sha256=$success.raw_worker_response_sha256}
Assert-Tsf ((Test-TsfGeneralResultV2AdmissionEvidence -Mission $admissionMission -Result $admissionResult).valid) 'Admission independently accepts consistent fulfilled evidence.'
$admissionWrongTask=$admissionResult|ConvertTo-Json -Depth 30|ConvertFrom-Json;$admissionWrongTask.worker_claim.attempted_task_sha256='f'*64
Assert-Tsf (!(Test-TsfGeneralResultV2AdmissionEvidence -Mission $admissionMission -Result $admissionWrongTask).valid) 'Admission independently rejects a forged attempted-task identity.'
$admissionWrongOutcome=$admissionResult|ConvertTo-Json -Depth 30|ConvertFrom-Json;$admissionWrongOutcome.worker_claim.outcome_disposition='UNABLE_TO_PERFORM'
Assert-Tsf (!(Test-TsfGeneralResultV2AdmissionEvidence -Mission $admissionMission -Result $admissionWrongOutcome).valid) 'Admission independently rejects worker-claim and canonical-outcome disagreement.'
$admissionMissing=$admissionResult|ConvertTo-Json -Depth 30|ConvertFrom-Json;$admissionMissing.observed_deliverables=@();$admissionMissing.missing_deliverables=@('requested_answer')
Assert-Tsf (!(Test-TsfGeneralResultV2AdmissionEvidence -Mission $admissionMission -Result $admissionMissing).valid) 'Admission independently rejects missing required deliverables.'
$admissionCrossRun=$admissionResult|ConvertTo-Json -Depth 30|ConvertFrom-Json;$admissionCrossRun.worker_claim.run_id='canonical-result-another-run-1'
Assert-Tsf (!(Test-TsfGeneralResultV2AdmissionEvidence -Mission $admissionMission -Result $admissionCrossRun).valid) 'Admission independently rejects cross-run worker evidence.'

$negativeCases=@(
    [pscustomobject]@{disposition='FULFILLED';answer='I cannot perform this task.';completed=@('requested_answer');missing=@();expected='UNABLE_TO_PERFORM'},
    [pscustomobject]@{disposition='REFUSED';answer='I refuse to perform this task.';completed=@();missing=@('requested_answer');expected='REFUSED'},
    [pscustomobject]@{disposition='BLOCKED_BY_POLICY';answer='This task is blocked by policy.';completed=@();missing=@('requested_answer');expected='BLOCKED_BY_POLICY'},
    [pscustomobject]@{disposition='NEEDS_CLARIFICATION';answer='Please clarify the requested output.';completed=@();missing=@('requested_answer');expected='NEEDS_CLARIFICATION'},
    [pscustomobject]@{disposition='PARTIAL';answer='Only part of the requested answer is available.';completed=@();missing=@('requested_answer');expected='PARTIAL'},
    [pscustomobject]@{disposition='FULFILLED';answer='Done.';completed=@('requested_answer');missing=@();expected='REQUIRED_DELIVERABLE_MISSING'},
    [pscustomobject]@{disposition='FULFILLED';answer='This is a substantive answer but the required deliverable id is absent.';completed=@();missing=@('requested_answer');expected='REQUIRED_DELIVERABLE_MISSING'}
)
foreach($case in $negativeCases){
    $claim=New-TestClaim -Contracts $contracts -Disposition $case.disposition -Answer $case.answer -Completed $case.completed -Missing $case.missing
    $evidence=Get-TestEvidence $contracts ($claim|ConvertTo-Json -Compress -Depth 20)
    Assert-Tsf (!$evidence.semantic_success) "Negative disposition $($case.expected) cannot succeed."
    Assert-Tsf ([string]$evidence.outcome_disposition -eq $case.expected) "Negative disposition $($case.expected) is explicit."
}

$wrongTask=New-TestClaim -Contracts $contracts -AttemptedTaskSha256 ('f'*64)
$wrongTaskEvidence=Get-TestEvidence $contracts ($wrongTask|ConvertTo-Json -Compress -Depth 20)
Assert-Tsf (!$wrongTaskEvidence.semantic_success) 'Wrong task identity cannot succeed.'
Assert-Tsf ($wrongTaskEvidence.outcome_evidence -contains 'WRONG_TASK_PERFORMED') 'Wrong task identity has explicit evidence.'

$crossRun=New-TestClaim $contracts
$crossRun.run_id='canonical-result-another-run-1'
$crossRunEvidence=Get-TestEvidence $contracts ($crossRun|ConvertTo-Json -Compress -Depth 20)
Assert-Tsf (!$crossRunEvidence.semantic_success) 'Cross-run worker claim cannot succeed.'
Assert-Tsf ($crossRunEvidence.outcome_evidence -contains 'WORKER_CLAIM_IDENTITY_MISMATCH') 'Cross-run rejection is explicit.'
$crossMission=New-TestClaim $contracts
$crossMission.mission_id='another-mission'
$crossMissionEvidence=Get-TestEvidence $contracts ($crossMission|ConvertTo-Json -Compress -Depth 20)
Assert-Tsf (!$crossMissionEvidence.semantic_success) 'Cross-mission worker claim cannot succeed.'
$crossRevision=New-TestClaim $contracts
$crossRevision.mission_revision=2
$crossRevisionEvidence=Get-TestEvidence $contracts ($crossRevision|ConvertTo-Json -Compress -Depth 20)
Assert-Tsf (!$crossRevisionEvidence.semantic_success) 'Cross-revision worker claim cannot succeed.'
$crossContract=New-TestClaim $contracts
$crossContract.task_completion_contract_identity_sha256='e'*64
$crossContractEvidence=Get-TestEvidence $contracts ($crossContract|ConvertTo-Json -Compress -Depth 20)
Assert-Tsf (!$crossContractEvidence.semantic_success) 'Cross-contract worker claim cannot succeed.'
Assert-Tsf ($crossContractEvidence.outcome_evidence -contains 'TASK_IDENTITY_MISMATCH') 'Cross-contract rejection is explicit.'
$openClaim=New-TestClaim $contracts
$openClaim|Add-Member -NotePropertyName verifier_green -NotePropertyValue $true
$openClaimEvidence=Get-TestEvidence $contracts ($openClaim|ConvertTo-Json -Compress -Depth 20)
Assert-Tsf (!$openClaimEvidence.semantic_success) 'Caller-supplied verifier or outcome authority is rejected by the closed claim.'
Assert-Tsf ($openClaimEvidence.outcome_evidence -contains 'WORKER_CLAIM_NOT_CLOSED') 'Closed-claim rejection is explicit.'

$legacyEmpty=Get-TestEvidence -Contracts $contracts -Raw '' -TaskContract $null
Assert-Tsf (!$legacyEmpty.admissible) 'Empty legacy response fails closed.'
Assert-Tsf ([string]$legacyEmpty.outcome_disposition -eq 'REQUIRED_DELIVERABLE_MISSING') 'Empty legacy response has explicit disposition.'
$legacyPolicy=Get-TestEvidence -Contracts $contracts -Raw 'The request is blocked by policy.' -TaskContract $null
Assert-Tsf (!$legacyPolicy.admissible) 'Policy-block legacy response fails closed.'
Assert-Tsf ([string]$legacyPolicy.outcome_disposition -eq 'BLOCKED_BY_POLICY') 'Policy-block legacy response is classified.'
$legacyUnknown=Get-TestEvidence -Contracts $contracts -Raw 'A nonempty but unstructured response.' -TaskContract $null
Assert-Tsf (!$legacyUnknown.admissible) 'Unknown legacy response never becomes success.'
Assert-Tsf ([string]$legacyUnknown.outcome_disposition -eq 'UNCLASSIFIED_RESULT') 'Unknown legacy response is explicit.'
$legacyUnsupported=Get-TestEvidence -Contracts $contracts -Raw 'The requested action is unsupported in this environment.' -TaskContract $null
Assert-Tsf (!$legacyUnsupported.admissible) 'Unsupported-action legacy response fails closed.'
Assert-Tsf ([string]$legacyUnsupported.outcome_disposition -eq 'UNABLE_TO_PERFORM') 'Unsupported-action legacy response is classified.'

$lifecycleSource = Get-Content -LiteralPath (Join-Path $root 'tools\Invoke-TsfMissionLifecycle.ps1') -Raw
Assert-Tsf ($lifecycleSource.Contains('answer must be a JSON string even when the requested answer is structured data; serialize any structured answer into that string.')) 'GENERAL_RESULT_V2 worker prompt explicitly binds answer to the canonical string type.'

"TSF_GENERAL_RESULT_INTENT_INTEGRITY_PASS assertions=$script:assertions"
