[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'tools\TsfJsonContract.ps1')
Import-Module (Join-Path $root 'tools\TsfDurableContract.psm1') -Force
. (Join-Path $root 'tools\TsfSemanticIntegrity.ps1')

$script:assertions = 0
function Assert-Policy([bool]$Condition,[string]$Message) {
    $script:assertions++
    if (!$Condition) { throw "ASSERTION_FAILED: $Message" }
}
function Copy-PolicyObject([object]$Value) { $Value | ConvertTo-Json -Depth 40 | ConvertFrom-Json }
function New-PolicyContracts([string]$Task) {
    $previewId = 'hq-preview-' + (Get-TsfContractJsonHash ([pscustomobject]@{ task = $Task })).Substring(0,32)
    $intent = New-TsfOriginalOperatorIntentContract -NaturalRequest $Task -PreviewId $previewId -RepositoryTarget $root -WorktreeTarget $root
    $operations = @((Get-TsfOriginalOperationAnalysis $Task).requested_operations)
    $scope = New-TsfScopeTransformationContract -OriginalIntent $intent -AuthorizedMissionGoal $Task -ProposedOperations $operations -ProposedAccess ([string]$intent.requested_access) -RepositoryTarget $root -WorktreeTarget $root
    $completion = New-TsfTaskCompletionContract -RequiredTask $Task -OriginalIntent $intent -ScopeTransformation $scope
    [pscustomobject]@{ intent=$intent;scope=$scope;completion=$completion }
}
function New-PolicyClaim {
    param(
        [Parameter(Mandatory)][object]$Contracts,
        [Parameter(Mandatory)][string]$MissionId,
        [Parameter(Mandatory)][string]$RunId,
        [string]$Disposition='FULFILLED',
        [string]$BlockedReason='NONE',
        [bool]$TaskAttempted=$true,
        [bool]$TaskCompleted=$true,
        [string]$Answer='',
        [string[]]$Completed=@(),
        [string[]]$Missing=@(),
        [string]$AttemptedTaskSha256=''
    )
    if ([string]::IsNullOrWhiteSpace($AttemptedTaskSha256)) { $AttemptedTaskSha256=[string]$Contracts.completion.required_task_sha256 }
    [pscustomobject][ordered]@{
        schema_version='tsf_worker_outcome_claim_v2';mission_id=$MissionId;mission_revision=1;run_id=$RunId
        task_completion_contract_identity_sha256=[string]$Contracts.completion.task_completion_contract_identity_sha256
        original_intent_identity_sha256=[string]$Contracts.completion.original_intent_identity_sha256
        scope_transformation_identity_sha256=[string]$Contracts.completion.scope_transformation_identity_sha256
        attempted_task_sha256=$AttemptedTaskSha256;task_attempted=$TaskAttempted;task_completed=$TaskCompleted
        outcome_disposition=$Disposition;completed_deliverables=@($Completed);missing_deliverables=@($Missing);blocked_reason=$BlockedReason
        substantive_answer=$Answer;evidence=@('fixture/policy.txt#bounded');caveats=@()
    }
}
function Get-PolicyEvidence([object]$Contracts,[object]$Claim,[bool]$Transport=$true) {
    $adapter=[pscustomobject]@{transport_success=$Transport;final_response=($Claim|ConvertTo-Json -Compress -Depth 40)}
    Get-TsfGeneralResultV2Evidence -MissionId ([string]$Claim.mission_id) -MissionRevision 1 -RunId ([string]$Claim.run_id) -Adapter $adapter -TaskCompletionContract $Contracts.completion
}
function Test-PolicyAdmission([object]$Contracts,[object]$Evidence) {
    $mission=[pscustomobject]@{result_validation_mode='GENERAL_RESULT_V2';task_completion_contract=$Contracts.completion}
    $result=[pscustomobject]@{
        result_validation_mode='GENERAL_RESULT_V2';mission_id=$Evidence.mission_id;mission_revision=$Evidence.mission_revision;result_id=$Evidence.result_id
        original_intent_identity_sha256=$Evidence.original_intent_identity_sha256;scope_transformation_identity_sha256=$Evidence.scope_transformation_identity_sha256;task_completion_contract_identity_sha256=$Evidence.task_completion_contract_identity_sha256
        transport_status=$Evidence.transport_status;semantic_status=$Evidence.semantic_status;outcome_disposition=$Evidence.outcome_disposition;worker_claim=$Evidence.worker_claim
        observed_deliverables=@($Evidence.observed_deliverables);missing_deliverables=@($Evidence.missing_deliverables);outcome_evidence=@($Evidence.outcome_evidence);raw_worker_response_sha256=$Evidence.raw_worker_response_sha256
    }
    Test-TsfGeneralResultV2AdmissionEvidence -Mission $mission -Result $result
}

