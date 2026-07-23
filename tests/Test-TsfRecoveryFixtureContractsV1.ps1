[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'tools\TsfJsonContract.ps1')
. (Join-Path $root 'tools\TsfSemanticIntegrity.ps1')

$script:assertions = 0
function Assert-Recovery([bool]$Condition,[string]$Message) {
    $script:assertions++
    if (!$Condition) { throw "ASSERTION_FAILED:$Message" }
}
function Copy-RecoveryObject([object]$Value) {
    $Value | ConvertTo-Json -Depth 40 | ConvertFrom-Json
}
function New-RecoveryContracts([string]$Task) {
    $previewId = 'hq-preview-' + (Get-TsfContractJsonHash ([pscustomobject]@{ task=$Task })).Substring(0,32)
    $intent = New-TsfOriginalOperatorIntentContract -NaturalRequest $Task -PreviewId $previewId -RepositoryTarget $root -WorktreeTarget $root
    $operations = @((Get-TsfOriginalOperationAnalysis $Task).requested_operations)
    $scope = New-TsfScopeTransformationContract -OriginalIntent $intent -AuthorizedMissionGoal $Task -ProposedOperations $operations -ProposedAccess ([string]$intent.requested_access) -RepositoryTarget $root -WorktreeTarget $root
    $completion = New-TsfTaskCompletionContract -RequiredTask $Task -OriginalIntent $intent -ScopeTransformation $scope
    [pscustomobject]@{ intent=$intent;scope=$scope;completion=$completion }
}
function New-RecoveryClaim {
    param(
        [Parameter(Mandatory)][object]$Contracts,
        [Parameter(Mandatory)][string]$MissionId,
        [Parameter(Mandatory)][string]$RunId,
        [string]$Disposition='FULFILLED',
        [string]$BlockedReason='NONE',
        [bool]$TaskCompleted=$true,
        [string]$Answer='',
        [string[]]$Completed=@(),
        [string[]]$Missing=@()
    )
    [pscustomobject][ordered]@{
        schema_version='tsf_worker_outcome_claim_v2'
        mission_id=$MissionId
        mission_revision=1
        run_id=$RunId
        task_completion_contract_identity_sha256=[string]$Contracts.completion.task_completion_contract_identity_sha256
        original_intent_identity_sha256=[string]$Contracts.completion.original_intent_identity_sha256
        scope_transformation_identity_sha256=[string]$Contracts.completion.scope_transformation_identity_sha256
        attempted_task_sha256=[string]$Contracts.completion.required_task_sha256
        task_attempted=$true
        task_completed=$TaskCompleted
        outcome_disposition=$Disposition
        completed_deliverables=@($Completed)
        missing_deliverables=@($Missing)
        blocked_reason=$BlockedReason
        substantive_answer=$Answer
        evidence=@('fleet/control/policy-manifest.v1.json#schema_version')
        caveats=@()
    }
}
function Get-RecoveryEvidence([object]$Contracts,[string]$MissionId,[string]$RunId,[object]$Response) {
    $finalResponse = if ($Response -is [string]) { [string]$Response } else { $Response | ConvertTo-Json -Compress -Depth 40 }
    Get-TsfGeneralResultV2Evidence -MissionId $MissionId -MissionRevision 1 -RunId $RunId -Adapter ([pscustomobject]@{transport_success=$true;final_response=$finalResponse}) -TaskCompletionContract $Contracts.completion
}
function Test-RecoveryAdmission([object]$Contracts,[object]$Evidence) {
    $mission = [pscustomobject]@{ result_validation_mode='GENERAL_RESULT_V2';task_completion_contract=$Contracts.completion }
    $result = [pscustomobject]@{
        result_validation_mode='GENERAL_RESULT_V2'
        mission_id=$Evidence.mission_id
        mission_revision=$Evidence.mission_revision
        result_id=$Evidence.result_id
        original_intent_identity_sha256=$Evidence.original_intent_identity_sha256
        scope_transformation_identity_sha256=$Evidence.scope_transformation_identity_sha256
        task_completion_contract_identity_sha256=$Evidence.task_completion_contract_identity_sha256
        transport_status=$Evidence.transport_status
        semantic_status=$Evidence.semantic_status
        outcome_disposition=$Evidence.outcome_disposition
        worker_claim=$Evidence.worker_claim
        observed_deliverables=@($Evidence.observed_deliverables)
        missing_deliverables=@($Evidence.missing_deliverables)
        outcome_evidence=@($Evidence.outcome_evidence)
        raw_worker_response_sha256=$Evidence.raw_worker_response_sha256
    }
    Test-TsfGeneralResultV2AdmissionEvidence -Mission $mission -Result $result
}

