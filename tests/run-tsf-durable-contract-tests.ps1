[CmdletBinding(PositionalBinding = $false)]
param([string]$EvidenceRoot = "")

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
$fixtureRoot = Join-Path $repo "tests\fixtures\fleet\durable-contract"
$workRoot = Join-Path $repo ".codex-local\durable-contract-tests"
if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) { $EvidenceRoot = Join-Path $workRoot "evidence" }
Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $workRoot, $EvidenceRoot | Out-Null

Import-Module (Join-Path $repo "tools\TsfDurableContract.psm1") -Force

$script:Results = [System.Collections.Generic.List[object]]::new()
function Assert-Contract {
    param([string]$CaseId, [string]$Category, [bool]$Condition, [string]$Expected, [string]$Observed, [string]$Assertion)
    $status = if ($Condition) { "PASS" } else { "FAIL" }
    $script:Results.Add([pscustomobject]@{ case_id = $CaseId; category = $Category; assertion = $Assertion; expected = $Expected; observed = $Observed; status = $status }) | Out-Null
    if (!$Condition) { throw "FAIL [$CaseId] $Assertion (expected=$Expected; observed=$Observed)" }
    Write-Host "PASS [$CaseId] $Assertion"
}
function Copy-ContractObject { param([object]$Value); return ($Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json) }
function Write-ContractJson { param([object]$Value, [string]$Path); $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8 }
function New-CaseRegistry {
    param([object]$Mission, [string]$CaseId)
    $path = Join-Path $workRoot "$CaseId-missions"
    New-Item -ItemType Directory -Force -Path $path | Out-Null
    Write-ContractJson -Value $Mission -Path (Join-Path $path "mission.json")
    return $path
}
function Invoke-CaseAdmission {
    param([string]$CaseId, [object]$Result, [object]$Mission, [string]$ActiveFingerprint = "", [string]$ReceiptDirectory = "", [datetimeoffset]$Now = [datetimeoffset]"2026-07-10T14:00:00Z")
    $resultPath = Join-Path $workRoot "$CaseId-result.json"
    Write-ContractJson -Value $Result -Path $resultPath
    $registry = New-CaseRegistry -Mission $Mission -CaseId $CaseId
    return Get-TsfAdmissionDecision -ResultPath $resultPath -MissionRegistryPath $registry -ActivePolicyFingerprint $ActiveFingerprint -ReceiptDirectory $ReceiptDirectory -CurrentTime $Now
}

$workMission = Get-Content -LiteralPath (Join-Path $fixtureRoot "missions\work-research.synthetic.mission.json") -Raw | ConvertFrom-Json
$codexMission = Get-Content -LiteralPath (Join-Path $fixtureRoot "missions\codex-implementation.synthetic.mission.json") -Raw | ConvertFrom-Json
$workResult = Get-Content -LiteralPath (Join-Path $fixtureRoot "results\work-research.synthetic.result.json") -Raw | ConvertFrom-Json
$codexResult = Get-Content -LiteralPath (Join-Path $fixtureRoot "results\codex-implementation.synthetic.result.json") -Raw | ConvertFrom-Json
$ungovernedResult = Get-Content -LiteralPath (Join-Path $fixtureRoot "results\ungoverned-direct-codex.synthetic.result.json") -Raw | ConvertFrom-Json

$missionValidation = Test-TsfMissionEnvelope -Mission $codexMission
Assert-Contract "DC-001" "schema" $missionValidation.valid "valid=true" "valid=$($missionValidation.valid); errors=$($missionValidation.errors -join ' | ')" "valid mission envelope passes validation"
$missionRoundTrip = $codexMission | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$missionRoundTripValidation = Test-TsfMissionEnvelope -Mission $missionRoundTrip
Assert-Contract "DC-002" "round_trip" $missionRoundTripValidation.valid "valid after JSON round-trip" "valid=$($missionRoundTripValidation.valid)" "valid mission survives JSON round-trip"
$resultValidation = Test-TsfResultEnvelope -Result $codexResult
Assert-Contract "DC-003" "schema" $resultValidation.valid "valid=true" "valid=$($resultValidation.valid); errors=$($resultValidation.errors -join ' | ')" "valid result envelope passes validation"
$resultRoundTrip = $codexResult | ConvertTo-Json -Depth 100 | ConvertFrom-Json
Assert-Contract "DC-004" "round_trip" (Test-TsfResultEnvelope -Result $resultRoundTrip).valid "valid after JSON round-trip" "valid=$((Test-TsfResultEnvelope -Result $resultRoundTrip).valid)" "valid result survives JSON round-trip"

