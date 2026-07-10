param(
    [string]$RequestFixturePath = "",
    [string]$NaturalRequest = "",
    [string]$ProjectId = "tsf-operator-console",
    [string]$ProposedWorkerRole = "documentation_worker",
    [string]$OutFile = "",
    [string]$RepoPath = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    $RepoPath = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

if (![string]::IsNullOrWhiteSpace($RequestFixturePath)) {
    if (!(Test-Path -LiteralPath $RequestFixturePath)) {
        throw "Missing request fixture: $RequestFixturePath"
    }
    $fixture = Get-Content -Raw -LiteralPath $RequestFixturePath | ConvertFrom-Json
    if ($fixture.PSObject.Properties.Name -contains "natural_request") {
        $NaturalRequest = [string]$fixture.natural_request
    }
    if ($fixture.PSObject.Properties.Name -contains "project_id") {
        $ProjectId = [string]$fixture.project_id
    }
    if ($fixture.PSObject.Properties.Name -contains "proposed_worker_role") {
        $ProposedWorkerRole = [string]$fixture.proposed_worker_role
    }
}

if ([string]::IsNullOrWhiteSpace($NaturalRequest)) {
    throw "NaturalRequest or RequestFixturePath with natural_request is required."
}

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $safeName = ($ProjectId.ToLowerInvariant() -replace "[^a-z0-9._-]+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeName)) { $safeName = "console-draft" }
    $OutFile = Join-Path $RepoPath "tests/fixtures/fleet/operator-console/draft-missions/$safeName.console-draft.json"
}

$intermediatePath = Join-Path (Split-Path -Parent $OutFile) ".draft-adapter-output.json"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null

$adapter = & (Join-Path $PSScriptRoot "New-TsfProjectMainBotMissionDraft.ps1") `
    -ProjectId $ProjectId `
    -NaturalRequest $NaturalRequest `
    -Lane "MASTER_TSF_CONTROL_PLANE" `
    -RequestedGoal $NaturalRequest `
    -ProposedWorkerRole $ProposedWorkerRole `
    -AllowedReads @("docs/hq", "fleet/control", "tools/operator-console/readonly") `
    -AllowedWrites @("tests/fixtures/fleet/operator-console/draft-missions") `
    -ExpectedArtifacts @("console-draft-mission-preview") `
    -StopConditions @("scope-gate|approval_required|Stop if request crosses a hard TSF gate.", "draft-only|execution_disabled|Do not execute from console draft helper.") `
    -OutFile $intermediatePath `
    -RepoPath $RepoPath

$classificationMap = @{
    "SAFE_LOCAL_MISSION" = "SAFE_DRAFT_ONLY"
    "NEEDS_TIM_APPROVAL" = "NEEDS_TIM_APPROVAL"
    "NEEDS_CHATGPT_HQ" = "NEEDS_CHATGPT_HQ"
    "BLOCKED_UNSAFE" = "BLOCKED_UNSAFE"
    "NEEDS_MAIN_BOT_REVIEW" = "NEEDS_TIM_APPROVAL"
}
$consoleClassification = if ($classificationMap.ContainsKey([string]$adapter.classification)) {
    $classificationMap[[string]$adapter.classification]
} else {
    "NEEDS_TIM_APPROVAL"
}

$draft = [pscustomobject]@{
    schema_version = "tsf_console_mission_draft_v1"
    verdict = $consoleClassification
    generated_at = (Get-Date).ToString("o")
    draft_only = $true
    execution_enabled = $false
    queue_submission_enabled = $false
    worker_execution_enabled = $false
    project_id = $ProjectId
    natural_request = $NaturalRequest
    proposed_worker_role = $ProposedWorkerRole
    draft_adapter_classification = $adapter.classification
    mission_draft = $adapter
    hard_gates = @(
        "push",
        "merge",
        "deploy",
        "install_packages",
        "migration",
        "secrets",
        "api_call",
        "codex_worker_execution",
        "background_runner",
        "product_repo_mutation",
        "canonical_nwr_mutation"
    )
    next_safe_action = if ($consoleClassification -eq "SAFE_DRAFT_ONLY") {
        "Review or copy the draft. Run preflight separately before any future execution gate."
    } else {
        "Stop for Tim approval or compressed HQ packet. Do not execute."
    }
}

$draft | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutFile -Encoding UTF8
if (Test-Path -LiteralPath $intermediatePath) {
    Remove-Item -LiteralPath $intermediatePath -Force
}

$draft