$structuredTask = 'Read only fleet/control/policy-manifest.v1.json and return a structured analysis with a summary, at least three findings, evidence references, and limitations.'
$structured = New-RecoveryContracts $structuredTask
$structuredIds = @($structured.completion.required_deliverables | ForEach-Object { [string]$_.deliverable_id } | Sort-Object)
Assert-Recovery ([string]$structured.completion.deliverable_profile -eq 'STRUCTURED_ANALYSIS_V2') 'Fixture A selects STRUCTURED_ANALYSIS_V2.'
Assert-Recovery ([string]$structured.completion.result_contract_class -eq 'STRUCTURED_DETERMINISTIC') 'Fixture A selects deterministic structure.'
Assert-Recovery ([string]$structured.completion.admission_eligibility -eq 'ADMISSIBLE_WHEN_VERIFIED') 'Fixture A is eligible only after verification.'
Assert-Recovery (!$structured.completion.operator_confirmation_required) 'Fixture A never confirms informational generic text.'
Assert-Recovery (($structuredIds -join ',') -eq 'evidence_references,findings,limitations,summary') 'Fixture A binds every required deliverable.'

$structuredMission = 'recovery-structured-0001'
$structuredRun = 'canonical-result-recovery-structured-0001-1'
$structuredAnswer = [pscustomobject][ordered]@{
    summary='The recovery fixture read the bounded policy manifest and completed a mechanically verifiable structured analysis.'
    findings=@(
        'The manifest declares its canonical schema version.',
        'The recovered run is distinct from the immutable interrupted run.',
        'Admission depends on structured deliverables and independent verification.'
    )
    evidence_references=@('fleet/control/policy-manifest.v1.json#schema_version')
    limitations='The fixture is limited to the bounded TSF-local policy manifest.'
} | ConvertTo-Json -Compress -Depth 10
$structuredClaim = New-RecoveryClaim -Contracts $structured -MissionId $structuredMission -RunId $structuredRun -Answer $structuredAnswer -Completed $structuredIds
$structuredEvidence = Get-RecoveryEvidence $structured $structuredMission $structuredRun $structuredClaim
$structuredAdmission = Test-RecoveryAdmission $structured $structuredEvidence
Assert-Recovery $structuredEvidence.semantic_success 'Fixture A establishes semantic fulfillment through structure.'
Assert-Recovery $structuredEvidence.admissible 'Fixture A is admissible after deterministic validation.'
Assert-Recovery ([string]$structuredEvidence.outcome_disposition -eq 'FULFILLED') 'Fixture A preserves the closed fulfilled disposition.'
Assert-Recovery (@($structuredEvidence.missing_deliverables).Count -eq 0) 'Fixture A has no missing deliverables.'
Assert-Recovery $structuredAdmission.valid 'Fixture A independently passes admission evidence.'

$genericTask = 'Read only fleet/control/policy-manifest.v1.json and return a concise recovery response.'
$generic = New-RecoveryContracts $genericTask
$genericMission = 'recovery-generic-0001'
$genericRun = 'canonical-result-recovery-generic-0001-1'
Assert-Recovery ([string]$generic.completion.deliverable_profile -eq 'TEXT_RESPONSE_V2') 'Fixture B selects TEXT_RESPONSE_V2.'
Assert-Recovery ([string]$generic.completion.result_contract_class -eq 'STRUCTURAL_TEXT_ONLY') 'Fixture B is structural-only.'
Assert-Recovery ([string]$generic.completion.admission_eligibility -eq 'INFORMATIONAL_NON_ADMISSIBLE') 'Fixture B is informational and non-admissible.'
Assert-Recovery ([bool]$generic.completion.operator_confirmation_required) 'Fixture B exposes the material informational distinction.'