$genericTask='Explain the bounded fixture in a concise response.'
$generic=New-PolicyContracts $genericTask
Assert-Policy ([string]$generic.completion.deliverable_profile-eq'TEXT_RESPONSE_V2') 'Generic task selects TEXT_RESPONSE_V2.'
Assert-Policy ([string]$generic.completion.result_contract_class-eq'STRUCTURAL_TEXT_ONLY') 'Generic task is structural-only.'
Assert-Policy ([string]$generic.completion.admission_eligibility-eq'INFORMATIONAL_NON_ADMISSIBLE') 'Generic task is informational and non-admissible.'
Assert-Policy ([bool]$generic.completion.operator_confirmation_required) 'Generic task requires pre-submission informational confirmation.'
Assert-Policy ([string]$generic.completion.non_admission_reason-eq'GENERIC_TEXT_REQUIRES_PROSE_INTERPRETATION') 'Generic reason is closed.'
Assert-Policy ((Test-TsfJsonContract $generic.completion (Join-Path $root 'fleet\control\task-completion-contract.schema.v2.json')).valid) 'Generic contract validates.'

$genericMission='structured-policy-generic-0001'
$genericRun='canonical-result-structured-policy-generic-0001-1'
$excellent='The bounded fixture is fully analyzed. Its three controls are identity binding, independent verification, and separate admission. The evidence is complete and the requested explanation is supplied.'
$excellentClaim=New-PolicyClaim $generic $genericMission $genericRun -Answer $excellent -Completed @('requested_answer')
$excellentEvidence=Get-PolicyEvidence $generic $excellentClaim
Assert-Policy ([string]$excellentEvidence.transport_status-eq'SUCCEEDED') 'Excellent generic prose preserves transport success.'
Assert-Policy ([string]$excellentEvidence.compatibility_mode-eq'STRUCTURAL_TEXT_ONLY_V2') 'Excellent generic prose has structural-only classification.'
Assert-Policy ([string]$excellentEvidence.outcome_disposition-eq'UNCLASSIFIED_RESULT') 'Affirmative generic prose uses the existing unclassified disposition.'
Assert-Policy (!$excellentEvidence.semantic_success-and!$excellentEvidence.admissible) 'Excellent generic prose cannot establish fulfillment.'
Assert-Policy ($excellentEvidence.outcome_evidence-contains'GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE') 'Excellent generic prose has deterministic non-admission evidence.'
Assert-Policy (@($excellentEvidence.observed_deliverables)-contains'requested_answer') 'Excellent generic response remains structurally observable.'
Assert-Policy (!(Test-PolicyAdmission $generic $excellentEvidence).valid) 'Excellent generic prose cannot pass admission.'
Assert-Policy ((Test-TsfJsonContract $excellentEvidence (Join-Path $root 'fleet\control\general-result-v2.schema.v1.json')).valid) 'Structural-only generic result evidence validates against its governing closed schema.'

