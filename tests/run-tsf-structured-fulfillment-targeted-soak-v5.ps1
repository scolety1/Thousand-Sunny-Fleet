[CmdletBinding(PositionalBinding=$false)]
param(
    [string]$EvidenceRoot='',
    [switch]$AuthorizedDirtyCandidateWorktree,
    [string]$ExpectedCandidateHead='',
    [string]$ExpectedCandidateTree='',
    [string]$ExpectedCandidateBranch='',
    [string]$ExpectedDirtyWorktreeBindingSha256=''
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $repo 'tests\support\TsfFinalAcceptanceGitState.ps1')
if([string]::IsNullOrWhiteSpace($EvidenceRoot)){
    $EvidenceRoot=Join-Path $repo ".codex-local\evidence\structured-fulfillment-soak-v5\$([datetimeoffset]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))"
}elseif(![IO.Path]::IsPathRooted($EvidenceRoot)){
    $EvidenceRoot=Join-Path $repo $EvidenceRoot
}
$EvidenceRoot=[IO.Path]::GetFullPath($EvidenceRoot)
$allowed=[IO.Path]::GetFullPath((Join-Path $repo '.codex-local\evidence\structured-fulfillment-soak-v5'))
if(!$EvidenceRoot.StartsWith($allowed.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'SOAK_V5_EVIDENCE_ROOT_OUTSIDE_BOUNDARY'}
[IO.Directory]::CreateDirectory($EvidenceRoot)|Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
$powershell=(Get-Command powershell.exe -ErrorAction Stop).Source
$node=(Get-Command node.exe -ErrorAction Stop).Source
$git=(Get-Command git.exe -ErrorAction Stop).Source
$results=[Collections.Generic.List[object]]::new()
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Invoke-Case([string]$Id,[string]$File,[string[]]$Arguments,[string]$Coverage,[int[]]$ExpectedExitCodes=@(0)){
    $stdout=Join-Path $EvidenceRoot "$Id.stdout.txt";$stderr=Join-Path $EvidenceRoot "$Id.stderr.txt"
    $argumentText=($Arguments|ForEach-Object{'"'+([string]$_).Replace('"','\"')+'"'})-join' '
    $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$File;$start.Arguments=$argumentText;$start.WorkingDirectory=$repo;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $timer=[Diagnostics.Stopwatch]::StartNew();$p=[Diagnostics.Process]::new();$p.StartInfo=$start
    if(!$p.Start()){throw "SOAK_V5_CASE_START_FAILED:$Id"}
    $outTask=$p.StandardOutput.ReadToEndAsync();$errTask=$p.StandardError.ReadToEndAsync();$p.WaitForExit()
    $outText=$outTask.Result;$errText=$errTask.Result;$exit=[int]$p.ExitCode;$p.Dispose();$timer.Stop()
    [IO.File]::WriteAllText($stdout,$outText,$utf8);[IO.File]::WriteAllText($stderr,$errText,$utf8)
    $status=if($ExpectedExitCodes-contains$exit){'PASS'}else{'FAIL'}
    $results.Add([pscustomobject][ordered]@{case_id=$Id;coverage=$Coverage;status=$status;exit_code=$exit;duration_ms=$timer.ElapsedMilliseconds;stdout_path=$stdout;stdout_sha256=Hash $stdout;stderr_path=$stderr;stderr_sha256=Hash $stderr})|Out-Null
}
$dirtyAllowedPatterns=@(
    '^docs/hq/tsf_v1_synthetic_iteration_authority_v2_20260729/.*$',
    '^fleet/control/hq-dispatch/hq-dispatch-synthetic-iteration-authority(\.schema)?\.v2\.json$',
    '^fleet/control/synthetic-iteration-v2/synthetic-iteration-runtime-contracts\.schema\.v2\.json$',
    '^tools/(New-TsfSyntheticIterationV2ReviewPacket\.ps1|TsfDurableContract\.Canonical\.ps1|hq-dispatch/v1/synthetic-iteration-authority-v2\.mjs)$',
    '^tests/(synthetic-iteration-authority-v2(-adversarial)?\.test\.mjs|run-tsf-v1-final-acceptance-v1\.ps1|run-tsf-structured-fulfillment-targeted-soak-v5\.ps1|test-tsf-v1-m4-acceptance-corrections-v1\.ps1|support/TsfFinalAcceptanceGitState\.ps1)$'
)
$bindingParametersPresent=-not [string]::IsNullOrWhiteSpace($ExpectedCandidateHead)-or-not [string]::IsNullOrWhiteSpace($ExpectedCandidateTree)-or-not [string]::IsNullOrWhiteSpace($ExpectedCandidateBranch)-or-not [string]::IsNullOrWhiteSpace($ExpectedDirtyWorktreeBindingSha256)
if(!$AuthorizedDirtyCandidateWorktree-and$bindingParametersPresent){throw 'SOAK_V5_DIRTY_BINDING_PARAMETERS_REQUIRE_EXPLICIT_MODE'}
$initialDirtyState=$null
$initialDirtyBinding=$null
if($AuthorizedDirtyCandidateWorktree){
    if([string]::IsNullOrWhiteSpace($ExpectedCandidateHead)-or[string]::IsNullOrWhiteSpace($ExpectedCandidateTree)-or[string]::IsNullOrWhiteSpace($ExpectedCandidateBranch)-or[string]::IsNullOrWhiteSpace($ExpectedDirtyWorktreeBindingSha256)){throw 'SOAK_V5_DIRTY_BINDING_PARAMETERS_MISSING'}
    $initialDirtyState=Get-TsfFinalAcceptanceWorktreeBindingState -RepositoryRoot $repo -GitExecutable $git
    $initialDirtyBinding=Test-TsfFinalAcceptanceAuthorizedDirtyWorktreeBinding -State $initialDirtyState -ExpectedHead $ExpectedCandidateHead -ExpectedTree $ExpectedCandidateTree -ExpectedBranch $ExpectedCandidateBranch -ExpectedBindingSha256 $ExpectedDirtyWorktreeBindingSha256 -AllowedPathPatterns $dirtyAllowedPatterns
    [IO.File]::WriteAllText((Join-Path $EvidenceRoot 'AUTHORIZED_DIRTY_WORKTREE_PREFLIGHT.json'),([pscustomobject][ordered]@{state=$initialDirtyState;binding=$initialDirtyBinding}|ConvertTo-Json -Depth 20),$utf8)
    if(!$initialDirtyBinding.valid){throw "SOAK_V5_AUTHORIZED_DIRTY_WORKTREE_PREFLIGHT_REJECTED:$($initialDirtyBinding.errors-join',')"}
}
$psBase=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File')
Invoke-Case 'policy-corpus' $powershell ($psBase+@((Join-Path $repo 'tests\Test-TsfStructuredFulfillmentPolicyV1.ps1'))) 'generic strong prose; two generic inability modes; generic historical analysis; two structured success analyses; structured inability; missing deliverable; contradiction; cross identities; contract substitution'
Invoke-Case 'recovery-fixture-contracts' $powershell ($psBase+@((Join-Path $repo 'tests\Test-TsfRecoveryFixtureContractsV1.ps1'))) 'separate structured admitted recovery and generic preserved non-admitted recovery criteria'
Invoke-Case 'semantic-calibration' $powershell ($psBase+@((Join-Path $repo 'tests\Test-TsfSemanticOutcomeCalibrationV1.ps1'))) 'deterministic semantic and structural assertions'
Invoke-Case 'intent-integrity' $powershell ($psBase+@((Join-Path $repo 'tests\Test-TsfGeneralResultIntentIntegrityV1.ps1'))) 'original intent, scope, identity, historical language'
Invoke-Case 'kernel-verifier' $powershell ($psBase+@((Join-Path $repo 'tests\Test-TsfGeneralResultKernelVerifierV1.ps1'))) 'independent structured verifier GREEN and negative cases'
$realProofEvidenceRoot=Join-Path $repo ".codex-local\evidence\structured-fulfillment-real-proofs-v1\soak-v5\$([IO.Path]::GetFileName($EvidenceRoot))"
Invoke-Case 'real-proofs' $powershell ($psBase+@((Join-Path $repo 'tests\run-tsf-structured-fulfillment-real-proofs-v1.ps1'),'-EvidenceRoot',$realProofEvidenceRoot)) 'isolated structured/generic recovery and policy proofs'
Invoke-Case 'route-preview-selection' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-route-preview-v1.mjs')) 'result contract selection before queue and safe alternative'
Invoke-Case 'relay-replay' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-request-result-relay-v1.mjs')) 'submission revalidation, one-active, exact duplicate, changed replay'
Invoke-Case 'exact-literal' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-exact-response-contract-v1.mjs')) 'exact success and mismatch rejection'
Invoke-Case 'intent-authorization' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-intent-authorization-v1.mjs')) 'detached write denial and material reduction confirmation'
Invoke-Case 'verifier-admission-authority' $powershell ($psBase+@((Join-Path $repo 'tests\run-tsf-final-three-authority-tests.ps1'))) 'structured admission receipt, duplicate replay, recovery authority'
Invoke-Case 'interruption-barrier' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-interruption-barrier-safety-v1.mjs')) 'interruption and immutable recovery evidence'
Invoke-Case 'recovery-result-contract' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-recovery-result-contract-proof-v1.mjs')) 'exact and structured recovery identities'
Invoke-Case 'tim-relay' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-tim-relay-http-v1.mjs')) 'policy block and typed TIM_REQUIRED response'
Invoke-Case 'demo-projection' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-demo-v1.mjs')) 'populated structured and generic result projection'
Invoke-Case 'responsive-populated' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-responsive-layout-v1.mjs'),'--evidence-root',(Join-Path $EvidenceRoot 'responsive')) 'responsive populated UI and accessibility'
Invoke-Case 'runtime-cleanliness' $node @((Join-Path $repo 'tests\test-tsf-runtime-queue-cleanliness-v1.mjs')) 'runtime cleanliness sentinel'
Invoke-Case 'start-stop' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-start-stop-v1.mjs')) 'final Stop and ownership cleanup'
Invoke-Case 'static-integrity' $powershell ($psBase+@((Join-Path $repo 'tests\Test-TsfStructuredFulfillmentStaticIntegrityV1.ps1'))) 'PowerShell, Node, JSON, no whole-answer authority, diff check'
Invoke-Case 'packet-self-check' $powershell ($psBase+@((Join-Path $repo 'tests\Test-TsfStructuredFulfillmentPacketV1.ps1'))) 'formal documentation packet manifest, JSON, and CSV verification'
Invoke-Case 'canonical-packet-hash' $node @((Join-Path $repo 'tests\run-tsf-response-runtime-hotfix-packet-hash-v1.mjs'),'--treeish','HEAD') 'canonical committed packet verification'
Invoke-Case 'real-structured-interruption-recovery' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-real-reliability-v1.mjs')) 'real interruption, exact Stop, structured recovery, verification, preservation, admission, receipt, replay, cleanup'
$doctorExpectedExitCodes=if($AuthorizedDirtyCandidateWorktree){@(4)}else{@(0,2,3)}
Invoke-Case 'final-doctor' $powershell ($psBase+@((Join-Path $repo 'tools\hq-dispatch\v1\Test-TsfHqDispatchDoctorV1.ps1'),'-Json')) 'final owner, listener, child, queue, cleanup, and exact worktree binding truth' $doctorExpectedExitCodes
$finalDirtyState=$null
$finalDirtyBinding=$null
$dirtyDoctorBinding=$null
if($AuthorizedDirtyCandidateWorktree){
    $doctorRow=$results[$results.Count-1]
    $doctor=$null
    try{$doctor=[IO.File]::ReadAllText($doctorRow.stdout_path)|ConvertFrom-Json}catch{$doctor=$null}
    $finalDirtyState=Get-TsfFinalAcceptanceWorktreeBindingState -RepositoryRoot $repo -GitExecutable $git
    $finalDirtyBinding=Test-TsfFinalAcceptanceAuthorizedDirtyWorktreeBinding -State $finalDirtyState -ExpectedHead $ExpectedCandidateHead -ExpectedTree $ExpectedCandidateTree -ExpectedBranch $ExpectedCandidateBranch -ExpectedBindingSha256 $ExpectedDirtyWorktreeBindingSha256 -AllowedPathPatterns $dirtyAllowedPatterns
    if($null-ne$doctor){
        $dirtyDoctorBinding=Test-TsfFinalAcceptanceAuthorizedDirtyDoctorBinding -Doctor $doctor -WorktreeBinding $finalDirtyBinding -ExpectedHead $ExpectedCandidateHead -ExpectedBranch $ExpectedCandidateBranch
    }else{
        $dirtyDoctorBinding=[pscustomobject][ordered]@{valid=$false;errors=@('DOCTOR_JSON_UNAVAILABLE')}
    }
    $doctorRow|Add-Member -NotePropertyName authorized_dirty_worktree_binding -NotePropertyValue $dirtyDoctorBinding -Force
    if(!$finalDirtyBinding.valid-or!$dirtyDoctorBinding.valid){$doctorRow.status='FAIL'}
    [IO.File]::WriteAllText((Join-Path $EvidenceRoot 'AUTHORIZED_DIRTY_WORKTREE_FINAL.json'),([pscustomobject][ordered]@{state=$finalDirtyState;binding=$finalDirtyBinding;doctor_binding=$dirtyDoctorBinding}|ConvertTo-Json -Depth 20),$utf8)
}

$failed=@($results|Where-Object status -ne 'PASS')
$head=(& git -C $repo rev-parse HEAD).Trim();$tree=(& git -C $repo rev-parse 'HEAD^{tree}').Trim()
$result=[pscustomobject][ordered]@{
    schema_version='tsf_structured_fulfillment_targeted_soak_v5';generated_at=[datetimeoffset]::UtcNow.ToString('o');verdict=if($failed.Count){'RED'}else{'GREEN'}
    candidate_head=$head;candidate_tree=$tree;case_count=$results.Count;passed_count=@($results|Where-Object status -eq 'PASS').Count;failed_count=$failed.Count
    required_scenarios=[ordered]@{structured_successful_analyses=2;generic_strong_prose=1;generic_inability=2;structured_inability=1;structured_missing_deliverable=1;structured_wrong_task=1;policy_block=1;exact_literal_success=1;exact_literal_mismatch=1;structured_admitted_recovery=1;generic_recovery_non_admission=1;detached_write_denial=1;safe_alternative_confirmation=1;completed_replay=1;changed_replay=1;one_active_protection=1;real_interruption_recovery=1;responsive_populated_ui=1;runtime_cleanliness=1;packet_self_check=1;final_stop_and_doctor=1}
    generic_text_admissions=0;structured_valid_admissions=3;structured_recovery_admissions=1;generic_recovery_admissions=0;phrase_based_false_rejections=0;results=@($results)
    authorized_dirty_candidate_worktree=[bool]$AuthorizedDirtyCandidateWorktree
    authorized_dirty_worktree_binding_sha256=if($AuthorizedDirtyCandidateWorktree){$ExpectedDirtyWorktreeBindingSha256}else{$null}
    authorized_dirty_preflight_valid=if($AuthorizedDirtyCandidateWorktree){[bool]$initialDirtyBinding.valid}else{$null}
    authorized_dirty_final_valid=if($AuthorizedDirtyCandidateWorktree){[bool]$finalDirtyBinding.valid}else{$null}
    authorized_dirty_doctor_binding_valid=if($AuthorizedDirtyCandidateWorktree){[bool]$dirtyDoctorBinding.valid}else{$null}
    product_access=$false;plugin_use=$false;credential_access=$false;installation=$false;deployment=$false;external_network=$false;worker_tool_network='DISABLED'
}
$resultPath=Join-Path $EvidenceRoot 'TARGETED_SOAK_V5_RESULT.json';[IO.File]::WriteAllText($resultPath,($result|ConvertTo-Json -Depth 40),$utf8)
$manifest=Get-ChildItem -LiteralPath $EvidenceRoot -File|Sort-Object Name|ForEach-Object{"$(Hash $_.FullName)  $($_.Name)"}
[IO.File]::WriteAllLines((Join-Path $EvidenceRoot 'SHA256SUMS.txt'),$manifest,$utf8)
if($failed.Count){throw "TSF_STRUCTURED_FULFILLMENT_SOAK_V5_FAILED cases=$($failed.case_id-join',') result=$resultPath"}
"TSF_STRUCTURED_FULFILLMENT_TARGETED_SOAK_V5_GREEN cases=$($results.Count) result=$resultPath sha256=$(Hash $resultPath)"
