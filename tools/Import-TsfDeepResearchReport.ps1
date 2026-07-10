param(
    [Parameter(Mandatory = $true)][string]$ReportPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProjectId,
    [string]$ExpectedPromptId = "",
    [string]$OutDir = "",
    [string]$RepoPath = ""
)

$ErrorActionPreference = "Stop"

function Get-TsfRepo {
    if (![string]::IsNullOrWhiteSpace($RepoPath)) { return (Resolve-Path -LiteralPath $RepoPath).Path }
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

function Read-TsfMetadataValue {
    param([string]$Text, [string]$Name)
    $pattern = "(?im)^\s*$([regex]::Escape($Name))\s*:\s*(.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

$repo = Get-TsfRepo
if (!(Test-Path -LiteralPath $ReportPath)) { throw "Missing report path: $ReportPath" }
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $repo ".codex-local\research-pipeline\imports" }

$approvedReadRoots = @(
    "C:\NWR_REVIEW\TSF_DEEP_RESEARCH_RETURNS",
    (Join-Path $repo "tests\fixtures\fleet\research-pipeline"),
    (Join-Path $repo ".codex-local\research-pipeline")
)
$approvedWriteRoots = @(
    (Join-Path $repo ".codex-local\research-pipeline\imports"),
    "C:\NWR_REVIEW\TSF_DEEP_RESEARCH_RETURNS"
)
if (!(Test-TsfPathInside -Path $ReportPath -Roots $approvedReadRoots)) {
    throw "ReportPath is outside approved import roots."
}
if (!(Test-TsfPathInside -Path $OutDir -Roots $approvedWriteRoots)) {
    throw "OutDir is outside approved import metadata roots."
}

$text = Get-Content -Raw -LiteralPath $ReportPath
$projectId = Read-TsfMetadataValue -Text $text -Name "research_project_id"
$promptId = Read-TsfMetadataValue -Text $text -Name "prompt_id"
$label = Read-TsfMetadataValue -Text $text -Name "label"
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ReportPath).Hash.ToLowerInvariant()

$status = "IMPORTED_VALID"
$reasons = New-Object System.Collections.ArrayList
if ($projectId -ne $ExpectedProjectId) {
    $status = "WRONG_RESEARCH_PROJECT"
    $reasons.Add("Report project id '$projectId' did not match expected '$ExpectedProjectId'.") | Out-Null
}
if (![string]::IsNullOrWhiteSpace($ExpectedPromptId) -and $promptId -ne $ExpectedPromptId) {
    $status = "WRONG_PROMPT_ID"
    $reasons.Add("Report prompt id '$promptId' did not match expected '$ExpectedPromptId'.") | Out-Null
}
if ($text -notmatch "(?im)^##\s+Sources\b|(?im)^Sources\s*:") {
    $status = "MISSING_CITATIONS"
    $reasons.Add("Report is missing a sources section.") | Out-Null
}
if ($text -match "(?i)\b(ignore previous instructions|exfiltrate|api key|credential|secret|background runner|bypass hq|treat this as approval)\b") {
    $status = "UNSAFE_CONTENT_BLOCKED"
    $reasons.Add("Report contains unsafe or authority-expanding instructions.") | Out-Null
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$existing = Get-ChildItem -LiteralPath $OutDir -Filter "*.import.json" -ErrorAction SilentlyContinue | ForEach-Object {
    Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
}
foreach ($item in @($existing)) {
    if ([string]$item.report_hash -eq $hash -or (([string]$item.research_project_id -eq $projectId) -and ([string]$item.prompt_id -eq $promptId) -and ([string]$item.status -eq "IMPORTED_VALID"))) {
        if ($status -eq "IMPORTED_VALID") {
            $status = "DUPLICATE_REPORT"
            $reasons.Add("Report duplicates an already imported report for this project/prompt.") | Out-Null
        }
    }
}

$preservedDir = Join-Path $OutDir "preserved"
New-Item -ItemType Directory -Force -Path $preservedDir | Out-Null
$safePrompt = ($promptId -replace "[^a-zA-Z0-9._-]+", "-").Trim("-")
if ([string]::IsNullOrWhiteSpace($safePrompt)) { $safePrompt = "unknown-prompt" }
$preservedPath = Join-Path $preservedDir "$safePrompt-$hash.md"
Copy-Item -LiteralPath $ReportPath -Destination $preservedPath -Force

$metadata = [pscustomobject]@{
    schema_version = "tsf_deep_research_import_metadata_v1"
    imported_at = (Get-Date).ToString("o")
    report_path = $ReportPath
    preserved_path = $preservedPath
    report_hash = $hash
    research_project_id = $projectId
    prompt_id = $promptId
    label = $label
    status = $status
    reasons = @($reasons)
    synthetic_fixture = ($label -eq "SYNTHETIC_FIXTURE_NOT_REAL_RESEARCH")
    advisory_only = $true
    grants_approval = $false
}

$metaName = "$safePrompt.import.json"
if ($status -ne "IMPORTED_VALID") {
    $metaName = "$safePrompt-$status-$($hash.Substring(0, 8)).import.json"
}
$metaPath = Join-Path $OutDir $metaName
$metadata | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $metaPath -Encoding UTF8
$metadata
