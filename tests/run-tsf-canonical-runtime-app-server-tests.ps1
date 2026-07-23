[CmdletBinding(PositionalBinding=$false)]
param(
    [string]$EvidenceRoot = 'docs/hq/tsf_canonical_runtime_app_server_vertical_slice_v1_20260711',
    [switch]$RunLiveReadOnly,
    [switch]$RunLiveWorkspaceWrite
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if(![IO.Path]::IsPathRooted($EvidenceRoot)){$EvidenceRoot=Join-Path $repo $EvidenceRoot}
Import-Module (Join-Path $repo 'tools\TsfDurableContract.psm1') -Force
. (Join-Path $repo 'tools\codex-fleet-enforcement-kernel.ps1')
$script:Results=[Collections.Generic.List[object]]::new()
$testRunNonce=[guid]::NewGuid().ToString('N')
function Assert-Case($Id,$Category,[bool]$Passed,$Observed){$script:Results.Add([pscustomobject]@{case_id=$Id;category=$Category;status=if($Passed){'PASS'}else{'FAIL'};observed=[string]$Observed})|Out-Null;Write-Host "$(if($Passed){'PASS'}else{'FAIL'}) $Id :: $Observed" -ForegroundColor $(if($Passed){'DarkGreen'}else{'Red'})}
function Throws([scriptblock]$Action){try{&$Action|Out-Null;return $false}catch{return $true}}
function ThrowsLike([scriptblock]$Action,[string]$Pattern){try{&$Action|Out-Null;return $false}catch{return $_.Exception.Message-match$Pattern}}
function Copy-Object($Value){$Value|ConvertTo-Json -Depth 100|ConvertFrom-Json}
function Write-Json($Value,$Path){$parent=Split-Path -Parent $Path;if($parent){New-Item -ItemType Directory -Force $parent|Out-Null};$Value|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $Path -Encoding UTF8}
function Get-Hash($Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}

$runtimeRoot=Join-Path $repo '.codex-local\fixtures\tsf-app-v1'
$fixtureRoot=Get-TsfKernelFullPath (Join-Path $repo '.codex-local\fixtures')
$runtimeFull=Get-TsfKernelFullPath $runtimeRoot
if(!(Test-TsfKernelPathInside $runtimeFull $fixtureRoot)){throw 'Unsafe runtime cleanup path.'}
if(Test-Path $runtimeFull){
    foreach($knownLink in @((Join-Path $runtimeFull 'path-repo\allowed\escape-link'),(Join-Path $runtimeFull 'repo-link'))){if(Test-Path -LiteralPath $knownLink){$item=Get-Item -LiteralPath $knownLink -Force;if(($item.Attributes-band[IO.FileAttributes]::ReparsePoint)-ne0){[IO.Directory]::Delete($knownLink,$false)}}}
    Remove-Item -LiteralPath $runtimeFull -Recurse -Force
}
New-Item -ItemType Directory -Force $runtimeFull,$EvidenceRoot|Out-Null

$gitState=Get-TsfKernelGitState -RepoPath $repo
if(!$gitState.can_capture-or!$gitState.branch_identity_available-or([string]$gitState.head)-notmatch'^[a-f0-9]{40,64}$'){throw "TSF_CANONICAL_APP_SERVER_GIT_IDENTITY_UNAVAILABLE: $([string]$gitState.error)"}
$branch=[string]$gitState.branch
$head=[string]$gitState.head
$fingerprint=Get-TsfPolicyFingerprint (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $repo -UnsupportedDevelopmentMode

function New-CanonicalMission {
    param([string]$Id,[string]$Repository,[string]$ExpectedBranch,[string]$StartingHead,[switch]$WorkspaceWrite)
    $created=[datetimeoffset]::UtcNow
    $role=if($WorkspaceWrite){'builder_worker'}else{'auditor_worker'}
    $alias=if($WorkspaceWrite){'BALANCED'}else{'FAST'}
    $route=Resolve-TsfModelRouting $alias CODEX
    $branchRequired=![string]::IsNullOrWhiteSpace($ExpectedBranch)
    $expectedBranchValue=if($branchRequired){$ExpectedBranch}else{$null}
    $reads=if($WorkspaceWrite){@('input')}else{@('fleet/control/policy-manifest.v1.json')}
    $writes=if($WorkspaceWrite){@('output')}else{@()}
    $artifact=if($WorkspaceWrite){'output/result.txt'}else{'fleet/control/policy-manifest.v1.json'}
    $goal=if($WorkspaceWrite){'Create output/result.txt with exactly: TSF workspace-write round trip complete. Do not modify any other file.'}else{'Read fleet/control/policy-manifest.v1.json and return its schema_version as the requested answer.'}
    $originalIntent=$null;$scopeTransformation=$null;$taskCompletionContract=$null;$resultValidationMode=$null
    if(!$WorkspaceWrite){
        $previewId='hq-preview-'+(Get-TsfContractJsonHash ([pscustomobject]@{mission_id=$Id})).Substring(0,32)
        $originalIntent=New-TsfOriginalOperatorIntentContract -NaturalRequest $goal -PreviewId $previewId -RepositoryTarget $Repository -WorktreeTarget $Repository -ProhibitedOperations @('push','merge','deploy','install','network','product_repo_mutation','background_runner','persistent_runner','secrets')
        $scopeTransformation=New-TsfScopeTransformationContract -OriginalIntent $originalIntent -AuthorizedMissionGoal $goal -ProposedOperations @($originalIntent.explicitly_requested_operations) -ProposedAccess 'READ_ONLY' -RepositoryTarget $Repository -WorktreeTarget $Repository -DetachedHead:(!$branchRequired)
        $taskCompletionContract=New-TsfTaskCompletionContract -RequiredTask $goal -OriginalIntent $originalIntent -ScopeTransformation $scopeTransformation
        $resultValidationMode='GENERAL_RESULT_V2'
    }
    [object[]]$requiredTests=$(if($null-ne$taskCompletionContract){@([pscustomobject]@{test_id='hq-dispatch-general-result-v2';required=$true;command="general-result-v2:$([string]$taskCompletionContract.task_completion_contract_identity_sha256)"})}else{@([pscustomobject]@{test_id='app-server-automatic-round-trip';required=$true;command='native stable stdio protocol'})})
    [pscustomobject][ordered]@{
        schema_version='tsf_mission_envelope_v1';mission_id=$Id;mission_revision=1;parent_mission_id=$null;project_id='TSF_CONTROL_PLANE';original_request=$goal;normalized_goal=$goal;exact_response_contract=$null;result_validation_mode=$resultValidationMode;original_operator_intent=$originalIntent;scope_transformation=$scopeTransformation;task_completion_contract=$taskCompletionContract;mission_type='canonical_app_server_vertical_slice';worker_role=$role;recommended_surface='CODEX';model_policy_alias=$alias;resolved_model=$route.resolved_model;reasoning_effort=$route.reasoning_effort;model_selection_assurance='RECOMMENDED_ONLY';permission_mode=if($WorkspaceWrite){'WORKSPACE_WRITE'}else{'READ_ONLY'};network_policy='PROHIBITED';control_plane_service_network_policy='CODEX_SERVICE_ONLY';worker_tool_network_policy='DISABLED';repository_allowlist=@($Repository);forbidden_repositories=@();source_allowlist=@();forbidden_sources=@('NORMAL_NWR_PACKETS','SECRETS','CREDENTIALS','PRIVATELENS','PRODUCT_REPOS');branch_worktree_policy=[pscustomobject]@{branch_required=$branchRequired;worktree_required=$true;expected_branch=$expectedBranchValue;expected_worktree=$Repository;starting_head=$StartingHead;unexpected_advance_behavior='REJECT'};allowed_reads=@($reads);allowed_writes=@($writes);forbidden_actions=@('push','merge','deploy','install','network','product_repo_mutation','background_runner','persistent_runner','secrets');completion_criteria=if($null-ne$taskCompletionContract){@($taskCompletionContract.success_criteria)}else{@('Bound foreground app-server turn completes and canonical admission succeeds.')};required_tests=$requiredTests;required_artifacts=@([pscustomobject]@{path=$artifact;hash_required=$true});required_verifier_independence='SEPARATE_ROLE';stop_conditions=@('Unexpected file touch.','Worker tool network request.','Native identity mismatch.','Timeout.','Verifier failure.');approval_references=@();policy=[pscustomobject]@{policy_commit=$fingerprint.policy_commit;manifest_version='tsf_policy_manifest_v1';fingerprint=$fingerprint.fingerprint;mission_schema_version='tsf_mission_envelope_v1';expected_result_schema_version='tsf_result_envelope_v1'};created_at=$created.ToString('o');expires_at=$created.AddMinutes(45).ToString('o');stale_state_behavior='TIM_REQUIRED';required_result_envelope_version='tsf_result_envelope_v1'
    }
}

function Set-GeneralResultFixtureBinding {
    param([Parameter(Mandatory)][object]$Result,[Parameter(Mandatory)][object]$Mission,[Parameter(Mandatory)][string]$ResultId)
    $contract=$Mission.task_completion_contract
    $Result.result_id=$ResultId;$Result.mission_id=$Mission.mission_id;$Result.mission_revision=$Mission.mission_revision
    $Result.original_intent_identity_sha256=[string]$contract.original_intent_identity_sha256;$Result.scope_transformation_identity_sha256=[string]$contract.scope_transformation_identity_sha256;$Result.task_completion_contract_identity_sha256=[string]$contract.task_completion_contract_identity_sha256
    $Result.worker_claim.mission_id=$Mission.mission_id;$Result.worker_claim.mission_revision=[int]$Mission.mission_revision;$Result.worker_claim.run_id=$ResultId
    $Result.worker_claim.original_intent_identity_sha256=[string]$contract.original_intent_identity_sha256;$Result.worker_claim.scope_transformation_identity_sha256=[string]$contract.scope_transformation_identity_sha256;$Result.worker_claim.task_completion_contract_identity_sha256=[string]$contract.task_completion_contract_identity_sha256;$Result.worker_claim.attempted_task_sha256=[string]$contract.required_task_sha256
    $Result.raw_worker_response_sha256=Get-TsfSemanticTextSha256 ($Result.worker_claim|ConvertTo-Json -Compress -Depth 100)
    return $Result
}

$readMission=New-CanonicalMission "synthetic-tsf-readonly-appserver-$testRunNonce" $repo $branch $head
Assert-Case 'VS-SCHEMA-001' schema (Test-TsfMissionEnvelope $readMission).valid 'read-only durable mission schema'
$readQueue=ConvertTo-TsfCanonicalExecutionArtifacts $readMission $repo
$readQueue2=ConvertTo-TsfCanonicalExecutionArtifacts $readMission $repo
Assert-Case 'VS-QUEUE-001' queue ((Get-TsfContractJsonHash $readQueue)-eq(Get-TsfContractJsonHash $readQueue2)) 'deterministic queue document'
$readQueueCheck=Test-TsfCanonicalQueueDocument $readQueue $readMission $repo
Assert-Case 'VS-QUEUE-002' queue $readQueueCheck.valid ($readQueueCheck.errors -join '; ')
Assert-Case 'VS-QUEUE-003' queue ($readQueue.source_binding.durable_mission_id-eq$readMission.mission_id-and$readQueue.source_binding.durable_mission_revision-eq1-and$readQueue.source_binding.policy_fingerprint-eq$fingerprint.fingerprint) 'durable binding preserved'
$swapped=Copy-Object $readQueue;$swapped.mission_packet.mission_id='unrelated-mission';Assert-Case 'VS-QUEUE-004' queue (!(Test-TsfCanonicalQueueDocument $swapped $readMission $repo -SkipRuntimeObservation).valid) 'swapped queue record rejected'
$roleSpoof=Copy-Object $readQueue;$roleSpoof.role_extension.worker_role='builder_worker';Assert-Case 'VS-QUEUE-005' queue (!(Test-TsfCanonicalQueueDocument $roleSpoof $readMission $repo -SkipRuntimeObservation).valid) 'role-extension spoof rejected'
$effortConflict=Copy-Object $readMission;$effortConflict.reasoning_effort='HIGH';Assert-Case 'VS-MODEL-001' model (Throws {ConvertTo-TsfCanonicalExecutionArtifacts $effortConflict $repo}) 'model-effort conflict fails closed'

Assert-Case 'VS-EFFORT-001' effort ((ConvertTo-TsfCanonicalEffortName 'LIGHT')-eq'LIGHT'-and(ConvertTo-TsfCanonicalEffortName 'low')-eq'LIGHT'-and(ConvertTo-TsfCanonicalEffortName 'LOW')-eq'LIGHT') 'LIGHT/low/LOW normalize canonically'
$baseEffortAdapter=[pscustomobject][ordered]@{mission_requested_effort='LIGHT';canonical_resolved_effort='LIGHT';thread_default_effort='low';turn_requested_effort='low';effective_effort='UNKNOWN';effective_effort_raw=$null;effective_effort_source='NOT_EXPOSED';effort_assurance='RECOMMENDED_ONLY';required_effort_assurance='RECOMMENDED_ONLY';turn_request_acknowledged=$true;native_reroute_or_override_events=@()}
$matchingEffort=Get-TsfEffortEvidence $readMission $baseEffortAdapter;Assert-Case 'VS-EFFORT-002' effort (@($matchingEffort.effort_conflicts).Count-eq0-and$matchingEffort.turn_requested_effort-eq'low') 'matching thread default and turn request'
$differentDefault=Copy-Object $baseEffortAdapter;$differentDefault.thread_default_effort='high';$differentEvidence=Get-TsfEffortEvidence $readMission $differentDefault;Assert-Case 'VS-EFFORT-003' effort (@($differentEvidence.effort_conflicts)-contains'THREAD_DEFAULT_DIFFERS_FROM_TURN_REQUEST') 'thread default differs without becoming effective proof'
Assert-Case 'VS-EFFORT-004' effort ($differentEvidence.effective_effort-eq'UNKNOWN'-and$differentEvidence.effective_effort_source-eq'NOT_EXPOSED') 'effective effort unavailable remains unknown'
$effectiveMatch=Copy-Object $baseEffortAdapter;$effectiveMatch.effective_effort='LIGHT';$effectiveMatch.effective_effort_raw='low';$effectiveMatch.effective_effort_source='THREAD_SETTINGS_UPDATED';$effectiveMatch.effort_assurance='ADAPTER_VERIFIED';$effectiveMatchEvidence=Get-TsfEffortEvidence $readMission $effectiveMatch;Assert-Case 'VS-EFFORT-005' effort ($effectiveMatchEvidence.effective_effort-eq'LIGHT'-and$effectiveMatchEvidence.effort_admission_effect-eq'ADMITTED') 'authoritative effective effort matches'
$effectiveMismatch=Copy-Object $effectiveMatch;$effectiveMismatch.effective_effort='HIGH';$effectiveMismatch.effective_effort_raw='high';$effectiveMismatchEvidence=Get-TsfEffortEvidence $readMission $effectiveMismatch;Assert-Case 'VS-EFFORT-006' effort ($effectiveMismatchEvidence.effort_admission_effect-eq'REJECTED_OUT_OF_SCOPE') 'authoritative effective effort mismatch fails closed'
$reroute=Copy-Object $baseEffortAdapter;$reroute.native_reroute_or_override_events=@([pscustomobject]@{method='model/rerouted';sequence=9;thread_id='fake-thread';turn_id='fake-turn';raw_payload_json='{"threadId":"fake-thread","turnId":"fake-turn"}';raw_payload_sha256=('a'*64)});$rerouteEvidence=Get-TsfEffortEvidence $readMission $reroute;Assert-Case 'VS-EFFORT-007' effort (@($rerouteEvidence.native_reroute_or_override_events).Count-eq1-and@($rerouteEvidence.effort_conflicts)-contains'NATIVE_MODEL_REROUTE_OBSERVED') 'native reroute preserved and evaluated'
Assert-Case 'VS-EFFORT-008' effort ($differentEvidence.effort_admission_effect-eq'ADMITTED_WITH_CAVEATS'-and$differentEvidence.effort_assurance-eq'RECOMMENDED_ONLY') 'RECOMMENDED_ONLY unknown effective effort admits with caveats'
$adapterRequiredMission=Copy-Object $readMission;$adapterRequiredMission.model_selection_assurance='ADAPTER_VERIFIED';$adapterRequired=Copy-Object $baseEffortAdapter;$adapterRequired.required_effort_assurance='ADAPTER_VERIFIED';$adapterRequiredEvidence=Get-TsfEffortEvidence $adapterRequiredMission $adapterRequired;Assert-Case 'VS-EFFORT-009' effort ($adapterRequiredEvidence.effort_admission_effect-eq'TIM_REQUIRED') 'ADAPTER_VERIFIED mission rejects unknown effective effort'
$exactMismatch=Copy-Object $effectiveMismatch;$exactMismatch.required_effort_assurance='ADAPTER_VERIFIED';$exactMismatchEvidence=Get-TsfEffortEvidence $adapterRequiredMission $exactMismatch;Assert-Case 'VS-EFFORT-010' effort ($exactMismatchEvidence.effort_admission_effect-eq'REJECTED_OUT_OF_SCOPE') 'exact-effort mission rejects authoritative mismatch'
$callerSpoof=Copy-Object $baseEffortAdapter;$callerSpoof|Add-Member caller_supplied_effective_effort 'HIGH';$callerSpoofEvidence=Get-TsfEffortEvidence $readMission $callerSpoof;Assert-Case 'VS-EFFORT-011' effort ($callerSpoofEvidence.effective_effort-eq'UNKNOWN') 'unbound caller effort cannot become observed evidence'
$rawCase=Copy-Object $baseEffortAdapter;$rawCase.thread_default_effort='HiGh';$rawCase.turn_requested_effort='low';$rawCaseEvidence=Get-TsfEffortEvidence $readMission $rawCase;Assert-Case 'VS-EFFORT-012' effort ($rawCaseEvidence.thread_default_effort-ceq'HiGh'-and$rawCaseEvidence.turn_requested_effort-ceq'low') 'raw native effort values preserved unchanged'

$pathRepo=Join-Path $runtimeRoot 'path-repo';New-Item -ItemType Directory -Force (Join-Path $pathRepo 'allowed'),(Join-Path $runtimeRoot 'outside')|Out-Null;Set-Content -LiteralPath (Join-Path $pathRepo 'allowed\file.txt') -Value 'x';Set-Content -LiteralPath (Join-Path $runtimeRoot 'outside\escape.txt') -Value 'escape'
Assert-Case 'VS-PATH-001' path (Test-TsfKernelPathContained 'allowed/file.txt' $pathRepo @('allowed/file.txt')) 'exact path equality'
Assert-Case 'VS-PATH-002' path (Test-TsfKernelPathContained 'allowed\file.txt' $pathRepo @('allowed')) 'separator descendant'
Assert-Case 'VS-PATH-003' path (!(Test-TsfKernelPathContained 'allowed-sibling/file.txt' $pathRepo @('allowed'))) 'sibling prefix rejected'
Assert-Case 'VS-PATH-004' path (!(Test-TsfKernelPathContained 'allowed/../outside.txt' $pathRepo @('allowed'))) 'traversal rejected'
Assert-Case 'VS-PATH-005' path (!(Test-TsfKernelPathContained (Join-Path $pathRepo 'allowed\file.txt') $pathRepo @('allowed'))) 'rooted injection rejected'
$junction=Join-Path $pathRepo 'allowed\escape-link';$junctionMade=$false;try{New-Item -ItemType Junction -Path $junction -Target (Join-Path $runtimeRoot 'outside')|Out-Null;$junctionMade=$true}catch{}
Assert-Case 'VS-PATH-006' path ($junctionMade-and!(Test-TsfKernelPathContained 'allowed/escape-link/escape.txt' $pathRepo @('allowed'))) 'detectable reparse escape rejected'
$repoLink=Join-Path $runtimeRoot 'repo-link';$rootLinkMade=$false;try{New-Item -ItemType Junction -Path $repoLink -Target $pathRepo|Out-Null;$rootLinkMade=$true}catch{}
$rootRejected=$false;if($rootLinkMade){$probe=". '$($repo.Replace("'","''"))\tools\codex-fleet-enforcement-kernel.ps1'; if(!(Test-TsfKernelPathContained 'allowed/file.txt' '$($repoLink.Replace("'","''"))' @('allowed'))){exit 0}else{exit 1}";& powershell -NoProfile -ExecutionPolicy Bypass -Command $probe|Out-Null;$rootRejected=$LASTEXITCODE-eq0;[IO.Directory]::Delete($repoLink,$false)}
Assert-Case 'VS-PATH-007' path ($rootLinkMade-and$rootRejected) 'reparse repository root rejected'

$approvalSchema=Join-Path $repo 'docs\hq\enforcement_kernel\minimum_viable_local_tsf_enforcement_kernel_v1\approval_ledger_schema_v1.json'
$invalidLedger=[pscustomobject]@{schema_version=1;ledger_id='invalid-anyof';approvals=@([pscustomobject]@{approval_id='approval-1';approved_by='fixture';approved_at='2026-07-10T00:00:00Z';repo_path=$repo;lane='MASTER_TSF_CONTROL_PLANE';exact_action='local_write';allowed_files_or_paths=@('fleet/control');required_verifier='verifier_worker';notes='missing expires and scope'})}
Assert-Case 'VS-APPROVAL-001' approval (!(Test-TsfJsonContract $invalidLedger $approvalSchema).valid) 'approval anyOf enforced'
$validLedger=Copy-Object $invalidLedger;$validLedger.approvals[0]|Add-Member expires_at '2099-01-01T00:00:00Z';Assert-Case 'VS-APPROVAL-002' approval (Test-TsfJsonContract $validLedger $approvalSchema).valid 'approval anyOf valid branch'
$approvalMission=Copy-Object $readQueue.mission_packet;$approvalMission.approval_requirements=@([pscustomobject]@{approval_id='approval-1';exact_action='local_write';required=$true;reason='test'});$match=Find-TsfKernelApprovalMatches $approvalMission $validLedger '' -CurrentTime ([datetimeoffset]'2026-07-10T12:00:00Z') -RequireCanonicalUsageBinding;Assert-Case 'VS-APPROVAL-003' approval (!$match[0].satisfied) $match[0].match_status
$canonicalApproval=Copy-Object $validLedger.approvals[0];$canonicalApproval|Add-Member state 'ACTIVE';$canonicalApproval|Add-Member mission_id $readMission.mission_id;$canonicalApproval|Add-Member usage_count 0;$canonicalApproval|Add-Member max_uses 2;$canonicalApproval|Add-Member reuse_policy 'SINGLE_USE';$canonicalApproval|Add-Member worktree_path $repo;$reuseLedger=[pscustomobject]@{schema_version=1;ledger_id='reuse';approvals=@($canonicalApproval)};$reuseMatch=Find-TsfKernelApprovalMatches $approvalMission $reuseLedger '' -CurrentTime ([datetimeoffset]'2026-07-10T12:00:00Z') -RequireCanonicalUsageBinding;Assert-Case 'VS-APPROVAL-004' approval (!$reuseMatch[0].satisfied-and$reuseMatch[0].match_status-eq'MATCH_REUSE_POLICY_INVALID') $reuseMatch[0].match_status
$stale=Copy-Object $canonicalApproval;$stale.max_uses=1;$stale.expires_at='2020-01-01T00:00:00Z';$staleLedger=[pscustomobject]@{schema_version=1;ledger_id='stale';approvals=@($stale)};$staleMatch=Find-TsfKernelApprovalMatches $approvalMission $staleLedger '' -CurrentTime ([datetimeoffset]'2026-07-10T12:00:00Z') -RequireCanonicalUsageBinding;Assert-Case 'VS-APPROVAL-005' approval (!$staleMatch[0].satisfied) $staleMatch[0].match_status
$fixtureApproval=Copy-Object $canonicalApproval;$fixtureApproval.max_uses=1;$fixtureApproval|Add-Member sample_fixture_only $true;$fixtureLedger=[pscustomobject]@{schema_version=1;ledger_id='fixture-leak';approvals=@($fixtureApproval)};$fixtureLedgerPath=Join-Path $runtimeRoot 'fixture-ledger.json';Write-Json $fixtureLedger $fixtureLedgerPath;$fixtureMatch=Find-TsfKernelApprovalMatches $approvalMission $fixtureLedger $fixtureLedgerPath -CurrentTime ([datetimeoffset]'2026-07-10T12:00:00Z') -RequireCanonicalUsageBinding;Assert-Case 'VS-APPROVAL-006' approval (!$fixtureMatch[0].satisfied-and$fixtureMatch[0].match_status-eq'FIXTURE_MATCH_NOT_AUTHORITY') $fixtureMatch[0].match_status
Assert-Case 'VS-REPLAY-001' replay (!(Get-Command Get-TsfAdmissionDecision).Parameters.ContainsKey('PreservationPacketPath')) 'receipt root is not caller-selectable'

$fingerprintRepo=Join-Path $env:TEMP 'tsf-fp-vslice';if(Test-Path $fingerprintRepo){Remove-Item -LiteralPath $fingerprintRepo -Recurse -Force};New-Item -ItemType Directory -Force $fingerprintRepo|Out-Null;$manifest=Get-Content (Join-Path $repo 'fleet\control\policy-manifest.v1.json') -Raw|ConvertFrom-Json
foreach($rel in @('fleet/control/policy-manifest.v1.json')+@($manifest.governing_files)){$src=Join-Path $repo $rel;$dst=Join-Path $fingerprintRepo $rel;New-Item -ItemType Directory -Force (Split-Path -Parent $dst)|Out-Null;Copy-Item -LiteralPath $src -Destination $dst}
& git -C $fingerprintRepo init -q;& git -C $fingerprintRepo config user.email 'fixture@tsf.invalid';& git -C $fingerprintRepo config user.name 'TSF Fixture';& git -C $fingerprintRepo add .;& git -C $fingerprintRepo commit -q -m fixture
$fpBase=Get-TsfPolicyFingerprint (Join-Path $fingerprintRepo 'fleet\control\policy-manifest.v1.json') $fingerprintRepo
Set-Content -LiteralPath (Join-Path $fingerprintRepo 'unrelated.txt') -Value 'unrelated';$fpUnrelated=Get-TsfPolicyFingerprint (Join-Path $fingerprintRepo 'fleet\control\policy-manifest.v1.json') $fingerprintRepo;Assert-Case 'VS-FP-001' fingerprint ($fpBase.fingerprint-eq$fpUnrelated.fingerprint) 'unrelated file excluded'
$governingClasses=@('tools/TsfDurableContract.Canonical.ps1','tools/Invoke-TsfMissionQueueForegroundExecutor.ps1','tools/codex-fleet-runtime.ps1','tools/Test-TsfWorkerRolePermission.ps1','docs/hq/enforcement_kernel/minimum_viable_local_tsf_enforcement_kernel_v1/approval_ledger_schema_v1.json','fleet/control/result-envelope.schema.v1.json')
$fpIndex=1;foreach($rel in $governingClasses){Add-Content -LiteralPath (Join-Path $fingerprintRepo $rel) -Value ' ';$changed=Get-TsfPolicyFingerprint (Join-Path $fingerprintRepo 'fleet\control\policy-manifest.v1.json') $fingerprintRepo -UnsupportedDevelopmentMode;Assert-Case ("VS-FP-{0:d3}"-f($fpIndex+1)) fingerprint ($changed.fingerprint-ne$fpBase.fingerprint) $rel;& git -C $fingerprintRepo checkout -q -- $rel;$fpIndex++}
$loadedRuntimeDependencies=@('tools/codex-fleet-enforcement-kernel.ps1','tools/codex-fleet-runtime.ps1','tools/TsfDurableContract.psm1');$declared=@($manifest.governing_files)
Assert-Case 'VS-FP-LOADED-001' fingerprint (@($loadedRuntimeDependencies|Where-Object{$declared-notcontains$_}).Count-eq0) 'all canonical orchestration loaded runtime dependencies are fingerprinted'

$fakeCwd=Join-Path $runtimeRoot 'fake-cwd';New-Item -ItemType Directory -Force $fakeCwd|Out-Null;$promptPath=Join-Path $runtimeRoot 'fake-prompt.txt';Set-Content -LiteralPath $promptPath -Value 'Return exactly TSF_FAKE_GREEN.'
function Invoke-FakeAdapter {
    param(
        [string]$Mode,
        [string]$MissionId='fake-mission-0001',
        [int]$MissionRevision=1,
        [string]$PolicyFingerprint=('a'*64),
        [string]$QueueDocumentSha256=('b'*64),
        [string]$Cwd=$fakeCwd,
        [string]$RequiredEffortAssurance='RECOMMENDED_ONLY'
    )
    $safeId=$MissionId-replace'[^A-Za-z0-9._-]','_';$out=Join-Path $runtimeRoot "fake-$Mode-$safeId";New-Item -ItemType Directory -Force $out|Out-Null
    $old=$env:TSF_FAKE_APP_SERVER_MODE;$env:TSF_FAKE_APP_SERVER_MODE=$Mode
    try{
        $resultPath=Join-Path $out 'ar.json';$eventPath=Join-Path $out 'ej.jsonl';$stderrPath=Join-Path $out 'se.log'
        & node (Join-Path $repo 'tools\tsf-codex-app-server-adapter.mjs') --codex-executable (Join-Path $repo 'tests\fixtures\fleet\durable-contract\fake-codex-app-server.mjs') --mission-id $MissionId --mission-revision $MissionRevision --policy-fingerprint $PolicyFingerprint --queue-document-sha256 $QueueDocumentSha256 --cwd $Cwd --model 'gpt-5.6-luna' --mission-requested-effort 'LIGHT' --canonical-resolved-effort 'LIGHT' --required-effort-assurance $RequiredEffortAssurance --effort 'low' --sandbox 'read-only' --prompt-file $promptPath --output-dir $out --result-file $resultPath --event-file $eventPath --stderr-file $stderrPath --timeout-seconds 2 --expires-at '2099-01-01T00:00:00Z'|Out-Null
        $exit=$LASTEXITCODE;$result=Get-Content $resultPath -Raw|ConvertFrom-Json
        return [pscustomobject]@{exit=$exit;result=$result;out=$out;result_path=$resultPath}
    }finally{$env:TSF_FAKE_APP_SERVER_MODE=$old}
}
$fakeNormal=Invoke-FakeAdapter normal;Assert-Case 'VS-PROTOCOL-001' protocol ($fakeNormal.exit-eq0-and$fakeNormal.result.success) 'stable fake protocol'
$fakeEffortMatch=Invoke-FakeAdapter 'effort-match';Assert-Case 'VS-PROTOCOL-EFFORT-001' protocol ($fakeEffortMatch.exit-eq0-and$fakeEffortMatch.result.thread_default_effort-eq'low'-and$fakeEffortMatch.result.turn_requested_effort-eq'low'-and$fakeEffortMatch.result.effective_effort-eq'LIGHT'-and$fakeEffortMatch.result.effective_effort_source-eq'THREAD_SETTINGS_UPDATED') 'native settings update binds matching effective effort'
$fakeEffortMismatch=Invoke-FakeAdapter 'effort-mismatch';Assert-Case 'VS-PROTOCOL-EFFORT-002' protocol ($fakeEffortMismatch.exit-eq0-and$fakeEffortMismatch.result.thread_default_effort-eq'high'-and$fakeEffortMismatch.result.turn_requested_effort-eq'low'-and$fakeEffortMismatch.result.effective_effort-eq'HIGH'-and@($fakeEffortMismatch.result.effort_conflicts)-contains'EFFECTIVE_EFFORT_DIFFERS_FROM_CANONICAL_RESOLUTION') 'native settings update preserves effective mismatch'
$fakeReroute=Invoke-FakeAdapter reroute;Assert-Case 'VS-PROTOCOL-EFFORT-003' protocol ($fakeReroute.exit-eq0-and@($fakeReroute.result.native_reroute_or_override_events|Where-Object method -eq 'model/rerouted').Count-eq1) 'native reroute event preserved'
$fakeUsage=Invoke-FakeAdapter normal;Assert-Case 'VS-USAGE-001' usage ($fakeUsage.exit-eq0-and$fakeUsage.result.turn_usage.evidence_classification-eq'NATIVE_OBSERVED'-and$fakeUsage.result.turn_usage.total_tokens-eq10-and$fakeUsage.result.turn_usage.raw_payload_sha256) 'one bound native usage event'
$fakeUsageMultiple=Invoke-FakeAdapter 'usage-multiple';Assert-Case 'VS-USAGE-002' usage ($fakeUsageMultiple.exit-eq0-and$fakeUsageMultiple.result.turn_usage.event_count-eq2-and$fakeUsageMultiple.result.turn_usage.unique_event_count-eq2-and$fakeUsageMultiple.result.turn_usage.total_tokens-eq20) 'multiple increasing usage updates select greatest cumulative snapshot'
$fakeUsageDuplicate=Invoke-FakeAdapter 'usage-duplicate';Assert-Case 'VS-USAGE-003' usage ($fakeUsageDuplicate.exit-eq0-and$fakeUsageDuplicate.result.turn_usage.event_count-eq2-and$fakeUsageDuplicate.result.turn_usage.unique_event_count-eq1-and$fakeUsageDuplicate.result.turn_usage.total_tokens-eq10) 'duplicate usage retained but not promoted twice'
$fakeUsageOutOfOrder=Invoke-FakeAdapter 'usage-out-of-order';Assert-Case 'VS-USAGE-004' usage ($fakeUsageOutOfOrder.exit-eq0-and$fakeUsageOutOfOrder.result.turn_usage.total_tokens-eq20) 'out-of-order usage selects greatest cumulative snapshot'
$fakeUsageAbsent=Invoke-FakeAdapter 'usage-absent';Assert-Case 'VS-USAGE-005' usage ($fakeUsageAbsent.exit-eq0-and$fakeUsageAbsent.result.turn_usage.status-eq'NOT_EXPOSED'-and$fakeUsageAbsent.result.turn_usage.evidence_classification-eq'UNVERIFIED'-and$null-eq$fakeUsageAbsent.result.turn_usage.total_tokens) 'absent usage remains unknown'
$fakeUsageMismatch=Invoke-FakeAdapter 'usage-mismatch';Assert-Case 'VS-USAGE-006' usage ($fakeUsageMismatch.exit-ne0-and$fakeUsageMismatch.result.failure-match'Spoofed turn id') $fakeUsageMismatch.result.failure
$fakeUsageMalformed=Invoke-FakeAdapter 'usage-malformed';Assert-Case 'VS-USAGE-007' usage ($fakeUsageMalformed.exit-ne0-and$fakeUsageMalformed.result.failure-match'Malformed native token usage') $fakeUsageMalformed.result.failure
foreach($mode in @('malformed','exit','timeout','duplicate','out-of-order','spoof')){$fake=Invoke-FakeAdapter $mode;Assert-Case ("VS-PROTOCOL-$mode") protocol ($fake.exit-ne0-and!$fake.result.success) $fake.result.failure}

$mapperRoot=Join-Path $runtimeRoot 'mapper-producer-binding';New-Item -ItemType Directory -Force $mapperRoot|Out-Null
$mapperQueuePath=Join-Path $mapperRoot 'queue.json';Write-Json $readQueue $mapperQueuePath
$mapperQueueHash=Get-TsfContractJsonHash $readQueue
$mapperRunId="canonical-result-$($readMission.mission_id)-$($readMission.mission_revision)"
$mapperPrompt=@"
Echo mission_id "$($readMission.mission_id)".
Echo mission_revision $($readMission.mission_revision).
Echo run_id "$mapperRunId".
Echo task_completion_contract_identity_sha256 "$([string]$readMission.task_completion_contract.task_completion_contract_identity_sha256)".
Echo original_intent_identity_sha256 "$([string]$readMission.task_completion_contract.original_intent_identity_sha256)".
Echo scope_transformation_identity_sha256 "$([string]$readMission.task_completion_contract.scope_transformation_identity_sha256)".
Echo attempted_task_sha256 "$([string]$readMission.task_completion_contract.required_task_sha256)".
"@
Set-Content -LiteralPath $promptPath -Value $mapperPrompt -Encoding UTF8
$mapperAdapter=Invoke-FakeAdapter general-success $readMission.mission_id $readMission.mission_revision $readMission.policy.fingerprint $mapperQueueHash $repo $readMission.model_selection_assurance
$mapperGeneralEvidence=Get-TsfGeneralResultV2Evidence -MissionId $readMission.mission_id -MissionRevision $readMission.mission_revision -RunId $mapperRunId -Adapter $mapperAdapter.result -TaskCompletionContract $readMission.task_completion_contract
Assert-Case 'VS-GENERAL-001' evidence ([bool]$mapperGeneralEvidence.semantic_success) 'structured general-result fixture is independently fulfilled'
$unableAdapter=Invoke-FakeAdapter general-unable $readMission.mission_id $readMission.mission_revision $readMission.policy.fingerprint $mapperQueueHash $repo $readMission.model_selection_assurance
$unableEvidence=Get-TsfGeneralResultV2Evidence -MissionId $readMission.mission_id -MissionRevision $readMission.mission_revision -RunId $mapperRunId -Adapter $unableAdapter.result -TaskCompletionContract $readMission.task_completion_contract
Assert-Case 'VS-GENERAL-002' evidence ([bool]$unableAdapter.result.transport_success-and![bool]$unableEvidence.semantic_success-and[string]$unableEvidence.outcome_disposition-eq'UNABLE_TO_PERFORM') 'transport-successful inability is not semantic fulfillment'
$missingAdapter=Invoke-FakeAdapter general-missing $readMission.mission_id $readMission.mission_revision $readMission.policy.fingerprint $mapperQueueHash $repo $readMission.model_selection_assurance
$missingEvidence=Get-TsfGeneralResultV2Evidence -MissionId $readMission.mission_id -MissionRevision $readMission.mission_revision -RunId $mapperRunId -Adapter $missingAdapter.result -TaskCompletionContract $readMission.task_completion_contract
Assert-Case 'VS-GENERAL-003' evidence ([bool]$missingAdapter.result.transport_success-and![bool]$missingEvidence.semantic_success-and@($missingEvidence.missing_deliverables)-contains'requested_answer') 'missing required deliverable is not semantic fulfillment'
$mapperPreflightPath=Join-Path $mapperRoot 'preflight.json';Write-Json ([pscustomobject]@{mission_id=$readMission.mission_id;preflight_approved=$true}) $mapperPreflightPath
$mapperRolePath=Join-Path $mapperRoot 'role.json';Write-Json ([pscustomobject]@{role_id=$readMission.worker_role;role_preflight_approved=$true}) $mapperRolePath
$mapperWorkerPath=Join-Path $mapperRoot 'worker.json';Write-Json ([pscustomobject]@{mission_id=$readMission.mission_id;mission_revision=$readMission.mission_revision;run_id=$mapperRunId;result_id=$mapperRunId;files_touched=@();general_result_evidence=$mapperGeneralEvidence;tests=@([pscustomobject]@{test_id='hq-dispatch-general-result-v2';status='PASS';observed='bound fulfilled general-result fixture';evidence=[string]$readMission.task_completion_contract.task_completion_contract_identity_sha256});approval_use=@()}) $mapperWorkerPath
$mapperVerifier=[pscustomobject]@{mission_id=$readMission.mission_id;mission_revision=$readMission.mission_revision;run_id=$mapperRunId;result_id=$mapperRunId;verdict='GREEN';verified=$true;general_result_evidence=$mapperGeneralEvidence}
$mapperVerifierIdentity=Test-TsfCanonicalVerifierIdentity $mapperVerifier $readMission $mapperRunId
Assert-Case 'VS-VERIFIER-IDENTITY-001' evidence $mapperVerifierIdentity.valid 'verifier identity is fully bound to durable mission and result'
$wrongRevisionVerifier=Copy-Object $mapperVerifier;$wrongRevisionVerifier.mission_revision=0
Assert-Case 'VS-VERIFIER-IDENTITY-002' evidence (!(Test-TsfCanonicalVerifierIdentity $wrongRevisionVerifier $readMission $mapperRunId).valid) 'revision-zero verifier identity fails closed'
$mapperVerifierPath=Join-Path $mapperRoot 'verifier.json';Write-Json $mapperVerifier $mapperVerifierPath
$mapperMissionPath=Join-Path $mapperRoot 'mission.json';Write-Json $readQueueCheck.effective_mission $mapperMissionPath
$mapperInstructionPath=Join-Path $mapperRoot 'instruction.json';Write-Json $readQueue.worker_instruction_packet $mapperInstructionPath
$mapperPacket=Write-TsfKernelPreservationPacket -MissionPath $mapperMissionPath -PreflightResultPath $mapperPreflightPath -RolePreflightPath $mapperRolePath -WorkerInstructionPath $mapperInstructionPath -WorkerResultPath $mapperWorkerPath -VerifierResultPath $mapperVerifierPath -AdapterResultPath $mapperAdapter.result_path -EventJournalPath $mapperAdapter.result.event_journal_path -QueueDocumentPath $mapperQueuePath -PromptPath $promptPath -StderrPath (Join-Path $mapperAdapter.out 'se.log') -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $mapperRunId -DurableMission $readMission -TestOnlyAllowSyntheticProducerRegistry
$mapperDescriptor=Get-TsfPreservationPacketDescriptor $mapperPacket.packet_file $readMission.mission_id $readMission.mission_revision
$mapperRuntime=[pscustomobject][ordered]@{schema_version='tsf_authenticated_runtime_evidence_v1';result_id=$mapperRunId;queue_document_path=(Join-Path $mapperPacket.packet_directory 'qd.json');adapter_result_path=(Join-Path $mapperPacket.packet_directory 'ar.json');preflight_path=(Join-Path $mapperPacket.packet_directory 'pf.json');role_preflight_path=(Join-Path $mapperPacket.packet_directory 'rp.json');worker_result_path=(Join-Path $mapperPacket.packet_directory 'wr.json');verifier_result_path=(Join-Path $mapperPacket.packet_directory 'vr.json');preservation_packet_path=$mapperPacket.packet_file;starting_head=$head;base_head=$head;dirty_before=$true;effective_effort='HIGH';effective_effort_source='CALLER_REPORTED';proposed_next_action='Verify caller effort cannot become authority.';created_at=[datetimeoffset]::UtcNow.ToString('o')}
$mapperResult=ConvertTo-TsfDurableResultEnvelope $readMission $mapperRuntime $repo -TestOnlyAllowSyntheticProducerRegistry
Assert-Case 'VS-EFFORT-013' effort ($mapperResult.actual_reasoning_effort-eq'UNKNOWN'-and$mapperResult.effort_evidence.effective_effort_source-eq'NOT_EXPOSED'-and$mapperResult.evidence_bindings.effort-eq'UNVERIFIED') 'caller RuntimeEvidence effort cannot be promoted by mapper'
Assert-Case 'VS-USAGE-008' usage ($mapperResult.usage_evidence.evidence_classification-eq'NATIVE_OBSERVED'-and$mapperResult.usage_evidence.total_tokens-eq10-and$mapperResult.evidence_bindings.usage-eq'NATIVE_OBSERVED') 'mapper retains only journal-bound native usage'
$substituteAdapter=Join-Path $mapperRoot 'substitute-adapter.json';Copy-Item -LiteralPath $mapperRuntime.adapter_result_path -Destination $substituteAdapter;$substituteEvidence=Copy-Object $mapperRuntime;$substituteEvidence.adapter_result_path=$substituteAdapter
Assert-Case 'VS-PROVENANCE-001' provenance (Throws{ConvertTo-TsfDurableResultEnvelope $readMission $substituteEvidence $repo -TestOnlyAllowSyntheticProducerRegistry}) 'substituted adapter path rejected before promotion'
$badProducer=Copy-Object $mapperDescriptor;$badProducer.manifest.artifacts|Where-Object logical_type -eq 'adapter_result'|ForEach-Object{$_.producer='caller'}
Assert-Case 'VS-PROVENANCE-002' provenance (Throws{Get-TsfManifestBoundArtifact $badProducer 'adapter_result' 'ar.json' 'codex_app_server_adapter' @('ADAPTER_OBSERVED')}) 'wrong producer rejected'
$badType=Copy-Object $mapperDescriptor;($badType.manifest.artifacts|Where-Object logical_type -eq 'adapter_result').logical_type='caller_result'
Assert-Case 'VS-PROVENANCE-003' provenance (Throws{Get-TsfManifestBoundArtifact $badType 'adapter_result' 'ar.json' 'codex_app_server_adapter' @('ADAPTER_OBSERVED')}) 'missing logical type rejected'
$badHash=Copy-Object $mapperDescriptor;($badHash.manifest.artifacts|Where-Object logical_type -eq 'adapter_result').sha256='0'*64
Assert-Case 'VS-PROVENANCE-004' provenance (Throws{Get-TsfManifestBoundArtifact $badHash 'adapter_result' 'ar.json' 'codex_app_server_adapter' @('ADAPTER_OBSERVED')}) 'wrong manifest hash rejected'
$badPath=Copy-Object $mapperDescriptor;($badPath.manifest.artifacts|Where-Object logical_type -eq 'adapter_result').path='../ar.json'
Assert-Case 'VS-PROVENANCE-005' provenance (Throws{Get-TsfManifestBoundArtifact $badPath 'adapter_result' 'ar.json' 'codex_app_server_adapter' @('ADAPTER_OBSERVED')}) 'path outside packet rejected'
Assert-Case 'VS-PROVENANCE-006' provenance (Throws{Get-TsfPreservationPacketDescriptor $mapperPacket.packet_file 'wrong-mission' 1}) 'manifest mission mismatch rejected'
Assert-Case 'VS-PROVENANCE-007' provenance (Throws{Get-TsfPreservationPacketDescriptor $mapperPacket.packet_file $readMission.mission_id 2}) 'manifest revision mismatch rejected'
$wrongRun=Copy-Object $mapperRuntime;$wrongRun.result_id='wrong-run'
Assert-Case 'VS-PROVENANCE-008' provenance (Throws{ConvertTo-TsfDurableResultEnvelope $readMission $wrongRun $repo -TestOnlyAllowSyntheticProducerRegistry}) 'manifest run identity mismatch rejected'
$registryRecord=@($mapperDescriptor.manifest.artifacts|Where-Object logical_type -eq 'producer_registry')
$historicalTestRegistry=Get-Content (Join-Path $mapperPacket.packet_directory 'pr.json') -Raw|ConvertFrom-Json
Assert-Case 'VS-PRODUCER-001' provenance ($registryRecord.Count-eq1-and$historicalTestRegistry.test_only) 'explicit synthetic injection is recorded as test-only producer provenance'
Assert-Case 'VS-PRODUCER-002' provenance (!(Test-TsfProducerEvidenceRegistry (Join-Path $mapperPacket.packet_directory 'pr.json') $readMission.mission_id $readMission.mission_revision $mapperRunId $readMission.policy.fingerprint $mapperQueueHash).valid) 'test-only registry cannot enter normal preservation'
$unregisteredRun="unregistered-producer-$testRunNonce"
Assert-Case 'VS-PRODUCER-003' provenance (ThrowsLike {Write-TsfKernelPreservationPacket -MissionPath $mapperMissionPath -PreflightResultPath $mapperPreflightPath -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $unregisteredRun -DurableMission $readMission} 'PRODUCER_EVIDENCE_REGISTRY_REQUIRED') 'arbitrary preflight cannot become KERNEL_OBSERVED'

$producerRun="normal-producer-registry-$testRunNonce";$producerL=New-TsfRuntimeStoragePlan (Get-TsfCanonicalRuntimeRoot) $readMission.mission_id $readMission.mission_revision $producerRun -Layout lifecycle_control
New-Item -ItemType Directory -Force $producerL.directory|Out-Null
Copy-Item $mapperMissionPath $producerL.artifacts.mission;Copy-Item $mapperPreflightPath $producerL.artifacts.preflight
$producerRegistry=$producerL.artifacts.producer_registry
$producerCapability=New-TsfTestOnlyProducerCapability $readMission.mission_id $readMission.mission_revision $producerRun $readMission.policy.fingerprint ('0'*64) $repo $branch $repo
New-TsfProducerEvidenceRegistry $producerRegistry $producerCapability|Out-Null
$otherProducerCapability=New-TsfTestOnlyProducerCapability $readMission.mission_id $readMission.mission_revision $producerRun $readMission.policy.fingerprint ('0'*64) $repo $branch $repo
$producerRegistryReopenBlocked=ThrowsLike {New-TsfProducerEvidenceRegistry $producerRegistry $otherProducerCapability|Out-Null} 'PRODUCER_EVIDENCE_REGISTRY_IMMUTABLE_CONFLICT'
Register-TsfProducerEvidence $producerRegistry mission $producerL.artifacts.mission $producerCapability|Out-Null
Register-TsfProducerEvidence $producerRegistry preflight $producerL.artifacts.preflight $producerCapability|Out-Null
$arbitraryAdapter=Join-Path $mapperRoot 'arbitrary-adapter.json';Copy-Item $mapperAdapter.result_path $arbitraryAdapter -Force
$arbitraryJournal=Join-Path $mapperRoot 'arbitrary-journal.jsonl';Copy-Item $mapperAdapter.result.event_journal_path $arbitraryJournal -Force
$arbitraryVerifier=Join-Path $mapperRoot 'arbitrary-verifier.json';Copy-Item $mapperVerifierPath $arbitraryVerifier -Force
$producerP=New-TsfRuntimeStoragePlan (Get-TsfCanonicalRuntimeRoot) $readMission.mission_id $readMission.mission_revision $producerRun -Layout preservation
$arbitraryAdapterBlocked=ThrowsLike {Write-TsfKernelPreservationPacket -MissionPath $producerL.artifacts.mission -PreflightResultPath $producerL.artifacts.preflight -AdapterResultPath $arbitraryAdapter -ProducerRegistryPath $producerRegistry -ProducerCapability $producerCapability -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $producerRun -DurableMission $readMission -TestOnlyAllowSyntheticProducerRegistry} 'UNREGISTERED_CALLER_EVIDENCE: adapter_result';if(Test-Path $producerP.staging_directory){Remove-Item $producerP.staging_directory -Recurse -Force}
$arbitraryJournalBlocked=ThrowsLike {Write-TsfKernelPreservationPacket -MissionPath $producerL.artifacts.mission -PreflightResultPath $producerL.artifacts.preflight -EventJournalPath $arbitraryJournal -ProducerRegistryPath $producerRegistry -ProducerCapability $producerCapability -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $producerRun -DurableMission $readMission -TestOnlyAllowSyntheticProducerRegistry} 'UNREGISTERED_CALLER_EVIDENCE: event_journal';if(Test-Path $producerP.staging_directory){Remove-Item $producerP.staging_directory -Recurse -Force}
$arbitraryVerifierBlocked=ThrowsLike {Write-TsfKernelPreservationPacket -MissionPath $producerL.artifacts.mission -PreflightResultPath $producerL.artifacts.preflight -VerifierResultPath $arbitraryVerifier -ProducerRegistryPath $producerRegistry -ProducerCapability $producerCapability -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $producerRun -DurableMission $readMission -TestOnlyAllowSyntheticProducerRegistry} 'UNREGISTERED_CALLER_EVIDENCE: verifier_result';if(Test-Path $producerP.staging_directory){Remove-Item $producerP.staging_directory -Recurse -Force}
$wrongCallerPathBlocked=ThrowsLike {Write-TsfKernelPreservationPacket -MissionPath $mapperMissionPath -PreflightResultPath $producerL.artifacts.preflight -ProducerRegistryPath $producerRegistry -ProducerCapability $producerCapability -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $producerRun -DurableMission $readMission -TestOnlyAllowSyntheticProducerRegistry} 'CALLER_EVIDENCE_PATH_NOT_REGISTERED: mission';if(Test-Path $producerP.staging_directory){Remove-Item $producerP.staging_directory -Recurse -Force}
Assert-Case 'VS-PRODUCER-004' provenance $arbitraryAdapterBlocked 'arbitrary adapter cannot become ADAPTER_OBSERVED'
Assert-Case 'VS-PRODUCER-005' provenance $arbitraryJournalBlocked 'arbitrary journal cannot become NATIVE_OBSERVED'
Assert-Case 'VS-PRODUCER-006' provenance $arbitraryVerifierBlocked 'arbitrary verifier cannot become VERIFIER_OBSERVED'
Assert-Case 'VS-PRODUCER-007' provenance $wrongCallerPathBlocked 'wrong caller path rejected'

function Test-BadProducerRegistry([string]$Name,[scriptblock]$Mutate,[string]$MissionId=$readMission.mission_id,[string]$RunId=$producerRun){
    $copy=Join-Path $mapperRoot "bad-registry-$Name.json";$value=Get-Content $producerRegistry -Raw|ConvertFrom-Json;&$Mutate $value;Write-Json $value $copy
    !(Test-TsfProducerEvidenceRegistry $copy $MissionId $readMission.mission_revision $RunId $readMission.policy.fingerprint ('0'*64)).valid
}
Assert-Case 'VS-PRODUCER-008' provenance (Test-BadProducerRegistry producer {param($r)$r.artifacts[0].producer='caller'}) 'wrong registered producer rejected'
Assert-Case 'VS-PRODUCER-009' provenance (Test-BadProducerRegistry type {param($r)$r.artifacts[0].logical_type='adapter_result'}) 'wrong registered logical type rejected'
Assert-Case 'VS-PRODUCER-010' provenance (Test-BadProducerRegistry path {param($r)$r.artifacts[0].canonical_relative_path='../outside.json'}) 'wrong registered path rejected'
Assert-Case 'VS-PRODUCER-011' provenance (Test-BadProducerRegistry mission {param($r)} 'wrong-mission') 'wrong registry mission binding rejected'
Assert-Case 'VS-PRODUCER-012' provenance (Test-BadProducerRegistry run {param($r)} $readMission.mission_id 'wrong-run') 'wrong registry run binding rejected'
$preflightBackup=Join-Path $mapperRoot 'registered-preflight.backup';Copy-Item $producerL.artifacts.preflight $preflightBackup -Force;Add-Content $producerL.artifacts.preflight 'tamper';$changedRegistry=Test-TsfProducerEvidenceRegistry $producerRegistry $readMission.mission_id $readMission.mission_revision $producerRun $readMission.policy.fingerprint ('0'*64) -AllowTestOnly;Copy-Item $preflightBackup $producerL.artifacts.preflight -Force
Assert-Case 'VS-PRODUCER-013' provenance (!$changedRegistry.valid-and($changedRegistry.errors-join' ')-match'bytes changed') 'registered artifact changed bytes fail closed'
Assert-Case 'VS-PRODUCER-014' provenance $producerRegistryReopenBlocked 'different caller invocation cannot reopen an orchestrator-owned registry'

$compactRoot=Get-TsfCanonicalRuntimeRoot
$longStorageMission='mission-'+('m'*500);$longStorageRun='result-'+('r'*500);$longPlan=New-TsfRuntimeStoragePlan $compactRoot $longStorageMission 99 $longStorageRun
$longPlan2=New-TsfRuntimeStoragePlan $compactRoot $longStorageMission 99 $longStorageRun
Assert-Case 'VS-STORAGE-001' storage ($longPlan.mission_identity.short_key-eq$longPlan2.mission_identity.short_key-and$longPlan.run_identity.short_key-eq$longPlan2.run_identity.short_key) 'long mission/result identities map deterministically'
Assert-Case 'VS-STORAGE-002' storage ($longPlan.mission_identity.short_key-match'^[a-z2-7]{32}$'-and$longPlan.run_identity.short_key-match'^[a-z2-7]{32}$'-and$longPlan.mission_identity.effective_security_bits-eq160) 'fixed Base32 keys retain 160 digest bits'
Assert-Case 'VS-STORAGE-003' storage ($longPlan.directory-notmatch[regex]::Escape($longStorageMission)-and$longPlan.directory-notmatch[regex]::Escape($longStorageRun)) 'raw logical identifiers never enter runtime paths'
Assert-Case 'VS-STORAGE-004' storage ($longPlan.budget.valid-and$longPlan.budget.maximum_path_length-le225) "all planned paths fit hard/target budgets; max $($longPlan.budget.maximum_path_length)"
$catalog=Get-TsfRuntimeArtifactCatalog;Assert-Case 'VS-STORAGE-005' storage ($catalog.manifest-eq'manifest.json'-and$catalog.mission-eq'm.json'-and$catalog.worker_result-eq'wr.json'-and$catalog.preservation_packet-eq'pp.json'-and$catalog.durable_result-eq'dr.json'-and$catalog.event_journal-eq'ej.jsonl') 'fixed compact artifact catalog'
$completePlan=New-TsfCompleteRuntimePathPlan $longStorageMission 99 $longStorageRun
$completePlan2=New-TsfCompleteRuntimePathPlan ('other-'+('z'*900)) 99 ('other-'+('y'*900))
Assert-Case 'VS-PATHPLAN-001' storage ($completePlan.budget.valid-and$completePlan.maximum_path_length-le225-and$completePlan.maximum_logical_type) "complete plan max $($completePlan.maximum_path_length) at $($completePlan.maximum_logical_type)"
Assert-Case 'VS-PATHPLAN-002' storage (@($completePlan.required_categories|Where-Object{$type=$_;@($completePlan.paths|Where-Object{$_.logical_type-eq$type}).Count-ne1}).Count-eq0) 'transition temporary backup recovery registry and receipt categories planned'
Assert-Case 'VS-PATHPLAN-003' storage ((Split-Path -Leaf $completePlan.queue_plan.artifacts.transition_01)-eq't01.json'-and(Split-Path -Leaf $completePlan.queue_plan.artifacts.transition_08)-eq't08.json') 'transition evidence uses fixed compact type codes'
Assert-Case 'VS-PATHPLAN-004' storage ($completePlan.maximum_path_length-eq$completePlan2.maximum_path_length) 'long mission run role branch and state text cannot lengthen fixed path plan'
$transitionSource=(Get-Content (Join-Path $repo 'tools\Invoke-TsfMissionLifecycle.ps1') -Raw)+(Get-Content (Join-Path $repo 'tools\Invoke-TsfMissionQueueForegroundExecutor.ps1') -Raw)
$unplannedTransitionSourceHit=$transitionSource-match'transition_\$\{'-or$transitionSource-match'transition_(inbox|drafted|preflight|approved|worker|postrun)'
Assert-Case 'VS-PATHPLAN-005' storage (!$unplannedTransitionSourceHit) 'no active canonical transition write bypasses compact plan'
$queueArtifactTypes=@('queue.preflight','queue.role_preflight','queue.worker_instruction','queue.worker_result','queue.verifier_result','queue.context_update','queue.registry_mission','queue.kernel_state.s1')
Assert-Case 'VS-PATHPLAN-006' storage (@($queueArtifactTypes|Where-Object{$type=$_;@($completePlan.paths|Where-Object{$_.logical_type-eq$type}).Count-ne1}).Count-eq0-and[string]$completePlan.registry_mission_path-eq[string](@($completePlan.paths|Where-Object{$_.logical_type-eq'queue.registry_mission'})[0].path)) 'all active queue-executor artifacts and admission registry snapshot use exact planned paths'
$queueExecutorSource=Get-Content (Join-Path $repo 'tools\Invoke-TsfMissionQueueForegroundExecutor.ps1') -Raw
Assert-Case 'VS-PATHPLAN-007' storage ($queueExecutorSource-notmatch'Join-Path \$OutDirectory "(worker_result|verifier_result|preflight_result|role_permission_preflight|worker_instruction|context_capsule\.updated)') 'normal queue-executor fixed artifacts cannot bypass the typed plan'

$productionQueue=Resolve-TsfQueueAuthority
$alternateQueue=Join-Path $runtimeRoot 'queue-authority-test';$normalAlternateRejected=ThrowsLike {Resolve-TsfQueueAuthority $alternateQueue} 'NONCANONICAL_QUEUE_ROOT_REJECTED';$testQueueAuthority=Resolve-TsfQueueAuthority $alternateQueue -TestOnlyAllowAlternateQueueRoot
Assert-Case 'VS-QUEUE-AUTH-001' queue ($productionQueue.kind-eq'PRODUCTION'-and[string]$productionQueue.root-eq(Get-TsfCanonicalProductionQueueRoot)) 'production queue root derives internally from queue policy'
Assert-Case 'VS-QUEUE-AUTH-002' queue $normalAlternateRejected 'normal alternate QueueRoot rejected'
Assert-Case 'VS-QUEUE-AUTH-003' queue ($testQueueAuthority.kind-eq'TEST_ONLY'-and$testQueueAuthority.identity_sha256-ne$productionQueue.identity_sha256) 'alternate queue accepted only through explicit isolated test capability'

$compactInputRoot=Join-Path $runtimeRoot 'compact-input';New-Item -ItemType Directory -Force $compactInputRoot|Out-Null
$compactMissionPath=Join-Path $compactInputRoot 'm.json';Write-Json $readQueueCheck.effective_mission $compactMissionPath
$compactPreflight=Join-Path $compactInputRoot 'pf.json';Write-Json ([pscustomobject]@{mission_id=$readMission.mission_id;verdict='GREEN';preflight_approved=$true}) $compactPreflight
$compactRole=Join-Path $compactInputRoot 'rp.json';Write-Json ([pscustomobject]@{mission_id=$readMission.mission_id;role_id=$readMission.worker_role;role_preflight_approved=$true}) $compactRole
$compactInstruction=Join-Path $compactInputRoot 'wi.json';Write-Json $readQueue.worker_instruction_packet $compactInstruction
$compactWorker=Join-Path $compactInputRoot 'wr.json';Write-Json ([pscustomobject]@{mission_id=$readMission.mission_id;files_touched=@();tests=@();approval_use=@()}) $compactWorker
$compactVerifier=Join-Path $compactInputRoot 'vr.json';Write-Json ([pscustomobject]@{mission_id=$readMission.mission_id;verdict='GREEN';verified=$true}) $compactVerifier
$compactRunId="compact-manifest-$testRunNonce"
$compactPacket=Write-TsfKernelPreservationPacket -MissionPath $compactMissionPath -PreflightResultPath $compactPreflight -RolePreflightPath $compactRole -WorkerInstructionPath $compactInstruction -WorkerResultPath $compactWorker -VerifierResultPath $compactVerifier -AdapterResultPath $mapperAdapter.result_path -EventJournalPath $mapperAdapter.result.event_journal_path -OutputDirectory $compactRoot -RunId $compactRunId -DurableMission $readMission -TestOnlyAllowSyntheticProducerRegistry
$compactManifest=Get-Content $compactPacket.manifest_path -Raw|ConvertFrom-Json;$compactManifestCheck=Test-TsfRuntimeStorageManifest $compactManifest $compactPacket.packet_directory $readMission.mission_id $readMission.mission_revision $compactRunId
Assert-Case 'VS-STORAGE-006' storage ($compactManifestCheck.valid-and$compactManifest.mission_identity_sha256.Length-eq64-and$compactManifest.run_identity_sha256.Length-eq64) 'complete compact manifest validates full SHA-256 identities'
Assert-Case 'VS-STORAGE-007' storage (@($compactManifest.artifacts|Where-Object{!(Test-Path -LiteralPath (Join-Path $compactPacket.packet_directory $_.path))}).Count-eq0) 'manifest binds every compact artifact to observed bytes'
$manifestMismatch=Copy-Object $compactManifest;$manifestMismatch.mission_identity_sha256='0'*64;$mismatchCheck=Test-TsfRuntimeStorageManifest $manifestMismatch $compactPacket.packet_directory
Assert-Case 'VS-STORAGE-008' storage (!$mismatchCheck.valid-and@($mismatchCheck.errors|Where-Object{$_-match'collision|identity'}).Count-gt0) 'short-key/full-digest collision mismatch fails closed'
$legacyRoot=Join-Path $runtimeRoot 'legacy-read-only';$legacyPacket=Join-Path $legacyRoot 'packet\preservation_packet.json';Write-Json ([pscustomobject]@{mission_id=$readMission.mission_id;final_decision='GREEN'}) $legacyPacket
$legacyDescriptor=Get-TsfPreservationPacketDescriptor $legacyPacket $readMission.mission_id $readMission.mission_revision
Assert-Case 'VS-STORAGE-009' storage ($legacyDescriptor.layout-eq'LEGACY_READ_ONLY') 'historical preservation packet remains readable only through compatibility descriptor'
$legacyResult=Copy-Object $mapperResult;$legacyResult.result_id="legacy-write-prohibited-$testRunNonce";$legacyResult.preservation_evidence.packet_path=$legacyPacket;$legacyResult.preservation_evidence.packet_sha256=Get-Hash $legacyPacket;$legacyResultPath=Join-Path $mapperRoot 'legacy-result.json';Write-Json $legacyResult $legacyResultPath
$legacyRegistry=Join-Path $runtimeRoot 'legacy-registry';Write-Json $readMission (Join-Path $legacyRegistry 'm.json');$legacyQueueRoot=Join-Path $runtimeRoot 'legacy-queue';$legacyQueuePath=Join-Path $legacyQueueRoot 'postrun_pending\m.json';Write-Json $readQueue $legacyQueuePath;$legacyLedger=Join-Path $runtimeRoot 'legacy-ledger.json';Write-Json ([pscustomobject]@{schema_version=1;ledger_id='legacy';approvals=@()}) $legacyLedger
$legacyBefore=Get-TsfRuntimeSha256Text ((Get-ChildItem -LiteralPath $legacyRoot -Recurse -File|Sort-Object FullName|ForEach-Object{"$($_.FullName)|$(Get-Hash $_.FullName)"})-join"`n")
$legacyAdmissionBlocked=ThrowsLike {Get-TsfAdmissionDecision $legacyResultPath $legacyRegistry (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $legacyLedger $legacyQueuePath $legacyQueueRoot -UnsupportedDevelopmentMode -TestOnlyAllowAlternateQueueRoot} 'LEGACY_PACKET_WRITE_PROHIBITED'
$legacyDurableBlocked=ThrowsLike {Add-TsfRuntimeDurableResult $legacyResult $legacyPacket} 'compact V1|LEGACY_PACKET_WRITE_PROHIBITED'
$legacyAfter=Get-TsfRuntimeSha256Text ((Get-ChildItem -LiteralPath $legacyRoot -Recurse -File|Sort-Object FullName|ForEach-Object{"$($_.FullName)|$(Get-Hash $_.FullName)"})-join"`n")
Assert-Case 'VS-LEGACY-001' legacy $legacyAdmissionBlocked 'legacy admission/transaction write rejected'
Assert-Case 'VS-LEGACY-002' legacy $legacyAdmissionBlocked 'legacy conflict write cannot be reached'
Assert-Case 'VS-LEGACY-003' legacy $legacyDurableBlocked 'legacy durable-result write rejected'
Assert-Case 'VS-LEGACY-004' legacy ($legacyBefore-eq$legacyAfter-and!(Test-Path (Join-Path $legacyRoot 'r'))) 'legacy directory remains byte-for-byte unchanged'
Assert-Case 'VS-STORAGE-010' storage ((Split-Path -Leaf $compactPacket.packet_file)-eq'pp.json'-and$compactPacket.packet_directory-match'[\\/]p[\\/][a-z2-7]{32}[\\/][a-z2-7]{32}$') 'new preservation writes enforce compact V1 layout'
$tempRun="temp-preservation-failure-$testRunNonce";$tempPlan=New-TsfRuntimeStoragePlan $compactRoot $readMission.mission_id $readMission.mission_revision $tempRun;$tempPreservationFailed=Throws{Write-TsfKernelPreservationPacket -MissionPath $compactMissionPath -PreflightResultPath $compactPreflight -OutputDirectory $compactRoot -RunId $tempRun -DurableMission $readMission -TestFault TEMP_WRITE -TestOnlyAllowSyntheticProducerRegistry}
Assert-Case 'VS-STORAGE-011' storage ($tempPreservationFailed-and!(Test-Path $tempPlan.directory)-and!(Test-Path $tempPlan.staging_directory)) 'temporary preservation failure occurs before any packet write'
$recoveryRun="finalization-recovery-$testRunNonce";$recoveryPlan=New-TsfRuntimeStoragePlan $compactRoot $readMission.mission_id $readMission.mission_revision $recoveryRun;$finalPreservationFailed=Throws{Write-TsfKernelPreservationPacket -MissionPath $compactMissionPath -PreflightResultPath $compactPreflight -WorkerResultPath $compactWorker -VerifierResultPath $compactVerifier -OutputDirectory $compactRoot -RunId $recoveryRun -DurableMission $readMission -TestFault FINALIZE -TestOnlyAllowSyntheticProducerRegistry}
$recoveredPacket=Write-TsfKernelPreservationPacket -MissionPath $compactMissionPath -PreflightResultPath $compactPreflight -WorkerResultPath $compactWorker -VerifierResultPath $compactVerifier -OutputDirectory $compactRoot -RunId $recoveryRun -DurableMission $readMission -TestOnlyAllowSyntheticProducerRegistry
Assert-Case 'VS-STORAGE-012' storage ($finalPreservationFailed-and$recoveredPacket.recovered_from_staging-and(Test-Path $recoveryPlan.directory)-and!(Test-Path $recoveryPlan.staging_directory)) 'verified staging packet reconciles idempotently after finalization failure'

$compactResult=Set-GeneralResultFixtureBinding (Copy-Object $mapperResult) $readMission $compactRunId;$compactResult.preservation_evidence.packet_path=$compactPacket.packet_file;$compactResult.preservation_evidence.packet_sha256=Get-Hash $compactPacket.packet_file
$compactDurable=Add-TsfRuntimeDurableResult $compactResult $compactPacket.packet_file;Assert-Case 'VS-STORAGE-013' storage ((Split-Path -Leaf $compactDurable.path)-eq'dr.json'-and(Test-Path $compactDurable.path)) 'durable result is inserted transactionally at the compact canonical address'
$compactAdmissionRoot=Join-Path $runtimeRoot 'compact-admission';$compactQueueRoot=Join-Path $compactAdmissionRoot 'queue';$compactQueuePath=Join-Path $compactQueueRoot 'postrun_pending\m.json';Write-Json $readQueue $compactQueuePath;$compactRegistry=Join-Path $compactAdmissionRoot 'registry';Write-Json $readMission (Join-Path $compactRegistry 'm.json');$compactLedger=Join-Path $compactAdmissionRoot 'ledger.json';Write-Json ([pscustomobject]@{schema_version=1;ledger_id='compact-empty';approvals=@()}) $compactLedger
$compactAdmission=Get-TsfAdmissionDecision $compactDurable.path $compactRegistry (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $compactLedger $compactQueuePath $compactQueueRoot -UnsupportedDevelopmentMode -TestOnlyAllowAlternateQueueRoot
Assert-Case 'VS-STORAGE-014' storage ($compactAdmission.status-eq'ADMITTED_WITH_CAVEATS'-and(Test-TsfKernelPathInside $compactAdmission.admission_receipt_path $compactPacket.packet_directory)-and(Test-Path $compactAdmission.transaction_receipt_path)) 'receipts are transactionally bound inside verified compact preservation packet'
Assert-Case 'VS-QUEUE-AUTH-004' queue ($compactAdmission.queue_authority_kind-eq'TEST_ONLY'-and!$compactAdmission.production_admission) 'test queue evidence cannot be labeled production admission'
$rawV1AuthorityHits=@(rg -n "\.codex-local\\(mission-queue-foreground-executor|mission-lifecycle)|safeMissionId.*OutDirectory|preservation_store 'r'" (Join-Path $repo 'tools') 2>$null|Where-Object{$_-notmatch'LEGACY_PACKET_WRITE_PROHIBITED'})
Assert-Case 'VS-STORAGE-015' storage ($rawV1AuthorityHits.Count-eq0) ($rawV1AuthorityHits-join'; ')
$queueControlPlan=New-TsfRuntimeStoragePlan $compactRoot $longStorageMission 99 $longStorageRun -Layout queue_control;$lifecycleControlPlan=New-TsfRuntimeStoragePlan $compactRoot $longStorageMission 99 $longStorageRun -Layout lifecycle_control
Assert-Case 'VS-CONTROL-001' storage ($queueControlPlan.directory-match'[\\/]q[\\/][a-z2-7]{32}[\\/][a-z2-7]{32}$'-and$queueControlPlan.directory-notmatch[regex]::Escape($longStorageMission)) 'queue executor control plan is compact and identifier-independent'
Assert-Case 'VS-CONTROL-002' storage ($lifecycleControlPlan.directory-match'[\\/]l[\\/][a-z2-7]{32}[\\/][a-z2-7]{32}$'-and$lifecycleControlPlan.directory-notmatch[regex]::Escape($longStorageMission)) 'lifecycle control plan is compact and identifier-independent'

$sourceWorktreeName='Thousand-Sunny-Fleet-durable-contract-v1-20260710'
$registeredWorktrees=@(& git -C $repo worktree list --porcelain | ForEach-Object { if($_.StartsWith('worktree ')){ $_.Substring(9) } })
$sourceWorktree=@($registeredWorktrees | Where-Object { (Split-Path -Leaf $_) -eq $sourceWorktreeName } | Select-Object -First 1)[0]
$recoveryRecord=Join-Path $sourceWorktree '.codex-local\preservation\transactional-admission-resume-v1-20260711\synthetic-recovery.json'
Assert-Case 'VS-RECOVERY-001' recovery ((Test-Path -LiteralPath $recoveryRecord)-and((Get-Content -LiteralPath $recoveryRecord -Raw|ConvertFrom-Json).recovery_action-eq'RECREATE_EXACT_SYNTHETIC_FIXTURE_ROOT')) 'previous failed scratch transaction preserved and deterministically recreated'

function New-AdmissionFixture {
    param([string]$Name,[string]$ResultId,[string]$MissionId="synthetic-transaction-$Name-$testRunNonce",[int]$PreservationPadding=0,[int]$PacketFolderPadding=40)
    $ResultId=if(($ResultId.Length+33)-gt160){$ResultId.Substring(0,126)+"-$testRunNonce"}else{"$ResultId-$testRunNonce"};$mission=Copy-Object $readMission;$mission.mission_id=$MissionId;$mission.created_at=[datetimeoffset]::UtcNow.ToString('o');$mission.expires_at=[datetimeoffset]::UtcNow.AddMinutes(30).ToString('o')
    $root=Join-Path $runtimeRoot "transactional\$Name";$queueRoot=Join-Path $root 'queue';$queuePath=Join-Path $queueRoot 'postrun_pending\m.json';$document=ConvertTo-TsfCanonicalExecutionArtifacts $mission $repo;Write-Json $document $queuePath
    $registry=Join-Path $root 'registry';Write-Json $mission (Join-Path $registry 'm.json')
    $effective=(Test-TsfCanonicalQueueDocument $document $mission $repo).effective_mission;$missionPath=Join-Path $root 'm.json';Write-Json $effective $missionPath;$preflightPath=Join-Path $root 'pf.json';Write-Json ([pscustomobject]@{mission_id=$mission.mission_id;verdict='GREEN';preflight_approved=$true}) $preflightPath
    $packet=Write-TsfKernelPreservationPacket -MissionPath $missionPath -PreflightResultPath $preflightPath -QueueDocumentPath $queuePath -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $ResultId -DurableMission $mission -TestOnlyAllowSyntheticProducerRegistry
    $result=Set-GeneralResultFixtureBinding (Copy-Object $mapperResult) $mission $ResultId;$result.mission_content_hash=Get-TsfContractJsonHash $mission;$result.policy_fingerprint=$mission.policy.fingerprint;$result.preservation_evidence.packet_path=$packet.packet_file;$result.preservation_evidence.packet_sha256=Get-Hash $packet.packet_file;$result.created_at=[datetimeoffset]::UtcNow.ToString('o')
    $durable=Add-TsfRuntimeDurableResult $result $packet.packet_file;$resultPath=$durable.path;$ledger=Join-Path $root 'ledger.json';Write-Json ([pscustomobject]@{schema_version=1;ledger_id="ledger-$Name";approvals=@()}) $ledger
    [pscustomobject]@{root=$root;mission=$mission;result=$result;result_path=$resultPath;registry=$registry;queue_root=$queueRoot;queue_path=$queuePath;ledger=$ledger;preservation_root=$packet.packet_directory;packet_path=$packet.packet_file}
}
function Invoke-AdmissionFixture($Fixture,[string]$Fault='NONE',[string]$QueuePath=''){
    if(!$QueuePath){$QueuePath=$Fixture.queue_path}
    Get-TsfAdmissionDecision $Fixture.result_path $Fixture.registry (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $Fixture.ledger $QueuePath $Fixture.queue_root -UnsupportedDevelopmentMode -TestOnlyAllowAlternateQueueRoot -TestFault $Fault
}

$longMissionId='synthetic-'+('m'*76)+'-'+$testRunNonce;$longResultId='r'+('x'*150);$txLong=New-AdmissionFixture 'long' $longResultId $longMissionId
$txReceipt=Invoke-AdmissionFixture $txLong
$receiptLeaf=Split-Path -Leaf $txReceipt.admission_receipt_path;$receiptKey=$receiptLeaf.Substring(2,32);$receiptRoot=Split-Path -Parent $txReceipt.admission_receipt_path;$allReceiptPaths=@('a','t','x','y','z','c'|ForEach-Object{Join-Path $receiptRoot "$_-$receiptKey.$(if($_-in@('a','t','c')){'json'}else{'tmp'})"});$maximumReceiptPath=($allReceiptPaths|ForEach-Object{$_.Length}|Measure-Object -Maximum).Maximum
Assert-Case 'VS-TX-001' transaction ($maximumReceiptPath-le240-and$maximumReceiptPath-le225-and$receiptLeaf-match'^a-[a-z2-7]{32}\.json$') "160-bit deterministic Base32 key; max path $maximumReceiptPath"
Assert-Case 'VS-TX-001A' transaction ($txReceipt.receipt_identity_sha256.Length-eq64-and(ConvertTo-TsfRuntimeShortKey $txReceipt.receipt_identity_sha256)-eq$receiptKey-and$txReceipt.receipt_id-match'^admission-[a-z2-7]{24}$') 'full SHA-256 identity retained and matches short key'
$txMarker=Get-Content $txReceipt.transaction_receipt_path -Raw|ConvertFrom-Json
Assert-Case 'VS-TX-002' transaction ((Test-Path -LiteralPath $txReceipt.admission_receipt_path)-and(Test-Path -LiteralPath $txReceipt.transaction_receipt_path)-and$txMarker.state-eq'COMMITTED'-and$txMarker.receipt_identity_sha256-eq$txReceipt.receipt_identity_sha256) 'queue and both mandatory receipts committed with matching full digest'
$originalReceiptHash=Get-Hash $txReceipt.admission_receipt_path;$exact=Invoke-AdmissionFixture $txLong 'NONE' $txReceipt.queue_transition_path
Assert-Case 'VS-TX-003' replay ($exact.idempotent_replay-and$exact.result_sha256-eq$txReceipt.result_sha256-and(Get-Hash $txReceipt.admission_receipt_path)-eq$originalReceiptHash) 'exact replay returns preserved original decision'
$wrongReplayQueue=Join-Path $runtimeRoot 'wrong-replay-queue';New-Item -ItemType Directory -Force $wrongReplayQueue|Out-Null;$txHashBeforeQueueMismatch=Get-Hash $txReceipt.transaction_receipt_path;$queueAuthorityMismatch=ThrowsLike {Get-TsfAdmissionDecision $txLong.result_path $txLong.registry (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $txLong.ledger $txReceipt.queue_transition_path $wrongReplayQueue -UnsupportedDevelopmentMode -TestOnlyAllowAlternateQueueRoot} 'QUEUE_IDENTITY_MISMATCH'
Assert-Case 'VS-QUEUE-AUTH-005' queue ($queueAuthorityMismatch-and(Get-Hash $txReceipt.admission_receipt_path)-eq$originalReceiptHash-and(Get-Hash $txReceipt.transaction_receipt_path)-eq$txHashBeforeQueueMismatch) 'queue-root authority mismatch fails before replay mutation'
$changed=Copy-Object $txLong.result;$changed.proposed_next_action='conflicting transaction replay';$changedPath=Join-Path $txLong.root 'conflicting-result.json';Write-Json $changed $changedPath;$changedFixture=Copy-Object $txLong;$changedFixture.result_path=$changedPath;$conflict=Invoke-AdmissionFixture $changedFixture 'NONE' $txReceipt.queue_transition_path
Assert-Case 'VS-TX-004' replay ($conflict.status-eq'REJECTED_INVALID_EVIDENCE'-and$conflict.conflict_identity_sha256.Length-eq64-and(Split-Path -Leaf $conflict.conflict_receipt_path)-match'^c-[a-z2-7]{32}\.json$'-and(Test-Path -LiteralPath $conflict.original_admission_receipt_path)-and(Get-Hash $txReceipt.admission_receipt_path)-eq$originalReceiptHash) 'conflicting result ID preserves original and writes collision-checked immutable conflict'

function Test-TransactionRelationshipTamper([string]$Name,[scriptblock]$Mutate){
    $path=[string]$txReceipt.transaction_receipt_path;$backup=Join-Path $txLong.root "transaction-$Name.backup"
    Copy-Item $path $backup -Force;$doc=Get-Content $path -Raw|ConvertFrom-Json;&$Mutate $doc;Write-Json $doc $path
    $receiptBefore=Get-Hash $txReceipt.admission_receipt_path;$transactionBefore=Get-Hash $path
    $blocked=Throws{Invoke-AdmissionFixture $txLong 'NONE' $txReceipt.queue_transition_path}
    $unchanged=$receiptBefore-eq(Get-Hash $txReceipt.admission_receipt_path)-and$transactionBefore-eq(Get-Hash $path)
    Copy-Item $backup $path -Force
    $blocked-and$unchanged
}
Assert-Case 'VS-REL-001' recovery (Test-TransactionRelationshipTamper resultid {param($d)$d.result_id='wrong-result'}) 'wrong result ID fails without evidence mutation'
Assert-Case 'VS-REL-002' recovery (Test-TransactionRelationshipTamper resulthash {param($d)$d.result_sha256='0'*64}) 'wrong result hash fails without evidence mutation'
Assert-Case 'VS-REL-003' recovery (Test-TransactionRelationshipTamper preservationhash {param($d)$d.preservation_packet_sha256='0'*64}) 'wrong preservation hash fails without evidence mutation'
Assert-Case 'VS-REL-004' recovery (Test-TransactionRelationshipTamper preservationpath {param($d)$d.preservation_packet_path='C:\wrong\pp.json'}) 'wrong preservation path fails without evidence mutation'
Assert-Case 'VS-REL-005' recovery (Test-TransactionRelationshipTamper receiptpath {param($d)$d.admission_receipt_path='C:\wrong\a.json'}) 'wrong receipt path fails without evidence mutation'
Assert-Case 'VS-REL-006' recovery (Test-TransactionRelationshipTamper receipthash {param($d)$d.admission_receipt_sha256='0'*64}) 'wrong receipt hash fails without evidence mutation'
Assert-Case 'VS-REL-007' recovery (Test-TransactionRelationshipTamper txidentity {param($d)$d.transaction_identity_sha256='0'*64}) 'wrong transaction identity fails without evidence mutation'
Assert-Case 'VS-REL-008' recovery (Test-TransactionRelationshipTamper txcontent {param($d)$d.transaction_content_sha256='0'*64}) 'wrong transaction content hash fails without evidence mutation'
Assert-Case 'VS-REL-009' recovery (Test-TransactionRelationshipTamper decision {param($d)$d.admission_status='REJECTED_INVALID_EVIDENCE'}) 'wrong admission decision fails without evidence mutation'
Assert-Case 'VS-REL-010' recovery (Test-TransactionRelationshipTamper queuehash {param($d)$d.queue_document_sha256='0'*64}) 'wrong queue hash fails without evidence mutation'
Assert-Case 'VS-REL-011' recovery (Test-TransactionRelationshipTamper state {param($d)$d.queue_state_to='complete_review_only'}) 'wrong destination state fails without evidence mutation'
Assert-Case 'VS-REL-012' recovery (Test-TransactionRelationshipTamper destination {param($d)$d.destination_path='C:\wrong\mission.json'}) 'wrong destination path fails without evidence mutation'

$txTemp=New-AdmissionFixture 'temp-failure' 'transaction-temp-failure-result';$tempFailed=Throws{Invoke-AdmissionFixture $txTemp 'TEMP_WRITE'}
Assert-Case 'VS-TX-005' transaction ($tempFailed-and(Test-Path $txTemp.queue_path)-and!(Test-Path (Join-Path $txTemp.queue_root 'complete_ready_for_gate\m.json'))) 'temporary receipt failure occurs before queue movement'
$txQueue=New-AdmissionFixture 'queue-failure' 'transaction-queue-failure-result';$queueFailed=Throws{Invoke-AdmissionFixture $txQueue 'QUEUE_TRANSITION'}
Assert-Case 'VS-TX-006' transaction ($queueFailed-and(Test-Path $txQueue.queue_path)-and!(Test-Path (Join-Path $txQueue.queue_root 'complete_ready_for_gate\m.json'))) 'simulated transition failure leaves queue unadvanced'
$txUnrelated=New-AdmissionFixture 'unrelated-queue' 'transaction-unrelated-queue-result';$unrelatedDocument=Get-Content $txUnrelated.queue_path -Raw|ConvertFrom-Json;$unrelatedDocument.durable_mission.mission_id='unrelated-queue-record';Write-Json $unrelatedDocument $txUnrelated.queue_path;$unrelatedBlocked=ThrowsLike {Invoke-AdmissionFixture $txUnrelated} 'QUEUE_DOCUMENT_IDENTITY_MISMATCH'
Assert-Case 'VS-TX-006A' transaction ($unrelatedBlocked-and(Test-Path $txUnrelated.queue_path)-and!(Test-Path (Join-Path $txUnrelated.queue_root 'complete_review_only\m.json'))) 'unrelated queue record fails closed without transition'
$txFinalize=New-AdmissionFixture 'finalize-failure' 'transaction-finalize-failure-result';$finalizeFailed=Throws{Invoke-AdmissionFixture $txFinalize 'FINALIZE_ADMISSION'}
$finalizeAdmission=Get-ChildItem -LiteralPath $txFinalize.preservation_root -Filter 'a-*.json' -File -Recurse|Select-Object -First 1
Assert-Case 'VS-TX-007' transaction ($finalizeFailed-and(Test-Path $txFinalize.queue_path)-and!(Test-Path (Join-Path $txFinalize.queue_root 'complete_ready_for_gate\m.json'))-and!$finalizeAdmission) 'final receipt failure rolls queue back through bound recovery'
$txCommit=New-AdmissionFixture 'commit-failure' 'transaction-commit-failure-result';$commitFailed=Throws{Invoke-AdmissionFixture $txCommit 'FINALIZE_TRANSACTION'};$commitReceipt=Get-ChildItem -LiteralPath $txCommit.preservation_root -Filter 'a-*.json' -File -Recurse|Select-Object -First 1;$commitMarker=Get-ChildItem -LiteralPath $txCommit.preservation_root -Filter 't-*.json' -File -Recurse|Select-Object -First 1;$commitState=Get-Content $commitMarker.FullName -Raw|ConvertFrom-Json;$reconciled=Invoke-AdmissionFixture $txCommit 'NONE' $commitState.destination_path
Assert-Case 'VS-TX-008' transaction ($commitFailed-and$commitReceipt-and$commitState.state-eq'RECOVERY_REQUIRED'-and$reconciled.idempotent_replay-and((Get-Content $commitMarker.FullName -Raw|ConvertFrom-Json).state-eq'COMMITTED')) 'idempotent retry reconciles durable recovery marker'
function Test-RecoverySubstitution([string]$Name,[scriptblock]$Mutate){$fixture=New-AdmissionFixture "recovery-$Name" "recovery-$Name-result";$failed=Throws{Invoke-AdmissionFixture $fixture 'FINALIZE_TRANSACTION'};$marker=Get-ChildItem -LiteralPath $fixture.preservation_root -Filter 't-*.json' -File -Recurse|Select-Object -First 1;$before=Get-Hash $marker.FullName;$state=Get-Content $marker.FullName -Raw|ConvertFrom-Json;$document=Get-Content $state.destination_path -Raw|ConvertFrom-Json;&$Mutate $document;Write-Json $document $state.destination_path;$blocked=Throws{Invoke-AdmissionFixture $fixture 'NONE' $state.destination_path};[pscustomobject]@{blocked=$failed-and$blocked;transaction_unchanged=(Get-Hash $marker.FullName)-eq$before;destination=$state.destination_path}}
$recoveryMission=Test-RecoverySubstitution mission {param($d)$d.durable_mission.mission_id='unrelated-mission'}
$recoveryRevision=Test-RecoverySubstitution revision {param($d)$d.source_binding.durable_mission_revision=99}
$recoveryContent=Test-RecoverySubstitution content {param($d)$d.source_binding.durable_mission_content_hash='0'*64}
$recoveryPolicy=Test-RecoverySubstitution policy {param($d)$d.durable_mission.policy.fingerprint='0'*64}
$recoveryQueueHash=Test-RecoverySubstitution queuehash {param($d)$d.compatibility_status='INVALID_SUBSTITUTION'}
Assert-Case 'VS-RECOVERY-002' recovery ($recoveryMission.blocked-and$recoveryMission.transaction_unchanged) 'substituted destination queue mission rejected without receipt mutation'
Assert-Case 'VS-RECOVERY-003' recovery ($recoveryRevision.blocked-and$recoveryRevision.transaction_unchanged) 'stale destination revision rejected without receipt mutation'
Assert-Case 'VS-RECOVERY-004' recovery ($recoveryContent.blocked-and$recoveryContent.transaction_unchanged) 'wrong destination content hash rejected without receipt mutation'
Assert-Case 'VS-RECOVERY-005' recovery ($recoveryPolicy.blocked-and$recoveryPolicy.transaction_unchanged) 'wrong destination policy fingerprint rejected without receipt mutation'
Assert-Case 'VS-RECOVERY-006' recovery ($recoveryQueueHash.blocked-and$recoveryQueueHash.transaction_unchanged) 'destination existence with wrong queue identity rejected without receipt mutation'

$alternateRoot=Join-Path $runtimeRoot 'alternate-normal-runtime';$alternatePlanRejected=ThrowsLike {New-TsfRuntimeStoragePlan $alternateRoot 'alternate-root-mission' 1 'alternate-root-run'} 'NONCANONICAL_RUNTIME_ROOT_REJECTED';$testOnlyPlan=New-TsfRuntimeStoragePlan $alternateRoot 'test-only-root-mission' 1 'test-only-root-run' -TestOnlyAllowAlternateRoot
$alternatePreservationRejected=ThrowsLike {Write-TsfKernelPreservationPacket -MissionPath $compactMissionPath -PreflightResultPath $compactPreflight -OutputDirectory $alternateRoot -RunId 'alternate-root-run' -DurableMission $readMission} 'NONCANONICAL_RUNTIME_ROOT_REJECTED'
Assert-Case 'VS-ROOT-001' storage ($alternatePlanRejected-and!(Test-Path $alternateRoot)) 'alternate caller runtime root rejected before any write'
Assert-Case 'VS-ROOT-002' storage ($alternatePreservationRejected-and!(Test-Path $alternateRoot)) 'alternate preservation output rejected before any write'
Assert-Case 'VS-ROOT-003' storage ($testOnlyPlan.directory-and!(Test-Path $testOnlyPlan.directory)) 'test-only planning entry cannot write or reach normal runtime entry points'
Assert-Case 'VS-TX-009' transaction ($alternatePlanRejected-and$alternatePreservationRejected) 'canonical path authority rejects alternate root before queue movement'
$txCollision=New-AdmissionFixture 'collision' 'transaction-collision-result';$identity=[pscustomobject][ordered]@{mission_id=$txCollision.result.mission_id;mission_revision=[int]$txCollision.result.mission_revision;result_id=$txCollision.result.result_id;policy_fingerprint=$txCollision.result.policy_fingerprint;preservation_packet_sha256=$txCollision.result.preservation_evidence.packet_sha256};$fullKey=Get-TsfContractJsonHash $identity;$key=ConvertTo-TsfRuntimeShortKey $fullKey;$receiptRoot=Join-Path $txCollision.preservation_root 'r';Write-Json ([pscustomobject]@{receipt_identity_sha256=('0'*64);result_sha256=Get-Hash $txCollision.result_path}) (Join-Path $receiptRoot "a-$key.json");$collisionFailed=Throws{Invoke-AdmissionFixture $txCollision}
Assert-Case 'VS-TX-010' transaction ($collisionFailed-and(Test-Path $txCollision.queue_path)) 'explicit receipt identity collision fails closed'
Assert-Case 'VS-TX-011' transaction (!(Get-Command Get-TsfAdmissionDecision).Parameters.ContainsKey('PreservationPacketPath')) 'caller cannot substitute receipt root'

function Invoke-LiveCase {
    param([object]$Mission,[string]$Label)
    $queueRoot=Join-Path $runtimeRoot "$Label\queue";$inbox=Join-Path $queueRoot 'inbox';New-Item -ItemType Directory -Force $inbox|Out-Null
    $document=ConvertTo-TsfCanonicalExecutionArtifacts $Mission $repo;$queuePath=Join-Path $inbox "$($Mission.mission_id).json";Write-Json $document $queuePath
    $runId="canonical-result-$($Mission.mission_id)-$($Mission.mission_revision)";$controlPlan=New-TsfRuntimeStoragePlan (Get-TsfCanonicalRuntimeRoot) $Mission.mission_id $Mission.mission_revision $runId -Layout queue_control;$caseRoot=[string]$controlPlan.directory
    $ledgerPath=Join-Path $caseRoot 'approval-ledger.json';Write-Json ([pscustomobject]@{schema_version=1;ledger_id="$Label-empty-ledger";approvals=@()}) $ledgerPath
    $outFile=[string]$controlPlan.artifacts.queue_result;$output=@(& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\Invoke-TsfMissionQueueForegroundExecutor.ps1') -MissionPath $queuePath -QueueRoot $queueRoot -ApprovalLedgerPath $ledgerPath -OutDirectory $caseRoot -OutFile $outFile -RunCanonicalAppServerWorker -UnsupportedDevelopmentMode -TestOnlyAllowAlternateQueueRoot -WorkerTimeoutSeconds 180 2>&1);$exit=$LASTEXITCODE
    $result=if(Test-Path $outFile){Get-Content $outFile -Raw|ConvertFrom-Json}else{$null}
    return [pscustomobject]@{exit=$exit;output=$output;result=$result;mission=$Mission;document=$document;case_root=$caseRoot;queue_root=$queueRoot;ledger=$ledgerPath}
}

$readCase=$null;$writeCase=$null;$readGreen=$false
if($RunLiveReadOnly){
    # The deterministic mapper fixture above deliberately occupies the canonical
    # result address for $readMission.  A real worker must have an independent
    # mission identity so immutable producer evidence can never be reused.
    $readMission=New-CanonicalMission "synthetic-tsf-live-readonly-appserver-$testRunNonce" $repo $branch $head
    $readCase=Invoke-LiveCase $readMission 'read-only';$readGreen=$readCase.exit-eq0-and$null-ne$readCase.result-and[string]$readCase.result.final_decision-eq'GREEN'
    Assert-Case 'VS-LIVE-RO-001' live_readonly $readGreen ($readCase.output -join ' ')
    if($readGreen){$lifecycle=Get-Content $readCase.result.lifecycle_result_path -Raw|ConvertFrom-Json;$adapter=Get-Content $lifecycle.adapter_result_path -Raw|ConvertFrom-Json;$durable=Get-Content $readCase.result.durable_result_path -Raw|ConvertFrom-Json;$claim=$adapter.final_response|ConvertFrom-Json
        Assert-Case 'VS-LIVE-RO-002' live_readonly ($claim.schema_version-eq'tsf_worker_outcome_claim_v1'-and$claim.outcome_disposition-in@('FULFILLED','FULFILLED_WITH_CAVEATS')-and@($claim.completed_deliverables)-contains'requested_answer'-and@($claim.missing_deliverables).Count-eq0-and[string]$claim.answer-match'tsf_policy_manifest_v1'-and$durable.result_validation_mode-eq'GENERAL_RESULT_V2'-and$durable.transport_status-eq'SUCCEEDED'-and$durable.semantic_status-eq'FULFILLED'-and$durable.outcome_disposition-in@('FULFILLED','FULFILLED_WITH_CAVEATS')-and@($durable.missing_deliverables).Count-eq0) 'mission-bound GENERAL_RESULT_V2 answer fulfilled'
        Assert-Case 'VS-LIVE-RO-003' live_readonly ($adapter.thread_id-and$adapter.turn_id-and$adapter.event_count-gt0) "$($adapter.thread_id):$($adapter.turn_id)"
        Assert-Case 'VS-LIVE-RO-004' live_readonly ($adapter.control_plane_service_network_policy-eq'CODEX_SERVICE_ONLY'-and$adapter.worker_tool_network_policy-eq'DISABLED'-and$adapter.codex_service_connection_used-and!$adapter.worker_network_used) 'network planes separated'
        Assert-Case 'VS-LIVE-RO-005' live_readonly ($adapter.child_exited-and$adapter.no_orphan_process) 'child cleanup'
        Assert-Case 'VS-LIVE-RO-006' live_readonly ($durable.model_assurance_level-eq'ADAPTER_VERIFIED'-and$durable.actual_model-eq$readMission.resolved_model-and$durable.actual_reasoning_effort-eq'UNKNOWN'-and$durable.effort_evidence.mission_requested_effort-eq'LIGHT'-and$durable.effort_evidence.canonical_resolved_effort-eq'LIGHT'-and$durable.effort_evidence.turn_requested_effort-eq'low'-and$durable.effort_evidence.effective_effort-eq'UNKNOWN'-and$durable.effort_evidence.effective_effort_source-eq'NOT_EXPOSED'-and$durable.effort_evidence.effort_assurance-eq'RECOMMENDED_ONLY') 'model observed and effort uncertainty preserved'
        Assert-Case 'VS-LIVE-RO-007' live_readonly ($readCase.result.admission_status-eq'ADMITTED_WITH_CAVEATS'-and$readCase.result.final_queue_state-eq'complete_ready_for_gate') 'admission caveat and queue transition'
        Assert-Case 'VS-LIVE-RO-008' live_readonly ($adapter.turn_usage.evidence_classification-eq'NATIVE_OBSERVED'-and$adapter.turn_usage.total_tokens-gt0-and$adapter.turn_usage.raw_payload_sha256-and$durable.usage_evidence.total_tokens-eq$adapter.turn_usage.total_tokens) 'bound native usage surfaced in adapter and durable result'
        $liveAdmissionPath=[string]$readCase.result.admission_receipt.admission_receipt_path;$liveTransactionPath=[string]$readCase.result.admission_receipt.transaction_receipt_path
        Assert-Case 'VS-LIVE-RO-009' live_readonly ((Test-Path -LiteralPath $liveAdmissionPath)-and(Test-Path -LiteralPath $liveTransactionPath)-and((Get-Content $liveTransactionPath -Raw|ConvertFrom-Json).state-eq'COMMITTED')) 'mandatory short receipts durably committed'
        $runtimeEvidence=Get-Content $readCase.result.runtime_evidence_path -Raw|ConvertFrom-Json
        $spoofAdapter=Get-Content $runtimeEvidence.adapter_result_path -Raw|ConvertFrom-Json;$spoofAdapter.observed_model='spoofed-model';$spoofAdapterPath=Join-Path $runtimeRoot 'spoof-adapter.json';Write-Json $spoofAdapter $spoofAdapterPath;$spoofEvidence=Copy-Object $runtimeEvidence;$spoofEvidence.adapter_result_path=$spoofAdapterPath;Assert-Case 'VS-EVIDENCE-001' evidence (Throws {ConvertTo-TsfDurableResultEnvelope $readMission $spoofEvidence $repo}) 'adapter spoof rejected'
        $spoofVerifier=Get-Content $runtimeEvidence.verifier_result_path -Raw|ConvertFrom-Json;$spoofVerifier.mission_id='spoofed-mission';$spoofVerifierPath=Join-Path $runtimeRoot 'spoof-verifier.json';Write-Json $spoofVerifier $spoofVerifierPath;$verifierEvidence=Copy-Object $runtimeEvidence;$verifierEvidence.verifier_result_path=$spoofVerifierPath;Assert-Case 'VS-EVIDENCE-002' evidence (Throws {ConvertTo-TsfDurableResultEnvelope $readMission $verifierEvidence $repo}) 'verifier spoof rejected'
        $spoofPres=Get-Content $runtimeEvidence.preservation_packet_path -Raw|ConvertFrom-Json;$spoofPres.mission_id='spoofed-mission';$spoofPresPath=Join-Path $runtimeRoot 'spoof-preservation.json';Write-Json $spoofPres $spoofPresPath;$presEvidence=Copy-Object $runtimeEvidence;$presEvidence.preservation_packet_path=$spoofPresPath;Assert-Case 'VS-EVIDENCE-003' evidence (Throws {ConvertTo-TsfDurableResultEnvelope $readMission $presEvidence $repo}) 'preservation mismatch rejected'
        $registry=Join-Path $readCase.case_root 'g';$resultPath=$readCase.result.durable_result_path;$originalReceiptPath=[string]$readCase.result.admission_receipt.admission_receipt_path;$originalReceiptHash=Get-Hash $originalReceiptPath;$exact=Get-TsfAdmissionDecision $resultPath $registry (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $readCase.ledger $readCase.result.final_queue_mission_path $readCase.queue_root -UnsupportedDevelopmentMode -TestOnlyAllowAlternateQueueRoot;Assert-Case 'VS-REPLAY-002' replay ($exact.idempotent_replay-and$exact.status-eq'ADMITTED_WITH_CAVEATS') 'exact replay idempotent'
        $changed=Copy-Object $durable;$changed.proposed_next_action='conflicting replay';$changedPath=Join-Path $runtimeRoot 'conflicting-result.json';Write-Json $changed $changedPath;$conflict=Get-TsfAdmissionDecision $changedPath $registry (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $readCase.ledger $readCase.result.final_queue_mission_path $readCase.queue_root -UnsupportedDevelopmentMode -TestOnlyAllowAlternateQueueRoot;Assert-Case 'VS-REPLAY-003' replay ($conflict.status-eq'REJECTED_INVALID_EVIDENCE'-and(Get-Hash $originalReceiptPath)-eq$originalReceiptHash-and(Test-Path -LiteralPath $conflict.conflict_receipt_path)) 'conflicting replay preserves original'
        $approvalBound=Copy-Object $readMission;$approvalBound.approval_references=@([pscustomobject]@{approval_id='approval-fixture-vertical';exact_action='local_write'});$approvalQueue=ConvertTo-TsfCanonicalExecutionArtifacts $approvalBound $repo;$approvalRoot=Join-Path $runtimeRoot 'missing-approval';$approvalQueueRoot=Join-Path $approvalRoot 'queue';$approvalQueuePath=Join-Path $approvalQueueRoot 'postrun_pending\mission.json';Write-Json $approvalQueue $approvalQueuePath;$approvalRegistry=Join-Path $approvalRoot 'registry';Write-Json $approvalBound (Join-Path $approvalRegistry 'mission.json')
        $approvalEffective=(Test-TsfCanonicalQueueDocument $approvalQueue $approvalBound $repo).effective_mission;$approvalMissionPath=Join-Path $approvalRoot 'm.json';Write-Json $approvalEffective $approvalMissionPath;$approvalPreflightPath=Join-Path $approvalRoot 'pf.json';Write-Json ([pscustomobject]@{mission_id=$approvalBound.mission_id;verdict='GREEN';preflight_approved=$true}) $approvalPreflightPath;$approvalRun="missing-required-approval-result-$testRunNonce";$approvalPacket=Write-TsfKernelPreservationPacket -MissionPath $approvalMissionPath -PreflightResultPath $approvalPreflightPath -QueueDocumentPath $approvalQueuePath -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $approvalRun -DurableMission $approvalBound -TestOnlyAllowSyntheticProducerRegistry
        $approvalResult=Set-GeneralResultFixtureBinding (Copy-Object $durable) $approvalBound $approvalRun;$approvalResult.mission_content_hash=Get-TsfContractJsonHash $approvalBound;$approvalResult.approval_use=@();$approvalResult.preservation_evidence.packet_path=$approvalPacket.packet_file;$approvalResult.preservation_evidence.packet_sha256=Get-Hash $approvalPacket.packet_file;$approvalResultPath=(Add-TsfRuntimeDurableResult $approvalResult $approvalPacket.packet_file).path;$missingApproval=Get-TsfAdmissionDecision $approvalResultPath $approvalRegistry (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $readCase.ledger $approvalQueuePath $approvalQueueRoot -UnsupportedDevelopmentMode -TestOnlyAllowAlternateQueueRoot;Assert-Case 'VS-APPROVAL-007' approval ($missingApproval.status-eq'TIM_REQUIRED'-and($missingApproval.reasons-join' ')-match'Every required approval') ($missingApproval.reasons-join'; ')
    }
}

if($RunLiveWorkspaceWrite-and$readGreen){
    $writeRepo=Join-Path $runtimeRoot 'workspace-write-repo';New-Item -ItemType Directory -Force (Join-Path $writeRepo 'input'),(Join-Path $writeRepo 'output')|Out-Null;Set-Content -LiteralPath (Join-Path $writeRepo 'input\source.txt') -Value 'synthetic input';& git -C $writeRepo init -q;& git -C $writeRepo config user.email 'fixture@tsf.invalid';& git -C $writeRepo config user.name 'TSF Fixture';& git -C $writeRepo add .;& git -C $writeRepo commit -q -m fixture;$writeBranch=(& git -C $writeRepo branch --show-current).Trim();$writeHead=(& git -C $writeRepo rev-parse HEAD).Trim();$writeMission=New-CanonicalMission "synthetic-tsf-workspace-appserver-$testRunNonce" $writeRepo $writeBranch $writeHead -WorkspaceWrite
    $writeCase=Invoke-LiveCase $writeMission 'workspace-write';$writeGreen=$writeCase.exit-eq0-and$null-ne$writeCase.result-and[string]$writeCase.result.final_decision-eq'GREEN';Assert-Case 'VS-LIVE-WR-001' live_workspace_write $writeGreen ($writeCase.output-join' ')
    if($writeGreen){$artifact=Join-Path $writeRepo 'output\result.txt';$adapter=Get-Content (Get-Content $writeCase.result.lifecycle_result_path -Raw|ConvertFrom-Json).adapter_result_path -Raw|ConvertFrom-Json;Assert-Case 'VS-LIVE-WR-002' live_workspace_write ((Get-Content $artifact -Raw).Trim()-eq'TSF workspace-write round trip complete.') 'exact fixture content';Assert-Case 'VS-LIVE-WR-003' live_workspace_write ($adapter.worker_tool_network_policy-eq'DISABLED'-and!$adapter.worker_network_used) 'worker network disabled';Assert-Case 'VS-LIVE-WR-004' live_workspace_write ($writeCase.result.admission_status-eq'ADMITTED_WITH_CAVEATS'-and$writeCase.result.final_queue_state-eq'complete_ready_for_gate') 'workspace admission with truthful effort caveat';Assert-Case 'VS-LIVE-WR-005' live_workspace_write ($adapter.turn_usage.evidence_classification-eq'NATIVE_OBSERVED'-and$adapter.turn_usage.total_tokens-gt0) 'workspace native usage observed';Assert-Case 'VS-LIVE-WR-006' live_workspace_write ((Test-Path -LiteralPath $writeCase.result.admission_receipt.admission_receipt_path)-and(Test-Path -LiteralPath $writeCase.result.admission_receipt.transaction_receipt_path)) 'workspace mandatory receipts persisted'}
}elseif($RunLiveWorkspaceWrite-and!$readGreen){Assert-Case 'VS-LIVE-WR-GATE' live_workspace_write $false 'read-only GREEN gate not satisfied'}

$script:Results|Export-Csv (Join-Path $EvidenceRoot 'EXECUTED_TEST_COVERAGE.csv') -NoTypeInformation -Encoding UTF8
$failed=@($script:Results|Where-Object status -ne 'PASS')
$capability=[pscustomobject]@{schema_version='tsf_app_server_capability_report_v1';codex_version='0.144.1';transport='stdio://';experimental_api=$false;stable_methods=@('initialize','model/list','thread/start','turn/start');read_only_attempted=[bool]$RunLiveReadOnly;read_only_green=$readGreen;workspace_write_attempted=[bool]($RunLiveWorkspaceWrite-and$readGreen);question_relay_status='QUESTION_RELAY_DEFERRED_AFTER_AUTOMATIC_ROUND_TRIP'};Write-Json $capability (Join-Path $EvidenceRoot 'APP_SERVER_CAPABILITY_REPORT.json')
$eventSummary=[pscustomobject]@{schema_version='tsf_app_server_event_summary_v1';read_only_thread_id=if($readGreen){[string]$readCase.result.thread_id}else{''};read_only_turn_id=if($readGreen){[string]$readCase.result.turn_id}else{''};workspace_thread_id=if($null-ne$writeCase-and$writeCase.result){[string]$writeCase.result.thread_id}else{''};workspace_turn_id=if($null-ne$writeCase-and$writeCase.result){[string]$writeCase.result.turn_id}else{''};all_children_exited=if($readGreen){[bool]$readCase.result.child_exited-and($null-eq$writeCase-or[bool]$writeCase.result.child_exited)}else{$false};no_orphan_process=if($readGreen){[bool]$readCase.result.no_orphan_process-and($null-eq$writeCase-or[bool]$writeCase.result.no_orphan_process)}else{$false}};Write-Json $eventSummary (Join-Path $EvidenceRoot 'APP_SERVER_EVENT_SUMMARY.json')
$validation=[pscustomobject]@{schema_version='tsf_canonical_runtime_app_server_vertical_slice_validation_v1';generated_at=[datetimeoffset]::UtcNow.ToString('o');verdict=if($failed.Count){'RED'}elseif($RunLiveReadOnly-and$readGreen-and(!$RunLiveWorkspaceWrite-or$null-ne$writeCase)){'GREEN'}else{'YELLOW'};executed_assertion_count=$script:Results.Count;passed_assertion_count=@($script:Results|Where-Object status -eq 'PASS').Count;failed_assertion_count=$failed.Count;fingerprint=$fingerprint.fingerprint;fingerprint_content_source=$fingerprint.content_source;read_only_green=$readGreen;workspace_write_green=if($null-ne$writeCase-and$writeCase.result){[string]$writeCase.result.final_decision-eq'GREEN'}else{$false};control_plane_service_network_policy='CODEX_SERVICE_ONLY';worker_tool_network_policy='DISABLED';direct_openai_api_called_by_tsf=$false;external_api_called=$false;worker_network_used=$false;push_performed=$false;merge_performed=$false;package_installed=$false;listener_opened=$false;persistent_process_started=$false;work_integration_performed=$false;plugin_or_mcp_added=$false;nwr_accessed=$false;privatelens_content_accessed=$false;product_repository_mutated=$false;deployment_performed=$false};Write-Json $validation (Join-Path $EvidenceRoot 'VALIDATION.json')
if($failed.Count){throw "$($failed.Count) canonical vertical-slice assertions failed."}
Write-Host "Canonical vertical-slice tests passed: $($script:Results.Count) assertions."
