[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$EvidenceRoot = 'docs/hq/tsf_durable_contract_canonical_integration_correction_v1_20260710'
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if (![IO.Path]::IsPathRooted($EvidenceRoot)) { $EvidenceRoot = Join-Path $repo $EvidenceRoot }
Import-Module (Join-Path $repo 'tools\TsfDurableContract.psm1') -Force
. (Join-Path $repo 'tools\codex-fleet-enforcement-kernel.ps1')
$script:Results = [Collections.Generic.List[object]]::new()
function Assert-Case($Id, $Category, [bool]$Passed, $Observed) {
    $script:Results.Add([pscustomobject]@{ case_id=$Id; category=$Category; status=if($Passed){'PASS'}else{'FAIL'}; observed=[string]$Observed }) | Out-Null
    if (!$Passed) { Write-Host "FAIL $Id :: $Observed" -ForegroundColor Red }
}
function Copy-Object($Value) { $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json }
function Write-Json($Value, $Path) { $parent=Split-Path -Parent $Path; if($parent){New-Item -ItemType Directory -Force $parent|Out-Null}; $Value|ConvertTo-Json -Depth 100|Set-Content -LiteralPath $Path -Encoding UTF8 }
function Throws([scriptblock]$Action) { try { &$Action|Out-Null; return $false } catch { return $true } }

$scratch = Join-Path $env:TEMP 'tsf-durable-canonical-correction-v1'
if (Test-Path $scratch) { Remove-Item -LiteralPath $scratch -Recurse -Force }
New-Item -ItemType Directory -Force $scratch | Out-Null
try {
    $fixture = Get-Content (Join-Path $repo 'tests\fixtures\fleet\durable-contract\missions\codex-implementation.synthetic.mission.json') -Raw | ConvertFrom-Json
    Assert-Case 'DC-C001' schema (Test-TsfMissionEnvelope $fixture).valid 'canonical mission accepted'
    $bad=Copy-Object $fixture; $bad.branch_worktree_policy.branch_required='true'; Assert-Case 'DC-C002' schema (!(Test-TsfMissionEnvelope $bad).valid) 'wrong nested boolean rejected'
    $bad=Copy-Object $fixture; $bad.allowed_reads='tools'; Assert-Case 'DC-C003' schema (!(Test-TsfMissionEnvelope $bad).valid) 'wrong array rejected'
    $bad=Copy-Object $fixture; $bad.model_policy_alias='standard_patch'; Assert-Case 'DC-C004' schema (!(Test-TsfMissionEnvelope $bad).valid) 'legacy alias rejected in new mission'
    $bad=Copy-Object $fixture; $bad|Add-Member extra_field $true; Assert-Case 'DC-C005' schema (!(Test-TsfMissionEnvelope $bad).valid) 'additional property rejected'
    $bad=Copy-Object $fixture; $bad.PSObject.Properties.Remove('policy'); Assert-Case 'DC-C006' schema (!(Test-TsfMissionEnvelope $bad).valid) 'missing nested contract rejected'
    $bad=Copy-Object $fixture; $bad.schema_version='v2'; Assert-Case 'DC-C007' schema (!(Test-TsfMissionEnvelope $bad).valid) 'version const rejected'
    $bad=Copy-Object $fixture; $bad.branch_worktree_policy.expected_branch=''; Assert-Case 'DC-C008' schema (!(Test-TsfMissionEnvelope $bad).valid) 'branch-required empty identity rejected'
    $bad=Copy-Object $fixture; $bad.branch_worktree_policy.expected_branch=$null; Assert-Case 'DC-C009' schema (!(Test-TsfMissionEnvelope $bad).valid) 'branch-required null identity rejected'

    foreach($alias in @('FAST','BALANCED','DEEP','MAX_SINGLE','PARALLEL')) {
        $route=Resolve-TsfModelRouting $alias CODEX
        Assert-Case "DC-M-$alias" model ($route.stable_alias-eq$alias-and!$route.legacy_compatibility_input) $route.resolved_model
    }
    $legacy=@{fast_readonly='FAST';standard_patch='BALANCED';deep_reasoning='DEEP';premium_audit='MAX_SINGLE'}
    foreach($key in $legacy.Keys) {
        $route=Resolve-TsfModelRouting $key CODEX
        Assert-Case "DC-ML-$key" model ($route.stable_alias-eq$legacy[$key]-and$route.legacy_compatibility_input) $route.stable_alias
    }
    Assert-Case 'DC-M-CONFLICT' model (Throws { Resolve-TsfModelRouting unknown CODEX }) 'unknown alias fails closed'

    $policyScratch=Join-Path $scratch 'policy-repo'; New-Item -ItemType Directory $policyScratch|Out-Null
    $manifest=Get-Content (Join-Path $repo 'fleet\control\policy-manifest.v1.json') -Raw|ConvertFrom-Json
    foreach($rel in @('fleet/control/policy-manifest.v1.json')+@($manifest.governing_files)) {
        $src=Join-Path $repo $rel; $dst=Join-Path $policyScratch $rel
        New-Item -ItemType Directory -Force (Split-Path -Parent $dst)|Out-Null; Copy-Item -LiteralPath $src -Destination $dst
    }
    & git -C $policyScratch init -q; & git -C $policyScratch config user.email 'fixture@tsf.invalid'; & git -C $policyScratch config user.name 'TSF Fixture'; & git -C $policyScratch add .; & git -C $policyScratch commit -q -m fixture
    $fp1=Get-TsfPolicyFingerprint (Join-Path $policyScratch 'fleet\control\policy-manifest.v1.json') $policyScratch
    $fp2=Get-TsfPolicyFingerprint (Join-Path $policyScratch 'fleet\control\policy-manifest.v1.json') $policyScratch
    Assert-Case 'DC-F001' fingerprint ($fp1.fingerprint-eq$fp2.fingerprint-and$fp1.content_source-eq'VERIFIED_COMMIT_BLOBS') $fp1.fingerprint
    Set-Content (Join-Path $policyScratch 'unrelated.txt') 'unrelated'
    $fpUnrelated=Get-TsfPolicyFingerprint (Join-Path $policyScratch 'fleet\control\policy-manifest.v1.json') $policyScratch
    Assert-Case 'DC-F002' fingerprint ($fpUnrelated.fingerprint-eq$fp1.fingerprint) 'unrelated file ignored'
    Add-Content (Join-Path $policyScratch 'tools\Move-TsfMissionState.ps1') '# governing change'
    Assert-Case 'DC-F003' fingerprint (Throws { Get-TsfPolicyFingerprint (Join-Path $policyScratch 'fleet\control\policy-manifest.v1.json') $policyScratch }) 'dirty governing policy rejected'
    $fpDirty=Get-TsfPolicyFingerprint (Join-Path $policyScratch 'fleet\control\policy-manifest.v1.json') $policyScratch -UnsupportedDevelopmentMode
    Assert-Case 'DC-F004' fingerprint ($fpDirty.fingerprint-ne$fp1.fingerprint-and$fpDirty.content_source-eq'WORKING_TREE_UNSUPPORTED_DEVELOPMENT') $fpDirty.fingerprint
    Assert-Case 'DC-F005' fingerprint (!(Get-Command Get-TsfPolicyFingerprint).Parameters.ContainsKey('GitCommit')) 'arbitrary commit parameter absent'
    & git -C $policyScratch checkout -q -- 'tools/Move-TsfMissionState.ps1'
    $badManifest=Copy-Object $manifest; $badManifest.governing_files=@($badManifest.governing_files|Where-Object{$_-ne'tools/TsfDurableContract.Canonical.ps1'})
    Write-Json $badManifest (Join-Path $policyScratch 'fleet\control\policy-manifest.v1.json')
    Assert-Case 'DC-F006' fingerprint (Throws { Get-TsfPolicyFingerprint (Join-Path $policyScratch 'fleet\control\policy-manifest.v1.json') $policyScratch -UnsupportedDevelopmentMode }) 'manifest omission detected'

    $sourceFingerprint=Get-TsfPolicyFingerprint (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $repo -UnsupportedDevelopmentMode
    $runtimeRepo=Join-Path $scratch 'runtime-repo'; New-Item -ItemType Directory $runtimeRepo|Out-Null
    & git -C $runtimeRepo init -q; & git -C $runtimeRepo config user.email 'fixture@tsf.invalid'; & git -C $runtimeRepo config user.name 'TSF Fixture'
    New-Item -ItemType Directory -Force (Join-Path $runtimeRepo 'input'),(Join-Path $runtimeRepo 'output')|Out-Null
    Set-Content (Join-Path $runtimeRepo 'input\source.txt') 'source'; & git -C $runtimeRepo add .; & git -C $runtimeRepo commit -q -m runtime
    $branch=(& git -C $runtimeRepo branch --show-current).Trim(); $head=(& git -C $runtimeRepo rev-parse HEAD).Trim()
    $mission=Copy-Object $fixture; $mission.repository_allowlist=@($runtimeRepo); $mission.forbidden_repositories=@(); $mission.source_allowlist=@(); $mission.forbidden_sources=@(); $mission.allowed_reads=@('input'); $mission.allowed_writes=@('output'); $mission.required_artifacts=@([pscustomobject]@{path='output/result.txt';hash_required=$true}); $mission.required_tests=@([pscustomobject]@{test_id='contract-static';required=$true;command='fixture assertion'}); $mission.branch_worktree_policy.expected_branch=$branch; $mission.branch_worktree_policy.expected_worktree=$runtimeRepo; $mission.branch_worktree_policy.starting_head=$head; $mission.policy.policy_commit=$sourceFingerprint.policy_commit; $mission.policy.fingerprint=$sourceFingerprint.fingerprint
    $x1=ConvertTo-TsfCanonicalExecutionArtifacts $mission $repo; $x2=ConvertTo-TsfCanonicalExecutionArtifacts $mission $repo
    Assert-Case 'DC-T001' translator ($x1.compatibility_status-eq'GENERATED_EXECUTION_PACKET') $x1.compatibility_status
    Assert-Case 'DC-T002' translator ((Get-TsfContractJsonHash $x1)-eq(Get-TsfContractJsonHash $x2)) 'deterministic translation'
    Assert-Case 'DC-T003' translator ($x1.source_binding.durable_mission_revision-eq1-and$x1.source_binding.policy_fingerprint-eq$sourceFingerprint.fingerprint) 'durable bindings preserved'
    Assert-Case 'DC-T004' translator (Test-TsfCanonicalQueueDocument $x1 $mission $repo).valid 'canonical queue wrapper accepted'
    $swapped=Copy-Object $x1; $swapped.mission_packet.mission_id='unrelated'; Assert-Case 'DC-T005' translator (!(Test-TsfCanonicalQueueDocument $swapped $mission $repo -SkipRuntimeObservation).valid) 'conflicting inner mission rejected'
    $lossy=Copy-Object $mission; $lossy.repository_allowlist=@($runtimeRepo,$repo); Assert-Case 'DC-T006' translator (Throws { ConvertTo-TsfCanonicalExecutionArtifacts $lossy $repo }) 'ambiguous repository mapping rejected'
    $conflict=Copy-Object $mission; $conflict.resolved_model='conflicting-model'; Assert-Case 'DC-T007' translator (Throws { ConvertTo-TsfCanonicalExecutionArtifacts $conflict $repo }) 'model conflict rejected'
    $effort=Copy-Object $mission; $effort.reasoning_effort='HIGH'; Assert-Case 'DC-T008' translator (Throws { ConvertTo-TsfCanonicalExecutionArtifacts $effort $repo }) 'effort conflict rejected'
    $unknownRole=Copy-Object $mission; $unknownRole.worker_role='missing-role'; Assert-Case 'DC-T009' translator (Throws { ConvertTo-TsfCanonicalExecutionArtifacts $unknownRole $repo }) 'unknown role rejected'
    & git -C $runtimeRepo checkout -q --detach $head
    $detachedGit=Get-TsfKernelGitState $runtimeRepo
    Assert-Case 'DC-G001' git ($detachedGit.can_capture-and$detachedGit.branch_identity_available-and$detachedGit.detached_head-and[string]::IsNullOrWhiteSpace([string]$detachedGit.branch)-and$detachedGit.head-eq$head) 'detached HEAD is explicit and commit-pinned'
    $detachedMission=Copy-Object $mission; $detachedMission.permission_mode='READ_ONLY'; $detachedMission.normalized_goal='Read one exact locally pinned fixture without tools or writes.'; $detachedMission.allowed_writes=@(); $detachedMission.required_artifacts=@([pscustomobject]@{path='input/source.txt';hash_required=$true}); $detachedMission.branch_worktree_policy.branch_required=$false; $detachedMission.branch_worktree_policy.expected_branch=$null; $detachedMission.branch_worktree_policy.unexpected_advance_behavior='REJECT'
    $detachedTranslation=ConvertTo-TsfCanonicalExecutionArtifacts $detachedMission $repo
    Assert-Case 'DC-T010' translator (!($detachedTranslation.mission_packet.PSObject.Properties.Name-contains'required_branch')) 'detached read-only packet omits required_branch'
    Assert-Case 'DC-T011' translator ($null-eq$detachedTranslation.source_binding.expected_branch-and![bool]$detachedTranslation.durable_mission.branch_worktree_policy.branch_required-and[string]$detachedTranslation.durable_mission.branch_worktree_policy.starting_head-eq$head) 'detached durable binding uses null branch and exact HEAD'
    $detachedWrite=Copy-Object $detachedMission; $detachedWrite.permission_mode='WORKSPACE_WRITE'; $detachedWrite.allowed_writes=@('output')
    $detachedWriteError=''; try { ConvertTo-TsfCanonicalExecutionArtifacts $detachedWrite $repo|Out-Null } catch { $detachedWriteError=$_.Exception.Message }
    Assert-Case 'DC-T012' translator ($detachedWriteError-match'Detached workspace writes are unsafe; an attached approved branch is required') $detachedWriteError
    Assert-Case 'DC-AUTH-001' authority (@(Get-Command -Module TsfDurableContract | Where-Object Name -eq 'Get-TsfAdmissionDecision').Count-eq1) 'one exported admission authority'

    New-Item -ItemType Directory -Force $EvidenceRoot|Out-Null
    $script:Results|Export-Csv (Join-Path $EvidenceRoot 'EXECUTED_TEST_COVERAGE.csv') -NoTypeInformation -Encoding UTF8
    $failed=@($script:Results|Where-Object status -ne 'PASS')
    $validation=[pscustomobject]@{schema_version='tsf_durable_contract_canonical_correction_validation_v1';generated_at=[datetimeoffset]::UtcNow.ToString('o');verdict=if($failed.Count){'RED'}else{'GREEN'};executed_assertion_count=$script:Results.Count;passed_assertion_count=@($script:Results|Where-Object status -eq 'PASS').Count;failed_assertion_count=$failed.Count;active_fingerprint_regenerated=$true;regression_suites=@();native_surface_launched=$false;api_called=$false;background_process_started=$false;package_installed=$false;product_repository_mutated=$false;nwr_accessed=$false;privatelens_content_accessed=$false;deployment_performed=$false}
    Write-Json $validation (Join-Path $EvidenceRoot 'VALIDATION.json')
    if($failed.Count){throw "$($failed.Count) durable canonical assertions failed."}
    Write-Host "Durable canonical contract tests passed: $($script:Results.Count) assertions."
} finally {
    if(Test-Path $scratch){Remove-Item -LiteralPath $scratch -Recurse -Force}
}
