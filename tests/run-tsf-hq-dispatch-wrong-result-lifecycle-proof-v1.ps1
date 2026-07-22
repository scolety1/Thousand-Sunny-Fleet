[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$TestOnlyIsolatedQueue,
    [string]$EvidenceRoot = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $repo 'tools\codex-fleet-enforcement-kernel.ps1')
$script:TsfRoot = $repo
. (Join-Path $repo 'tools\TsfDurableContract.Canonical.ps1')

$expectedLiteral = 'TSF_V1_CANONICAL_FIRST_LAUNCH_GREEN'
$expectedHash = '192168669db5ba0e1e6eb6877f2ce775defd0654a0fe4e124621aa7b9607c627'
$observedLiteral = 'TSF_HQ_DISPATCH_READ_ONLY_GREEN'
$observedHash = '106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba'
$nonce = ([datetimeoffset]::UtcNow.ToString('yyyyMMddHHmmssfff') + '-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$missionId = "synthetic-hq2-wrong-result-$nonce"
$missionRevision = 1
$runId = "canonical-result-$missionId-$missionRevision"
$fixtureBase = Join-Path $repo '.codex-local\fixtures\hq-dispatch-wrong-result-lifecycle-v1'
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) { $EvidenceRoot = Join-Path $fixtureBase $nonce }
$EvidenceRoot = Get-TsfKernelFullPath $EvidenceRoot
if (!(Test-TsfKernelPathInside $EvidenceRoot $fixtureBase)) { throw 'WRONG_RESULT_EVIDENCE_ROOT_OUTSIDE_TEST_FIXTURES' }
New-Item -ItemType Directory -Force -Path $EvidenceRoot | Out-Null
$queueRoot = if ($TestOnlyIsolatedQueue) { Join-Path $EvidenceRoot 'queue' } else { Get-TsfCanonicalProductionQueueRoot }
$baselineStatus = @(& git -C $repo status --porcelain=v2)
$candidateGitState = Get-TsfKernelGitState -RepoPath $repo
if (!$candidateGitState.can_capture -or !$candidateGitState.branch_identity_available -or ([string]$candidateGitState.head) -notmatch '^[a-f0-9]{40,64}$') {
    throw "WRONG_RESULT_CANDIDATE_GIT_IDENTITY_UNAVAILABLE: $([string]$candidateGitState.error)"
}
$candidateHead = [string]$candidateGitState.head
$candidateTree = (& git -C $repo rev-parse 'HEAD^{tree}').Trim()
$candidateBranch = [string]$candidateGitState.branch
$script:assertions = 0

