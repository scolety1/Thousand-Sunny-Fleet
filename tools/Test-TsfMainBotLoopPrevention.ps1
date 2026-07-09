param(
    [Parameter(Mandatory = $true)]
    [string]$CasePath,

    [string]$RulesPath = "fleet/control/main-bot-loop-prevention-rules.v1.json",
    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

$case = Get-Content -LiteralPath $CasePath -Raw | ConvertFrom-Json
$rules = Get-Content -LiteralPath $RulesPath -Raw | ConvertFrom-Json
$hits = [System.Collections.Generic.List[object]]::new()

function Add-LoopHit {
    param([string]$RuleId, [string]$Decision, [string]$Reason)
    $script:hits.Add([pscustomobject]@{
        rule_id = $RuleId
        decision = $Decision
        reason = $Reason
    }) | Out-Null
}

if (($case.repeated_same_blocker_count -as [int]) -ge 3) {
    Add-LoopHit -RuleId "repeat-same-blocker" -Decision "STOP_AND_PRESERVE" -Reason "Same blocker repeated three or more times."
}
if (($case.artifact_only_iterations -as [int]) -ge 2 -and ![bool]$case.lifecycle_progress) {
    Add-LoopHit -RuleId "artifact-only-no-progress" -Decision "STOP_AND_PRESERVE" -Reason "Artifact-only work repeated without lifecycle progress."
}
if (($case.forbidden_action_repeats -as [int]) -ge 1) {
    Add-LoopHit -RuleId "forbidden-action-repeat" -Decision "NEEDS_TIM_APPROVAL" -Reason "Forbidden action requested again without approval."
}
if ([bool]$case.worker_green_verifier_red) {
    Add-LoopHit -RuleId "worker-green-verifier-red" -Decision "RED_UNSAFE" -Reason "Worker says GREEN while verifier says RED."
}
if ([bool]$case.duplicate_system_proposed -and [bool]$case.reusable_component_exists) {
    Add-LoopHit -RuleId "duplicate-system-with-reuse" -Decision "STOP_AND_PRESERVE" -Reason "New duplicate system proposed while reusable component exists."
}
if ([bool]$case.continue_research_no_finish_line) {
    Add-LoopHit -RuleId "research-no-finish-line" -Decision "NEEDS_MAIN_BOT_REVIEW" -Reason "Research request lacks an artifact-producing finish line."
}

$decision = "PASS_NO_LOOP"
if ($hits.Count -gt 0) {
    $priority = @("RED_UNSAFE", "NEEDS_TIM_APPROVAL", "STOP_AND_PRESERVE", "NEEDS_MAIN_BOT_REVIEW")
    foreach ($candidate in $priority) {
        if (@($hits | Where-Object { $_.decision -eq $candidate }).Count -gt 0) {
            $decision = $candidate
            break
        }
    }
}

$result = [pscustomobject]@{
    schema_version = "main_bot_loop_prevention_result_v1"
    case_id = [string]$case.case_id
    decision = $decision
    rule_hits = @($hits)
    rules_path = $RulesPath
    background_runner_started = $false
    api_called = $false
}

if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    $result | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}

$result
