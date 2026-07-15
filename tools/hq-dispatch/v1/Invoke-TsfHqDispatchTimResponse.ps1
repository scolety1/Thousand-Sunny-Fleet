[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$TestOnlyQueueRoot = ''
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath)))
. (Join-Path $repoRoot 'tools\codex-fleet-enforcement-kernel.ps1')
Import-Module (Join-Path $repoRoot 'tools\TsfDurableContract.psm1') -Force

function Read-ClosedResponseInput {
    $raw = [Console]::In.ReadToEnd()
    if ([Text.Encoding]::UTF8.GetByteCount($raw) -gt 16384) { throw 'TIM_RESPONSE_INPUT_TOO_LARGE' }
    try { $value = $raw | ConvertFrom-Json -ErrorAction Stop } catch { throw 'TIM_RESPONSE_INVALID_JSON' }
    if ($null -eq $value -or $value -is [array]) { throw 'TIM_RESPONSE_INVALID_SHAPE' }
    $allowed = @('mission_id','mission_revision','run_id','result_id','tim_required_request_id','request_evidence_sha256','response_id','response_content_sha256','response_type','operator_confirmation','response_payload')
    $unknown = @($value.PSObject.Properties.Name | Where-Object { $allowed -notcontains $_ })
    if ($unknown.Count) { throw "TIM_RESPONSE_UNKNOWN_FIELD: $($unknown -join ',')" }
    $missing = @($allowed | Where-Object { !($value.PSObject.Properties.Name -contains $_) })
    if ($missing.Count) { throw "TIM_RESPONSE_MISSING_FIELD: $($missing -join ',')" }
    return $value
}

function Get-CanonicalResponseContentHash([object]$Value) {
    $parts = [Collections.Generic.List[string]]::new()
    foreach ($name in @('mission_id','mission_revision','run_id','result_id','tim_required_request_id','request_evidence_sha256','response_id','response_type','operator_confirmation','response_payload')) {
        $text = if ($null -eq $Value.$name) { '' } else { [string]$Value.$name }
        $parts.Add("$name`:$([Text.Encoding]::UTF8.GetByteCount($text))`:$text") | Out-Null
    }
    return Get-TsfRuntimeSha256Text (($parts -join "`n") + "`n")
}

function Assert-BoundedPayload([object]$InputValue) {
    $type = [string]$InputValue.response_type
    $payload = if ($null -eq $InputValue.response_payload) { $null } else { [string]$InputValue.response_payload }
    $expectedPhrase = switch ($type) {
        'APPROVE_EXACT_REQUEST' { 'APPROVE EXACT REQUEST' }
        'DENY_REQUEST' { 'DENY REQUEST' }
        'PROVIDE_CLARIFICATION' { 'PROVIDE CLARIFICATION' }
        default { throw 'TIM_RESPONSE_TYPE_UNKNOWN' }
    }
    if ([string]$InputValue.operator_confirmation -cne $expectedPhrase) { throw 'TIM_RESPONSE_CONFIRMATION_MISMATCH' }
    if ($type -eq 'APPROVE_EXACT_REQUEST' -and $null -ne $payload) { throw 'APPROVAL_RESPONSE_PAYLOAD_PROHIBITED' }
    if ($type -eq 'DENY_REQUEST' -and $null -ne $payload -and ($payload.Length -gt 500 -or $payload.IndexOf([char]0) -ge 0)) { throw 'DENIAL_REASON_INVALID' }
    if ($type -eq 'PROVIDE_CLARIFICATION') {
        if ([string]::IsNullOrWhiteSpace($payload) -or $payload.Length -gt 2000 -or $payload.IndexOf([char]0) -ge 0) { throw 'CLARIFICATION_INVALID' }
        $secretPattern = '(?i)(-----BEGIN [A-Z ]*PRIVATE KEY-----|\bAKIA[0-9A-Z]{16}\b|\b(?:sk|ghp|github_pat)-?[A-Za-z0-9_\-]{16,}\b|\b(?:password|passwd|secret|token|api[_-]?key)\s*[:=])'
        $commandPattern = '(?i)(\bcmd\.exe\b|\bpowershell(?:\.exe)?\b|\bbash\b|\bsh\s+-c\b|Invoke-Expression|Start-Process|\$\(|`[^`]+`|<script\b)'
        if ($payload -match $secretPattern) { throw 'CLARIFICATION_SECRET_LIKE_REJECTED' }
        if ($payload -match $commandPattern) { throw 'CLARIFICATION_EXECUTABLE_CONTENT_REJECTED' }
    }
    return $payload
}

