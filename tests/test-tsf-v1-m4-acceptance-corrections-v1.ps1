[CmdletBinding(PositionalBinding = $false)]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'tools\hq-dispatch\v1\doctor-format.ps1')
. (Join-Path $PSScriptRoot 'support\TsfParserEvidence.ps1')
. (Join-Path $PSScriptRoot 'support\TsfFinalAcceptanceGitState.ps1')
$assertions = 0

function Assert-True([bool]$Condition, [string]$Message) {
    $script:assertions += 1
    if (-not $Condition) { throw "ASSERTION_FAILED:$Message" }
}

function Assert-Equal($Actual, $Expected, [string]$Message) {
    $script:assertions += 1
    if ($Actual -ne $Expected) { throw "ASSERTION_FAILED:$Message expected=[$Expected] actual=[$Actual]" }
}

$fixtureReport = [pscustomobject]@{
    overall_status = 'GREEN'
    safe_to_start = $true
    repository = [pscustomobject]@{ top = 'C:/TSF_V1'; head = ('a' * 40) }
    listener_state = [pscustomobject]@{ host = '127.0.0.1'; port = 4317; listeners = @() }
    process_owner = [pscustomobject]@{ disposition = 'ABSENT' }
    path_budget = [pscustomobject]@{ maximum_path_length = 138; target_limit = 225 }
    pending_tim_required_requests = 0
    interrupted_missions = 0
    duplicate_replay_conflicts = 0
    checks = @([pscustomobject]@{ id = 'repository'; status = 'GREEN'; next_action = 'Continue.' })
    exact_next_action = 'Start in the foreground.'
}
$fixtureLines = @(ConvertTo-TsfHqDispatchDoctorHumanLinesV1 -Report $fixtureReport)
Assert-True ($fixtureLines -contains '[GREEN] repository') 'Doctor uses the stable check identifier as the human label'
Assert-True ($fixtureLines -contains '  Next: Continue.') 'Doctor human next action comes from the authoritative check'

$missingLabel = $fixtureReport.PSObject.Copy()
$missingLabel.checks = @([pscustomobject]@{ id = ''; status = 'GREEN'; next_action = 'Continue.' })
$missingLabelFailed = $false
try { ConvertTo-TsfHqDispatchDoctorHumanLinesV1 -Report $missingLabel | Out-Null } catch { $missingLabelFailed = $_.Exception.Message -eq 'TSF_HQ_DOCTOR_CHECK_LABEL_MISSING' }
Assert-True $missingLabelFailed 'Missing Doctor labels fail the human truthfulness formatter'

$parserPass = New-TsfParserEvidenceRowV1 -Check 'powershell_syntax:valid.ps1' -ParserKind POWERSHELL -ParserErrors @() -SuccessEvidence 'valid.ps1'
Assert-Equal $parserPass.status 'PASS' 'Successful parser row is PASS'
Assert-Equal $parserPass.exit_code 0 'Successful parser row records exit zero'
Assert-Equal $parserPass.parser_result_identity 'POWERSHELL_PARSER_SUCCESS' 'Successful parser row records explicit success identity'

$parserFailure = New-TsfParserEvidenceRowV1 -Check 'powershell_syntax:invalid.ps1' -ParserKind POWERSHELL -ParserErrors @('Unexpected token at line 1') -SuccessEvidence 'invalid.ps1'
Assert-Equal $parserFailure.status 'FAIL' 'Failed parser row is FAIL'
Assert-True ($parserFailure.exit_code -ne 0) 'Failed parser row records nonzero exit identity'
Assert-Equal $parserFailure.parser_result_identity 'POWERSHELL_PARSER_FAILURE' 'Failed parser row records explicit failure identity'
Assert-True ($parserFailure.evidence -match 'Unexpected token') 'Failed parser evidence is preserved'

