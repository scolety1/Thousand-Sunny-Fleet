[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$OutFile = "docs/codex/SEED_FIXTURE_REVIEW.md",

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Test-Heading {
    param([string]$Text, [string]$Heading)
    return ($Text -match "(?im)^##\s+$([regex]::Escape($Heading))\s*$")
}

function Test-UnsafeRealDataLine {
    param([string]$Text)

    foreach ($line in @($Text -split "\r?\n")) {
        if ($line -match "(?i)\breal customer data\b|\bproduction data\b") {
            if ($line -notmatch "(?i)\b(no|not|never|without|avoid|forbid|forbidden|synthetic only)\b") {
                return $true
            }
        }
    }

    return $false
}

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }

Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)" }

$planPath = "docs/codex/SEED_FIXTURE_PLAN.md"
$evidencePath = "docs/codex/SEED_FIXTURE_EVIDENCE.md"
$issues = [System.Collections.Generic.List[string]]::new()

if (!(Test-Path $planPath)) {
    $issues.Add("Missing docs/codex/SEED_FIXTURE_PLAN.md.") | Out-Null
} else {
    $plan = Get-Content $planPath -Raw
    foreach ($heading in @("Seed Data Scope", "Fixture Files", "Synthetic Data Rules", "Reset Command", "Expected Records")) {
        if (!(Test-Heading -Text $plan -Heading $heading)) {
            $issues.Add("SEED_FIXTURE_PLAN.md missing heading: $heading.") | Out-Null
        }
    }
    if (Test-UnsafeRealDataLine -Text $plan) {
        $issues.Add("SEED_FIXTURE_PLAN.md appears to allow real customer or production data.") | Out-Null
    }
}

if (!(Test-Path $evidencePath)) {
    $issues.Add("Missing docs/codex/SEED_FIXTURE_EVIDENCE.md.") | Out-Null
} else {
    $evidence = Get-Content $evidencePath -Raw
    if ($evidence -notmatch "(?im)^\s*Status:\s*APPROVED\s*$") {
        $issues.Add("SEED_FIXTURE_EVIDENCE.md is not Status: APPROVED.") | Out-Null
    }
    foreach ($heading in @("Generated Fixtures", "Validation Command", "Reset Evidence", "Data Safety Notes")) {
        if (!(Test-Heading -Text $evidence -Heading $heading)) {
            $issues.Add("SEED_FIXTURE_EVIDENCE.md missing heading: $heading.") | Out-Null
        }
    }
}

$verdict = if ($issues.Count -eq 0) { "GREEN" } else { "RED" }
$lines = @(
    "# Seed Fixture Review",
    "",
    "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "",
    "## Verdict",
    "",
    $verdict,
    "",
    "## Findings",
    ""
)
if ($issues.Count -eq 0) {
    $lines += "- Seed and fixture evidence is approved."
} else {
    $issues | ForEach-Object { $lines += "- $_" }
}
$lines += ""
$lines += "## Required Evidence"
$lines += ""
$lines += "- Seed data scope"
$lines += "- Fixture files"
$lines += "- Synthetic data rules"
$lines += "- Reset command"
$lines += "- Validation evidence"

if (!$ValidateOnly -or $issues.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -Path $OutFile -Value $lines -Encoding UTF8
}

if ($issues.Count -gt 0) {
    Write-Host "Seed fixture review failed." -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Seed fixture review passed." -ForegroundColor Green
exit 0
