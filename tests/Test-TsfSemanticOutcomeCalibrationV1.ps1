[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'tools\TsfJsonContract.ps1')
. (Join-Path $root 'tools\TsfSemanticIntegrity.ps1')
$script:assertions=0
function Assert-Calibration([bool]$Condition,[string]$Message){$script:assertions++;if(!$Condition){throw "ASSERTION_FAILED: $Message"}}

function New-CalibrationContracts([string]$Task='Analyze the bounded fixture and return a substantive answer.'){
    $intent=New-TsfOriginalOperatorIntentContract -NaturalRequest $Task -PreviewId 'hq-preview-11111111111111111111111111111111' -RepositoryTarget $root -WorktreeTarget $root
    $ops=@((Get-TsfOriginalOperationAnalysis $Task).requested_operations)
    $scope=New-TsfScopeTransformationContract -OriginalIntent $intent -AuthorizedMissionGoal $Task -ProposedOperations $ops -ProposedAccess ([string]$intent.requested_access) -RepositoryTarget $root -WorktreeTarget $root
    $completion=New-TsfTaskCompletionContract -RequiredTask $Task -OriginalIntent $intent -ScopeTransformation $scope
    [pscustomobject]@{intent=$intent;scope=$scope;completion=$completion}
}

function New-CalibrationClaim {
    param(
        [Parameter(Mandatory)][object]$Contracts,
        [string]$Disposition='FULFILLED',
        [string]$BlockedReason='NONE',
        [bool]$TaskAttempted=$true,
        [bool]$TaskCompleted=$true,
        [string]$Answer='The bounded fixture analysis is complete and supplies the requested substantive result.',
        [string[]]$Completed=@('requested_answer'),
        [string[]]$Missing=@(),
        [string[]]$Caveats=@(),
        [string]$AttemptedTaskSha256=''
    )
    if([string]::IsNullOrWhiteSpace($AttemptedTaskSha256)){$AttemptedTaskSha256=[string]$Contracts.completion.required_task_sha256}
    [pscustomobject][ordered]@{
        schema_version='tsf_worker_outcome_claim_v2';mission_id='calibration-mission';mission_revision=1;run_id='canonical-result-calibration-1'
        task_completion_contract_identity_sha256=[string]$Contracts.completion.task_completion_contract_identity_sha256
        original_intent_identity_sha256=[string]$Contracts.completion.original_intent_identity_sha256
        scope_transformation_identity_sha256=[string]$Contracts.completion.scope_transformation_identity_sha256
        attempted_task_sha256=$AttemptedTaskSha256;task_attempted=$TaskAttempted;task_completed=$TaskCompleted
        outcome_disposition=$Disposition;completed_deliverables=@($Completed);missing_deliverables=@($Missing);blocked_reason=$BlockedReason
        substantive_answer=$Answer;evidence=@('fixture/source.txt#bounded-evidence');caveats=@($Caveats)
    }
}

function Get-CalibrationEvidence([object]$Contracts,[object]$Claim){
    $adapter=[pscustomobject]@{transport_success=$true;final_response=($Claim|ConvertTo-Json -Compress -Depth 30)}
    Get-TsfGeneralResultV2Evidence -MissionId 'calibration-mission' -MissionRevision 1 -RunId 'canonical-result-calibration-1' -Adapter $adapter -TaskCompletionContract $Contracts.completion
}

function Test-CalibrationAdmission([object]$Contracts,[object]$Evidence){
    $mission=[pscustomobject]@{result_validation_mode='GENERAL_RESULT_V2';task_completion_contract=$Contracts.completion}
    $result=[pscustomobject]@{
        result_validation_mode='GENERAL_RESULT_V2';mission_id=$Evidence.mission_id;mission_revision=$Evidence.mission_revision;result_id=$Evidence.result_id
        original_intent_identity_sha256=$Evidence.original_intent_identity_sha256;scope_transformation_identity_sha256=$Evidence.scope_transformation_identity_sha256;task_completion_contract_identity_sha256=$Evidence.task_completion_contract_identity_sha256
        transport_status=$Evidence.transport_status;semantic_status=$Evidence.semantic_status;outcome_disposition=$Evidence.outcome_disposition;worker_claim=$Evidence.worker_claim
        observed_deliverables=@($Evidence.observed_deliverables);missing_deliverables=@($Evidence.missing_deliverables);outcome_evidence=@($Evidence.outcome_evidence);raw_worker_response_sha256=$Evidence.raw_worker_response_sha256
    }
    Test-TsfGeneralResultV2AdmissionEvidence -Mission $mission -Result $result
}

