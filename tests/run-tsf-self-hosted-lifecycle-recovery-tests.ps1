$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'tools\codex-fleet-enforcement-kernel.ps1')
Import-Module (Join-Path $repo 'tools\TsfDurableContract.psm1') -Force
$nonce=[guid]::NewGuid().ToString('N').Substring(0,10)
$root=Join-Path $repo ".codex-local\fixtures\self-hosted-lifecycle-recovery-$nonce"
New-Item -ItemType Directory -Force -Path $root|Out-Null
$preserved=Join-Path $repo '.codex-local\programs\self-hosted-overnight-v1\phase1-stopped-foundation-audit'
$stopPath=Join-Path $preserved 'STOP_RECORD.json';$snapshotPath=Join-Path $preserved 'queue-record-preflight-pending.json'
$originalStopHash=(Get-FileHash $stopPath -Algorithm SHA256).Hash.ToLowerInvariant();$originalSnapshotHash=(Get-FileHash $snapshotPath -Algorithm SHA256).Hash.ToLowerInvariant()
$template=(Get-Content $snapshotPath -Raw|ConvertFrom-Json).durable_mission
$head=(& git -C $repo rev-parse HEAD).Trim();$branch=(& git -C $repo branch --show-current).Trim()
$fingerprint=Get-TsfPolicyFingerprint (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $repo -UnsupportedDevelopmentMode
$rows=[Collections.Generic.List[object]]::new()
function Assert-Case([string]$Id,[bool]$Pass,[string]$Evidence){$rows.Add([pscustomobject]@{test_id=$Id;status=$(if($Pass){'PASS'}else{'FAIL'});evidence=$Evidence})|Out-Null;if(!$Pass){throw "FAILED: $Id :: $Evidence"}}
function Copy-Value($Value){$Value|ConvertTo-Json -Depth 100|ConvertFrom-Json}
function New-Mission([string]$Name){
    $m=Copy-Value $template;$m.mission_id="synthetic-self-hosted-$Name-$nonce";$m.mission_revision=1;$m.parent_mission_id=$null;$m.original_request="Fixture-only lifecycle terminal result case $Name";$m.normalized_goal="Return fixture-only terminal behavior for $Name without launching a worker.";$m.created_at=[datetimeoffset]::UtcNow.ToString('o');$m.expires_at=[datetimeoffset]::UtcNow.AddHours(2).ToString('o');$m.branch_worktree_policy.expected_branch=$branch;$m.branch_worktree_policy.expected_worktree=$repo;$m.branch_worktree_policy.starting_head=$head;$m.policy.policy_commit=$head;$m.policy.fingerprint=[string]$fingerprint.fingerprint;$m
}
function Write-Json($Value,[string]$Path){New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path)|Out-Null;$Value|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $Path -Encoding UTF8}
function Invoke-Case([string]$Name,[string]$Fault){
    $mission=New-Mission $Name;$doc=ConvertTo-TsfCanonicalExecutionArtifacts $mission $repo;$input=Join-Path $root "$Name\input.json";Write-Json $doc $input
    $queue=Join-Path $root "$Name\queue";New-Item -ItemType Directory -Force -Path $queue|Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\Invoke-TsfMissionLifecycle.ps1') -MissionPath $input -QueueRoot $queue -TestOnlyAllowAlternateQueueRoot -TestOnlyFault $Fault | Out-Null
    $exit=$LASTEXITCODE;$runId="canonical-result-$($mission.mission_id)-1";$plan=New-TsfCompleteRuntimePathPlan $mission.mission_id 1 $runId;$path=[string]$plan.lifecycle_plan.artifacts.lifecycle_result
    $result=Get-Content $path -Raw|ConvertFrom-Json;[pscustomobject]@{mission=$mission;doc=$doc;plan=$plan;path=$path;result=$result;exit=$exit;queue=$queue}
}

