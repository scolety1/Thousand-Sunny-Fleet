[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'tools\codex-fleet-enforcement-kernel.ps1')

$fixtureRoot=Join-Path $root '.codex-local\fixtures\general-result-kernel-verifier-v1'
if(Test-Path $fixtureRoot){Remove-Item -LiteralPath $fixtureRoot -Recurse -Force}
New-Item -ItemType Directory -Path $fixtureRoot -Force|Out-Null
$script:assertions=0
function Assert-Tsf([bool]$Condition,[string]$Message){$script:assertions++;if(!$Condition){throw "ASSERTION_FAILED: $Message"}}

$missionId='general-verifier-fixture-0001'
$revision=1
$runId="canonical-result-$missionId-$revision"
$request='Analyze the bounded fleet fixture and return summary, at least three findings, evidence references, and limitations.'
$intent=New-TsfOriginalOperatorIntentContract -NaturalRequest $request -PreviewId 'hq-preview-11111111111111111111111111111111' -RepositoryTarget $root -WorktreeTarget $root
$scope=New-TsfScopeTransformationContract -OriginalIntent $intent -AuthorizedMissionGoal $request -ProposedOperations @('READ_ANALYSIS','RETURN_RESULT') -ProposedAccess 'READ_ONLY' -RepositoryTarget $root -WorktreeTarget $root
$task=New-TsfTaskCompletionContract -RequiredTask $request -OriginalIntent $intent -ScopeTransformation $scope
$mission=[pscustomobject][ordered]@{
    mission_id=$missionId;mission_revision=$revision;project_id='TSF_CONTROL_PLANE';repo_path=$root;lane='MASTER_TSF_CONTROL_PLANE';mission_type='hq_dispatch_general_result_v2'
    result_validation_mode='GENERAL_RESULT_V2';original_operator_intent=$intent;scope_transformation=$scope;task_completion_contract=$task
    required_tests=@([pscustomobject]@{test_id='hq-dispatch-general-result-v2';required=$true;command="general-result-v2:$([string]$task.task_completion_contract_identity_sha256)"})
    allowed_reads=@('fleet/control/policy-manifest.v1.json');allowed_writes=@();forbidden_reads=@();forbidden_writes=@();forbidden_actions=@('push','merge','deploy','install_packages','migration','secrets','plugins','network')
    expected_artifacts=@('fleet/control/policy-manifest.v1.json');role_extension=[pscustomobject]@{worker_role='researcher_source_tracer_worker';role_output_contract='Return the mission-bound structured general result.'}
}
$missionPath=Join-Path $fixtureRoot 'mission.json'
$workerPath=Join-Path $fixtureRoot 'worker.json'
$adapterPath=Join-Path $fixtureRoot 'adapter.json'
$verifierPath=Join-Path $fixtureRoot 'verifier.json'
Write-TsfKernelJson $mission $missionPath

