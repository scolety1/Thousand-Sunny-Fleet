$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'tools\codex-fleet-enforcement-kernel.ps1')
Import-Module (Join-Path $repo 'tools\TsfDurableContract.psm1') -Force
$nonce = [guid]::NewGuid().ToString('N').Substring(0, 10)
$root = Join-Path $repo ".codex-local\fixtures\optional-lifecycle-arguments-$nonce"
New-Item -ItemType Directory -Force -Path $root | Out-Null
$rows = [Collections.Generic.List[object]]::new()
function Assert-Case([string]$Id, [bool]$Pass, [string]$Evidence) {
    $rows.Add([pscustomobject]@{test_id=$Id;status=$(if($Pass){'PASS'}else{'FAIL'});evidence=$Evidence}) | Out-Null
    if (!$Pass) { throw "FAILED: $Id :: $Evidence" }
}
function Throws-Like([scriptblock]$Action, [string]$Pattern) {
    try { & $Action | Out-Null; return $false } catch { return $_.Exception.Message -match $Pattern }
}
function Write-Json($Value, [string]$Path) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}
function Copy-Value($Value) { $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json }

$noApprovalMission = [pscustomobject]@{
    mission_id = "optional-args-no-approval-$nonce"
    repo_path = $repo
    lane = 'MASTER_TSF_CONTROL_PLANE'
    allowed_writes = @()
    approval_requirements = @()
}
$noApprovalPlan = Test-TsfApprovalLedgerInvocationBinding -Mission $noApprovalMission -CanonicalLedgerPath (Join-Path $root 'unused-al.json')
$argumentPlan = New-TsfLifecycleInvocationArgumentPlan -PowerShellPath 'powershell' -LifecycleEntryPoint (Join-Path $repo 'tools\Invoke-TsfMissionLifecycle.ps1') -MissionPath 'mission.json' -OutDirectory 'out' -OutFile 'out\lc.json' -StateRoot 'out\s' -QueueMissionPath 'queue\mission.json' -QueueRoot 'queue' -CanonicalQueueDocumentEvidencePath 'out\qd.json' -WorkerTimeoutSeconds 30 -ApprovalPlan $noApprovalPlan -ManageQueueTransitions
Assert-Case 'OLA-NOAPPROVAL-001' (!$noApprovalPlan.include_approval_ledger -and !$noApprovalPlan.approval_ledger_consumed -and $noApprovalPlan.approval_semantics -eq 'NO_APPROVAL_REQUIRED') 'Explicit no-approval semantics.'
Assert-Case 'OLA-NOAPPROVAL-002' (@($argumentPlan.argument_names_included) -notcontains 'ApprovalLedgerPath' -and @($argumentPlan.optional_arguments_omitted) -contains 'ApprovalLedgerPath') 'ApprovalLedgerPath omitted by deterministic builder.'
Assert-Case 'OLA-OPTIONAL-001' (@($argumentPlan.arguments | Where-Object { [string]::IsNullOrWhiteSpace([string]$_) }).Count -eq 0) 'No empty optional value reaches native binding.'
Assert-Case 'OLA-REQUIRED-001' (Throws-Like { New-TsfLifecycleInvocationArgumentPlan -PowerShellPath powershell -LifecycleEntryPoint lifecycle.ps1 -MissionPath '' -OutDirectory out -OutFile out\lc.json -StateRoot out\s -QueueMissionPath q\m.json -QueueRoot q -CanonicalQueueDocumentEvidencePath out\qd.json -WorkerTimeoutSeconds 30 -ApprovalPlan $noApprovalPlan } '.') 'Required arguments fail closed.'

