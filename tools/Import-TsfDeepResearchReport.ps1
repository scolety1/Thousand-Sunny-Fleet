param(
    [Parameter(Mandatory = $true)][string]$ReportPath,
    [Parameter(Mandatory = $true)][string]$ExpectedProjectId,
    [string]$ExpectedPromptId = "",
    [string]$OutDir = "",
    [string]$RepoPath = "",
    [int64]$MaxReportBytes = 2097152
)

$ErrorActionPreference = "Stop"
$requiredSections = @("Summary", "Findings", "Recommendations", "Caveats", "Sources")

function Get-TsfRepo {
    if (![string]::IsNullOrWhiteSpace($RepoPath)) { return (Resolve-Path -LiteralPath $RepoPath).Path }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

function Get-TsfCanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "Path cannot be empty." }
    return [System.IO.Path]::GetFullPath($Path)
}

function Test-TsfPathInside {
    param([string]$Path, [string[]]$Roots)
    $full = (Get-TsfCanonicalPath -Path $Path).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    foreach ($root in $Roots) {
        $rootFull = (Get-TsfCanonicalPath -Path $root).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        if ($full.Equals($rootFull, [System.StringComparison]::OrdinalIgnoreCase) -or $full.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
    }
    return $false
}

function Read-TsfMetadataValue {
    param([string]$Text, [string]$Name)
    $match = [regex]::Match($Text, "(?im)^\s*$([regex]::Escape($Name))\s*:\s*(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Get-TsfMarkdownSections {
    param([string]$Text)
    $sections = @{}
    $matches = [regex]::Matches($Text, '(?m)^##\s+([^\r\n#]+?)\s*$')
    for ($index = 0; $index -lt $matches.Count; $index++) {
        $name = $matches[$index].Groups[1].Value.Trim()
        $start = $matches[$index].Index + $matches[$index].Length
        $end = if ($index + 1 -lt $matches.Count) { $matches[$index + 1].Index } else { $Text.Length }
        $sections[$name.ToLowerInvariant()] = $Text.Substring($start, $end - $start).Trim()
    }
    return $sections
}

function Read-TsfUtf8Text {
    param([byte[]]$Bytes)
    $offset = 0
    if ($Bytes.Length -ge 2 -and (($Bytes[0] -eq 0xff -and $Bytes[1] -eq 0xfe) -or ($Bytes[0] -eq 0xfe -and $Bytes[1] -eq 0xff))) {
        throw "UTF-16 reports are not accepted; return UTF-8 Markdown."
    }
    if ($Bytes.Length -ge 3 -and $Bytes[0] -eq 0xef -and $Bytes[1] -eq 0xbb -and $Bytes[2] -eq 0xbf) { $offset = 3 }
    $encoding = New-Object System.Text.UTF8Encoding($false, $true)
    try { return $encoding.GetString($Bytes, $offset, $Bytes.Length - $offset) } catch { throw "Report is not valid UTF-8 text." }
}

$repo = Get-TsfRepo
if (!(Test-Path -LiteralPath $ReportPath -PathType Leaf)) { throw "Missing report path: $ReportPath" }
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $repo ".codex-local\research-pipeline\imports" }
$approvedReadRoots = @("C:\NWR_REVIEW\TSF_DEEP_RESEARCH_RETURNS", (Join-Path $repo "tests\fixtures\fleet\research-pipeline"), (Join-Path $repo ".codex-local\research-pipeline"))
$approvedWriteRoots = @((Join-Path $repo ".codex-local\research-pipeline\imports"), "C:\NWR_REVIEW\TSF_DEEP_RESEARCH_RETURNS")
if (!(Test-TsfPathInside -Path $ReportPath -Roots $approvedReadRoots)) { throw "ReportPath is outside approved import roots." }
if (!(Test-TsfPathInside -Path $OutDir -Roots $approvedWriteRoots)) { throw "OutDir is outside approved import metadata roots." }
if ($MaxReportBytes -lt 1 -or $MaxReportBytes -gt 10485760) { throw "MaxReportBytes must be between 1 byte and 10 MiB." }

$reportFile = Get-Item -LiteralPath $ReportPath
$hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ReportPath).Hash.ToLowerInvariant()
$text = ""
$encodingStatus = "UTF8_VALIDATED"
$readError = ""
if ($reportFile.Length -le $MaxReportBytes) {
    try { $text = Read-TsfUtf8Text -Bytes ([System.IO.File]::ReadAllBytes($reportFile.FullName)) } catch { $encodingStatus = "TEXT_ENCODING_REJECTED"; $readError = $_.Exception.Message }
}

