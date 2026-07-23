[CmdletBinding(PositionalBinding = $false)]
param()

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $fleetRoot "tools\codex-fleet-enforcement-kernel.ps1")

$script:Failures = [System.Collections.Generic.List[string]]::new()

function Add-TestFailure {
    param([string]$Message)
    $script:Failures.Add($Message) | Out-Null
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if ($Condition) {
        Write-Host "PASS: $Message" -ForegroundColor Green
    } else {
        Add-TestFailure -Message $Message
    }
}

function Assert-Equal {
    param([object]$Actual, [object]$Expected, [string]$Message)
    if ([string]$Actual -eq [string]$Expected) {
        Write-Host "PASS: $Message" -ForegroundColor Green
    } else {
        Add-TestFailure -Message "$Message (expected '$Expected', got '$Actual')"
    }
}

function Write-FixtureMission {
    param(
        [string]$FixtureName,
        [string]$OutPath,
        [string]$RepoPath
    )

    $fixture = Read-TsfKernelJson -Path (Join-Path $fixtureDir $FixtureName)
    $fixture.repo_path = $RepoPath
    Write-TsfKernelJson -Value $fixture -Path $OutPath
    return $fixture
}

function Write-FixtureLedger {
    param(
        [string]$OutPath,
        [string]$RepoPath
    )

    $ledger = Read-TsfKernelJson -Path (Join-Path $fixtureDir "approval-ledger.fixture.sample.json")
    $ledger.approvals[0].repo_path = $RepoPath
    Write-TsfKernelJson -Value $ledger -Path $OutPath
    return $ledger
}

Write-Host "Running Minimum Viable TSF Kernel tests..." -ForegroundColor Cyan

$fixtureDir = Join-Path $fleetRoot "tests\fixtures\fleet\enforcement-kernel"
$testRoot = Join-Path $fleetRoot ".codex-local\fixtures\minimum-viable-kernel-tests"
Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

$repoPath = Join-Path $testRoot "repo"
New-Item -ItemType Directory -Force -Path $repoPath | Out-Null
& git -C $repoPath init | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "git init failed for fixture repo"
}

$stateRoot = Join-Path $testRoot "states"
$validMissionPath = Join-Path $testRoot "mission.valid.json"
$approvalMissionPath = Join-Path $testRoot "mission.approval.json"
$invalidMissionPath = Join-Path $testRoot "mission.invalid.json"
$ledgerPath = Join-Path $testRoot "approval-ledger.fixture.sample.json"
$preflightPath = Join-Path $testRoot "preflight.valid.json"
$blockedPreflightPath = Join-Path $testRoot "preflight.blocked.json"
$fixturePreflightPath = Join-Path $testRoot "preflight.fixture.json"
$fixtureAllowedPreflightPath = Join-Path $testRoot "preflight.fixture-allowed.json"
$adapterPath = Join-Path $testRoot "worker-instruction.json"
$refusedAdapterPath = Join-Path $testRoot "worker-refused.json"
$missingVerifierPath = Join-Path $testRoot "verifier.missing.json"
$greenVerifierPath = Join-Path $testRoot "verifier.green.json"
$preservationSummaryPath = Join-Path $testRoot "preservation-summary.json"

Write-FixtureMission -FixtureName "mission.valid.local-tsf.json" -OutPath $validMissionPath -RepoPath $repoPath | Out-Null
Write-FixtureMission -FixtureName "mission.restricted-missing-approval.json" -OutPath $approvalMissionPath -RepoPath $repoPath | Out-Null
Write-FixtureMission -FixtureName "mission.invalid-missing-artifacts.json" -OutPath $invalidMissionPath -RepoPath $repoPath | Out-Null
Write-FixtureLedger -OutPath $ledgerPath -RepoPath $repoPath | Out-Null

$validPreflight = Invoke-TsfKernelPreflight -MissionPath $validMissionPath -OutFile $preflightPath -StateRoot $stateRoot
Assert-Equal -Actual $validPreflight.verdict -Expected "GREEN" -Message "Valid mission preflight is GREEN"
Assert-True -Condition ([bool]$validPreflight.preflight_approved) -Message "Valid mission is approved for worker"
Assert-True -Condition (Test-Path -LiteralPath (Join-Path $stateRoot "approved-for-worker\tsf-kernel-fixture-valid-0001.json")) -Message "Approved mission is copied to approved-for-worker state"

$blockedPreflight = Invoke-TsfKernelPreflight -MissionPath $approvalMissionPath -OutFile $blockedPreflightPath -StateRoot $stateRoot
Assert-Equal -Actual $blockedPreflight.verdict -Expected "TIM_REQUIRED" -Message "Restricted action without approval returns TIM_REQUIRED"
Assert-True -Condition (!$blockedPreflight.preflight_approved) -Message "Restricted action without approval is not approved"

