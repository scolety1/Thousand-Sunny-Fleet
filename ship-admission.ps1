[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Project = "",

    [string]$Config = ".\projects.json",

    [switch]$All,

    [switch]$NoWrite,

    [switch]$Enforce
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-Projects {
    param([string]$Path)

    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (!$resolved) {
        Stop-WithMessage "Project config not found: $Path"
    }

    $loaded = Get-Content -LiteralPath $resolved.Path -Raw | ConvertFrom-Json
    if ($loaded -is [array]) {
        return @($loaded)
    }
    if ($null -ne $loaded -and $loaded.PSObject.Properties.Name -contains "value") {
        return @($loaded.value)
    }
    if ($null -ne $loaded) {
        return @($loaded)
    }
    return @()
}

function Get-SectionText {
    param(
        [string]$Text,
        [string]$Heading
    )

    $pattern = "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return ""
}

function Get-SummaryValue {
    param(
        [string]$Text,
        [string]$Label
    )

    $pattern = "(?im)^\s*$([regex]::Escape($Label))\s*:\s*(.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return ""
}

function Convert-ToScore {
    param(
        [string]$Value,
        [int]$Weight
    )

    $trimmed = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed -match "^(TODO|TBD|N/A|-)$") {
        return $null
    }

    $numberMatch = [regex]::Match($trimmed, "-?\d+")
    if (!$numberMatch.Success) {
        return $null
    }

    $score = [int]$numberMatch.Value
    if ($score -lt 0) { $score = 0 }
    if ($score -gt $Weight) { $score = $Weight }
    return $score
}

function Get-ScoreRows {
    param([string]$Text)

    $rows = @()
    foreach ($line in ($Text -split "\r?\n")) {
        if ($line -notmatch "^\|") { continue }
        if ($line -match "^\|\s*-+") { continue }
        if ($line -match "\|\s*Criterion\s*\|") { continue }

        $cells = @($line.Trim().Trim("|") -split "\|" | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 4) { continue }
        if ($cells[0] -eq "Total") { continue }

        $weightMatch = [regex]::Match($cells[1], "\d+")
        if (!$weightMatch.Success) { continue }

        $weight = [int]$weightMatch.Value
        $score = Convert-ToScore -Value $cells[2] -Weight $weight
        $rows += [pscustomobject]@{
            Criterion = $cells[0]
            Weight = $weight
            Score = $score
            Evidence = $cells[3]
        }
    }
    return @($rows)
}

function Get-CheckedRedFlags {
    param([string]$Text)

    $redFlagSection = Get-SectionText -Text $Text -Heading "Red Flags"
    $flags = @()
    foreach ($line in ($redFlagSection -split "\r?\n")) {
        if ($line -match "^\s*-\s+\[[xX]\]\s+(.+?)\s*$") {
            $flags += $matches[1].Trim()
        }
    }
    return @($flags)
}

function Get-DocCompleteness {
    param([string]$RepoPath)

    $docs = @(
        "docs\codex\USER_JOB.md",
        "docs\codex\EVALUATORS.md",
        "docs\codex\SHIP_ADMISSION.md",
        "docs\codex\SHIP_SCORECARD.md",
        "docs\codex\PRODUCT_USEFULNESS.md"
    )

    $missing = @()
    foreach ($doc in $docs) {
        if (!(Test-Path -LiteralPath (Join-Path $RepoPath $doc))) {
            $missing += $doc
        }
    }
    return [pscustomobject]@{
        Required = $docs
        Missing = $missing
    }
}

function New-AdmissionReview {
    param([object]$ProjectEntry)

    $repo = Resolve-Path ([string]$ProjectEntry.repo) -ErrorAction SilentlyContinue
    if (!$repo) {
        return [pscustomobject]@{
            Name = [string]$ProjectEntry.name
            Repo = [string]$ProjectEntry.repo
            Decision = "PARK"
            Score = 0
            MaxScore = 100
            RedFlags = @("Repo path not found")
            MissingDocs = @()
            ScoreRows = @()
            Summary = @{}
            Reasons = @("Repo path not found.")
        }
    }

    $repoPath = $repo.Path
    $docState = Get-DocCompleteness -RepoPath $repoPath
    $scorecardPath = Join-Path $repoPath "docs\codex\SHIP_SCORECARD.md"
    $scorecard = if (Test-Path -LiteralPath $scorecardPath) { Get-Content -LiteralPath $scorecardPath -Raw } else { "" }
    $rows = if (![string]::IsNullOrWhiteSpace($scorecard)) { Get-ScoreRows -Text $scorecard } else { @() }
    $redFlags = if (![string]::IsNullOrWhiteSpace($scorecard)) { Get-CheckedRedFlags -Text $scorecard } else { @() }

    $score = 0
    $maxScore = 100
    $unknownScores = @()
    foreach ($row in $rows) {
        if ($null -eq $row.Score) {
            $unknownScores += $row.Criterion
        } else {
            $score += [int]$row.Score
        }
    }

    if ($rows.Count -gt 0) {
        $maxScore = ($rows | Measure-Object -Property Weight -Sum).Sum
    }

    $summary = [ordered]@{
        "Ship name" = Get-SummaryValue -Text $scorecard -Label "Ship name"
        "Primary user or buyer" = Get-SummaryValue -Text $scorecard -Label "Primary user or buyer"
        "Weekly job this replaces" = Get-SummaryValue -Text $scorecard -Label "Weekly job this replaces"
        "First useful version" = Get-SummaryValue -Text $scorecard -Label "First useful version"
        "Local evaluator" = Get-SummaryValue -Text $scorecard -Label "Local evaluator"
        "Current recommendation" = Get-SummaryValue -Text $scorecard -Label "Current recommendation"
    }

    $reasons = @()
    $decision = "ADMIT"
    if ($docState.Missing.Count -gt 0) {
        $decision = "REVISE"
        $reasons += "Missing required admission docs."
    }
    if ($rows.Count -eq 0) {
        $decision = "REVISE"
        $reasons += "Scorecard table is missing or unreadable."
    }
    if ($unknownScores.Count -gt 0) {
        $decision = "REVISE"
        $reasons += "Scorecard has unfilled scores."
    }
    if ($redFlags.Count -gt 0) {
        $decision = "PARK"
        $reasons += "One or more admission red flags are checked."
    }
    if ($decision -eq "ADMIT") {
        if ($score -lt 55) {
            $decision = "PARK"
            $reasons += "Score is below 55."
        } elseif ($score -lt 70) {
            $decision = "REVISE"
            $reasons += "Score is between 55 and 69."
        } else {
            $reasons += "Score is 70+ with no checked red flags."
        }
    }

    return [pscustomobject]@{
        Name = [string]$ProjectEntry.name
        Repo = $repoPath
        Decision = $decision
        Score = $score
        MaxScore = $maxScore
        RedFlags = $redFlags
        MissingDocs = @($docState.Missing)
        UnknownScores = $unknownScores
        ScoreRows = $rows
        Summary = $summary
        Reasons = $reasons
    }
}

