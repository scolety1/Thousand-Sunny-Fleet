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

    [string]$CanonicalQueueDocumentEvidencePath = "",

    [switch]$TestOnlyAllowAlternateQueueRoot,

    [string]$RuntimeRoot = "",

    [int]$WorkerTimeoutSeconds = 180,

    [ValidateSet('NONE','GREEN','PREFLIGHT','ROLE_PERMISSION','WORKER_START','VERIFIER','PRESERVATION')]
    [string]$TestOnlyFault = 'NONE'
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

$lifecycleStage = 'INVOCATION'
$inputDocument = $null
$mission = $null
$missionId = ''
$missionRevision = 1
$runId = ''
$queueDocumentHash = ''
$policyFingerprintForRegistry = ('0' * 64)
$completePathPlan = $null
$producerRegistryPath = ''
$producerCapability = $null
$repoPathForRegistry = $fleetRoot
$gitForRegistry = $null
$events = [System.Collections.Generic.List[object]]::new()
$blockedReasons = [System.Collections.Generic.List[string]]::new()
$preflight = $null
$rolePreflight = $null
$verifier = $null
$preservation = $null
$workerStatus = 'NOT_RUN'
$adapterResult = $null
$effectiveMissionPath = ''
$workerResultPath = ''
$verifierPath = ''
$script:currentQueueMissionPath = $QueueMissionPath

try {
$lifecycleStage = 'MISSION_BINDING'
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
$canonicalRuntimeRoot=Get-TsfCanonicalRuntimeRoot
if ([string]::IsNullOrWhiteSpace($RuntimeRoot)) { $RuntimeRoot = $canonicalRuntimeRoot }
$RuntimeRoot=Assert-TsfCanonicalRuntimeRoot $RuntimeRoot
$completePathPlan=New-TsfCompleteRuntimePathPlan -MissionId $missionId -MissionRevision $missionRevision -RunId $runId
if (!$completePathPlan.budget.valid) { throw "Lifecycle runtime artifact path preflight failed before mutation: $($completePathPlan.budget.errors -join '; ')" }
$adapterStoragePlan=$completePathPlan.adapter_plan
$preservationStoragePlan=$completePathPlan.preservation_plan
$lifecycleStoragePlan=$completePathPlan.lifecycle_plan
$queueStoragePlan=$completePathPlan.queue_plan
$queueAuthority=Resolve-TsfQueueAuthority -QueueRoot $QueueRoot -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
$artifactCatalog=Get-TsfRuntimeArtifactCatalog
$expectedOutDirectory=[string]$lifecycleStoragePlan.directory
if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
    $OutDirectory = $expectedOutDirectory
} elseif(![string]::Equals((Get-TsfKernelFullPath $OutDirectory),$expectedOutDirectory,[StringComparison]::OrdinalIgnoreCase)) {
    throw 'NONCANONICAL_LIFECYCLE_OUTPUT_REJECTED'
}
if ([string]::IsNullOrWhiteSpace($StateRoot)) {
    $StateRoot = Join-Path $OutDirectory 's'
} elseif(!(Test-TsfKernelPathInside (Get-TsfKernelFullPath $StateRoot) $OutDirectory)) {
    throw 'NONCANONICAL_LIFECYCLE_STATE_ROOT_REJECTED'
}
if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = Join-Path $OutDirectory $artifactCatalog.lifecycle_result
} elseif(![string]::Equals((Get-TsfKernelFullPath $OutFile),(Get-TsfKernelFullPath (Join-Path $OutDirectory $artifactCatalog.lifecycle_result)),[StringComparison]::OrdinalIgnoreCase)) {
    throw 'NONCANONICAL_LIFECYCLE_RESULT_REJECTED'
}

New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null
$events = [System.Collections.Generic.List[object]]::new()
$effectiveMissionPath = [string]$lifecycleStoragePlan.artifacts.mission
$rolePreflightPath = Join-Path $OutDirectory $artifactCatalog.role_preflight
$workerResultPath = Join-Path $OutDirectory $artifactCatalog.worker_result
$preflightPath = Join-Path $OutDirectory $artifactCatalog.preflight
$workerInstructionPath = Join-Path $OutDirectory $artifactCatalog.worker_instruction
$verifierPath = Join-Path $OutDirectory $artifactCatalog.verifier_result
$preservationRoot = $RuntimeRoot

