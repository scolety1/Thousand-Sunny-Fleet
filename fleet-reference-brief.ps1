[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Project,

    [string]$FleetGroup = "",

    [switch]$All,

    [string]$ConfigPath = ".\projects.json",

    [switch]$Write,

    [switch]$Validate,

    [string]$OutPath = "out\reference-brief.md"
)

$ErrorActionPreference = "Continue"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-Projects {
    param([string]$Path)
    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (!$resolved) { Stop-WithMessage "Config not found: $Path" }
    $loaded = Get-Content -LiteralPath $resolved.Path -Raw | ConvertFrom-Json
    if ($loaded -is [array]) { return @($loaded) }
    if ($null -ne $loaded -and $loaded.PSObject.Properties.Name -contains "value") { return @($loaded.value) }
    if ($null -ne $loaded) { return @($loaded) }
    return @()
}

function Get-ConfigValue {
    param([object]$Object, [string]$Name, [object]$Default = "")
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Get-OperatingMode {
    param([string]$RepoPath)
    $path = Join-Path $RepoPath "docs\codex\OPERATING_MODE.md"
    if (!(Test-Path -LiteralPath $path)) { return "" }
    $text = Get-Content -LiteralPath $path -Raw
    $match = [regex]::Match($text, "(?im)^Mode:\s*(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function New-HospitalityBrief {
    param([object]$Ship)
    $name = [string](Get-ConfigValue -Object $Ship -Name "name" -Default "Ship")
    $demoName = [string](Get-ConfigValue -Object $Ship -Name "demoName" -Default $name)
    return @"
# Creative Reference Brief

Project: $name

Mode: hospitality-studio

Demo: $demoName

## Surface Type

Choose exactly one before coding: customer-facing restaurant page, guest-facing wine/menu list, manager/internal tool, or product sales page.

## Reference Qualities

- Atmospheric, editorial hospitality composition.
- Strong first-screen mood before feature proof.
- Confident whitespace and typographic hierarchy.
- Details are easy to find but not dumped immediately.
- Public pages should feel like a restaurant, menu, private event, or beverage page first; internal tools should feel like one calm service surface, not a dashboard.
- Main content should be partially revealed with clear paths to more, not all shown at once.
- Borrow quality, restraint, and rhythm only. Do not copy layouts, wording, brand marks, menus, images, or trade dress from reference sites.

## Emotional Target

The page should feel calm, specific, restaurant-grade, and worth showing to a real operator.

## First Screen Rules

- Show brand/place feeling.
- Show one primary promise.
- Show one primary action.
- Show one beautiful preview or detail.
- Hide secondary workflows, staff-only context, and implementation explanation until the user asks.
- If the product is a wine list, show the wine list first; "help me choose" is a clear secondary action.
- If the product is a manager tool, show the one useful working brief first; deeper details open after selection.

## Forbidden Patterns

- Dashboard dump.
- All features visible at once.
- "Everything on one page" proof layouts.
- Generic SaaS hero.
- Double headers or wrapper chrome.
- Long AI-brochure copy.
- Internal staff notes on a guest-facing first screen.
- Restaurant pages that look like admin software.

## Acceptance Lens

A stranger should understand the main restaurant job in under 30 seconds without feeling overloaded.
"@
}

function Test-ReferenceBrief {
    param([string]$RepoPath)
    $path = Join-Path $RepoPath "docs\codex\REFERENCE_BRIEF.md"
    $issues = [System.Collections.Generic.List[string]]::new()
    if (!(Test-Path -LiteralPath $path)) {
        $legacyPath = Join-Path $RepoPath "docs\codex\CREATIVE_BRIEF.md"
        if (Test-Path -LiteralPath $legacyPath) {
            $path = $legacyPath
        } else {
            $issues.Add("Missing docs/codex/REFERENCE_BRIEF.md") | Out-Null
            return @($issues)
        }
    }
    $text = Get-Content -LiteralPath $path -Raw
    foreach ($heading in @("Surface Type", "Reference Qualities", "Emotional Target", "First Screen Rules", "Forbidden Patterns", "Acceptance Lens")) {
        if ($text -notmatch "(?m)^## $([regex]::Escape($heading))\s*$") {
            $issues.Add("Missing section: $heading") | Out-Null
        }
    }
    foreach ($phrase in @("Do not copy", "first screen", "not dumped", "under 30 seconds")) {
        if ($text -notmatch [regex]::Escape($phrase)) {
            $issues.Add("Missing phrase: $phrase") | Out-Null
        }
    }
    return @($issues)
}

function Get-SelectedShips {
    param([object[]]$Ships)

    if ($All) { return @($Ships) }
    if (![string]::IsNullOrWhiteSpace($FleetGroup)) {
        return @($Ships | Where-Object { [string](Get-ConfigValue -Object $_ -Name "fleetGroup" -Default "") -eq $FleetGroup })
    }
    if (![string]::IsNullOrWhiteSpace($Project)) {
        return @($Ships | Where-Object { [string](Get-ConfigValue -Object $_ -Name "name" -Default "") -eq $Project })
    }

    Stop-WithMessage "Specify -Project, -FleetGroup, or -All."
}

$ships = @(Get-Projects -Path $ConfigPath)
$selectedShips = @(Get-SelectedShips -Ships $ships)
if ($selectedShips.Count -eq 0) {
    if (![string]::IsNullOrWhiteSpace($FleetGroup)) { Stop-WithMessage "No projects found for fleet group: $FleetGroup" }
    if (![string]::IsNullOrWhiteSpace($Project)) { Stop-WithMessage "Project not found: $Project" }
    Stop-WithMessage "No projects selected."
}

$reportLines = @(
    "# Reference Brief Gate",
    "",
    "Generated: $(Get-Date -Format o)",
    "",
    "Selection: $(if (![string]::IsNullOrWhiteSpace($Project)) { "Project=$Project" } elseif (![string]::IsNullOrWhiteSpace($FleetGroup)) { "FleetGroup=$FleetGroup" } else { "All" })",
    "",
    "## Ships",
    ""
)

$blocked = $false
foreach ($ship in $selectedShips) {
    $name = [string](Get-ConfigValue -Object $ship -Name "name" -Default "Ship")
    $repo = Resolve-Path -LiteralPath ([string](Get-ConfigValue -Object $ship -Name "repo" -Default "")) -ErrorAction SilentlyContinue
    if (!$repo) {
        $blocked = $true
        $reportLines += "- ${name}: BLOCK - repo not found"
        continue
    }
    $mode = Get-OperatingMode -RepoPath $repo.Path

    if ($Write) {
        $outFile = Join-Path $repo.Path "docs\codex\REFERENCE_BRIEF.md"
        New-Item -ItemType Directory -Force -Path (Split-Path $outFile) | Out-Null
        if ($mode -eq "hospitality-studio") {
            Set-Content -LiteralPath $outFile -Value (New-HospitalityBrief -Ship $ship) -Encoding UTF8
        } else {
            Set-Content -LiteralPath $outFile -Value "# Reference Brief`n`nProject: $name`n`nMode: $mode`n`nThis ship does not require the hospitality reference brief gate." -Encoding UTF8
        }
    }

    $issues = if ($mode -eq "hospitality-studio") { @(Test-ReferenceBrief -RepoPath $repo.Path) } else { @() }
    $status = if ($issues.Count -gt 0) { "BLOCK" } else { "READY" }
    if ($status -eq "BLOCK") { $blocked = $true }
    $reportLines += "- ${name}: $status (mode=$(if ([string]::IsNullOrWhiteSpace($mode)) { 'missing' } else { $mode }))"
    foreach ($issue in $issues) {
        $reportLines += "  - $issue"
    }
}

$reportLines += ""
$reportLines += "Decision: $(if ($blocked) { 'BLOCK' } else { 'READY' })"

$outFull = Join-Path $fleetRoot $OutPath
New-Item -ItemType Directory -Force -Path (Split-Path $outFull) | Out-Null
Set-Content -LiteralPath $outFull -Value $reportLines -Encoding UTF8
$reportLines | ForEach-Object { Write-Host $_ }

if ($Validate -and $blocked) { exit 1 }
exit 0
