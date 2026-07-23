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
$request='Return a concise summary: the fleet is idle.'
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
    [pscustomobject][ordered]@{schema_version='tsf_worker_outcome_claim_v1';mission_id=$missionId;mission_revision=$revision;run_id=$ClaimRunId;task_completion_contract_identity_sha256=[string]$task.task_completion_contract_identity_sha256;original_intent_identity_sha256=[string]$task.original_intent_identity_sha256;scope_transformation_identity_sha256=[string]$task.scope_transformation_identity_sha256;attempted_task_sha256=[string]$task.required_task_sha256;outcome_disposition=$Disposition;completed_deliverables=@($Completed);missing_deliverables=@($Missing);answer=$Answer;evidence=@('final response');caveats=@()}
}
function Invoke-Case([object]$Claim,[bool]$RoleSatisfied){
    $adapter=[pscustomobject][ordered]@{schema_version='tsf_codex_app_server_adapter_result_v1';mission_id=$missionId;mission_revision=$revision;run_id=$runId;result_id=$runId;final_response=($Claim|ConvertTo-Json -Compress -Depth 20);final_response_observed=$true;transport_success=$true;success=$true;semantic_response_success=$false;thread_id='thread-general-verifier';turn_id='turn-general-verifier'}
    Write-TsfKernelJson $adapter $adapterPath
    $evidence=Get-TsfGeneralResultV2Evidence -MissionId $missionId -MissionRevision $revision -RunId $runId -Adapter $adapter -TaskCompletionContract $task
    $worker=[pscustomobject][ordered]@{schema_version=1;mission_id=$missionId;worker_role='researcher_source_tracer_worker';role_output_contract_satisfied=$RoleSatisfied;worker_status=$(if($RoleSatisfied){'CODEX_APP_SERVER_WORKER_GREEN'}else{'GENERAL_RESULT_NOT_FULFILLED'});files_touched=@();files_created=@();restricted_actions_attempted=@();adapter_result_path=$adapterPath;adapter_result_sha256=(Get-FileHash $adapterPath -Algorithm SHA256).Hash.ToLowerInvariant();general_result_evidence=$evidence;tests=@([pscustomobject]@{test_id='hq-dispatch-general-result-v2';status=$(if($evidence.semantic_success){'PASS'}else{'FAIL'});observed="General result disposition: $([string]$evidence.outcome_disposition)";evidence=[string]$task.task_completion_contract_identity_sha256})}
    Write-TsfKernelJson $worker $workerPath
    Invoke-TsfKernelPostRunVerify -MissionPath $missionPath -WorkerResultPath $workerPath -OutFile $verifierPath -StateRoot (Join-Path $fixtureRoot 'state')
}

$fulfilled=Invoke-Case (New-Claim 'FULFILLED' 'The fleet is idle, stated concisely as requested.' @('requested_answer') @()) $true
Assert-Tsf ([string]$fulfilled.verdict -eq 'GREEN') 'Independent verifier accepts a mission-bound fulfilled result.'
Assert-Tsf ([bool]$fulfilled.verified) 'Fulfilled result is verified.'
Assert-Tsf ([bool]$fulfilled.general_result_evidence.semantic_success) 'Verifier records semantic success separately from transport.'
Assert-Tsf ([string]$fulfilled.general_result_evidence.transport_status -eq 'SUCCEEDED') 'Verifier records successful transport.'

$unable=Invoke-Case (New-Claim 'UNABLE_TO_PERFORM' 'I cannot perform this requested task.' @() @('requested_answer')) $false
Assert-Tsf ([string]$unable.verdict -eq 'RED') 'Worker inability cannot become verifier GREEN.'
Assert-Tsf (![bool]$unable.general_result_evidence.semantic_success) 'Worker inability has semantic fulfillment false.'
Assert-Tsf ([string]$unable.general_result_evidence.outcome_disposition -eq 'UNABLE_TO_PERFORM') 'Worker inability disposition is truthful.'

$missing=Invoke-Case (New-Claim 'FULFILLED' 'This narration omits the requested answer deliverable.' @() @('requested_answer')) $false
Assert-Tsf ([string]$missing.verdict -eq 'RED') 'Missing deliverable cannot become verifier GREEN.'
Assert-Tsf ([string]$missing.general_result_evidence.outcome_disposition -eq 'REQUIRED_DELIVERABLE_MISSING') 'Missing deliverable is explicit.'

$partial=Invoke-Case (New-Claim 'PARTIAL' 'Only part of the requested task was completed.' @() @('requested_answer')) $false
Assert-Tsf ([string]$partial.verdict -eq 'RED') 'Unaccepted partial result cannot become verifier GREEN.'
Assert-Tsf ([string]$partial.general_result_evidence.outcome_disposition -eq 'PARTIAL') 'Partial disposition is preserved.'

$wrongTask=New-Claim 'FULFILLED' 'This is a substantive answer to a related but different task.' @('requested_answer') @()
$wrongTask.attempted_task_sha256='f'*64
$wrong=Invoke-Case $wrongTask $false
Assert-Tsf ([string]$wrong.verdict -eq 'RED') 'Wrong-task identity cannot become verifier GREEN.'
Assert-Tsf ($wrong.general_result_evidence.outcome_evidence -contains 'WRONG_TASK_PERFORMED') 'Wrong-task evidence is explicit.'

"TSF_GENERAL_RESULT_KERNEL_VERIFIER_PASS assertions=$script:assertions"