$repoPathForRegistry=Get-TsfKernelFullPath ([string]$mission.repo_path)
$gitForRegistry=Get-TsfKernelGitState $repoPathForRegistry
$policyFingerprintForRegistry=if(Test-LifecycleProperty $inputDocument 'source_binding'){[string]$inputDocument.source_binding.policy_fingerprint}else{'0'*64}
$queueHashForRegistry=if($queueDocumentHash){$queueDocumentHash}else{'0'*64}
$producerRegistryPath=[string]$lifecycleStoragePlan.artifacts.producer_registry
$producerCapability=New-TsfOrchestratorProducerCapability -InvocationInfo $MyInvocation -MissionId $missionId -MissionRevision $missionRevision -RunId $runId -PolicyFingerprint $policyFingerprintForRegistry -QueueDocumentSha256 $queueHashForRegistry -Repository $repoPathForRegistry -Branch $(if($gitForRegistry.can_capture){[string]$gitForRegistry.branch}else{''}) -Worktree $repoPathForRegistry
New-TsfProducerEvidenceRegistry -RegistryPath $producerRegistryPath -Capability $producerCapability | Out-Null

if([string]$inputDocument.schema_version-eq'tsf_canonical_queue_document_v1'){
    $expectedQueueEvidence=[string]$queueStoragePlan.artifacts.queue_document
    if([string]::IsNullOrWhiteSpace($CanonicalQueueDocumentEvidencePath)){$CanonicalQueueDocumentEvidencePath=$expectedQueueEvidence}
    if(![string]::Equals((Get-TsfKernelFullPath $CanonicalQueueDocumentEvidencePath),(Get-TsfKernelFullPath $expectedQueueEvidence),[StringComparison]::OrdinalIgnoreCase)){throw 'NONCANONICAL_QUEUE_DOCUMENT_EVIDENCE_PATH'}
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $CanonicalQueueDocumentEvidencePath)|Out-Null
    if(!(Test-Path $CanonicalQueueDocumentEvidencePath -PathType Leaf)){Copy-Item -LiteralPath $MissionPath -Destination $CanonicalQueueDocumentEvidencePath}
    $queueEvidenceDocument=Read-TsfKernelJson $CanonicalQueueDocumentEvidencePath
    $queueEvidenceCheck=Test-TsfCanonicalQueueDocument -QueueDocument $queueEvidenceDocument
    if(!$queueEvidenceCheck.valid-or[string]$queueEvidenceCheck.queue_document_sha256-ne$queueDocumentHash){throw 'QUEUE_DOCUMENT_EVIDENCE_HASH_MISMATCH'}
    Register-TsfProducerEvidence $producerRegistryPath queue_document $CanonicalQueueDocumentEvidencePath $producerCapability | Out-Null
}

if (Test-LifecycleProperty -Value $inputDocument -Name "mission_packet") {
    if ($null -ne $roleExtension -and !(Test-LifecycleProperty -Value $mission -Name "role_extension")) {
        $mission | Add-Member -NotePropertyName "role_extension" -NotePropertyValue $roleExtension -Force
    }
    $events.Add((New-LifecycleEvent -Step "mission_normalize" -Status "PASS" -Message "Project Main Bot draft normalized to mission packet for kernel lifecycle." -Evidence $effectiveMissionPath)) | Out-Null
}
Write-TsfKernelJson -Value $mission -Path $effectiveMissionPath
Register-TsfProducerEvidence $producerRegistryPath mission $effectiveMissionPath $producerCapability | Out-Null