$fixtureDir = Join-Path $repo 'tests\fixtures\fleet\enforcement-kernel'
$approvalMission = Get-Content (Join-Path $fixtureDir 'mission.restricted-missing-approval.json') -Raw | ConvertFrom-Json
$approvalMission.mission_id = "optional-args-approval-$nonce"
$approvalMission.repo_path = $repo
$approvalMission.allowed_writes = @('docs/hq')
$approvalMission.expected_artifacts = @('docs/hq/approved.txt')
$approvalPlanPaths = New-TsfCompleteRuntimePathPlan -MissionId $approvalMission.mission_id -MissionRevision 1 -RunId "approval-$nonce"
$canonicalLedgerPath = [string]$approvalPlanPaths.queue_plan.artifacts.approval_ledger
$validLedger = Get-Content (Join-Path $fixtureDir 'approval-ledger.fixture.sample.json') -Raw | ConvertFrom-Json
$validLedger.ledger_id = "optional-args-ledger-$nonce"
$validLedger.approvals[0].repo_path = $repo
$validLedger.approvals[0].allowed_files_or_paths = @('docs/hq')
$validLedger.approvals[0].sample_fixture_only = $false
$validLedger.approvals[0] | Add-Member state ACTIVE -Force
$validLedger.approvals[0] | Add-Member mission_id $approvalMission.mission_id -Force
$validLedger.approvals[0] | Add-Member usage_count 0 -Force
$validLedger.approvals[0] | Add-Member max_uses 1 -Force
$validLedger.approvals[0] | Add-Member reuse_policy SINGLE_USE -Force
Write-Json $validLedger $canonicalLedgerPath
$validApprovalPlan = Test-TsfApprovalLedgerInvocationBinding -Mission $approvalMission -ApprovalLedgerPath $canonicalLedgerPath -CanonicalLedgerPath $canonicalLedgerPath
Assert-Case 'OLA-APPROVAL-001' ($validApprovalPlan.include_approval_ledger -and $validApprovalPlan.approval_ledger_consumed -and $validApprovalPlan.approval_semantics -eq 'APPROVAL_REQUIRED') $canonicalLedgerPath
Assert-Case 'OLA-APPROVAL-002' (Throws-Like { Test-TsfApprovalLedgerInvocationBinding -Mission $approvalMission -CanonicalLedgerPath $canonicalLedgerPath } 'TIM_REQUIRED_APPROVAL_LEDGER_MISSING') 'Missing approval ledger fails closed.'
Assert-Case 'OLA-APPROVAL-003' (Throws-Like { Test-TsfApprovalLedgerInvocationBinding -Mission $approvalMission -ApprovalLedgerPath '' -CanonicalLedgerPath $canonicalLedgerPath } 'TIM_REQUIRED_APPROVAL_LEDGER_MISSING') 'Empty path fails closed.'
Assert-Case 'OLA-APPROVAL-004' (Throws-Like { Test-TsfApprovalLedgerInvocationBinding -Mission $approvalMission -ApprovalLedgerPath (Join-Path $root 'caller-override.json') -CanonicalLedgerPath $canonicalLedgerPath } 'NONCANONICAL_APPROVAL_LEDGER_PATH') 'Caller override cannot replace canonical ledger path.'
[IO.File]::WriteAllBytes($canonicalLedgerPath, [byte[]]@())
Assert-Case 'OLA-APPROVAL-005' (Throws-Like { Test-TsfApprovalLedgerInvocationBinding -Mission $approvalMission -ApprovalLedgerPath $canonicalLedgerPath -CanonicalLedgerPath $canonicalLedgerPath } 'APPROVAL_LEDGER_EMPTY') 'Empty ledger fails closed.'
Set-Content -LiteralPath $canonicalLedgerPath -Value '{not-json' -Encoding UTF8
Assert-Case 'OLA-APPROVAL-006' (Throws-Like { Test-TsfApprovalLedgerInvocationBinding -Mission $approvalMission -ApprovalLedgerPath $canonicalLedgerPath -CanonicalLedgerPath $canonicalLedgerPath } '.') 'Malformed ledger fails closed.'
$mismatchLedger = Copy-Value $validLedger
$mismatchLedger.approvals[0].mission_id = 'different-mission'
Write-Json $mismatchLedger $canonicalLedgerPath
Assert-Case 'OLA-APPROVAL-007' (Throws-Like { Test-TsfApprovalLedgerInvocationBinding -Mission $approvalMission -ApprovalLedgerPath $canonicalLedgerPath -CanonicalLedgerPath $canonicalLedgerPath } 'TIM_REQUIRED_APPROVAL_LEDGER_MISMATCH') 'Mission mismatch fails closed.'
Write-Json $validLedger $canonicalLedgerPath
$approvalArgumentPlan = New-TsfLifecycleInvocationArgumentPlan -PowerShellPath powershell -LifecycleEntryPoint lifecycle.ps1 -MissionPath mission.json -OutDirectory out -OutFile out\lc.json -StateRoot out\s -QueueMissionPath q\m.json -QueueRoot q -CanonicalQueueDocumentEvidencePath out\qd.json -WorkerTimeoutSeconds 30 -ApprovalPlan $validApprovalPlan
Assert-Case 'OLA-APPROVAL-008' (@($approvalArgumentPlan.argument_names_included) -contains 'ApprovalLedgerPath' -and @($approvalArgumentPlan.arguments) -contains $canonicalLedgerPath) 'Validated canonical ledger is included.'