$inabilityClaim=New-PolicyClaim $generic $genericMission $genericRun -Answer "I couldn't complete the requested task." -Completed @('requested_answer')
$inabilityEvidence=Get-PolicyEvidence $generic $inabilityClaim
Assert-Policy ([string]$inabilityEvidence.transport_status-eq'SUCCEEDED') 'Generic inability prose is preserved.'
Assert-Policy ([string]$inabilityEvidence.outcome_disposition-eq'UNCLASSIFIED_RESULT') 'FULFILLED plus inability prose is not phrase-scanned into worker failure.'
Assert-Policy (!$inabilityEvidence.semantic_success-and!(Test-PolicyAdmission $generic $inabilityEvidence).valid) 'Generic inability prose cannot admit.'

$historyText='The prior service cannot validate old input, an operator was unable to continue, the run failed, a policy says workers must not deploy, and the archive remained incomplete and blocked.'
$historyClaim=New-PolicyClaim $generic $genericMission $genericRun -Answer $historyText -Completed @('requested_answer')
$historyEvidence=Get-PolicyEvidence $generic $historyClaim
Assert-Policy ([string]$historyEvidence.outcome_disposition-eq'UNCLASSIFIED_RESULT') 'Historical inability language does not infer current worker failure.'
Assert-Policy (@($historyEvidence.outcome_evidence).Count-eq1-and$historyEvidence.outcome_evidence[0]-eq'GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE') 'Historical generic result fails only on contract class, not phrases.'
Assert-Policy (!$historyEvidence.semantic_success-and!(Test-PolicyAdmission $generic $historyEvidence).valid) 'Historical generic analysis remains informational.'

$workerUnable=New-PolicyClaim $generic $genericMission $genericRun -Disposition 'UNABLE_TO_PERFORM' -BlockedReason 'TASK_INCOMPLETE' -TaskCompleted:$false -Answer 'The worker reports a bounded inability.' -Completed @() -Missing @('requested_answer')
$workerUnableEvidence=Get-PolicyEvidence $generic $workerUnable
Assert-Policy ([string]$workerUnableEvidence.outcome_disposition-eq'UNABLE_TO_PERFORM') 'Closed worker inability remains distinguishable from subject matter.'
Assert-Policy (!$workerUnableEvidence.semantic_success-and!(Test-PolicyAdmission $generic $workerUnableEvidence).valid) 'Closed worker inability cannot admit.'

$structuredTask='Analyze the bounded historical fixture and return a summary, at least three findings, evidence references, and limitations.'
$structured=New-PolicyContracts $structuredTask
$structuredIds=@($structured.completion.required_deliverables|ForEach-Object{[string]$_.deliverable_id}|Sort-Object)
Assert-Policy ([string]$structured.completion.deliverable_profile-eq'STRUCTURED_ANALYSIS_V2') 'Analytical mission selects structured profile.'
Assert-Policy ([string]$structured.completion.result_contract_class-eq'STRUCTURED_DETERMINISTIC') 'Analytical mission selects deterministic structure.'
Assert-Policy ([string]$structured.completion.admission_eligibility-eq'ADMISSIBLE_WHEN_VERIFIED') 'Structured result is eligible only when verified.'
Assert-Policy (!$structured.completion.operator_confirmation_required) 'Structured result does not require informational-only confirmation.'
Assert-Policy ((Test-TsfJsonContract $structured.completion (Join-Path $root 'fleet\control\task-completion-contract.schema.v2.json')).valid) 'Structured contract validates.'

