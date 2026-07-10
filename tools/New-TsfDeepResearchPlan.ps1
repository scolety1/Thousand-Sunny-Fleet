param(
    [Parameter(Mandatory = $true)][string]$IdeaPath,
    [string]$RegistryPath = "",
    [string]$OutDir = "",
    [string]$ProjectId = "",
    [int]$MaxPrompts = 4,
    [string]$RepoPath = ""
)

$ErrorActionPreference = "Stop"

function Get-TsfRepo {
    if (![string]::IsNullOrWhiteSpace($RepoPath)) { return (Resolve-Path -LiteralPath $RepoPath).Path }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

function Normalize-TsfText {
    param([string]$Value)
    return (($Value.ToLowerInvariant() -replace "[^a-z0-9]+", " ").Trim() -replace "\s+", " ")
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

$repo = Get-TsfRepo
if (!(Test-Path -LiteralPath $IdeaPath)) { throw "Missing idea path: $IdeaPath" }
if ([string]::IsNullOrWhiteSpace($RegistryPath)) { $RegistryPath = Join-Path $repo "fleet\control\research-registry.v1.json" }
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $repo "tests\fixtures\fleet\research-pipeline\research-plans" }

$approvedOutRoots = @(
    (Join-Path $repo "tests\fixtures\fleet\research-pipeline\research-plans"),
    (Join-Path $repo ".codex-local\research-pipeline\research-plans")
)
if (!(Test-TsfPathInside -Path $OutDir -Roots $approvedOutRoots)) {
    throw "OutDir is outside approved research plan roots: $OutDir"
}

$idea = Get-Content -Raw -LiteralPath $IdeaPath | ConvertFrom-Json
$registry = $null
if (Test-Path -LiteralPath $RegistryPath) {
    $registry = Get-Content -Raw -LiteralPath $RegistryPath | ConvertFrom-Json
}

if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    $ProjectId = "research-$($idea.idea_id)"
}
$safeProjectId = ($ProjectId.ToLowerInvariant() -replace "[^a-z0-9._-]+", "-").Trim("-")
if ([string]::IsNullOrWhiteSpace($safeProjectId)) { throw "ProjectId did not produce a safe identifier." }

$original = [string]$idea.original_wording
$normalized = Normalize-TsfText -Value $original
$classification = [string]$idea.research_classification
$stopReasons = New-Object System.Collections.ArrayList
$duplicateOf = ""

if ($null -ne $registry -and $registry.PSObject.Properties.Name -contains "known_research_projects") {
    foreach ($known in @($registry.known_research_projects)) {
        $knownText = Normalize-TsfText -Value ([string]$known.title)
        if (![string]::IsNullOrWhiteSpace($knownText) -and ($normalized -eq $knownText -or $normalized.Contains($knownText) -or $knownText.Contains($normalized))) {
            $duplicateOf = [string]$known.research_project_id
        }
    }
}

if ($classification -eq "BLOCKED_UNSAFE" -or $original -match "(?i)\b(secret|credential|api key|normal nwr packets?|canonical nwr|product repo|privatelens|raw repo dump)\b") {
    $classification = "BLOCKED_UNSAFE"
    $stopReasons.Add("Unsafe or forbidden research scope requested.") | Out-Null
} elseif ($classification -eq "NEEDS_TIM_DESIGN_INPUT_FIRST" -or $original.Trim().Length -lt 24) {
    $classification = "NEEDS_TIM_DESIGN_INPUT_FIRST"
    $stopReasons.Add("Idea needs Tim design input before research export.") | Out-Null
} elseif (![string]::IsNullOrWhiteSpace($duplicateOf) -and $safeProjectId -ne $duplicateOf) {
    $classification = "DUPLICATE_OR_OVERLAPPING"
    $stopReasons.Add("Potential duplicate or overlapping research project: $duplicateOf") | Out-Null
} elseif ($original -match "(?i)\b(agent[- ]of[- ]agents|architecture|deep research|research intake|import|export|operator console)\b") {
    $classification = "MULTI_ANGLE_DEEP_RESEARCH"
} elseif ($classification -ne "SINGLE_DEEP_RESEARCH_RUN" -and $classification -ne "QUICK_LOCAL_REVIEW") {
    $classification = "SINGLE_DEEP_RESEARCH_RUN"
}

