param(
    [string]$IdeaText = "",
    [string]$IdeaFixturePath = "",
    [string]$ProjectId = "tsf",
    [string[]]$Tags = @(),
    [switch]$Urgent,
    [string]$IdeaId = "",
    [string]$OutDir = "",
    [string]$RepoPath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-TsfRepoPath {
    if (![string]::IsNullOrWhiteSpace($RepoPath)) {
        return (Resolve-Path -LiteralPath $RepoPath).Path
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

function Test-TsfPathInside {
    param([string]$Path, [string[]]$Roots)
    $full = [System.IO.Path]::GetFullPath($Path)
    foreach ($root in $Roots) {
        $rootFull = [System.IO.Path]::GetFullPath($root).TrimEnd("\")
        if ($full.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($rootFull + "\", [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

$repo = Resolve-TsfRepoPath

if (![string]::IsNullOrWhiteSpace($IdeaFixturePath)) {
    if (!(Test-Path -LiteralPath $IdeaFixturePath)) {
        throw "Missing idea fixture: $IdeaFixturePath"
    }
    $fixture = Get-Content -Raw -LiteralPath $IdeaFixturePath | ConvertFrom-Json
    if ($fixture.PSObject.Properties.Name -contains "idea_text") { $IdeaText = [string]$fixture.idea_text }
    if ($fixture.PSObject.Properties.Name -contains "project_id") { $ProjectId = [string]$fixture.project_id }
    if ($fixture.PSObject.Properties.Name -contains "tags") { $Tags = @($fixture.tags | ForEach-Object { [string]$_ }) }
}

if ([string]::IsNullOrWhiteSpace($IdeaText)) {
    throw "IdeaText or IdeaFixturePath with idea_text is required."
}
if ($IdeaText.Length -gt 5000) {
    throw "IdeaText exceeds the 5000 character local intake limit."
}

if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = Join-Path $repo "tests\fixtures\fleet\research-pipeline\idea-inbox"
}

$approvedRoots = @(
    (Join-Path $repo "tests\fixtures\fleet\research-pipeline\idea-inbox"),
    (Join-Path $repo ".codex-local\research-pipeline\idea-inbox")
)
if (!(Test-TsfPathInside -Path $OutDir -Roots $approvedRoots)) {
    throw "OutDir is outside approved research idea roots: $OutDir"
}

if ([string]::IsNullOrWhiteSpace($IdeaId)) {
    $seed = ($IdeaText.ToLowerInvariant() -replace "[^a-z0-9]+", "-").Trim("-")
    if ($seed.Length -gt 46) { $seed = $seed.Substring(0, 46).Trim("-") }
    if ([string]::IsNullOrWhiteSpace($seed)) { $seed = "research-idea" }
    $IdeaId = "idea-$seed"
}
$safeId = ($IdeaId.ToLowerInvariant() -replace "[^a-z0-9._-]+", "-").Trim("-")
if ([string]::IsNullOrWhiteSpace($safeId)) { throw "IdeaId did not produce a safe file name." }

$classification = "QUICK_LOCAL_REVIEW"
$promptCount = 0
if ($IdeaText.Trim().Length -lt 24 -or $IdeaText -match "(?i)\b(make it better|research stuff|do research)\b") {
    $classification = "NEEDS_TIM_DESIGN_INPUT_FIRST"
} elseif ($IdeaText -match "(?i)\b(secret|credential|api key|normal nwr packets?|canonical nwr|product repo|privatelens)\b") {
    $classification = "BLOCKED_UNSAFE"
} elseif ($IdeaText -match "(?i)\b(agent[- ]of[- ]agents|deep research|architecture|multi[- ]agent|import|export|research pipeline)\b") {
    $classification = "MULTI_ANGLE_DEEP_RESEARCH"
    $promptCount = 3
} elseif ($IdeaText -match "(?i)\b(compare|evaluate|strategy|framework)\b") {
    $classification = "SINGLE_DEEP_RESEARCH_RUN"
    $promptCount = 1
}

$components = New-Object System.Collections.ArrayList
if ($IdeaText -match "(?i)operator console|chatroom") { $components.Add("operator_console") | Out-Null }
if ($IdeaText -match "(?i)project main bot|agent-of-agents|agent of agents") { $components.Add("project_main_bot") | Out-Null }
if ($IdeaText -match "(?i)deep research|research") { $components.Add("deep_research_pipeline") | Out-Null }
if ($IdeaText -match "(?i)import|export") { $components.Add("research_import_export") | Out-Null }
if ($IdeaText -match "(?i)queue") { $components.Add("mission_queue") | Out-Null }
if ($components.Count -eq 0) { $components.Add("tsf_control_plane") | Out-Null }

$idea = [pscustomobject]@{
    schema_version = "tsf_research_idea_v1"
    idea_id = $safeId
    created_at = (Get-Date).ToString("o")
    project_id = $ProjectId
    original_wording = $IdeaText
    interpreted_goal = if ($classification -eq "NEEDS_TIM_DESIGN_INPUT_FIRST") { "Clarify the requested research decision before planning." } else { "Plan local, advisory research for TSF control-plane decisions." }
    tags = @($Tags)
    urgency = if ($Urgent) { "urgent" } else { "normal" }
    assumptions = @(
        "No API call is made by idea intake.",
        "Research conclusions are advisory and never approval.",
        "Operator Console may supervise but cannot bypass HQ gates."
    )
    expected_decision = "KEEP_CHANGE_ADD_REMOVE_DELAY recommendation after import/synthesis"
    related_tsf_components = @($components)
    related_prior_ideas = @()
    research_classification = $classification
    research_prompt_count = $promptCount
    export_enabled = $false
    import_enabled = $true
    synthesis_enabled = $true
    final_decision_authority = "Tim_or_approved_TSF_gate"
    provenance = [pscustomobject]@{
        created_by = "local_tsf_research_intake_helper"
        source = if ([string]::IsNullOrWhiteSpace($IdeaFixturePath)) { "direct_text" } else { "fixture" }
        api_called = $false
        worker_invoked = $false
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outFile = Join-Path $OutDir "$safeId.json"
$idea | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $outFile -Encoding UTF8
$idea