$policyRoot = Join-Path $workRoot "policy-root"
New-Item -ItemType Directory -Force -Path (Join-Path $policyRoot "policy") | Out-Null
Set-Content -LiteralPath (Join-Path $policyRoot "policy\a.json") -Encoding UTF8 -Value '{"value":"A"}'
$testManifest = [pscustomobject]@{ schema_version = "tsf_policy_manifest_v1"; governing_files = @("policy/a.json"); schema_versions = [pscustomobject]@{ mission = "v1" } }
Write-ContractJson -Value $testManifest -Path (Join-Path $policyRoot "manifest.json")
$fp1 = Get-TsfPolicyFingerprint -ManifestPath (Join-Path $policyRoot "manifest.json") -RepositoryRoot $policyRoot -GitCommit ("a" * 40)
$fp2 = Get-TsfPolicyFingerprint -ManifestPath (Join-Path $policyRoot "manifest.json") -RepositoryRoot $policyRoot -GitCommit ("a" * 40)
Assert-Contract "DC-005" "policy_fingerprint" ($fp1.fingerprint -eq $fp2.fingerprint) "identical fingerprints" "$($fp1.fingerprint) / $($fp2.fingerprint)" "policy fingerprint is stable for identical inputs"
Set-Content -LiteralPath (Join-Path $policyRoot "policy\a.json") -Encoding UTF8 -Value '{"value":"B"}'
$fp3 = Get-TsfPolicyFingerprint -ManifestPath (Join-Path $policyRoot "manifest.json") -RepositoryRoot $policyRoot -GitCommit ("a" * 40)
Assert-Contract "DC-006" "policy_fingerprint" ($fp1.fingerprint -ne $fp3.fingerprint) "fingerprint changes" "$($fp1.fingerprint) -> $($fp3.fingerprint)" "governing policy change changes fingerprint"
$fixturePolicyFingerprint = Get-TsfPolicyFingerprint -ManifestPath (Join-Path $repo "fleet\control\policy-manifest.v1.json") -RepositoryRoot $repo -GitCommit ([string]$workMission.policy.policy_commit)
Assert-Contract "DC-006A" "policy_fingerprint" ($fixturePolicyFingerprint.fingerprint -eq [string]$workMission.policy.fingerprint -and $fixturePolicyFingerprint.fingerprint -eq [string]$codexMission.policy.fingerprint) "fixtures bind their declared policy commit and fingerprint" "$($fixturePolicyFingerprint.policy_commit):$($fixturePolicyFingerprint.fingerprint)" "synthetic missions preserve the fingerprint for their declared policy commit"
$currentPolicyFingerprint = Get-TsfPolicyFingerprint -ManifestPath (Join-Path $repo "fleet\control\policy-manifest.v1.json") -RepositoryRoot $repo

$missingMissionId = Copy-ContractObject $ungovernedResult
$missingMissionId.PSObject.Properties.Remove("mission_id")
$missingPath = Join-Path $workRoot "missing-mission-id.json"; Write-ContractJson $missingMissionId $missingPath
$missingDecision = Get-TsfAdmissionDecision -ResultPath $missingPath -MissionRegistryPath (New-CaseRegistry $codexMission "missing-id") -CurrentTime ([datetimeoffset]"2026-07-10T14:00:00Z")
Assert-Contract "DC-007" "identity" ($missingDecision.status -eq "UNTRUSTED_NOT_TSF_GOVERNED") "UNTRUSTED_NOT_TSF_GOVERNED" $missingDecision.status "missing mission ID is untrusted"
$unknown = Copy-ContractObject $codexResult; $unknown.mission_id = "unknown-mission-0001"; $unknown.result_id = "unknown-result-0001"
$unknownDecision = Invoke-CaseAdmission "unknown" $unknown $codexMission
Assert-Contract "DC-008" "identity" ($unknownDecision.status -eq "UNTRUSTED_NOT_TSF_GOVERNED") "UNTRUSTED_NOT_TSF_GOVERNED" $unknownDecision.status "unknown mission ID is untrusted"
$mismatch = Copy-ContractObject $codexResult; $mismatch.result_id = "mismatch-result-0001"; $mismatch.policy_fingerprint = ("f" * 64)
$mismatchDecision = Invoke-CaseAdmission "mismatch" $mismatch $codexMission
Assert-Contract "DC-009" "policy" ($mismatchDecision.status -eq "REJECTED_POLICY_MISMATCH") "REJECTED_POLICY_MISMATCH" $mismatchDecision.status "mismatched policy fingerprint is rejected"

