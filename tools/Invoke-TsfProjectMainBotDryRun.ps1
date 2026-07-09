param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,

    [string]$OutDirectory = "",
    [string]$ContextCapsulePath = "tests/fixtures/fleet/project-main-bot/sample_project_context_capsule.json",
    [string]$ApprovalLedgerPath = ""
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
. (Join-Path $fleetRoot "tools\codex-fleet-enforcement-kernel.ps1")

function Get-MainBotValue {
    param([object]$Object, [string]$Name, [object]$Default)
    if ($null -ne $Object -and $Object.PSObject.Properties.Name -contains $Name -and $null -ne $Object.$Name) {
        return $Object.$Name
    }
    return $Default
}

function ConvertTo-MainBotArray {
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

function New-MainBotSummary {
    param(
        [string]$Path,
        [object]$Result
    )
    $lines = @(
        "# Project Main Bot Dry-Run Summary",
        "",
        "Mission: $($Result.mission_id)",
        "Worker role: $($Result.worker_role)",
        "Next action: $($Result.next_action)",
        "Classification: $($Result.classification)",
        "Lifecycle decision: $($Result.lifecycle_final_decision)",
        "",
        "No Codex CLI, API, background runner, product repo mutation, canonical NWR mutation, push, merge, deploy, install, migration, secrets, PrivateLens, or all-fleet action was performed."
    )
    Set-Content -LiteralPath $Path -Encoding UTF8 -Value $lines
}

$request = Get-Content -LiteralPath $RequestPath -Raw | ConvertFrom-Json
$caseId = [string](Get-MainBotValue -Object $request -Name "case_id" -Default ("main-bot-" + (Get-Date -Format "yyyyMMddHHmmss")))
if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
    $OutDirectory = Join-Path $fleetRoot ".codex-local\project-main-bot-dry-run\$caseId"
}
New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null

$draftPath = Join-Path $OutDirectory "mission_draft.json"
$lifecyclePath = Join-Path $OutDirectory "lifecycle_result.json"
$summaryPath = Join-Path $OutDirectory "tim_summary.md"
$contextOutPath = Join-Path $OutDirectory "context_capsule.updated.json"

$projectId = [string](Get-MainBotValue -Object $request -Name "project_id" -Default "thousand-sunny-fleet")
$naturalRequest = [string](Get-MainBotValue -Object $request -Name "natural_request" -Default "")
$goal = [string](Get-MainBotValue -Object $request -Name "requested_goal" -Default $naturalRequest)
$workerRole = [string](Get-MainBotValue -Object $request -Name "proposed_worker_role" -Default "researcher_source_tracer_worker")
$lane = [string](Get-MainBotValue -Object $request -Name "lane" -Default "MASTER_TSF_CONTROL_PLANE")
$allowedReads = @(ConvertTo-MainBotArray (Get-MainBotValue -Object $request -Name "allowed_reads" -Default @("docs/hq", "fleet/control", "tests/fixtures/fleet/project-main-bot")))
$allowedWrites = @(ConvertTo-MainBotArray (Get-MainBotValue -Object $request -Name "allowed_writes" -Default @("docs/hq/role_aware_mission_lifecycle_integration_v1")))
$forbiddenActions = @(ConvertTo-MainBotArray (Get-MainBotValue -Object $request -Name "forbidden_actions" -Default @()))
$expectedArtifacts = @(ConvertTo-MainBotArray (Get-MainBotValue -Object $request -Name "expected_artifacts" -Default @("docs/hq/role_aware_mission_lifecycle_integration_v1/dry-run-artifact.md")))
$stopConditions = @(ConvertTo-MainBotArray (Get-MainBotValue -Object $request -Name "stop_conditions" -Default @("scope-gate|approval_required|Stop if the request crosses a hard TSF gate.")))
$approvalRequirements = @(ConvertTo-MainBotArray (Get-MainBotValue -Object $request -Name "approval_requirements" -Default @()))

$draftParams = @{
    ProjectId = $projectId
    NaturalRequest = $naturalRequest
    Lane = $lane
    RequestedGoal = $goal
    ProposedWorkerRole = $workerRole
    AllowedReads = $allowedReads
    AllowedWrites = $allowedWrites
    ExpectedArtifacts = $expectedArtifacts
    StopConditions = $stopConditions
    OutFile = $draftPath
    RepoPath = $fleetRoot
    ContextCapsuleId = [string](Get-MainBotValue -Object $request -Name "context_capsule_id" -Default "sample-tsf-role-foundation-context-20260709")
    LaneId = [string](Get-MainBotValue -Object $request -Name "lane_id" -Default $caseId)
}
if ($forbiddenActions.Count -gt 0) {
    $draftParams.ForbiddenActions = $forbiddenActions
}
if ($approvalRequirements.Count -gt 0) {
    $draftParams.ApprovalRequirements = $approvalRequirements
}
& (Join-Path $fleetRoot "tools\New-TsfProjectMainBotMissionDraft.ps1") @draftParams | Out-Null

