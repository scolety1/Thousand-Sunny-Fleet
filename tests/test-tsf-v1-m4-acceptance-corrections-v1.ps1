[CmdletBinding(PositionalBinding = $false)]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'tools\hq-dispatch\v1\doctor-format.ps1')
. (Join-Path $PSScriptRoot 'support\TsfParserEvidence.ps1')
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
Assert-True ($finalAcceptanceSource -match 'ExpectedExitCodes @\(0, 2, 3\)') 'Final acceptance recognizes every safe governed Doctor disposition'
Assert-True ($finalAcceptanceSource -notmatch 'ExpectedExitCodes @\(0, 2, 3, 4\)') 'Final acceptance never accepts Doctor UNSAFE_TO_START exit four'
Assert-True ($finalAcceptanceSource -match "diff', '--check', 'refs/remotes/origin/main\.\.\.HEAD'") 'Final acceptance checks whitespace in the committed candidate diff'
Assert-True ($finalAcceptanceSource -match "94_ASSERTION_REAL_APP_SERVER_INTERRUPTION_AND_NEW_RUN_RECOVERY_PROOF") 'Final acceptance PASS basis records the exact current real-proof assertion count'
Assert-True ($finalAcceptanceSource -notmatch "83_ASSERTION_REAL_APP_SERVER_INTERRUPTION_AND_NEW_RUN_RECOVERY_PROOF") 'Final acceptance rejects the stale pre-correction real-proof assertion count'
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
