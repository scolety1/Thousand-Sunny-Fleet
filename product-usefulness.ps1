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
    if ($loaded -is [array]) { return @($loaded) }
    if ($null -ne $loaded -and $loaded.PSObject.Properties.Name -contains "value") { return @($loaded.value) }
    if ($null -ne $loaded) { return @($loaded) }
    return @()
}

function Get-SectionText {
    param(
        [string]$Text,
        [string]$Heading
    )

    $pattern = "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Get-LineValue {
    param(
        [string]$Text,
        [string]$Label
    )

    $pattern = "(?im)^\s*$([regex]::Escape($Label))\s*:\s*(.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Test-IsFilledText {
    param([string]$Value)

    $trimmed = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { return $false }
    if ($trimmed -match "^(TODO|TBD|N/A|-|What can|What changed|What still|Specific improvement)$") { return $false }
    return $true
}

function Get-CheckedItems {
    param([string]$Text)

    $items = @()
    foreach ($line in ($Text -split "\r?\n")) {
        if ($line -match "^\s*-\s+\[[xX]\]\s+(.+?)\s*$") {
            $items += $matches[1].Trim()
        }
    }
    return @($items)
}

function Get-UncheckedTaskCount {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $path)) { return 0 }
    return @(Select-String -Path $path -Pattern "^\s*-\s+\[ \]\s+" -ErrorAction SilentlyContinue).Count
}

