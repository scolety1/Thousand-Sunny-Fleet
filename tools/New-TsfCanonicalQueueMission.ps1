[CmdletBinding(PositionalBinding=$false)]
param(
    [Parameter(Mandatory)][string]$DurableMissionPath,
    [string]$QueueRoot='fleet/missions',
    [string]$RecoveryFromMissionId='',
    [string]$RecoveryEvidenceDirectory='',
    [switch]$TestOnlyAllowAlternateQueueRoot,
    [switch]$TestOnlyMissingHelper
)
$ErrorActionPreference='Stop'
$fleetRoot=Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$requiredHelpers=@(
    'tools\codex-fleet-enforcement-kernel.ps1',
    'tools\TsfDurableContract.psm1',
    'tools\TsfDurableContract.Canonical.ps1',
    'tools\TsfRuntimeArtifactAddressing.ps1',
    'tools\TsfLifecycleTerminalResult.ps1'
)
$missingHelpers=@($requiredHelpers|Where-Object{!(Test-Path -LiteralPath (Join-Path $fleetRoot $_) -PathType Leaf)})
if($TestOnlyMissingHelper){$missingHelpers+=@('TEST_ONLY_MISSING_HELPER.ps1')}
. (Join-Path $fleetRoot 'tools\codex-fleet-enforcement-kernel.ps1')
Import-Module (Join-Path $fleetRoot 'tools\TsfDurableContract.psm1') -Force

$mission=Read-TsfKernelJson $DurableMissionPath
$missionId=[string]$mission.mission_id
$revision=[int]$mission.mission_revision
$runId="canonical-result-$missionId-$revision"
$plan=New-TsfCompleteRuntimePathPlan $missionId $revision $runId
$resultPath=[string]$plan.queue_plan.artifacts.preparation_result
$queueAuthority=Resolve-TsfQueueAuthority $QueueRoot -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
$git=Get-TsfKernelGitState $fleetRoot
$status='INTERNAL_ERROR';$blocked=[Collections.Generic.List[string]]::new();$queueRecord='';$queueHash='';$recoveryMarker='';$created=$false
try{
    if($missingHelpers.Count){foreach($helper in $missingHelpers){$blocked.Add("Required repository-relative helper is missing: $helper")|Out-Null};$status='BLOCKED_HELPER_IMPORT';throw 'PREPARATION_BLOCKED'
    }
    if(!$git.can_capture){$blocked.Add('Repository Git state cannot be captured.')|Out-Null;throw 'PREPARATION_BLOCKED'}
    if([string]$git.branch-ne[string]$mission.branch_worktree_policy.expected_branch-or[string]$git.head-ne[string]$mission.branch_worktree_policy.starting_head){$blocked.Add('Mission branch/HEAD binding differs from the current repository.')|Out-Null;throw 'PREPARATION_BLOCKED'}
    $document=ConvertTo-TsfCanonicalExecutionArtifacts $mission $fleetRoot
    $check=Test-TsfCanonicalQueueDocument $document $mission $fleetRoot
    if(!$check.valid){foreach($error in @($check.errors)){$blocked.Add([string]$error)|Out-Null};throw 'PREPARATION_BLOCKED'}
    $queueHash=[string]$check.queue_document_sha256
    $leaf="$missionId.r$revision.json"
    $collisions=@(Get-ChildItem -LiteralPath ([string]$queueAuthority.root) -File -Recurse -ErrorAction SilentlyContinue|Where-Object{$_.Name-eq$leaf-or$_.Name-like"$missionId.r*.json"})
    if($collisions.Count){$status='BLOCKED_COLLISION';$blocked.Add("Mission identity already exists in queue: $($collisions.FullName -join ', ')")|Out-Null;throw 'PREPARATION_BLOCKED'}
    if($RecoveryFromMissionId){
        if($RecoveryFromMissionId-eq$missionId){$status='BLOCKED_COLLISION';$blocked.Add('Retry must not reuse the failed mission ID.')|Out-Null;throw 'PREPARATION_BLOCKED'}
        $stopPath=Join-Path $RecoveryEvidenceDirectory 'STOP_RECORD.json';$snapshotPath=Join-Path $RecoveryEvidenceDirectory 'queue-record-preflight-pending.json'
        if(!(Test-Path $stopPath -PathType Leaf)-or!(Test-Path $snapshotPath -PathType Leaf)){$status='BLOCKED_RECOVERY_EVIDENCE';$blocked.Add('Required immutable failed-attempt evidence is missing.')|Out-Null;throw 'PREPARATION_BLOCKED'}
        $stop=Read-TsfKernelJson $stopPath
        if([string]$stop.mission_id-ne$RecoveryFromMissionId){$status='BLOCKED_RECOVERY_EVIDENCE';$blocked.Add('Recovery evidence mission identity mismatch.')|Out-Null;throw 'PREPARATION_BLOCKED'}
        $marker=[pscustomobject][ordered]@{schema_version='tsf_self_hosted_audit_recovery_marker_v1';created_at=[datetimeoffset]::UtcNow.ToString('o');original_mission_id=$RecoveryFromMissionId;original_attempt_completed=$false;original_attempt_resumable=$false;original_stop_record_path=(Get-TsfKernelFullPath $stopPath);original_stop_record_sha256=(Get-FileHash $stopPath -Algorithm SHA256).Hash.ToLowerInvariant();original_queue_snapshot_path=(Get-TsfKernelFullPath $snapshotPath);original_queue_snapshot_sha256=(Get-FileHash $snapshotPath -Algorithm SHA256).Hash.ToLowerInvariant();retry_mission_id=$missionId;retry_mission_revision=$revision;retry_head=[string]$git.head;retry_queue_document_sha256=$queueHash;duplicate_worker_prevented=$true}
        $recoveryMarker=[string]$plan.queue_plan.artifacts.recovery_marker
        Write-TsfKernelJson $marker $recoveryMarker
    }
    $queueRecord=Join-Path (Join-Path ([string]$queueAuthority.root) 'inbox') $leaf
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $queueRecord)|Out-Null
    Write-TsfKernelJson $document ([string]$plan.queue_plan.artifacts.transition_temp)
    Move-Item -LiteralPath ([string]$plan.queue_plan.artifacts.transition_temp) -Destination $queueRecord
    $created=$true;$status='PREPARED'
}catch{
    if($_.Exception.Message-ne'PREPARATION_BLOCKED'){$blocked.Add($_.Exception.Message)|Out-Null}
}
$result=[pscustomobject][ordered]@{schema_version='tsf_mission_preparation_result_v1';generated_at=[datetimeoffset]::UtcNow.ToString('o');status=$status;mission_id=$missionId;mission_revision=$revision;run_id=$runId;result_path=$resultPath;queue_record_created=$created;queue_record_path=$queueRecord;queue_document_sha256=$queueHash;policy_fingerprint=[string]$mission.policy.fingerprint;repository=$fleetRoot;branch=[string]$git.branch;worktree=$fleetRoot;helpers_verified=($missingHelpers.Count-eq0);recovery_from_mission_id=$RecoveryFromMissionId;recovery_marker_path=$recoveryMarker;blocked_reasons=@($blocked)}
$validation=Test-TsfJsonContract $result (Join-Path $fleetRoot 'fleet\control\mission-preparation-result.schema.v1.json')
if(!$validation.valid){throw "PREPARATION_RESULT_SCHEMA_MISMATCH: $($validation.errors -join '; ')"}
Write-TsfKernelJson $result $resultPath
$result
if($status-ne'PREPARED'){exit 1}