$promptCount = 0
if ($classification -eq "MULTI_ANGLE_DEEP_RESEARCH") { $promptCount = 3 }
elseif ($classification -eq "SINGLE_DEEP_RESEARCH_RUN") { $promptCount = 1 }
elseif ($classification -eq "QUICK_LOCAL_REVIEW") { $promptCount = 0 }

if ($promptCount -gt $MaxPrompts) {
    $classification = "TIM_REQUIRED_PROMPT_COUNT_EXCEEDED"
    $stopReasons.Add("Prompt count exceeds local policy.") | Out-Null
}

$prompts = @()
if ($promptCount -gt 0 -and $stopReasons.Count -eq 0) {
    $promptSpecs = @(
        [pscustomobject]@{
            prompt_id = "architecture-supervisor-hierarchy"
            research_question = "What Agent-of-Agents hierarchy should TSF use for Project Main Bot, mission queue, workers, and Operator Console supervision?"
            reason_cannot_combine = "Hierarchy and control-plane authority need focused treatment."
            required_source_types = @("official framework docs", "primary papers", "security references")
        },
        [pscustomobject]@{
            prompt_id = "research-intake-import-export"
            research_question = "How should TSF receive, export, import, and synthesize external Deep Research without bypassing HQ gates?"
            reason_cannot_combine = "Import/export provenance and advisory semantics are separate from hierarchy."
            required_source_types = @("workflow architecture", "provenance", "durable execution")
        },
        [pscustomobject]@{
            prompt_id = "operator-console-supervision-and-risk"
            research_question = "How should the Operator Console supervise Agent-of-Agents workflows while preserving least privilege and no-API controls?"
            reason_cannot_combine = "Console supervision and risk controls require dedicated threat modeling."
            required_source_types = @("observability", "least privilege", "human-in-the-loop systems")
        }
    )
    if ($promptCount -eq 1) { $promptSpecs = @($promptSpecs[0]) }
    foreach ($spec in $promptSpecs) {
        $prompts += [pscustomobject]@{
            prompt_id = $spec.prompt_id
            title = $spec.prompt_id
            research_question = $spec.research_question
            reason_cannot_combine = $spec.reason_cannot_combine
            required_source_types = $spec.required_source_types
            context_package = "Use compressed TSF context only; do not include full raw repo dumps, secrets, product repos, or normal NWR packets."
            output_contract = "Return recommendations as KEEP/CHANGE/ADD/REMOVE/DELAY with citations and caveats."
            stop_condition = "Stop if API credentials, private data, product/canonical NWR scope, or authority expansion is required."
        }
    }
}

$planVerdict = "GREEN_RESEARCH_PLAN_READY_FOR_EXPORT"
if ($stopReasons.Count -gt 0) { $planVerdict = "TIM_REQUIRED_RESEARCH_PLAN_BLOCKED" }
if ($promptCount -eq 0 -and $stopReasons.Count -eq 0) { $planVerdict = "GREEN_LOCAL_REVIEW_ONLY_NO_EXPORT_NEEDED" }

$plan = [pscustomobject]@{
    schema_version = "tsf_deep_research_plan_v1"
    research_project_id = $safeProjectId
    idea_id = [string]$idea.idea_id
    created_at = (Get-Date).ToString("o")
    classification = $classification
    verdict = $planVerdict
    prompt_count = $promptCount
    max_prompt_count = $MaxPrompts
    prompts = $prompts
    duplicate_of = $duplicateOf
    stop_reasons = @($stopReasons)
    manifest = [pscustomobject]@{
        no_api_called = $true
        deep_research_auto_submission_enabled = $false
        advisory_only = $true
        hq_gate_required_for_adoption = $true
        raw_repo_dump_included = $false
        product_repo_scope = $false
        canonical_nwr_scope = $false
    }
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$outFile = Join-Path $OutDir "$safeProjectId.plan.json"
$plan | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $outFile -Encoding UTF8
$plan