$forbiddenRepo = Copy-ContractObject $codexResult; $forbiddenRepo.result_id = "forbidden-repo-result-0001"; $forbiddenRepo.actual_repository = "PRODUCT_REPOS"
$decision = Invoke-CaseAdmission "forbidden-repo" $forbiddenRepo $codexMission
Assert-Contract "DC-010" "scope" ($decision.status -eq "REJECTED_OUT_OF_SCOPE") "REJECTED_OUT_OF_SCOPE" $decision.status "forbidden repository is rejected"
$forbiddenPath = Copy-ContractObject $codexResult; $forbiddenPath.result_id = "forbidden-path-result-0001"; $forbiddenPath.files_changed = @("outside/mission/file.txt")
$decision = Invoke-CaseAdmission "forbidden-path" $forbiddenPath $codexMission
Assert-Contract "DC-011" "scope" ($decision.status -eq "REJECTED_OUT_OF_SCOPE") "REJECTED_OUT_OF_SCOPE" $decision.status "path outside allowed writes is rejected"
$forbiddenRead = Copy-ContractObject $codexResult; $forbiddenRead.result_id = "forbidden-read-result-0001"; $forbiddenRead.files_inspected = @("outside/mission/source.txt")
$decision = Invoke-CaseAdmission "forbidden-read" $forbiddenRead $codexMission
Assert-Contract "DC-011A" "scope" ($decision.status -eq "REJECTED_OUT_OF_SCOPE") "REJECTED_OUT_OF_SCOPE" $decision.status "inspected path outside allowed reads is rejected"
$wrongBranch = Copy-ContractObject $codexResult; $wrongBranch.result_id = "wrong-branch-result-0001"; $wrongBranch.actual_branch_worktree.branch = "work/wrong"
$decision = Invoke-CaseAdmission "wrong-branch" $wrongBranch $codexMission
Assert-Contract "DC-012" "scope" ($decision.status -eq "REJECTED_OUT_OF_SCOPE") "REJECTED_OUT_OF_SCOPE" $decision.status "branch mismatch is rejected"
$wrongWorktree = Copy-ContractObject $codexResult; $wrongWorktree.result_id = "wrong-worktree-result-0001"; $wrongWorktree.actual_branch_worktree.worktree = "WRONG_WORKTREE"
$decision = Invoke-CaseAdmission "wrong-worktree" $wrongWorktree $codexMission
Assert-Contract "DC-013" "scope" ($decision.status -eq "REJECTED_OUT_OF_SCOPE") "REJECTED_OUT_OF_SCOPE" $decision.status "worktree mismatch is rejected"
$missingTest = Copy-ContractObject $codexResult; $missingTest.result_id = "missing-test-result-0001"; $missingTest.tests = @()
$decision = Invoke-CaseAdmission "missing-test" $missingTest $codexMission
Assert-Contract "DC-014" "evidence" ($decision.status -eq "REJECTED_INVALID_EVIDENCE") "REJECTED_INVALID_EVIDENCE" $decision.status "missing required test evidence is rejected"
$missingVerifier = Copy-ContractObject $codexResult; $missingVerifier.result_id = "missing-verifier-result-0001"; $missingVerifier.verifier_evidence = @()
$decision = Invoke-CaseAdmission "missing-verifier" $missingVerifier $codexMission
Assert-Contract "DC-015" "verification" ($decision.status -eq "REVIEW_REQUIRED") "REVIEW_REQUIRED" $decision.status "missing independent verifier requires review"

