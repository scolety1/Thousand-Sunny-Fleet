[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$OutFile = "docs/codex/ANALYTICAL_FIXTURE_READINESS.md",

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-MarkdownSection {
    param(
        [string]$Text,
        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $escaped = [regex]::Escape($Heading)
    $match = [regex]::Match($Text, "(?ims)^##\s+$escaped\s*\r?\n(?<body>.*?)(?=^##\s+|\z)")
    if (!$match.Success) { return "" }
    return $match.Groups["body"].Value.Trim()
}

function Test-SectionHasSubstance {
    param(
        [string]$Text,
        [string]$Heading
    )

    $body = Get-MarkdownSection -Text $Text -Heading $Heading
    if ([string]::IsNullOrWhiteSpace($body)) { return $false }
    if ($body -match "(?i)\bTODO\b|to be decided|tbd|placeholder") { return $false }
    $contentLines = @($body -split "\r?\n" | Where-Object {
        $line = ([string]$_).Trim()
        ![string]::IsNullOrWhiteSpace($line) -and $line -notmatch "^\s*<!--" -and $line -notmatch "^\s*$"
    })
    return ($contentLines.Count -gt 0)
}

function Get-TrackedOrExistingFiles {
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @(git ls-files 2>$null) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace([string]$_)) { $files.Add(([string]$_).Replace("\", "/")) | Out-Null }
    }
    foreach ($root in @("tests", "test", "fixtures", "sample_data", "data_packs")) {
        if (Test-Path $root) {
            Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                $base = (Get-Location).Path.TrimEnd("\", "/")
                $full = $_.FullName
                $relative = if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $full.Substring($base.Length).TrimStart("\", "/")
                } else {
                    $full
                }
                $relative = $relative.Replace("\", "/")
                $files.Add($relative) | Out-Null
            }
        }
    }
    return @($files)
}

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }
Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)" }

$issues = [System.Collections.Generic.List[string]]::new()
$planPath = "docs/codex/FIXTURE_TEST_PLAN.md"
if (!(Test-Path $planPath)) {
    $issues.Add("Missing docs/codex/FIXTURE_TEST_PLAN.md.") | Out-Null
    $planText = ""
} else {
    $planText = Get-Content $planPath -Raw
}

foreach ($heading in @("Fixture Data", "Expected Outputs", "Formula Tests", "Import Tests", "Edge Cases")) {
    if ($planText -notmatch "(?im)^##\s+$([regex]::Escape($heading))\s*$") {
        $issues.Add("FIXTURE_TEST_PLAN.md missing heading: $heading.") | Out-Null
    }
}

foreach ($requiredSubstance in @("Fixture Data", "Expected Outputs", "Formula Tests")) {
    if (!(Test-SectionHasSubstance -Text $planText -Heading $requiredSubstance)) {
        $issues.Add("FIXTURE_TEST_PLAN.md section needs concrete non-TODO content: $requiredSubstance.") | Out-Null
    }
}

$files = @(Get-TrackedOrExistingFiles)
$fixtureFiles = @($files | Where-Object {
    $_ -match "(?i)(^|/)(fixtures?|sample_data|data_packs)(/|$).+\.(csv|tsv|json|jsonl|yaml|yml|md|txt)$"
})
$testFiles = @($files | Where-Object {
    $_ -match "(?i)(^|/)(tests?|__tests__)(/|$).+\.(py|js|jsx|ts|tsx|ps1|md)$"
})

if ($fixtureFiles.Count -eq 0) {
    $issues.Add("No fixture/sample data files found under fixtures, sample_data, or data_packs.") | Out-Null
}
if ($testFiles.Count -eq 0) {
    $issues.Add("No test files found under tests, test, or __tests__.") | Out-Null
}

$verdict = if ($issues.Count -eq 0) { "GREEN" } else { "RED" }
$lines = @(
    "# Analytical Fixture Readiness",
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
    $lines += "- Fixture-first gate passed."
    $lines += "- Fixture files: $($fixtureFiles.Count)"
    $lines += "- Test files: $($testFiles.Count)"
} else {
    $issues | ForEach-Object { $lines += "- $_" }
}
$lines += ""
$lines += "## Rule"
$lines += ""
$lines += "Analytical engine work requires concrete fixture data, expected outputs, and formula/import tests before implementation starts."

if (!$ValidateOnly -or $issues.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -Path $OutFile -Encoding UTF8 -Value $lines
}

if ($issues.Count -gt 0) {
    Write-Host "Analytical fixture readiness failed." -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Analytical fixture readiness passed." -ForegroundColor Green
exit 0
