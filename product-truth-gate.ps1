[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Repo = ".",
    [string]$OutFile = "docs/codex/PRODUCT_TRUTH_REVIEW.md",
    [switch]$Write,
    [switch]$NoWrite
)

$ErrorActionPreference = "Stop"

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo not found: $Repo" -ForegroundColor Red
    exit 1
}

Set-Location $repoPath.Path

function Get-SectionLines {
    param(
        [string]$Text,
        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    $match = [regex]::Match($Text, "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n(?<body>.*?)(?=^##\s+|\z)")
    if (!$match.Success) { return @() }

    return @($match.Groups["body"].Value -split "\r?\n" |
        ForEach-Object { ([string]$_).Trim() } |
        Where-Object { $_ -match "^\-\s+.+" } |
        ForEach-Object { ($_ -replace "^\-\s+", "").Trim() } |
        Where-Object { ![string]::IsNullOrWhiteSpace($_) -and $_ -notmatch "^(none|n/a)$" })
}

function Get-ScanFiles {
    $roots = @("src", "app", "web", "pages", "components", "public", "content", "index.html")
    $extensions = @(".html", ".css", ".js", ".jsx", ".ts", ".tsx", ".vue", ".svelte", ".astro", ".mdx", ".json")
    $files = [System.Collections.Generic.List[string]]::new()

    foreach ($root in $roots) {
        if (!(Test-Path -LiteralPath $root)) { continue }
        $item = Get-Item -LiteralPath $root
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $item.FullName -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
                ForEach-Object { $files.Add($_.FullName) | Out-Null }
        } else {
            if ($extensions -contains $item.Extension.ToLowerInvariant()) {
                $files.Add($item.FullName) | Out-Null
            }
        }
    }

    return @($files | Sort-Object -Unique)
}

function Test-TextExists {
    param(
        [string[]]$Files,
        [string]$Needle
    )

    foreach ($file in $Files) {
        $content = Get-Content -LiteralPath $file -Raw -ErrorAction SilentlyContinue
        if ($null -ne $content -and $content.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) { return $true }
    }
    return $false
}

function Get-ApprovedHospitalitySynonyms {
    param([string]$Needle)

    $key = ([string]$Needle).Trim().ToLowerInvariant()
    $synonyms = @{
        "view menus" = @("View menu", "Menus", "Menu preview")
        "reserve a table" = @("Reserve", "Book a table")
        "private dining" = @("Private Dining", "Private room", "Private dinner")
        "request an event" = @("Request event", "Start your inquiry", "Plan a private dinner")
        "stop losing event leads." = @("Request event", "Start your inquiry", "Private dining", "events host")
        "training without the binder." = @("Tonight's lineup", "Training cards", "Acknowledge lineup", "lineup notes")
    }

    if ($synonyms.ContainsKey($key)) { return @($synonyms[$key]) }
    return @()
}

function Find-RequiredVisibleTextMatch {
    param(
        [string[]]$Files,
        [string]$Needle
    )

    if (Test-TextExists -Files $Files -Needle $Needle) {
        return [pscustomobject]@{ found = $true; matched = $Needle; via = "exact" }
    }

    foreach ($synonym in @(Get-ApprovedHospitalitySynonyms -Needle $Needle)) {
        if (Test-TextExists -Files $Files -Needle $synonym) {
            return [pscustomobject]@{ found = $true; matched = $synonym; via = "approved hospitality synonym" }
        }
    }

    return [pscustomobject]@{ found = $false; matched = ""; via = "" }
}

$truthPath = "docs/codex/PRODUCT_TRUTH.md"
$contractMissing = !(Test-Path -LiteralPath $truthPath)
$required = @()
$forbidden = @()

if (!$contractMissing) {
    $truth = Get-Content -LiteralPath $truthPath -Raw
    $required = @(Get-SectionLines -Text $truth -Heading "Required Visible Text")
    $forbidden = @(Get-SectionLines -Text $truth -Heading "Forbidden Visible Text")
}

$scanFiles = @(Get-ScanFiles)
$issues = [System.Collections.Generic.List[string]]::new()
$approvedMatches = [System.Collections.Generic.List[string]]::new()

if ($contractMissing) {
    $issues.Add("PRODUCT_TRUTH.md missing; no product-truth assertions are enforced.") | Out-Null
}

foreach ($text in $required) {
    $match = Find-RequiredVisibleTextMatch -Files $scanFiles -Needle $text
    if (!$match.found) {
        $issues.Add("Required visible text missing: $text") | Out-Null
    } elseif ($match.via -ne "exact") {
        $approvedMatches.Add("$text => $($match.matched)") | Out-Null
    }
}

foreach ($text in $forbidden) {
    if (Test-TextExists -Files $scanFiles -Needle $text) {
        $issues.Add("Forbidden visible text still present: $text") | Out-Null
    }
}

$status = if ($contractMissing) { "MISSING" } elseif ($issues.Count -gt 0) { "RED" } else { "GREEN" }
$report = @(
    "# Product Truth Review",
    "",
    "Status: $status",
    "",
    "## Contract",
    "",
    "Contract file: $truthPath",
    "Scanned files: $($scanFiles.Count)",
    "",
    "## Required Visible Text",
    ""
)

if ($required.Count -eq 0) { $report += "- None configured" } else { $required | ForEach-Object { $report += "- $_" } }
$report += @("", "## Forbidden Visible Text", "")
if ($forbidden.Count -eq 0) { $report += "- None configured" } else { $forbidden | ForEach-Object { $report += "- $_" } }
$report += @("", "## Approved Hospitality Synonym Matches", "")
if ($approvedMatches.Count -eq 0) { $report += "- None" } else { $approvedMatches | ForEach-Object { $report += "- $_" } }
$report += @("", "## Issues", "")
if ($issues.Count -eq 0) { $report += "- None" } else { $issues | ForEach-Object { $report += "- $_" } }

if ($Write -and !$NoWrite) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -LiteralPath $OutFile -Value $report -Encoding UTF8
}

$report | ForEach-Object { Write-Output $_ }

if ($status -eq "RED") { exit 1 }
exit 0