foreach ($authorityCase in @(
    [pscustomobject]@{ id="approval"; field="grants_approval"; case="DC-016" },
    [pscustomobject]@{ id="merge"; field="grants_merge_authority"; case="DC-017" },
    [pscustomobject]@{ id="production"; field="grants_production_authority"; case="DC-018" }
)) {
    $claim = Copy-ContractObject $codexResult; $claim.result_id = "$($authorityCase.id)-claim-result-0001"; $claim.($authorityCase.field) = $true
    $decision = Invoke-CaseAdmission "$($authorityCase.id)-claim" $claim $codexMission
    Assert-Contract $authorityCase.case "authority" ($decision.status -eq "TIM_REQUIRED") "TIM_REQUIRED" $decision.status "result claiming $($authorityCase.id) authority requires Tim"
}

$directCodexPath = Join-Path $fixtureRoot "results\ungoverned-direct-codex.synthetic.result.json"
$decision = Get-TsfAdmissionDecision -ResultPath $directCodexPath -MissionRegistryPath (New-CaseRegistry $codexMission "bypass-codex") -CurrentTime ([datetimeoffset]"2026-07-10T14:00:00Z")
Assert-Contract "DC-019" "bypass" ($decision.status -eq "UNTRUSTED_NOT_TSF_GOVERNED") "UNTRUSTED_NOT_TSF_GOVERNED" $decision.status "direct Codex work without mission is untrusted"
$bypassWork = Copy-ContractObject $ungovernedResult; $bypassWork.result_id = "synthetic-ungoverned-work-0001"; $bypassWork.surface_used = "WORK"
$bypassWorkPath = Join-Path $workRoot "bypass-work.json"; Write-ContractJson $bypassWork $bypassWorkPath
$decision = Get-TsfAdmissionDecision -ResultPath $bypassWorkPath -MissionRegistryPath (New-CaseRegistry $workMission "bypass-work") -CurrentTime ([datetimeoffset]"2026-07-10T14:00:00Z")
Assert-Contract "DC-020" "bypass" ($decision.status -eq "UNTRUSTED_NOT_TSF_GOVERNED") "UNTRUSTED_NOT_TSF_GOVERNED" $decision.status "direct Work research without mission is untrusted"

$staleMission = Copy-ContractObject $codexMission; $staleMission.expires_at = "2026-07-09T00:00:00Z"
$staleResult = Copy-ContractObject $codexResult; $staleResult.result_id = "stale-result-0001"
$decision = Invoke-CaseAdmission "stale" $staleResult $staleMission -Now ([datetimeoffset]"2026-07-10T14:00:00Z")
Assert-Contract "DC-021" "recovery" ($decision.status -eq "REVIEW_REQUIRED") "REVIEW_REQUIRED" $decision.status "expired mission requires review"
$receiptDir = Join-Path $workRoot "duplicate-receipts"
$duplicateResult = Copy-ContractObject $codexResult; $duplicateResult.result_id = "duplicate-result-0001"
$first = Invoke-CaseAdmission "duplicate-first" $duplicateResult $codexMission -ReceiptDirectory $receiptDir
$duplicatePath = Join-Path $workRoot "duplicate-first-result.json"
$registry = New-CaseRegistry $codexMission "duplicate-replay"
$second = Get-TsfAdmissionDecision -ResultPath $duplicatePath -MissionRegistryPath $registry -ReceiptDirectory $receiptDir -CurrentTime ([datetimeoffset]"2026-07-10T14:00:00Z")
Assert-Contract "DC-022" "idempotency" ($first.status -eq "ADMITTED" -and $second.status -eq "ADMITTED" -and $second.idempotent_replay) "same ADMITTED receipt with idempotent_replay=true" "first=$($first.status); second=$($second.status); replay=$($second.idempotent_replay)" "exact duplicate result is idempotent"