$structuredMission='structured-policy-analysis-0001'
$structuredRun='canonical-result-structured-policy-analysis-0001-1'
$structuredAnswer=([pscustomobject][ordered]@{
    summary='The historical record says an earlier service could not validate input; this completed analysis separates that subject matter from current status.'
    findings=@('A prior operator was unable to continue.','Policy says a worker must not deploy.','The historical run failed and remained incomplete, but those quotations are not current worker status.')
    evidence_references=@('fixture/history.txt#S1','fixture/policy.txt#S2')
    limitations='This analysis is bounded to deterministic local fixture text.'
}|ConvertTo-Json -Compress -Depth 10)
$structuredClaim=New-PolicyClaim $structured $structuredMission $structuredRun -Answer $structuredAnswer -Completed $structuredIds
$structuredEvidence=Get-PolicyEvidence $structured $structuredClaim
Assert-Policy $structuredEvidence.semantic_success 'Valid structured historical analysis establishes semantic fulfillment.'
Assert-Policy $structuredEvidence.admissible 'Valid structured historical analysis is eligible for admission.'
Assert-Policy ([string]$structuredEvidence.outcome_disposition-eq'FULFILLED') 'Valid structured status is preserved.'
Assert-Policy (@($structuredEvidence.observed_deliverables).Count-eq4-and@($structuredEvidence.missing_deliverables).Count-eq0) 'All structured deliverables are independently observed.'
Assert-Policy (@($structuredEvidence.outcome_evidence).Count-eq0) 'Historical inability phrases create no outcome errors.'
Assert-Policy ((Test-PolicyAdmission $structured $structuredEvidence).valid) 'Independent admission recomputation accepts valid structured analysis.'
Assert-Policy ((Test-TsfJsonContract $structuredEvidence (Join-Path $root 'fleet\control\general-result-v2.schema.v1.json')).valid) 'Structured result evidence validates.'

$structuredUnable=New-PolicyClaim $structured $structuredMission $structuredRun -Disposition 'UNABLE_TO_PERFORM' -BlockedReason 'TASK_INCOMPLETE' -TaskCompleted:$false -Answer $structuredAnswer -Completed $structuredIds
$structuredUnableEvidence=Get-PolicyEvidence $structured $structuredUnable
Assert-Policy (!$structuredUnableEvidence.semantic_success-and[string]$structuredUnableEvidence.outcome_disposition-eq'UNABLE_TO_PERFORM') 'Structured worker inability is not fulfillment even with substantive content.'
Assert-Policy (!(Test-PolicyAdmission $structured $structuredUnableEvidence).valid) 'Structured worker inability cannot admit.'

$missingAnswer=([pscustomobject][ordered]@{summary='A bounded partial analysis.';findings=@('First finding.','Second finding.','Third finding.');limitations='Evidence references are absent.'}|ConvertTo-Json -Compress -Depth 10)
$missingClaim=New-PolicyClaim $structured $structuredMission $structuredRun -Disposition 'REQUIRED_DELIVERABLE_MISSING' -BlockedReason 'REQUIRED_DELIVERABLE_MISSING' -TaskCompleted:$false -Answer $missingAnswer -Completed @('findings','limitations','summary') -Missing @('evidence_references')
$missingEvidence=Get-PolicyEvidence $structured $missingClaim
Assert-Policy (!$missingEvidence.semantic_success-and@($missingEvidence.missing_deliverables)-contains'evidence_references') 'Missing structured deliverable is deterministic.'
Assert-Policy (!(Test-PolicyAdmission $structured $missingEvidence).valid) 'Missing structured deliverable cannot admit.'

$contradictory=New-PolicyClaim $structured $structuredMission $structuredRun -Answer $structuredAnswer -Completed @('findings','limitations','summary') -Missing @('evidence_references')
$contradictoryEvidence=Get-PolicyEvidence $structured $contradictory
Assert-Policy (!$contradictoryEvidence.semantic_success) 'Contradictory fulfilled structured claim fails closed.'
Assert-Policy ($contradictoryEvidence.outcome_evidence-contains'WORKER_CLAIM_DELIVERABLE_MISMATCH') 'Contradictory structured claim has mechanical mismatch evidence.'
Assert-Policy (!(Test-PolicyAdmission $structured $contradictoryEvidence).valid) 'Contradictory structured result cannot admit.'

