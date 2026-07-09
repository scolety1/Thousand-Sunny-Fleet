$ErrorActionPreference = "Stop"
$fleetRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $fleetRoot

. ".\tools\codex-fleet-enforcement-kernel.ps1"

$failures = New-Object System.Collections.ArrayList

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (!$Condition) {
        Write-Host "FAIL: $Message" -ForegroundColor Red
        $script:failures.Add($Message) | Out-Null
    } else {
        Write-Host "PASS: $Message" -ForegroundColor Green
    }
}

function Assert-Equal {
    param([object]$Actual, [object]$Expected, [string]$Message)
    Assert-True -Condition ([string]$Actual -eq [string]$Expected) -Message "$Message (expected=$Expected actual=$Actual)"
}

function Read-Json {
    param([string]$Path)
    Assert-True -Condition (Test-Path -LiteralPath $Path) -Message "JSON exists: $Path"
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-Json {
    param([string]$Path, [object]$Value)
    $parent = Split-Path -Parent $Path
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $Value | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Path -Encoding UTF8
}

$outRoot = ".codex-local/role-aware-lifecycle-tests"
if (Test-Path -LiteralPath $outRoot) {
    Remove-Item -LiteralPath $outRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

$roleFixtureRoot = "tests/fixtures/fleet/project-main-bot/role_aware_lifecycle"
$builderFixture = Join-Path $roleFixtureRoot "builder_worker.mission-draft.json"
$builderLifecyclePath = Join-Path $outRoot "builder.lifecycle.json"
& ".\tools\Invoke-TsfMissionLifecycle.ps1" -MissionPath $builderFixture -OutDirectory (Join-Path $outRoot "builder-lifecycle") -OutFile $builderLifecyclePath -DryRun | Out-Null
$builderLifecycle = Read-Json $builderLifecyclePath
Assert-True -Condition ([bool]$builderLifecycle.preflight_approved) -Message "safe Builder dry-run mission passes kernel preflight"
Assert-True -Condition ([bool]$builderLifecycle.role_preflight_approved) -Message "safe Builder dry-run mission passes role preflight"
Assert-Equal -Actual $builderLifecycle.worker_status -Expected "DRY_RUN_NO_WORKER" -Message "safe Builder dry-run does not execute worker"

$unknownDraft = Read-Json $builderFixture
$unknownDraft.role_extension.worker_role = "missing_worker_role"
$unknownDraft.role_extension.role_permission_profile_id = "missing_worker_role"
$unknownPath = Join-Path $outRoot "unknown-role.json"
$unknownPermPath = Join-Path $outRoot "unknown-role.permission.json"
Write-Json $unknownPath $unknownDraft
& ".\tools\Test-TsfWorkerRolePermission.ps1" -MissionDraftPath $unknownPath -OutFile $unknownPermPath | Out-Null
$unknownPerm = Read-Json $unknownPermPath
Assert-Equal -Actual $unknownPerm.verdict -Expected "RED" -Message "unknown role blocks"

$profiles = Read-Json "fleet/control/worker-permission-profiles.v1.json"
$profiles.profiles.PSObject.Properties.Remove("builder_worker")
$missingProfilePath = Join-Path $outRoot "profiles.missing-builder.json"
$missingProfilePermPath = Join-Path $outRoot "missing-profile.permission.json"
Write-Json $missingProfilePath $profiles
& ".\tools\Test-TsfWorkerRolePermission.ps1" -MissionDraftPath $builderFixture -PermissionProfilesPath $missingProfilePath -OutFile $missingProfilePermPath | Out-Null
$missingProfile = Read-Json $missingProfilePermPath
Assert-Equal -Actual $missingProfile.verdict -Expected "RED" -Message "missing permission profile blocks"

$outsideDraft = Read-Json $builderFixture
$outsideDraft.mission_packet.allowed_writes = @("C:\Temp\tsf-role-lifecycle-outside.md")
$outsidePath = Join-Path $outRoot "outside-write.json"
$outsidePermPath = Join-Path $outRoot "outside-write.permission.json"
Write-Json $outsidePath $outsideDraft
& ".\tools\Test-TsfWorkerRolePermission.ps1" -MissionDraftPath $outsidePath -OutFile $outsidePermPath | Out-Null
$outsidePerm = Read-Json $outsidePermPath
Assert-Equal -Actual $outsidePerm.verdict -Expected "TIM_REQUIRED" -Message "role cannot write outside repo permission scope"

$codexDraftPath = Join-Path $outRoot "codex-api-draft.json"
& ".\tools\New-TsfProjectMainBotMissionDraft.ps1" -ProjectId "thousand-sunny-fleet" -NaturalRequest "Invoke Codex CLI and call an API." -ProposedWorkerRole "ai_builder_worker" -AllowedWrites @("docs/hq/role_aware_mission_lifecycle_integration_v1") -OutFile $codexDraftPath | Out-Null
$codexDraft = Read-Json $codexDraftPath
Assert-Equal -Actual $codexDraft.classification -Expected "NEEDS_TIM_APPROVAL" -Message "Codex CLI/API request blocks without approval"

$protectedDraft = Read-Json $builderFixture
$protectedDraft.mission_packet.allowed_reads = @("C:\NWR\Niners-War-Room")
$protectedPath = Join-Path $outRoot "protected-path.json"
$protectedPermPath = Join-Path $outRoot "protected-path.permission.json"
Write-Json $protectedPath $protectedDraft
& ".\tools\Test-TsfWorkerRolePermission.ps1" -MissionDraftPath $protectedPath -OutFile $protectedPermPath | Out-Null
$protectedPerm = Read-Json $protectedPermPath
Assert-Equal -Actual $protectedPerm.verdict -Expected "TIM_REQUIRED" -Message "product/canonical NWR path request blocks"

foreach ($roleTemplate in @("tester_worker", "auditor_worker", "researcher_source_tracer_worker")) {
    $template = Read-Json "fleet/control/worker-mission-templates/v1/$roleTemplate.mission-template.json"
    Assert-Equal -Actual $template.role_id -Expected $roleTemplate -Message "$roleTemplate template validates"
}

$mainBotResultPath = Join-Path $outRoot "main-bot-safe-result.json"
$mainBotOut = Join-Path $outRoot "main-bot-safe"
$mainBotResult = & ".\tools\Invoke-TsfProjectMainBotDryRun.ps1" -RequestPath (Join-Path $roleFixtureRoot "requests/build-this-safely.request.json") -OutDirectory $mainBotOut
$mainBotResult | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $mainBotResultPath -Encoding UTF8
$mainBot = Read-Json $mainBotResultPath
Assert-True -Condition (Test-Path -LiteralPath $mainBot.draft_path) -Message "Project Main Bot dry-run creates mission draft"
Assert-Equal -Actual $mainBot.next_action -Expected "READY_FOR_WORKER_DRY_RUN" -Message "Project Main Bot dry-run reaches worker dry-run readiness"

$requestFiles = @(Get-ChildItem -LiteralPath (Join-Path $roleFixtureRoot "requests") -Filter *.json)
foreach ($requestFile in $requestFiles) {
    $request = Read-Json $requestFile.FullName
    $draftPath = Join-Path $outRoot "translator-$($request.case_id).json"
    $draftParams = @{
        ProjectId = [string]$request.project_id
        NaturalRequest = [string]$request.natural_request
        RequestedGoal = [string]$request.requested_goal
        ProposedWorkerRole = [string]$request.proposed_worker_role
        Lane = [string]$request.lane
        AllowedReads = @($request.allowed_reads)
        AllowedWrites = @($request.allowed_writes)
        ExpectedArtifacts = @($request.expected_artifacts)
        StopConditions = @($request.stop_conditions)
        OutFile = $draftPath
    }
    if (@($request.forbidden_actions).Count -gt 0) {
        $draftParams.ForbiddenActions = @($request.forbidden_actions)
    }
    if (@($request.approval_requirements).Count -gt 0) {
        $draftParams.ApprovalRequirements = @($request.approval_requirements)
    }
    & ".\tools\New-TsfProjectMainBotMissionDraft.ps1" @draftParams | Out-Null
    $draft = Read-Json $draftPath
    Assert-Equal -Actual $draft.classification -Expected $request.expected_classification -Message "translator fixture $($request.case_id) maps to expected classification"
}

$contextOut = Join-Path $outRoot "context.updated.json"
& ".\tools\Update-TsfProjectContextCapsule.ps1" -CapsulePath "tests/fixtures/fleet/project-main-bot/sample_project_context_capsule.json" -MissionId "role-aware-test-context-0001" -MissionResult "GREEN" -WorkerRole "tester_worker" -CurrentLane "MASTER_TSF_CONTROL_PLANE" -ArtifactsCreated @("role-aware-test-artifact") -NextRecommendedAction "Continue role-aware lifecycle integration." -OutFile $contextOut | Out-Null
$context = Read-Json $contextOut
Assert-True -Condition (@($context.completed_missions | Where-Object { $_ -match "role-aware-test-context-0001" }).Count -eq 1) -Message "context capsule update writes valid JSON"

$loopCases = @(Get-ChildItem -LiteralPath "tests/fixtures/fleet/project-main-bot/loop_prevention" -Filter *.json)
foreach ($caseFile in $loopCases) {
    $case = Read-Json $caseFile.FullName
    $loopOut = Join-Path $outRoot "loop-$($case.case_id).json"
    & ".\tools\Test-TsfMainBotLoopPrevention.ps1" -CasePath $caseFile.FullName -OutFile $loopOut | Out-Null
    $loop = Read-Json $loopOut
    Assert-Equal -Actual $loop.decision -Expected $case.expected_decision -Message "loop-prevention fixture $($case.case_id) classifies correctly"
}

$requiredInstructionFields = @("mission_id", "worker_role", "allowed_reads", "allowed_writes", "forbidden_actions", "exact_task", "expected_artifacts", "stop_conditions", "verifier_contract", "escalation_triggers", "do_not_exceed_role_authority")
foreach ($packetFile in @(Get-ChildItem -LiteralPath "tests/fixtures/fleet/project-main-bot/worker_instruction_packets" -Filter *.json)) {
    $packet = Read-Json $packetFile.FullName
    foreach ($field in $requiredInstructionFields) {
        Assert-True -Condition ($packet.PSObject.Properties.Name -contains $field) -Message "worker instruction packet $($packetFile.Name) has $field"
    }
}

$effectiveMission = Read-Json $builderFixture
$missionOnly = $effectiveMission.mission_packet
$missionOnly | Add-Member -NotePropertyName "role_extension" -NotePropertyValue $effectiveMission.role_extension -Force
$effectiveMissionPath = Join-Path $outRoot "verifier-effective-mission.json"
$workerResultPath = Join-Path $outRoot "verifier-worker-missing.json"
$verifierOut = Join-Path $outRoot "verifier-missing-artifact.json"
Write-Json $effectiveMissionPath $missionOnly
Write-Json $workerResultPath ([pscustomobject]@{
    schema_version = 1
    mission_id = [string]$missionOnly.mission_id
    worker_role = "builder_worker"
    role_output_contract_satisfied = $false
    files_created = @()
    files_touched = @()
    restricted_actions_attempted = @()
})
$verifier = Invoke-TsfKernelPostRunVerify -MissionPath $effectiveMissionPath -WorkerResultPath $workerResultPath -OutFile $verifierOut -StateRoot (Join-Path $outRoot "states")
Assert-Equal -Actual $verifier.verdict -Expected "RED" -Message "verifier fails closed on missing expected artifact"

$hqPacket = Read-Json (Join-Path $roleFixtureRoot "hq_escalation/hq_escalation_case.no_api.json")
Assert-True -Condition ($hqPacket.api_called -eq $false) -Message "HQ escalation case produces packet and no API call"

if ($failures.Count -gt 0) {
    Write-Host "Role-aware lifecycle integration tests failed: $($failures.Count)" -ForegroundColor Red
    exit 1
}

Write-Host "Role-aware lifecycle integration tests passed." -ForegroundColor Green
