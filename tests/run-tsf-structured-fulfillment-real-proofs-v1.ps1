[CmdletBinding(PositionalBinding=$false)]
param([string]$EvidenceRoot='')

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $repo 'tools\TsfJsonContract.ps1')
Import-Module (Join-Path $repo 'tools\TsfDurableContract.psm1') -Force
. (Join-Path $repo 'tools\TsfSemanticIntegrity.ps1')

if([string]::IsNullOrWhiteSpace($EvidenceRoot)){
    $EvidenceRoot=Join-Path $repo ".codex-local\evidence\structured-fulfillment-real-proofs-v1\$([datetimeoffset]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))"
}elseif(![IO.Path]::IsPathRooted($EvidenceRoot)){
    $EvidenceRoot=Join-Path $repo $EvidenceRoot
}
$EvidenceRoot=[IO.Path]::GetFullPath($EvidenceRoot)
$allowed=[IO.Path]::GetFullPath((Join-Path $repo '.codex-local\evidence\structured-fulfillment-real-proofs-v1'))
if(!$EvidenceRoot.StartsWith($allowed.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'REAL_PROOF_EVIDENCE_ROOT_OUTSIDE_BOUNDARY'}
[IO.Directory]::CreateDirectory($EvidenceRoot)|Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Write-Json([object]$Value,[string]$Path){[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 40),$utf8)}
function Assert-Proof([bool]$Condition,[string]$Message){if(!$Condition){throw "REAL_PROOF_FAILED:$Message"}}
function Copy-O([object]$Value){$Value|ConvertTo-Json -Depth 40|ConvertFrom-Json}
function Contracts([string]$Task){
    $preview='hq-preview-'+(Get-TsfContractJsonHash ([pscustomobject]@{task=$Task})).Substring(0,32)
    $intent=New-TsfOriginalOperatorIntentContract $Task $preview $repo $repo
    $scope=New-TsfScopeTransformationContract $intent $Task @((Get-TsfOriginalOperationAnalysis $Task).requested_operations) ([string]$intent.requested_access) $repo $repo
    [pscustomobject]@{intent=$intent;scope=$scope;completion=(New-TsfTaskCompletionContract $Task $intent $scope)}
}
function Claim([object]$Contracts,[string]$Mission,[string]$Run,[string]$Disposition,[string]$Blocked,[bool]$CompletedTask,[string]$Answer,[string[]]$Completed,[string[]]$Missing){
    [pscustomobject][ordered]@{schema_version='tsf_worker_outcome_claim_v2';mission_id=$Mission;mission_revision=1;run_id=$Run;task_completion_contract_identity_sha256=[string]$Contracts.completion.task_completion_contract_identity_sha256;original_intent_identity_sha256=[string]$Contracts.completion.original_intent_identity_sha256;scope_transformation_identity_sha256=[string]$Contracts.completion.scope_transformation_identity_sha256;attempted_task_sha256=[string]$Contracts.completion.required_task_sha256;task_attempted=$true;task_completed=$CompletedTask;outcome_disposition=$Disposition;completed_deliverables=@($Completed);missing_deliverables=@($Missing);blocked_reason=$Blocked;substantive_answer=$Answer;evidence=@('fixture/source.txt#bounded');caveats=@()}
}
function Evidence([object]$Contracts,[object]$Claim){
    Get-TsfGeneralResultV2Evidence ([string]$Claim.mission_id) 1 ([string]$Claim.run_id) ([pscustomobject]@{transport_success=$true;final_response=($Claim|ConvertTo-Json -Compress -Depth 40)}) $Contracts.completion
}
function Admission([object]$Contracts,[object]$Evidence){
    $mission=[pscustomobject]@{result_validation_mode='GENERAL_RESULT_V2';task_completion_contract=$Contracts.completion}
    $result=[pscustomobject]@{result_validation_mode='GENERAL_RESULT_V2';mission_id=$Evidence.mission_id;mission_revision=$Evidence.mission_revision;result_id=$Evidence.result_id;original_intent_identity_sha256=$Evidence.original_intent_identity_sha256;scope_transformation_identity_sha256=$Evidence.scope_transformation_identity_sha256;task_completion_contract_identity_sha256=$Evidence.task_completion_contract_identity_sha256;transport_status=$Evidence.transport_status;semantic_status=$Evidence.semantic_status;outcome_disposition=$Evidence.outcome_disposition;worker_claim=$Evidence.worker_claim;observed_deliverables=@($Evidence.observed_deliverables);missing_deliverables=@($Evidence.missing_deliverables);outcome_evidence=@($Evidence.outcome_evidence);raw_worker_response_sha256=$Evidence.raw_worker_response_sha256}
    Test-TsfGeneralResultV2AdmissionEvidence $mission $result
}
function Invoke-Runner([string]$Id,[string]$File,[string[]]$Arguments){
    $stdout=Join-Path $EvidenceRoot "$Id.stdout.txt";$stderr=Join-Path $EvidenceRoot "$Id.stderr.txt"
    $argumentText=($Arguments|ForEach-Object{'"'+([string]$_).Replace('"','\"')+'"'})-join' '
    $start=[Diagnostics.ProcessStartInfo]::new();$start.FileName=$File;$start.Arguments=$argumentText;$start.WorkingDirectory=$repo;$start.UseShellExecute=$false;$start.CreateNoWindow=$true;$start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $p=[Diagnostics.Process]::new();$p.StartInfo=$start
    if(!$p.Start()){throw "REAL_PROOF_RUNNER_START_FAILED:$Id"}
    $stdoutTask=$p.StandardOutput.ReadToEndAsync();$stderrTask=$p.StandardError.ReadToEndAsync();$p.WaitForExit()
    $stdoutText=$stdoutTask.Result;$stderrText=$stderrTask.Result;$exit=[int]$p.ExitCode;$p.Dispose()
    [IO.File]::WriteAllText($stdout,$stdoutText,$utf8);[IO.File]::WriteAllText($stderr,$stderrText,$utf8)
    if($exit-ne0){throw "REAL_PROOF_RUNNER_FAILED:$Id exit=$exit"}
    [pscustomobject]@{id=$Id;exit_code=$exit;stdout_path=$stdout;stdout_sha256=Hash $stdout;stderr_path=$stderr;stderr_sha256=Hash $stderr}
}