$unknownModelMission = Copy-ContractObject $codexMission; $unknownModelMission.model_selection_assurance = "RECOMMENDED_ONLY"; $unknownModelMission.resolved_model = $null
$unknownModel = Copy-ContractObject $codexResult; $unknownModel.result_id = "unknown-model-result-0001"; $unknownModel.actual_model = $null; $unknownModel.actual_reasoning_effort = "UNKNOWN"; $unknownModel.model_assurance_level = "RECOMMENDED_ONLY"
$decision = Invoke-CaseAdmission "unknown-model" $unknownModel $unknownModelMission
Assert-Contract "DC-023" "model" ($decision.status -eq "ADMITTED_WITH_CAVEATS") "ADMITTED_WITH_CAVEATS" $decision.status "unknown model with honest recommended-only assurance is admitted with caveat"
$adapterVerified = Copy-ContractObject $codexResult; $adapterVerified.result_id = "adapter-verified-result-0001"
$decision = Invoke-CaseAdmission "adapter-verified" $adapterVerified $codexMission
Assert-Contract "DC-024" "model" ($decision.status -eq "ADMITTED") "ADMITTED" $decision.status "adapter-verified model setting is admitted when other evidence passes"
$networkUse = Copy-ContractObject $codexResult; $networkUse.result_id = "network-use-result-0001"; $networkUse.network_activity.used = $true; $networkUse.network_activity.destinations = @("example.invalid")
$decision = Invoke-CaseAdmission "network-use" $networkUse $codexMission
Assert-Contract "DC-025" "scope" ($decision.status -eq "REJECTED_OUT_OF_SCOPE") "REJECTED_OUT_OF_SCOPE" $decision.status "network use is rejected when prohibited"
$wrongSource = Copy-ContractObject $workResult; $wrongSource.result_id = "wrong-source-result-0001"; $wrongSource.network_activity.destinations = @("UNAPPROVED_SOURCE")
$decision = Invoke-CaseAdmission "wrong-source" $wrongSource $workMission
Assert-Contract "DC-025A" "scope" ($decision.status -eq "REJECTED_OUT_OF_SCOPE") "REJECTED_OUT_OF_SCOPE" $decision.status "network source outside source allowlist is rejected"
$missingArtifact = Copy-ContractObject $codexResult; $missingArtifact.result_id = "missing-artifact-result-0001"; $missingArtifact.artifacts[0].exists = $false
$decision = Invoke-CaseAdmission "missing-artifact" $missingArtifact $codexMission
Assert-Contract "DC-026" "evidence" ($decision.status -eq "REJECTED_INVALID_EVIDENCE") "REJECTED_INVALID_EVIDENCE" $decision.status "missing required artifact is rejected"
$branchAdvanced = Copy-ContractObject $codexResult; $branchAdvanced.result_id = "branch-advanced-result-0001"; $branchAdvanced.git_facts.starting_head = ("3" * 40)
$decision = Invoke-CaseAdmission "branch-advanced" $branchAdvanced $codexMission
Assert-Contract "DC-027" "recovery" ($decision.status -eq "REVIEW_REQUIRED") "REVIEW_REQUIRED" $decision.status "unexpected starting HEAD requires review"
$activePolicyChanged = Copy-ContractObject $codexResult; $activePolicyChanged.result_id = "active-policy-change-result-0001"
$decision = Invoke-CaseAdmission "active-policy-change" $activePolicyChanged $codexMission -ActiveFingerprint ("e" * 64)
Assert-Contract "DC-028" "recovery" ($decision.status -eq "REVIEW_REQUIRED") "REVIEW_REQUIRED" $decision.status "policy change while mission active requires review"
$undeclaredApproval = Copy-ContractObject $codexResult; $undeclaredApproval.result_id = "undeclared-approval-result-0001"; $undeclaredApproval.approval_use = @([pscustomobject]@{ approval_id = "not-in-mission"; exact_action = "merge"; used = $true })
$decision = Invoke-CaseAdmission "undeclared-approval" $undeclaredApproval $codexMission
Assert-Contract "DC-028A" "authority" ($decision.status -eq "TIM_REQUIRED") "TIM_REQUIRED" $decision.status "approval use absent from mission references requires Tim"
$forbiddenAction = Copy-ContractObject $codexResult; $forbiddenAction.result_id = "forbidden-action-result-0001"; $forbiddenAction.major_actions = @("ACTION:merge")
$decision = Invoke-CaseAdmission "forbidden-action" $forbiddenAction $codexMission
Assert-Contract "DC-028B" "scope" ($decision.status -eq "REJECTED_OUT_OF_SCOPE") "REJECTED_OUT_OF_SCOPE" $decision.status "structured forbidden action is rejected"
$valid = Copy-ContractObject $codexResult; $valid.result_id = "valid-admitted-result-0001"
$validDecision = Invoke-CaseAdmission "valid-admitted" $valid $codexMission
Assert-Contract "DC-029" "admission" ($validDecision.status -eq "ADMITTED") "ADMITTED" $validDecision.status "valid compliant result is admitted"
$caveat = Copy-ContractObject $workResult; $caveat.result_id = "valid-caveat-result-0001"
$caveatDecision = Invoke-CaseAdmission "valid-caveat" $caveat $workMission
Assert-Contract "DC-030" "admission" ($caveatDecision.status -eq "ADMITTED_WITH_CAVEATS") "ADMITTED_WITH_CAVEATS" $caveatDecision.status "valid advisory result with uncertainty is admitted with caveats"