$green=Invoke-Case green GREEN
Assert-Case 'SHLC-GREEN-001' ($green.result.terminal_status-eq'COMPLETED_GREEN'-and$green.exit-eq0) $green.path
$caveat=Invoke-Case caveat NONE
Assert-Case 'SHLC-CAVEAT-001' ($caveat.result.terminal_status-eq'COMPLETED_WITH_CAVEATS'-and$caveat.exit-eq0) $caveat.path
$preflight=Invoke-Case preflight PREFLIGHT
Assert-Case 'SHLC-PREFLIGHT-001' ($preflight.result.terminal_status-eq'BLOCKED_PREFLIGHT'-and!$preflight.result.worker_launched) $preflight.path
$role=Invoke-Case role ROLE_PERMISSION
Assert-Case 'SHLC-ROLE-001' ($role.result.terminal_status-eq'BLOCKED_ROLE_PERMISSION'-and!$role.result.worker_launched) $role.path
$start=Invoke-Case workerstart WORKER_START
Assert-Case 'SHLC-WORKER-START-001' ($start.result.terminal_status-eq'BLOCKED_WORKER_START'-and!$start.result.worker_launched) $start.path
$verifier=Invoke-Case verifier VERIFIER
Assert-Case 'SHLC-VERIFIER-001' ($verifier.result.terminal_status-eq'BLOCKED_VERIFIER'-and!$verifier.result.worker_launched) $verifier.path
$preservation=Invoke-Case preservation PRESERVATION
Assert-Case 'SHLC-PRESERVATION-001' ($preservation.result.terminal_status-eq'BLOCKED_PRESERVATION'-and!$preservation.result.evidence_preserved) $preservation.path
Assert-Case 'SHLC-PATH-001' ([string]::Equals([string]$green.result.result_path,[string]$green.plan.lifecycle_plan.artifacts.lifecycle_result,[StringComparison]::OrdinalIgnoreCase)) ([string]$green.result.result_path)
$greenCheck=Test-TsfLifecycleTerminalResult $green.result $green.plan (Get-TsfContractJsonHash $green.doc) ([string]$green.mission.policy.fingerprint) -RequireProducerProvenance
Assert-Case 'SHLC-PROVENANCE-001' $greenCheck.valid ($greenCheck.errors -join '; ')
$bad=Copy-Value $green.result;$bad.terminal_status='NOT_A_STATUS';$badCheck=Test-TsfLifecycleTerminalResult $bad $green.plan (Get-TsfContractJsonHash $green.doc) ([string]$green.mission.policy.fingerprint)
Assert-Case 'SHLC-SCHEMA-001' (!$badCheck.valid) ($badCheck.errors -join '; ')
$backup=Join-Path $root 'green-lifecycle-result.backup';Copy-Item $green.path $backup;Remove-Item $green.path
$missing=Test-TsfLifecycleTerminalResult $green.result $green.plan (Get-TsfContractJsonHash $green.doc) ([string]$green.mission.policy.fingerprint) -RequireProducerProvenance
Assert-Case 'SHLC-MISSING-001' (!$missing.valid-and(($missing.errors -join '; ')-match'missing')) ($missing.errors -join '; ')
Copy-Item $backup $green.path
Assert-Case 'SHLC-NO-WORKER-001' (@($green,$caveat,$preflight,$role,$start,$verifier,$preservation|Where-Object{$_.result.worker_launched}).Count-eq0) 'All fixture-only lifecycle cases report worker_launched=false.'

