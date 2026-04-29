[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$OutFile = "docs/codex/CALIBRATION_READINESS.md",

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
        ![string]::IsNullOrWhiteSpace($line) -and
            $line -notmatch "^\s*<!--" -and
            $line -notmatch "^\s*$"
    })
    return ($contentLines.Count -gt 0)
}

function Test-HistoryUnavailableWithFallback {
    param([string]$PlanText)

    $history = Get-MarkdownSection -Text $PlanText -Heading "Historical Checks"
    if ([string]::IsNullOrWhiteSpace($history)) { return $false }
    if ($history -notmatch "(?i)history unavailable|historical data unavailable|no historical data|not enough historical data") {
        return $false
    }

    $combined = @(
        $history,
        (Get-MarkdownSection -Text $PlanText -Heading "Sanity Checks"),
        (Get-MarkdownSection -Text $PlanText -Heading "Calibration Metrics")
    ) -join "`n"

    return ($combined -match "(?i)fallback|sanity|known case|fixture|manual review|proxy")
}

function Get-TrackedOrExistingFiles {
    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @(git ls-files 2>$null) | ForEach-Object {
        if (![string]::IsNullOrWhiteSpace([string]$_)) {
            $files.Add(([string]$_).Replace("\", "/")) | Out-Null
        }
    }

    foreach ($root in @("docs/codex", "tests", "test", "fixtures", "sample_data", "data_packs", "reports")) {
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

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }
Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)" }

$issues = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()
$planPath = "docs/codex/CALIBRATION_PLAN.md"
if (!(Test-Path $planPath)) {
    $issues.Add("Missing docs/codex/CALIBRATION_PLAN.md.") | Out-Null
    $planText = ""
} else {
    $planText = Get-Content $planPath -Raw
}

$requiredHeadings = @(
    "Historical Checks",
    "Sanity Checks",
    "Calibration Metrics",
    "Failure Modes",
    "Tuning Rules"
)
foreach ($heading in $requiredHeadings) {
    if ($planText -notmatch "(?im)^##\s+$([regex]::Escape($heading))\s*$") {
        $issues.Add("CALIBRATION_PLAN.md missing heading: $heading.") | Out-Null
    } elseif (!(Test-SectionHasSubstance -Text $planText -Heading $heading)) {
        $issues.Add("CALIBRATION_PLAN.md section needs concrete non-TODO content: $heading.") | Out-Null
    }
}

$historyUnavailableWithFallback = Test-HistoryUnavailableWithFallback -PlanText $planText
$historySection = Get-MarkdownSection -Text $planText -Heading "Historical Checks"
if ($historySection -match "(?i)history unavailable|historical data unavailable|no historical data|not enough historical data") {
    if ($historyUnavailableWithFallback) {
        $warnings.Add("Historical data is explicitly unavailable and fallback sanity/known-case checks are documented.") | Out-Null
    } else {
        $issues.Add("History is marked unavailable, but the plan does not explain fallback sanity, known-case, fixture, or proxy checks.") | Out-Null
    }
} elseif (![string]::IsNullOrWhiteSpace($planText) -and $historySection -notmatch "(?i)backtest|historical|known case|actual|past|baseline|holdout|walk-forward") {
    $issues.Add("Historical Checks must name a backtest, known-case comparison, baseline, holdout, or explicit unavailable-history fallback.") | Out-Null
}

$metricSection = Get-MarkdownSection -Text $planText -Heading "Calibration Metrics"
if (![string]::IsNullOrWhiteSpace($planText) -and $metricSection -notmatch "(?i)accuracy|calibration|brier|log loss|false positive|false negative|precision|recall|hit rate|mean absolute|error|confidence") {
    $issues.Add("Calibration Metrics must name at least one concrete calibration or error metric.") | Out-Null
}

$files = @(Get-TrackedOrExistingFiles)
$evidenceFiles = @($files | Where-Object {
    $_ -match "(?i)(^|/)docs/codex/(CALIBRATION_RESULTS|BACKTEST_REPORT|KNOWN_CASES|MODEL_EVALUATION|CONFIDENCE_REVIEW)\.md$" -or
    $_ -match "(?i)(^|/)(tests?|__tests__)(/|$).*(calibrat|backtest|confidence|sanity|known|regime|score).*\.(py|js|jsx|ts|tsx|ps1|md)$" -or
    $_ -match "(?i)(^|/)(fixtures?|sample_data|data_packs|reports)(/|$).*(calibrat|backtest|known|expected|confidence|sanity).*\.(csv|tsv|json|jsonl|yaml|yml|md|txt)$"
})

if ($evidenceFiles.Count -eq 0) {
    if ($historyUnavailableWithFallback) {
        $warnings.Add("No calibration-specific artifact found yet; fallback is documented, but create known-case or confidence tests before trusting dashboard output.") | Out-Null
    } else {
        $issues.Add("No calibration evidence found. Add CALIBRATION_RESULTS.md, BACKTEST_REPORT.md, KNOWN_CASES.md, calibration/backtest/confidence tests, or calibration fixture/report files.") | Out-Null
    }
}

$verdict = if ($issues.Count -gt 0) {
    "RED"
} elseif ($warnings.Count -gt 0) {
    "YELLOW"
} else {
    "GREEN"
}

$lines = @(
    "# Calibration Readiness",
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
    $lines += "- Calibration readiness passed."
} else {
    $issues | ForEach-Object { $lines += "- [RED] $_" }
    $warnings | ForEach-Object { $lines += "- [YELLOW] $_" }
}
$lines += ""
$lines += "## Evidence"
$lines += ""
if ($evidenceFiles.Count -eq 0) {
    $lines += "- No calibration evidence files found."
} else {
    $evidenceFiles | Sort-Object | ForEach-Object { $lines += "- $_" }
}
$lines += ""
$lines += "## Rule"
$lines += ""
$lines += "Calibration work must prove the deterministic model is not just plausible. It needs historical checks or an explicit unavailable-history fallback, sanity checks, calibration metrics, failure modes, tuning rules, and evidence files before dashboards or scenario tools should be trusted."

if (!$ValidateOnly -or $issues.Count -gt 0 -or $warnings.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -Path $OutFile -Encoding UTF8 -Value $lines
}

if ($issues.Count -gt 0) {
    Write-Host "Calibration readiness failed." -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

if ($warnings.Count -gt 0) {
    Write-Host "Calibration readiness is yellow." -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
    exit 0
}

Write-Host "Calibration readiness passed." -ForegroundColor Green
exit 0