$generic=Contracts 'Explain the bounded TSF fixture in a concise response.'
$genericMission='real-proof-generic-0001';$genericRun='canonical-result-real-proof-generic-0001-1'
$excellent='The completed-looking analysis identifies mission binding, independent verification, and separate admission, cites bounded evidence, and supplies a polished final explanation.'
$excellentPath=Join-Path $EvidenceRoot 'PROOF_A_GENERIC_EXCELLENT_RESPONSE.txt';[IO.File]::WriteAllText($excellentPath,$excellent,$utf8)
$aClaim=Claim $generic $genericMission $genericRun FULFILLED NONE $true $excellent @('requested_answer') @()
$a=Evidence $generic $aClaim;$aAdmission=Admission $generic $a
Assert-Proof ($a.transport_status-eq'SUCCEEDED'-and$a.compatibility_mode-eq'STRUCTURAL_TEXT_ONLY_V2'-and!$a.semantic_success-and!$a.admissible-and!$aAdmission.valid) 'A_GENERIC_EXCELLENT'
$aPath=Join-Path $EvidenceRoot 'PROOF_A_EVIDENCE.json';Write-Json $a $aPath

$inability="I couldn't complete the requested task."
$inabilityPath=Join-Path $EvidenceRoot 'PROOF_B_GENERIC_INABILITY_RESPONSE.txt';[IO.File]::WriteAllText($inabilityPath,$inability,$utf8)
$bClaim=Claim $generic $genericMission $genericRun FULFILLED NONE $true $inability @('requested_answer') @()
$b=Evidence $generic $bClaim;$bAdmission=Admission $generic $b
Assert-Proof ($b.transport_status-eq'SUCCEEDED'-and$b.outcome_disposition-eq'UNCLASSIFIED_RESULT'-and!$b.semantic_success-and!$bAdmission.valid) 'B_GENERIC_INABILITY'
$bPath=Join-Path $EvidenceRoot 'PROOF_B_EVIDENCE.json';Write-Json $b $bPath

$genericRecoveryMission='real-proof-generic-recovery-0001';$genericRecoveryRun='canonical-result-real-proof-generic-recovery-0001-1'
$genericRecoveryClaim=Claim $generic $genericRecoveryMission $genericRecoveryRun FULFILLED NONE $true $excellent @('requested_answer') @()
$genericRecovery=Evidence $generic $genericRecoveryClaim;$genericRecoveryAdmission=Admission $generic $genericRecovery
Assert-Proof ($genericRecovery.transport_status-eq'SUCCEEDED'-and$genericRecovery.compatibility_mode-eq'STRUCTURAL_TEXT_ONLY_V2'-and!$genericRecovery.semantic_success-and!$genericRecovery.admissible-and!$genericRecoveryAdmission.valid) 'PROOF_2_GENERIC_RECOVERY_NON_ADMISSION'
$genericRecoveryPath=Join-Path $EvidenceRoot 'PROOF_2_GENERIC_RECOVERY_NON_ADMISSION.json';Write-Json ([pscustomobject][ordered]@{fixture_class='GENERIC_RECOVERY_RESPONSE_PRESERVED_NON_ADMISSIBLE';recovery_parent=[pscustomobject]@{mission_id='interrupted-source-0001';mission_revision=1;run_id='canonical-result-interrupted-source-0001-1'};result=$genericRecovery;admission_valid=[bool]$genericRecoveryAdmission.valid;success_receipt_created=$false;ui_message='Response received. Task fulfillment could not be independently verified from this result contract. The response was preserved but not admitted.'}) $genericRecoveryPath