$fixturePreflight = Invoke-TsfKernelPreflight -MissionPath $approvalMissionPath -ApprovalLedgerPath $ledgerPath -OutFile $fixturePreflightPath -StateRoot $stateRoot
Assert-Equal -Actual $fixturePreflight.verdict -Expected "TIM_REQUIRED" -Message "Fixture approval is recognized but not authority by default"
$fixtureMatchCount = @($fixturePreflight.approval_matches | Where-Object { $_.match_status -eq "FIXTURE_MATCH_NOT_AUTHORITY" }).Count
Assert-True -Condition ($fixtureMatchCount -eq 1) -Message "Fixture approval match status is explicit"

Assert-True -Condition (!(Get-Command Invoke-TsfKernelPreflight).Parameters.ContainsKey('AllowFixtureApprovalsForTests')) -Message "Runtime preflight exposes no fixture-approval authority switch"
Assert-True -Condition (!(Get-Command (Join-Path $fleetRoot 'tsf-kernel-preflight.ps1')).Parameters.ContainsKey('AllowFixtureApprovalsForTests')) -Message "Runtime wrapper exposes no fixture-approval authority switch"

$invalidPreflight = Invoke-TsfKernelPreflight -MissionPath $invalidMissionPath -StateRoot $stateRoot
Assert-Equal -Actual $invalidPreflight.verdict -Expected "RED" -Message "Invalid mission schema fails closed"

$adapter = New-TsfKernelWorkerInstruction -MissionPath $validMissionPath -PreflightResultPath $preflightPath -OutFile $adapterPath -StateRoot $stateRoot
Assert-Equal -Actual $adapter.adapter_status -Expected "STUB_READY_CODEX_CLI_BLOCKED" -Message "Approved mission creates safe Codex adapter stub"
Assert-True -Condition (!$adapter.background_runner_started) -Message "Adapter does not start background runner"
Assert-True -Condition (!$adapter.all_fleet_started) -Message "Adapter does not start all-fleet"
Assert-True -Condition ([string]$adapter.command_preview -match "NOT RUN IN V1") -Message "Adapter produces a non-executed command preview"
Assert-True -Condition ([string]$adapter.allowed_scope_summary.allowed_reads -match "docs/hq") -Message "Adapter summarizes allowed reads"
Assert-True -Condition ([string]$adapter.forbidden_action_summary -match "push") -Message "Adapter summarizes forbidden actions"
Assert-True -Condition ([string]$adapter.expected_artifact_contract -match "fixture-artifact") -Message "Adapter summarizes expected artifacts"
Assert-True -Condition ([string]$adapter.postrun_verifier_instruction -match "tsf-kernel-postrun-verify.ps1") -Message "Adapter includes post-run verifier instruction"

$refused = New-TsfKernelWorkerInstruction -MissionPath $approvalMissionPath -PreflightResultPath $blockedPreflightPath -OutFile $refusedAdapterPath -StateRoot $stateRoot
Assert-Equal -Actual $refused.adapter_status -Expected "REFUSED_PREFLIGHT_FAILED" -Message "Adapter refuses failed preflight"

$missingWorkerResultPath = Join-Path $testRoot "worker-result.missing-artifact.json"
Copy-Item -LiteralPath (Join-Path $fixtureDir "worker-result.missing-artifact.json") -Destination $missingWorkerResultPath -Force
$missingVerifier = Invoke-TsfKernelPostRunVerify -MissionPath $validMissionPath -WorkerResultPath $missingWorkerResultPath -OutFile $missingVerifierPath -StateRoot $stateRoot
Assert-Equal -Actual $missingVerifier.verdict -Expected "RED" -Message "Verifier fails closed when required artifact is missing"
Assert-True -Condition (!$missingVerifier.verified) -Message "Missing artifact is not verified"

$artifactPath = Join-Path $repoPath "expected\fixture-artifact.txt"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $artifactPath) | Out-Null
Set-Content -LiteralPath $artifactPath -Encoding UTF8 -Value "fixture artifact"
$missingClaimWorkerResultPath = Join-Path $testRoot "worker-result.missing-created-claim.json"
Copy-Item -LiteralPath (Join-Path $fixtureDir "worker-result.missing-created-claim.json") -Destination $missingClaimWorkerResultPath -Force
$missingClaimVerifierPath = Join-Path $testRoot "verifier.missing-created-claim.json"
$missingClaimVerifier = Invoke-TsfKernelPostRunVerify -MissionPath $validMissionPath -WorkerResultPath $missingClaimWorkerResultPath -OutFile $missingClaimVerifierPath -StateRoot $stateRoot
Assert-Equal -Actual $missingClaimVerifier.verdict -Expected "RED" -Message "Verifier fails when worker result does not claim expected artifact"
Assert-True -Condition (($missingClaimVerifier.blocked_reasons -join "`n") -match "did not claim expected artifact") -Message "Verifier records expected artifact claim failure"