$corpus=Get-Content -Raw -LiteralPath (Join-Path $root 'tests\fixtures\fleet\semantic-outcome\semantic-outcome-corpus.v1.json')|ConvertFrom-Json
$acceptanceSource=Get-Content -Raw -LiteralPath (Join-Path $root 'tests\run-tsf-v1-final-acceptance-v1.ps1')
Assert-Calibration ($acceptanceSource -match 'run-tsf-semantic-outcome-targeted-soak-v3') 'Final acceptance protected-path allowlist includes the semantic outcome targeted soak runner.'
$lifecycleSource=Get-Content -Raw -LiteralPath (Join-Path $root 'tools\Invoke-TsfMissionLifecycle.ps1')
Assert-Calibration ($lifecycleSource -match 'evidence must be a JSON array of strings' -and $lifecycleSource -match 'caveats must be a JSON array of strings') 'Live worker prompt states closed evidence and caveat array types.'
Assert-Calibration ([string]$corpus.schema_version-eq'tsf_semantic_outcome_corpus_v1') 'Corpus version is closed.'
$contracts=New-CalibrationContracts
Assert-Calibration ([string]$contracts.completion.schema_version-eq'tsf_task_completion_contract_v2') 'New missions use task completion contract V2.'
Assert-Calibration ([string]$contracts.completion.result_contract_class-eq'STRUCTURAL_TEXT_ONLY') 'Generic text missions are selected as structural-only.'
Assert-Calibration ([string]$contracts.completion.admission_eligibility-eq'INFORMATIONAL_NON_ADMISSIBLE') 'Generic text missions are visibly non-admissible before execution.'
Assert-Calibration ([bool]$contracts.completion.operator_confirmation_required) 'Generic informational mission submission requires explicit operator confirmation.'
Assert-Calibration ((Test-TsfJsonContract $contracts.completion (Join-Path $root 'fleet\control\task-completion-contract.schema.v2.json')).valid) 'V2 task contract validates.'

foreach($case in @($corpus.worker_own_non_success)){
    $claim=New-CalibrationClaim -Contracts $contracts -Disposition ([string]$case.disposition) -BlockedReason ([string]$case.blocked_reason) -TaskCompleted:$false -Answer ([string]$case.answer) -Completed @() -Missing @('requested_answer')
    $evidence=Get-CalibrationEvidence $contracts $claim
    Assert-Calibration ([string]$evidence.transport_status-eq'SUCCEEDED') "$($case.id) preserves successful transport."
    Assert-Calibration (!$evidence.semantic_success-and!$evidence.admissible) "$($case.id) cannot become semantic fulfillment."
    Assert-Calibration ([string]$evidence.semantic_status-eq'NOT_FULFILLED') "$($case.id) remains unfulfilled."
    Assert-Calibration (!(Test-CalibrationAdmission $contracts $evidence).valid) "$($case.id) cannot pass admission evidence."
}

foreach($case in @($corpus.fulfilled_subject_matter)){
    $claim=New-CalibrationClaim -Contracts $contracts -Answer ([string]$case.answer)
    $evidence=Get-CalibrationEvidence $contracts $claim
    Assert-Calibration (!$evidence.semantic_success-and!$evidence.admissible) "$($case.id) generic prose cannot establish fulfillment."
    Assert-Calibration ([string]$evidence.compatibility_mode-eq'STRUCTURAL_TEXT_ONLY_V2') "$($case.id) is classified structurally without phrase scanning."
    Assert-Calibration ([string]$evidence.outcome_disposition-eq'UNCLASSIFIED_RESULT') "$($case.id) affirmative generic text uses the one existing unclassified disposition."
    Assert-Calibration ($evidence.outcome_evidence-contains'GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE') "$($case.id) has the exact structural non-admission reason."
    Assert-Calibration (!(Test-CalibrationAdmission $contracts $evidence).valid) "$($case.id) cannot pass admission evidence."
}

