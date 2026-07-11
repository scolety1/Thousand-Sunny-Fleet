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

    [switch]$RunCanonicalAppServerWorker,

    [switch]$ManageQueueTransitions,

    [string]$QueueMissionPath = "",

    [string]$QueueRoot = "fleet/missions",

    [string]$RuntimeRoot = "",

    [int]$WorkerTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $fleetRoot "tools\codex-fleet-enforcement-kernel.ps1")
. (Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1")
Import-Module (Join-Path $fleetRoot "tools\TsfDurableContract.psm1") -Force

function Test-LifecycleProperty {
    param([object]$Value, [string]$Name)
    return ($null -ne $Value -and $Value.PSObject.Properties.Name -contains $Name)
}

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

    $safeDirectory = (Get-TsfKernelFullPath -Path $RepoPath).Replace('\','/')
    $lines = @(& git -c "safe.directory=$safeDirectory" -C $RepoPath status --short --untracked-files=all 2>&1)
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

$inputDocument = Read-TsfKernelJson -Path $MissionPath
$queueDocumentCheck = $null
$queueDocumentHash = ""
if ([string]$inputDocument.schema_version -eq 'tsf_canonical_queue_document_v1') {
    $queueDocumentCheck = Test-TsfCanonicalQueueDocument -QueueDocument $inputDocument
    if (![bool]$queueDocumentCheck.valid) { throw "Canonical queue document failed binding: $($queueDocumentCheck.errors -join '; ')" }
    $mission = $queueDocumentCheck.effective_mission
    $queueDocumentHash = [string]$queueDocumentCheck.queue_document_sha256
} else {
    $mission = if (Test-LifecycleProperty -Value $inputDocument -Name "mission_packet") { $inputDocument.mission_packet } else { $inputDocument }
}
$roleExtension = if (Test-LifecycleProperty -Value $inputDocument -Name "role_extension") {
    $inputDocument.role_extension
} elseif (Test-LifecycleProperty -Value $mission -Name "role_extension") {
    $mission.role_extension
} else {
    $null
}
$missionId = [string]$mission.mission_id
$missionRevision = if (Test-LifecycleProperty -Value $inputDocument -Name 'source_binding') { [int]$inputDocument.source_binding.durable_mission_revision } elseif (Test-LifecycleProperty -Value $inputDocument -Name 'durable_mission') { [int]$inputDocument.durable_mission.mission_revision } else { 1 }
$runId = if (Test-LifecycleProperty -Value $inputDocument -Name 'source_binding') { "canonical-result-$missionId-$missionRevision" } else { Get-TsfRuntimeSha256Text "$missionId|$missionRevision|$((Get-FileHash -LiteralPath $MissionPath -Algorithm SHA256).Hash.ToLowerInvariant())" }
if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) { $RuntimeRoot = Join-Path $fleetRoot '.codex-local\rt' }
$adapterStoragePlan = New-TsfRuntimeStoragePlan -RuntimeRoot $RuntimeRoot -MissionId $missionId -MissionRevision $missionRevision -RunId $runId -Layout adapter
$preservationStoragePlan = New-TsfRuntimeStoragePlan -RuntimeRoot $RuntimeRoot -MissionId $missionId -MissionRevision $missionRevision -RunId $runId -Layout preservation
$completeRuntimePaths=@()
$completeRuntimePaths+=@($adapterStoragePlan.artifacts.PSObject.Properties|ForEach-Object{[string]$_.Value})
$completeRuntimePaths+=@($preservationStoragePlan.artifacts.PSObject.Properties|ForEach-Object{[string]$_.Value})
$completeRuntimePaths+=@($preservationStoragePlan.staging_artifacts.PSObject.Properties|ForEach-Object{[string]$_.Value})
$completeRuntimePaths+=@($preservationStoragePlan.receipt_paths.PSObject.Properties|ForEach-Object{[string]$_.Value})
$completePathPlan = Test-TsfRuntimePathPlan -RuntimeRoot $RuntimeRoot -Paths $completeRuntimePaths
if (!$completePathPlan.valid) { throw "Lifecycle runtime artifact path preflight failed before worker execution: $($completePathPlan.errors -join '; ')" }
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
$effectiveMissionPath = $MissionPath
$rolePreflightPath = Join-Path $OutDirectory "role_permission_preflight.json"
$workerResultPath = Join-Path $OutDirectory "worker_result.json"
$preflightPath = Join-Path $OutDirectory "preflight_result.json"
$workerInstructionPath = Join-Path $OutDirectory "worker_instruction.json"
$verifierPath = Join-Path $OutDirectory "verifier_result.json"
$preservationRoot = $RuntimeRoot

if (Test-LifecycleProperty -Value $inputDocument -Name "mission_packet") {
    if ($null -ne $roleExtension -and !(Test-LifecycleProperty -Value $mission -Name "role_extension")) {
        $mission | Add-Member -NotePropertyName "role_extension" -NotePropertyValue $roleExtension -Force
    }
    $effectiveMissionPath = Join-Path $OutDirectory "mission_packet.effective.json"
    Write-TsfKernelJson -Value $mission -Path $effectiveMissionPath
    $events.Add((New-LifecycleEvent -Step "mission_normalize" -Status "PASS" -Message "Project Main Bot draft normalized to mission packet for kernel lifecycle." -Evidence $effectiveMissionPath)) | Out-Null
}

$preflight = Invoke-TsfKernelPreflight -MissionPath $effectiveMissionPath -ApprovalLedgerPath $ApprovalLedgerPath -OutFile $preflightPath -StateRoot $StateRoot
$events.Add((New-LifecycleEvent -Step "preflight" -Status ([string]$preflight.verdict) -Message "Preflight completed." -Evidence $preflightPath)) | Out-Null

$workerInstruction = $null
$rolePreflight = $null
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
$roleOutputContractSatisfied = $false
$adapterResult = $null
$adapterResultPath = [string]$adapterStoragePlan.artifacts.adapter_result
$adapterEventPath = [string]$adapterStoragePlan.artifacts.event_journal
$adapterStderrPath = [string]$adapterStoragePlan.artifacts.stderr
$currentQueueMissionPath = $QueueMissionPath
$script:currentQueueMissionPath = $QueueMissionPath

function Move-LifecycleQueueState {
    param([string]$From,[string]$To)
    if (!$ManageQueueTransitions) { return }
    if ([string]::IsNullOrWhiteSpace($script:currentQueueMissionPath)) { throw 'QueueMissionPath is required when lifecycle manages transitions.' }
    $transitionPath = Join-Path $OutDirectory "transition_${From}_to_${To}.json"
    $transition = & (Join-Path $fleetRoot 'tools\Move-TsfMissionState.ps1') -MissionPath $script:currentQueueMissionPath -FromState $From -ToState $To -QueueRoot $QueueRoot -OutFile $transitionPath
    if ([string]$transition.verdict -ne 'GREEN') { throw "Lifecycle queue transition failed: $From -> $To :: $($transition.blocked_reasons -join '; ')" }
    $script:currentQueueMissionPath = [string]$transition.destination_path
    $events.Add((New-LifecycleEvent -Step 'queue_transition' -Status 'PASS' -Message "$From -> $To" -Evidence $transitionPath)) | Out-Null
}
$rolePreflightApproved = $true
$rolePreflightVerdict = "NOT_REQUIRED"
$requiresRolePreflight = $false
if ($null -ne $roleExtension) {
    $requiresRolePreflight = $true
}
if (@(ConvertTo-TsfKernelArray -Value $mission.required_preflight_checks | Where-Object { [string]$_ -eq "worker_role_permission" }).Count -gt 0) {
    $requiresRolePreflight = $true
}

if (!([bool]$preflight.preflight_approved)) {
    $blockedReasons.Add("Preflight did not approve mission.") | Out-Null
    $events.Add((New-LifecycleEvent -Step "worker_adapter" -Status "SKIPPED_PREFLIGHT_NOT_APPROVED" -Message "Worker adapter skipped because preflight failed.")) | Out-Null
} else {
    if ($requiresRolePreflight) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "tools\Test-TsfWorkerRolePermission.ps1") -MissionDraftPath $effectiveMissionPath -OutFile $rolePreflightPath | Out-Null
        $rolePreflight = Read-TsfKernelJson -Path $rolePreflightPath
        $rolePreflightVerdict = [string]$rolePreflight.verdict
        $rolePreflightApproved = [bool]$rolePreflight.role_preflight_approved
        $events.Add((New-LifecycleEvent -Step "worker_role_permission" -Status $rolePreflightVerdict -Message "Role-aware permission preflight completed." -Evidence $rolePreflightPath)) | Out-Null
        if (!$rolePreflightApproved) {
            foreach ($reason in @(ConvertTo-TsfKernelArray -Value $rolePreflight.blocked_reasons)) { $blockedReasons.Add([string]$reason) | Out-Null }
            foreach ($reason in @(ConvertTo-TsfKernelArray -Value $rolePreflight.tim_required_reasons)) { $blockedReasons.Add([string]$reason) | Out-Null }
            $workerStatus = if ($rolePreflightVerdict -eq "TIM_REQUIRED") { "TIM_REQUIRED_ROLE_PERMISSION" } else { "BLOCKED_ROLE_PERMISSION" }
            $events.Add((New-LifecycleEvent -Step "worker_adapter" -Status "SKIPPED_ROLE_PERMISSION_NOT_APPROVED" -Message "Worker instruction generation skipped because role permission failed.")) | Out-Null
        }
    }

    if ($rolePreflightApproved) {
        Move-LifecycleQueueState -From 'preflight_pending' -To 'approved_for_worker'
        $workerInstruction = New-TsfKernelWorkerInstruction -MissionPath $effectiveMissionPath -PreflightResultPath $preflightPath -OutFile $workerInstructionPath -StateRoot $StateRoot
        $events.Add((New-LifecycleEvent -Step "worker_instruction" -Status ([string]$workerInstruction.adapter_status) -Message "Worker instruction generated." -Evidence $workerInstructionPath)) | Out-Null

        if (!$RunApprovedFixtureWorker -and !$RunCanonicalAppServerWorker) {
            $events.Add((New-LifecycleEvent -Step "worker_execution" -Status "DRY_RUN_NO_WORKER" -Message "Default lifecycle mode does not invoke a worker.")) | Out-Null
            $workerStatus = "DRY_RUN_NO_WORKER"
        } elseif ($RunCanonicalAppServerWorker) {
            Move-LifecycleQueueState -From 'approved_for_worker' -To 'worker_running'
            $repoPath = Get-TsfKernelFullPath -Path ([string]$mission.repo_path)
            $statusBefore = @(Get-LifecycleRelativeGitStatusPaths -RepoPath $repoPath)
            $sandbox = if (@(ConvertTo-TsfKernelArray -Value $mission.allowed_writes).Count -eq 0) { 'read-only' } else { 'workspace-write' }
            New-Item -ItemType Directory -Force -Path $adapterStoragePlan.directory | Out-Null
            $promptPath = Join-Path $adapterStoragePlan.directory 'q.txt'
            $task = if ($mission.PSObject.Properties.Name -contains 'worker_instruction_contract') { [string]$mission.worker_instruction_contract.exact_task } else { 'Return exactly TSF_CANONICAL_APP_SERVER_GREEN.' }
            $prompt = @"
TSF mission id: $missionId
Execute only this synthetic task:
$task

Worker shell and tool network access is disabled. Do not browse or call any external service.
Do not access secrets, authentication files, NWR, TSF-NWR, normal NWR packets, PrivateLens, product repositories, or unrelated repositories.
Do not install packages, push, merge, deploy, start servers, listeners, daemons, background jobs, or scheduled work.
Use only the explicitly allowed read/write paths in the bound mission.
"@
            Set-Content -LiteralPath $promptPath -Value $prompt -Encoding UTF8
            $adapterResult = & (Join-Path $fleetRoot 'tools\Invoke-TsfCodexAppServerForeground.ps1') -MissionId $missionId -MissionRevision $missionRevision -PolicyFingerprint ([string]$inputDocument.source_binding.policy_fingerprint) -QueueDocumentSha256 $queueDocumentHash -Cwd $repoPath -Model ([string]$inputDocument.model_resolution.resolved_model) -ReasoningEffort ([string]$inputDocument.model_resolution.reasoning_effort) -EffortAssurance ([string]$inputDocument.durable_mission.model_selection_assurance) -Sandbox $sandbox -PromptFile $promptPath -OutputDirectory ([string]$adapterStoragePlan.directory) -ResultPath $adapterResultPath -EventJournalPath $adapterEventPath -StderrPath $adapterStderrPath -ExpiresAt ([datetimeoffset]$inputDocument.durable_mission.expires_at) -TimeoutSeconds $WorkerTimeoutSeconds
            $statusAfter = @(Get-LifecycleRelativeGitStatusPaths -RepoPath $repoPath)
            $workerFilesTouched = @($statusAfter | Where-Object { $statusBefore -notcontains $_ })
            $workerFilesCreated = @($workerFilesTouched | Where-Object { Test-Path -LiteralPath (Get-TsfKernelFullPath -Path $_ -BasePath $repoPath) -PathType Leaf })
            $unexpectedTouched = @($workerFilesTouched | Where-Object { $allowed=$false;foreach($scope in @(ConvertTo-TsfKernelArray -Value $mission.allowed_writes)){if(Test-TsfKernelPathContained -RelativePath $_ -RepositoryRoot $repoPath -AllowedScopes @($scope)){$allowed=$true;break}};!$allowed })
            if (![bool]$adapterResult.success) { $blockedReasons.Add("App-server adapter failed: $($adapterResult.failure)") | Out-Null; $workerStatus='APP_SERVER_FAILED' }
            elseif ($unexpectedTouched.Count -gt 0) { $blockedReasons.Add("App-server worker touched forbidden paths: $($unexpectedTouched -join ', ')") | Out-Null; $workerStatus='APP_SERVER_TOUCHED_FORBIDDEN_PATH' }
            else { $workerStatus='CODEX_APP_SERVER_WORKER_GREEN';$roleOutputContractSatisfied=$true }
            $events.Add((New-LifecycleEvent -Step 'app_server_worker' -Status $workerStatus -Message 'Bound foreground app-server child completed.' -Evidence $adapterResultPath)) | Out-Null
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
}

$workerResult = [pscustomobject]@{
    schema_version = 1
    mission_id = $missionId
    worker_role = if ($null -ne $roleExtension) { [string]$roleExtension.worker_role } else { "" }
    role_output_contract_satisfied = $roleOutputContractSatisfied
    worker_status = $workerStatus
    codex_cli_detected = $codexCliDetected
    codex_cli_invoked = $codexCliInvoked
    codex_exit_code = $codexExitCode
    files_touched = @($workerFilesTouched)
    files_created = @($workerFilesCreated)
    unexpected_touched_files = @($unexpectedTouched)
    restricted_actions_attempted = @()
    blocked_reasons = @($blockedReasons)
    adapter_result_path = if ($null -ne $adapterResult) { $adapterResultPath } else { "" }
    adapter_result_sha256 = if ($null -ne $adapterResult -and (Test-Path $adapterResultPath)) { (Get-FileHash $adapterResultPath -Algorithm SHA256).Hash.ToLowerInvariant() } else { "" }
    thread_id = if ($null -ne $adapterResult) { [string]$adapterResult.thread_id } else { "" }
    turn_id = if ($null -ne $adapterResult) { [string]$adapterResult.turn_id } else { "" }
    tests = if ($null -ne $adapterResult) { @($inputDocument.durable_mission.required_tests | ForEach-Object { [pscustomobject]@{test_id=[string]$_.test_id;status=if([bool]$adapterResult.success){'PASS'}else{'FAIL'};observed='Bound app-server automatic round trip';evidence=[string]$adapterResult.event_journal_sha256} }) } else { @() }
    approval_use = @()
}
Write-TsfKernelJson -Value $workerResult -Path $workerResultPath

if ($ManageQueueTransitions -and $rolePreflightApproved -and ($RunApprovedFixtureWorker -or $RunCanonicalAppServerWorker)) { Move-LifecycleQueueState -From 'worker_running' -To 'postrun_pending' }

if ([bool]$preflight.preflight_approved -and ($RunApprovedFixtureWorker -or $RunCanonicalAppServerWorker)) {
    $verifier = Invoke-TsfKernelPostRunVerify -MissionPath $effectiveMissionPath -WorkerResultPath $workerResultPath -OutFile $verifierPath -StateRoot $StateRoot
    $events.Add((New-LifecycleEvent -Step "postrun_verify" -Status ([string]$verifier.verdict) -Message "Post-run verifier completed." -Evidence $verifierPath)) | Out-Null
}

$exactNextAction = if ($RunApprovedFixtureWorker -or $RunCanonicalAppServerWorker) {
    "Review fixture lifecycle output. Commit only if verifier is GREEN and touched files are expected."
} else {
    "Dry-run lifecycle complete. Run with -RunApprovedFixtureWorker only for the approved fixture pilot."
}
$preservation = Write-TsfKernelPreservationPacket -MissionPath $effectiveMissionPath -PreflightResultPath $preflightPath -RolePreflightPath $(if($requiresRolePreflight){$rolePreflightPath}else{''}) -WorkerInstructionPath $workerInstructionPath -WorkerResultPath $workerResultPath -VerifierResultPath $verifierPath -AdapterResultPath $(if($null-ne$adapterResult){$adapterResultPath}else{''}) -EventJournalPath $(if($null-ne$adapterResult){$adapterEventPath}else{''}) -OutputDirectory $preservationRoot -RunId $runId -DurableMission $(if(Test-LifecycleProperty -Value $inputDocument -Name 'durable_mission'){$inputDocument.durable_mission}else{$null}) -ExactNextAction $exactNextAction
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
    effective_mission_path = (Get-TsfKernelFullPath -Path $effectiveMissionPath)
    approval_ledger_path = if ([string]::IsNullOrWhiteSpace($ApprovalLedgerPath)) { "" } else { Get-TsfKernelFullPath -Path $ApprovalLedgerPath }
    out_directory = (Get-TsfKernelFullPath -Path $OutDirectory)
    final_decision = $finalDecision
    preflight_verdict = [string]$preflight.verdict
    preflight_approved = [bool]$preflight.preflight_approved
    role_preflight_required = $requiresRolePreflight
    role_preflight_verdict = $rolePreflightVerdict
    role_preflight_approved = $rolePreflightApproved
    role_preflight_path = if ($requiresRolePreflight) { $rolePreflightPath } else { "" }
    worker_status = $workerStatus
    codex_cli_detected = $codexCliDetected
    codex_cli_invoked = $codexCliInvoked
    codex_exit_code = $codexExitCode
    worker_result_path = $workerResultPath
    verifier_verdict = if ($null -ne $verifier) { [string]$verifier.verdict } else { "" }
    preservation_packet_path = [string]$preservation.packet_directory
    preservation_packet_file = [string]$preservation.packet_file
    preservation_manifest_path = [string]$preservation.manifest_path
    runtime_storage_run_id = $runId
    runtime_path_maximum = [int]$completePathPlan.maximum_path_length
    runtime_path_target_met = [bool]$completePathPlan.target_met
    adapter_result_path = if ($null -ne $adapterResult) { $adapterResultPath } else { "" }
    app_server_event_journal_path = if ($null -ne $adapterResult) { $adapterEventPath } else { "" }
    queue_mission_path = $script:currentQueueMissionPath
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