$structured=Contracts 'Analyze the bounded historical fixture and return a summary, at least three findings, evidence references, and limitations.'
$ids=@($structured.completion.required_deliverables|ForEach-Object{[string]$_.deliverable_id}|Sort-Object)
$answer=([pscustomobject][ordered]@{summary='A prior system could not validate input; this completed structured analysis separates historical content from current status.';findings=@('The historical worker was unable to continue.','Policy says workers must not deploy.','The earlier run failed and remained incomplete, while this structured result is complete.');evidence_references=@('fixture/source.txt#S1','fixture/policy.txt#S2');limitations='The proof is limited to deterministic local fixture text.'}|ConvertTo-Json -Compress -Depth 10)
$structuredMission='real-proof-structured-0001';$structuredRun='canonical-result-real-proof-structured-0001-1'
$cClaim=Claim $structured $structuredMission $structuredRun FULFILLED NONE $true $answer $ids @()
$c=Evidence $structured $cClaim;$cAdmission=Admission $structured $c
Assert-Proof ($c.semantic_success-and$c.admissible-and$cAdmission.valid-and@($c.observed_deliverables).Count-eq4) 'C_STRUCTURED_VALID'
$cPath=Join-Path $EvidenceRoot 'PROOF_C_EVIDENCE.json';Write-Json $c $cPath

$structuredRecovery=Contracts 'Read only fleet/control/policy-manifest.v1.json and return a structured analysis with a summary, at least three findings, evidence references, and limitations.'
$structuredRecoveryIds=@($structuredRecovery.completion.required_deliverables|ForEach-Object{[string]$_.deliverable_id}|Sort-Object)
$structuredRecoveryMission='real-proof-structured-recovery-0001';$structuredRecoveryRun='canonical-result-real-proof-structured-recovery-0001-1'
$structuredRecoveryClaim=Claim $structuredRecovery $structuredRecoveryMission $structuredRecoveryRun FULFILLED NONE $true $answer $structuredRecoveryIds @()
$structuredRecoveryEvidence=Evidence $structuredRecovery $structuredRecoveryClaim;$structuredRecoveryAdmission=Admission $structuredRecovery $structuredRecoveryEvidence
Assert-Proof ($structuredRecovery.completion.deliverable_profile-eq'STRUCTURED_ANALYSIS_V2'-and$structuredRecoveryEvidence.semantic_success-and$structuredRecoveryEvidence.admissible-and$structuredRecoveryAdmission.valid) 'PROOF_1_STRUCTURED_RECOVERY_CONTRACT'
$structuredRecoveryPath=Join-Path $EvidenceRoot 'PROOF_1_STRUCTURED_RECOVERY_CONTRACT.json';Write-Json ([pscustomobject][ordered]@{fixture_class='RECOVERY_PIPELINE_COMPLETED_AND_ADMITTED';recovery_parent=[pscustomobject]@{mission_id='interrupted-source-0001';mission_revision=1;run_id='canonical-result-interrupted-source-0001-1'};task_completion_contract=$structuredRecovery.completion;result=$structuredRecoveryEvidence;admission_valid=[bool]$structuredRecoveryAdmission.valid}) $structuredRecoveryPath

$missingAnswer=([pscustomobject][ordered]@{summary='A bounded partial analysis.';findings=@('One.','Two.','Three.');limitations='Evidence references are missing.'}|ConvertTo-Json -Compress -Depth 10)
$dClaim=Claim $structured $structuredMission $structuredRun REQUIRED_DELIVERABLE_MISSING REQUIRED_DELIVERABLE_MISSING $false $missingAnswer @('findings','limitations','summary') @('evidence_references')
$d=Evidence $structured $dClaim;$dAdmission=Admission $structured $d
Assert-Proof (!$d.semantic_success-and!$dAdmission.valid-and@($d.missing_deliverables)-contains'evidence_references') 'D_STRUCTURED_MISSING'
$dPath=Join-Path $EvidenceRoot 'PROOF_D_EVIDENCE.json';Write-Json $d $dPath