function New-Claim([string]$Disposition,[string]$Answer,[string[]]$Completed,[string[]]$Missing,[string]$ClaimRunId=$runId){
    $fulfilled=$Disposition-in@('FULFILLED','FULFILLED_WITH_CAVEATS')
    $reason=switch($Disposition){'REFUSED'{'REFUSED'}'BLOCKED_BY_POLICY'{'POLICY_BLOCK'}'NEEDS_CLARIFICATION'{'NEEDS_CLARIFICATION'}'REQUIRED_DELIVERABLE_MISSING'{'REQUIRED_DELIVERABLE_MISSING'}'WRONG_TASK_PERFORMED'{'WRONG_TASK'}'FAILED'{'EXECUTION_FAILED'}'PARTIAL'{'TASK_INCOMPLETE'}'UNABLE_TO_PERFORM'{'TASK_INCOMPLETE'}default{if($fulfilled){'NONE'}else{'UNSPECIFIED'}}}
    [pscustomobject][ordered]@{schema_version='tsf_worker_outcome_claim_v2';mission_id=$missionId;mission_revision=$revision;run_id=$ClaimRunId;task_completion_contract_identity_sha256=[string]$task.task_completion_contract_identity_sha256;original_intent_identity_sha256=[string]$task.original_intent_identity_sha256;scope_transformation_identity_sha256=[string]$task.scope_transformation_identity_sha256;attempted_task_sha256=[string]$task.required_task_sha256;task_attempted=$true;task_completed=$fulfilled;outcome_disposition=$Disposition;completed_deliverables=@($Completed);missing_deliverables=@($Missing);blocked_reason=$reason;substantive_answer=$Answer;evidence=@('final response');caveats=@()}
}
function Invoke-Case([object]$Claim,[bool]$RoleSatisfied){
    $adapter=[pscustomobject][ordered]@{schema_version='tsf_codex_app_server_adapter_result_v1';mission_id=$missionId;mission_revision=$revision;run_id=$runId;result_id=$runId;final_response=($Claim|ConvertTo-Json -Compress -Depth 20);final_response_observed=$true;transport_success=$true;success=$true;semantic_response_success=$false;thread_id='thread-general-verifier';turn_id='turn-general-verifier'}
    Write-TsfKernelJson $adapter $adapterPath
    $evidence=Get-TsfGeneralResultV2Evidence -MissionId $missionId -MissionRevision $revision -RunId $runId -Adapter $adapter -TaskCompletionContract $task
    $worker=[pscustomobject][ordered]@{schema_version=1;mission_id=$missionId;worker_role='researcher_source_tracer_worker';role_output_contract_satisfied=$RoleSatisfied;worker_status=$(if($RoleSatisfied){'CODEX_APP_SERVER_WORKER_GREEN'}else{'GENERAL_RESULT_NOT_FULFILLED'});files_touched=@();files_created=@();restricted_actions_attempted=@();adapter_result_path=$adapterPath;adapter_result_sha256=(Get-FileHash $adapterPath -Algorithm SHA256).Hash.ToLowerInvariant();general_result_evidence=$evidence;tests=@([pscustomobject]@{test_id='hq-dispatch-general-result-v2';status=$(if($evidence.semantic_success){'PASS'}else{'FAIL'});observed="General result disposition: $([string]$evidence.outcome_disposition)";evidence=[string]$task.task_completion_contract_identity_sha256})}
    Write-TsfKernelJson $worker $workerPath
    Invoke-TsfKernelPostRunVerify -MissionPath $missionPath -WorkerResultPath $workerPath -OutFile $verifierPath -StateRoot (Join-Path $fixtureRoot 'state')
}

$requiredIds=@('evidence_references','findings','limitations','summary')
$fulfilledAnswer=([pscustomobject][ordered]@{summary='The bounded fleet fixture is idle and structurally verified.';findings=@('No active owner is recorded.','No listener is present.','The queue has no active item.');evidence_references=@('fixture/owner.json','fixture/listener.json');limitations='This proof is limited to the local fixture.'}|ConvertTo-Json -Compress -Depth 10)
$fulfilled=Invoke-Case (New-Claim 'FULFILLED' $fulfilledAnswer $requiredIds @()) $true
Assert-Tsf ([string]$fulfilled.verdict -eq 'GREEN') 'Independent verifier accepts a mission-bound fulfilled result.'
Assert-Tsf ([bool]$fulfilled.verified) 'Fulfilled result is verified.'
Assert-Tsf ([bool]$fulfilled.general_result_evidence.semantic_success) 'Verifier records semantic success separately from transport.'
Assert-Tsf ([string]$fulfilled.general_result_evidence.transport_status -eq 'SUCCEEDED') 'Verifier records successful transport.'

$unable=Invoke-Case (New-Claim 'UNABLE_TO_PERFORM' 'I cannot perform this requested task.' @() $requiredIds) $false
Assert-Tsf ([string]$unable.verdict -eq 'RED') 'Worker inability cannot become verifier GREEN.'
Assert-Tsf (![bool]$unable.general_result_evidence.semantic_success) 'Worker inability has semantic fulfillment false.'
Assert-Tsf ([string]$unable.general_result_evidence.outcome_disposition -eq 'UNABLE_TO_PERFORM') 'Worker inability disposition is truthful.'

$missingAnswer=([pscustomobject][ordered]@{summary='The partial fixture summary is present.';findings=@('First bounded finding.','Second bounded finding.','Third bounded finding.');limitations='Evidence references are intentionally absent.'}|ConvertTo-Json -Compress -Depth 10)
$missing=Invoke-Case (New-Claim 'FULFILLED' $missingAnswer @('findings','limitations','summary') @('evidence_references')) $false
Assert-Tsf ([string]$missing.verdict -eq 'RED') 'Missing deliverable cannot become verifier GREEN.'
Assert-Tsf ([string]$missing.general_result_evidence.outcome_disposition -eq 'REQUIRED_DELIVERABLE_MISSING') 'Missing deliverable is explicit.'