$outsideAllowedWorkerResultPath = Join-Path $testRoot "worker-result.outside-allowed-write.json"
Copy-Item -LiteralPath (Join-Path $fixtureDir "worker-result.outside-allowed-write.json") -Destination $outsideAllowedWorkerResultPath -Force
$outsideAllowedVerifierPath = Join-Path $testRoot "verifier.outside-allowed-write.json"
$outsideAllowedVerifier = Invoke-TsfKernelPostRunVerify -MissionPath $validMissionPath -WorkerResultPath $outsideAllowedWorkerResultPath -OutFile $outsideAllowedVerifierPath -StateRoot $stateRoot
Assert-Equal -Actual $outsideAllowedVerifier.verdict -Expected "RED" -Message "Verifier fails when worker touches outside allowed_writes"
Assert-True -Condition (($outsideAllowedVerifier.blocked_reasons -join "`n") -match "outside allowed_writes") -Message "Verifier records allowed-write scope failure"

$validWorkerResultPath = Join-Path $testRoot "worker-result.valid.json"
Copy-Item -LiteralPath (Join-Path $fixtureDir "worker-result.valid.json") -Destination $validWorkerResultPath -Force
$greenVerifier = Invoke-TsfKernelPostRunVerify -MissionPath $validMissionPath -WorkerResultPath $validWorkerResultPath -OutFile $greenVerifierPath -StateRoot $stateRoot
Assert-Equal -Actual $greenVerifier.verdict -Expected "RED" -Message "Legacy general mission fails closed without a task-completion contract"
Assert-True -Condition (!([bool]$greenVerifier.verified)) -Message "Legacy general result is not promoted to verified"
Assert-Equal -Actual $greenVerifier.final_state -Expected "blocked_red" -Message "Legacy general result writes deterministic blocked state"

$preserveOut = Get-TsfCanonicalRuntimeRoot
$preservation = Write-TsfKernelPreservationPacket -MissionPath $validMissionPath -PreflightResultPath $preflightPath -WorkerResultPath $validWorkerResultPath -VerifierResultPath $greenVerifierPath -OutputDirectory $preserveOut -ExactNextAction "Fixture preservation complete." -TestOnlyAllowSyntheticProducerRegistry
Write-TsfKernelJson -Value $preservation -Path $preservationSummaryPath
Assert-True -Condition (Test-Path -LiteralPath $preservation.packet_file) -Message "Compact preservation packet is written"
Assert-True -Condition (Test-Path -LiteralPath $preservation.manifest_path) -Message "Runtime artifact manifest is written"

$cliPreflightPath = Join-Path $testRoot "preflight.cli.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "tsf-kernel-preflight.ps1") -MissionPath $validMissionPath -OutFile $cliPreflightPath -StateRoot $stateRoot | Out-Null
Assert-Equal -Actual $LASTEXITCODE -Expected 0 -Message "Preflight wrapper exits 0 for valid mission"
Assert-True -Condition (Test-Path -LiteralPath $cliPreflightPath) -Message "Preflight wrapper writes JSON result"

$authorRepoPath = Join-Path $testRoot "author-repo"
New-Item -ItemType Directory -Force -Path $authorRepoPath | Out-Null
& git -C $authorRepoPath init | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "git init failed for authoring fixture repo"
}
$authoredMissionPath = Join-Path $testRoot "mission.authored.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "tools\New-TsfMissionPacket.ps1") `
    -MissionId "tsf-kernel-fixture-authored-0001" `
    -ProjectId "TSF_CONTROL_PLANE" `
    -RepoPath $authorRepoPath `
    -Lane "MASTER_TSF_CONTROL_PLANE" `
    -MissionType "tsf_infrastructure" `
    -AllowedReads "docs/hq/enforcement_kernel" `
    -AllowedWrites "expected/authored-fixture-artifact.txt" `
    -ExpectedArtifacts "expected/authored-fixture-artifact.txt" `
    -StopCondition "expected-artifact|artifact_exists|Expected artifact must exist after worker run." `
    -OutFile $authoredMissionPath `
    -ValidateShape | Out-Null
$authoringExitCode = $LASTEXITCODE
Assert-Equal -Actual $authoringExitCode -Expected 0 -Message "Mission authoring helper exits 0 for safe fixture packet"
Assert-True -Condition (Test-Path -LiteralPath $authoredMissionPath) -Message "Mission authoring helper writes packet"
$authoredMission = Read-TsfKernelJson -Path $authoredMissionPath
Assert-Equal -Actual $authoredMission.mission_id -Expected "tsf-kernel-fixture-authored-0001" -Message "Authored mission preserves requested id"
$authoredPreflight = Invoke-TsfKernelPreflight -MissionPath $authoredMissionPath -StateRoot $stateRoot
Assert-Equal -Actual $authoredPreflight.verdict -Expected "GREEN" -Message "Authored mission passes kernel preflight"

if ($script:Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Minimum Viable TSF Kernel tests failed: $($script:Failures.Count)" -ForegroundColor Red
    foreach ($failure in $script:Failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""
Write-Host "Minimum Viable TSF Kernel tests passed." -ForegroundColor Green
exit 0