$projectId = if ($encodingStatus -eq "UTF8_VALIDATED") { Read-TsfMetadataValue -Text $text -Name "research_project_id" } else { "" }
$promptId = if ($encodingStatus -eq "UTF8_VALIDATED") { Read-TsfMetadataValue -Text $text -Name "prompt_id" } else { "" }
$label = if ($encodingStatus -eq "UTF8_VALIDATED") { Read-TsfMetadataValue -Text $text -Name "label" } else { "" }
$sections = if ($encodingStatus -eq "UTF8_VALIDATED") { Get-TsfMarkdownSections -Text $text } else { @{} }
$missingSections = @($requiredSections | Where-Object { !$sections.ContainsKey($_.ToLowerInvariant()) -or [string]::IsNullOrWhiteSpace([string]$sections[$_.ToLowerInvariant()]) })
$sourcesText = if ($sections.ContainsKey("sources")) { [string]$sections["sources"] } else { "" }
$hasSourceLocator = $sourcesText -match '(?im)(https?://\S+|doi:\s*\S+|\[[0-9]+\]|^\s*[-*]\s+\S+|^\s*[A-Za-z0-9._-]+\s*\|\s*\S+)'
$unsafe = (
    $text -match '(?i)\bignore (all |any )?(previous|prior) instructions\b' -or
    $text -match '(?i)\bexfiltrat(e|ion)\b' -or
    $text -match '(?i)\b(use|reveal|send|provide|expose)\b.{0,40}\b(api[ -]?key|credential|secret)\b' -or
    $text -match '(?i)\b(start|enable|launch)\b.{0,30}\bbackground runner\b' -or
    $text -match '(?i)\bbypass hq\b' -or
    $text -match '(?i)\btreat this as approval\b' -or
    $text -match '(?i)\bgrant(s|ed)? approval\b'
)

$status = "IMPORTED_VALID"
$reasons = New-Object System.Collections.ArrayList
if ($reportFile.Length -gt $MaxReportBytes) {
    $status = "INCOMPLETE_REPORT_TOO_LARGE"
    $reasons.Add("Report size $($reportFile.Length) exceeds the $MaxReportBytes byte limit.") | Out-Null
} elseif ($encodingStatus -ne "UTF8_VALIDATED") {
    $status = "REJECTED_TEXT_ENCODING"
    $reasons.Add($readError) | Out-Null
} elseif ($unsafe) {
    $status = "UNSAFE_CONTENT_BLOCKED"
    $reasons.Add("Report contains unsafe or authority-expanding instruction text.") | Out-Null
} elseif ($projectId -ne $ExpectedProjectId) {
    $status = "WRONG_RESEARCH_PROJECT"
    $reasons.Add("Report project id '$projectId' did not match expected '$ExpectedProjectId'.") | Out-Null
} elseif (![string]::IsNullOrWhiteSpace($ExpectedPromptId) -and $promptId -ne $ExpectedPromptId) {
    $status = "WRONG_PROMPT_ID"
    $reasons.Add("Report prompt id '$promptId' did not match expected '$ExpectedPromptId'.") | Out-Null
} elseif ($missingSections.Count -gt 0) {
    $status = "INCOMPLETE_REPORT"
    $reasons.Add("Required non-empty sections missing: $($missingSections -join ', ').") | Out-Null
} elseif (!$hasSourceLocator) {
    $status = "INCOMPLETE_SOURCES"
    $reasons.Add("Sources section lacks a recognizable locator, citation marker, or structured source entry.") | Out-Null
}

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$existing = @(Get-ChildItem -LiteralPath $OutDir -Filter "*.import.json" -File -ErrorAction SilentlyContinue | ForEach-Object { Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json })
if ($status -eq "IMPORTED_VALID") {
    foreach ($item in $existing) {
        if ([string]$item.report_hash -eq $hash -or (([string]$item.research_project_id -eq $projectId) -and ([string]$item.prompt_id -eq $promptId -and [string]$item.status -eq "IMPORTED_VALID"))) {
            $status = "DUPLICATE_REPORT"
            $reasons.Add("Report duplicates an already imported report for this project/prompt.") | Out-Null
            break
        }
    }
}

$preservedDir = Join-Path $OutDir "preserved"
New-Item -ItemType Directory -Force -Path $preservedDir | Out-Null
$safePrompt = ($promptId -replace '[^a-zA-Z0-9._-]+', '-').Trim('-')
if ([string]::IsNullOrWhiteSpace($safePrompt)) { $safePrompt = "unknown-prompt" }
$preservedPath = Join-Path $preservedDir "$safePrompt-$hash.md"
if (!(Test-TsfPathInside -Path $preservedPath -Roots @($preservedDir))) { throw "Preserved report destination escaped its approved root." }
Copy-Item -LiteralPath $ReportPath -Destination $preservedPath -Force

$metadata = [pscustomobject]@{
    schema_version = "tsf_deep_research_import_metadata_v1"
    imported_at = (Get-Date).ToString("o")
    report_path = $ReportPath
    preserved_path = $preservedPath
    report_hash = $hash
    report_size_bytes = [int64]$reportFile.Length
    max_report_size_bytes = $MaxReportBytes
    text_encoding_status = $encodingStatus
    research_project_id = $projectId
    prompt_id = $promptId
    label = $label
    status = $status
    reasons = @($reasons)
    required_sections = $requiredSections
    missing_or_empty_sections = @($missingSections)
    basic_citation_presence = [bool]$hasSourceLocator
    citation_validation = if ($hasSourceLocator) { "BASIC_CITATION_PRESENCE_VALIDATED" } else { "BASIC_CITATION_PRESENCE_NOT_VALIDATED" }
    claim_to_source_verification = $false
    synthetic_fixture = ($label -eq "SYNTHETIC_FIXTURE_NOT_REAL_RESEARCH")
    advisory_only = $true
    grants_approval = $false
}
$metaName = if ($status -eq "IMPORTED_VALID") { "$safePrompt.import.json" } else { "$safePrompt-$status-$($hash.Substring(0, 8)).import.json" }
$metaPath = Join-Path $OutDir $metaName
if (!(Test-TsfPathInside -Path $metaPath -Roots @($OutDir))) { throw "Import metadata destination escaped its approved root." }
$metadata | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $metaPath -Encoding UTF8
$metadata