$firstPreserved = Join-Path $repo '.codex-local\programs\self-hosted-overnight-v1\phase1-stopped-foundation-audit'
$secondPreserved = Join-Path $repo '.codex-local\programs\optional-approval-ledger-recovery-v1\second-failed-audit'
$firstStop = Join-Path $firstPreserved 'STOP_RECORD.json'
$firstQueue = Join-Path $firstPreserved 'queue-record-preflight-pending.json'
$secondQueue = Join-Path $secondPreserved 'queue-record-preflight-pending.json'
$secondExecutor = Join-Path $secondPreserved 'qe.json'
Assert-Case 'OLA-HISTORY-001' ((Get-FileHash $firstStop -Algorithm SHA256).Hash.ToLowerInvariant() -eq 'f1829aeb1f9109b1b579a3449c5b7b4861561e6df70e67174c328a26638770ac') $firstStop
Assert-Case 'OLA-HISTORY-002' ((Get-FileHash $firstQueue -Algorithm SHA256).Hash.ToLowerInvariant() -eq 'b448d6ace79b44b0b2ac93074b7547c334888617233da690d213600be35c5eb8') $firstQueue
Assert-Case 'OLA-HISTORY-003' ((Get-FileHash $secondQueue -Algorithm SHA256).Hash.ToLowerInvariant() -eq '75724fe7d76ec7ab99cb96dde02a3895e97994a65bd30471eaab8aad79ef0ab5' -and (Get-FileHash $secondExecutor -Algorithm SHA256).Hash.ToLowerInvariant() -eq '14bede8d37746f0b5e546ef1babdfa8945831d46ece480162162f475032e465e') "$secondQueue|$secondExecutor"

$template = (Get-Content $firstQueue -Raw | ConvertFrom-Json).durable_mission
$head = (& git -C $repo rev-parse HEAD).Trim()
$branch = (& git -C $repo branch --show-current).Trim()
$fingerprint = Get-TsfPolicyFingerprint (Join-Path $repo 'fleet\control\policy-manifest.v1.json') $repo -UnsupportedDevelopmentMode
function New-AuditMission([string]$Name) {
    $m = Copy-Value $template
    $m.mission_id = "optional-args-$Name-$nonce"
    $m.mission_revision = 1
    $m.parent_mission_id = $null
    $m.created_at = [datetimeoffset]::UtcNow.ToString('o')
    $m.expires_at = [datetimeoffset]::UtcNow.AddHours(1).ToString('o')
    $m.approval_references = @()
    $m.repository_allowlist = @($repo)
    $m.branch_worktree_policy.expected_branch = $branch
    $m.branch_worktree_policy.expected_worktree = $repo
    $m.branch_worktree_policy.starting_head = $head
    $m.policy.policy_commit = $head
    $m.policy.fingerprint = [string]$fingerprint.fingerprint
    return $m
}
function Prepare-AuditCase([string]$Name) {
    $m = New-AuditMission $Name
    $missionPath = Join-Path $root "$Name\mission.json"
    $queueRoot = Join-Path $root "$Name\queue"
    Write-Json $m $missionPath
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\New-TsfCanonicalQueueMission.ps1') -DurableMissionPath $missionPath -QueueRoot $queueRoot -TestOnlyAllowAlternateQueueRoot | Out-Null
    $plan = New-TsfCompleteRuntimePathPlan $m.mission_id 1 "canonical-result-$($m.mission_id)-1"
    $prep = Get-Content $plan.queue_plan.artifacts.preparation_result -Raw | ConvertFrom-Json
    return [pscustomobject]@{mission=$m;queue_root=$queueRoot;queue_path=[string]$prep.queue_record_path;plan=$plan}
}

