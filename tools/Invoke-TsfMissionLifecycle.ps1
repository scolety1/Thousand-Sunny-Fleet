[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$MissionPath,

    [string]$ApprovalLedgerPath = "",

    [string]$OutDirectory = "",

    [string]$OutFile = "",

    [string]$StateRoot = "",

    [switch]$DryRun,

    [switch]$RunApprovedFixtureWorker,

    [int]$WorkerTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $fleetRoot "tools\codex-fleet-enforcement-kernel.ps1")
. (Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1")

function New-LifecycleEvent {
    param(
        [string]$Step,
        [string]$Status,
        [string]$Message,
        [string]$Evidence = ""
    )

    [pscustomobject]@{
        step = $Step
        status = $Status
        message = $Message
        evidence = $Evidence
    }
}

function Get-LifecycleRelativeGitStatusPaths {
    param([string]$RepoPath)

    $lines = @(& git -C $RepoPath status --short --untracked-files=all 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw ($lines -join "`n")
    }

    $paths = @()
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
            continue
        }

        $path = $line.Substring(3).Trim()
        if ($path -match " -> ") {
            $path = ($path -split " -> ")[-1].Trim()
        }
        $paths += $path.Replace("\", "/")
    }

    return @($paths)
}

function Test-LifecycleFixturePilotMission {
    param(
        [Parameter(Mandatory = $true)][object]$Mission,
        [Parameter(Mandatory = $true)][object]$Preflight
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $repoPath = Get-TsfKernelFullPath -Path ([string]$Mission.repo_path)
    $fleetRootFull = Get-TsfKernelFullPath -Path $fleetRoot
    $expectedRelativePath = "tests/fixtures/fleet/enforcement-kernel/worker-output/fixture_worker_result.txt"
    $allowedOutputRoot = "tests/fixtures/fleet/enforcement-kernel/worker-output"

    if (!(Test-TsfKernelPathInside -ChildPath $repoPath -ParentPath $fleetRootFull)) {
        $reasons.Add("Fixture pilot repo_path must be inside the TSF repo.") | Out-Null
    }
    if ([string]$Mission.lane -ne "MASTER_TSF_CONTROL_PLANE") {
        $reasons.Add("Fixture pilot lane must be MASTER_TSF_CONTROL_PLANE.") | Out-Null
    }
    if ([string]$Mission.mission_type -ne "tsf_infrastructure") {
        $reasons.Add("Fixture pilot mission_type must be tsf_infrastructure.") | Out-Null
    }

    $expectedArtifacts = @(ConvertTo-TsfKernelArray -Value $Mission.expected_artifacts | ForEach-Object { ([string]$_).Replace("\", "/") })
    $allowedWrites = @(ConvertTo-TsfKernelArray -Value $Mission.allowed_writes | ForEach-Object { ([string]$_).Replace("\", "/") })
    if ($expectedArtifacts.Count -ne 1 -or $expectedArtifacts[0] -ne $expectedRelativePath) {
        $reasons.Add("Fixture pilot expected_artifacts must contain only $expectedRelativePath.") | Out-Null
    }
    if ($allowedWrites.Count -ne 1 -or $allowedWrites[0] -ne $expectedRelativePath) {
        $reasons.Add("Fixture pilot allowed_writes must contain only $expectedRelativePath.") | Out-Null
    }

    $requirements = @(Get-TsfKernelApprovalRequirements -Mission $Mission | Where-Object { [string]$_.exact_action -eq "codex_cli_fixture_worker_invocation" })
    if ($requirements.Count -ne 1) {
        $reasons.Add("Fixture pilot must require exact approval action codex_cli_fixture_worker_invocation.") | Out-Null
    }

    $approvalMatches = @(ConvertTo-TsfKernelArray -Value $Preflight.approval_matches | Where-Object { [string]$_.exact_action -eq "codex_cli_fixture_worker_invocation" -and [bool]$_.satisfied })
    if ($approvalMatches.Count -ne 1) {
        $reasons.Add("Fixture pilot exact approval was not satisfied by preflight.") | Out-Null
    }

    $forbiddenActions = @(ConvertTo-TsfKernelArray -Value $Mission.forbidden_actions | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
    foreach ($action in @("push", "merge", "deploy", "install_packages", "migration", "secrets", "background_runner", "persistent_runner", "all_fleet", "canonical_nwr_inspection", "canonical_nwr_mutation", "normal_nwr_packet_read", "product_repo_inspection", "product_repo_mutation")) {
        if ($forbiddenActions -notcontains $action) {
            $reasons.Add("Fixture pilot must forbid $action.") | Out-Null
        }
    }

    $allowedWriteRootFull = Get-TsfKernelFullPath -Path $allowedOutputRoot -BasePath $repoPath
    $expectedFull = Get-TsfKernelFullPath -Path $expectedRelativePath -BasePath $repoPath
    if (!(Test-TsfKernelPathInside -ChildPath $expectedFull -ParentPath $allowedWriteRootFull)) {
        $reasons.Add("Fixture pilot expected output must be inside worker-output folder.") | Out-Null
    }

    return @($reasons)
}

$mission = Read-TsfKernelJson -Path $MissionPath
$missionId = [string]$mission.mission_id
if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
    $safeMissionId = $missionId -replace "[^A-Za-z0-9._:-]", "_"
    $OutDirectory = Join-Path $fleetRoot ".codex-local\mission-lifecycle\$safeMissionId"
}
if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $StateRoot = Join-Path $OutDirectory "states"
}
if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = Join-Path $OutDirectory "lifecycle_result.json"
}

New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null
$events = [System.Collections.Generic.List[object]]::new()
$workerResultPath = Join-Path $OutDirectory "worker_result.json"
$preflightPath = Join-Path $OutDirectory "preflight_result.json"
$workerInstructionPath = Join-Path $OutDirectory "worker_instruction.json"
$verifierPath = Join-Path $OutDirectory "verifier_result.json"
$preservationRoot = Join-Path $OutDirectory "preservation"

$preflight = Invoke-TsfKernelPreflight -MissionPath $MissionPath -ApprovalLedgerPath $ApprovalLedgerPath -OutFile $preflightPath -StateRoot $StateRoot
$events.Add((New-LifecycleEvent -Step "preflight" -Status ([string]$preflight.verdict) -Message "Preflight completed." -Evidence $preflightPath)) | Out-Null

$workerInstruction = $null
$verifier = $null
$preservation = $null
$workerStatus = "NOT_RUN_DRY_RUN"
$codexCliDetected = $false
$codexCliInvoked = $false
$codexExitCode = $null
$codexOutputPath = ""
$workerFilesTouched = @()
$workerFilesCreated = @()
$unexpectedTouched = @()
$blockedReasons = [System.Collections.Generic.List[string]]::new()

if (!([bool]$preflight.preflight_approved)) {
    $blockedReasons.Add("Preflight did not approve mission.") | Out-Null
    $events.Add((New-LifecycleEvent -Step "worker_adapter" -Status "SKIPPED_PREFLIGHT_NOT_APPROVED" -Message "Worker adapter skipped because preflight failed.")) | Out-Null
} else {
    $workerInstruction = New-TsfKernelWorkerInstruction -MissionPath $MissionPath -PreflightResultPath $preflightPath -OutFile $workerInstructionPath -StateRoot $StateRoot
    $events.Add((New-LifecycleEvent -Step "worker_instruction" -Status ([string]$workerInstruction.adapter_status) -Message "Worker instruction generated." -Evidence $workerInstructionPath)) | Out-Null

    if (!$RunApprovedFixtureWorker) {
        $events.Add((New-LifecycleEvent -Step "worker_execution" -Status "DRY_RUN_NO_WORKER" -Message "Default lifecycle mode does not invoke a worker.")) | Out-Null
        $workerStatus = "DRY_RUN_NO_WORKER"
    } else {
        $fixtureErrors = @(Test-LifecycleFixturePilotMission -Mission $mission -Preflight $preflight)
        if ($fixtureErrors.Count -gt 0) {
            foreach ($reason in $fixtureErrors) { $blockedReasons.Add($reason) | Out-Null }
            $workerStatus = "BLOCKED_FIXTURE_SAFETY_CHECK_FAILED"
            $events.Add((New-LifecycleEvent -Step "fixture_safety" -Status $workerStatus -Message ($fixtureErrors -join "; "))) | Out-Null
        } else {
            $codexCommand = Get-Command "codex" -ErrorAction SilentlyContinue
            $codexCliDetected = ($null -ne $codexCommand)
            if (!$codexCliDetected) {
                $blockedReasons.Add("Codex CLI was not detected.") | Out-Null
                $workerStatus = "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL"
            } else {
                $versionOutput = @(codex --version 2>&1)
                if ($LASTEXITCODE -ne 0) {
                    $blockedReasons.Add("Codex CLI version check failed: $($versionOutput -join ' ')") | Out-Null
                    $workerStatus = "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL"
                } else {
                    $repoPath = Get-TsfKernelFullPath -Path ([string]$mission.repo_path)
                    $statusBefore = @(Get-LifecycleRelativeGitStatusPaths -RepoPath $repoPath)
                    if ($statusBefore.Count -gt 0) {
                        $blockedReasons.Add("Fixture pilot requires clean TSF repo status before worker invocation.") | Out-Null
                        $workerStatus = "BLOCKED_DIRTY_REPO_BEFORE_WORKER"
                    } else {
                        $expectedArtifact = "tests/fixtures/fleet/enforcement-kernel/worker-output/fixture_worker_result.txt"
                        $expectedFull = Get-TsfKernelFullPath -Path $expectedArtifact -BasePath $repoPath
                        $prompt = @"
You are a foreground TSF fixture worker.

Within the current TSF repo, create exactly this one file:
$expectedArtifact

The file content must be exactly:
TSF foreground worker pilot complete.

Do not touch any other file.
Do not inspect product repos.
Do not inspect C:\NWR\Niners-War-Room.
Do not read normal NWR packets.
Do not run installs, package managers, migrations, deploys, push, merge, all-fleet commands, servers, background processes, or network-port commands.
Return a concise status after the file is written.
"@
                        $lastMessagePath = Join-Path $OutDirectory "codex_worker_last_message.txt"
                        $codexOutputPath = Join-Path $OutDirectory "codex_worker_events.jsonl"
                        $codexCliInvoked = $true
                        $codexResult = Invoke-FleetProcess -FilePath "codex" -Arguments @("exec", "--ephemeral", "--cd", $repoPath, "--sandbox", "workspace-write", "--output-last-message", $lastMessagePath, "--json", "-") -InputText $prompt -WorkingDirectory $repoPath -LogPath $codexOutputPath -TimeoutSeconds $WorkerTimeoutSeconds
                        $codexExitCode = $codexResult.exitCode
                        $statusAfter = @(Get-LifecycleRelativeGitStatusPaths -RepoPath $repoPath)
                        $workerFilesTouched = @($statusAfter)
                        if (Test-Path -LiteralPath $expectedFull) {
                            $workerFilesCreated = @($expectedArtifact)
                        }
                        $unexpectedTouched = @($statusAfter | Where-Object { $_ -ne $expectedArtifact })
                        if ($codexResult.timedOut) {
                            $blockedReasons.Add("Codex CLI fixture pilot timed out.") | Out-Null
                            $workerStatus = "CODEX_CLI_TIMEOUT"
                        } elseif ($codexExitCode -ne 0) {
                            $codexOutputText = (($codexResult.output | ForEach-Object { [string]$_ }) -join "`n")
                            if ($codexOutputText -match "(?i)(auth|login|credential|config\.toml|service_tier|permission|approval)") {
                                $blockedReasons.Add("Codex CLI fixture pilot requires config/auth/permission review before execution can be trusted: $($codexOutputText -replace '\s+', ' ')") | Out-Null
                                $workerStatus = "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL"
                            } else {
                                $blockedReasons.Add("Codex CLI fixture pilot exited nonzero: $codexExitCode") | Out-Null
                                $workerStatus = "CODEX_CLI_NONZERO"
                            }
                        } elseif ($unexpectedTouched.Count -gt 0) {
                            $blockedReasons.Add("Codex CLI touched paths outside the allowed fixture output: $($unexpectedTouched -join ', ')") | Out-Null
                            $workerStatus = "CODEX_CLI_TOUCHED_FORBIDDEN_PATH"
                        } elseif (!(Test-Path -LiteralPath $expectedFull)) {
                            $blockedReasons.Add("Codex CLI did not create the expected fixture artifact.") | Out-Null
                            $workerStatus = "CODEX_CLI_EXPECTED_ARTIFACT_MISSING"
                        } else {
                            $content = (Get-Content -LiteralPath $expectedFull -Raw).Trim()
                            if ($content -ne "TSF foreground worker pilot complete.") {
                                $blockedReasons.Add("Codex CLI created artifact with unexpected content.") | Out-Null
                                $workerStatus = "CODEX_CLI_UNEXPECTED_ARTIFACT_CONTENT"
                            } else {
                                $workerStatus = "CODEX_CLI_FIXTURE_WORKER_GREEN"
                            }
                        }
                    }
                }
            }

            $events.Add((New-LifecycleEvent -Step "worker_execution" -Status $workerStatus -Message "Fixture worker step completed or blocked." -Evidence $codexOutputPath)) | Out-Null
        }
    }
}

$workerResult = [pscustomobject]@{
    schema_version = 1
    mission_id = $missionId
    worker_status = $workerStatus
    codex_cli_detected = $codexCliDetected
    codex_cli_invoked = $codexCliInvoked
    codex_exit_code = $codexExitCode
    files_touched = @($workerFilesTouched)
    files_created = @($workerFilesCreated)
    unexpected_touched_files = @($unexpectedTouched)
    restricted_actions_attempted = @()
    blocked_reasons = @($blockedReasons)
}
Write-TsfKernelJson -Value $workerResult -Path $workerResultPath

if ([bool]$preflight.preflight_approved -and $RunApprovedFixtureWorker) {
    $verifier = Invoke-TsfKernelPostRunVerify -MissionPath $MissionPath -WorkerResultPath $workerResultPath -OutFile $verifierPath -StateRoot $StateRoot
    $events.Add((New-LifecycleEvent -Step "postrun_verify" -Status ([string]$verifier.verdict) -Message "Post-run verifier completed." -Evidence $verifierPath)) | Out-Null
}

$exactNextAction = if ($RunApprovedFixtureWorker) {
    "Review fixture lifecycle output. Commit only if verifier is GREEN and touched files are expected."
} else {
    "Dry-run lifecycle complete. Run with -RunApprovedFixtureWorker only for the approved fixture pilot."
}
$preservation = Write-TsfKernelPreservationPacket -MissionPath $MissionPath -PreflightResultPath $preflightPath -WorkerResultPath $workerResultPath -VerifierResultPath $verifierPath -OutputDirectory $preservationRoot -ExactNextAction $exactNextAction
$events.Add((New-LifecycleEvent -Step "preserve" -Status ([string]$preservation.final_decision) -Message "Preservation packet written." -Evidence ([string]$preservation.packet_directory))) | Out-Null

$finalDecision = "YELLOW"
if (![bool]$preflight.preflight_approved) {
    $finalDecision = [string]$preflight.verdict
} elseif ($blockedReasons.Count -gt 0) {
    $finalDecision = "RED"
} elseif ($null -ne $verifier) {
    $finalDecision = [string]$verifier.verdict
} elseif ($workerStatus -eq "DRY_RUN_NO_WORKER") {
    $finalDecision = "YELLOW"
}

$result = [pscustomobject]@{
    schema_version = 1
    generated_at = (Get-Date).ToString("o")
    mission_id = $missionId
    mission_path = (Get-TsfKernelFullPath -Path $MissionPath)
    approval_ledger_path = if ([string]::IsNullOrWhiteSpace($ApprovalLedgerPath)) { "" } else { Get-TsfKernelFullPath -Path $ApprovalLedgerPath }
    out_directory = (Get-TsfKernelFullPath -Path $OutDirectory)
    final_decision = $finalDecision
    preflight_verdict = [string]$preflight.verdict
    preflight_approved = [bool]$preflight.preflight_approved
    worker_status = $workerStatus
    codex_cli_detected = $codexCliDetected
    codex_cli_invoked = $codexCliInvoked
    codex_exit_code = $codexExitCode
    worker_result_path = $workerResultPath
    verifier_verdict = if ($null -ne $verifier) { [string]$verifier.verdict } else { "" }
    preservation_packet_path = [string]$preservation.packet_directory
    events = @($events)
    blocked_reasons = @($blockedReasons)
    background_runner_started = $false
    all_fleet_started = $false
    product_repos_mutated = $false
    canonical_nwr_mutated = $false
    push_merge_deploy_attempted = $false
}

Write-TsfKernelJson -Value $result -Path $OutFile
$result | ConvertTo-Json -Depth 30

if ($finalDecision -eq "GREEN" -or $finalDecision -eq "YELLOW") {
    exit 0
}

exit 1
