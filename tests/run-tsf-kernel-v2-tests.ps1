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

function Write-TestJson {
    param([object]$Value, [string]$Path)
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-BaseMission {
    param(
        [string]$MissionId,
        [string]$RepoPath,
        [string]$ExpectedArtifact = "expected/fixture-artifact.txt",
        [string[]]$ApprovalActions = @(),
        [string[]]$AllowedWrites = @()
    )

    if ($AllowedWrites.Count -eq 0) {
        $AllowedWrites = @($ExpectedArtifact)
    }

    $approvalRequirements = @()
    foreach ($action in $ApprovalActions) {
        $approvalRequirements += [pscustomobject]@{
            exact_action = $action
            required = $true
            reason = "Regression fixture requests $action."
            approval_id = "missing-$action"
        }
    }

    $approvalActionSet = @($ApprovalActions | ForEach-Object { $_.Trim().ToLowerInvariant() })
    $forbiddenActions = @($script:TsfKernelRestrictedActions | Where-Object { $approvalActionSet -notcontains $_ })

    return [pscustomobject]@{
        mission_id = $MissionId
        project_id = "TSF_CONTROL_PLANE"
        repo_path = $RepoPath
        lane = "MASTER_TSF_CONTROL_PLANE"
        mission_type = "tsf_infrastructure"
        allowed_reads = @("docs/hq/enforcement_kernel")
        allowed_writes = @($AllowedWrites)
        forbidden_reads = @("C:/NWR/Niners-War-Room")
        forbidden_writes = @("C:/NWR/Niners-War-Room")
        forbidden_actions = @($forbiddenActions)
        expected_artifacts = @($ExpectedArtifact)
        required_preflight_checks = @("schema", "repo_exists", "path_scope", "restricted_action_coverage", "git_status_capture", "approval_ledger")
        required_postrun_checks = @("mission_id_match", "expected_artifacts_exist", "restricted_actions_absent", "forbidden_outputs_absent")
        stop_conditions = @(
            [pscustomobject]@{
                id = "expected-artifact"
                check_type = "artifact_exists"
                description = "Expected artifact must exist."
            }
        )
        approval_requirements = @($approvalRequirements)
        hq_escalation_policy = [pscustomobject]@{
            default = "local_only_no_api"
            escalate_on = @("RED", "TIM_REQUIRED")
            notes = "Regression fixture."
        }
        created_by = "fixture"
        created_at = "2026-07-08T00:00:00Z"
    }
}

Write-Host "Running TSF Kernel V2 tests..." -ForegroundColor Cyan

$testRoot = Join-Path $fleetRoot ".codex-local\fixtures\tsf-kernel-v2-tests"
Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $testRoot | Out-Null

$repoPath = Join-Path $testRoot "repo"
New-Item -ItemType Directory -Force -Path $repoPath | Out-Null
& git -C $repoPath init | Out-Null
if ($LASTEXITCODE -ne 0) { throw "git init failed" }

$stateRoot = Join-Path $testRoot "states"
$validMissionPath = Join-Path $testRoot "mission.lifecycle-valid.json"
$validMission = New-BaseMission -MissionId "tsf-kernel-v2-lifecycle-valid" -RepoPath $repoPath
Write-TestJson -Value $validMission -Path $validMissionPath

$lifecycleOut = Join-Path $testRoot "lifecycle-dry-run"
$lifecycleResultPath = Join-Path $lifecycleOut "lifecycle_result.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "tools\Invoke-TsfMissionLifecycle.ps1") -MissionPath $validMissionPath -OutDirectory $lifecycleOut -OutFile $lifecycleResultPath | Out-Null
Assert-Equal -Actual $LASTEXITCODE -Expected 0 -Message "Lifecycle dry-run wrapper exits 0"
$lifecycleResult = Read-TsfKernelJson -Path $lifecycleResultPath
Assert-Equal -Actual $lifecycleResult.final_decision -Expected "YELLOW" -Message "Lifecycle dry-run closes as YELLOW"
Assert-Equal -Actual $lifecycleResult.worker_status -Expected "DRY_RUN_NO_WORKER" -Message "Lifecycle dry-run does not run worker"
Assert-True -Condition (Test-Path -LiteralPath $lifecycleResult.preservation_packet_path) -Message "Lifecycle dry-run writes preservation packet"

$fixtures = Read-TsfKernelJson -Path (Join-Path $fleetRoot "tests\fixtures\fleet\enforcement-kernel\failure-modes\failure-mode-regression-fixtures.json")
$rows = @()
foreach ($fixture in @($fixtures.fixtures)) {
    $caseId = [string]$fixture.case_id
    $expected = [string]$fixture.expected_verdict
    $missionPath = Join-Path $testRoot "$caseId.json"
    $observed = ""
    $passed = $false

    if ([string]$fixture.mode -eq "malformed_missing_fields") {
        Write-TestJson -Value ([pscustomobject]@{ mission_id = "bad" }) -Path $missionPath
        $result = Invoke-TsfKernelPreflight -MissionPath $missionPath -StateRoot $stateRoot
        $observed = [string]$result.verdict
    } elseif ([string]$fixture.mode -eq "approval_required") {
        $mission = New-BaseMission -MissionId "case-$caseId" -RepoPath $repoPath -ApprovalActions @([string]$fixture.exact_action)
        Write-TestJson -Value $mission -Path $missionPath
        $result = Invoke-TsfKernelPreflight -MissionPath $missionPath -StateRoot $stateRoot
        $observed = [string]$result.verdict
    } elseif ([string]$fixture.mode -eq "forbidden_write_path") {
        $mission = New-BaseMission -MissionId "case-$caseId" -RepoPath $repoPath -ExpectedArtifact "C:/NWR/Niners-War-Room/forbidden.txt" -AllowedWrites @("C:/NWR/Niners-War-Room/forbidden.txt")
        Write-TestJson -Value $mission -Path $missionPath
        $result = Invoke-TsfKernelPreflight -MissionPath $missionPath -StateRoot $stateRoot
        $observed = [string]$result.verdict
    } elseif ([string]$fixture.mode -eq "branch_mismatch") {
        $mission = New-BaseMission -MissionId "case-$caseId" -RepoPath $repoPath
        $mission | Add-Member -NotePropertyName required_branch -NotePropertyValue "definitely-not-current-branch" -Force
        Write-TestJson -Value $mission -Path $missionPath
        $result = Invoke-TsfKernelPreflight -MissionPath $missionPath -StateRoot $stateRoot
        $observed = [string]$result.verdict
    } elseif ([string]$fixture.mode -eq "postrun_missing_artifact") {
        $mission = New-BaseMission -MissionId "tsf-kernel-fixture-valid-0001" -RepoPath $repoPath
        Write-TestJson -Value $mission -Path $missionPath
        $workerPath = Join-Path $testRoot "$caseId.worker.json"
        Copy-Item -LiteralPath (Join-Path $fleetRoot "tests\fixtures\fleet\enforcement-kernel\worker-result.missing-artifact.json") -Destination $workerPath -Force
        $result = Invoke-TsfKernelPostRunVerify -MissionPath $missionPath -WorkerResultPath $workerPath -StateRoot $stateRoot
        $observed = [string]$result.verdict
    } else {
        $observed = "UNKNOWN_MODE"
    }

    $passed = ($observed -eq $expected)
    Assert-True -Condition $passed -Message "Failure mode $caseId fails closed as $expected"
    $rows += [pscustomobject]@{
        case_id = $caseId
        mode = [string]$fixture.mode
        expected_verdict = $expected
        observed_verdict = $observed
        passed = $passed
    }
}

$matrixOut = Join-Path $testRoot "failure_mode_regression_matrix.csv"
$rows | Export-Csv -LiteralPath $matrixOut -NoTypeInformation

if ($script:Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "TSF Kernel V2 tests failed: $($script:Failures.Count)" -ForegroundColor Red
    foreach ($failure in $script:Failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""
Write-Host "TSF Kernel V2 tests passed." -ForegroundColor Green
exit 0