$draft = Read-TsfKernelJson -Path $draftPath
$classification = [string]$draft.classification
$nextAction = "STOP_AND_PRESERVE"
$lifecycle = $null
$contextUpdate = $null

if ($classification -eq "BLOCKED_UNSAFE") {
    $nextAction = "RED_UNSAFE"
} elseif ($classification -eq "NEEDS_TIM_APPROVAL") {
    $nextAction = "NEEDS_TIM_APPROVAL"
} elseif ($classification -eq "NEEDS_CHATGPT_HQ") {
    $nextAction = "NEEDS_CHATGPT_HQ"
} elseif ($classification -eq "NEEDS_MAIN_BOT_REVIEW") {
    $nextAction = "STOP_AND_PRESERVE"
} else {
    $lifecycleParams = @{
        MissionPath = $draftPath
        OutDirectory = (Join-Path $OutDirectory "lifecycle")
        OutFile = $lifecyclePath
        DryRun = $true
    }
    if (![string]::IsNullOrWhiteSpace($ApprovalLedgerPath)) {
        $lifecycleParams.ApprovalLedgerPath = $ApprovalLedgerPath
    }
    & (Join-Path $fleetRoot "tools\Invoke-TsfMissionLifecycle.ps1") @lifecycleParams | Out-Null
    $lifecycle = Read-TsfKernelJson -Path $lifecyclePath
    if ([string]$lifecycle.role_preflight_verdict -eq "TIM_REQUIRED" -or [string]$lifecycle.final_decision -eq "TIM_REQUIRED") {
        $nextAction = "NEEDS_TIM_APPROVAL"
    } elseif ([string]$lifecycle.role_preflight_verdict -eq "RED") {
        $nextAction = "BLOCKED_ROLE_PERMISSION"
    } elseif ([bool]$lifecycle.preflight_approved -and [bool]$lifecycle.role_preflight_approved -and [string]$lifecycle.worker_status -eq "DRY_RUN_NO_WORKER") {
        $nextAction = "READY_FOR_WORKER_DRY_RUN"
    } elseif ([string]$lifecycle.final_decision -eq "RED") {
        $nextAction = "RED_UNSAFE"
    }
}

$missionId = [string]$draft.mission_packet.mission_id
$blockers = @()
if ($null -ne $lifecycle) {
    $blockers = @(ConvertTo-MainBotArray $lifecycle.blocked_reasons)
}
$contextParams = @{
    CapsulePath = $ContextCapsulePath
    MissionId = $missionId
    MissionResult = $nextAction
    WorkerRole = $workerRole
    CurrentLane = $lane
    ArtifactsCreated = @($draftPath, $lifecyclePath, $summaryPath)
    NextRecommendedAction = "Continue only through TSF role-aware foreground lifecycle."
    OutFile = $contextOutPath
}
if ($blockers.Count -gt 0) {
    $contextParams.BlockersEncountered = $blockers
}
$approvalActions = @(ConvertTo-MainBotArray $draft.mission_packet.approval_requirements | ForEach-Object { [string]$_.exact_action } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
if ($approvalActions.Count -gt 0) {
    $contextParams.ApprovalsRequired = $approvalActions
}
$contextUpdate = & (Join-Path $fleetRoot "tools\Update-TsfProjectContextCapsule.ps1") @contextParams

$result = [pscustomobject]@{
    schema_version = "project_main_bot_dry_run_result_v1"
    case_id = $caseId
    request_path = $RequestPath
    mission_id = $missionId
    worker_role = $workerRole
    classification = $classification
    next_action = $nextAction
    draft_path = $draftPath
    lifecycle_result_path = if ($null -ne $lifecycle) { $lifecyclePath } else { "" }
    lifecycle_final_decision = if ($null -ne $lifecycle) { [string]$lifecycle.final_decision } else { "" }
    worker_instruction_path = if ($null -ne $lifecycle) { [string]$lifecycle.worker_result_path -replace "worker_result\.json$", "worker_instruction.json" } else { "" }
    context_capsule_update_path = $contextOutPath
    tim_summary_path = $summaryPath
    background_runner_started = $false
    codex_cli_invoked = $false
    api_called = $false
    product_repos_mutated = $false
    canonical_nwr_mutated = $false
    push_merge_deploy_attempted = $false
}

$outFile = Join-Path $OutDirectory "project_main_bot_dry_run_result.json"
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outFile -Encoding UTF8
New-MainBotSummary -Path $summaryPath -Result $result
$result
