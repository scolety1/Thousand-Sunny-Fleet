[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string]$Repo = "",

    [string]$OutDir = "docs/codex",

    [switch]$Template,

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-ProjectList {
    if (!(Test-Path $ConfigPath)) {
        Stop-WithMessage "Config not found: $ConfigPath"
    }

    $parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($parsedProjects -is [array]) { return @($parsedProjects) }
    if ($null -ne $parsedProjects -and $parsedProjects.PSObject.Properties.Name -contains "value") { return @($parsedProjects.value) }
    if ($null -ne $parsedProjects) { return @($parsedProjects) }
    return @()
}

function Resolve-Ship {
    if (![string]::IsNullOrWhiteSpace($Repo)) {
        $repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
        if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }
        return [pscustomobject]@{
            name = if (![string]::IsNullOrWhiteSpace($Project)) { $Project } else { Split-Path -Leaf $repoPath.Path }
            repo = $repoPath.Path
        }
    }

    if ([string]::IsNullOrWhiteSpace($Project)) {
        Stop-WithMessage "Provide -Project or -Repo."
    }

    $matches = @(Get-ProjectList | Where-Object { [string]$_.name -ceq [string]$Project })
    if ($matches.Count -ne 1) {
        Stop-WithMessage "Project not found or ambiguous: $Project"
    }

    return $matches[0]
}

function Get-AnalysisPaths {
    param([string]$Root)

    return [pscustomobject]@{
        brief = Join-Path $Root "ANALYSIS_BRIEF.md"
        data = Join-Path $Root "DATA_CONTRACT.md"
        formulas = Join-Path $Root "FORMULA_SPEC.md"
        fixtures = Join-Path $Root "FIXTURE_TEST_PLAN.md"
        calibration = Join-Path $Root "CALIBRATION_PLAN.md"
        approval = Join-Path $Root "ANALYSIS_APPROVAL.md"
    }
}

function Test-FileHasHeadings {
    param(
        [string]$Path,
        [string[]]$Headings
    )

    if (!(Test-Path -LiteralPath $Path)) { return $false }
    $text = Get-Content -LiteralPath $Path -Raw
    foreach ($heading in $Headings) {
        if ($text -notmatch "(?im)^##\s+$([regex]::Escape($heading))\s*$") {
            return $false
        }
    }
    return $true
}

function Test-AnalysisApproval {
    param([string]$Path)

    if (!(Test-Path -LiteralPath $Path)) { return $false }
    $text = Get-Content -LiteralPath $Path -Raw
    return ($text -match "(?im)^\s*Status:\s*APPROVED\s*$")
}

function Test-AnalysisPlan {
    param([object]$Paths)

    $issues = [System.Collections.Generic.List[string]]::new()
    if (!(Test-FileHasHeadings -Path $Paths.brief -Headings @("Decision", "User", "Outputs", "Non Goals", "Assumptions"))) {
        $issues.Add("ANALYSIS_BRIEF.md is missing or incomplete.") | Out-Null
    }
    if (!(Test-FileHasHeadings -Path $Paths.data -Headings @("Snapshots", "Canonical IDs", "Input Schemas", "Validation Rules", "Missing Data"))) {
        $issues.Add("DATA_CONTRACT.md is missing or incomplete.") | Out-Null
    }
    if (!(Test-FileHasHeadings -Path $Paths.formulas -Headings @("Scores", "Formulas", "Weights", "Confidence", "Examples"))) {
        $issues.Add("FORMULA_SPEC.md is missing or incomplete.") | Out-Null
    }
    if (!(Test-FileHasHeadings -Path $Paths.fixtures -Headings @("Fixture Data", "Expected Outputs", "Formula Tests", "Import Tests", "Edge Cases"))) {
        $issues.Add("FIXTURE_TEST_PLAN.md is missing or incomplete.") | Out-Null
    }
    if (!(Test-FileHasHeadings -Path $Paths.calibration -Headings @("Historical Checks", "Sanity Checks", "Calibration Metrics", "Failure Modes", "Tuning Rules"))) {
        $issues.Add("CALIBRATION_PLAN.md is missing or incomplete.") | Out-Null
    }
    if (!(Test-AnalysisApproval -Path $Paths.approval)) {
        $issues.Add("ANALYSIS_APPROVAL.md is missing Status: APPROVED.") | Out-Null
    }
    return @($issues)
}