$genericAnswer = 'The recovery response is complete-looking, cites the bounded manifest, and claims that every requested step was fulfilled.'
$genericClaim = New-RecoveryClaim -Contracts $generic -MissionId $genericMission -RunId $genericRun -Answer $genericAnswer -Completed @('requested_answer')
$genericEvidence = Get-RecoveryEvidence $generic $genericMission $genericRun $genericClaim
$genericAdmission = Test-RecoveryAdmission $generic $genericEvidence
Assert-Recovery ([string]$genericEvidence.transport_status -eq 'SUCCEEDED') 'Fixture B preserves successful transport.'
Assert-Recovery ([string]$genericEvidence.compatibility_mode -eq 'STRUCTURAL_TEXT_ONLY_V2') 'Fixture B records structural-only compatibility.'
Assert-Recovery ([string]$genericEvidence.outcome_disposition -eq 'UNCLASSIFIED_RESULT') 'Fixture B demotes worker FULFILLED to UNCLASSIFIED_RESULT.'
Assert-Recovery (!$genericEvidence.semantic_success -and !$genericEvidence.admissible) 'Fixture B never establishes fulfillment or admissibility.'
Assert-Recovery ($genericEvidence.outcome_evidence -contains 'GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE') 'Fixture B records the closed non-admission reason.'
Assert-Recovery (!$genericAdmission.valid) 'Fixture B creates no successful admission evidence.'
Assert-Recovery ([string]$genericEvidence.raw_worker_response_sha256 -match '^[a-f0-9]{64}$') 'Fixture B preserves a hash-bound raw response.'

$genericUnableClaim = New-RecoveryClaim -Contracts $generic -MissionId $genericMission -RunId $genericRun -Answer "I couldn't complete the requested task." -Completed @('requested_answer')
$genericUnable = Get-RecoveryEvidence $generic $genericMission $genericRun $genericUnableClaim
Assert-Recovery ([string]$genericUnable.outcome_disposition -eq 'UNCLASSIFIED_RESULT' -and !(Test-RecoveryAdmission $generic $genericUnable).valid) 'Generic inability remains non-admissible without phrase authority.'

$structuredUnableClaim = New-RecoveryClaim -Contracts $structured -MissionId $structuredMission -RunId $structuredRun -Disposition 'UNABLE_TO_PERFORM' -BlockedReason 'TASK_INCOMPLETE' -TaskCompleted:$false -Answer $structuredAnswer -Completed $structuredIds
$structuredUnable = Get-RecoveryEvidence $structured $structuredMission $structuredRun $structuredUnableClaim
Assert-Recovery (!$structuredUnable.semantic_success -and !(Test-RecoveryAdmission $structured $structuredUnable).valid) 'Structured inability cannot admit.'

$missingAnswer = [pscustomobject][ordered]@{
    summary='The recovery analysis is incomplete.'
    findings=@('First bounded finding.','Second bounded finding.','Third bounded finding.')
    limitations='Evidence references are intentionally absent.'
} | ConvertTo-Json -Compress
$missingClaim = New-RecoveryClaim -Contracts $structured -MissionId $structuredMission -RunId $structuredRun -Disposition 'REQUIRED_DELIVERABLE_MISSING' -BlockedReason 'REQUIRED_DELIVERABLE_MISSING' -TaskCompleted:$false -Answer $missingAnswer -Completed @('findings','limitations','summary') -Missing @('evidence_references')
$missingEvidence = Get-RecoveryEvidence $structured $structuredMission $structuredRun $missingClaim
Assert-Recovery (@($missingEvidence.missing_deliverables) -contains 'evidence_references' -and !(Test-RecoveryAdmission $structured $missingEvidence).valid) 'Missing structured deliverable cannot admit.'