foreach($case in @(
    [pscustomobject]@{name='cross-mission';field='mission_id';value='structured-policy-other-0001';error='WORKER_CLAIM_IDENTITY_MISMATCH'},
    [pscustomobject]@{name='cross-revision';field='mission_revision';value=2;error='WORKER_CLAIM_IDENTITY_MISMATCH'},
    [pscustomobject]@{name='cross-run';field='run_id';value='canonical-result-structured-policy-other-0001-1';error='WORKER_CLAIM_IDENTITY_MISMATCH'},
    [pscustomobject]@{name='wrong-task';field='attempted_task_sha256';value=('f'*64);error='WRONG_TASK_PERFORMED'}
)) {
    $forged=Copy-PolicyObject $structuredClaim
    $forged.($case.field)=$case.value
    $forgedAdapter=[pscustomobject]@{transport_success=$true;final_response=($forged|ConvertTo-Json -Compress -Depth 40)}
    $forgedEvidence=Get-TsfGeneralResultV2Evidence -MissionId $structuredMission -MissionRevision 1 -RunId $structuredRun -Adapter $forgedAdapter -TaskCompletionContract $structured.completion
    Assert-Policy (!$forgedEvidence.semantic_success) "$($case.name) cannot establish structured fulfillment."
    Assert-Policy ($forgedEvidence.outcome_evidence-contains$case.error) "$($case.name) has identity evidence."
    Assert-Policy (!(Test-PolicyAdmission $structured $forgedEvidence).valid) "$($case.name) cannot admit."
}

$contractSubstitution=Copy-PolicyObject $structured.completion
$contractSubstitution.result_contract_class='STRUCTURAL_TEXT_ONLY'
$contractSubstitution.admission_eligibility='INFORMATIONAL_NON_ADMISSIBLE'
$contractSubstitution.operator_confirmation_required=$true
$contractSubstitution.non_admission_reason='GENERIC_TEXT_REQUIRES_PROSE_INTERPRETATION'
$contractSubstitutionProjection=Copy-PolicyObject $contractSubstitution
$contractSubstitutionProjection.PSObject.Properties.Remove('task_completion_contract_identity_sha256')
Assert-Policy ((Get-TsfContractJsonHash $contractSubstitutionProjection)-ne[string]$structured.completion.task_completion_contract_identity_sha256) 'Result-contract class substitution changes the bound contract identity.'
$substitutedContracts=[pscustomobject]@{intent=$structured.intent;scope=$structured.scope;completion=$contractSubstitution}
$substitutedEvidence=Get-PolicyEvidence $substitutedContracts $structuredClaim
Assert-Policy (!$substitutedEvidence.semantic_success-and!$substitutedEvidence.admissible) 'Result-contract substitution cannot admit.'

$callerAuthority=Copy-PolicyObject $structuredClaim
$callerAuthority|Add-Member verifier_green $true
$callerAuthorityEvidence=Get-PolicyEvidence $structured $callerAuthority
Assert-Policy (!$callerAuthorityEvidence.semantic_success-and$callerAuthorityEvidence.outcome_evidence-contains'WORKER_CLAIM_NOT_CLOSED') 'Caller-supplied verifier authority is rejected.'

$legacy=Get-TsfGeneralResultV2Evidence -MissionId $genericMission -MissionRevision 1 -RunId $genericRun -Adapter ([pscustomobject]@{transport_success=$true;final_response=$historyText}) -TaskCompletionContract $null
Assert-Policy ([string]$legacy.compatibility_mode-eq'LEGACY_FAIL_CLOSED_V1') 'Legacy response remains readable under its historical compatibility mode.'
Assert-Policy ([string]$legacy.outcome_disposition-eq'UNCLASSIFIED_RESULT'-and!$legacy.semantic_success-and!$legacy.admissible) 'Legacy generic prose cannot gain admission on replay.'

$exactRequest='Return exactly TSF_STRUCTURED_POLICY_GREEN.'
$exact=New-TsfExactResponseContract -NaturalRequest $exactRequest -PreviewId 'hq-preview-11111111111111111111111111111111'
Assert-Policy ($null-ne$exact-and[string]$exact.expected_literal-eq'TSF_STRUCTURED_POLICY_GREEN') 'Exact literal contract selection is unchanged.'
Assert-Policy ((Test-TsfExactResponseContract -Contract $exact -NaturalRequest $exactRequest -PreviewId 'hq-preview-11111111111111111111111111111111').valid) 'Exact literal independent recomputation remains valid.'
$exactMismatch=Copy-PolicyObject $exact
$exactMismatch.expected_literal='TSF_STRUCTURED_POLICY_RED'
Assert-Policy (!(Test-TsfExactResponseContract -Contract $exactMismatch -NaturalRequest $exactRequest -PreviewId 'hq-preview-11111111111111111111111111111111').valid) 'Exact literal mismatch remains rejected.'

