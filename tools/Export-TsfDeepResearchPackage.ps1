param(
    [Parameter(Mandatory = $true)][string]$PlanPath,
    [string]$OutputRoot = "C:\NWR_REVIEW\TSF_DEEP_RESEARCH_EXPORTS",
    [string]$FallbackRoot = "C:\NWR_SANDBOX\TSF_DEEP_RESEARCH_EXPORTS",
    [string]$RepoPath = ""
)

$ErrorActionPreference = "Stop"

function New-TsfTextFile {
    param([string]$Path, [string]$Text)
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Set-Content -LiteralPath $Path -Value $Text -Encoding UTF8
}

function Test-TsfSafeExportRoot {
    param([string]$Path)
    $full = [System.IO.Path]::GetFullPath($Path)
    return ($full.StartsWith("C:\NWR_REVIEW\TSF_DEEP_RESEARCH_EXPORTS", [System.StringComparison]::OrdinalIgnoreCase) -or
        $full.StartsWith("C:\NWR_SANDBOX\TSF_DEEP_RESEARCH_EXPORTS", [System.StringComparison]::OrdinalIgnoreCase) -or
        $full -match "\\.codex-local\\research-pipeline\\exports")
}

if (!(Test-Path -LiteralPath $PlanPath)) { throw "Missing plan path: $PlanPath" }
$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
if ($plan.verdict -notin @("GREEN_RESEARCH_PLAN_READY_FOR_EXPORT")) {
    throw "Plan is not ready for export: $($plan.verdict)"
}
if ([int]$plan.prompt_count -lt 1) { throw "Plan has no exportable prompts." }
if ([int]$plan.prompt_count -gt [int]$plan.max_prompt_count) { throw "Plan prompt count exceeds policy." }

if (!(Test-TsfSafeExportRoot -Path $OutputRoot)) { throw "OutputRoot is not an approved research export root." }
try {
    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
} catch {
    $OutputRoot = $FallbackRoot
    if (!(Test-TsfSafeExportRoot -Path $OutputRoot)) { throw "FallbackRoot is not approved." }
    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
}

$projectRoot = Join-Path $OutputRoot ([string]$plan.research_project_id)
New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
$exported = @()

foreach ($prompt in @($plan.prompts)) {
    $promptId = ([string]$prompt.prompt_id -replace "[^a-zA-Z0-9._-]+", "-").Trim("-")
    if ([string]::IsNullOrWhiteSpace($promptId)) { throw "Prompt id is not safe." }
    $promptDir = Join-Path $projectRoot $promptId
    New-Item -ItemType Directory -Force -Path $promptDir | Out-Null

    $sendText = @"
TSF Deep Research Request

Research project: $($plan.research_project_id)
Prompt id: $promptId

Question:
$($prompt.research_question)

Required output:
- KEEP / CHANGE / ADD / REMOVE / DELAY recommendations.
- Cite public sources.
- Identify caveats and uncertainty.
- Do not request credentials, secrets, product repo data, canonical NWR data, or API access.
- Treat all conclusions as advisory only; they do not approve TSF changes.
"@
    $contextText = @"
Compressed TSF Context

TSF has a Project Main Bot, mission queue, role-aware workers, local foreground execution, isolated worktree lanes, and a read-only Operator Console. Research should advise architecture and research import/export patterns only.

Hard exclusions: no raw repo dump, no secrets, no product repos, no canonical NWR, no normal NWR packets, no API execution.
"@
    $sourceTrace = "source_id,source_type,description`nlocal_context,compressed_tsf_context,No raw repo dump included`n"
    $contract = [pscustomobject]@{
        schema_version = "tsf_deep_research_required_output_contract_v1"
        research_project_id = [string]$plan.research_project_id
        prompt_id = $promptId
        required_sections = @("summary", "recommendations", "sources", "caveats", "adoption_gate")
        advisory_only = $true
        hq_gate_required_for_adoption = $true
        forbidden_requests = @("secrets", "credentials", "api keys", "product repo", "canonical NWR", "normal NWR packets")
    }
    $manifest = [pscustomobject]@{
        schema_version = "tsf_deep_research_export_manifest_v1"
        research_project_id = [string]$plan.research_project_id
        prompt_id = $promptId
        created_at = (Get-Date).ToString("o")
        no_api_called = $true
        auto_submission_enabled = $false
        raw_repo_dump_included = $false
        product_repo_scope = $false
        canonical_nwr_scope = $false
        files = @(
            "SEND_TO_CHATGPT_DEEP_RESEARCH.md",
            "RESEARCH_CONTEXT.md",
            "SOURCE_TRACE.csv",
            "REQUIRED_OUTPUT_CONTRACT.json",
            "RETURN_REPORT_IMPORT_INSTRUCTIONS.md",
            "RESEARCH_MANIFEST.json"
        )
    }

    New-TsfTextFile -Path (Join-Path $promptDir "SEND_TO_CHATGPT_DEEP_RESEARCH.md") -Text $sendText
    New-TsfTextFile -Path (Join-Path $promptDir "RESEARCH_CONTEXT.md") -Text $contextText
    New-TsfTextFile -Path (Join-Path $promptDir "SOURCE_TRACE.csv") -Text $sourceTrace
    $contract | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $promptDir "REQUIRED_OUTPUT_CONTRACT.json") -Encoding UTF8
    New-TsfTextFile -Path (Join-Path $promptDir "RETURN_REPORT_IMPORT_INSTRUCTIONS.md") -Text "Return the completed report under the approved TSF return root. Include the research_project_id, prompt_id, source list, and caveats. Do not include secrets or approvals."
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $promptDir "RESEARCH_MANIFEST.json") -Encoding UTF8

    $zipPath = Join-Path $projectRoot "$promptId.zip"
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -Path (Join-Path $promptDir "*") -DestinationPath $zipPath -Force
    $exported += [pscustomobject]@{
        prompt_id = $promptId
        package_dir = $promptDir
        zip_path = $zipPath
        zip_exists = (Test-Path -LiteralPath $zipPath)
    }
}

$index = [pscustomobject]@{
    schema_version = "tsf_deep_research_export_index_v1"
    research_project_id = [string]$plan.research_project_id
    created_at = (Get-Date).ToString("o")
    exported_prompt_count = @($exported).Count
    exports = $exported
    api_called = $false
    auto_submitted = $false
}
$index | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $projectRoot "EXPORT_INDEX.json") -Encoding UTF8
$index
