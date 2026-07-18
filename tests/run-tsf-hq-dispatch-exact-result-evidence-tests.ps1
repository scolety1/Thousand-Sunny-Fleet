[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $root 'tools\codex-fleet-enforcement-kernel.ps1')
$script:TsfRoot=$root
. (Join-Path $root 'tools\TsfDurableContract.Canonical.ps1')
$fixture=Join-Path $root '.codex-local\fixtures\hq-dispatch-exact-verifier'
if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force}
New-Item -ItemType Directory -Force -Path $fixture|Out-Null
$expectedText='TSF_V1_CANONICAL_FIRST_LAUNCH_GREEN'
$oldFixtureText='TSF_HQ_DISPATCH_READ_ONLY_GREEN'
$expectedHash=Get-TsfRawTextSha256 $expectedText
$missionId='hq2-exact-verifier-test';$runId="canonical-result-$missionId-1";$script:assertions=0
$naturalRequest="Read only the TSF policy fixture and return exactly $expectedText."
$previewId='hq-preview-11111111111111111111111111111111'
$previewArtifactHash='a'*64
$responseContract=New-TsfExactResponseContract -NaturalRequest $naturalRequest -PreviewId $previewId -PreviewArtifactSha256 $previewArtifactHash -MissionId $missionId -MissionRevision 1
function Assert-Case([bool]$Condition,[string]$Message){$script:assertions++;if(!$Condition){throw "ASSERTION_FAILED: $Message"}}
function Write-Json($Value,[string]$Path){New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null;[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 50),[Text.UTF8Encoding]::new($false))}
function Copy-Value($Value){$Value|ConvertTo-Json -Depth 50|ConvertFrom-Json}

$mission=[pscustomobject]@{
    mission_id=$missionId;mission_revision=1;original_request=$naturalRequest;exact_response_contract=$responseContract;repo_path=$root;expected_artifacts=@('fleet/control/policy-manifest.v1.json');allowed_writes=@();forbidden_writes=@()
    required_tests=@([pscustomobject]@{test_id='hq-dispatch-read-only-exact-response';required=$true;command="exact-response-sha256:$expectedHash"})
    role_extension=[pscustomobject]@{worker_role='researcher_source_tracer_worker';role_output_contract='Return the exact mission-bound response.'}
}