function Get-VisualIssueSummary {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\VISUAL_BUGS.md"
    if (!(Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{ Exists = $false; High = 0; Medium = 0; Low = 0 }
    }
    return [pscustomobject]@{
        Exists = $true
        High = @(Select-String -Path $path -Pattern "\[HIGH\]" -ErrorAction SilentlyContinue).Count
        Medium = @(Select-String -Path $path -Pattern "\[MEDIUM\]" -ErrorAction SilentlyContinue).Count
        Low = @(Select-String -Path $path -Pattern "\[LOW\]" -ErrorAction SilentlyContinue).Count
    }
}

function Get-CheckpointValue {
    param(
        [string]$RepoPath,
        [string]$Heading
    )

    $path = Join-Path $RepoPath "docs\codex\CHECKPOINT_REVIEW.md"
    if (!(Test-Path -LiteralPath $path)) { return "missing" }
    $text = Get-Content -LiteralPath $path -Raw
    $section = Get-SectionText -Text $text -Heading $Heading
    if ([string]::IsNullOrWhiteSpace($section)) { return "unknown" }
    return (($section -split "\r?\n" | Select-Object -First 1) -join "").Trim()
}

function Normalize-GateResult {
    param([string]$Value)

    $upper = ([string]$Value).Trim().ToUpperInvariant()
    if ([string]::IsNullOrWhiteSpace($upper) -or $upper -match "^TODO\b") {
        return ""
    }
    foreach ($allowed in @("CONTINUE", "REPAIR", "SIMPLIFY", "PARK", "NEEDS HUMAN DIRECTION")) {
        if ($upper -eq $allowed) { return $allowed }
    }
    if ($upper -match "(CONTINUE|REPAIR|SIMPLIFY|PARK|NEEDS HUMAN DIRECTION)") {
        return $matches[1]
    }
    return ""
}

function New-UsefulnessReview {
    param([object]$ProjectEntry)

    $repo = Resolve-Path ([string]$ProjectEntry.repo) -ErrorAction SilentlyContinue
    if (!$repo) {
        return [pscustomobject]@{
            Name = [string]$ProjectEntry.name
            Repo = [string]$ProjectEntry.repo
            Decision = "PARK"
            Reasons = @("Repo path not found.")
            CheckedImprovements = @()
            CheckedGateItems = @()
            MissingDocs = @()
            UsefulState = ""
            LastUsefulChange = ""
            MainFriction = ""
            SpecificImprovement = ""
            UncheckedTasks = 0
            Visual = [pscustomobject]@{ Exists = $false; High = 0; Medium = 0; Low = 0 }
            CheckpointVerdict = "missing"
        }
    }

    $repoPath = $repo.Path
    $path = Join-Path $repoPath "docs\codex\PRODUCT_USEFULNESS.md"
    $missingDocs = @()
    if (!(Test-Path -LiteralPath $path)) {
        $missingDocs += "docs\codex\PRODUCT_USEFULNESS.md"
    }

    $text = if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw } else { "" }
    $usefulState = Get-SectionText -Text $text -Heading "Current Useful State"
    $lastUsefulChange = Get-SectionText -Text $text -Heading "Last Useful Change"
    $mainFriction = Get-SectionText -Text $text -Heading "Main Friction"
    $nextImprovement = Get-SectionText -Text $text -Heading "Next Useful Improvement"
    $gateSection = Get-SectionText -Text $text -Heading "Usefulness Gate"
    $specificImprovement = Get-LineValue -Text $nextImprovement -Label "Specific improvement"
    $explicitGate = Normalize-GateResult -Value (Get-LineValue -Text $gateSection -Label "Gate result")
    $checkedImprovements = Get-CheckedItems -Text $nextImprovement
    $checkedGateItems = Get-CheckedItems -Text $gateSection
    $uncheckedTasks = Get-UncheckedTaskCount -RepoPath $repoPath
    $visual = Get-VisualIssueSummary -RepoPath $repoPath
    $checkpointVerdict = Get-CheckpointValue -RepoPath $repoPath -Heading "Verdict"
    $checkpointNextStep = Get-CheckpointValue -RepoPath $repoPath -Heading "Recommended Next Step"

    $reasons = @()
    $decision = ""

    if ($missingDocs.Count -gt 0) {
        $decision = "NEEDS HUMAN DIRECTION"
        $reasons += "Product usefulness doc is missing."
    }

    if ([string]::IsNullOrWhiteSpace($decision) -and ![string]::IsNullOrWhiteSpace($explicitGate) -and $explicitGate -ne "TODO") {
        $decision = $explicitGate
        $reasons += "Explicit gate result is set in PRODUCT_USEFULNESS.md."
    }

    if ([string]::IsNullOrWhiteSpace($decision)) {
        $filledBasics = (Test-IsFilledText $usefulState) -and (Test-IsFilledText $mainFriction) -and (Test-IsFilledText $specificImprovement)
        if (!$filledBasics) {
            $decision = "NEEDS HUMAN DIRECTION"
            $reasons += "Usefulness doc has unfilled product truth fields."
        } elseif ($visual.High -gt 0 -or $checkpointVerdict -eq "RED") {
            $decision = "REPAIR"
            $reasons += "High visual issue or RED checkpoint requires repair."
        } elseif ($checkedImprovements -contains "repair or regression risk" -or $checkpointNextStep -eq "patch first") {
            $decision = "REPAIR"
            $reasons += "Next useful improvement or checkpoint asks for repair."
        } elseif ($checkedGateItems.Count -lt 5) {
            $decision = "SIMPLIFY"
            $reasons += "Not all usefulness gate checks are satisfied."
        } elseif ($uncheckedTasks -eq 0 -and !(Test-IsFilledText $specificImprovement)) {
            $decision = "PARK"
            $reasons += "No unchecked tasks and no specific next improvement."
        } else {
            $decision = "CONTINUE"
            $reasons += "Usefulness gate is filled and no blocking repair signal was found."
        }
    }

    return [pscustomobject]@{
        Name = [string]$ProjectEntry.name
        Repo = $repoPath
        Decision = $decision
        Reasons = $reasons
        CheckedImprovements = @($checkedImprovements)
        CheckedGateItems = @($checkedGateItems)
        MissingDocs = @($missingDocs)
        UsefulState = $usefulState
        LastUsefulChange = $lastUsefulChange
        MainFriction = $mainFriction
        SpecificImprovement = $specificImprovement
        UncheckedTasks = $uncheckedTasks
        Visual = $visual
        CheckpointVerdict = $checkpointVerdict
        CheckpointNextStep = $checkpointNextStep
    }
}

