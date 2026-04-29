[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$OutFile = "docs/codex/ANALYTICAL_NUMBER_PROVENANCE.md",

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Test-GeneratedReportPath {
    param([string]$Path)

    $normalized = ([string]$Path).Replace("\", "/")
    return $normalized -match "^docs/codex/(ANALYTICAL_NUMBER_PROVENANCE|CHECKPOINT_REVIEW|JOEY_SECURITY_REVIEW|ROBIN_COPY_REVIEW|SENSITIVE_SYSTEMS_REVIEW|SIMON_DESIGN_REVIEW|VISUAL_BUGS|NIGHTLY_REPORT|NEXT_5_TASKS|TASK_QUEUE|MAGIC_SCORECARD|WORK_PACK_STATUS|QUARANTINED_TASKS|RUNTIME_VERIFICATION|MIGRATION_REVIEW|AUTO_REPAIR)\.md$"
}

function Test-AllowedEvidencePath {
    param([string]$Path)

    $normalized = ([string]$Path).Replace("\", "/")
    if (Test-GeneratedReportPath -Path $normalized) { return $true }
    return (
        $normalized -match "(^|/)(tests?|__tests__|fixtures?|sample_data|data_packs|data|snapshots?)(/|$)" -or
        $normalized -match "^docs/codex/(ANALYSIS_BRIEF|DATA_CONTRACT|FORMULA_SPEC|FIXTURE_TEST_PLAN|CALIBRATION_PLAN|ANALYSIS_APPROVAL)\.md$" -or
        $normalized -match "\.(csv|tsv|json|jsonl|sqlite|db|parquet|yaml|yml)$"
    )
}

function Test-UserFacingPath {
    param([string]$Path)

    $normalized = ([string]$Path).Replace("\", "/")
    if (Test-AllowedEvidencePath -Path $normalized) { return $false }
    if ($normalized -match "\.(css|scss|sass|less|map|lock|png|jpg|jpeg|gif|webp|svg|ico|woff2?|ttf|otf)$") { return $false }
    return (
        $normalized -match "(^|/)(app|src|pages|components|routes|views|public|content|reports|templates)(/|$)" -or
        $normalized -match "\.(html|jsx|tsx|vue|svelte|astro|mdx|md|py)$"
    )
}

function Test-ObviousComputedSource {
    param([string]$Line)

    $text = [string]$Line
    return (
        $text -match '(?i)(computed|calculate|calculated|derived|fromData|from_data|score_|prob_|rank_|model_outputs|pick_values|fixture|expected|test|assert|formula|return\s+|def\s+|function\s+|const\s+\w+\s*=\s*\(|let\s+\w+\s*=\s*\(|var\s+\w+\s*=\s*\()' -or
        $text -match '\{[^}]*\}' -or
        $text -match '\$\{[^}]*\}' -or
        $text -match ':\s*[A-Za-z_][A-Za-z0-9_]*(?:\.|\[|\(|$)'
    )
}

function Test-NumericClaimLine {
    param([string]$Line)

    $text = ([string]$Line).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $false }
    if ($text -match "^\s*(//|#|\*)") { return $false }
    if ($text -match "(?i)(margin|padding|width|height|radius|opacity|z-index|line-height|font-size|duration|delay|transform|translate|rotate|rgb|rgba|hsl|hsla|px|rem|em|vh|vw)") { return $false }
    if (Test-ObviousComputedSource -Line $text) { return $false }

    $claimPatterns = @(
        '(?i)\b(up|down|strong up|heavy drop|smash|hit|useful|replaceable|miss|bust|confidence|probability|chance|risk|score|rank|value|projection|expected|forecast|keeper|drop|trade|war)\b[^\r\n]{0,80}\b\d{1,4}(?:\.\d+)?\s*%',
        '(?i)\b\d{1,4}(?:\.\d+)?\s*%\b[^\r\n]{0,80}\b(up|down|strong up|heavy drop|smash|hit|useful|replaceable|miss|bust|confidence|probability|chance|risk|score|rank|value|projection|expected|forecast|keeper|drop|trade|war)\b',
        '(?i)\b(score|rank|value|probability|chance|confidence|risk|projection|forecast)\b\s*[:=-]\s*\$?\d{1,6}(?:\.\d+)?\b',
        '(?i)\$[0-9][0-9,]*(?:\.\d{2})?\b[^\r\n]{0,80}\b(value|price|cost|revenue|profit|loss|budget|forecast|projection)\b',
        '(?i)\b(value|price|cost|revenue|profit|loss|budget|forecast|projection)\b[^\r\n]{0,80}\$[0-9][0-9,]*(?:\.\d{2})?\b'
    )

    foreach ($pattern in $claimPatterns) {
        if ($text -match $pattern) { return $true }
    }
    return $false
}

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }
Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)" }

$issues = [System.Collections.Generic.List[object]]::new()
$diff = @(git diff --cached --unified=0 2>$null)
$currentPath = ""
foreach ($line in @($diff)) {
    $text = [string]$line
    if ($text.StartsWith("+++ b/")) {
        $currentPath = $text.Substring(6)
        continue
    }
    if (!$text.StartsWith("+") -or $text.StartsWith("+++")) { continue }
    if (!(Test-UserFacingPath -Path $currentPath)) { continue }

    $added = $text.Substring(1)
    if (Test-NumericClaimLine -Line $added) {
        $issues.Add([pscustomobject]@{
            path = $currentPath
            line = $added.Trim()
        }) | Out-Null
    }
}

$verdict = if ($issues.Count -eq 0) { "GREEN" } else { "RED" }
$lines = @(
    "# Analytical Number Provenance",
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
    $lines += "- No hardcoded analytical number claims found in staged user-facing files."
} else {
    foreach ($issue in $issues) {
        $snippet = $issue.line
        if ($snippet.Length -gt 160) { $snippet = $snippet.Substring(0, 160) + "..." }
        $lines += ('- `{0}`: `{1}`' -f $issue.path, $snippet)
    }
}
$lines += ""
$lines += "## Rule"
$lines += ""
$lines += "Analytical ships must not add user-facing hardcoded probabilities, scores, ranks, dollar values, forecasts, or recommendation numbers unless they are clearly computed from code/data or live in fixtures, sample data, tests, formulas, or generated reports."

if (!$ValidateOnly -or $issues.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -Path $OutFile -Encoding UTF8 -Value $lines
}

if ($issues.Count -gt 0) {
    Write-Host "Analytical number provenance failed." -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $($_.path): $($_.line)" -ForegroundColor Red }
    exit 1
}

Write-Host "Analytical number provenance passed." -ForegroundColor Green
exit 0
