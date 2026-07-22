[CmdletBinding(PositionalBinding=$false)]
param([Parameter(Mandatory)][string]$RepositoryRoot)

$ErrorActionPreference='Stop'
$repo=[IO.Path]::GetFullPath($RepositoryRoot)
Import-Module (Join-Path $repo 'tools\TsfDurableContract.psm1') -Force
. (Join-Path $repo 'tools\codex-fleet-enforcement-kernel.ps1')
$inputText=[Console]::In.ReadToEnd()
if([string]::IsNullOrWhiteSpace($inputText)){throw 'TSF_QUEUE_TEST_RECORD_DESCRIPTORS_REQUIRED'}
$parsedDescriptors=$inputText|ConvertFrom-Json
$descriptors=@();foreach($item in $parsedDescriptors){$descriptors+=$item}
$fixture=Get-Content -Raw -LiteralPath (Join-Path $repo 'tests\fixtures\fleet\durable-contract\missions\codex-implementation.synthetic.mission.json')|ConvertFrom-Json
$gitState=Get-TsfKernelGitState -RepoPath $repo
if(!$gitState.can_capture-or!$gitState.branch_identity_available-or([string]$gitState.head)-notmatch'^[a-f0-9]{40,64}$'){throw "TSF_QUEUE_TEST_GIT_IDENTITY_UNAVAILABLE: $([string]$gitState.error)"}
$head=[string]$gitState.head
$branch=[string]$gitState.branch
$detached=[bool]$gitState.detached_head
$fingerprint=Get-TsfPolicyFingerprint (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $repo -UnsupportedDevelopmentMode
$utf8=[Text.UTF8Encoding]::new($false)
$results=@()
foreach($descriptor in $descriptors){
    $mission=$fixture|ConvertTo-Json -Depth 100|ConvertFrom-Json
    $mission.mission_id=[string]$descriptor.mission_id
    $mission.mission_revision=[int]$descriptor.mission_revision
    $mission.original_request="SYNTHETIC DOCTOR VALIDATION FIXTURE: $([string]$descriptor.outcome)"
    $mission.normalized_goal='Read one TSF-local policy fixture without writes, tools, plugins, credentials, or worker network.'
    $mission.worker_role='researcher_source_tracer_worker'
    $mission.permission_mode='READ_ONLY'
    $mission.repository_allowlist=@($repo)
    $mission.source_allowlist=@('fleet/control/policy-manifest.v1.json')
    $mission.allowed_reads=@('fleet/control/policy-manifest.v1.json')
    $mission.allowed_writes=@()
    $mission.required_artifacts=@([pscustomobject]@{path='fleet/control/policy-manifest.v1.json';hash_required=$true})
    $mission.required_tests=@([pscustomobject]@{test_id='doctor-canonical-queue-validation';required=$true;command='behavior-derived fixture assertion'})
    $mission.branch_worktree_policy.branch_required=!$detached
    $mission.branch_worktree_policy.expected_branch=if($detached){$null}else{$branch}
    $mission.branch_worktree_policy.expected_worktree=$repo
    $mission.branch_worktree_policy.starting_head=$head
    $mission.branch_worktree_policy.unexpected_advance_behavior='REJECT'
    $mission.policy.policy_commit=[string]$fingerprint.policy_commit
    $mission.policy.fingerprint=[string]$fingerprint.fingerprint
    $mission.created_at=[datetimeoffset]::UtcNow.ToString('o')
    $mission.expires_at=[datetimeoffset]::UtcNow.AddHours(1).ToString('o')
    $mission.stale_state_behavior='TIM_REQUIRED'
    $document=ConvertTo-TsfCanonicalExecutionArtifacts $mission $repo
    $path=[IO.Path]::GetFullPath([string]$descriptor.path)
    $parent=Split-Path -Parent $path
    [IO.Directory]::CreateDirectory($parent)|Out-Null
    [IO.File]::WriteAllText($path,($document|ConvertTo-Json -Depth 100)+[Environment]::NewLine,$utf8)
    $results+=[pscustomobject]@{path=$path;mission_id=$mission.mission_id;mission_revision=$mission.mission_revision;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()}
}
[Console]::Out.Write(($results|ConvertTo-Json -Depth 10 -Compress))