$eClaim=Claim $structured $structuredMission $structuredRun UNABLE_TO_PERFORM TASK_INCOMPLETE $false $answer $ids @()
$e=Evidence $structured $eClaim;$eAdmission=Admission $structured $e
Assert-Proof (!$e.semantic_success-and!$eAdmission.valid-and$e.outcome_disposition-eq'UNABLE_TO_PERFORM') 'E_STRUCTURED_UNABLE'
$ePath=Join-Path $EvidenceRoot 'PROOF_E_EVIDENCE.json';Write-Json $e $ePath

$powershell=(Get-Command powershell.exe -ErrorAction Stop).Source;$node=(Get-Command node.exe -ErrorAction Stop).Source
$psBase=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File')
$authorityRunner=Invoke-Runner 'PROOF_C_VERIFIER_ADMISSION_RECEIPT_AUTHORITY' $powershell ($psBase+@((Join-Path $repo 'tests\run-tsf-final-three-authority-tests.ps1')))
$exactRunner=Invoke-Runner 'PROOF_F_EXACT_LITERAL' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-exact-response-contract-v1.mjs'))
$intentRunner=Invoke-Runner 'PROOF_G_DETACHED_WRITE_INTENT' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-intent-authorization-v1.mjs'))

$ui=Get-Content -Raw -LiteralPath (Join-Path $repo 'tools\hq-dispatch\v1\public\app.js')
Assert-Proof ($ui.Contains('Response received. Task fulfillment could not be independently verified from this result contract. The response was preserved but not admitted.')-and$ui.Contains('substantive_answer: status.result.worker_claim.substantive_answer')) 'GENERIC_UI_DISPLAY_AND_TRUTH'

$proofs=@(
    [pscustomobject]@{proof_id='1';status='PASS';identity=Hash $structuredRecoveryPath;fixture_class='RECOVERY_PIPELINE_COMPLETED_AND_ADMITTED';contract='STRUCTURED_ANALYSIS_V2';verifier='GREEN';admitted=$true},
    [pscustomobject]@{proof_id='2';status='PASS';identity=Hash $genericRecoveryPath;fixture_class='GENERIC_RECOVERY_RESPONSE_PRESERVED_NON_ADMISSIBLE';contract='TEXT_RESPONSE_V2';verifier='NOT_GREEN';admitted=$false;receipt_created=$false},
    [pscustomobject]@{proof_id='A';status='PASS';identity=Hash $aPath;response_sha256=Hash $excellentPath;transport='SUCCEEDED';admitted=$false;receipt_created=$false;reason='GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE'},
    [pscustomobject]@{proof_id='B';status='PASS';identity=Hash $bPath;response_sha256=Hash $inabilityPath;transport='SUCCEEDED';admitted=$false;receipt_created=$false;reason='GENERIC_TEXT_STRUCTURAL_ONLY_NON_ADMISSIBLE'},
    [pscustomobject]@{proof_id='C';status='PASS';identity=Hash $cPath;verifier='GREEN';admitted=$true;receipt_authority_suite_sha256=$authorityRunner.stdout_sha256},
    [pscustomobject]@{proof_id='D';status='PASS';identity=Hash $dPath;verifier='NOT_GREEN';admitted=$false;receipt_created=$false},
    [pscustomobject]@{proof_id='E';status='PASS';identity=Hash $ePath;verifier='NOT_GREEN';admitted=$false;receipt_created=$false},
    [pscustomobject]@{proof_id='F';status='PASS';identity=$exactRunner.stdout_sha256;success_and_mismatch_rejection=$true},
    [pscustomobject]@{proof_id='G';status='PASS';identity=$intentRunner.stdout_sha256;prequeue_denial=$true;false_fulfillment=$false}
)
$result=[pscustomobject][ordered]@{schema_version='tsf_structured_fulfillment_real_proofs_v1';generated_at=[datetimeoffset]::UtcNow.ToString('o');verdict='GREEN';candidate_head=(& git -C $repo rev-parse HEAD).Trim();candidate_tree=(& git -C $repo rev-parse 'HEAD^{tree}').Trim();proofs=$proofs;runner_evidence=@($authorityRunner,$exactRunner,$intentRunner);product_access=$false;plugin_use=$false;credential_access=$false;installation=$false;deployment=$false;external_network=$false}
$resultPath=Join-Path $EvidenceRoot 'REAL_PROOFS_RESULT.json';Write-Json $result $resultPath
$manifest=Get-ChildItem -LiteralPath $EvidenceRoot -File|Sort-Object Name|ForEach-Object{"$(Hash $_.FullName)  $($_.Name)"}
[IO.File]::WriteAllLines((Join-Path $EvidenceRoot 'SHA256SUMS.txt'),$manifest,$utf8)
"TSF_STRUCTURED_FULFILLMENT_REAL_PROOFS_GREEN proofs=$($proofs.Count) result=$resultPath sha256=$(Hash $resultPath)"
