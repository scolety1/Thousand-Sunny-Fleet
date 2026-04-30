[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$OutFile = "docs/codex/API_CONTRACT_REVIEW.md",

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

function Test-Approved {
    param([string]$Text)
    return ($Text -match "(?im)^\s*Status:\s*APPROVED\s*$")
}

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }

Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)" }

$contractPath = "docs/codex/API_CONTRACT.md"
$testsPath = "docs/codex/API_CONTRACT_TESTS.md"
$issues = [System.Collections.Generic.List[string]]::new()

if (!(Test-Path $contractPath)) {
    $issues.Add("Missing docs/codex/API_CONTRACT.md.") | Out-Null
} else {
    $contract = Get-Content $contractPath -Raw
    foreach ($heading in @("Endpoints", "Request Shapes", "Response Shapes", "Error Cases", "Auth And Permissions", "Data Access", "Local Test Evidence")) {
        if (!(Test-Heading -Text $contract -Heading $heading)) {
            $issues.Add("API_CONTRACT.md missing heading: $heading.") | Out-Null
        }
    }
    if ($contract -match "(?i)\bTBD\b|\bTODO\b|\bunknown\b") {
        $issues.Add("API_CONTRACT.md still contains TBD/TODO/unknown placeholders.") | Out-Null
    }
}

if (!(Test-Path $testsPath)) {
    $issues.Add("Missing docs/codex/API_CONTRACT_TESTS.md.") | Out-Null
} else {
    $tests = Get-Content $testsPath -Raw
    if (!(Test-Approved -Text $tests)) {
        $issues.Add("API_CONTRACT_TESTS.md is not Status: APPROVED.") | Out-Null
    }
    foreach ($heading in @("Contract Tests", "Fixture Inputs", "Expected Outputs", "Failure Cases", "Run Command")) {
        if (!(Test-Heading -Text $tests -Heading $heading)) {
            $issues.Add("API_CONTRACT_TESTS.md missing heading: $heading.") | Out-Null
        }
    }
}

$verdict = if ($issues.Count -eq 0) { "GREEN" } else { "RED" }
$lines = @(
    "# API Contract Review",
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
    $lines += "- API contract and contract-test evidence are approved."
} else {
    $issues | ForEach-Object { $lines += "- $_" }
}
$lines += ""
$lines += "## Required Evidence"
$lines += ""
$lines += "- Endpoints"
$lines += "- Request and response shapes"
$lines += "- Error cases"
$lines += "- Auth and permission assumptions"
$lines += "- Data access boundaries"
$lines += "- Local contract-test command and evidence"

if (!$ValidateOnly -or $issues.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -Path $OutFile -Value $lines -Encoding UTF8
}

if ($issues.Count -gt 0) {
    Write-Host "API contract review failed." -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "API contract review passed." -ForegroundColor Green
exit 0