$writeRequest='Edit the configuration file and commit the change.'
$writeIntent=New-TsfOriginalOperatorIntentContract -NaturalRequest $writeRequest -PreviewId 'hq-preview-22222222222222222222222222222222' -RepositoryTarget $root -WorktreeTarget $root
$reducedScope=New-TsfScopeTransformationContract -OriginalIntent $writeIntent -AuthorizedMissionGoal 'Inspect the configuration file.' -ProposedOperations @('READ_ANALYSIS','RETURN_RESULT') -ProposedAccess 'READ_ONLY' -RepositoryTarget $root -WorktreeTarget $root -DetachedHead:$true
Assert-Policy (!$reducedScope.queue_allowed-and$reducedScope.operator_confirmation_required) 'Detached write/commit request remains blocked before queueing.'
Assert-Policy ([string]$reducedScope.classification-eq'AUTHORITY_REDUCTION_REQUIRES_OPERATOR_CONFIRMATION') 'Material scope reduction remains explicit.'

$routeSource=Get-Content -Raw -LiteralPath (Join-Path $root 'tools\hq-dispatch\v1\Invoke-TsfHqDispatchRoutePreview.ps1')
$missionSource=Get-Content -Raw -LiteralPath (Join-Path $root 'tools\hq-dispatch\v1\New-TsfHqDispatchGovernedMission.ps1')
$relaySource=Get-Content -Raw -LiteralPath (Join-Path $root 'tools\hq-dispatch\v1\mission-relay.mjs')
$lifecycleSource=Get-Content -Raw -LiteralPath (Join-Path $root 'tools\Invoke-TsfMissionLifecycle.ps1')
$uiSource=Get-Content -Raw -LiteralPath (Join-Path $root 'tools\hq-dispatch\v1\public\app.js')
Assert-Policy ($routeSource.Contains('result_contract_selection = $resultContractSelection')) 'Preview exposes result-contract selection before queueing.'
Assert-Policy ($missionSource.Contains('HQ_SUBMISSION_RESULT_CONTRACT_CONFIRMATION_REQUIRED_OR_CHANGED')) 'Mission preparation revalidates informational confirmation.'
Assert-Policy ($missionSource.Contains('HQ_SUBMISSION_TASK_COMPLETION_CONTRACT_CHANGED')) 'Mission preparation independently recomputes task contract.'
Assert-Policy ($relaySource.Contains('RESULT_CONTRACT_CONFIRMATION_REQUIRED_OR_CHANGED')) 'Relay rejects missing or changed material confirmation.'
Assert-Policy ($relaySource.Contains('RECOMPUTED_PREVIEW_MISMATCH')) 'Relay rejects stale or substituted contract selection.'
Assert-Policy ($lifecycleSource.Contains('This TEXT_RESPONSE_V2 contract is structural-only and informational')) 'Worker prompt tells generic workers the result is informational.'
Assert-Policy ($uiSource.Contains('GENERIC_TEXT_RECEIVED_FULFILLMENT_UNVERIFIED')) 'UI has a dedicated generic text state.'
Assert-Policy ($uiSource.Contains('Response received. Task fulfillment could not be independently verified from this result contract. The response was preserved but not admitted.')) 'UI states preservation without admission.'
Assert-Policy (!$uiSource.Contains('generic_text_is_fulfilled: true')) 'UI contains no generic fulfillment shortcut.'

"TSF_STRUCTURED_FULFILLMENT_POLICY_PASS assertions=$script:assertions"