function Format-AdmissionMarkdown {
    param([object]$Review)

    $lines = @(
        "# Ship Admission Review",
        "",
        "Generated: $(Get-Date -Format o)",
        "",
        "## Decision",
        "",
        "Decision: $($Review.Decision)",
        "",
        "Score: $($Review.Score) / $($Review.MaxScore)",
        "",
        "## Summary",
        ""
    )

    foreach ($key in $Review.Summary.Keys) {
        $value = [string]$Review.Summary[$key]
        if ([string]::IsNullOrWhiteSpace($value)) { $value = "missing" }
        $lines += "- ${key}: $value"
    }

    $lines += ""
    $lines += "## Reasons"
    $lines += ""
    if ($Review.Reasons.Count -eq 0) {
        $lines += "- No issues found."
    } else {
        foreach ($reason in $Review.Reasons) {
            $lines += "- $reason"
        }
    }

    $lines += ""
    $lines += "## Missing Docs"
    $lines += ""
    if ($Review.MissingDocs.Count -eq 0) {
        $lines += "- None"
    } else {
        foreach ($doc in $Review.MissingDocs) {
            $lines += "- $doc"
        }
    }

    $lines += ""
    $lines += "## Red Flags"
    $lines += ""
    if ($Review.RedFlags.Count -eq 0) {
        $lines += "- None checked"
    } else {
        foreach ($flag in $Review.RedFlags) {
            $lines += "- $flag"
        }
    }

    $lines += ""
    $lines += "## Score Rows"
    $lines += ""
    $lines += "| Criterion | Weight | Score | Evidence |"
    $lines += "| --- | ---: | ---: | --- |"
    foreach ($row in $Review.ScoreRows) {
        $score = if ($null -eq $row.Score) { "missing" } else { [string]$row.Score }
        $evidence = ([string]$row.Evidence).Replace("|", "/")
        $lines += "| $($row.Criterion) | $($row.Weight) | $score | $evidence |"
    }
    if ($Review.ScoreRows.Count -eq 0) {
        $lines += "| missing | 100 | missing | Scorecard table was not found or could not be parsed. |"
    }

    $lines += ""
    $lines += "## Next Action"
    $lines += ""
    switch ($Review.Decision) {
        "ADMIT" { $lines += "- Ship is eligible for meaningful autonomous runtime." }
        "REVISE" { $lines += "- Sharpen admission docs, evaluator, or task queue before meaningful runtime." }
        "PARK" { $lines += "- Park this ship unless a human explicitly approves redesign or override." }
    }

    return ($lines -join "`n")
}

function Write-AdmissionReview {
    param([object]$Review)

    $outPath = Join-Path $Review.Repo "docs\codex\SHIP_ADMISSION_REVIEW.md"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
    Set-Content -LiteralPath $outPath -Value (Format-AdmissionMarkdown -Review $Review)
}

Set-Location $fleetRoot
$projects = Get-Projects -Path $Config
if ($projects.Count -eq 0) {
    Stop-WithMessage "No projects found in $Config"
}

if (!$All -and [string]::IsNullOrWhiteSpace($Project)) {
    Stop-WithMessage "Specify -Project ShipName or -All."
}

$selected = if ($All) {
    @($projects)
} else {
    @($projects | Where-Object { $_.name -eq $Project })
}

if ($selected.Count -eq 0) {
    Stop-WithMessage "Project not found: $Project"
}

$reviews = @()
foreach ($entry in $selected) {
    $review = New-AdmissionReview -ProjectEntry $entry
    $reviews += $review

    if (!$NoWrite -and (Test-Path -LiteralPath $review.Repo)) {
        Write-AdmissionReview -Review $review
    }

    $color = switch ($review.Decision) {
        "ADMIT" { "Green" }
        "REVISE" { "Yellow" }
        "PARK" { "Red" }
        default { "White" }
    }
    Write-Host ("{0}: {1} ({2}/{3})" -f $review.Name, $review.Decision, $review.Score, $review.MaxScore) -ForegroundColor $color
    foreach ($reason in $review.Reasons) {
        Write-Host "  - $reason"
    }
}

if ($Enforce) {
    $blocked = @($reviews | Where-Object { $_.Decision -ne "ADMIT" })
    if ($blocked.Count -gt 0) {
        Write-Host "Admission enforcement failed for $($blocked.Count) ship(s)." -ForegroundColor Red
        exit 1
    }
}

exit 0