$failureCase = Prepare-AuditCase 'binding-failure'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\Invoke-TsfMissionQueueForegroundExecutor.ps1') -MissionPath $failureCase.queue_path -QueueRoot $failureCase.queue_root -TestOnlyAllowAlternateQueueRoot -TestOnlyLifecycleInvocationFault PARAMETER_BINDING | Out-Null
$failureResult = Get-Content $failureCase.plan.queue_plan.artifacts.executor_invocation_failure -Raw | ConvertFrom-Json
$executorResult = Get-Content $failureCase.plan.queue_plan.artifacts.queue_result -Raw | ConvertFrom-Json
Assert-Case 'OLA-FAILURE-001' ($failureResult.terminal_status -eq 'BLOCKED_LIFECYCLE_INVOCATION' -and !$failureResult.lifecycle_started -and !$failureResult.worker_started -and !$failureResult.app_server_started) ([string]$failureResult.result_path)
$recoverableQueuePath = Join-Path (Join-Path $failureCase.queue_root 'preflight_pending') (Split-Path -Leaf $failureCase.queue_path)
Assert-Case 'OLA-FAILURE-002' ($executorResult.final_state -eq '' -and $failureResult.queue_state -eq 'preflight_pending' -and (Test-Path $recoverableQueuePath)) 'Queue remains recoverable and no worker state is implied.'
$registry = Get-Content $failureResult.producer_registry_path -Raw | ConvertFrom-Json
Assert-Case 'OLA-FAILURE-003' (@($registry.artifacts | Where-Object { $_.logical_type -eq 'executor_invocation_failure' }).Count -eq 1) ([string]$failureResult.producer_registry_path)
Assert-Case 'OLA-FAILURE-004' (@($failureResult.argument_names_included) -notcontains 'ApprovalLedgerPath' -and @($failureResult.optional_arguments_omitted) -contains 'ApprovalLedgerPath') 'Failure evidence records names only and ledger omission.'

$startedCase = Prepare-AuditCase 'lifecycle-started'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'tools\Invoke-TsfMissionQueueForegroundExecutor.ps1') -MissionPath $startedCase.queue_path -QueueRoot $startedCase.queue_root -TestOnlyAllowAlternateQueueRoot -TestOnlyNoWorkerLifecycle | Out-Null
$startedExecutor = Get-Content $startedCase.plan.queue_plan.artifacts.queue_result -Raw | ConvertFrom-Json
$startedLifecycle = Get-Content $startedCase.plan.lifecycle_plan.artifacts.lifecycle_result -Raw | ConvertFrom-Json
Assert-Case 'OLA-NOAPPROVAL-003' ($startedExecutor.lifecycle_started -and !$startedExecutor.app_server_started -and @($startedExecutor.lifecycle_argument_names_included) -notcontains 'ApprovalLedgerPath') ([string]$startedExecutor.lifecycle_result_path)
Assert-Case 'OLA-NOAPPROVAL-004' ($startedLifecycle.approval_semantics -eq 'NO_APPROVAL_REQUIRED' -and !$startedLifecycle.approval_ledger_consumed -and !(Test-Path $startedCase.plan.queue_plan.artifacts.approval_ledger)) 'Lifecycle starts without synthetic ledger or worker.'
Assert-Case 'OLA-RECOVERY-001' ($failureCase.mission.mission_id -notin @('tsf-foundation-authority-audit-bd35f991-20260711','tsf-foundation-lifecycle-audit-2d98222b-20260711') -and $startedCase.mission.mission_id -ne $failureCase.mission.mission_id) 'Retries use fresh mission IDs.'
Assert-Case 'OLA-RECOVERY-002' ($executorResult.worker_invocations_used -eq 0 -and $startedExecutor.worker_invocations_used -eq 0) 'No duplicate or live workers spawned.'

$out = Join-Path $root 'EXECUTED_TEST_COVERAGE.csv'
$rows | Export-Csv -LiteralPath $out -NoTypeInformation -Encoding UTF8
[pscustomobject]@{verdict='GREEN_TSF_OPTIONAL_LIFECYCLE_ARGUMENT_TESTS';tests=$rows.Count;worker_invocations=0;output=$out;first_stop_sha256=(Get-FileHash $firstStop -Algorithm SHA256).Hash.ToLowerInvariant();first_queue_sha256=(Get-FileHash $firstQueue -Algorithm SHA256).Hash.ToLowerInvariant();second_queue_sha256=(Get-FileHash $secondQueue -Algorithm SHA256).Hash.ToLowerInvariant();second_executor_sha256=(Get-FileHash $secondExecutor -Algorithm SHA256).Hash.ToLowerInvariant()}