$prepMission=New-Mission preparation;$prepPath=Join-Path $root 'preparation\mission.json';Write-Json $prepMission $prepPath;$prepQueue=Join-Path $root 'preparation\queue'
Push-Location $env:TEMP;try{& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\New-TsfCanonicalQueueMission.ps1') -DurableMissionPath $prepPath -QueueRoot $prepQueue -TestOnlyAllowAlternateQueueRoot|Out-Null;$prepExit=$LASTEXITCODE}finally{Pop-Location}
$prepPlan=New-TsfCompleteRuntimePathPlan $prepMission.mission_id 1 "canonical-result-$($prepMission.mission_id)-1";$prepResult=Get-Content $prepPlan.queue_plan.artifacts.preparation_result -Raw|ConvertFrom-Json
Assert-Case 'SHLC-HELPER-CWD-001' ($prepExit-eq0-and$prepResult.status-eq'PREPARED'-and$prepResult.helpers_verified) ([string]$prepResult.queue_record_path)
$missingMission=New-Mission missinghelper;$missingMissionPath=Join-Path $root 'missing-helper\mission.json';Write-Json $missingMission $missingMissionPath;$missingQueue=Join-Path $root 'missing-helper\queue'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\New-TsfCanonicalQueueMission.ps1') -DurableMissionPath $missingMissionPath -QueueRoot $missingQueue -TestOnlyAllowAlternateQueueRoot -TestOnlyMissingHelper|Out-Null
$missingPrepPlan=New-TsfCompleteRuntimePathPlan $missingMission.mission_id 1 "canonical-result-$($missingMission.mission_id)-1";$missingPrep=Get-Content $missingPrepPlan.queue_plan.artifacts.preparation_result -Raw|ConvertFrom-Json
Assert-Case 'SHLC-HELPER-MISSING-001' ($missingPrep.status-eq'BLOCKED_HELPER_IMPORT'-and!$missingPrep.queue_record_created-and@(Get-ChildItem $missingQueue -File -Recurse -ErrorAction SilentlyContinue).Count-eq0) ($missingPrep.blocked_reasons -join '; ')

$retryMission=New-Mission retry;$retryPath=Join-Path $root 'retry\mission.json';Write-Json $retryMission $retryPath;$retryQueue=Join-Path $root 'retry\queue'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\New-TsfCanonicalQueueMission.ps1') -DurableMissionPath $retryPath -QueueRoot $retryQueue -RecoveryFromMissionId 'tsf-foundation-authority-audit-bd35f991-20260711' -RecoveryEvidenceDirectory $preserved -TestOnlyAllowAlternateQueueRoot|Out-Null
$retryPlan=New-TsfCompleteRuntimePathPlan $retryMission.mission_id 1 "canonical-result-$($retryMission.mission_id)-1";$retryPrep=Get-Content $retryPlan.queue_plan.artifacts.preparation_result -Raw|ConvertFrom-Json;$marker=Get-Content $retryPrep.recovery_marker_path -Raw|ConvertFrom-Json
Assert-Case 'SHLC-RETRY-001' ($retryPrep.status-eq'PREPARED'-and$marker.original_attempt_completed-eq$false-and$marker.original_attempt_resumable-eq$false-and$marker.retry_mission_id-eq$retryMission.mission_id) ([string]$retryPrep.recovery_marker_path)
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\New-TsfCanonicalQueueMission.ps1') -DurableMissionPath $retryPath -QueueRoot $retryQueue -RecoveryFromMissionId 'tsf-foundation-authority-audit-bd35f991-20260711' -RecoveryEvidenceDirectory $preserved -TestOnlyAllowAlternateQueueRoot|Out-Null
$retryCollision=Get-Content $retryPlan.queue_plan.artifacts.preparation_result -Raw|ConvertFrom-Json
Assert-Case 'SHLC-RETRY-COLLISION-001' ($retryCollision.status-eq'BLOCKED_COLLISION'-and!$retryCollision.queue_record_created) ($retryCollision.blocked_reasons -join '; ')
Assert-Case 'SHLC-ORIGINAL-EVIDENCE-001' ((Get-FileHash $stopPath -Algorithm SHA256).Hash.ToLowerInvariant()-eq$originalStopHash-and(Get-FileHash $snapshotPath -Algorithm SHA256).Hash.ToLowerInvariant()-eq$originalSnapshotHash) "$originalStopHash|$originalSnapshotHash"

$out=Join-Path $root 'EXECUTED_TEST_COVERAGE.csv';$rows|Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8
[pscustomobject]@{verdict='GREEN_TSF_SELF_HOSTED_LIFECYCLE_RECOVERY_FOCUSED_TESTS';tests=$rows.Count;output=$out;worker_invocations=0;original_stop_sha256=$originalStopHash;original_queue_snapshot_sha256=$originalSnapshotHash}