function Invoke-ExactVerifierCase([string]$Name,[scriptblock]$Mutate){
    $caseRoot=Join-Path $fixture $Name;New-Item -ItemType Directory -Force -Path $caseRoot|Out-Null
    $adapterPath=Join-Path $caseRoot 'adapter.json';$workerPath=Join-Path $caseRoot 'worker.json';$missionPath=Join-Path $caseRoot 'mission.json';$verifierPath=Join-Path $caseRoot 'verifier.json'
    $adapter=[pscustomobject]@{mission_id=$missionId;mission_revision=1;run_id=$runId;result_id=$runId;thread_id='thread-exact';turn_id='turn-exact';final_response=$expectedText;final_response_observed=$true;expected_response_sha256=$expectedHash;observed_response_sha256=$expectedHash;transport_success=$true;response_exact_match=$true;semantic_response_success=$true}
    & $Mutate $adapter $null
    Write-Json $adapter $adapterPath;$adapterHash=(Get-FileHash -LiteralPath $adapterPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $exact=[pscustomobject]@{mission_id=$missionId;mission_revision=1;run_id=$runId;result_id=$runId;thread_id='thread-exact';turn_id='turn-exact';adapter_result_path=$adapterPath;adapter_result_sha256=$adapterHash;validation_mode='EXACT_LITERAL_V1';normalization_version='ASCII_TOKEN_IDENTITY_V1';expected_literal=$expectedText;observed_literal=[string]$adapter.final_response;observed_representation='SAFE_LITERAL';semantic_contract_sha256=[string]$responseContract.semantic_contract_sha256;expected_response_sha256=$expectedHash;observed_response_sha256=[string]$adapter.observed_response_sha256;transport_success=$true;exact_match=$true;semantic_success=$true}
    $worker=[pscustomobject]@{mission_id=$missionId;worker_role='researcher_source_tracer_worker';role_output_contract_satisfied=$true;files_created=@();files_touched=@();restricted_actions_attempted=@();adapter_result_path=$adapterPath;adapter_result_sha256=$adapterHash;exact_response_evidence=$exact;tests=@([pscustomobject]@{test_id='hq-dispatch-read-only-exact-response';status='PASS';observed='Exact response hash comparison';evidence=[string]$adapter.observed_response_sha256})}
    & $Mutate $adapter $worker
    Write-Json $worker $workerPath;Write-Json $mission $missionPath
    Invoke-TsfKernelPostRunVerify -MissionPath $missionPath -WorkerResultPath $workerPath -OutFile $verifierPath -StateRoot (Join-Path $caseRoot 'state')
}

try{
    $green=Invoke-ExactVerifierCase 'green' {param($a,$w)}
    Assert-Case ($green.verdict-eq'GREEN'-and$green.exact_response_evidence.exact_match) 'independent verifier accepts the exact bound response'
    $wrong=Invoke-ExactVerifierCase 'old-substituted-response' {param($a,$w)if($null-eq$w){$a.final_response=$oldFixtureText;$a.observed_response_sha256=$expectedHash}}
    Assert-Case ($wrong.verdict-eq'RED') 'verifier rejects the old substituted fixture response even when producer flags claim success'
    foreach($case in @(
        [pscustomobject]@{name='prefix';value="X$expectedText"},
        [pscustomobject]@{name='suffix';value="$($expectedText)X"},
        [pscustomobject]@{name='case';value=$expectedText.ToLowerInvariant()},
        [pscustomobject]@{name='leading-whitespace';value=" $expectedText"},
        [pscustomobject]@{name='trailing-whitespace';value="$expectedText "},
        [pscustomobject]@{name='newline';value="$expectedText`n"}
    )){
        $candidate=Invoke-ExactVerifierCase $case.name {param($a,$w)if($null-eq$w){$a.final_response=$case.value;$a.observed_response_sha256=$expectedHash}}
        Assert-Case ($candidate.verdict-eq'RED') "verifier rejects $($case.name) mismatch"
    }
    $missing=Invoke-ExactVerifierCase 'missing-response' {param($a,$w)if($null-eq$w){$a.final_response='';$a.final_response_observed=$false;$a.observed_response_sha256=$null;$a.response_exact_match=$false;$a.semantic_response_success=$false}}
    Assert-Case ($missing.verdict-eq'RED') 'verifier rejects a missing response'
    $crossRun=Invoke-ExactVerifierCase 'cross-run' {param($a,$w)if($null-eq$w){$a.run_id='canonical-result-other-1';$a.result_id='canonical-result-other-1'}}
    Assert-Case ($crossRun.verdict-eq'RED') 'verifier rejects cross-run response substitution'
    $workerCross=Invoke-ExactVerifierCase 'worker-cross-run' {param($a,$w)if($null-ne$w){$w.exact_response_evidence.run_id='canonical-result-other-1'}}
    Assert-Case ($workerCross.verdict-eq'RED') 'verifier rejects cross-run worker evidence'
    $hashMismatch=Invoke-ExactVerifierCase 'expected-hash-mismatch' {param($a,$w)if($null-eq$w){$a.expected_response_sha256='0'*64}}
    Assert-Case ($hashMismatch.verdict-eq'RED') 'verifier rejects an expected hash that differs from the mission fixture'
    $semanticMismatch=Invoke-ExactVerifierCase 'semantic-contract-mismatch' {param($a,$w)if($null-ne$w){$w.exact_response_evidence.semantic_contract_sha256='2'*64}}
    Assert-Case ($semanticMismatch.verdict-eq'RED') 'verifier rejects a cross-contract semantic binding'
    $normalizationMismatch=Invoke-ExactVerifierCase 'normalization-mismatch' {param($a,$w)if($null-ne$w){$w.exact_response_evidence.normalization_version='UNREVIEWED_NORMALIZATION'}}
    Assert-Case ($normalizationMismatch.verdict-eq'RED') 'verifier rejects a normalization-contract mismatch'

    $admissionMission=[pscustomobject]@{required_tests=$mission.required_tests}
    $admissionGood=[pscustomobject]@{tests=@([pscustomobject]@{test_id='hq-dispatch-read-only-exact-response';status='PASS';evidence=$expectedHash;evidence_classification='KERNEL_OBSERVED'})}
    Assert-Case ((Test-TsfRequiredTestEvidence $admissionMission $admissionGood).valid) 'admission helper accepts exact hash-bound PASS evidence'
    $admissionBad=Copy-Value $admissionGood;$admissionBad.tests[0].evidence='1'*64
    Assert-Case (!(Test-TsfRequiredTestEvidence $admissionMission $admissionBad).valid) 'admission rejects hardcoded PASS with the wrong evidence hash'
    $admissionTransportOnly=[pscustomobject]@{tests=@([pscustomobject]@{test_id='hq-dispatch-read-only-exact-response';status='PASS';evidence='transport-success';evidence_classification='KERNEL_OBSERVED'})}
    Assert-Case (!(Test-TsfRequiredTestEvidence $admissionMission $admissionTransportOnly).valid) 'adapter transport success alone cannot satisfy admission'

    $claims=[pscustomobject]@{product_repository_access=[pscustomobject]@{classification='NOT_OBSERVED';value=$null;source='no read audit';run_id=$runId};worker_tool_network=[pscustomobject]@{classification='CONFIGURED_DISABLED';value=$false;source='sandbox networkAccess=false';run_id=$runId}}
    Assert-Case ((Test-TsfObservationClaims $claims $runId).valid) 'policy/configuration and missing observation remain distinct valid claims'
    $hardcoded=Copy-Value $claims;$hardcoded.product_repository_access.value=$false
    Assert-Case (!(Test-TsfObservationClaims $hardcoded $runId).valid) 'hardcoded false cannot establish NOT_OBSERVED runtime evidence'
    $crossClaim=Copy-Value $claims;$crossClaim.worker_tool_network.run_id='canonical-result-other-1'
    Assert-Case (!(Test-TsfObservationClaims $crossClaim $runId).valid) 'cross-run observation substitution is rejected'
}finally{if(Test-Path -LiteralPath $fixture){Remove-Item -LiteralPath $fixture -Recurse -Force}}
"HQ_DISPATCH_EXACT_EVIDENCE_PASS assertions=$script:assertions"