$preflight = Invoke-TsfKernelPreflight -MissionPath $effectiveMissionPath -ApprovalLedgerPath $ApprovalLedgerPath -OutFile $preflightPath -StateRoot $StateRoot
$lifecycleStage = 'PREFLIGHT'
if($TestOnlyFault-ne'NONE'){
    if(!$TestOnlyAllowAlternateQueueRoot-or[string]$queueAuthority.kind-ne'TEST_ONLY'){throw 'TEST_ONLY_LIFECYCLE_FAULT_REQUIRES_ISOLATED_QUEUE'}
    if($TestOnlyFault-eq'PREFLIGHT'){$preflight.preflight_approved=$false;$preflight.verdict='RED';$preflight.blocked_reasons=@('TEST_ONLY_PREFLIGHT_BLOCK');Write-TsfKernelJson $preflight $preflightPath}
}
Register-TsfProducerEvidence $producerRegistryPath preflight $preflightPath $producerCapability | Out-Null
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
    $code=switch("$From>$To"){'preflight_pending>approved_for_worker'{'transition_04'}'approved_for_worker>worker_running'{'transition_05'}'worker_running>postrun_pending'{'transition_06'}default{'transition_08'}}
    $transitionPath = [string]$queueStoragePlan.artifacts.$code
    $transition = & (Join-Path $fleetRoot 'tools\Move-TsfMissionState.ps1') -MissionPath $script:currentQueueMissionPath -FromState $From -ToState $To -QueueRoot ([string]$queueAuthority.root) -OutFile $transitionPath -TestOnlyAllowAlternateQueueRoot:$TestOnlyAllowAlternateQueueRoot
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
        if($TestOnlyFault-eq'ROLE_PERMISSION'){$rolePreflightApproved=$false;$rolePreflightVerdict='RED';$rolePreflight.role_preflight_approved=$false;$rolePreflight.verdict='RED';$rolePreflight.blocked_reasons=@('TEST_ONLY_ROLE_PERMISSION_BLOCK');Write-TsfKernelJson $rolePreflight $rolePreflightPath}
        Register-TsfProducerEvidence $producerRegistryPath role_preflight $rolePreflightPath $producerCapability | Out-Null
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
        Register-TsfProducerEvidence $producerRegistryPath worker_instruction $workerInstructionPath $producerCapability | Out-Null
        $events.Add((New-LifecycleEvent -Step "worker_instruction" -Status ([string]$workerInstruction.adapter_status) -Message "Worker instruction generated." -Evidence $workerInstructionPath)) | Out-Null

        if ($TestOnlyFault -eq 'WORKER_START') {
            $blockedReasons.Add('TEST_ONLY_WORKER_START_BLOCK') | Out-Null
            $workerStatus = 'BLOCKED_WORKER_START'
            $events.Add((New-LifecycleEvent -Step 'worker_execution' -Status $workerStatus -Message 'Worker start was deterministically blocked before launch.')) | Out-Null
        } elseif (!$RunApprovedFixtureWorker -and !$RunCanonicalAppServerWorker) {
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
            Register-TsfProducerEvidence $producerRegistryPath prompt $promptPath $producerCapability | Out-Null
            $adapterResult = & (Join-Path $fleetRoot 'tools\Invoke-TsfCodexAppServerForeground.ps1') -MissionId $missionId -MissionRevision $missionRevision -PolicyFingerprint ([string]$inputDocument.source_binding.policy_fingerprint) -QueueDocumentSha256 $queueDocumentHash -Cwd $repoPath -Model ([string]$inputDocument.model_resolution.resolved_model) -ReasoningEffort ([string]$inputDocument.model_resolution.reasoning_effort) -EffortAssurance ([string]$inputDocument.durable_mission.model_selection_assurance) -Sandbox $sandbox -PromptFile $promptPath -OutputDirectory ([string]$adapterStoragePlan.directory) -ResultPath $adapterResultPath -EventJournalPath $adapterEventPath -StderrPath $adapterStderrPath -ExpiresAt ([datetimeoffset]$inputDocument.durable_mission.expires_at) -TimeoutSeconds $WorkerTimeoutSeconds
            Register-TsfProducerEvidence $producerRegistryPath adapter_result $adapterResultPath $producerCapability | Out-Null
            Register-TsfProducerEvidence $producerRegistryPath event_journal $adapterEventPath $producerCapability | Out-Null
            Register-TsfProducerEvidence $producerRegistryPath stderr $adapterStderrPath $producerCapability | Out-Null
            if($null-ne$adapterResult.turn_usage){Write-TsfKernelJson $adapterResult.turn_usage ([string]$lifecycleStoragePlan.artifacts.usage);Register-TsfProducerEvidence $producerRegistryPath usage ([string]$lifecycleStoragePlan.artifacts.usage) $producerCapability|Out-Null}
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
Register-TsfProducerEvidence $producerRegistryPath worker_result $workerResultPath $producerCapability | Out-Null

if ($ManageQueueTransitions -and $rolePreflightApproved -and ($RunApprovedFixtureWorker -or $RunCanonicalAppServerWorker)) { Move-LifecycleQueueState -From 'worker_running' -To 'postrun_pending' }

if ([bool]$preflight.preflight_approved -and ($RunApprovedFixtureWorker -or $RunCanonicalAppServerWorker -or $TestOnlyFault -in @('GREEN','VERIFIER'))) {
    $lifecycleStage = 'VERIFIER'
    if($TestOnlyFault-in@('GREEN','VERIFIER')){
        $verifier=[pscustomobject]@{schema_version=1;mission_id=$missionId;verdict=$(if($TestOnlyFault-eq'GREEN'){'GREEN'}else{'RED'});postrun_approved=($TestOnlyFault-eq'GREEN');blocked_reasons=$(if($TestOnlyFault-eq'GREEN'){@()}else{@('TEST_ONLY_VERIFIER_BLOCK')});tim_required_reasons=@()}
        Write-TsfKernelJson $verifier $verifierPath
    }else{$verifier = Invoke-TsfKernelPostRunVerify -MissionPath $effectiveMissionPath -WorkerResultPath $workerResultPath -OutFile $verifierPath -StateRoot $StateRoot}
    Register-TsfProducerEvidence $producerRegistryPath verifier_result $verifierPath $producerCapability | Out-Null
    $events.Add((New-LifecycleEvent -Step "postrun_verify" -Status ([string]$verifier.verdict) -Message "Post-run verifier completed." -Evidence $verifierPath)) | Out-Null
}

$exactNextAction = if ($RunApprovedFixtureWorker -or $RunCanonicalAppServerWorker) {
    "Review fixture lifecycle output. Commit only if verifier is GREEN and touched files are expected."
} else {
    "Dry-run lifecycle complete. Run with -RunApprovedFixtureWorker only for the approved fixture pilot."
}
$lifecycleStage = 'PRESERVATION'
if($TestOnlyFault-eq'PRESERVATION'){throw 'TEST_ONLY_PRESERVATION_BLOCK'}
$preservation = Write-TsfKernelPreservationPacket -MissionPath $effectiveMissionPath -PreflightResultPath $preflightPath -RolePreflightPath $(if($null-ne$rolePreflight){$rolePreflightPath}else{''}) -WorkerInstructionPath $(if($null-ne$workerInstruction){$workerInstructionPath}else{''}) -WorkerResultPath $workerResultPath -VerifierResultPath $(if($null-ne$verifier){$verifierPath}else{''}) -AdapterResultPath $(if($null-ne$adapterResult){$adapterResultPath}else{''}) -EventJournalPath $(if($null-ne$adapterResult){$adapterEventPath}else{''}) -QueueDocumentPath $(if([string]$inputDocument.schema_version-eq'tsf_canonical_queue_document_v1'){$CanonicalQueueDocumentEvidencePath}else{''}) -PromptPath $(if($null-ne$adapterResult){$promptPath}else{''}) -StderrPath $(if($null-ne$adapterResult){$adapterStderrPath}else{''}) -ProducerRegistryPath $producerRegistryPath -ProducerCapability $producerCapability -OutputDirectory $preservationRoot -RunId $runId -DurableMission $(if(Test-LifecycleProperty -Value $inputDocument -Name 'durable_mission'){$inputDocument.durable_mission}else{$null}) -ExactNextAction $exactNextAction
$events.Add((New-LifecycleEvent -Step "preserve" -Status ([string]$preservation.final_decision) -Message "Preservation packet written." -Evidence ([string]$preservation.packet_directory))) | Out-Null

$lifecycleStage = 'TERMINAL_RESULT'
$terminalQueueDocumentHash=if($queueDocumentHash){$queueDocumentHash}else{'0'*64}
$terminalStatus = 'COMPLETED_WITH_CAVEATS'
if (![bool]$preflight.preflight_approved) {
    $terminalStatus = if ([string]$preflight.verdict -eq 'TIM_REQUIRED') { 'TIM_REQUIRED' } else { 'BLOCKED_PREFLIGHT' }
} elseif (!$rolePreflightApproved) {
    $terminalStatus = if ($rolePreflightVerdict -eq 'TIM_REQUIRED') { 'TIM_REQUIRED' } else { 'BLOCKED_ROLE_PERMISSION' }
} elseif ($workerStatus -eq 'BLOCKED_WORKER_START') {
    $terminalStatus = 'BLOCKED_WORKER_START'
} elseif ($null -ne $verifier -and [string]$verifier.verdict -ne 'GREEN') {
    $terminalStatus = if ([string]$verifier.verdict -eq 'TIM_REQUIRED') { 'TIM_REQUIRED' } else { 'BLOCKED_VERIFIER' }
} elseif ($blockedReasons.Count -gt 0) {
    $terminalStatus = if (@($blockedReasons | Where-Object { $_ -match 'TIM_REQUIRED' }).Count -gt 0) { 'TIM_REQUIRED' } else { 'BLOCKED_WORKER_RESULT' }
} elseif ([string]$preservation.final_decision -notin @('GREEN','YELLOW')) {
    $terminalStatus = 'BLOCKED_PRESERVATION'
} elseif ($null -ne $verifier -and [string]$verifier.verdict -eq 'GREEN') {
    $terminalStatus = 'COMPLETED_GREEN'
}
$registry = Read-TsfKernelJson $producerRegistryPath
$queueState = if([string]::IsNullOrWhiteSpace([string]$script:currentQueueMissionPath)){''}else{Split-Path -Leaf (Split-Path -Parent ([string]$script:currentQueueMissionPath))}
$result = New-TsfLifecycleTerminalResult -TerminalStatus $terminalStatus -MissionId $missionId -MissionRevision $missionRevision -RunId $runId -QueueDocumentSha256 $terminalQueueDocumentHash -PolicyFingerprint $policyFingerprintForRegistry -Repository $repoPathForRegistry -Branch ([string]$gitForRegistry.branch) -Worktree $repoPathForRegistry -ResultPath $OutFile -ProducerRegistryPath $producerRegistryPath -ProducerBindingIdentitySha256 ([string]$registry.binding_identity_sha256) -OrchestratorInvocationIdentity ([string]$registry.binding.orchestrator_invocation_identity) -OutcomeStage $lifecycleStage -MissionPath (Get-TsfKernelFullPath $MissionPath) -EffectiveMissionPath (Get-TsfKernelFullPath $effectiveMissionPath) -QueueMissionPath ([string]$script:currentQueueMissionPath) -QueueState $queueState -PreflightVerdict ([string]$preflight.verdict) -PreflightApproved ([bool]$preflight.preflight_approved) -RolePreflightVerdict $rolePreflightVerdict -RolePreflightRequired $requiresRolePreflight -RolePreflightApproved $rolePreflightApproved -WorkerStatus $workerStatus -VerifierVerdict $(if($null-ne$verifier){[string]$verifier.verdict}else{''}) -PreservationStatus 'PRESERVED' -PreservationPacketFile ([string]$preservation.packet_file) -PreservationManifestPath ([string]$preservation.manifest_path) -AdapterResultPath $(if($null-ne$adapterResult){$adapterResultPath}else{''}) -WorkerResultPath $workerResultPath -VerifierResultPath $(if($null-ne$verifier){$verifierPath}else{''}) -WorkerLaunched ([bool]($null-ne$adapterResult-or$codexCliInvoked)) -EvidencePreserved $true -RuntimePathMaximum ([int]$completePathPlan.maximum_path_length) -Events @($events) -BlockedReasons @($blockedReasons)
$validation = Test-TsfLifecycleTerminalResult -Result $result -PathPlan $completePathPlan -QueueDocumentSha256 $terminalQueueDocumentHash -PolicyFingerprint $policyFingerprintForRegistry
if(!$validation.valid){throw "LIFECYCLE_TERMINAL_RESULT_SCHEMA_MISMATCH: $($validation.errors -join '; ')"}
Write-TsfKernelJson -Value $result -Path $OutFile
Register-TsfProducerEvidence $producerRegistryPath lifecycle_result $OutFile $producerCapability | Out-Null
$provenance = Test-TsfLifecycleTerminalResult -Result $result -PathPlan $completePathPlan -QueueDocumentSha256 $terminalQueueDocumentHash -PolicyFingerprint $policyFingerprintForRegistry -RequireProducerProvenance
if(!$provenance.valid){throw "LIFECYCLE_TERMINAL_RESULT_PROVENANCE_MISMATCH: $($provenance.errors -join '; ')"}
$result | ConvertTo-Json -Depth 30
if($result.final_decision-in@('GREEN','YELLOW')){exit 0}
exit 1
} catch {
    $failureMessage = $_.Exception.Message
    if($null-eq$blockedReasons){$blockedReasons=[System.Collections.Generic.List[string]]::new()}
    if(@($blockedReasons)-notcontains$failureMessage){$blockedReasons.Add($failureMessage)|Out-Null}
    if($null-ne$events){$events.Add((New-LifecycleEvent -Step $lifecycleStage -Status 'FAIL' -Message $failureMessage))|Out-Null}
    $terminalStatus = if($lifecycleStage-eq'PRESERVATION'){'BLOCKED_PRESERVATION'}elseif($failureMessage-match'TIM_REQUIRED'){'TIM_REQUIRED'}else{'INTERNAL_ERROR'}
    if($null-ne$completePathPlan){
        if([string]::IsNullOrWhiteSpace($OutFile)){$OutFile=[string]$completePathPlan.lifecycle_plan.artifacts.lifecycle_result}
        if([string]::IsNullOrWhiteSpace($producerRegistryPath)){$producerRegistryPath=[string]$completePathPlan.lifecycle_plan.artifacts.producer_registry}
        $bindingHash=('0'*64);$invocationHash=('0'*64);$branch=''
        if(Test-Path $producerRegistryPath -PathType Leaf){$registry=Read-TsfKernelJson $producerRegistryPath;$bindingHash=[string]$registry.binding_identity_sha256;$invocationHash=[string]$registry.binding.orchestrator_invocation_identity;$branch=[string]$registry.binding.branch}
        $result = New-TsfLifecycleTerminalResult -TerminalStatus $terminalStatus -MissionId $missionId -MissionRevision $missionRevision -RunId $runId -QueueDocumentSha256 $(if($queueDocumentHash){$queueDocumentHash}else{'0'*64}) -PolicyFingerprint $(if($policyFingerprintForRegistry){$policyFingerprintForRegistry}else{'0'*64}) -Repository $repoPathForRegistry -Branch $branch -Worktree $repoPathForRegistry -ResultPath $OutFile -ProducerRegistryPath $producerRegistryPath -ProducerBindingIdentitySha256 $bindingHash -OrchestratorInvocationIdentity $invocationHash -OutcomeStage $lifecycleStage -MissionPath $(if($MissionPath){Get-TsfKernelFullPath $MissionPath}else{''}) -EffectiveMissionPath $effectiveMissionPath -QueueMissionPath ([string]$script:currentQueueMissionPath) -PreflightVerdict $(if($null-ne$preflight){[string]$preflight.verdict}else{''}) -PreflightApproved $(if($null-ne$preflight){[bool]$preflight.preflight_approved}else{$false}) -RolePreflightVerdict $(if($null-ne$rolePreflight){[string]$rolePreflight.verdict}else{''}) -RolePreflightRequired $(if($null-ne$requiresRolePreflight){[bool]$requiresRolePreflight}else{$false}) -RolePreflightApproved $(if($null-ne$rolePreflightApproved){[bool]$rolePreflightApproved}else{$false}) -WorkerStatus $workerStatus -VerifierVerdict $(if($null-ne$verifier){[string]$verifier.verdict}else{''}) -PreservationStatus $(if($null-ne$preservation){'PRESERVED'}else{'BLOCKED'}) -PreservationPacketFile $(if($null-ne$preservation){[string]$preservation.packet_file}else{''}) -PreservationManifestPath $(if($null-ne$preservation){[string]$preservation.manifest_path}else{''}) -AdapterResultPath $(if($null-ne$adapterResult){$adapterResultPath}else{''}) -WorkerResultPath $workerResultPath -VerifierResultPath $(if($null-ne$verifier){$verifierPath}else{''}) -WorkerLaunched ([bool]($null-ne$adapterResult)) -EvidencePreserved ([bool]($null-ne$preservation)) -RuntimePathMaximum ([int]$completePathPlan.maximum_path_length) -Events @($events) -BlockedReasons @($blockedReasons) -InternalError $failureMessage
        Write-TsfKernelJson -Value $result -Path $OutFile
        if($null-ne$producerCapability-and(Test-Path $producerRegistryPath -PathType Leaf)){try{Register-TsfProducerEvidence $producerRegistryPath lifecycle_result $OutFile $producerCapability|Out-Null}catch{}}
        $result|ConvertTo-Json -Depth 30
    }
    exit 1
}
