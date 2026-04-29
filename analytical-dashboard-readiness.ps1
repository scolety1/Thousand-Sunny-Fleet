[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$OutFile = "docs/codex/ANALYTICAL_DASHBOARD_READINESS.md",

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-TrackedOrExistingFiles {
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @(git ls-files 2>$null) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace([string]$_)) {
            $files.Add(([string]$_).Replace("\", "/")) | Out-Null
        }
    }

    foreach ($root in @("docs/codex", "tests", "test", "__tests__", "fixtures", "sample_data", "data_packs", "reports", "src", "app")) {
        if (Test-Path $root) {
            Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
                $base = (Get-Location).Path.TrimEnd("\", "/")
                $full = $_.FullName
                $relative = if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $full.Substring($base.Length).TrimStart("\", "/")
                } else {
                    $full
                }
                $files.Add($relative.Replace("\", "/")) | Out-Null
            }
        }
    }

    return @($files)
}

function Test-FileContains {
    param(
        [string[]]$Files,
        [string]$Pattern
    )

    foreach ($file in $Files) {
        if (!(Test-Path $file)) { continue }
        try {
            $text = Get-Content $file -Raw -ErrorAction Stop
            if ($text -match $Pattern) { return $true }
        } catch {
            continue
        }
    }
    return $false
}

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }
Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)" }

$issues = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$files = @(Get-TrackedOrExistingFiles)

$testFiles = @($files | Where-Object {
    $_ -match "(?i)(^|/)(tests?|__tests__)(/|$).+\.(py|js|jsx|ts|tsx|ps1|md)$"
})
$formulaTestFiles = @($testFiles | Where-Object {
    $_ -match "(?i)(formula|score|rank|probab|model|engine|keeper|pick|trade|confidence|calibrat|backtest)"
})
$importValidationTestFiles = @($testFiles | Where-Object {
    $_ -match "(?i)(import|validat|schema|loader|data_contract|snapshot|csv)"
})

if ($testFiles.Count -eq 0) {
    $issues.Add("No tests found. Dashboard work needs formula/model and import/validation tests first.") | Out-Null
}
if ($formulaTestFiles.Count -eq 0 -and !(Test-FileContains -Files $testFiles -Pattern "(?i)formula|score|rank|probab|model|engine|confidence|expected")) {
    $issues.Add("No formula/model test evidence found.") | Out-Null
}
if ($importValidationTestFiles.Count -eq 0 -and !(Test-FileContains -Files $testFiles -Pattern "(?i)import|validat|schema|loader|snapshot|csv|reject|warn")) {
    $issues.Add("No import or validation test evidence found.") | Out-Null
}

$fixtureOutputFiles = @($files | Where-Object {
    $_ -match "(?i)(^|/)(fixtures?|sample_data|data_packs)(/|$).*(expected|output|model_outputs|scores|rankings|pick_values|report|table).*\.(csv|tsv|json|jsonl|yaml|yml|md|txt)$"
})
if ($fixtureOutputFiles.Count -eq 0) {
    $issues.Add("No fixture expected-output, model-output, score, ranking, pick-value, report, or table files found.") | Out-Null
}

$deterministicOutputFiles = @($files | Where-Object {
    $_ -match "(?i)(^|/)docs/codex/(DETERMINISTIC_OUTPUTS|MODEL_OUTPUTS|SAMPLE_REPORT|BACKTEST_REPORT|CALIBRATION_RESULTS|KNOWN_CASES)\.md$" -or
    $_ -match "(?i)(^|/)(reports|sample_data|data_packs|fixtures?)(/|$).*(report|table|model_outputs|scores|rankings|probabilities|recommendations|war_board|draft_room).*\.(md|csv|tsv|json|jsonl|txt)$"
})
if ($deterministicOutputFiles.Count -eq 0) {
    $issues.Add("No deterministic report/table artifact found. Add a generated report, model_outputs table, score/ranking table, or documented sample output before dashboard UI work.") | Out-Null
}

$calibrationReport = "docs/codex/CALIBRATION_READINESS.md"
if (Test-Path $calibrationReport) {
    $calibrationText = Get-Content $calibrationReport -Raw
    if ($calibrationText -match "(?is)## Verdict\s+RED\b") {
        $issues.Add("CALIBRATION_READINESS.md is RED; dashboard work must wait.") | Out-Null
    } elseif ($calibrationText -match "(?is)## Verdict\s+YELLOW\b") {
        $warnings.Add("CALIBRATION_READINESS.md is YELLOW; keep dashboard work restrained, table-first, and caveated.") | Out-Null
    } elseif ($calibrationText -notmatch "(?is)## Verdict\s+GREEN\b") {
        $warnings.Add("CALIBRATION_READINESS.md exists but has no GREEN/YELLOW/RED verdict.") | Out-Null
    }
} else {
    $warnings.Add("CALIBRATION_READINESS.md is not committed in the ship; startup calibration gate may still have passed through .codex-local evidence.") | Out-Null
}

$verdict = if ($issues.Count -gt 0) {
    "RED"
} elseif ($warnings.Count -gt 0) {
    "YELLOW"
} else {
    "GREEN"
}

$lines = @(
    "# Analytical Dashboard Readiness",
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
if ($issues.Count -eq 0 -and $warnings.Count -eq 0) {
    $lines += "- Dashboard restraint gate passed."
} else {
    $issues | ForEach-Object { $lines += "- [RED] $_" }
    $warnings | ForEach-Object { $lines += "- [YELLOW] $_" }
}

$lines += ""
$lines += "## Evidence"
$lines += ""
$lines += "- Test files: $($testFiles.Count)"
$lines += "- Formula/model test evidence files: $($formulaTestFiles.Count)"
$lines += "- Import/validation test evidence files: $($importValidationTestFiles.Count)"
$lines += "- Fixture output files: $($fixtureOutputFiles.Count)"
$lines += "- Deterministic output files: $($deterministicOutputFiles.Count)"
foreach ($file in @($fixtureOutputFiles + $deterministicOutputFiles | Sort-Object -Unique | Select-Object -First 40)) {
    $lines += "  - $file"
}

$lines += ""
$lines += "## Rule"
$lines += ""
$lines += "Analytical dashboards and scenario tools must stay table-first and report-first until formula/model tests, import validation tests, fixture expected outputs, and at least one deterministic report/table artifact exist. Do not turn uncalibrated formulas into persuasive insight copy."

if (!$ValidateOnly -or $issues.Count -gt 0 -or $warnings.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -Path $OutFile -Encoding UTF8 -Value $lines
}

if ($issues.Count -gt 0) {
    Write-Host "Analytical dashboard readiness failed." -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

if ($warnings.Count -gt 0) {
    Write-Host "Analytical dashboard readiness is yellow." -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    exit 0
}

Write-Host "Analytical dashboard readiness passed." -ForegroundColor Green
exit 0