$doctorPath = Join-Path $repoRoot 'tools\hq-dispatch\v1\Test-TsfHqDispatchDoctorV1.ps1'
$jsonText = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $doctorPath -Json | Out-String
$jsonExit = $LASTEXITCODE
$humanText = & powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $doctorPath | Out-String
$humanExit = $LASTEXITCODE
$doctor = $jsonText | ConvertFrom-Json
Assert-Equal $humanExit $jsonExit 'Human and JSON Doctor formats preserve the same process exit'
Assert-True ($doctor.schema_version -eq 'tsf_hq_dispatch_doctor_v1') 'JSON Doctor authority schema remains unchanged'
foreach ($check in @($doctor.checks)) {
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$check.id)) 'Every authoritative Doctor check has a stable identifier'
    $labelPattern = '(?m)^\[' + [regex]::Escape([string]$check.status) + '\] ' + [regex]::Escape([string]$check.id) + '\r?$'
    Assert-True ($humanText -match $labelPattern) "Human Doctor status and label agree for $($check.id)"
    Assert-True ($humanText -match ('(?m)^  Next: ' + [regex]::Escape([string]$check.next_action) + '\r?$')) "Human Doctor next action agrees for $($check.id)"
}

$runnerSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-tsf-hq-dispatch-reliability-v1.ps1') -Raw
Assert-True ($runnerSource -match 'New-TsfParserEvidenceRowV1') 'Aggregate runner uses the tested parser evidence constructor'
Assert-True ($runnerSource -notmatch 'function Add-Result[\s\S]*?exit_code\s*=\s*0') 'Aggregate runner has no hardcoded-zero generic result row'

$canonicalMatrixSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-tsf-canonical-runtime-app-server-tests.ps1') -Raw
Assert-True ($canonicalMatrixSource -match 'synthetic-tsf-readonly-appserver-\$testRunNonce') 'Canonical matrix uses a unique read-only fixture identity per run'
Assert-True ($canonicalMatrixSource -match 'synthetic-transaction-\$Name-\$testRunNonce') 'Canonical matrix uses unique transactional fixture identities per run'
Assert-True ($canonicalMatrixSource -notmatch "New-CanonicalMission 'synthetic-tsf-readonly-appserver-correction-0001'") 'Canonical matrix cannot reuse the historical fixed read-only fixture identity'
$staticIntegritySource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-tsf-final-static-integrity-tests.ps1') -Raw
Assert-True ($staticIntegritySource -match 'git diff --name-only "\$BaseRef\.\.\.HEAD"') 'Static integrity discovers committed M4 corrections relative to the baseline'
$finalAcceptanceSource = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'run-tsf-v1-final-acceptance-v1.ps1') -Raw
Assert-True ($finalAcceptanceSource -match '\[switch\]\$AuthorizedDirtyCandidateWorktree') 'Working-tree acceptance requires an explicit mode switch'
Assert-True ($finalAcceptanceSource -match '\$doctorExpectedExitCodes = if \(\$AuthorizedDirtyCandidateWorktree\) \{ @\(0, 2, 3, 4\) \} else \{ @\(0, 2, 3\) \}') 'Doctor exit four is conditional on the explicit dirty-candidate mode while clean acceptance keeps the governed exits'
Assert-True ($finalAcceptanceSource -match 'Test-TsfFinalAcceptanceAuthorizedDirtyWorktreeBinding') 'Final acceptance verifies the exact dirty byte binding before and after tests'
Assert-True ($finalAcceptanceSource -match 'Test-TsfFinalAcceptanceAuthorizedDirtyDoctorBinding') 'Final acceptance independently binds Doctor exit four to dirty-worktree-only unsafety and clean runtime ownership'
Assert-True ($finalAcceptanceSource -match 'FINAL_ACCEPTANCE_DIRTY_BINDING_PARAMETERS_REQUIRE_EXPLICIT_MODE') 'Dirty binding parameters fail closed without the explicit mode'
Assert-True ($finalAcceptanceSource -match "diff', '--check', 'refs/remotes/origin/main\.\.\.HEAD'") 'Final acceptance checks whitespace in the committed candidate diff'
Assert-True ($finalAcceptanceSource -match "201_ASSERTION_REAL_APP_SERVER_INTERRUPTION_STRUCTURED_RECOVERY_ADMISSION_AND_FRESH_EXACT_STOP_PROOF") 'Final acceptance PASS basis records the exact current structured-recovery and fresh-owner Stop real-proof assertion count'
Assert-True ($finalAcceptanceSource -notmatch "186_ASSERTION_REAL_APP_SERVER_INTERRUPTION_AND_FRESH_EXACT_STOP_MISSION_REVISION_RECOVERY_PROOF") 'Final acceptance rejects the superseded pre-structured-recovery assertion count'
Assert-True ($finalAcceptanceSource -notmatch "94_ASSERTION_REAL_APP_SERVER_INTERRUPTION_AND_NEW_RUN_RECOVERY_PROOF") 'Final acceptance rejects the stale universal exact-evidence real-proof assertion count'
$bindingFixture = [pscustomobject][ordered]@{
    head = ('a' * 40)
    tree = ('b' * 40)
    branch = 'work/test'
    binding_sha256 = ('c' * 64)
    errors = @()
    staged_paths = @()
    dirty_paths = @('tests/allowed.ps1')
}
$validBinding = Test-TsfFinalAcceptanceAuthorizedDirtyWorktreeBinding -State $bindingFixture -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40) -ExpectedBranch 'work/test' -ExpectedBindingSha256 ('c' * 64) -AllowedPathPatterns @('^tests/allowed\.ps1$')
Assert-True $validBinding.valid 'Exact head, tree, branch, byte binding, empty index, and allowed path set are accepted'
$wrongBinding = Test-TsfFinalAcceptanceAuthorizedDirtyWorktreeBinding -State $bindingFixture -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40) -ExpectedBranch 'work/test' -ExpectedBindingSha256 ('d' * 64) -AllowedPathPatterns @('^tests/allowed\.ps1$')
Assert-True (-not $wrongBinding.valid) 'A substituted dirty-worktree byte binding is rejected'
Assert-True (@($wrongBinding.errors) -contains 'WORKTREE_BINDING_SHA256_MISMATCH') 'Dirty-worktree mismatch has a deterministic rejection identity'
$stagedFixture = $bindingFixture.PSObject.Copy()
$stagedFixture.staged_paths = @('tests/allowed.ps1')
$stagedBinding = Test-TsfFinalAcceptanceAuthorizedDirtyWorktreeBinding -State $stagedFixture -ExpectedHead ('a' * 40) -ExpectedTree ('b' * 40) -ExpectedBranch 'work/test' -ExpectedBindingSha256 ('c' * 64) -AllowedPathPatterns @('^tests/allowed\.ps1$')
Assert-True (-not $stagedBinding.valid) 'Dirty acceptance rejects a nonempty index'
$dirtyDoctorFixture = [pscustomobject][ordered]@{
    overall_status = 'UNSAFE_TO_START'
    safe_to_start = $false
    repository = [pscustomobject]@{ head = ('a' * 40); branch = 'work/test'; clean = $false }
    process_owner = [pscustomobject]@{ disposition = 'ABSENT' }
    listener_state = [pscustomobject]@{ listeners = @() }
    active_child = @()
    checks = @(
        [pscustomobject]@{ id = 'repository'; status = 'GREEN' },
        [pscustomobject]@{ id = 'worktree_cleanliness'; status = 'UNSAFE_TO_START' },
        [pscustomobject]@{ id = 'canonical_reconciliation'; status = 'TIM_REQUIRED' }
    )
}
$validDoctorBinding = Test-TsfFinalAcceptanceAuthorizedDirtyDoctorBinding -Doctor $dirtyDoctorFixture -WorktreeBinding $validBinding -ExpectedHead ('a' * 40) -ExpectedBranch 'work/test'
Assert-True $validDoctorBinding.valid 'Doctor exit four is acceptable only when dirty-worktree cleanliness is the sole unsafe check and runtime ownership is clean'
$badDoctorFixture = $dirtyDoctorFixture.PSObject.Copy()
$badDoctorFixture.listener_state = [pscustomobject]@{ listeners = @([pscustomobject]@{ owning_pid = 42 }) }
$badDoctorBinding = Test-TsfFinalAcceptanceAuthorizedDirtyDoctorBinding -Doctor $badDoctorFixture -WorktreeBinding $validBinding -ExpectedHead ('a' * 40) -ExpectedBranch 'work/test'
Assert-True (-not $badDoctorBinding.valid) 'Dirty-worktree mode never authorizes a listener'
Assert-True (@($badDoctorBinding.errors) -contains 'DOCTOR_LISTENER_PRESENT') 'Listener rejection remains explicit'
$kernelSource = Get-Content -LiteralPath (Join-Path $repoRoot 'tools\codex-fleet-enforcement-kernel.ps1') -Raw
Assert-True ($kernelSource -match 'mission_revision\s*=\s*\[int\]\$responseContractMission\.mission_revision') 'Verifier top-level revision comes from the authoritative durable response contract'
$durableContractSource = Get-Content -LiteralPath (Join-Path $repoRoot 'tools\TsfDurableContract.Canonical.ps1') -Raw
Assert-True ($durableContractSource -match 'Test-TsfCanonicalVerifierIdentity') 'Durable-result mapping rejects an unbound verifier identity'