$wrongContract = Get-RecoveryEvidence $structured $structuredMission $structuredRun 'A generic recovery response cannot satisfy a structured recovery contract.'
Assert-Recovery (!$wrongContract.semantic_success -and !(Test-RecoveryAdmission $structured $wrongContract).valid) 'Generic text cannot substitute for Fixture A structured evidence.'

foreach ($case in @(
    [pscustomobject]@{field='mission_id';value='recovery-other-0001';message='Cross-mission recovery result is rejected.'},
    [pscustomobject]@{field='mission_revision';value=2;message='Cross-revision recovery result is rejected.'},
    [pscustomobject]@{field='run_id';value='canonical-result-recovery-other-0001-1';message='Cross-run recovery result is rejected.'}
)) {
    $forged = Copy-RecoveryObject $structuredClaim
    $forged.($case.field) = $case.value
    $forgedEvidence = Get-RecoveryEvidence $structured $structuredMission $structuredRun $forged
    Assert-Recovery (!$forgedEvidence.semantic_success -and !(Test-RecoveryAdmission $structured $forgedEvidence).valid) $case.message
}

$structuredAgain = New-RecoveryContracts $structuredTask
Assert-Recovery ([string]$structuredAgain.completion.task_completion_contract_identity_sha256 -eq [string]$structured.completion.task_completion_contract_identity_sha256) 'Exact contract replay is stable and idempotent.'
Assert-Recovery ([string]$generic.completion.task_completion_contract_identity_sha256 -ne [string]$structured.completion.task_completion_contract_identity_sha256) 'Changed result-contract replay has a distinct identity.'

$relaySource = Get-Content -Raw -LiteralPath (Join-Path $root 'tools\hq-dispatch\v1\mission-relay.mjs')
$realFixtureSource = Get-Content -Raw -LiteralPath (Join-Path $root 'tests\test-tsf-hq-dispatch-real-reliability-v1.mjs')
$uiSource = Get-Content -Raw -LiteralPath (Join-Path $root 'tools\hq-dispatch\v1\public\app.js')
Assert-Recovery ($relaySource.Contains('taskCompletionContract: sourceMission.task_completion_contract ?? null')) 'Recovery clones the canonical source contract instead of inventing authority.'
Assert-Recovery ($relaySource.Contains('async retryInterrupted({ item, interruption = null, sessionGeneration = "" })')) 'Recovery activation accepts no caller-supplied result contract.'
Assert-Recovery ($realFixtureSource.Contains('return a structured analysis with a summary, at least three findings, evidence references, and limitations')) 'The real admitted-recovery fixture requests the structured contract explicitly.'
Assert-Recovery ($uiSource.Contains('Response received. Task fulfillment could not be independently verified from this result contract. The response was preserved but not admitted.')) 'Fixture B UI states preservation without admission.'
Assert-Recovery ($uiSource.Contains('no_admission_receipt: status.admission == null')) 'Fixture B UI exposes absence of an admission receipt.'

[pscustomobject][ordered]@{
    schema_version='tsf_recovery_fixture_contract_test_v1'
    status='PASS'
    assertions=$script:assertions
    architecture_classification='RECOVERY_SUCCESS_FIXTURE_USES_NON_ADMISSIBLE_GENERIC_TEXT'
    criteria=@(
        [pscustomobject]@{name='RECOVERY_PIPELINE_COMPLETED_AND_ADMITTED';status='PASS';contract='STRUCTURED_ANALYSIS_V2'},
        [pscustomobject]@{name='GENERIC_RECOVERY_RESPONSE_PRESERVED_NON_ADMISSIBLE';status='PASS';contract='TEXT_RESPONSE_V2'}
    )
    generic_text_admissions=0
    semantic_llm_authority_added=$false
    whole_answer_regex_authority_added=$false
} | ConvertTo-Json -Depth 8
