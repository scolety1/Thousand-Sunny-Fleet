[CmdletBinding(PositionalBinding=$false)]
param(
    [string]$EvidenceRoot=''
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if([string]::IsNullOrWhiteSpace($EvidenceRoot)){
    $stamp=[datetimeoffset]::UtcNow.ToString('yyyyMMddTHHmmssfffZ')
    $EvidenceRoot=Join-Path $repo ".codex-local\evidence\semantic-outcome-soak-v3\$stamp"
}elseif(![IO.Path]::IsPathRooted($EvidenceRoot)){
    $EvidenceRoot=Join-Path $repo $EvidenceRoot
}
$EvidenceRoot=[IO.Path]::GetFullPath($EvidenceRoot)
$allowedRoot=[IO.Path]::GetFullPath((Join-Path $repo '.codex-local\evidence\semantic-outcome-soak-v3'))
if(!$EvidenceRoot.StartsWith($allowedRoot.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'SOAK_EVIDENCE_ROOT_OUTSIDE_BOUNDARY'}
[IO.Directory]::CreateDirectory($EvidenceRoot)|Out-Null
$utf8=[Text.UTF8Encoding]::new($false)
$powershell=(Get-Command powershell.exe -ErrorAction Stop).Source
$node=(Get-Command node.exe -ErrorAction Stop).Source
$results=[Collections.Generic.List[object]]::new()

function Get-SoakSha256([string]$Path){(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()}
function Invoke-SoakCase {
    param([string]$Id,[string]$Executable,[string[]]$Arguments,[string]$Coverage)
    $stdoutPath=Join-Path $EvidenceRoot "$Id.stdout.txt"
    $stderrPath=Join-Path $EvidenceRoot "$Id.stderr.txt"
    $argumentText=($Arguments|ForEach-Object{'"'+([string]$_).Replace('"','\"')+'"'})-join' '
    $start=[Diagnostics.ProcessStartInfo]::new()
    $start.FileName=$Executable
    $start.Arguments=$argumentText
    $start.WorkingDirectory=$repo
    $start.UseShellExecute=$false
    $start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true
    $start.RedirectStandardError=$true
    $timer=[Diagnostics.Stopwatch]::StartNew()
    $process=[Diagnostics.Process]::new()
    $process.StartInfo=$start
    if(!$process.Start()){throw "SOAK_CASE_START_FAILED:$Id"}
    $stdoutTask=$process.StandardOutput.ReadToEndAsync()
    $stderrTask=$process.StandardError.ReadToEndAsync()
    $process.WaitForExit()
    $stdout=$stdoutTask.Result
    $stderr=$stderrTask.Result
    $exit=$process.ExitCode
    $process.Dispose()
    $timer.Stop()
    [IO.File]::WriteAllText($stdoutPath,$stdout,$utf8)
    [IO.File]::WriteAllText($stderrPath,$stderr,$utf8)
    $results.Add([pscustomobject][ordered]@{
        case_id=$Id;coverage=$Coverage;exit_code=$exit;status=if($exit-eq0){'PASS'}else{'FAIL'}
        duration_ms=$timer.ElapsedMilliseconds;command=($Executable+' '+($Arguments-join' '))
        stdout_path=$stdoutPath;stdout_sha256=Get-SoakSha256 $stdoutPath
        stderr_path=$stderrPath;stderr_sha256=Get-SoakSha256 $stderrPath
    })|Out-Null
}

$psBase=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File')
Invoke-SoakCase 'semantic-corpus' $powershell ($psBase+@((Join-Path $repo 'tests\Test-TsfSemanticOutcomeCalibrationV1.ps1'))) 'historical/normative success x12; contractions/passives/indirect inability x20; missing deliverable; wrong task; policy block; legacy fail closed'
Invoke-SoakCase 'general-intent-integrity' $powershell ($psBase+@((Join-Path $repo 'tests\Test-TsfGeneralResultIntentIntegrityV1.ps1'))) 'structured claim identity, scope, cross-run/revision, admission, answer/status separation'
Invoke-SoakCase 'kernel-verifier' $powershell ($psBase+@((Join-Path $repo 'tests\Test-TsfGeneralResultKernelVerifierV1.ps1'))) 'independent verifier fulfilled/inability/missing/wrong-task decisions'
Invoke-SoakCase 'exact-literal' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-exact-response-contract-v1.mjs')) 'exact-literal success and mismatch'
Invoke-SoakCase 'intent-authorization' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-intent-authorization-v1.mjs')) 'detached write/commit denial and intent/scope preservation'
Invoke-SoakCase 'request-result-relay' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-request-result-relay-v1.mjs')) 'one-active-mission protection and transport/semantic/admission UI relay'
Invoke-SoakCase 'authority-replay' $powershell ($psBase+@((Join-Path $repo 'tests\run-tsf-final-three-authority-tests.ps1'))) 'exact duplicate replay, changed replay, admission receipts, recovery authority'
Invoke-SoakCase 'interruption-barrier' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-interruption-barrier-safety-v1.mjs')) 'interruption evidence and safe recovery boundary'
Invoke-SoakCase 'recovery-contract' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-recovery-result-contract-proof-v1.mjs')) 'exact/general recovery identity and replay'
Invoke-SoakCase 'responsive-populated' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-responsive-layout-v1.mjs')) 'responsive populated-state and accessible semantic truth'
Invoke-SoakCase 'runtime-cleanliness' $node @((Join-Path $repo 'tests\test-tsf-runtime-queue-cleanliness-v1.mjs')) 'runtime-cleanliness sentinel'
Invoke-SoakCase 'start-stop-doctor' $node @((Join-Path $repo 'tests\test-tsf-hq-dispatch-start-stop-v1.mjs')) 'final Start/Stop ownership, listener cleanup, and Doctor'

$head=(& git -C $repo rev-parse HEAD).Trim()
$tree=(& git -C $repo rev-parse 'HEAD^{tree}').Trim()
$status=@(& git -C $repo status --porcelain=v2 --untracked-files=all)
$failed=@($results|Where-Object status -ne 'PASS')
$result=[pscustomobject][ordered]@{
    schema_version='tsf_semantic_outcome_targeted_soak_v3'
    generated_at=[datetimeoffset]::UtcNow.ToString('o')
    verdict=if($failed.Count){'RED'}else{'GREEN'}
    candidate_head=$head
    candidate_tree=$tree
    working_tree_dirty=@($status).Count-gt0
    case_count=$results.Count
    passed_count=@($results|Where-Object status -eq 'PASS').Count
    failed_count=$failed.Count
    required_scenarios=[ordered]@{
        historical_normative_success=12
        worker_inability_contractions_passives_indirect=20
        missing_deliverable=1
        wrong_task=1
        policy_block=1
        exact_literal_success_and_mismatch=2
        detached_write_commit_denial=1
        exact_duplicate_and_changed_replay=2
        one_active_mission_protection=1
        interruption_recovery=2
        responsive_populated_state=1
        runtime_cleanliness=1
        final_stop_and_doctor=1
    }
    no_product_access=$true
    no_plugin_use=$true
    no_credential_access=$true
    no_deployment=$true
    no_installation=$true
    worker_tool_network='DISABLED'
    control_plane_service_network='NOT_USED_BY_DETERMINISTIC_SOAK'
    results=@($results)
}
$resultPath=Join-Path $EvidenceRoot 'TARGETED_SOAK_V3_RESULT.json'
[IO.File]::WriteAllText($resultPath,($result|ConvertTo-Json -Depth 30),$utf8)
$manifestLines=Get-ChildItem -LiteralPath $EvidenceRoot -File|Sort-Object Name|ForEach-Object{"$((Get-SoakSha256 $_.FullName))  $($_.Name)"}
$manifestPath=Join-Path $EvidenceRoot 'SHA256SUMS.txt'
[IO.File]::WriteAllLines($manifestPath,$manifestLines,$utf8)
if($failed.Count){throw "TSF_SEMANTIC_OUTCOME_SOAK_V3_FAILED cases=$($failed.case_id-join',') result=$resultPath"}
"TSF_SEMANTIC_OUTCOME_TARGETED_SOAK_V3_GREEN cases=$($results.Count) result=$resultPath sha256=$(Get-SoakSha256 $resultPath)"