$inconsistent=New-CalibrationClaim -Contracts $contracts -TaskCompleted:$false -BlockedReason 'TASK_INCOMPLETE'
$inconsistentEvidence=Get-CalibrationEvidence $contracts $inconsistent
Assert-Calibration (!$inconsistentEvidence.semantic_success-and[string]$inconsistentEvidence.outcome_disposition-eq'UNCLASSIFIED_RESULT') 'Fulfilled disposition with worker-own incompletion fails closed.'

$missingClaim=New-CalibrationClaim -Contracts $contracts -Answer '' -Completed @() -Missing @('requested_answer')
$missingEvidence=Get-CalibrationEvidence $contracts $missingClaim
Assert-Calibration (!$missingEvidence.semantic_success-and[string]$missingEvidence.outcome_disposition-eq'REQUIRED_DELIVERABLE_MISSING') 'Generic claim with absent content remains mechanically required-deliverable-missing.'

$partialAll=New-CalibrationClaim -Contracts $contracts -Disposition 'PARTIAL' -BlockedReason 'TASK_INCOMPLETE' -TaskCompleted:$false
$partialAllEvidence=Get-CalibrationEvidence $contracts $partialAll
Assert-Calibration (!$partialAllEvidence.semantic_success-and$partialAllEvidence.outcome_evidence-contains'PARTIAL_HAS_ALL_DELIVERABLES') 'Partial claim with all deliverables fails closed.'

$wrongTask=New-CalibrationClaim -Contracts $contracts -AttemptedTaskSha256 ('f'*64)
$wrongTaskEvidence=Get-CalibrationEvidence $contracts $wrongTask
Assert-Calibration (!$wrongTaskEvidence.semantic_success-and[string]$wrongTaskEvidence.outcome_disposition-eq'WRONG_TASK_PERFORMED') 'Wrong-task substitution is rejected.'

$legacyClaim=[pscustomobject][ordered]@{schema_version='tsf_worker_outcome_claim_v1';mission_id='calibration-mission';mission_revision=1;run_id='canonical-result-calibration-1';task_completion_contract_identity_sha256=[string]$contracts.completion.task_completion_contract_identity_sha256;original_intent_identity_sha256=[string]$contracts.completion.original_intent_identity_sha256;scope_transformation_identity_sha256=[string]$contracts.completion.scope_transformation_identity_sha256;attempted_task_sha256=[string]$contracts.completion.required_task_sha256;outcome_disposition='FULFILLED';completed_deliverables=@('requested_answer');missing_deliverables=@();answer='A nonempty legacy answer cannot admit.';evidence=@('legacy');caveats=@()}
$legacyEvidence=Get-CalibrationEvidence $contracts $legacyClaim
Assert-Calibration (!$legacyEvidence.semantic_success-and[string]$legacyEvidence.compatibility_mode-eq'LEGACY_STRUCTURED_CLAIM_V1_FAIL_CLOSED') 'V1 structured claims remain readable but fail closed for new admission.'

$legacyFreeformAdapter=[pscustomobject]@{transport_success=$true;final_response='A prior actor could not comply, but this text has no structured status segment.'}
$legacyFreeform=Get-TsfGeneralResultV2Evidence -MissionId 'calibration-mission' -MissionRevision 1 -RunId 'canonical-result-calibration-1' -Adapter $legacyFreeformAdapter -TaskCompletionContract $null
Assert-Calibration (!$legacyFreeform.semantic_success-and[string]$legacyFreeform.outcome_disposition-eq'UNCLASSIFIED_RESULT') 'Nonempty freeform legacy output is never scanned into outcome authority.'

