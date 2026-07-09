param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,

    [string]$OutDirectory = "",
    [string]$PolicyPath = "fleet/control/project-main-bot-self-continuation-policy.v1.json",
    [string]$ContextCapsulePath = "tests/fixtures/fleet/project-main-bot/sample_project_context_capsule.json"
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

function Read-SelfContinuationJson {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { throw "Missing JSON file: $Path" }
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
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

$request = Read-SelfContinuationJson -Path $RequestPath
$policy = Read-SelfContinuationJson -Path (Join-Path $fleetRoot $PolicyPath)
$caseId = if ($request.PSObject.Properties.Name -contains "case_id") { [string]$request.case_id } else { "self-continuation-" + (Get-Date -Format "yyyyMMddHHmmss") }
if ([string]::IsNullOrWhiteSpace($OutDirectory)) {
    $OutDirectory = Join-Path $fleetRoot ".codex-local\project-main-bot-self-continuation\$caseId"
}
New-Item -ItemType Directory -Force -Path $OutDirectory | Out-Null

$dryRunOut = Join-Path $OutDirectory "dry_run"
$dryRunResultPath = Join-Path $dryRunOut "project_main_bot_dry_run_result.json"
& (Join-Path $fleetRoot "tools\Invoke-TsfProjectMainBotDryRun.ps1") -RequestPath $RequestPath -OutDirectory $dryRunOut -ContextCapsulePath $ContextCapsulePath | Out-Null
$dryRun = Read-SelfContinuationJson -Path $dryRunResultPath

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
if ($hardGateHit.Count -gt 0 -or [string]$dryRun.next_action -eq "NEEDS_TIM_APPROVAL") {
    $nextDecision = "TIM_REQUIRED"
    $escalationRequired = $true
} elseif ([string]$dryRun.next_action -eq "NEEDS_CHATGPT_HQ") {
    $nextDecision = "NEEDS_CHATGPT_HQ_PACKET_ONLY"
    $escalationRequired = $true
} elseif ([string]$dryRun.next_action -eq "READY_FOR_WORKER_DRY_RUN") {
    $nextDecision = "GREEN_SELF_CONTINUATION_DRY_RUN_READY"
} elseif ([string]$dryRun.next_action -eq "BLOCKED_ROLE_PERMISSION") {
    $nextDecision = "RED_ROLE_PERMISSION_BLOCKED"
} elseif ([string]$dryRun.next_action -eq "RED_UNSAFE") {
    $nextDecision = "RED_UNSAFE"
}

$result = [pscustomobject]@{
    schema_version = "project_main_bot_self_continuation_result_v1"
    case_id = $caseId
    request_path = $RequestPath
    dry_run_result_path = $dryRunResultPath
    dry_run_next_action = [string]$dryRun.next_action
    selected_worker_role = [string]$dryRun.worker_role
    next_decision = $nextDecision
    retry_used = $retryUsed
    max_retries_per_mission = [int]$policy.max_retries_per_mission
    escalation_required = $escalationRequired
    hard_gate_hits = @($hardGateHit)
    local_commit_allowed_after_validation = $true
    codex_cli_worker_execution_invoked = $false
    api_called = $false
    background_runner_started = $false
    push_merge_deploy_attempted = $false
    product_repos_mutated = $false
    canonical_nwr_mutated = $false
}

$outFile = Join-Path $OutDirectory "self_continuation_result.json"
$result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outFile -Encoding UTF8
$result