$dogfood = @(
    [pscustomobject]@{ flow = "SYNTHETIC_WORK_RESEARCH"; mission_id = $workMission.mission_id; result_id = $workResult.result_id; admission_status = (Invoke-CaseAdmission "dogfood-work" $workResult $workMission).status; launches_native_surface = $false },
    [pscustomobject]@{ flow = "SYNTHETIC_CODEX_IMPLEMENTATION"; mission_id = $codexMission.mission_id; result_id = $codexResult.result_id; admission_status = (Invoke-CaseAdmission "dogfood-codex" $codexResult $codexMission).status; launches_native_surface = $false },
    [pscustomobject]@{ flow = "SYNTHETIC_UNGOVERNED_CODEX"; mission_id = $null; result_id = $ungovernedResult.result_id; admission_status = (Get-TsfAdmissionDecision -ResultPath (Join-Path $fixtureRoot "results\ungoverned-direct-codex.synthetic.result.json") -MissionRegistryPath (New-CaseRegistry $codexMission "dogfood-ungoverned") -CurrentTime ([datetimeoffset]"2026-07-10T14:00:00Z")).status; launches_native_surface = $false }
)
Assert-Contract "DC-031" "dogfood" ($dogfood[0].admission_status -eq "ADMITTED_WITH_CAVEATS") "ADMITTED_WITH_CAVEATS" $dogfood[0].admission_status "synthetic Work research remains advisory and admits only with caveats"
Assert-Contract "DC-032" "dogfood" ($dogfood[1].admission_status -eq "ADMITTED") "ADMITTED" $dogfood[1].admission_status "synthetic bounded Codex implementation admits with complete evidence"
Assert-Contract "DC-033" "dogfood" ($dogfood[2].admission_status -eq "UNTRUSTED_NOT_TSF_GOVERNED") "UNTRUSTED_NOT_TSF_GOVERNED" $dogfood[2].admission_status "synthetic ungoverned Codex task is not admitted"

$coveragePath = Join-Path $EvidenceRoot "EXECUTED_TEST_COVERAGE.csv"
@($script:Results) | Export-Csv -LiteralPath $coveragePath -NoTypeInformation -Encoding UTF8
$dogfood | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $EvidenceRoot "SYNTHETIC_DOGFOOD_RESULTS.json") -Encoding UTF8
$failed = @($script:Results | Where-Object status -ne "PASS")
$validation = [pscustomobject][ordered]@{
    schema_version = "tsf_durable_contract_validation_v1"
    generated_at = [datetimeoffset]::UtcNow.ToString("o")
    verdict = if ($failed.Count -eq 0) { "GREEN_DURABLE_CONTRACT_TESTS" } else { "RED_DURABLE_CONTRACT_TESTS" }
    executed_assertion_count = $script:Results.Count
    passed_assertion_count = @($script:Results | Where-Object status -eq "PASS").Count
    failed_assertion_count = $failed.Count
    policy_commit = $currentPolicyFingerprint.policy_commit
    policy_fingerprint = $currentPolicyFingerprint.fingerprint
    policy_governing_file_count = $currentPolicyFingerprint.governing_file_count
    synthetic_flow_count = $dogfood.Count
    all_fixtures_synthetic = $true
    native_surface_launched = $false
    api_called = $false
    background_process_started = $false
    grants_approval = $false
    grants_merge_authority = $false
    grants_production_authority = $false
}
$validation | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $EvidenceRoot "VALIDATION.json") -Encoding UTF8
if ($failed.Count -gt 0) { exit 1 }
Write-Host "Durable contract tests passed: $($script:Results.Count) executed assertions."
exit 0