$analysisTask='Analyze the bounded fixture and return summary, findings, evidence references, and limitations.'
$analysisContracts=New-CalibrationContracts $analysisTask
Assert-Calibration ([string]$analysisContracts.completion.deliverable_profile-eq'STRUCTURED_ANALYSIS_V2') 'Explicit analysis fixture selects structured deliverables.'
Assert-Calibration ([string]$analysisContracts.completion.result_contract_class-eq'STRUCTURED_DETERMINISTIC') 'Explicit analysis fixture selects deterministic structured admission.'
Assert-Calibration ([string]$analysisContracts.completion.admission_eligibility-eq'ADMISSIBLE_WHEN_VERIFIED') 'Structured analysis is eligible only after verification.'
Assert-Calibration (!$analysisContracts.completion.operator_confirmation_required) 'Structured admissible contract needs no informational-only confirmation.'
$analysisIds=@($analysisContracts.completion.required_deliverables|ForEach-Object{[string]$_.deliverable_id})
$analysisContent=[pscustomobject][ordered]@{
    summary='The completed analysis separates prior inability statements from the current worker outcome.'
    findings=@('The prior system could not validate input.','A verifier cannot trust caller-controlled status.','Workers must not deploy without authority.')
    evidence_references=@('fixture/source.txt#history','fixture/policy.json#authority')
    limitations='The fixture is bounded to deterministic local evidence.'
}
$analysisClaim=New-CalibrationClaim -Contracts $analysisContracts -Answer ($analysisContent|ConvertTo-Json -Compress -Depth 10) -Completed $analysisIds -Missing @()
$analysisEvidence=Get-CalibrationEvidence $analysisContracts $analysisClaim
Assert-Calibration ($analysisEvidence.semantic_success-and@($analysisEvidence.observed_deliverables).Count-eq4) 'Structured analysis passes type, cardinality, structure, and evidence checks despite normative inability prose.'
Assert-Calibration ((Test-CalibrationAdmission $analysisContracts $analysisEvidence).valid) 'Structured analysis passes independent admission evidence.'
Assert-Calibration ((Test-TsfJsonContract $analysisEvidence (Join-Path $root 'fleet\control\general-result-v2.schema.v1.json')).valid) 'Structured general-result evidence validates against its schema.'

$missingAnalysisContent=$analysisContent|ConvertTo-Json -Depth 10|ConvertFrom-Json
$missingAnalysisContent.PSObject.Properties.Remove('evidence_references')
$missingAnalysisClaim=New-CalibrationClaim -Contracts $analysisContracts -Disposition 'REQUIRED_DELIVERABLE_MISSING' -BlockedReason 'REQUIRED_DELIVERABLE_MISSING' -TaskCompleted:$false -Answer ($missingAnalysisContent|ConvertTo-Json -Compress -Depth 10) -Completed @('summary','findings','limitations') -Missing @('evidence_references')
$missingAnalysisEvidence=Get-CalibrationEvidence $analysisContracts $missingAnalysisClaim
Assert-Calibration (!$missingAnalysisEvidence.semantic_success-and@($missingAnalysisEvidence.missing_deliverables)-contains'evidence_references') 'Structured analysis missing evidence references cannot admit.'

$oversizedAnswer=New-CalibrationClaim -Contracts $contracts -Answer ('x'*50001)
$oversizedAnswerEvidence=Get-CalibrationEvidence $contracts $oversizedAnswer
Assert-Calibration (!$oversizedAnswerEvidence.semantic_success-and$oversizedAnswerEvidence.outcome_evidence-contains'DELIVERABLE_CONTENT_INVALID:requested_answer') 'Substantive answer content is bounded.'
$oversizedEvidence=New-CalibrationClaim -Contracts $contracts
$oversizedEvidence.evidence=@('e'*2001)
$oversizedEvidenceResult=Get-CalibrationEvidence $contracts $oversizedEvidence
Assert-Calibration (!$oversizedEvidenceResult.semantic_success-and$oversizedEvidenceResult.outcome_evidence-contains'EVIDENCE_REFERENCES_OUT_OF_BOUNDS') 'Evidence references are bounded.'

$uiSource=Get-Content -Raw -LiteralPath (Join-Path $root 'tools\hq-dispatch\v1\public\app.js')
Assert-Calibration ($uiSource.Contains('fulfilled_label_requires_verifier_green_and_admission: true')) 'UI requires verifier and admission before fulfilled presentation.'
Assert-Calibration ($uiSource.Contains('worker_claim_is_not_verifier_or_admission_authority: true')) 'UI identifies the worker claim as non-authoritative.'
Assert-Calibration ($uiSource.Contains('Response received. Task fulfillment could not be independently verified from this result contract. The response was preserved but not admitted.')) 'UI contains the exact generic-text operator truth.'
Assert-Calibration ($uiSource.Contains('GENERIC_TEXT_RECEIVED_FULFILLMENT_UNVERIFIED')) 'UI has a non-green generic structural-only outcome.'

"TSF_SEMANTIC_OUTCOME_CALIBRATION_PASS assertions=$script:assertions"