function Assert-Case([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (!$Condition) { throw "ASSERTION_FAILED: $Message" }
}

function Write-JsonFile([object]$Value, [string]$Path) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    [IO.File]::WriteAllText($Path, (($Value | ConvertTo-Json -Depth 60) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
}

function Read-JsonFile([string]$Path) {
    Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}

function Copy-Value([object]$Value) {
    $Value | ConvertTo-Json -Depth 60 | ConvertFrom-Json
}

function Get-Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Invoke-ConsoleJsonScript([string]$ScriptPath, [hashtable]$Parameters, [object]$InputValue) {
    function Quote-Argument([string]$Value) {
        if ($Value -notmatch '[\s"]') { return $Value }
        '"' + ($Value -replace '(\\*)"', '$1$1\"' -replace '(\\+)$', '$1$1') + '"'
    }
    $arguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath)
    foreach ($entry in $Parameters.GetEnumerator()) {
        $arguments += "-$([string]$entry.Key)"
        if ($entry.Value -isnot [bool] -or ![bool]$entry.Value) { $arguments += [string]$entry.Value }
    }
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
    $start.Arguments = (($arguments | ForEach-Object { Quote-Argument ([string]$_) }) -join ' ')
    $start.WorkingDirectory = $repo
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $process.StandardInput.Write(($InputValue | ConvertTo-Json -Depth 60 -Compress))
    $process.StandardInput.Close()
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    $exitCode = $process.ExitCode
    $process.Dispose()
    [pscustomobject]@{ exit_code = $exitCode; stdout = $stdout.Trim(); error = $stderr.Trim() }
}

function ConvertFrom-LastJsonLine([string]$Text) {
    $lines = @($Text -split '\r?\n' | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if (!$lines.Count) { throw 'EXPECTED_JSON_OUTPUT_WAS_EMPTY' }
    $lines[-1] | ConvertFrom-Json -ErrorAction Stop
}

function Move-QueueRecord([string]$Path, [string]$From, [string]$To, [int]$Sequence) {
    $params = @{
        MissionPath = $Path
        FromState = $From
        ToState = $To
        QueueRoot = $queueRoot
        OutFile = (Join-Path $EvidenceRoot ('transition-{0:d2}-{1}-to-{2}.json' -f $Sequence, $From, $To))
    }
    if ($TestOnlyIsolatedQueue) { $params.TestOnlyAllowAlternateQueueRoot = $true }
    $transition = & (Join-Path $repo 'tools\Move-TsfMissionState.ps1') @params
    Assert-Case ([string]$transition.verdict -eq 'GREEN') "$From -> $To transition is canonical"
    Assert-Case (Test-Path -LiteralPath ([string]$transition.destination_path) -PathType Leaf) "$To queue record exists"
    [string]$transition.destination_path
}

$previewScript = Join-Path $repo 'tools\hq-dispatch\v1\Invoke-TsfHqDispatchRoutePreview.ps1'
$missionScript = Join-Path $repo 'tools\hq-dispatch\v1\New-TsfHqDispatchGovernedMission.ps1'
$naturalRequest = "Read only the TSF policy fixture and return exactly $expectedLiteral."

$previewProcess = Invoke-ConsoleJsonScript $previewScript @{} ([pscustomobject]@{ natural_request = $naturalRequest })
Assert-Case ($previewProcess.exit_code -eq 0) "reviewed route preview exits zero: $($previewProcess.error)"
$preview = ConvertFrom-LastJsonLine $previewProcess.stdout
Assert-Case ([string]$preview.result_validation_mode -eq 'EXACT_LITERAL_V1') 'preview selects the exact-literal contract'
Assert-Case ([string]$preview.exact_response_contract.expected_literal -ceq $expectedLiteral) 'preview retains the reviewed expected literal byte-for-byte'
Assert-Case ([string]$preview.exact_response_contract.expected_literal_sha256 -eq $expectedHash) 'preview retains the reviewed expected SHA-256'
$previewArtifactPath = Get-TsfKernelFullPath ([string]$preview.artifact.relative_path) $repo
$previewArtifactHash = Get-Hash $previewArtifactPath
$reviewedContract = Copy-Value $preview.exact_response_contract
$reviewedContract.preview_binding.preview_artifact_sha256 = $previewArtifactHash
$submission = [pscustomobject][ordered]@{
    mission_id = $missionId
    mission_revision = $missionRevision
    natural_request = $naturalRequest
    preview_id = [string]$preview.preview_id
    preview_sha256 = $previewArtifactHash
    request_hash = Get-TsfKernelRawTextSha256 $naturalRequest
    submission_id = "hq-submission-$([guid]::NewGuid())"
    reviewed_exact_response_contract = $reviewedContract
}
$missionParameters = @{}
if ($TestOnlyIsolatedQueue) {
    $missionParameters.TestOnlyQueueRoot = $queueRoot
    $missionParameters.UnsupportedDevelopmentMode = $true
}
$injected = Copy-Value $submission
$injected | Add-Member -NotePropertyName verifier_result -NotePropertyValue ([pscustomobject]@{ verdict = 'GREEN' })
$injected | Add-Member -NotePropertyName admission_result -NotePropertyValue ([pscustomobject]@{ status = 'ADMITTED' })
$injectedProcess = Invoke-ConsoleJsonScript $missionScript $missionParameters $injected
Assert-Case ($injectedProcess.exit_code -ne 0) 'closed submission input rejects caller-supplied verifier and admission results'
Assert-Case ($injectedProcess.error -match 'HQ_SUBMISSION_UNKNOWN_FIELD' -and $injectedProcess.error -match 'verifier_result' -and $injectedProcess.error -match 'admission_result') 'caller outcome injection has the exact closed-input disposition'

$missionProcess = Invoke-ConsoleJsonScript $missionScript $missionParameters $submission
Assert-Case ($missionProcess.exit_code -eq 0) "governed mission preparation exits zero: $($missionProcess.error)"
$preparation = ConvertFrom-LastJsonLine $missionProcess.stdout
Assert-Case ([string]$preparation.mission_id -eq $missionId -and [int]$preparation.mission_revision -eq 1) 'submission revalidation preserves mission identity'
Assert-Case ([string]$preparation.exact_response_contract.expected_literal_sha256 -eq $expectedHash) 'submission revalidation preserves the reviewed exact contract'
Assert-Case ([string]$preparation.queue_state -eq 'inbox' -and (Test-Path -LiteralPath ([string]$preparation.queue_record_path) -PathType Leaf)) 'one canonical inbox queue document is prepared'

$queuePath = [string]$preparation.queue_record_path
$queueDocument = Read-JsonFile $queuePath
$queueCheck = Test-TsfCanonicalQueueDocument -QueueDocument $queueDocument -ExpectedMission $queueDocument.durable_mission -RepositoryRoot $repo
Assert-Case ([bool]$queueCheck.valid) 'prepared queue document passes the complete canonical validator'
Assert-Case ([string]$queueCheck.queue_document_sha256 -eq [string]$preparation.queue_document_sha256) 'queue document identity matches mission preparation'
Assert-Case ([string]$queueDocument.mission_packet.exact_response_contract.expected_literal_sha256 -eq $expectedHash) 'mission packet retains the expected contract'
Assert-Case ([string]$queueDocument.worker_instruction_packet.exact_response_contract.expected_literal -ceq $expectedLiteral) 'worker instruction retains the expected literal'
$initialQueueFileHash = Get-Hash $queuePath

$effectiveMissionPath = Join-Path $EvidenceRoot 'effective-mission.json'
Write-JsonFile $queueCheck.effective_mission $effectiveMissionPath
$promptPath = Join-Path $EvidenceRoot 'worker-prompt.txt'
[IO.File]::WriteAllText($promptPath, "Return exactly $expectedLiteral", [Text.UTF8Encoding]::new($false))
$preflightPath = Join-Path $EvidenceRoot 'preflight-result.json'
Write-JsonFile ([pscustomobject]@{ schema_version = 1; mission_id = $missionId; verdict = 'GREEN'; preflight_approved = $true }) $preflightPath

$queuePath = Move-QueueRecord $queuePath 'inbox' 'drafted' 1
$queuePath = Move-QueueRecord $queuePath 'drafted' 'preflight_pending' 2
$queuePath = Move-QueueRecord $queuePath 'preflight_pending' 'approved_for_worker' 3
$queuePath = Move-QueueRecord $queuePath 'approved_for_worker' 'worker_running' 4

$adapterDirectory = Join-Path $EvidenceRoot 'adapter'
New-Item -ItemType Directory -Force -Path $adapterDirectory | Out-Null
$adapterPath = Join-Path $adapterDirectory 'adapter-result.json'
$eventPath = Join-Path $adapterDirectory 'event-journal.jsonl'
$stderrPath = Join-Path $adapterDirectory 'stderr.log'
$adapterArgs = @(
    (Join-Path $repo 'tools\tsf-codex-app-server-adapter.mjs'),
    '--codex-executable', (Join-Path $repo 'tests\fixtures\fleet\durable-contract\fake-codex-app-server.mjs'),
    '--mission-id', $missionId, '--mission-revision', '1',
    '--policy-fingerprint', ([string]$preparation.policy_fingerprint),
    '--queue-document-sha256', ([string]$preparation.queue_document_sha256),
    '--run-id', $runId, '--result-id', $runId,
    '--cwd', $repo, '--model', 'gpt-5.6-luna',
    '--mission-requested-effort', 'LIGHT', '--canonical-resolved-effort', 'LIGHT',
    '--required-effort-assurance', 'RECOMMENDED_ONLY', '--effort', 'low', '--sandbox', 'read-only',
    '--prompt-file', $promptPath, '--output-dir', $adapterDirectory,
    '--result-file', $adapterPath, '--event-file', $eventPath, '--stderr-file', $stderrPath,
    '--timeout-seconds', '10', '--expires-at', ([datetimeoffset]::UtcNow.AddMinutes(10).ToString('o')),
    '--expected-response-sha256', $expectedHash
)
$priorFakeMode = $env:TSF_FAKE_APP_SERVER_MODE
try {
    $env:TSF_FAKE_APP_SERVER_MODE = 'old-substituted'
    $adapterStdout = @(& node @adapterArgs 2>&1)
    $adapterExit = $LASTEXITCODE
} finally {
    if ($null -eq $priorFakeMode) { Remove-Item Env:TSF_FAKE_APP_SERVER_MODE -ErrorAction SilentlyContinue } else { $env:TSF_FAKE_APP_SERVER_MODE = $priorFakeMode }
}
Assert-Case ($adapterExit -eq 0) "deterministic adapter transport exits zero: $($adapterStdout -join ' ')"
$adapter = Read-JsonFile $adapterPath
Assert-Case ([bool]$adapter.transport_success -and [bool]$adapter.success) 'worker transport succeeds independently of result semantics'
Assert-Case ([string]$adapter.final_response -ceq $observedLiteral -and [string]$adapter.observed_response_sha256 -eq $observedHash) 'deterministic worker returns the specified obsolete literal and hash'
Assert-Case (![bool]$adapter.semantic_response_success -and ![bool]$adapter.response_exact_match) 'adapter records semantic failure despite transport success'
Assert-Case ([string]$adapter.expected_response_sha256 -eq $expectedHash) 'adapter mismatch remains bound to the reviewed expected hash'

$adapterHash = Get-Hash $adapterPath
$workerPath = Join-Path $EvidenceRoot 'worker-result.json'
$exactEvidence = [pscustomobject][ordered]@{
    mission_id = $missionId; mission_revision = 1; run_id = $runId; result_id = $runId
    thread_id = [string]$adapter.thread_id; turn_id = [string]$adapter.turn_id
    adapter_result_path = $adapterPath; adapter_result_sha256 = $adapterHash
    validation_mode = 'EXACT_LITERAL_V1'; normalization_version = [string]$reviewedContract.normalization_version
    expected_literal = $expectedLiteral; observed_literal = $observedLiteral; observed_representation = 'SAFE_LITERAL'
    semantic_contract_sha256 = [string]$reviewedContract.semantic_contract_sha256
    expected_response_sha256 = $expectedHash; observed_response_sha256 = $observedHash
    transport_success = $true; exact_match = $false; semantic_success = $false
}
$worker = [pscustomobject][ordered]@{
    schema_version = 1; mission_id = $missionId
    worker_role = [string]$queueCheck.effective_mission.role_extension.worker_role
    role_output_contract_satisfied = $false
    worker_status = 'BLOCKED_EXACT_RESPONSE_MISMATCH'
    codex_cli_detected = $true; codex_cli_invoked = $true; codex_exit_code = $adapterExit
    files_touched = @(); files_created = @(); unexpected_touched_files = @(); restricted_actions_attempted = @()
    blocked_reasons = @('Observed response differs from the reviewed exact-literal contract.')
    adapter_result_path = $adapterPath; adapter_result_sha256 = $adapterHash
    thread_id = [string]$adapter.thread_id; turn_id = [string]$adapter.turn_id
    exact_response_evidence = $exactEvidence
    observation_claims = $adapter.observation_claims
    tests = @([pscustomobject]@{ test_id = 'hq-dispatch-read-only-exact-response'; status = 'FAIL'; observed = 'Exact response hash comparison'; evidence = $observedHash })
    approval_use = @()
}
Write-JsonFile $worker $workerPath
$queuePath = Move-QueueRecord $queuePath 'worker_running' 'postrun_pending' 5
$verifierPath = Join-Path $EvidenceRoot 'verifier-result.json'
$verifier = Invoke-TsfKernelPostRunVerify -MissionPath $effectiveMissionPath -WorkerResultPath $workerPath -CanonicalQueueDocumentPath $queuePath -OutFile $verifierPath -StateRoot (Join-Path $EvidenceRoot 'kernel-state')
Assert-Case ([string]$verifier.verdict -eq 'RED' -and ![bool]$verifier.verified) 'independent post-run verifier is RED'
Assert-Case ([bool]$verifier.exact_response_evidence.independently_recomputed -and ![bool]$verifier.exact_response_evidence.exact_match) 'verifier independently recomputes the mismatch'
Assert-Case ([string]$verifier.exact_response_evidence.expected_response_sha256 -eq $expectedHash -and [string]$verifier.exact_response_evidence.observed_response_sha256 -eq $observedHash) 'verifier preserves both exact response identities'

$preservation = Write-TsfKernelPreservationPacket -MissionPath $effectiveMissionPath -PreflightResultPath $preflightPath -WorkerResultPath $workerPath -VerifierResultPath $verifierPath -AdapterResultPath $adapterPath -EventJournalPath $eventPath -QueueDocumentPath $queuePath -PromptPath $promptPath -StderrPath $stderrPath -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $runId -DurableMission $queueDocument.durable_mission -ExactNextAction 'Reject admission; preserve the mismatch and require a newly reviewed mission.' -TestOnlyAllowSyntheticProducerRegistry
Assert-Case ([string]$preservation.final_decision -eq 'RED' -and (Test-Path -LiteralPath ([string]$preservation.packet_file) -PathType Leaf)) 'canonical preservation retains the RED verifier outcome'
$packetHashBeforeReplay = Get-Hash ([string]$preservation.packet_file)
$manifestHashBeforeReplay = Get-Hash ([string]$preservation.manifest_path)
$preservationReplay = Write-TsfKernelPreservationPacket -MissionPath $effectiveMissionPath -PreflightResultPath $preflightPath -WorkerResultPath $workerPath -VerifierResultPath $verifierPath -AdapterResultPath $adapterPath -EventJournalPath $eventPath -QueueDocumentPath $queuePath -PromptPath $promptPath -StderrPath $stderrPath -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $runId -DurableMission $queueDocument.durable_mission -ExactNextAction 'Reject admission; preserve the mismatch and require a newly reviewed mission.' -TestOnlyAllowSyntheticProducerRegistry
Assert-Case ([bool]$preservationReplay.idempotent_replay) 'exact preservation replay is idempotent'
Assert-Case ((Get-Hash ([string]$preservation.packet_file)) -eq $packetHashBeforeReplay -and (Get-Hash ([string]$preservation.manifest_path)) -eq $manifestHashBeforeReplay) 'exact replay leaves packet and manifest byte-identical'

$lifecyclePlan = New-TsfRuntimeStoragePlan (Get-TsfCanonicalRuntimeRoot) $missionId 1 $runId -Layout lifecycle_control
$registryPath = [string]$lifecyclePlan.artifacts.producer_registry
$registryHashBeforeChangedReplay = Get-Hash $registryPath
$changedDurableMission = Copy-Value $queueDocument.durable_mission
$changedDurableMission.policy.fingerprint = 'f' * 64
$changedReplayBlocked = $false
$changedReplayError = ''
try {
    Write-TsfKernelPreservationPacket -MissionPath $effectiveMissionPath -PreflightResultPath $preflightPath -WorkerResultPath $workerPath -VerifierResultPath $verifierPath -AdapterResultPath $adapterPath -EventJournalPath $eventPath -QueueDocumentPath $queuePath -PromptPath $promptPath -StderrPath $stderrPath -OutputDirectory (Get-TsfCanonicalRuntimeRoot) -RunId $runId -DurableMission $changedDurableMission -TestOnlyAllowSyntheticProducerRegistry | Out-Null
} catch {
    $changedReplayBlocked = $true
    $changedReplayError = $_.Exception.Message
}
Assert-Case ($changedReplayBlocked -and $changedReplayError -match 'PRODUCER_EVIDENCE_REGISTRY_INVALID') 'changed durable binding replay fails closed before acceptance'
Assert-Case ((Get-Hash ([string]$preservation.packet_file)) -eq $packetHashBeforeReplay -and (Get-Hash ([string]$preservation.manifest_path)) -eq $manifestHashBeforeReplay -and (Get-Hash $registryPath) -eq $registryHashBeforeChangedReplay) 'changed replay preserves the original packet, manifest, and registry'

$completePlan = New-TsfCompleteRuntimePathPlan -MissionId $missionId -MissionRevision 1 -RunId $runId
$registry = Read-JsonFile $registryPath
$gitState = Get-TsfKernelGitState $repo
$lifecyclePath = [string]$completePlan.lifecycle_plan.artifacts.lifecycle_result
$lifecycle = New-TsfLifecycleTerminalResult -TerminalStatus 'BLOCKED_VERIFIER' -MissionId $missionId -MissionRevision 1 -RunId $runId -QueueDocumentSha256 ([string]$preparation.queue_document_sha256) -PolicyFingerprint ([string]$preparation.policy_fingerprint) -Repository $repo -Branch ([string]$gitState.branch) -Worktree $repo -ResultPath $lifecyclePath -ProducerRegistryPath $registryPath -ProducerBindingIdentitySha256 ([string]$registry.binding_identity_sha256) -OrchestratorInvocationIdentity ([string]$registry.binding.orchestrator_invocation_identity) -OutcomeStage 'TERMINAL_RESULT' -MissionPath ([string]$preparation.mission_path) -EffectiveMissionPath $effectiveMissionPath -QueueMissionPath $queuePath -QueueState 'postrun_pending' -PreflightVerdict 'GREEN' -PreflightApproved $true -ApprovalSemantics 'NO_APPROVAL_REQUIRED' -WorkerStatus 'BLOCKED_EXACT_RESPONSE_MISMATCH' -VerifierVerdict 'RED' -PreservationStatus 'PRESERVED' -PreservationPacketFile ([string]$preservation.packet_file) -PreservationManifestPath ([string]$preservation.manifest_path) -AdapterResultPath $adapterPath -WorkerResultPath $workerPath -VerifierResultPath $verifierPath -WorkerLaunched $true -EvidencePreserved $true -RuntimePathMaximum ([int]$completePlan.maximum_path_length) -BlockedReasons @('Independent exact-response verifier rejected the obsolete worker literal.')
$lifecycleValidation = Test-TsfLifecycleTerminalResult -Result $lifecycle -PathPlan $completePlan -QueueDocumentSha256 ([string]$preparation.queue_document_sha256) -PolicyFingerprint ([string]$preparation.policy_fingerprint)
Assert-Case ([bool]$lifecycleValidation.valid -and [string]$lifecycle.final_decision -eq 'RED') 'canonical lifecycle terminal result records the semantic mismatch as BLOCKED_VERIFIER'
Write-TsfKernelJson $lifecycle $lifecyclePath
$producerCapability = New-TsfTestOnlyProducerCapability -MissionId $missionId -MissionRevision 1 -RunId $runId -PolicyFingerprint ([string]$preparation.policy_fingerprint) -QueueDocumentSha256 ([string]$preparation.queue_document_sha256) -Repository $repo -Branch ([string]$gitState.branch) -Worktree $repo -ExistingRegistryPath $registryPath
Register-TsfProducerEvidence $registryPath lifecycle_result $lifecyclePath $producerCapability | Out-Null
$lifecycleProvenance = Test-TsfLifecycleTerminalResult -Result $lifecycle -PathPlan $completePlan -QueueDocumentSha256 ([string]$preparation.queue_document_sha256) -PolicyFingerprint ([string]$preparation.policy_fingerprint) -RequireProducerProvenance
Assert-Case ([bool]$lifecycleProvenance.valid) 'lifecycle terminal result has registered producer provenance'

$queuePath = Move-QueueRecord $queuePath 'postrun_pending' 'complete_review_only' 6
Assert-Case ((Get-Hash $queuePath) -eq $initialQueueFileHash) 'queue evidence remains byte-identical and readable across the negative lifecycle'
$terminalQueueDocument = Read-JsonFile $queuePath
$terminalQueueCheck = Test-TsfCanonicalQueueDocument -QueueDocument $terminalQueueDocument -ExpectedMission $terminalQueueDocument.durable_mission -RepositoryRoot $repo
Assert-Case ([bool]$terminalQueueCheck.valid) 'terminal negative queue evidence still passes the complete canonical document validator'
if (!$TestOnlyIsolatedQueue) {
    $terminalFileCheck = Test-TsfCanonicalQueueRecordFile -QueueRecordPath $queuePath -QueueRoot $queueRoot -ExpectedQueueState 'complete_review_only' -ExpectedMissionId $missionId -ExpectedMissionRevision 1 -RepositoryRoot $repo
    Assert-Case ([bool]$terminalFileCheck.valid -and [string]$terminalFileCheck.canonical_validator -eq 'Test-TsfCanonicalQueueDocument') 'Doctor file authority validates the final canonical negative record'
}

$admissionReceipts = @(Get-ChildItem -LiteralPath ([string]$preservation.packet_directory) -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^(a|t)-[a-z2-7]{32}\.json$' })
Assert-Case ($admissionReceipts.Count -eq 0) 'verifier RED produces no admission or transaction receipt'
$relaySourcePath = Join-Path $repo 'tools\hq-dispatch\v1\mission-relay.mjs'
$relaySource = Get-Content -LiteralPath $relaySourcePath -Raw
Assert-Case ($relaySource -match 'if \(admission && \["ADMITTED", "ADMITTED_WITH_CAVEATS"\]\.includes\(admission\.status\)\)' -and $relaySource -match 'No successful canonical admission receipt exists') 'UI status authority requires a successful canonical receipt and otherwise presents rejection'

$doctor = $null
$doctorExit = $null
if (!$TestOnlyIsolatedQueue) {
    $doctorOutput = @(& node (Join-Path $repo 'tools\hq-dispatch\v1\reliability-cli.mjs') doctor 2>&1)
    $doctorExit = $LASTEXITCODE
    $doctor = ($doctorOutput -join [Environment]::NewLine) | ConvertFrom-Json
    $runtimePolicy = @($doctor.checks | Where-Object { [string]$_.id -eq 'runtime_queue_evidence_policy' })
    $doctorItem = @($doctor.reconciliation.items | Where-Object { [string]$_.mission_id -eq $missionId -and [int]$_.mission_revision -eq 1 })
    Assert-Case ($runtimePolicy.Count -eq 1 -and [string]$runtimePolicy[0].status -eq 'GREEN') 'Doctor inventories the negative record without a canonical-validation error'
    Assert-Case ($doctorItem.Count -eq 1 -and [string]$doctorItem[0].last_known_queue_state -eq 'complete_review_only') 'Doctor reconciliation exposes the truthful terminal queue state'
    Assert-Case ([string]$doctorItem[0].admission_state -notmatch '^ADMITTED') 'Doctor never projects the negative record as admitted success'
}

$finalStatus = @(& git -C $repo status --porcelain=v2)
Assert-Case (($finalStatus -join "`n") -ceq ($baselineStatus -join "`n")) 'generated negative proof leaves source Git status unchanged'
if (!$TestOnlyIsolatedQueue) { Assert-Case ($finalStatus.Count -eq 0) 'production canonical proof leaves the committed source worktree clean' }

$summary = [pscustomobject][ordered]@{
    schema_version = 'tsf_hq_dispatch_wrong_result_lifecycle_proof_v1'
    generated_at = [datetimeoffset]::UtcNow.ToString('o')
    execution_classification = 'DETERMINISTIC_FAKE_APP_SERVER_WITH_PRODUCTION_ADAPTER_AND_KERNEL'
    real_app_server_execution = $false
    queue_authority = if ($TestOnlyIsolatedQueue) { 'TEST_ONLY_ISOLATED' } else { 'PRODUCTION_CANONICAL' }
    candidate = [pscustomobject]@{ head = $candidateHead; tree = $candidateTree; branch = if ($candidateBranch) { $candidateBranch } else { $null }; worktree = $repo; detached = [string]::IsNullOrWhiteSpace($candidateBranch) }
    mission_id = $missionId
    mission_revision = 1
    run_id = $runId
    expected_literal = $expectedLiteral
    expected_sha256 = $expectedHash
    observed_literal = $observedLiteral
    observed_sha256 = $observedHash
    transport_success = [bool]$adapter.transport_success
    semantic_response_success = [bool]$adapter.semantic_response_success
    response_exact_match = [bool]$adapter.response_exact_match
    verifier_verdict = [string]$verifier.verdict
    verifier_independently_recomputed = [bool]$verifier.exact_response_evidence.independently_recomputed
    lifecycle_terminal_status = [string]$lifecycle.terminal_status
    lifecycle_final_decision = [string]$lifecycle.final_decision
    preservation_packet_path = [string]$preservation.packet_file
    preservation_packet_sha256 = Get-Hash ([string]$preservation.packet_file)
    preservation_manifest_path = [string]$preservation.manifest_path
    preservation_manifest_sha256 = Get-Hash ([string]$preservation.manifest_path)
    exact_replay_idempotent = [bool]$preservationReplay.idempotent_replay
    changed_replay_fail_closed = $changedReplayBlocked
    changed_replay_error = $changedReplayError
    queue_record_path = $queuePath
    queue_document_sha256 = [string]$terminalQueueCheck.queue_document_sha256
    queue_state = 'complete_review_only'
    admission_invoked = $false
    admission_receipt_count = $admissionReceipts.Count
    admitted_success_presented = $false
    ui_terminal_projection = 'REJECTED_NO_SUCCESSFUL_CANONICAL_ADMISSION_RECEIPT'
    caller_verifier_or_admission_accepted = $false
    doctor_exit = $doctorExit
    doctor_overall_status = if ($null -ne $doctor) { [string]$doctor.overall_status } else { 'NOT_APPLICABLE_ISOLATED_PRE_AMEND' }
    doctor_canonical_record_validated = !$TestOnlyIsolatedQueue
    source_status_unchanged = $true
    source_clean = $finalStatus.Count -eq 0
    assertions = $script:assertions
    evidence_root = $EvidenceRoot
}
$summaryPath = Join-Path $EvidenceRoot 'WRONG_RESULT_LIFECYCLE_PROOF.json'
Write-JsonFile $summary $summaryPath

"TSF_HQ_DISPATCH_WRONG_RESULT_LIFECYCLE_PASS assertions=$script:assertions classification=DETERMINISTIC mission_id=$missionId evidence=$summaryPath"