$inputValue = Read-ClosedResponseInput
$payload = Assert-BoundedPayload $inputValue
if ([string]$inputValue.mission_id -notmatch '^[A-Za-z0-9._:-]{8,160}$' -or [int]$inputValue.mission_revision -lt 1) { throw 'TIM_RESPONSE_INVALID_MISSION_IDENTITY' }
foreach ($name in @('request_evidence_sha256','response_content_sha256')) { if ([string]$inputValue.$name -notmatch '^[a-f0-9]{64}$') { throw "TIM_RESPONSE_INVALID_$($name.ToUpperInvariant())" } }
if ([string]$inputValue.tim_required_request_id -notmatch '^timreq-[a-f0-9]{32}$' -or [string]$inputValue.response_id -notmatch '^hq-response-[A-Za-z0-9-]{16,80}$') { throw 'TIM_RESPONSE_INVALID_REQUEST_OR_RESPONSE_ID' }
$computedContentHash = Get-CanonicalResponseContentHash $inputValue
if ($computedContentHash -ne [string]$inputValue.response_content_sha256) { throw 'TIM_RESPONSE_CONTENT_HASH_MISMATCH' }

$missionId = [string]$inputValue.mission_id
$sourceRevision = [int]$inputValue.mission_revision
$sourceRunId = "canonical-result-$missionId-$sourceRevision"
if ([string]$inputValue.run_id -ne $sourceRunId -or [string]$inputValue.result_id -ne $sourceRunId) { throw 'TIM_RESPONSE_RUN_RESULT_IDENTITY_MISMATCH' }
$sourcePlan = New-TsfCompleteRuntimePathPlan -MissionId $missionId -MissionRevision $sourceRevision -RunId $sourceRunId
$evidencePath = [string]$sourcePlan.lifecycle_plan.artifacts.lifecycle_result
if (!(Test-Path -LiteralPath $evidencePath -PathType Leaf)) { throw 'TIM_REQUIRED_TERMINAL_RESULT_MISSING' }
$observedEvidenceHash = (Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($observedEvidenceHash -ne [string]$inputValue.request_evidence_sha256) { throw 'TIM_REQUIRED_REQUEST_EVIDENCE_MISMATCH' }
$terminal = Read-TsfKernelJson $evidencePath
$terminalValidation = Test-TsfLifecycleTerminalResult -Result $terminal -PathPlan $sourcePlan -QueueDocumentSha256 ([string]$terminal.queue_document_sha256) -PolicyFingerprint ([string]$terminal.policy_fingerprint)
if (!$terminalValidation.valid) { throw "TIM_REQUIRED_TERMINAL_RESULT_INVALID: $($terminalValidation.errors -join '; ')" }
if ([string]$terminal.terminal_status -ne 'TIM_REQUIRED' -or [string]$terminal.final_decision -ne 'TIM_REQUIRED') { throw 'RESULT_NOT_TERMINAL_TIM_REQUIRED' }
foreach ($field in @('mission_id','mission_revision','run_id','result_id')) { if ([string]$terminal.$field -ne [string]$inputValue.$field) { throw "TIM_RESPONSE_$($field.ToUpperInvariant())_MISMATCH" } }
$requestValue = $terminal.tim_required_request
$requestValidation = Test-TsfJsonContract $requestValue (Join-Path $repoRoot 'fleet\control\tim-required-request.schema.v1.json')
if (!$requestValidation.valid) { throw "TIM_REQUIRED_REQUEST_INVALID: $($requestValidation.errors -join '; ')" }
if ([string]$requestValue.request_id -ne [string]$inputValue.tim_required_request_id) { throw 'TIM_REQUIRED_REQUEST_ID_MISMATCH' }
if ($requestValue.superseded -or $requestValue.invalidated) { throw 'TIM_REQUIRED_REQUEST_SUPERSEDED_OR_INVALIDATED' }
if ([datetimeoffset]::UtcNow -gt [datetimeoffset]::Parse([string]$requestValue.expires_at)) { throw 'TIM_REQUIRED_REQUEST_EXPIRED' }
if (!$requestValue.original_run_terminal -or $requestValue.worker_active -or $requestValue.app_server_child_active) { throw 'ORIGINAL_RUN_NOT_TERMINAL_OR_CHILD_ACTIVE' }
if ([bool]$terminal.worker_launched) {
    if ([string]::IsNullOrWhiteSpace([string]$terminal.adapter_result_path) -or !(Test-Path -LiteralPath ([string]$terminal.adapter_result_path) -PathType Leaf)) { throw 'WORKER_CLEANUP_EVIDENCE_MISSING' }
    $adapter = Read-TsfKernelJson ([string]$terminal.adapter_result_path)
    if (![bool]$adapter.child_exited -or ![bool]$adapter.no_orphan_process) { throw 'WORKER_OR_APP_SERVER_CHILD_STILL_ACTIVE' }
}
if (@($requestValue.response_types) -notcontains [string]$inputValue.response_type) { throw 'TIM_RESPONSE_TYPE_INCOMPATIBLE_WITH_REQUEST' }
if ([string]$requestValue.request_kind -eq 'APPROVAL_REQUIRED' -and [string]$inputValue.response_type -notin @('APPROVE_EXACT_REQUEST','DENY_REQUEST')) { throw 'TIM_RESPONSE_TYPE_INCOMPATIBLE_WITH_APPROVAL' }
if ([string]$requestValue.request_kind -eq 'CLARIFICATION_REQUIRED' -and [string]$inputValue.response_type -ne 'PROVIDE_CLARIFICATION') { throw 'TIM_RESPONSE_TYPE_INCOMPATIBLE_WITH_CLARIFICATION' }
if ([string]$requestValue.request_kind -eq 'AUTHORITY_DECISION_REQUIRED' -and [string]$inputValue.response_type -ne 'DENY_REQUEST') { throw 'UNKNOWN_AUTHORITY_REQUEST_FAILS_CLOSED' }

$responsePath = [string]$sourcePlan.queue_plan.artifacts.context_update
$mutexName = 'Local\TSF_TIM_RESPONSE_' + (Get-TsfRuntimeSha256Text ([string]$requestValue.request_id)).Substring(0,24)
$mutex = [Threading.Mutex]::new($false,$mutexName)
if (!$mutex.WaitOne([TimeSpan]::FromSeconds(15))) { $mutex.Dispose(); throw 'TIM_RESPONSE_LOCK_TIMEOUT' }
try {
    $idempotent = $false
    $approvalOutcome = $null
    $targetRevision = if ([string]$inputValue.response_type -eq 'DENY_REQUEST') { $null } else { $sourceRevision + 1 }
    $targetPlan = if ($null -eq $targetRevision) { $null } else { New-TsfCompleteRuntimePathPlan -MissionId $missionId -MissionRevision $targetRevision -RunId "canonical-result-$missionId-$targetRevision" }
    if (Test-Path -LiteralPath $responsePath -PathType Leaf) {
        $responseRecord = Read-TsfKernelJson $responsePath
        if ([string]$responseRecord.source_request.request_id -ne [string]$requestValue.request_id) { throw 'TIM_RESPONSE_RECORD_REQUEST_COLLISION' }
        if ([string]$responseRecord.response_id -ne [string]$inputValue.response_id -or [string]$responseRecord.response_content_sha256 -ne $computedContentHash) { throw 'TIM_RESPONSE_CHANGED_REPLAY_REJECTED' }
        $idempotent = $true
    } else {
        if ([string]$inputValue.response_type -eq 'APPROVE_EXACT_REQUEST') {
            $approvalOutcome = New-TsfKernelExactApprovalLedger -Request $requestValue -RequestEvidencePath $evidencePath -RequestEvidenceSha256 $observedEvidenceHash -ResponseId ([string]$inputValue.response_id) -ResponseContentSha256 $computedContentHash -AuthorizedMissionRevision $targetRevision
        }
        $queueRoot = if ($TestOnlyQueueRoot) { Get-TsfKernelFullPath $TestOnlyQueueRoot } else { Join-Path $repoRoot 'fleet\missions' }
        if ($TestOnlyQueueRoot -and !(Test-TsfKernelPathInside $queueRoot (Join-Path $repoRoot '.codex-local\fixtures'))) { throw 'HQ_TEST_QUEUE_ROOT_OUTSIDE_FIXTURES' }
        $revisionLink = if ($null -eq $targetRevision) { $null } else { [pscustomobject][ordered]@{
            mission_id=$missionId;mission_revision=$targetRevision;run_id="canonical-result-$missionId-$targetRevision";mission_path=[string]$targetPlan.registry_mission_path;queue_record_path=(Join-Path (Join-Path $queueRoot 'inbox') "$missionId.r$targetRevision.json")
        } }
        $recordedAt = [datetimeoffset]::UtcNow.ToString('o')
        $authorityGranted = @()
        if ($null -ne $approvalOutcome) { $authorityGranted = @([string]$requestValue.operation) }
        $responseRecord = [pscustomobject][ordered]@{
            schema_version='tsf_tim_required_response_v1'
            response_id=[string]$inputValue.response_id
            response_content_sha256=$computedContentHash
            response_type=[string]$inputValue.response_type
            operator_confirmation=[string]$inputValue.operator_confirmation
            response_payload=$payload
            response_payload_sha256=if($null-eq$payload){$null}else{Get-TsfRuntimeSha256Text $payload}
            recorded_at=$recordedAt
            source_request=[pscustomobject][ordered]@{mission_id=$missionId;mission_revision=$sourceRevision;run_id=$sourceRunId;result_id=$sourceRunId;request_id=[string]$requestValue.request_id}
            request_evidence_sha256=$observedEvidenceHash
            terminal_disposition=switch([string]$inputValue.response_type){'APPROVE_EXACT_REQUEST'{'EXACT_APPROVAL_RELAYED'}'DENY_REQUEST'{'TIM_REQUIRED_DENIED'}'PROVIDE_CLARIFICATION'{'CLARIFICATION_RECORDED'}}
            authority_granted=@($authorityGranted)
            approval=if($null-eq$approvalOutcome){$null}else{[pscustomobject][ordered]@{approval_id=[string]$approvalOutcome.approval_id;ledger_path=[string]$approvalOutcome.ledger_path;ledger_sha256=[string]$approvalOutcome.ledger_sha256;authority_source='CANONICAL_TSF_APPROVAL_LEDGER'}}
            revision=$revisionLink
            idempotency=[pscustomobject][ordered]@{one_response_per_request=$true;changed_replay_rejected=$true;duplicate_revision_prevented=$true;duplicate_queue_prevented=$true}
        }
        $responseValidation = Test-TsfJsonContract $responseRecord (Join-Path $repoRoot 'fleet\control\tim-required-response.schema.v1.json')
        if (!$responseValidation.valid) { throw "TIM_RESPONSE_RECORD_SCHEMA_MISMATCH: $($responseValidation.errors -join '; ')" }
        try { Write-TsfKernelAtomicJson $responseRecord $responsePath | Out-Null } catch {
            if (!(Test-Path -LiteralPath $responsePath -PathType Leaf)) { throw }
            $existing = Read-TsfKernelJson $responsePath
            if ([string]$existing.response_id -ne [string]$inputValue.response_id -or [string]$existing.response_content_sha256 -ne $computedContentHash) { throw 'TIM_RESPONSE_CONCURRENT_CONFLICT' }
            $responseRecord = $existing; $idempotent = $true
        }
    }
    $recordHash = (Get-FileHash -LiteralPath $responsePath -Algorithm SHA256).Hash.ToLowerInvariant()
    [Console]::Out.WriteLine(([pscustomobject][ordered]@{
        schema_version='tsf_hq_dispatch_tim_response_wrapper_result_v1';response_id=[string]$responseRecord.response_id;response_type=[string]$responseRecord.response_type;response_content_sha256=[string]$responseRecord.response_content_sha256;request_id=[string]$responseRecord.source_request.request_id;response_record_path=$responsePath;response_record_sha256=$recordHash;terminal_disposition=[string]$responseRecord.terminal_disposition;approval=$responseRecord.approval;revision=$responseRecord.revision;idempotent_replay=$idempotent;original_result_unchanged=((Get-FileHash -LiteralPath $evidencePath -Algorithm SHA256).Hash.ToLowerInvariant()-eq$observedEvidenceHash);worker_resumed=$false
    } | ConvertTo-Json -Depth 30 -Compress))
} finally {
    $mutex.ReleaseMutex(); $mutex.Dispose()
}