function Write-TemplatePlan {
    param(
        [object]$Ship,
        [object]$Paths
    )

    if (!(Test-Path -LiteralPath $Paths.brief)) {
        Set-Content -LiteralPath $Paths.brief -Encoding UTF8 -Value @"
# Analysis Brief

## Decision
TODO: Name the exact decision this tool helps with.

## User
TODO: Name the primary user and when they use it.

## Outputs
TODO: List the tables, labels, probabilities, recommendations, and reports the tool should produce.

## Non Goals
TODO: List predictions, automations, live dependencies, or advice this tool must not attempt.

## Assumptions
TODO: List rules, defaults, source constraints, and manual-review boundaries.
"@
    }

    if (!(Test-Path -LiteralPath $Paths.data)) {
        Set-Content -LiteralPath $Paths.data -Encoding UTF8 -Value @"
# Data Contract

## Snapshots
TODO: Define versioned local snapshot folders and source metadata.

## Canonical IDs
TODO: Define player/entity/team/security IDs and merge rules.

## Input Schemas
TODO: Define CSV/SQLite tables, required columns, types, and examples.

## Validation Rules
TODO: Define reject vs warning rules before import.

## Missing Data
TODO: Define defaults, warnings, confidence penalties, and manual review flags.
"@
    }

    if (!(Test-Path -LiteralPath $Paths.formulas)) {
        Set-Content -LiteralPath $Paths.formulas -Encoding UTF8 -Value @"
# Formula Spec

## Scores
TODO: List every score, rank, label, probability, or recommendation.

## Formulas
TODO: Write deterministic formulas in plain math/pseudocode before coding.

## Weights
TODO: Define weights, strategy-mode adjustments, and allowed ranges.

## Confidence
TODO: Define confidence inputs, missing-data shrinkage, and display buckets.

## Examples
TODO: Include small examples with expected outputs.
"@
    }

    if (!(Test-Path -LiteralPath $Paths.fixtures)) {
        Set-Content -LiteralPath $Paths.fixtures -Encoding UTF8 -Value @"
# Fixture Test Plan

## Fixture Data
TODO: Define tiny known datasets checked into tests, fixtures, sample_data, or data_packs.

## Expected Outputs
TODO: Write expected scores, ranks, errors, warnings, labels, and output rows for each fixture.

## Formula Tests
TODO: Map each formula to at least one deterministic test and command.

## Import Tests
TODO: Map validation rules to passing and failing fixtures.

## Edge Cases
TODO: Include missing values, duplicate IDs, ties, placeholders, and impossible rows.
"@
    }

    if (!(Test-Path -LiteralPath $Paths.calibration)) {
        Set-Content -LiteralPath $Paths.calibration -Encoding UTF8 -Value @"
# Calibration Plan

## Historical Checks
TODO: Define history/backtest or known-case comparisons.

## Sanity Checks
TODO: Define obvious outcomes the model must get right.

## Calibration Metrics
TODO: Define accuracy, false positives, false negatives, ranking stability, and confidence metrics.

## Failure Modes
TODO: Define where the model might overreact, underreact, or fake precision.

## Tuning Rules
TODO: Define how thresholds/weights may change without curve-fitting.
"@
    }

    if (!(Test-Path -LiteralPath $Paths.approval)) {
        Set-Content -LiteralPath $Paths.approval -Encoding UTF8 -Value @"
# Analysis Approval

Project: $($Ship.name)
Status: DRAFT

Human approval means the problem, data contract, formulas, fixtures, and calibration plan are coherent enough for engine-build work.
"@
    }
}

$ship = Resolve-Ship
$repoPath = Resolve-Path -LiteralPath ([string]$ship.repo) -ErrorAction SilentlyContinue
if (!$repoPath) { Stop-WithMessage "Repo not found: $($ship.repo)" }

$targetRoot = Join-Path $repoPath.Path $OutDir
$paths = Get-AnalysisPaths -Root $targetRoot

if ($ValidateOnly) {
    $issues = @(Test-AnalysisPlan -Paths $paths)
    if ($issues.Count -gt 0) {
        Write-Host "Analytical planning pack is not approved for $($ship.name)." -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        exit 1
    }

    Write-Host "Analytical planning pack is approved for $($ship.name)." -ForegroundColor Green
    exit 0
}

Push-Location $repoPath.Path
$preStatus = @(git status --short 2>$null)
if ($preStatus.Count -gt 0) {
    Pop-Location
    Stop-WithMessage "Analytical planning requires a clean working tree."
}

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
Write-TemplatePlan -Ship $ship -Paths $paths

if ($Template) {
    Pop-Location
    Write-Host "Analytical planning templates written to $targetRoot." -ForegroundColor Green
    Write-Host "Review and change ANALYSIS_APPROVAL.md Status to APPROVED when ready." -ForegroundColor Yellow
    exit 0
}

git add $OutDir/ANALYSIS_BRIEF.md $OutDir/DATA_CONTRACT.md $OutDir/FORMULA_SPEC.md $OutDir/FIXTURE_TEST_PLAN.md $OutDir/CALIBRATION_PLAN.md $OutDir/ANALYSIS_APPROVAL.md | Out-Null
$changed = @(git diff --cached --name-only)
if ($changed.Count -eq 0) {
    Pop-Location
    Write-Host "Analytical planning pack already exists with no changes." -ForegroundColor Yellow
    exit 0
}

git commit -m "Codex analytical planning pack" | Out-Null
if ($LASTEXITCODE -ne 0) {
    Pop-Location
    Stop-WithMessage "Analytical planning templates were written, but commit failed."
}

Pop-Location
Write-Host "Analytical planning pack written to $targetRoot." -ForegroundColor Green
Write-Host "Approval remains DRAFT until a human changes ANALYSIS_APPROVAL.md to Status: APPROVED." -ForegroundColor Yellow
