param(
    [Parameter(Mandatory = $true)][string]$ImportMetadataDir,
    [Parameter(Mandatory = $true)][string]$PlanPath,
    [string]$OutDir = "",
    [string]$RepoPath = ""
)

$ErrorActionPreference = "Stop"
$requiredSections = @("Summary", "Findings", "Recommendations", "Caveats", "Sources")

function Get-TsfRepo {
    if (![string]::IsNullOrWhiteSpace($RepoPath)) { return (Resolve-Path -LiteralPath $RepoPath).Path }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
}

function Get-TsfCanonicalPath {
    param([Parameter(Mandatory = $true)][string]$Path)
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

function Get-TsfMeaningfulLines {
    param([string]$Text)
    return @($Text -split '\r?\n' | ForEach-Object { ($_ -replace '^\s*[-*]\s+', '').Trim() } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
}

function Get-TsfRecommendations {
    param([string]$Text)
    $rows = @()
    foreach ($line in @($Text -split '\r?\n')) {
        $match = [regex]::Match($line, '^\s*[-*]?\s*(KEEP|CHANGE|ADD|REMOVE|DELAY)\b\s*(?:[:\-]\s*)?(.+?)\s*$', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if ($match.Success -and ![string]::IsNullOrWhiteSpace($match.Groups[2].Value)) {
            $item = $match.Groups[2].Value.Trim().TrimEnd('.')
            $rows += [pscustomobject]@{
                decision = $match.Groups[1].Value.ToUpperInvariant()
                item = $item
                normalized_item = (($item.ToLowerInvariant() -replace '[^a-z0-9]+', ' ').Trim() -replace '\s+', ' ')
                source_line = $line.Trim()
            }
        }
    }
    return $rows
}

function Write-TsfCsv {
    param([object[]]$Rows, [string]$Path)
    $parent = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    @($Rows) | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
}

$repo = Get-TsfRepo
if (!(Test-Path -LiteralPath $ImportMetadataDir -PathType Container)) { throw "Missing import metadata dir: $ImportMetadataDir" }
if (!(Test-Path -LiteralPath $PlanPath -PathType Leaf)) { throw "Missing plan path: $PlanPath" }
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = Join-Path $repo ".codex-local\research-pipeline\synthesis" }

$plan = Get-Content -Raw -LiteralPath $PlanPath | ConvertFrom-Json
$expectedProjectId = [string]$plan.research_project_id
$expectedPromptIds = @($plan.prompts | ForEach-Object { [string]$_.prompt_id })
if ($expectedPromptIds.Count -lt 1) { throw "Plan has no expected prompt IDs." }
$metadataRoot = Get-TsfCanonicalPath -Path $ImportMetadataDir
$preservedRoot = Get-TsfCanonicalPath -Path (Join-Path $metadataRoot "preserved")
$imports = @(Get-ChildItem -LiteralPath $metadataRoot -Filter "*.import.json" -File | Sort-Object Name | ForEach-Object {
    $record = Get-Content -Raw -LiteralPath $_.FullName | ConvertFrom-Json
    $record | Add-Member -NotePropertyName metadata_path -NotePropertyValue $_.FullName -Force
    $record
})

$excluded = New-Object System.Collections.ArrayList
$preCandidates = New-Object System.Collections.ArrayList
foreach ($import in $imports) {
    $reason = ""
    if ([string]$import.status -ne "IMPORTED_VALID") { $reason = "STATUS_$([string]$import.status)" }
    elseif ([string]$import.research_project_id -ne $expectedProjectId) { $reason = "WRONG_RESEARCH_PROJECT" }
    elseif ([string]$import.prompt_id -notin $expectedPromptIds) { $reason = "UNEXPECTED_PROMPT_ID" }
    elseif (!(Test-Path -LiteralPath ([string]$import.preserved_path) -PathType Leaf)) { $reason = "PRESERVED_REPORT_MISSING" }
    elseif (!(Test-TsfPathInside -Path ([string]$import.preserved_path) -Roots @($preservedRoot))) { $reason = "PRESERVED_REPORT_OUTSIDE_IMPORT_ROOT" }
    elseif ((Get-FileHash -Algorithm SHA256 -LiteralPath ([string]$import.preserved_path)).Hash.ToLowerInvariant() -ne [string]$import.report_hash) { $reason = "PRESERVED_REPORT_HASH_MISMATCH" }
    if (![string]::IsNullOrWhiteSpace($reason)) {
        [void]$excluded.Add([pscustomobject]@{ prompt_id = [string]$import.prompt_id; report_hash = [string]$import.report_hash; status = [string]$import.status; exclusion_reason = $reason; metadata_file = (Split-Path -Leaf ([string]$import.metadata_path)) })
    } else {
        [void]$preCandidates.Add($import)
    }
}

$eligible = New-Object System.Collections.ArrayList
$missing = New-Object System.Collections.ArrayList
foreach ($promptId in $expectedPromptIds) {
    $matches = @($preCandidates | Where-Object { [string]$_.prompt_id -eq $promptId })
    if ($matches.Count -ne 1) {
        [void]$missing.Add($promptId)
        foreach ($duplicateCandidate in $matches) {
            [void]$excluded.Add([pscustomobject]@{ prompt_id = $promptId; report_hash = [string]$duplicateCandidate.report_hash; status = [string]$duplicateCandidate.status; exclusion_reason = "DUPLICATE_ELIGIBLE_PROMPT_IMPORT"; metadata_file = (Split-Path -Leaf ([string]$duplicateCandidate.metadata_path)) })
        }
        continue
    }

    $candidate = $matches[0]
    $body = Get-Content -Raw -LiteralPath ([string]$candidate.preserved_path) -Encoding UTF8
    $sections = Get-TsfMarkdownSections -Text $body
    $missingRequired = @($requiredSections | Where-Object { !$sections.ContainsKey($_.ToLowerInvariant()) -or [string]::IsNullOrWhiteSpace([string]$sections[$_.ToLowerInvariant()]) })
    $recommendations = if ($sections.ContainsKey("recommendations")) { @(Get-TsfRecommendations -Text ([string]$sections["recommendations"])) } else { @() }
    if ($missingRequired.Count -gt 0 -or $recommendations.Count -eq 0) {
        [void]$missing.Add($promptId)
        $why = if ($missingRequired.Count -gt 0) { "MISSING_OR_EMPTY_REQUIRED_SECTIONS_$($missingRequired -join '_')" } else { "NO_STRUCTURED_DECISION_SIGNAL" }
        [void]$excluded.Add([pscustomobject]@{ prompt_id = $promptId; report_hash = [string]$candidate.report_hash; status = [string]$candidate.status; exclusion_reason = $why; metadata_file = (Split-Path -Leaf ([string]$candidate.metadata_path)) })
        continue
    }
    [void]$eligible.Add([pscustomobject]@{ metadata = $candidate; sections = $sections; recommendations = $recommendations })
}

$comparison = @()
$claims = @()
$decisions = @()
$claimIndex = 1
foreach ($report in @($eligible | Sort-Object { [string]$_.metadata.prompt_id })) {
    $promptId = [string]$report.metadata.prompt_id
    $hash = [string]$report.metadata.report_hash
    $summary = [string]$report.sections["summary"]
    $findings = @(Get-TsfMeaningfulLines -Text ([string]$report.sections["findings"]))
    $caveats = @(Get-TsfMeaningfulLines -Text ([string]$report.sections["caveats"]))
    $sources = @(Get-TsfMeaningfulLines -Text ([string]$report.sections["sources"]))
    $comparison += [pscustomobject]@{
        prompt_id = $promptId
        report_hash = $hash
        summary = ($summary -replace '\r?\n', ' ').Trim()
        finding_count = $findings.Count
        recommendation_count = @($report.recommendations).Count
        caveat_count = $caveats.Count
        source_entry_count = $sources.Count
        synthetic_fixture = [bool]$report.metadata.synthetic_fixture
    }
    foreach ($finding in $findings) {
        $claims += [pscustomobject]@{ claim_id = "claim-{0:D3}" -f $claimIndex; claim = $finding; claim_type = "FINDING"; prompt_id = $promptId; report_hash = $hash; source_entries = ($sources -join " | "); confidence = "SINGLE_REPORT_UNCORROBORATED" }
        $claimIndex++
    }
    foreach ($recommendation in @($report.recommendations)) {
        $decisions += [pscustomobject]@{
            decision = $recommendation.decision
            item = $recommendation.item
            rationale = "Explicit recommendation signal from imported report; caveats: $($caveats -join ' | ')"
            prompt_id = $promptId
            report_hash = $hash
            source_line = $recommendation.source_line
            source_entries = ($sources -join " | ")
            evidence_strength = "SINGLE_REPORT_UNCORROBORATED"
            normalized_item = $recommendation.normalized_item
        }
    }
}

$agreements = @()
$disagreements = @()
$agreementIndex = 1
$disagreementIndex = 1
foreach ($itemGroup in @($decisions | Group-Object normalized_item | Sort-Object Name)) {
    $decisionNames = @($itemGroup.Group | ForEach-Object { [string]$_.decision } | Sort-Object -Unique)
    $promptIds = @($itemGroup.Group | ForEach-Object { [string]$_.prompt_id } | Sort-Object -Unique)
    if ($decisionNames.Count -gt 1) {
        $disagreements += [pscustomobject]@{ disagreement_id = "disagreement-{0:D3}" -f $disagreementIndex; topic = $itemGroup.Name; decisions = ($decisionNames -join " | "); prompt_ids = ($promptIds -join " | "); status = "UNRESOLVED_ADVISORY_DISAGREEMENT"; resolution = "Preserve uncertainty; human decision required." }
        $disagreementIndex++
    } elseif ($promptIds.Count -gt 1) {
        $agreements += [pscustomobject]@{ agreement_id = "agreement-{0:D3}" -f $agreementIndex; topic = $itemGroup.Name; decision = $decisionNames[0]; prompt_ids = ($promptIds -join " | "); report_count = $itemGroup.Count }
        $agreementIndex++
        foreach ($decision in $itemGroup.Group) { $decision.evidence_strength = "MULTI_REPORT_AGREEMENT" }
    }
}
if ($agreements.Count -eq 0) { $agreements = @([pscustomobject]@{ agreement_id = "none"; topic = ""; decision = ""; prompt_ids = ""; report_count = 0 }) }
if ($disagreements.Count -eq 0) { $disagreements = @([pscustomobject]@{ disagreement_id = "none"; topic = ""; decisions = ""; prompt_ids = ""; status = "NO_CONTENT_DERIVED_DISAGREEMENT_DETECTED"; resolution = "No shared recommendation subject had conflicting explicit decision signals." }) }
if ($comparison.Count -eq 0) { $comparison = @([pscustomobject]@{ prompt_id = ""; report_hash = ""; summary = ""; finding_count = 0; recommendation_count = 0; caveat_count = 0; source_entry_count = 0; synthetic_fixture = $false }) }
if ($claims.Count -eq 0) { $claims = @([pscustomobject]@{ claim_id = "none"; claim = ""; claim_type = "NO_ELIGIBLE_CLAIMS"; prompt_id = ""; report_hash = ""; source_entries = ""; confidence = "INSUFFICIENT_EVIDENCE" }) }
if ($decisions.Count -eq 0) { $decisions = @([pscustomobject]@{ decision = "DELAY"; item = "Synthesis decision"; rationale = "Insufficient eligible report evidence."; prompt_id = ""; report_hash = ""; source_line = ""; source_entries = ""; evidence_strength = "INSUFFICIENT_EVIDENCE"; normalized_item = "synthesis decision" }) }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Write-TsfCsv -Rows $comparison -Path (Join-Path $OutDir "research_report_comparison_matrix.csv")
Write-TsfCsv -Rows $claims -Path (Join-Path $OutDir "research_claim_evidence_matrix.csv")
Write-TsfCsv -Rows $agreements -Path (Join-Path $OutDir "research_agreement_register.csv")
Write-TsfCsv -Rows $disagreements -Path (Join-Path $OutDir "research_disagreement_register.csv")
Write-TsfCsv -Rows @($decisions | Select-Object decision, item, rationale, prompt_id, report_hash, source_line, source_entries, evidence_strength) -Path (Join-Path $OutDir "research_keep_change_add_remove_delay.csv")
Write-TsfCsv -Rows @($excluded) -Path (Join-Path $OutDir "research_excluded_imports.csv")

$verdict = if ($missing.Count -eq 0 -and $eligible.Count -eq $expectedPromptIds.Count) { "GREEN_CONTENT_DERIVED_SYNTHESIS_READY_FOR_ADVISORY_REVIEW" } else { "YELLOW_SYNTHESIS_INSUFFICIENT_ELIGIBLE_REPORT_CONTENT" }
$decisionOutput = [pscustomobject]@{
    schema_version = "tsf_deep_research_synthesis_decision_v2"
    research_project_id = $expectedProjectId
    generated_at = (Get-Date).ToString("o")
    verdict = $verdict
    eligible_report_count = $eligible.Count
    excluded_import_count = $excluded.Count
    missing_prompt_ids = @($missing)
    content_derived = $true
    deterministic_markdown_parser = $true
    advisory_only = $true
    grants_approval = $false
    uncertainty = if ($verdict -like "GREEN_*") { "Decisions remain advisory; single-report items are uncorroborated and caveats are preserved." } else { "Insufficient eligible report content; no GREEN synthesis claim is allowed." }
    recommended_next_action = "Human review inside a separately authorized TSF implementation gate."
    agreements = @($agreements)
    disagreements = @($disagreements)
    keep_change_add_remove_delay = @($decisions | Select-Object decision, item, rationale, prompt_id, report_hash, source_line, source_entries, evidence_strength)
    excluded_imports = @($excluded)
}
$decisionOutput | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath (Join-Path $OutDir "research_synthesis_decision.json") -Encoding UTF8
$validation = [pscustomobject]@{
    schema_version = "tsf_deep_research_synthesis_validation_v2"
    verdict = $verdict
    expected_project_id = $expectedProjectId
    expected_prompt_ids = $expectedPromptIds
    reports_compared = $eligible.Count
    excluded_imports = $excluded.Count
    missing_reports = @($missing)
    required_sections = $requiredSections
    content_derived = $true
    api_called = $false
    codex_worker_invoked = $false
    external_service_called = $false
    background_runner_started = $false
    research_treated_as_approval = $false
    grants_approval = $false
}
$validation | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $OutDir "research_synthesis_validation.json") -Encoding UTF8
$decisionOutput
