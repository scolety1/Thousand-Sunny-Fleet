[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$TestOnlyQueueRoot = '',
    [switch]$UnsupportedDevelopmentMode
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
. (Join-Path $repoRoot 'tools\codex-fleet-enforcement-kernel.ps1')
Import-Module (Join-Path $repoRoot 'tools\TsfDurableContract.psm1') -Force

$raw = [Console]::In.ReadToEnd()
if ([Text.Encoding]::UTF8.GetByteCount($raw) -gt 16384) { throw 'HQ_QUEUE_RECONCILE_INPUT_TOO_LARGE' }
try { $inputValue = $raw | ConvertFrom-Json -ErrorAction Stop } catch { throw 'HQ_QUEUE_RECONCILE_INPUT_INVALID_JSON' }
$allowed = @('mission_id','mission_revision','run_id','result_id','queue_record_path','queue_record_sha256','receipt_path','receipt_sha256','transaction_path','transaction_sha256','source_evidence_sha256')
$unknown = @($inputValue.PSObject.Properties.Name | Where-Object { $allowed -notcontains $_ })
$missing = @($allowed | Where-Object { !($inputValue.PSObject.Properties.Name -contains $_) })
if ($unknown.Count -or $missing.Count) { throw 'HQ_QUEUE_RECONCILE_CLOSED_INPUT_INVALID' }

$missionId = [string]$inputValue.mission_id
$revision = [int]$inputValue.mission_revision
$runId = [string]$inputValue.run_id
if ($missionId -notmatch '^[A-Za-z0-9._:-]{8,160}$' -or $revision -lt 1 -or $runId -ne "canonical-result-$missionId-$revision" -or [string]$inputValue.result_id -ne $runId) { throw 'HQ_QUEUE_RECONCILE_IDENTITY_INVALID' }
foreach ($field in @('queue_record_sha256','receipt_sha256','transaction_sha256','source_evidence_sha256')) { if ([string]$inputValue.$field -notmatch '^[a-f0-9]{64}$') { throw "HQ_QUEUE_RECONCILE_$($field.ToUpperInvariant())_INVALID" } }

$queueAuthority = Resolve-TsfQueueAuthority -QueueRoot $(if($TestOnlyQueueRoot){$TestOnlyQueueRoot}else{'fleet/missions'}) -TestOnlyAllowAlternateQueueRoot:([bool]$TestOnlyQueueRoot)
if ($TestOnlyQueueRoot -and !$UnsupportedDevelopmentMode) { throw 'HQ_QUEUE_RECONCILE_TEST_ROOT_REQUIRES_DEVELOPMENT_MODE' }
$queuePath = Get-TsfKernelFullPath ([string]$inputValue.queue_record_path)
$receiptPath = Get-TsfKernelFullPath ([string]$inputValue.receipt_path)
$transactionPath = Get-TsfKernelFullPath ([string]$inputValue.transaction_path)
if ($TestOnlyQueueRoot) {
    $fixtureRoot = Get-TsfKernelFullPath (Join-Path $repoRoot '.codex-local\fixtures')
    foreach ($candidate in @($receiptPath,$transactionPath)) { if (!(Test-TsfKernelPathInside $candidate $fixtureRoot) -or !(Test-TsfKernelReparseContained $candidate $repoRoot)) { throw 'HQ_QUEUE_RECONCILE_TEST_EVIDENCE_OUTSIDE_FIXTURES' } }
} else {
    $receiptPath = Assert-TsfRuntimePathUnderCanonicalRoot $receiptPath
    $transactionPath = Assert-TsfRuntimePathUnderCanonicalRoot $transactionPath
}
if (!(Test-TsfKernelPathInside $queuePath ([string]$queueAuthority.root)) -or !(Test-TsfKernelReparseContained $queuePath $repoRoot)) { throw 'HQ_QUEUE_RECONCILE_QUEUE_PATH_OUTSIDE_AUTHORITY' }
foreach ($pair in @(@($receiptPath,[string]$inputValue.receipt_sha256,'RECEIPT'),@($transactionPath,[string]$inputValue.transaction_sha256,'TRANSACTION'))) {
    if (!(Test-Path -LiteralPath $pair[0] -PathType Leaf) -or (Get-FileHash -LiteralPath $pair[0] -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pair[1]) { throw "HQ_QUEUE_RECONCILE_$($pair[2])_HASH_MISMATCH" }
}

$receipt = Read-TsfKernelJson $receiptPath
$transaction = Read-TsfKernelJson $transactionPath
$plan = New-TsfCompleteRuntimePathPlan $missionId $revision $runId
$resultPath = [string]$plan.preservation_plan.artifacts.durable_result
$missionPath = [string]$plan.registry_mission_path
if (!(Test-Path -LiteralPath $resultPath -PathType Leaf) -or !(Test-Path -LiteralPath $missionPath -PathType Leaf)) { throw 'HQ_QUEUE_RECONCILE_CANONICAL_RESULT_OR_MISSION_MISSING' }
$result = Read-TsfKernelJson $resultPath
$preservationPath = [string]$result.preservation_evidence.packet_path
if (!(Test-Path -LiteralPath $preservationPath -PathType Leaf)) { throw 'HQ_QUEUE_RECONCILE_PRESERVATION_MISSING' }
$resultHash = (Get-FileHash -LiteralPath $resultPath -Algorithm SHA256).Hash.ToLowerInvariant()
$preservationHash = (Get-FileHash -LiteralPath $preservationPath -Algorithm SHA256).Hash.ToLowerInvariant()

$fromState = [string]$receipt.queue_state_from
$toState = [string]$receipt.queue_state_to
if ($toState -ne (Get-TsfAdmissionQueueTarget ([string]$receipt.status)) -or $fromState -ne 'postrun_pending' -or [string]$transaction.state -ne 'COMMITTED') { throw 'HQ_QUEUE_RECONCILE_RECEIPT_STATE_INVALID' }
if (![string]::Equals((Get-TsfKernelFullPath ([string]$transaction.source_path)), $queuePath, [StringComparison]::OrdinalIgnoreCase)) { throw 'HQ_QUEUE_RECONCILE_TRANSACTION_SOURCE_MISMATCH' }
$expectedDestination = Join-Path (Join-Path ([string]$queueAuthority.root) $toState) ([IO.Path]::GetFileName($queuePath))
if (![string]::Equals((Get-TsfKernelFullPath ([string]$transaction.destination_path)), (Get-TsfKernelFullPath $expectedDestination), [StringComparison]::OrdinalIgnoreCase) -or ![string]::Equals((Get-TsfKernelFullPath ([string]$receipt.queue_transition_path)), (Get-TsfKernelFullPath $expectedDestination), [StringComparison]::OrdinalIgnoreCase)) { throw 'HQ_QUEUE_RECONCILE_TRANSACTION_DESTINATION_MISMATCH' }

$actualQueuePath = if(Test-Path -LiteralPath $queuePath -PathType Leaf){$queuePath}elseif(Test-Path -LiteralPath $expectedDestination -PathType Leaf){$expectedDestination}else{throw 'HQ_QUEUE_RECONCILE_QUEUE_RECORD_MISSING'}
if ((Get-FileHash -LiteralPath $actualQueuePath -Algorithm SHA256).Hash.ToLowerInvariant() -ne [string]$inputValue.queue_record_sha256) { throw 'HQ_QUEUE_RECONCILE_QUEUE_HASH_MISMATCH' }
$queueDocument = Read-TsfKernelJson $actualQueuePath
$relationship = Test-TsfAdmissionRelationship $result $resultHash $preservationPath $preservationHash $receipt $receiptPath $transaction $transactionPath $queueDocument ([string]$inputValue.queue_record_sha256) $queueAuthority -CanonicalReceiptPath $receiptPath -ExpectedTransactionFileHash ([string]$inputValue.transaction_sha256) -ActualQueueRecordPath $expectedDestination -RepositoryRoot $repoRoot
if (!$relationship.valid) { throw "HQ_QUEUE_RECONCILE_CANONICAL_RELATIONSHIP_INVALID: $($relationship.errors -join '; ')" }

$idempotent = [string]::Equals($actualQueuePath,$expectedDestination,[StringComparison]::OrdinalIgnoreCase)
$transition = $null
if (!$idempotent) {
    $transition = & (Join-Path $repoRoot 'tools\Move-TsfMissionState.ps1') -MissionPath $queuePath -FromState $fromState -ToState $toState -QueueRoot ([string]$queueAuthority.root) -OutFile ([string]$plan.queue_plan.artifacts.transition_08) -TestOnlyAllowAlternateQueueRoot:([bool]$TestOnlyQueueRoot)
    if ([string]$transition.verdict -ne 'GREEN' -or ![bool]$transition.moved) { throw "HQ_QUEUE_RECONCILE_CANONICAL_TRANSITION_REJECTED: $($transition.blocked_reasons -join '; ')" }
}

[Console]::Out.WriteLine(([pscustomobject][ordered]@{
    schema_version = 'tsf_hq_dispatch_queue_reconciliation_result_v1'
    mission_id = $missionId
    mission_revision = $revision
    run_id = $runId
    result_id = $runId
    source_evidence_sha256 = [string]$inputValue.source_evidence_sha256
    canonical_receipt_path = $receiptPath
    canonical_receipt_sha256 = [string]$inputValue.receipt_sha256
    canonical_transaction_path = $transactionPath
    canonical_transaction_sha256 = [string]$inputValue.transaction_sha256
    queue_state_from = $fromState
    queue_state_to = $toState
    queue_record_path = $actualQueuePath
    destination_path = $expectedDestination
    transition_result = $transition
    idempotent_replay = $idempotent
    canonical_history_preserved = $true
    approval_inferred = $false
} | ConvertTo-Json -Compress -Depth 30))