$m3ValidationPath = Join-Path $repoRoot 'docs\hq\tsf_hq_dispatch_reliability_lifecycle_v1_20260716\VALIDATION.json'
$errataPath = Join-Path $repoRoot 'docs\hq\tsf_v1_final_acceptance_demo_v1_20260717\M3_VALIDATION_ERRATA_V1.json'
$m3Validation = Get-Content -LiteralPath $m3ValidationPath -Raw | ConvertFrom-Json
$errata = Get-Content -LiteralPath $errataPath -Raw | ConvertFrom-Json
Assert-Equal $errata.recorded_hash $m3Validation.adoption.hashes.'status-porcelain-v2.txt' 'Erratum binds the exact accepted M3 validation field'
Assert-True ($errata.recorded_hash -ne $errata.independently_verified_correct_hash) 'Erratum distinguishes recorded and corrected hashes'
Assert-Equal $errata.original_m3_commit 'b437d47206b820ea1d9ec9b110d0b09b47fedd93' 'Erratum binds the accepted M3 commit'
Assert-Equal $errata.accepted_merge_commit '952f30e137214735fe2513a7b068d9680ca882c7' 'Erratum binds the accepted M3 merge'
$externalBundle = 'C:\TSF_M3\.codex-local\recovery\overnight-m3-adoption'
Assert-True (Test-Path -LiteralPath $externalBundle -PathType Container) 'Original immutable M3 adoption bundle is available for final acceptance rehash'
$statusHash = (Get-FileHash -LiteralPath (Join-Path $externalBundle 'status-porcelain-v2.txt') -Algorithm SHA256).Hash.ToLowerInvariant()
$adoptionHash = (Get-FileHash -LiteralPath (Join-Path $externalBundle 'ADOPTION.json') -Algorithm SHA256).Hash.ToLowerInvariant()
$hashManifestHash = (Get-FileHash -LiteralPath (Join-Path $externalBundle 'HASHES.sha256') -Algorithm SHA256).Hash.ToLowerInvariant()
Assert-Equal $statusHash $errata.independently_verified_correct_hash 'Preserved status bytes independently rehash to the corrected value'
Assert-Equal $adoptionHash $errata.immutable_adoption_bundle_binding.adoption_manifest_sha256 'Erratum binds the immutable adoption manifest'
Assert-Equal $hashManifestHash $errata.immutable_adoption_bundle_binding.bundle_hash_manifest_sha256 'Erratum binds the adoption hash manifest'

[pscustomobject][ordered]@{
    schema_version = 'tsf_v1_m4_acceptance_corrections_test_v1'
    status = 'PASS'
    assertions = $assertions
    doctor_json_authority_unchanged = $true
    doctor_missing_label_negative_test = 'PASS'
    parser_failure_negative_test = 'PASS'
    repeatable_fixture_identity_test = 'PASS'
    failed_parser_exit_code = $parserFailure.exit_code
    failed_parser_result_identity = $parserFailure.parser_result_identity
    m3_erratum_external_rehash = 'PASS'
    m3_status_porcelain_correct_sha256 = $statusHash
} | ConvertTo-Json -Depth 10