$partial=Invoke-Case (New-Claim 'PARTIAL' $missingAnswer @('findings','limitations','summary') @('evidence_references')) $false
Assert-Tsf ([string]$partial.verdict -eq 'RED') 'Unaccepted partial result cannot become verifier GREEN.'
Assert-Tsf ([string]$partial.general_result_evidence.outcome_disposition -eq 'PARTIAL') 'Partial disposition is preserved.'

$wrongTask=New-Claim 'FULFILLED' $fulfilledAnswer $requiredIds @()
$wrongTask.attempted_task_sha256='f'*64
$wrong=Invoke-Case $wrongTask $false
Assert-Tsf ([string]$wrong.verdict -eq 'RED') 'Wrong-task identity cannot become verifier GREEN.'
Assert-Tsf ($wrong.general_result_evidence.outcome_evidence -contains 'WRONG_TASK_PERFORMED') 'Wrong-task evidence is explicit.'

$missionId='general-verifier-generic-0001'
$runId="canonical-result-$missionId-$revision"
$request='Explain the bounded fleet fixture in a concise response.'
$intent=New-TsfOriginalOperatorIntentContract -NaturalRequest $request -PreviewId 'hq-preview-22222222222222222222222222222222' -RepositoryTarget $root -WorktreeTarget $root
$scope=New-TsfScopeTransformationContract -OriginalIntent $intent -AuthorizedMissionGoal $request -ProposedOperations @('READ_ANALYSIS','RETURN_RESULT') -ProposedAccess 'READ_ONLY' -RepositoryTarget $root -WorktreeTarget $root
$task=New-TsfTaskCompletionContract -RequiredTask $request -OriginalIntent $intent -ScopeTransformation $scope
$mission=[pscustomobject][ordered]@{
    mission_id=$missionId;mission_revision=$revision;project_id='TSF_CONTROL_PLANE';repo_path=$root;lane='MASTER_TSF_CONTROL_PLANE';mission_type='hq_dispatch_general_result_v2'
    result_validation_mode='GENERAL_RESULT_V2';original_operator_intent=$intent;scope_transformation=$scope;task_completion_contract=$task
    required_tests=@([pscustomobject]@{test_id='hq-dispatch-general-result-v2';required=$true;command="general-result-v2:$([string]$task.task_completion_contract_identity_sha256)"})
    allowed_reads=@('fleet/control/policy-manifest.v1.json');allowed_writes=@();forbidden_reads=@();forbidden_writes=@();forbidden_actions=@('push','merge','deploy','install_packages','migration','secrets','plugins','network')
    expected_artifacts=@('fleet/control/policy-manifest.v1.json');role_extension=[pscustomobject]@{worker_role='researcher_source_tracer_worker';role_output_contract='Return the mission-bound generic informational result.'}
}
Write-TsfKernelJson $mission $missionPath
$genericAnswer='The bounded fleet fixture is idle, its result remains informational, and the raw response is preserved for operator review.'
$generic=Invoke-Case (New-Claim 'FULFILLED' $genericAnswer @('requested_answer') @()) $false
$genericSchema=Test-TsfJsonContract -Value $generic.general_result_evidence -SchemaPath (Join-Path $root 'fleet\control\general-result-v2.schema.v1.json')
Assert-Tsf ([string]$generic.general_result_evidence.compatibility_mode -eq 'STRUCTURAL_TEXT_ONLY_V2') 'Generic postrun evidence uses the canonical structural-only compatibility mode.'
Assert-Tsf ([bool]$genericSchema.valid) 'Generic postrun evidence validates against the governing general-result schema.'
Assert-Tsf ([string]$generic.verdict -eq 'RED') 'Schema-valid generic informational evidence remains verifier RED for fulfillment.'
Assert-Tsf (![bool]$generic.general_result_evidence.semantic_success -and ![bool]$generic.general_result_evidence.admissible) 'Schema compatibility does not grant generic fulfillment or admission.'
Assert-Tsf (@($generic.blocked_reasons | Where-Object { $_ -like 'Verifier general-result evidence violates schema:*' }).Count -eq 0) 'Generic postrun rejection contains no self-schema violation.'

"TSF_GENERAL_RESULT_KERNEL_VERIFIER_PASS assertions=$script:assertions"
