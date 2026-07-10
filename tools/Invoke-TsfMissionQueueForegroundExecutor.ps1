param(
    [Parameter(Mandatory = $true)]
    [string]$MissionPath,

    [string]$QueueRoot = "fleet/missions",
    [string]$PolicyPath = "fleet/control/mission-queue-foreground-executor-policy.v1.json",
    [string]$StatePolicyPath = "fleet/control/mission-queue-state-policy.v1.json",
    [string]$ApprovalLedgerPath = "",
    [string]$ContextCapsulePath = "",
    [string]$OutDirectory = "",
    [string]$OutFile = "",
    [switch]$DryRun,
    [switch]$RunApprovedFixtureWorker,
    [int]$WorkerTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $fleetRoot "tools\codex-fleet-enforcement-kernel.ps1")
. (Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1")

function Read-QueueExecutorJson {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { throw "Missing JSON file: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-QueueExecutorJson {
    param([object]$Value, [string]$Path)
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-QueueExecutorFullPath {
    param([string]$Path, [string]$BasePath = "")
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    if ([string]::IsNullOrWhiteSpace($BasePath)) {
        $BasePath = $fleetRoot
    }
    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function ConvertTo-QueueExecutorArray {
    param([object]$Value)
    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @($Value)
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    }
    return @([string]$Value)
}

function Get-QueueExecutorRelativeGitStatusPaths {
    param([string]$RepoPath)

    $lines = @(& git -C $RepoPath status --short --untracked-files=all 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw ($lines -join "`n")
    }

    $paths = @()
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) { continue }
        $path = $line.Substring(3).Trim()
        if ($path -match " -> ") { $path = ($path -split " -> ")[-1].Trim() }
        $paths += $path.Replace("\", "/")
    }
    return @($paths)
}

function Get-QueueExecutorMissionState {
    param(
        [string]$MissionFullPath,
        [string]$QueueRootFullPath,
        [string[]]$States
    )

    foreach ($state in $States) {
        $stateRoot = [System.IO.Path]::GetFullPath((Join-Path $QueueRootFullPath $state)).TrimEnd('\', '/')
        $mission = [System.IO.Path]::GetFullPath($MissionFullPath)
        if ($mission.StartsWith(($stateRoot + [System.IO.Path]::DirectorySeparatorChar), [System.StringComparison]::OrdinalIgnoreCase)) {
            return $state
        }
    }
    return ""
}

function Add-QueueExecutorEvent {
    param(
        [System.Collections.ArrayList]$Events,
        [string]$Step,
        [string]$Status,
        [string]$Message,
        [string]$Evidence = ""
    )
    $Events.Add([pscustomobject]@{
        step = $Step
        status = $Status
        message = $Message
        evidence = $Evidence
    }) | Out-Null
}

function Invoke-QueueExecutorTransition {
    param(
        [string]$CurrentMissionPath,
        [string]$FromState,
        [string]$ToState,
        [string]$QueueRootPath,
        [string]$OutPath,
        [switch]$DryRunTransition
    )

    $params = @{
        MissionPath = $CurrentMissionPath
        FromState = $FromState
        ToState = $ToState
        QueueRoot = $QueueRootPath
        OutFile = $OutPath
    }
    if ($DryRunTransition) { $params.DryRun = $true }
    $transition = & (Join-Path $fleetRoot "tools\Move-TsfMissionState.ps1") @params
    if ([string]$transition.verdict -ne "GREEN") {
        throw "Queue transition failed: $FromState -> $ToState :: $($transition.blocked_reasons -join '; ')"
    }
    return $transition
}

function Test-QueueExecutorFixtureMission {
    param(
        [object]$Mission,
        [object]$Preflight,
        [object]$RolePreflight,
        [object]$Policy
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $role = ""
    if ($Mission.PSObject.Properties.Name -contains "role_extension" -and $null -ne $Mission.role_extension) {
        $role = [string]$Mission.role_extension.worker_role
    }
    $allowedRoles = @(ConvertTo-QueueExecutorArray $Policy.allowed_fixture_worker_roles)
    if ($allowedRoles -notcontains $role) {
        $reasons.Add("Worker role is not approved for queue fixture execution: $role") | Out-Null
    }

    $expectedArtifacts = @(ConvertTo-QueueExecutorArray $Mission.expected_artifacts | ForEach-Object { ([string]$_).Replace("\", "/") })
    $allowedWrites = @(ConvertTo-QueueExecutorArray $Mission.allowed_writes | ForEach-Object { ([string]$_).Replace("\", "/") })
    if ($expectedArtifacts.Count -ne 1) {
        $reasons.Add("Queue fixture mission must have exactly one expected artifact.") | Out-Null
    }
    if ($allowedWrites.Count -ne 1) {
        $reasons.Add("Queue fixture mission must have exactly one allowed write path.") | Out-Null
    }
    if ($expectedArtifacts.Count -eq 1 -and $allowedWrites.Count -eq 1 -and $expectedArtifacts[0] -ne $allowedWrites[0]) {
        $reasons.Add("Expected artifact and allowed write path must match exactly.") | Out-Null
    }

    $artifact = if ($expectedArtifacts.Count -eq 1) { $expectedArtifacts[0] } else { "" }
    $allowedRoot = ([string]$Policy.allowed_fixture_output_root).Replace("\", "/").TrimEnd("/")
    if ([string]::IsNullOrWhiteSpace($artifact) -or !$artifact.StartsWith(($allowedRoot + "/"), [System.StringComparison]::OrdinalIgnoreCase)) {
        $reasons.Add("Expected artifact must stay under $allowedRoot.") | Out-Null
    }

    $fixture = $Mission.queue_executor_fixture
    if ($null -eq $fixture -or [string]::IsNullOrWhiteSpace([string]$fixture.expected_content)) {
        $reasons.Add("Queue fixture mission must include queue_executor_fixture.expected_content.") | Out-Null
    }

    $requirements = @(Get-TsfKernelApprovalRequirements -Mission $Mission | Where-Object { [string]$_.exact_action -eq [string]$Policy.required_exact_action })
    if ($requirements.Count -ne 1) {
        $reasons.Add("Queue fixture mission must require exact action $($Policy.required_exact_action).") | Out-Null
    }
    $approvalMatches = @(ConvertTo-TsfKernelArray -Value $Preflight.approval_matches | Where-Object { [string]$_.exact_action -eq [string]$Policy.required_exact_action -and [bool]$_.satisfied })
    if ($approvalMatches.Count -ne 1) {
        $reasons.Add("Queue fixture exact approval was not satisfied by kernel preflight.") | Out-Null
    }
    if ($null -eq $RolePreflight -or ![bool]$RolePreflight.role_preflight_approved) {
        $reasons.Add("Role-aware preflight did not approve the queue fixture mission.") | Out-Null
    }

    return @($reasons)
}

$policy = Read-QueueExecutorJson -Path (Get-QueueExecutorFullPath -Path $PolicyPath)
$statePolicy = Read-QueueExecutorJson -Path (Get-QueueExecutorFullPath -Path $StatePolicyPath)
$queueRootFull = Get-QueueExecutorFullPath -Path $QueueRoot
$missionFull = Get-QueueExecutorFullPath -Path $MissionPath
if (!(Test-Path -LiteralPath $missionFull)) { throw "Mission file not found: $missionFull" }

$missionInput = Read-QueueExecutorJson -Path $missionFull
$mission = if ($missionInput.PSObject.Properties.Name -contains "mission_packet") { $missionInput.mission_packet } else { $missionInput }
$missionId = [string]$mission.mission_id
if ([string]::IsNullOrWhiteSpace($missionId)) { $missionId = "queue-mission-" + (Get-Date -Format "yyyyMMddHHmmss") }

if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
    $safeMissionId = $missionId -replace "[^A-Za-z0-9._:-]", "_"
    $OutDirectory = Join-Path $fleetRoot ".codex-local\mission-queue-foreground-executor\$safeMissionId"
}
if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = Join-Path $OutDirectory "queue_executor_result.json"
}
New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null

$originalQueueRootFull = $queueRootFull
$originalMissionFull = $missionFull
$queueRootForTransitions = $QueueRoot

if ($DryRun) {
    $originalState = Get-QueueExecutorMissionState -MissionFullPath $originalMissionFull -QueueRootFullPath $originalQueueRootFull -States @($statePolicy.states)
    if ([string]::IsNullOrWhiteSpace($originalState)) {
        throw "Mission path is not inside a known queue state folder."
    }
    $simulationQueueRoot = Join-Path $OutDirectory "dry_run_queue"
    foreach ($state in @($statePolicy.states)) {
        New-Item -ItemType Directory -Force -Path (Join-Path $simulationQueueRoot ([string]$state)) | Out-Null
    }
    $simMission = Join-Path (Join-Path $simulationQueueRoot $originalState) ([System.IO.Path]::GetFileName($originalMissionFull))
    Copy-Item -LiteralPath $originalMissionFull -Destination $simMission -Force
    $queueRootFull = [System.IO.Path]::GetFullPath($simulationQueueRoot)
    $queueRootForTransitions = $queueRootFull
    $missionFull = [System.IO.Path]::GetFullPath($simMission)
}

foreach ($state in @($statePolicy.states)) {
    New-Item -ItemType Directory -Force -Path (Join-Path $queueRootFull ([string]$state)) | Out-Null
}

$events = New-Object System.Collections.ArrayList
$blockedReasons = [System.Collections.Generic.List[string]]::new()
$workerInvocationsUsed = 0
$codexCliInvoked = $false
$codexExitCode = $null
$workerStatus = "NOT_RUN"
$workerResultPath = Join-Path $OutDirectory "worker_result.json"
$verifierPath = Join-Path $OutDirectory "verifier_result.json"
$preflightPath = Join-Path $OutDirectory "preflight_result.json"
$rolePreflightPath = Join-Path $OutDirectory "role_permission_preflight.json"
$workerInstructionPath = Join-Path $OutDirectory "worker_instruction.json"
$contextUpdatePath = ""
$preservationPacketPath = ""
$finalDecision = "RED_QUEUE_EXECUTOR_BLOCKED"
$finalState = ""
$currentMissionPath = $missionFull
$currentState = Get-QueueExecutorMissionState -MissionFullPath $currentMissionPath -QueueRootFullPath $queueRootFull -States @($statePolicy.states)
$startState = $currentState

try {
    if ([string]::IsNullOrWhiteSpace($currentState)) {
        throw "Mission path is not inside a known queue state folder."
    }
    if (@("inbox", "drafted") -notcontains $currentState) {
        throw "Queue executor only starts from inbox or drafted in V1; current state is $currentState."
    }
    Add-QueueExecutorEvent -Events $events -Step "queue_start" -Status "PASS" -Message "Mission accepted from queue state $currentState." -Evidence $currentMissionPath

    if ($currentState -eq "inbox") {
        $transitionPath = Join-Path $OutDirectory "transition_inbox_to_drafted.json"
        $transition = Invoke-QueueExecutorTransition -CurrentMissionPath $currentMissionPath -FromState "inbox" -ToState "drafted" -QueueRootPath $queueRootForTransitions -OutPath $transitionPath -DryRunTransition:$false
        Add-QueueExecutorEvent -Events $events -Step "transition" -Status "PASS" -Message "inbox -> drafted" -Evidence $transitionPath
        $currentMissionPath = [string]$transition.destination_path
        $currentState = "drafted"
    }

    $transitionPath = Join-Path $OutDirectory "transition_drafted_to_preflight_pending.json"
    $transition = Invoke-QueueExecutorTransition -CurrentMissionPath $currentMissionPath -FromState "drafted" -ToState "preflight_pending" -QueueRootPath $queueRootForTransitions -OutPath $transitionPath -DryRunTransition:$false
    Add-QueueExecutorEvent -Events $events -Step "transition" -Status "PASS" -Message "drafted -> preflight_pending" -Evidence $transitionPath
    $currentMissionPath = [string]$transition.destination_path
    $currentState = "preflight_pending"

    $preflight = Invoke-TsfKernelPreflight -MissionPath $currentMissionPath -ApprovalLedgerPath $ApprovalLedgerPath -OutFile $preflightPath -StateRoot (Join-Path $OutDirectory "kernel_states")
    Add-QueueExecutorEvent -Events $events -Step "kernel_preflight" -Status ([string]$preflight.verdict) -Message "Kernel preflight completed." -Evidence $preflightPath

    if (![bool]$preflight.preflight_approved) {
        foreach ($reason in @(ConvertTo-TsfKernelArray -Value $preflight.blocked_reasons)) { $blockedReasons.Add([string]$reason) | Out-Null }
        foreach ($reason in @(ConvertTo-TsfKernelArray -Value $preflight.tim_required_reasons)) { $blockedReasons.Add([string]$reason) | Out-Null }
        $transitionPath = Join-Path $OutDirectory "transition_preflight_pending_to_blocked_needs_tim.json"
        $transition = Invoke-QueueExecutorTransition -CurrentMissionPath $currentMissionPath -FromState "preflight_pending" -ToState "blocked_needs_tim" -QueueRootPath $queueRootForTransitions -OutPath $transitionPath -DryRunTransition:$false
        $currentMissionPath = [string]$transition.destination_path
        $finalState = "blocked_needs_tim"
        $finalDecision = if ([string]$preflight.verdict -eq "TIM_REQUIRED") { "TIM_REQUIRED_QUEUE_PREFLIGHT_BLOCKED" } else { "RED_QUEUE_PREFLIGHT_BLOCKED" }
    } else {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "tools\Test-TsfWorkerRolePermission.ps1") -MissionDraftPath $currentMissionPath -OutFile $rolePreflightPath | Out-Null
        $rolePreflight = Read-QueueExecutorJson -Path $rolePreflightPath
        Add-QueueExecutorEvent -Events $events -Step "role_preflight" -Status ([string]$rolePreflight.verdict) -Message "Role-aware permission preflight completed." -Evidence $rolePreflightPath
        if (![bool]$rolePreflight.role_preflight_approved) {
            foreach ($reason in @(ConvertTo-TsfKernelArray -Value $rolePreflight.blocked_reasons)) { $blockedReasons.Add([string]$reason) | Out-Null }
            foreach ($reason in @(ConvertTo-TsfKernelArray -Value $rolePreflight.tim_required_reasons)) { $blockedReasons.Add([string]$reason) | Out-Null }
            $transitionPath = Join-Path $OutDirectory "transition_preflight_pending_to_blocked_needs_tim.json"
            $transition = Invoke-QueueExecutorTransition -CurrentMissionPath $currentMissionPath -FromState "preflight_pending" -ToState "blocked_needs_tim" -QueueRootPath $queueRootForTransitions -OutPath $transitionPath -DryRunTransition:$false
            $currentMissionPath = [string]$transition.destination_path
            $finalState = "blocked_needs_tim"
            $finalDecision = if ([string]$rolePreflight.verdict -eq "TIM_REQUIRED") { "TIM_REQUIRED_QUEUE_ROLE_BLOCKED" } else { "RED_QUEUE_ROLE_BLOCKED" }
        } else {
            $transitionPath = Join-Path $OutDirectory "transition_preflight_pending_to_approved_for_worker.json"
            $transition = Invoke-QueueExecutorTransition -CurrentMissionPath $currentMissionPath -FromState "preflight_pending" -ToState "approved_for_worker" -QueueRootPath $queueRootForTransitions -OutPath $transitionPath -DryRunTransition:$false
            Add-QueueExecutorEvent -Events $events -Step "transition" -Status "PASS" -Message "preflight_pending -> approved_for_worker" -Evidence $transitionPath
            $currentMissionPath = [string]$transition.destination_path
            $currentState = "approved_for_worker"

            $workerInstruction = New-TsfKernelWorkerInstruction -MissionPath $currentMissionPath -PreflightResultPath $preflightPath -OutFile $workerInstructionPath -StateRoot (Join-Path $OutDirectory "kernel_states")
            Add-QueueExecutorEvent -Events $events -Step "worker_instruction" -Status ([string]$workerInstruction.adapter_status) -Message "Worker instruction generated." -Evidence $workerInstructionPath

            if (!$RunApprovedFixtureWorker -or $DryRun) {
                $workerStatus = if ($RunApprovedFixtureWorker -and $DryRun) { "DRY_RUN_APPROVED_FIXTURE_WORKER_NOT_INVOKED" } else { "DRY_RUN_NO_WORKER" }
                $workerResult = [pscustomobject]@{
                    schema_version = 1
                    mission_id = $missionId
                    worker_role = if ($mission.PSObject.Properties.Name -contains "role_extension") { [string]$mission.role_extension.worker_role } else { "" }
                    role_output_contract_satisfied = $false
                    worker_status = $workerStatus
                    codex_cli_invoked = $false
                    codex_exit_code = $null
                    files_touched = @()
                    files_created = @()
                    unexpected_touched_files = @()
                    restricted_actions_attempted = @()
                    blocked_reasons = @()
                }
                Write-QueueExecutorJson -Value $workerResult -Path $workerResultPath
                $finalState = "approved_for_worker"
                $finalDecision = "YELLOW_QUEUE_DRY_RUN_APPROVED"
            } else {
                $fixtureErrors = @(Test-QueueExecutorFixtureMission -Mission $mission -Preflight $preflight -RolePreflight $rolePreflight -Policy $policy)
                if ($fixtureErrors.Count -gt 0) {
                    foreach ($reason in $fixtureErrors) { $blockedReasons.Add($reason) | Out-Null }
                    $workerStatus = "BLOCKED_QUEUE_FIXTURE_SAFETY_CHECK"
                    $finalDecision = "RED_QUEUE_FIXTURE_SAFETY_BLOCKED"
                    $finalState = "blocked_needs_tim"
                    $transitionPath = Join-Path $OutDirectory "transition_approved_for_worker_to_worker_running.blocked.json"
                } else {
                    $transitionPath = Join-Path $OutDirectory "transition_approved_for_worker_to_worker_running.json"
                    $transition = Invoke-QueueExecutorTransition -CurrentMissionPath $currentMissionPath -FromState "approved_for_worker" -ToState "worker_running" -QueueRootPath $QueueRoot -OutPath $transitionPath -DryRunTransition:$false
                    Add-QueueExecutorEvent -Events $events -Step "transition" -Status "PASS" -Message "approved_for_worker -> worker_running" -Evidence $transitionPath
                    $currentMissionPath = [string]$transition.destination_path
                    $currentState = "worker_running"

                    $repoPath = Get-TsfKernelFullPath -Path ([string]$mission.repo_path)
                    $expectedArtifact = ([string]$mission.expected_artifacts[0]).Replace("\", "/")
                    $expectedContent = [string]$mission.queue_executor_fixture.expected_content
                    $expectedFull = Get-TsfKernelFullPath -Path $expectedArtifact -BasePath $repoPath
                    $statusBefore = @(Get-QueueExecutorRelativeGitStatusPaths -RepoPath $repoPath)
                    $prompt = @"
You are a foreground TSF queue fixture worker.

Mission id: $missionId
Worker role: $($mission.role_extension.worker_role)

Create exactly this one file inside the current TSF repo:
$expectedArtifact

The file content must be exactly:
$expectedContent

Do not touch any other file.
Do not inspect product repos.
Do not inspect C:\NWR\Niners-War-Room.
Do not read normal NWR packets.
Do not push, merge, deploy, install packages, run migrations, access secrets, use PrivateLens, run all-fleet, start background processes, open network ports, call APIs, change app wiring, rankings, formulas, source truth, recommendations, or hidden sort.
Return a concise status after the file is written.
"@
                    $lastMessagePath = Join-Path $OutDirectory "codex_worker_last_message.txt"
                    $codexOutputPath = Join-Path $OutDirectory "codex_worker_events.jsonl"
                    $codexCliInvoked = $true
                    $workerInvocationsUsed = 1
                    $codexResult = Invoke-FleetProcess -FilePath "codex" -Arguments @("exec", "-c", "service_tier=fast", "--sandbox", "workspace-write", "--ephemeral", "--cd", $repoPath, "--output-last-message", $lastMessagePath, "--json", "-") -InputText $prompt -WorkingDirectory $repoPath -LogPath $codexOutputPath -TimeoutSeconds $WorkerTimeoutSeconds
                    $codexExitCode = $codexResult.exitCode
                    $statusAfter = @(Get-QueueExecutorRelativeGitStatusPaths -RepoPath $repoPath)
                    $newTouched = @($statusAfter | Where-Object { $statusBefore -notcontains $_ })
                    $unexpectedTouched = @($newTouched | Where-Object { $_ -ne $expectedArtifact })
                    $artifactCreated = Test-Path -LiteralPath $expectedFull
                    $artifactContentMatched = $false
                    if ($artifactCreated) {
                        $artifactContentMatched = ((Get-Content -LiteralPath $expectedFull -Raw).Trim() -eq $expectedContent)
                    }

                    if ($codexResult.timedOut) {
                        $workerStatus = "CODEX_CLI_TIMEOUT"
                        $blockedReasons.Add("Codex CLI queue fixture worker timed out.") | Out-Null
                    } elseif ($codexExitCode -ne 0) {
                        $codexOutputText = (($codexResult.output | ForEach-Object { [string]$_ }) -join "`n")
                        if ($codexOutputText -match "(?i)(auth|login|credential|api key|config\.toml|service_tier|permission|approval)") {
                            $workerStatus = "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL"
                            $blockedReasons.Add("Codex CLI requires auth/config/permission review: $($codexOutputText -replace '\s+', ' ')") | Out-Null
                        } else {
                            $workerStatus = "CODEX_CLI_NONZERO"
                            $blockedReasons.Add("Codex CLI queue fixture worker exited nonzero: $codexExitCode") | Out-Null
                        }
                    } elseif ($unexpectedTouched.Count -gt 0) {
                        $workerStatus = "CODEX_CLI_TOUCHED_FORBIDDEN_PATH"
                        $blockedReasons.Add("Codex CLI touched paths outside the allowed fixture output: $($unexpectedTouched -join ', ')") | Out-Null
                    } elseif (!$artifactCreated) {
                        $workerStatus = "CODEX_CLI_EXPECTED_ARTIFACT_MISSING"
                        $blockedReasons.Add("Codex CLI did not create expected fixture artifact.") | Out-Null
                    } elseif (!$artifactContentMatched) {
                        $workerStatus = "CODEX_CLI_UNEXPECTED_ARTIFACT_CONTENT"
                        $blockedReasons.Add("Codex CLI created artifact with unexpected content.") | Out-Null
                    } else {
                        $workerStatus = "CODEX_CLI_QUEUE_FIXTURE_GREEN"
                    }

                    $workerResult = [pscustomobject]@{
                        schema_version = 1
                        mission_id = $missionId
                        worker_role = [string]$mission.role_extension.worker_role
                        role_output_contract_satisfied = ($workerStatus -eq "CODEX_CLI_QUEUE_FIXTURE_GREEN")
                        worker_status = $workerStatus
                        codex_cli_invoked = $codexCliInvoked
                        codex_exit_code = $codexExitCode
                        service_tier_fast_used = $true
                        sandbox_workspace_write_used = $true
                        ignore_user_config_used = $false
                        danger_full_access_used = $false
                        files_touched = @($newTouched)
                        files_created = if ($artifactCreated) { @($expectedArtifact) } else { @() }
                        unexpected_touched_files = @($unexpectedTouched)
                        restricted_actions_attempted = @()
                        blocked_reasons = @($blockedReasons)
                    }
                    Write-QueueExecutorJson -Value $workerResult -Path $workerResultPath

                    $transitionPath = Join-Path $OutDirectory "transition_worker_running_to_postrun_pending.json"
                    $transition = Invoke-QueueExecutorTransition -CurrentMissionPath $currentMissionPath -FromState "worker_running" -ToState "postrun_pending" -QueueRootPath $QueueRoot -OutPath $transitionPath -DryRunTransition:$false
                    Add-QueueExecutorEvent -Events $events -Step "transition" -Status "PASS" -Message "worker_running -> postrun_pending" -Evidence $transitionPath
                    $currentMissionPath = [string]$transition.destination_path
                    $currentState = "postrun_pending"

                    $verifier = Invoke-TsfKernelPostRunVerify -MissionPath $currentMissionPath -WorkerResultPath $workerResultPath -OutFile $verifierPath -StateRoot (Join-Path $OutDirectory "kernel_states")
                    Add-QueueExecutorEvent -Events $events -Step "postrun_verify" -Status ([string]$verifier.verdict) -Message "Post-run verifier completed." -Evidence $verifierPath

                    if ([string]$workerStatus -eq "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL") {
                        $finalDecision = "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL"
                        $finalState = "blocked_needs_tim"
                    } elseif ([string]$workerStatus -eq "CODEX_CLI_QUEUE_FIXTURE_GREEN" -and [string]$verifier.verdict -eq "GREEN") {
                        $finalDecision = "GREEN_QUEUE_WORKER_VERIFIED"
                        $finalState = if ($mission.PSObject.Properties.Name -contains "queue_final_state" -and ![string]::IsNullOrWhiteSpace([string]$mission.queue_final_state)) { [string]$mission.queue_final_state } else { "complete_review_only" }
                    } else {
                        $finalDecision = "RED_QUEUE_VERIFIER_BLOCKED"
                        $finalState = "blocked_needs_tim"
                    }

                    $transitionPath = Join-Path $OutDirectory ("transition_postrun_pending_to_$finalState.json")
                    Invoke-QueueExecutorTransition -CurrentMissionPath $currentMissionPath -FromState "postrun_pending" -ToState $finalState -QueueRootPath $QueueRoot -OutPath $transitionPath -DryRunTransition:$false | Out-Null
                    Add-QueueExecutorEvent -Events $events -Step "transition" -Status "PASS" -Message "postrun_pending -> $finalState" -Evidence $transitionPath
                }
            }
        }
    }

    if (!(Test-Path -LiteralPath $workerResultPath)) {
        $workerResult = [pscustomobject]@{
            schema_version = 1
            mission_id = $missionId
            worker_role = if ($mission.PSObject.Properties.Name -contains "role_extension") { [string]$mission.role_extension.worker_role } else { "" }
            role_output_contract_satisfied = $false
            worker_status = $workerStatus
            codex_cli_invoked = $false
            codex_exit_code = $null
            files_touched = @()
            files_created = @()
            unexpected_touched_files = @()
            restricted_actions_attempted = @()
            blocked_reasons = @($blockedReasons)
        }
        Write-QueueExecutorJson -Value $workerResult -Path $workerResultPath
    }

    if (Test-Path -LiteralPath $preflightPath) {
        $preservation = Write-TsfKernelPreservationPacket -MissionPath $currentMissionPath -PreflightResultPath $preflightPath -WorkerResultPath $workerResultPath -VerifierResultPath $verifierPath -OutputDirectory (Join-Path $OutDirectory "preservation") -ExactNextAction "Review queue executor result; continue only through a new TSF gate."
        $preservationPacketPath = [string]$preservation.packet_directory
        Add-QueueExecutorEvent -Events $events -Step "preserve" -Status ([string]$preservation.final_decision) -Message "Preservation packet written." -Evidence $preservationPacketPath
    }

    if (![string]::IsNullOrWhiteSpace($ContextCapsulePath) -and (Test-Path -LiteralPath (Join-Path $fleetRoot "tools\Update-TsfProjectContextCapsule.ps1"))) {
        $contextUpdatePath = Join-Path $OutDirectory "context_capsule.updated.json"
        & (Join-Path $fleetRoot "tools\Update-TsfProjectContextCapsule.ps1") -CapsulePath $ContextCapsulePath -MissionId $missionId -MissionResult $finalDecision -WorkerRole ([string]$mission.role_extension.worker_role) -CurrentLane "MASTER_TSF_CONTROL_PLANE" -ArtifactsCreated @($workerResultPath, $verifierPath, $preservationPacketPath) -NextRecommendedAction "Review queue executor result and continue only through an approved TSF gate." -OutFile $contextUpdatePath | Out-Null
    }
} catch {
    $blockedReasons.Add($_.Exception.Message) | Out-Null
    Add-QueueExecutorEvent -Events $events -Step "exception" -Status "FAIL" -Message $_.Exception.Message
    $finalDecision = "RED_QUEUE_EXECUTOR_BLOCKED"
}

$result = [pscustomobject]@{
    schema_version = "mission_queue_foreground_executor_result_v1"
    generated_at = (Get-Date).ToString("o")
    mission_id = $missionId
    mission_path = $missionFull
    original_mission_path = $originalMissionFull
    queue_root = $originalQueueRootFull
    effective_queue_root = $queueRootFull
    start_state = $startState
    final_state = $finalState
    final_decision = $finalDecision
    dry_run = [bool]$DryRun
    run_approved_fixture_worker = [bool]$RunApprovedFixtureWorker
    worker_invocations_used = $workerInvocationsUsed
    worker_status = $workerStatus
    codex_cli_worker_execution_invoked = $codexCliInvoked
    codex_exit_code = $codexExitCode
    preflight_result_path = $preflightPath
    role_preflight_result_path = $rolePreflightPath
    worker_instruction_path = $workerInstructionPath
    worker_result_path = $workerResultPath
    verifier_result_path = if (Test-Path -LiteralPath $verifierPath) { $verifierPath } else { "" }
    preservation_packet_path = $preservationPacketPath
    context_capsule_update_path = $contextUpdatePath
    blocked_reasons = @($blockedReasons)
    events = @($events)
    background_runner_started = $false
    all_fleet_started = $false
    api_called = $false
    push_performed = $false
    merge_performed = $false
    product_repos_mutated = $false
    canonical_nwr_mutated = $false
}

Write-QueueExecutorJson -Value $result -Path $OutFile
$result

if ($finalDecision -like "RED_*" -or $finalDecision -like "TIM_REQUIRED*") {
    exit 1
}
exit 0
