[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory)][string]$FinalAcceptanceEvidenceRoot,
    [Parameter(Mandatory)][string]$ProductionProofStdoutPath,
    [Parameter(Mandatory)][string]$WrongResultProofPath,
    [Parameter(Mandatory)][string]$InterruptionProofPath,
    [Parameter(Mandatory)][string]$ResponsiveProofPath,
    [ValidateSet('HEAD', 'INDEX')][string]$PacketHashSource = 'HEAD'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$packet = Join-Path $repo 'docs\hq\tsf_v1_response_contract_runtime_cleanliness_hotfix_v1_20260718'
. (Join-Path $repo 'tests\support\TsfPacketEvidencePath.ps1')
$head = (& git -C $repo rev-parse HEAD).Trim()
$tree = (& git -C $repo rev-parse 'HEAD^{tree}').Trim()
$parent = (& git -C $repo rev-parse 'HEAD^').Trim()
$subject = (& git -C $repo show -s --format=%s HEAD).Trim()
$script:assertions = 0

function Assert-Case([bool]$Condition, [string]$Message) {
    $script:assertions++
    if (!$Condition) { throw "PACKET_SELF_CHECK_FAILED: $Message" }
}

function Get-Hash([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Read-Json([string]$Path) {
    Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
}

function Resolve-EvidencePath([string]$Path) {
    $approvedRoots = @($repo, 'C:\TSF_HOTFIX2', 'C:\TSFDA4', 'C:\TSF_HOTFIX2_NATIVE_PROOF2')
    Resolve-TsfPacketEvidencePath -Path $Path -RepositoryRoot $repo -ApprovedRoots $approvedRoots -ExpectedType Leaf
}

Assert-Case ($parent -eq '7cceadcf6fa6a6c65000c72604023f87fc84f728') 'final candidate parent differs from the required base'
Assert-Case ((& git -C $repo rev-list --count '7cceadcf6fa6a6c65000c72604023f87fc84f728..HEAD').Trim() -eq '1') 'final history is not exactly one commit over the base'
Assert-Case ($subject -ceq 'fix: preserve exact response contracts and runtime cleanliness') 'final commit subject differs from the required subject'

$coveragePath = Join-Path $packet 'EXECUTED_TEST_COVERAGE.csv'
$coverage = @(Import-Csv -LiteralPath $coveragePath)
$requiredPreAmend = @('doctor-canonical-runtime-cleanliness', 'wrong-result-integrated-lifecycle', 'exact-response-contract', 'exact-response-verifier', 'recovery-result-contract-adversarial', 'interruption-proof-corrected-1', 'interruption-proof-corrected-2', 'responsive-operator-ui', 'stop-owner-refresh-adversarial', 'interruption-proof-fresh-owner-stop', 'stop-stable-authentication-adversarial', 'detached-full-acceptance-working-tree')
$requiredPacketSeal = @('packet-seal-proof2-native-fetch-1', 'packet-seal-proof2-native-fetch-2', 'packet-seal-proof2-interruption-1', 'packet-seal-proof2-interruption-2', 'packet-seal-proof2-full-acceptance', 'packet-seal-proof2-real-exact-response', 'packet-seal-proof2-wrong-result', 'packet-seal-proof2-cross-revision', 'packet-seal-proof2-runtime-sentinel', 'packet-seal-proof2-responsive', 'packet-seal-proof2-self-check')
$packetSealHead = '57c0b873808c416c4c4d2d7d689c02f198ff7cbb'
$packetSealTree = '65e8639d08c5582549f89028f9614bff8e62c8ba'
Assert-Case ($coverage.Count -eq ($requiredPreAmend.Count + $requiredPacketSeal.Count + 1)) 'tracked corrected, packet-seal proof, and preserved-failure coverage row count is incomplete'
Assert-Case (@($coverage.test_id | Sort-Object -Unique).Count -eq $coverage.Count) 'tracked coverage has a duplicate suite id'
foreach ($id in $requiredPreAmend) { Assert-Case (@($coverage | Where-Object test_id -eq $id).Count -eq 1) "tracked coverage is missing $id" }
foreach ($id in $requiredPacketSeal) { Assert-Case (@($coverage | Where-Object test_id -eq $id).Count -eq 1) "tracked packet-seal coverage is missing $id" }
$preservedFailure = @($coverage | Where-Object test_id -eq 'interruption-proof-original-blocker')
Assert-Case ($preservedFailure.Count -eq 1) 'tracked coverage is missing the original managed-wrapper failure'
foreach ($row in $coverage) {
    Assert-Case (![string]::IsNullOrWhiteSpace([string]$row.command) -and ![string]::IsNullOrWhiteSpace([string]$row.execution_classification)) "coverage command/classification missing for $($row.test_id)"
    if ([string]$row.test_id -eq 'interruption-proof-original-blocker') {
        Assert-Case ([string]$row.exit_code -eq 'EXIT_NOT_RELIABLY_OBSERVED' -and [string]$row.status -eq 'PRESERVED_FAILURE' -and [int]$row.assertions -eq 0) 'original managed-wrapper failure was assigned a fabricated numeric exit or mislabeled'
        Assert-Case ([string]$row.binding_scope -eq 'PRE_AMEND_PRESERVED_FAILURE') 'original managed-wrapper failure binding scope is mislabeled'
    } else {
        Assert-Case ([int]$row.exit_code -eq 0 -and [string]$row.status -eq 'PASS' -and [int]$row.assertions -gt 0) "coverage result/count invalid for $($row.test_id)"
        $expectedScope = if ($requiredPacketSeal -contains [string]$row.test_id) { 'PRE_FINAL_PACKET_SEAL_PROOF2' } else { 'PRE_AMEND_CORRECTION_WORKTREE' }
        Assert-Case ([string]$row.binding_scope -eq $expectedScope) "coverage binding scope is mislabeled for $($row.test_id)"
        if ($requiredPacketSeal -contains [string]$row.test_id) {
            Assert-Case ([string]$row.candidate_head -eq $packetSealHead -and [string]$row.candidate_tree -eq $packetSealTree) "packet-seal evidence is not bound to the preserved Proof 2 candidate: $($row.test_id)"
        }
    }
    foreach ($kind in @('stdout', 'stderr')) {
        $path = Resolve-EvidencePath ([string]$row."${kind}_path")
        Assert-Case (Test-Path -LiteralPath $path -PathType Leaf) "$kind evidence missing for $($row.test_id)"
        Assert-Case ((Get-Hash $path) -eq [string]$row."${kind}_sha256") "$kind evidence hash mismatch for $($row.test_id)"
    }
    if ([string]$row.test_id -eq 'detached-full-acceptance-working-tree') {
        $stderrManifest = Test-TsfPerCommandStderrManifest `
            -ManifestPath ([string]$row.stderr_path) `
            -RepositoryRoot $repo `
            -ApprovedRoots @($repo, 'C:\TSFDA4') `
            -ExpectedSuiteId ([string]$row.test_id) `
            -ExpectedHead ([string]$row.candidate_head) `
            -ExpectedTree ([string]$row.candidate_tree)
        Assert-Case ($stderrManifest.entry_count -eq 31) 'detached acceptance stderr manifest does not cover all 31 child checks'
    }
}
Assert-Case (@($coverage | Where-Object binding_scope -like 'EXACT_CANDIDATE*').Count -eq 0) 'tracked coverage makes an impossible self-referential exact-candidate claim'

$validation = Read-Json (Join-Path $packet 'VALIDATION.json')
Assert-Case ([string]$validation.final_candidate.identity_binding -eq 'THE_SINGLE_COMMIT_CONTAINING_THIS_PACKET') 'packet final-candidate identity is not bound to its containing commit'
Assert-Case ([string]$validation.packet_seal_proof2.head -eq $packetSealHead -and [string]$validation.packet_seal_proof2.tree -eq $packetSealTree) 'validation does not bind the exact preserved packet-seal proof candidate'
Assert-Case ([string]$validation.packet_seal_proof2.binding_scope -eq 'PRE_FINAL_PACKET_SEAL_PROOF2') 'validation mislabels packet-seal evidence as the self-referential final candidate'
Assert-Case ([bool]$validation.publication_gate.ready -and ![bool]$validation.publication_gate.publication_authorized) 'packet must be review-ready without claiming publication authorization before independent reviews'

$packetHashScript = Join-Path $repo 'tests\run-tsf-response-runtime-hotfix-packet-hash-v1.mjs'
$packetHashRaw = if ($PacketHashSource -eq 'INDEX') {
    (& node $packetHashScript --index | Out-String)
} else {
    (& node $packetHashScript --treeish HEAD | Out-String)
}
$packetHashExit = $LASTEXITCODE
Assert-Case ($packetHashExit -eq 0) 'canonical Git-blob packet checker did not exit zero'
$packetHash = $packetHashRaw | ConvertFrom-Json
Assert-Case ([string]$packetHash.status -eq 'PASS') 'canonical Git-blob packet verification failed'
Assert-Case ([string]$packetHash.hash_domain -eq 'CANONICAL_GIT_BLOB_BYTES_V1') 'packet hash domain is not canonical Git blob bytes'
Assert-Case (@($packetHash.missing).Count -eq 0 -and @($packetHash.unlisted).Count -eq 0 -and @($packetHash.mismatches).Count -eq 0) 'packet has a missing, unlisted, or canonical-mismatch entry'
Assert-Case (@($packetHash.materialization_failures).Count -eq 0) 'detached materialization has an unexplained or semantic mismatch'
foreach ($row in @($packetHash.materialized)) {
    Assert-Case ([string]$row.disposition -in @('EXACT_CANONICAL_BYTES', 'EXPECTED_GIT_TEXT_MATERIALIZATION')) "packet checkout materialization is unexplained: $($row.name)"
    Assert-Case ([bool]$row.normalized_equivalent) "packet checkout materialization is not semantically equivalent: $($row.name)"
}

$acceptanceRoot = [IO.Path]::GetFullPath($FinalAcceptanceEvidenceRoot)
$acceptance = Read-Json (Join-Path $acceptanceRoot 'acceptance-summary.json')
$acceptanceWorktree = [IO.Path]::GetFullPath([string]$acceptance.repository.worktree)
function Resolve-FinalAcceptanceEvidencePath([string]$Path) {
    Resolve-TsfPacketEvidencePath -Path $Path -RepositoryRoot $acceptanceWorktree -ApprovedRoots @($acceptanceWorktree) -ExpectedType Leaf
}
Assert-Case ([string]$acceptance.status -eq 'PASS' -and [int]$acceptance.execution.failed_checks -eq 0) 'final V1 acceptance is not PASS'
Assert-Case ([string]$acceptance.repository.head -eq $head -and [string]$acceptance.repository.tree -eq $tree) 'final acceptance does not bind the exact candidate'
$requiredFinal = @('exact_response_contract_propagation', 'doctor_canonical_runtime_cleanliness', 'recovery_result_contract_modes', 'initial_doctor_isolation', 'canonical_packet_git_blob_hashes', 'responsive_operator_ui', 'wrong_result_integrated_lifecycle', 'canonical_app_server_matrix', 'real_app_server_interruption_recovery', 'final_doctor_json', 'final_no_owner_listener_or_owned_child', 'final_tracked_worktree_clean')
foreach ($id in $requiredFinal) { Assert-Case (@($acceptance.checks | Where-Object check -eq $id).Count -eq 1) "final acceptance is missing $id" }
$calculatedAcceptanceCount = 0
foreach ($row in @($acceptance.checks)) {
    Assert-Case ([string]$row.status -eq 'PASS') "final acceptance row failed: $($row.check)"
    Assert-Case ([string]$row.candidate_head -eq $head -and [string]$row.candidate_tree -eq $tree) "final acceptance row is not candidate-bound: $($row.check)"
    Assert-Case ([int]$row.assertion_or_criterion_count -gt 0) "final acceptance row lacks a count: $($row.check)"
    $calculatedAcceptanceCount += [int]$row.assertion_or_criterion_count
    foreach ($kind in @('stdout', 'stderr')) {
        $path = Resolve-FinalAcceptanceEvidencePath ([string]$row."${kind}_path")
        Assert-Case (Test-Path -LiteralPath $path -PathType Leaf) "final $kind evidence missing: $($row.check)"
        Assert-Case ((Get-Hash $path) -eq [string]$row."${kind}_sha256") "final $kind hash mismatch: $($row.check)"
    }
}
Assert-Case ($calculatedAcceptanceCount -eq [int]$acceptance.execution.assertion_or_criterion_count) 'final acceptance aggregate count differs from source rows'

$productionProof = Read-Json ([IO.Path]::GetFullPath($ProductionProofStdoutPath))
Assert-Case ([string]$productionProof.status -eq 'PASS' -and [int]$productionProof.assertions -gt 0) 'real production proof is not PASS'
Assert-Case ([string]$productionProof.candidate.head -eq $head -and [string]$productionProof.candidate.tree -eq $tree -and [bool]$productionProof.candidate.detached) 'real production proof is not detached at the exact candidate'
Assert-Case ([string]$productionProof.submission.expected_literal_sha256 -eq '192168669db5ba0e1e6eb6877f2ce775defd0654a0fe4e124621aa7b9607c627') 'real proof expected-response identity differs'
Assert-Case ([string]$productionProof.worker.expected_response_sha256 -eq [string]$productionProof.worker.observed_response_sha256) 'real proof worker response is not exact'
Assert-Case ([string]$productionProof.verifier.verdict -eq 'GREEN' -and [bool]$productionProof.verifier.exact_response.independently_recomputed) 'real proof verifier is not independently GREEN'
Assert-Case ([string]$productionProof.preservation.status -eq 'PRESERVED' -and [string]$productionProof.admission.verdict -in @('ADMITTED', 'ADMITTED_WITH_CAVEATS')) 'real proof preservation/admission is incomplete'
Assert-Case ([bool]$productionProof.doctor_final.safe_to_start -and [int]$productionProof.doctor_final.listeners -eq 0 -and [int]$productionProof.doctor_final.owned_children -eq 0) 'real proof final cleanup is not safe'

$wrongProof = Read-Json ([IO.Path]::GetFullPath($WrongResultProofPath))
Assert-Case ([string]$wrongProof.queue_authority -eq 'TEST_ONLY_ISOLATED' -and [string]$wrongProof.execution_classification -eq 'DETERMINISTIC_FAKE_APP_SERVER_WITH_PRODUCTION_ADAPTER_AND_KERNEL') 'wrong-result proof classification/queue authority is inaccurate'
Assert-Case ([string]$wrongProof.candidate.head -eq $head -and [string]$wrongProof.candidate.tree -eq $tree -and [bool]$wrongProof.candidate.detached) 'wrong-result proof is not detached at the exact candidate'
Assert-Case ([string]$wrongProof.expected_sha256 -eq '192168669db5ba0e1e6eb6877f2ce775defd0654a0fe4e124621aa7b9607c627' -and [string]$wrongProof.observed_sha256 -eq '106dd1ebd1181784b66d19f0efc651e015e324d9f8fe106d91faf3ff935a11ba') 'wrong-result proof response identities differ'
Assert-Case ([bool]$wrongProof.transport_success -and ![bool]$wrongProof.semantic_response_success -and ![bool]$wrongProof.response_exact_match) 'wrong-result transport/semantic split is not preserved'
Assert-Case ([string]$wrongProof.verifier_verdict -eq 'RED' -and [bool]$wrongProof.verifier_independently_recomputed -and [string]$wrongProof.lifecycle_terminal_status -eq 'BLOCKED_VERIFIER') 'wrong-result verifier/lifecycle is not fail-closed'
Assert-Case ([bool]$wrongProof.exact_replay_idempotent -and [bool]$wrongProof.changed_replay_fail_closed) 'wrong-result replay behavior is incomplete'
Assert-Case (![bool]$wrongProof.admission_invoked -and [int]$wrongProof.admission_receipt_count -eq 0 -and ![bool]$wrongProof.admitted_success_presented) 'wrong-result proof presented or admitted false success'
Assert-Case ([bool]$wrongProof.source_clean -and [bool]$wrongProof.source_status_unchanged) 'wrong-result proof dirtied the exact candidate source'
if ([string]$wrongProof.queue_authority -eq 'TEST_ONLY_ISOLATED') {
    Assert-Case ([string]$wrongProof.doctor_overall_status -eq 'NOT_APPLICABLE_ISOLATED_PRE_AMEND' -and ![bool]$wrongProof.doctor_canonical_record_validated -and $null -eq $wrongProof.doctor_exit) 'isolated wrong-result proof falsely claimed production Doctor validation'
} else {
    Assert-Case ([bool]$wrongProof.doctor_canonical_record_validated) 'Doctor did not validate the final canonical negative record'
}

$interruptionProofArray = Read-Json ([IO.Path]::GetFullPath($InterruptionProofPath))
$interruptionProofs = @($interruptionProofArray | ForEach-Object { $_ })
foreach ($proof in $interruptionProofs) {
    Assert-Case ([string]$proof.status -eq 'PASS' -and [int]$proof.assertions -ge 186) 'the final interruption proof is not the complete passing fresh-owner and mission-revision proof'
    Assert-Case ([bool]$proof.initial_doctor.first_attempt -and ![bool]$proof.initial_doctor.retry_performed) 'the final interruption proof did not pass its isolated Doctor on the first invocation'
    Assert-Case ([bool]$proof.initial_doctor.human_json_agreement -and @($proof.initial_doctor.blocking_check_ids).Count -eq 0) 'the final initial Doctor classifications disagree or contain blocking checks'
    Assert-Case (Test-Path -LiteralPath ([string]$proof.initial_doctor.diagnostic_path) -PathType Leaf) 'the final first-attempt Doctor diagnostic is missing'
    Assert-Case ((Get-Hash ([string]$proof.initial_doctor.diagnostic_path)) -eq [string]$proof.initial_doctor.diagnostic_sha256) 'the final first-attempt Doctor diagnostic hash differs'
    Assert-Case ([string]$proof.interrupted_server.barrier_hook_point -eq 'AUTHORITATIVE_REAL_APP_SERVER_SUSPENDED_AFTER_EXACT_OWNERSHIP_REGISTRATION') 'a final interruption proof did not reach the authoritative exact-owned barrier'
    Assert-Case ([string]$proof.recovery_server.result_contract_mode -in @('EXACT_LITERAL_V1', 'NOT_APPLICABLE_NO_EXACT_RESPONSE_CONTRACT')) 'a final interruption proof has an unknown recovery result-contract mode'
    Assert-Case ([string]$proof.recovery_server.result_contract_mode -eq [string]$proof.recovery_server.exact_response_evidence_disposition) 'a final interruption proof result-contract classification is contradictory'
    $barrier = Read-Json ([string]$proof.interrupted_server.barrier_ready_path)
    Assert-Case ([string]$barrier.candidate_commit -eq $head -and [string]$barrier.candidate_tree -eq $tree) 'a final interruption proof barrier does not bind the exact candidate'
    $diagnostic = Read-Json ([string]$proof.interrupted_server.barrier_diagnostic_path)
    Assert-Case ([string]$diagnostic.barrier_state -eq 'READY_CLEANED' -and [string]$diagnostic.last_reached_stage -eq 'EXACT_OWNED_PROCESS_AND_SERVER_CLEANUP_CONFIRMED') 'a final interruption proof lacks exact process-and-server cleanup evidence'
}

$responsiveProof = Read-Json ([IO.Path]::GetFullPath($ResponsiveProofPath))
Assert-Case ([string]$responsiveProof.status -eq 'PASS' -and [int]$responsiveProof.assertions -eq 333) 'final responsive proof is not PASS with the complete assertion count'
Assert-Case ([string]$responsiveProof.candidate.head -eq $head -and [string]$responsiveProof.candidate.tree -eq $tree) 'final responsive proof does not bind the exact candidate'
Assert-Case ((@($responsiveProof.required_viewports) -join ',') -eq '320,375,390,768,1180') 'final responsive proof does not cover every required width'
Assert-Case (@($responsiveProof.measurements | Where-Object { [int]$_.page_overflow_pixels -ne 0 -or @($_.offenders).Count -ne 0 -or @($_.clipped_controls).Count -ne 0 -or @($_.unlabeled_controls).Count -ne 0 }).Count -eq 0) 'final responsive proof contains page overflow, an offender, a clipped control, or an unlabeled control'
Assert-Case (![bool]$responsiveProof.runtime.page_level_overflow_hiding_used -and ![bool]$responsiveProof.runtime.hidden_content_used_to_pass) 'final responsive proof hid page overflow or authority content'

[pscustomobject][ordered]@{
    schema_version = 'tsf_response_runtime_hotfix_packet_self_check_v1'
    status = 'PASS'
    generated_at = [datetimeoffset]::UtcNow.ToString('o')
    candidate = [pscustomobject]@{ head = $head; tree = $tree; parent = $parent; subject = $subject }
    runtime_candidate_binding = 'EXACT_HEAD_TREE_FROM_FRESH_DETACHED_PROOF_INPUTS'
    packet_seal_proof_candidate = [pscustomobject]@{ head = $packetSealHead; tree = $packetSealTree; binding_scope = 'PRE_FINAL_PACKET_SEAL_PROOF2' }
    tracked_coverage_rows = $coverage.Count
    final_acceptance_rows = @($acceptance.checks).Count
    final_acceptance_assertion_or_criterion_count = $calculatedAcceptanceCount
    final_acceptance_result_sha256 = Get-Hash (Join-Path $acceptanceRoot 'acceptance-summary.json')
    packet_hash_domain = [string]$packetHash.hash_domain
    packet_hash_source = $PacketHashSource
    packet_files_hashed = @($packetHash.canonical_entries).Count
    packet_materialization_dispositions = @($packetHash.materialized | Group-Object disposition | ForEach-Object { [pscustomobject]@{ disposition = $_.Name; count = $_.Count } })
    assertions = $script:assertions
    production_proof_mission_id = [string]$productionProof.mission.mission_id
    production_proof_stdout_sha256 = Get-Hash ([IO.Path]::GetFullPath($ProductionProofStdoutPath))
    wrong_result_mission_id = [string]$wrongProof.mission_id
    wrong_result_proof_sha256 = Get-Hash ([IO.Path]::GetFullPath($WrongResultProofPath))
    interruption_proof_fixture_identities = @($interruptionProofs | ForEach-Object { Split-Path -Leaf ([string]$_.fixture_root) })
    interruption_proof_sha256 = Get-Hash ([IO.Path]::GetFullPath($InterruptionProofPath))
    responsive_proof_sha256 = Get-Hash ([IO.Path]::GetFullPath($ResponsiveProofPath))
} | ConvertTo-Json -Depth 10
