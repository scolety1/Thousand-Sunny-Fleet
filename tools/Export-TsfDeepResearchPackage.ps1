param(
    [Parameter(Mandatory = $true)][string]$PlanPath,
    [string]$OutputRoot = "C:\NWR_REVIEW\TSF_DEEP_RESEARCH_EXPORTS",
    [string]$FallbackRoot = "C:\NWR_SANDBOX\TSF_DEEP_RESEARCH_EXPORTS",
    [string]$RepoPath = ""
)

$ErrorActionPreference = "Stop"

function Get-TsfCanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "Path cannot be empty." }
    if ($Path.IndexOfAny([char[]]@(0)) -ge 0) { throw "Path contains a control character." }
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-TsfPathInside {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string[]]$Roots
    )
    $full = (Get-TsfCanonicalPath -Path $Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    foreach ($root in $Roots) {
        $rootFull = (Get-TsfCanonicalPath -Path $root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        if ($full.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        $boundary = $rootFull + [System.IO.Path]::DirectorySeparatorChar
        if ($full.StartsWith($boundary, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Assert-TsfSafeIdentifier {
    param([Parameter(Mandatory = $true)][string]$Value, [Parameter(Mandatory = $true)][string]$Name)
    if ([string]::IsNullOrWhiteSpace($Value)) { throw "$Name cannot be empty." }
    if ($Value -match '[\x00-\x1f\x7f]' -or $Value.IndexOfAny([System.IO.Path]::GetInvalidFileNameChars()) -ge 0) { throw "$Name contains invalid or control characters." }
    if ([System.IO.Path]::IsPathRooted($Value)) { throw "$Name cannot be rooted or absolute." }
    if ($Value -match '[\\/]' -or $Value -match '\.\.') { throw "$Name cannot contain separators or traversal." }
    if ($Value -notmatch '^[a-z0-9](?:[a-z0-9._-]{0,62}[a-z0-9])?$') {
        throw "$Name must match the strict lowercase identifier allowlist."
    }
    if ($Value -match '^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\..*)?$') {
        throw "$Name cannot use a reserved Windows device name."
    }
}

function Assert-TsfDestination {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$ApprovedRoot)
    $canonical = Get-TsfCanonicalPath -Path $Path
    if (!(Test-TsfPathInside -Path $canonical -Roots @($ApprovedRoot))) {
        throw "Derived export destination escapes the approved output root: $canonical"
    }
    return $canonical
}

function New-TsfTextFile {
    param([string]$Path, [string]$Text, [string]$ApprovedRoot)
    $safePath = Assert-TsfDestination -Path $Path -ApprovedRoot $ApprovedRoot
    $parent = Assert-TsfDestination -Path (Split-Path -Parent $safePath) -ApprovedRoot $ApprovedRoot
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    Set-Content -LiteralPath $safePath -Value $Text -Encoding UTF8
}

if (!(Test-Path -LiteralPath $PlanPath -PathType Leaf)) { throw "Missing plan path: $PlanPath" }
$repo = if ([string]::IsNullOrWhiteSpace($RepoPath)) {
    (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
    (Resolve-Path -LiteralPath $RepoPath).Path
}
$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
if ($plan.verdict -ne "GREEN_RESEARCH_PLAN_READY_FOR_EXPORT") { throw "Plan is not ready for export: $($plan.verdict)" }
if ([int]$plan.prompt_count -lt 1) { throw "Plan has no exportable prompts." }
if ([int]$plan.prompt_count -gt [int]$plan.max_prompt_count) { throw "Plan prompt count exceeds policy." }

$approvedRoots = @(
    (Get-TsfCanonicalPath -Path "C:\NWR_REVIEW\TSF_DEEP_RESEARCH_EXPORTS"),
    (Get-TsfCanonicalPath -Path "C:\NWR_SANDBOX\TSF_DEEP_RESEARCH_EXPORTS"),
    (Get-TsfCanonicalPath -Path (Join-Path $repo ".codex-local\research-pipeline\exports"))
)
$requestedRoot = Get-TsfCanonicalPath -Path $OutputRoot
if (!(Test-TsfPathInside -Path $requestedRoot -Roots $approvedRoots)) { throw "OutputRoot is not an approved research export root." }
$fallbackCanonical = Get-TsfCanonicalPath -Path $FallbackRoot
if (!(Test-TsfPathInside -Path $fallbackCanonical -Roots $approvedRoots)) { throw "FallbackRoot is not an approved research export root." }

$projectId = [string]$plan.research_project_id
Assert-TsfSafeIdentifier -Value $projectId -Name "research_project_id"
$promptPlans = @()
foreach ($prompt in @($plan.prompts)) {
    $promptId = [string]$prompt.prompt_id
    Assert-TsfSafeIdentifier -Value $promptId -Name "prompt_id"
    $promptPlans += [pscustomobject]@{ prompt = $prompt; prompt_id = $promptId }
}
if ($promptPlans.Count -ne [int]$plan.prompt_count) { throw "Plan prompt count does not match its prompt collection." }

# Validate all derived destinations before creating the export tree.
$projectRoot = Assert-TsfDestination -Path (Join-Path $requestedRoot $projectId) -ApprovedRoot $requestedRoot
foreach ($entry in $promptPlans) {
    $promptDir = Assert-TsfDestination -Path (Join-Path $projectRoot $entry.prompt_id) -ApprovedRoot $requestedRoot
    foreach ($name in @("SEND_TO_CHATGPT_DEEP_RESEARCH.md", "RESEARCH_CONTEXT.md", "SOURCE_TRACE.csv", "REQUIRED_OUTPUT_CONTRACT.json", "RETURN_REPORT_IMPORT_INSTRUCTIONS.md", "RESEARCH_MANIFEST.json")) {
        [void](Assert-TsfDestination -Path (Join-Path $promptDir $name) -ApprovedRoot $requestedRoot)
    }
    [void](Assert-TsfDestination -Path (Join-Path $projectRoot "$($entry.prompt_id).zip") -ApprovedRoot $requestedRoot)
}
[void](Assert-TsfDestination -Path (Join-Path $projectRoot "EXPORT_INDEX.json") -ApprovedRoot $requestedRoot)

try {
    New-Item -ItemType Directory -Force -Path $requestedRoot | Out-Null
} catch {
    $requestedRoot = $fallbackCanonical
    $projectRoot = Assert-TsfDestination -Path (Join-Path $requestedRoot $projectId) -ApprovedRoot $requestedRoot
    foreach ($entry in $promptPlans) {
        [void](Assert-TsfDestination -Path (Join-Path $projectRoot $entry.prompt_id) -ApprovedRoot $requestedRoot)
        [void](Assert-TsfDestination -Path (Join-Path $projectRoot "$($entry.prompt_id).zip") -ApprovedRoot $requestedRoot)
    }
    New-Item -ItemType Directory -Force -Path $requestedRoot | Out-Null
}

New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
$exported = @()
foreach ($entry in $promptPlans) {
    $prompt = $entry.prompt
    $promptId = $entry.prompt_id
    $promptDir = Assert-TsfDestination -Path (Join-Path $projectRoot $promptId) -ApprovedRoot $requestedRoot
    New-Item -ItemType Directory -Force -Path $promptDir | Out-Null

    $sendText = @"
TSF Deep Research Request

Research project: $projectId
Prompt id: $promptId

Question:
$($prompt.research_question)

Required output:
- Include non-empty Summary, Findings, Recommendations, Caveats, and Sources sections.
- Express recommendations as explicit KEEP / CHANGE / ADD / REMOVE / DELAY lines.
- Include at least one recognizable public source locator or structured source entry.
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
        research_project_id = $projectId
        prompt_id = $promptId
        required_sections = @("summary", "findings", "recommendations", "caveats", "sources")
        citation_check = "BASIC_CITATION_PRESENCE_VALIDATED"
        claim_to_source_verification = $false
        advisory_only = $true
        hq_gate_required_for_adoption = $true
        forbidden_requests = @("secrets", "credentials", "api keys", "product repo", "canonical NWR", "normal NWR packets")
    }
    $manifest = [pscustomobject]@{
        schema_version = "tsf_deep_research_export_manifest_v1"
        research_project_id = $projectId
        prompt_id = $promptId
        created_at = (Get-Date).ToString("o")
        no_api_called = $true
        auto_submission_enabled = $false
        raw_repo_dump_included = $false
        product_repo_scope = $false
        canonical_nwr_scope = $false
        return_transport = "REPORT_FILE_ONLY_ZIP_RETURN_NOT_IMPLEMENTED"
        files = @("SEND_TO_CHATGPT_DEEP_RESEARCH.md", "RESEARCH_CONTEXT.md", "SOURCE_TRACE.csv", "REQUIRED_OUTPUT_CONTRACT.json", "RETURN_REPORT_IMPORT_INSTRUCTIONS.md", "RESEARCH_MANIFEST.json")
    }

    New-TsfTextFile -Path (Join-Path $promptDir "SEND_TO_CHATGPT_DEEP_RESEARCH.md") -Text $sendText -ApprovedRoot $requestedRoot
    New-TsfTextFile -Path (Join-Path $promptDir "RESEARCH_CONTEXT.md") -Text $contextText -ApprovedRoot $requestedRoot
    New-TsfTextFile -Path (Join-Path $promptDir "SOURCE_TRACE.csv") -Text $sourceTrace -ApprovedRoot $requestedRoot
    $contractPath = Assert-TsfDestination -Path (Join-Path $promptDir "REQUIRED_OUTPUT_CONTRACT.json") -ApprovedRoot $requestedRoot
    $contract | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $contractPath -Encoding UTF8
    New-TsfTextFile -Path (Join-Path $promptDir "RETURN_REPORT_IMPORT_INSTRUCTIONS.md") -Text "Return one completed UTF-8 Markdown report file under the approved TSF return root. ZIP return import is not implemented. Include the research_project_id, prompt_id, all required sections, source entries, and caveats. Do not include secrets or approvals." -ApprovedRoot $requestedRoot
    $manifestPath = Assert-TsfDestination -Path (Join-Path $promptDir "RESEARCH_MANIFEST.json") -ApprovedRoot $requestedRoot
    $manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    $zipPath = Assert-TsfDestination -Path (Join-Path $projectRoot "$promptId.zip") -ApprovedRoot $requestedRoot
    if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
    Compress-Archive -Path (Join-Path $promptDir "*") -DestinationPath $zipPath -Force
    $exported += [pscustomobject]@{ prompt_id = $promptId; package_dir = $promptDir; zip_path = $zipPath; zip_exists = (Test-Path -LiteralPath $zipPath) }
}

$index = [pscustomobject]@{
    schema_version = "tsf_deep_research_export_index_v1"
    research_project_id = $projectId
    created_at = (Get-Date).ToString("o")
    exported_prompt_count = @($exported).Count
    exports = $exported
    api_called = $false
    auto_submitted = $false
    return_zip_import_implemented = $false
}
$indexPath = Assert-TsfDestination -Path (Join-Path $projectRoot "EXPORT_INDEX.json") -ApprovedRoot $requestedRoot
$index | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $indexPath -Encoding UTF8
$index
