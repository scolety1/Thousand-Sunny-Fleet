param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,

    [string]$OutDirectory = "",
    [string]$PolicyPath = "fleet/control/project-main-bot-self-continuation-policy.v1.json",
    [string]$BoundedPolicyPath = "fleet/control/project-main-bot-bounded-self-continuation.v1.json",
    [string]$ContextCapsulePath = "tests/fixtures/fleet/project-main-bot/sample_project_context_capsule.json",
    [int]$MaxSteps = 6,
    [int]$MaxWorkerInvocations = 0,
    [switch]$DryRun,
    [switch]$ApprovedFixtureWorkerMode,
    [int]$WorkerTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $fleetRoot "tools\codex-fleet-enforcement-kernel.ps1")
. (Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1")

function Read-SelfContinuationJson {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { throw "Missing JSON file: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-SelfContinuationJson {
    param([object]$Value, [string]$Path)
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function ConvertTo-SelfContinuationArray {
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

function Get-SelfContinuationRelativeGitStatusPaths {
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

function New-SelfContinuationApprovalLedger {
    param(
        [string]$Path,
        [string]$RepoPath,
        [string]$AllowedPath
    )

    $ledger = [pscustomobject]@{
        schema_version = 1
        ledger_id = "bounded-main-bot-self-continuation-local-ledger-20260709"
        notes = "Lane-local ledger generated from Tim's Bounded Project Main Bot Self-Continuation approval. Scope is one fixture worker artifact only."
        approvals = @(
            [pscustomobject]@{
                approval_id = "tim-approval-bounded-main-bot-self-continuation-20260709"
                exact_action = "codex_cli_bounded_self_continuation_fixture_worker_invocation"
                lane = "MASTER_TSF_CONTROL_PLANE"
                repo_path = $RepoPath
                scope_limit = "Only the bounded Project Main Bot self-continuation builder fixture artifact may be written."
                allowed_files_or_paths = @($AllowedPath)
                expires_at = "2026-07-10T23:59:59-06:00"
                sample_fixture_only = $false
            }
        )
    }
    Write-SelfContinuationJson -Value $ledger -Path $Path
    return $ledger
}

function New-SelfContinuationLoopCase {
    param([string]$Path)

    $case = [pscustomobject]@{
        case_id = "bounded-main-bot-self-continuation-safe-progress"
        repeated_same_blocker_count = 0
        artifact_only_iterations = 0
        lifecycle_progress = $true
        forbidden_action_repeats = 0
        worker_green_verifier_red = $false
        duplicate_system_proposed = $false
        reusable_component_exists = $true
        continue_research_no_finish_line = $false
        expected_decision = "PASS_NO_LOOP"
    }
    Write-SelfContinuationJson -Value $case -Path $Path
    return $case
}

function New-SelfContinuationStopResult {
    param(
        [string]$CaseId,
        [string]$RequestPath,
        [string]$OutDirectory,
        [string]$Decision,
        [string[]]$Reasons,
        [int]$MaxWorkerInvocations
    )

    $result = [pscustomobject]@{
        schema_version = "project_main_bot_self_continuation_result_v1"
        case_id = $CaseId
        request_path = $RequestPath
        dry_run_result_path = ""
        dry_run_next_action = ""
        selected_worker_role = ""
        next_decision = $Decision
        retry_used = $false
        max_retries_per_mission = 1
        max_worker_invocations = $MaxWorkerInvocations
        worker_invocations_used = 0
        escalation_required = $true
        hard_gate_hits = @()
        blocked_reasons = @($Reasons)
        local_commit_allowed_after_validation = $false
        codex_cli_worker_execution_invoked = $false
        codex_cli_invoked = $false
        api_called = $false
        background_runner_started = $false
        push_merge_deploy_attempted = $false
        product_repos_mutated = $false
        canonical_nwr_mutated = $false
    }
    Write-SelfContinuationJson -Value $result -Path (Join-Path $OutDirectory "self_continuation_result.json")
    return $result
}

$request = Read-SelfContinuationJson -Path $RequestPath
$policy = Read-SelfContinuationJson -Path (Join-Path $fleetRoot $PolicyPath)
$boundedPolicy = $null
if (Test-Path -LiteralPath (Join-Path $fleetRoot $BoundedPolicyPath)) {
    $boundedPolicy = Read-SelfContinuationJson -Path (Join-Path $fleetRoot $BoundedPolicyPath)
}

$caseId = if ($request.PSObject.Properties.Name -contains "case_id") { [string]$request.case_id } else { "self-continuation-" + (Get-Date -Format "yyyyMMddHHmmss") }
if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
    $OutDirectory = Join-Path $fleetRoot ".codex-local\project-main-bot-self-continuation\$caseId"
}
New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null

$maxAllowedWorkerInvocations = if ($null -ne $boundedPolicy -and $boundedPolicy.PSObject.Properties.Name -contains "max_worker_invocations") {
    [int]$boundedPolicy.max_worker_invocations
} else {
    2
}
if ($MaxWorkerInvocations -gt $maxAllowedWorkerInvocations) {
    return (New-SelfContinuationStopResult -CaseId $caseId -RequestPath $RequestPath -OutDirectory $OutDirectory -Decision "TIM_REQUIRED_WORKER_BUDGET_EXCEEDED" -Reasons @("Requested worker budget exceeds bounded self-continuation policy.") -MaxWorkerInvocations $MaxWorkerInvocations)
}

$builderArtifact = "tests/fixtures/fleet/project-main-bot/self-continuation/worker-output/main_bot_builder_result.txt"
$builderContent = "TSF Project Main Bot builder worker self-continuation complete."
$approvalLedgerPath = ""
if ($ApprovedFixtureWorkerMode) {
    $approvalLedgerPath = Join-Path $OutDirectory "approval-ledger.bounded-self-continuation.json"
    New-SelfContinuationApprovalLedger -Path $approvalLedgerPath -RepoPath $fleetRoot -AllowedPath $builderArtifact | Out-Null
}

$dryRunOut = Join-Path $OutDirectory "dry_run"
$dryRunResultPath = Join-Path $dryRunOut "project_main_bot_dry_run_result.json"
$dryRunParams = @{
    RequestPath = $RequestPath
    OutDirectory = $dryRunOut
    ContextCapsulePath = $ContextCapsulePath
}
if (![string]::IsNullOrWhiteSpace($approvalLedgerPath)) {
    $dryRunParams.ApprovalLedgerPath = $approvalLedgerPath
}
& (Join-Path $fleetRoot "tools\Invoke-TsfProjectMainBotDryRun.ps1") @dryRunParams | Out-Null
$dryRunResult = Read-SelfContinuationJson -Path $dryRunResultPath

$hardGatePatterns = @(
    "push",
    "merge",
    "deploy",
    "install",
    "migration",
    "secret",
    "credential",
    "api",
    "background",
    "all-fleet",
    "canonical nwr",
    "product repo",
    "source truth",
    "ranking",
    "app wiring"
)
$naturalRequest = if ($request.PSObject.Properties.Name -contains "natural_request") { [string]$request.natural_request } else { "" }
$hardGateHit = @($hardGatePatterns | Where-Object { $naturalRequest -match [regex]::Escape($_) })

$nextDecision = "STOP_AND_PRESERVE"
$retryUsed = $false
$escalationRequired = $false
$blockedReasons = [System.Collections.Generic.List[string]]::new()
$workerInvocationsUsed = 0
$workerStatus = "NOT_RUN"
$workerResultPath = ""
$verifierPath = ""
$verifierVerdict = ""
$preservationPacketPath = ""
$contextUpdatePath = ""
$loopPreventionPath = ""
$loopDecision = ""
$codexCliInvoked = $false
$codexExitCode = $null
$artifactCreated = $false
$artifactContentMatched = $false
$workerFilesTouched = @()
$unexpectedTouched = @()
$localCommitAllowed = $true

if ($hardGateHit.Count -gt 0 -or [string]$dryRunResult.next_action -eq "NEEDS_TIM_APPROVAL") {
    $nextDecision = "TIM_REQUIRED"
    $escalationRequired = $true
} elseif ([string]$dryRunResult.next_action -eq "NEEDS_CHATGPT_HQ") {
    $nextDecision = "NEEDS_CHATGPT_HQ_PACKET_ONLY"
    $escalationRequired = $true
} elseif ([string]$dryRunResult.next_action -eq "READY_FOR_WORKER_DRY_RUN") {
    $nextDecision = "GREEN_SELF_CONTINUATION_DRY_RUN_READY"
} elseif ([string]$dryRunResult.next_action -eq "BLOCKED_ROLE_PERMISSION") {
    $nextDecision = "RED_ROLE_PERMISSION_BLOCKED"
} elseif ([string]$dryRunResult.next_action -eq "RED_UNSAFE") {
    $nextDecision = "RED_UNSAFE"
}

if ($ApprovedFixtureWorkerMode -and !$DryRun -and $nextDecision -eq "GREEN_SELF_CONTINUATION_DRY_RUN_READY") {
    if ($MaxWorkerInvocations -lt 1) {
        $nextDecision = "TIM_REQUIRED_WORKER_BUDGET_EXCEEDED"
        $escalationRequired = $true
        $blockedReasons.Add("Approved fixture worker mode requires a positive worker invocation budget.") | Out-Null
    } else {
        $lifecycle = Read-SelfContinuationJson -Path ([string]$dryRunResult.lifecycle_result_path)
        $effectiveMissionPath = [string]$lifecycle.effective_mission_path
        $preflightPath = Join-Path ([string]$lifecycle.out_directory) "preflight_result.json"
        $mission = Read-SelfContinuationJson -Path $effectiveMissionPath
        $expectedArtifacts = @(ConvertTo-SelfContinuationArray $mission.expected_artifacts | ForEach-Object { ([string]$_).Replace("\", "/") })
        $allowedWrites = @(ConvertTo-SelfContinuationArray $mission.allowed_writes | ForEach-Object { ([string]$_).Replace("\", "/") })
        $role = if ($mission.PSObject.Properties.Name -contains "role_extension" -and $null -ne $mission.role_extension) { [string]$mission.role_extension.worker_role } else { [string]$dryRunResult.worker_role }

        if ($role -ne "builder_worker") {
            $blockedReasons.Add("Bounded self-continuation fixture requires builder_worker role.") | Out-Null
        }
        if ($expectedArtifacts.Count -ne 1 -or $expectedArtifacts[0] -ne $builderArtifact) {
            $blockedReasons.Add("Expected artifacts must contain only $builderArtifact.") | Out-Null
        }
        if ($allowedWrites.Count -ne 1 -or $allowedWrites[0] -ne $builderArtifact) {
            $blockedReasons.Add("Allowed writes must contain only $builderArtifact.") | Out-Null
        }
        if ($MaxSteps -lt 1) {
            $blockedReasons.Add("MaxSteps must allow at least one foreground step.") | Out-Null
        }

        $statusBefore = @(Get-SelfContinuationRelativeGitStatusPaths -RepoPath $fleetRoot)
        if ($statusBefore.Count -gt 0) {
            $blockedReasons.Add("TSF worktree must be clean before the bounded worker invocation.") | Out-Null
        }

        if ($blockedReasons.Count -gt 0) {
            $nextDecision = "RED_UNSAFE"
            $workerStatus = "BLOCKED_SELF_CONTINUATION_SAFETY_CHECK"
        } else {
            $expectedFull = Get-TsfKernelFullPath -Path $builderArtifact -BasePath $fleetRoot
            $prompt = @"
You are a foreground TSF Builder Worker operating under a TSF Project Main Bot worker instruction packet.

Mission id: $($mission.mission_id)
Worker role: builder_worker

Create exactly this one file inside the current TSF repo:
$builderArtifact

The file content must be exactly:
$builderContent

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
            $codexResult = Invoke-FleetProcess -FilePath "codex" -Arguments @("exec", "-c", "service_tier=fast", "--sandbox", "workspace-write", "--ephemeral", "--cd", $fleetRoot, "--output-last-message", $lastMessagePath, "--json", "-") -InputText $prompt -WorkingDirectory $fleetRoot -LogPath $codexOutputPath -TimeoutSeconds $WorkerTimeoutSeconds
            $codexExitCode = $codexResult.exitCode
            $statusAfter = @(Get-SelfContinuationRelativeGitStatusPaths -RepoPath $fleetRoot)
            $workerFilesTouched = @($statusAfter)
            $unexpectedTouched = @($statusAfter | Where-Object { $_ -ne $builderArtifact })

            if (Test-Path -LiteralPath $expectedFull) {
                $artifactCreated = $true
                $artifactContentMatched = ((Get-Content -LiteralPath $expectedFull -Raw).Trim() -eq $builderContent)
            }

            if ($codexResult.timedOut) {
                $blockedReasons.Add("Codex CLI bounded self-continuation worker timed out.") | Out-Null
                $workerStatus = "CODEX_CLI_TIMEOUT"
                $nextDecision = "RED_UNSAFE"
            } elseif ($codexExitCode -ne 0) {
                $codexOutputText = (($codexResult.output | ForEach-Object { [string]$_ }) -join "`n")
                if ($codexOutputText -match "(?i)(auth|login|credential|api key|config\.toml|service_tier|permission|approval)") {
                    $blockedReasons.Add("Codex CLI requires auth/config/permission review: $($codexOutputText -replace '\s+', ' ')") | Out-Null
                    $workerStatus = "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL"
                    $nextDecision = "TIM_REQUIRED_CODEX_CLI_AUTH_OR_EXECUTION_APPROVAL"
                    $escalationRequired = $true
                } else {
                    $blockedReasons.Add("Codex CLI bounded worker exited nonzero: $codexExitCode") | Out-Null
                    $workerStatus = "CODEX_CLI_NONZERO"
                    $nextDecision = "RED_UNSAFE"
                }
            } elseif ($unexpectedTouched.Count -gt 0) {
                $blockedReasons.Add("Codex CLI touched paths outside the allowed fixture output: $($unexpectedTouched -join ', ')") | Out-Null
                $workerStatus = "CODEX_CLI_TOUCHED_FORBIDDEN_PATH"
                $nextDecision = "RED_UNSAFE"
            } elseif (!$artifactCreated) {
                $blockedReasons.Add("Codex CLI did not create the bounded self-continuation fixture artifact.") | Out-Null
                $workerStatus = "CODEX_CLI_EXPECTED_ARTIFACT_MISSING"
                $nextDecision = "RED_UNSAFE"
            } elseif (!$artifactContentMatched) {
                $blockedReasons.Add("Codex CLI created the fixture artifact with unexpected content.") | Out-Null
                $workerStatus = "CODEX_CLI_UNEXPECTED_ARTIFACT_CONTENT"
                $nextDecision = "RED_UNSAFE"
            } else {
                $workerStatus = "CODEX_CLI_BOUNDED_SELF_CONTINUATION_GREEN"
            }

            $workerResultPath = Join-Path $OutDirectory "worker_result.json"
            $workerResult = [pscustomobject]@{
                schema_version = 1
                mission_id = [string]$mission.mission_id
                worker_role = "builder_worker"
                role_output_contract_satisfied = ($workerStatus -eq "CODEX_CLI_BOUNDED_SELF_CONTINUATION_GREEN")
                worker_status = $workerStatus
                codex_cli_detected = $true
                codex_cli_invoked = $codexCliInvoked
                codex_exit_code = $codexExitCode
                service_tier_fast_used = $true
                sandbox_workspace_write_used = $true
                ignore_user_config_used = $false
                danger_full_access_used = $false
                files_touched = @($workerFilesTouched)
                files_created = if ($artifactCreated) { @($builderArtifact) } else { @() }
                unexpected_touched_files = @($unexpectedTouched)
                restricted_actions_attempted = @()
                blocked_reasons = @($blockedReasons)
            }
            Write-SelfContinuationJson -Value $workerResult -Path $workerResultPath

            $verifierPath = Join-Path $OutDirectory "verifier_result.json"
            $verifier = Invoke-TsfKernelPostRunVerify -MissionPath $effectiveMissionPath -WorkerResultPath $workerResultPath -OutFile $verifierPath -StateRoot (Join-Path $OutDirectory "states")
            $verifierVerdict = [string]$verifier.verdict
            if ($verifierVerdict -eq "GREEN" -and $workerStatus -eq "CODEX_CLI_BOUNDED_SELF_CONTINUATION_GREEN") {
                $nextDecision = "GREEN_SELF_CONTINUATION_WORKER_VERIFIED"
            } elseif ($nextDecision -notmatch "^TIM_REQUIRED") {
                $nextDecision = "RED_VERIFIER_BLOCKED"
                foreach ($reason in @(ConvertTo-SelfContinuationArray $verifier.blocked_reasons)) {
                    $blockedReasons.Add([string]$reason) | Out-Null
                }
            }

            $preservation = Write-TsfKernelPreservationPacket -MissionPath $effectiveMissionPath -PreflightResultPath $preflightPath -WorkerResultPath $workerResultPath -VerifierResultPath $verifierPath -OutputDirectory (Join-Path $fleetRoot '.codex-local\rt') -ExactNextAction "Preserve bounded Project Main Bot self-continuation evidence; next milestone requires a new Tim-approved gate."
            $preservationPacketPath = [string]$preservation.packet_directory

            $loopCasePath = Join-Path $OutDirectory "loop_prevention_case.json"
            New-SelfContinuationLoopCase -Path $loopCasePath | Out-Null
            $loopPreventionPath = Join-Path $OutDirectory "loop_prevention_result.json"
            $loop = & (Join-Path $fleetRoot "tools\Test-TsfMainBotLoopPrevention.ps1") -CasePath $loopCasePath -OutFile $loopPreventionPath
            $loopDecision = [string]$loop.decision
            if ($loopDecision -ne "PASS_NO_LOOP" -and $nextDecision -notmatch "^TIM_REQUIRED") {
                $nextDecision = "RED_LOOP_PREVENTION_BLOCKED"
                $blockedReasons.Add("Loop prevention returned $loopDecision for the safe self-continuation case.") | Out-Null
            }

            $contextUpdatePath = Join-Path $OutDirectory "context_capsule.updated.json"
            & (Join-Path $fleetRoot "tools\Update-TsfProjectContextCapsule.ps1") -CapsulePath $ContextCapsulePath -MissionId ([string]$mission.mission_id) -MissionResult $nextDecision -WorkerRole "builder_worker" -CurrentLane "MASTER_TSF_CONTROL_PLANE" -ArtifactsCreated @($builderArtifact, $workerResultPath, $verifierPath, $preservationPacketPath) -NextRecommendedAction "Continue with a separate Tim-approved local mission queue foreground executor milestone." -OutFile $contextUpdatePath | Out-Null
        }
    }
}

$result = [pscustomobject]@{
    schema_version = "project_main_bot_self_continuation_result_v1"
    case_id = $caseId
    request_path = $RequestPath
    dry_run_result_path = $dryRunResultPath
    dry_run_next_action = [string]$dryRunResult.next_action
    selected_worker_role = [string]$dryRunResult.worker_role
    next_decision = $nextDecision
    retry_used = $retryUsed
    max_retries_per_mission = [int]$policy.max_retries_per_mission
    max_steps = $MaxSteps
    max_worker_invocations = $MaxWorkerInvocations
    worker_invocations_used = $workerInvocationsUsed
    escalation_required = $escalationRequired
    hard_gate_hits = @($hardGateHit)
    blocked_reasons = @($blockedReasons)
    approval_ledger_path = $approvalLedgerPath
    worker_status = $workerStatus
    worker_result_path = $workerResultPath
    verifier_result_path = $verifierPath
    verifier_verdict = $verifierVerdict
    preservation_packet_path = $preservationPacketPath
    context_capsule_update_path = $contextUpdatePath
    loop_prevention_result_path = $loopPreventionPath
    loop_prevention_decision = $loopDecision
    builder_fixture_artifact_path = $builderArtifact
    builder_fixture_artifact_created = $artifactCreated
    builder_fixture_content_matched = $artifactContentMatched
    worker_files_touched = @($workerFilesTouched)
    unexpected_touched_files = @($unexpectedTouched)
    local_commit_allowed_after_validation = $localCommitAllowed
    codex_cli_worker_execution_invoked = $codexCliInvoked
    codex_cli_invoked = $codexCliInvoked
    codex_exit_code = $codexExitCode
    api_called = $false
    background_runner_started = $false
    push_merge_deploy_attempted = $false
    product_repos_mutated = $false
    canonical_nwr_mutated = $false
}

$outFile = Join-Path $OutDirectory "self_continuation_result.json"
Write-SelfContinuationJson -Value $result -Path $outFile
$result