function Format-UsefulnessMarkdown {
    param([object]$Review)

    $lines = @(
        "# Product Usefulness Review",
        "",
        "Generated: $(Get-Date -Format o)",
        "",
        "## Decision",
        "",
        "Decision: $($Review.Decision)",
        "",
        "Unchecked tasks: $($Review.UncheckedTasks)",
        "",
        "Checkpoint verdict: $($Review.CheckpointVerdict)",
        "",
        "Checkpoint next step: $($Review.CheckpointNextStep)",
        "",
        "Visual issues: high $($Review.Visual.High), medium $($Review.Visual.Medium), low $($Review.Visual.Low)",
        "",
        "## Reasons",
        ""
    )

    if ($Review.Reasons.Count -eq 0) {
        $lines += "- No issues found."
    } else {
        foreach ($reason in $Review.Reasons) { $lines += "- $reason" }
    }

    $lines += ""
    $lines += "## Product Truth"
    $lines += ""
    $lines += "- Current useful state: $(if (Test-IsFilledText $Review.UsefulState) { ($Review.UsefulState -replace '\r?\n', ' ') } else { 'missing' })"
    $lines += "- Last useful change: $(if (Test-IsFilledText $Review.LastUsefulChange) { ($Review.LastUsefulChange -replace '\r?\n', ' ') } else { 'missing' })"
    $lines += "- Main friction: $(if (Test-IsFilledText $Review.MainFriction) { ($Review.MainFriction -replace '\r?\n', ' ') } else { 'missing' })"
    $lines += "- Specific improvement: $(if (Test-IsFilledText $Review.SpecificImprovement) { $Review.SpecificImprovement } else { 'missing' })"

    $lines += ""
    $lines += "## Checked Improvement Areas"
    $lines += ""
    if ($Review.CheckedImprovements.Count -eq 0) {
        $lines += "- None"
    } else {
        foreach ($item in $Review.CheckedImprovements) { $lines += "- $item" }
    }

    $lines += ""
    $lines += "## Checked Gate Items"
    $lines += ""
    if ($Review.CheckedGateItems.Count -eq 0) {
        $lines += "- None"
    } else {
        foreach ($item in $Review.CheckedGateItems) { $lines += "- $item" }
    }

    $lines += ""
    $lines += "## Missing Docs"
    $lines += ""
    if ($Review.MissingDocs.Count -eq 0) {
        $lines += "- None"
    } else {
        foreach ($doc in $Review.MissingDocs) { $lines += "- $doc" }
    }

    $lines += ""
    $lines += "## Next Action"
    $lines += ""
    switch ($Review.Decision) {
        "CONTINUE" { $lines += "- Ship is eligible for another useful batch." }
        "REPAIR" { $lines += "- Run a repair-first batch before mission-forward work." }
        "SIMPLIFY" { $lines += "- Simplify the next task and reduce product complexity before continuing." }
        "PARK" { $lines += "- Park this ship until a new useful outcome is identified." }
        "NEEDS HUMAN DIRECTION" { $lines += "- Fill product truth fields or ask for clearer direction before another autonomous loop." }
        default { $lines += "- Review manually." }
    }

    return ($lines -join "`n")
}

function Write-UsefulnessReview {
    param([object]$Review)

    $outPath = Join-Path $Review.Repo "docs\codex\PRODUCT_USEFULNESS_REVIEW.md"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
    Set-Content -LiteralPath $outPath -Value (Format-UsefulnessMarkdown -Review $Review)
}

Set-Location $fleetRoot
$projects = Get-Projects -Path $Config
if ($projects.Count -eq 0) { Stop-WithMessage "No projects found in $Config" }
if (!$All -and [string]::IsNullOrWhiteSpace($Project)) { Stop-WithMessage "Specify -Project ShipName or -All." }

$selected = if ($All) { @($projects) } else { @($projects | Where-Object { $_.name -eq $Project }) }
if ($selected.Count -eq 0) { Stop-WithMessage "Project not found: $Project" }

$reviews = @()
foreach ($entry in $selected) {
    $review = New-UsefulnessReview -ProjectEntry $entry
    $reviews += $review

    if (!$NoWrite -and (Test-Path -LiteralPath $review.Repo)) {
        Write-UsefulnessReview -Review $review
    }

    $color = switch ($review.Decision) {
        "CONTINUE" { "Green" }
        "REPAIR" { "Yellow" }
        "SIMPLIFY" { "Yellow" }
        "PARK" { "Red" }
        "NEEDS HUMAN DIRECTION" { "Magenta" }
        default { "White" }
    }
    Write-Host ("{0}: {1}" -f $review.Name, $review.Decision) -ForegroundColor $color
    foreach ($reason in $review.Reasons) {
        Write-Host "  - $reason"
    }
}

if ($Enforce) {
    $blocked = @($reviews | Where-Object { $_.Decision -in @("PARK", "NEEDS HUMAN DIRECTION") })
    if ($blocked.Count -gt 0) {
        Write-Host "Usefulness enforcement failed for $($blocked.Count) ship(s)." -ForegroundColor Red
        exit 1
    }
}

exit 0
