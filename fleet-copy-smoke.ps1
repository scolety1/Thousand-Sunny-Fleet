[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$Project = "",

    [string]$OutFile = "docs/codex/COPY_SMOKE.md",

    [int]$MaxHits = 120,

    [switch]$FailOnHigh
)

$ErrorActionPreference = "Continue"

$repoMatches = @(Resolve-Path $Repo -ErrorAction SilentlyContinue)
if ($repoMatches.Count -ne 1) {
    Write-Host "Repo not found or ambiguous: $Repo" -ForegroundColor Red
    exit 1
}

$repoPath = $repoMatches[0].Path
Set-Location $repoPath

if ([string]::IsNullOrWhiteSpace($Project)) {
    $Project = Split-Path -Leaf $repoPath
}

function Get-TrackedPublicFiles {
    $all = @(git ls-files 2>$null)
    if ($LASTEXITCODE -ne 0 -or $all.Count -eq 0) {
        $all = @(Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { Resolve-Path -Relative $_.FullName })
    }

    return @($all |
        ForEach-Object { ([string]$_).Replace("\", "/").TrimStart("./") } |
        Where-Object {
            ($_ -match "^(src|app|web|pages|components|routes|views|public|data|content)/" -and $_ -match "\.(tsx|jsx|ts|js|html|mdx|md|json)$") -or
            $_ -match "\.(tsx|jsx|html|mdx)$"
        } |
        Where-Object {
            $_ -notmatch "^(dist|build|coverage|node_modules|\.codex-logs|\.git)/" -and
            $_ -notmatch "^(docs/codex|\.codex-local|out)/" -and
            $_ -notmatch "(package-lock\.json|package\.json|tsbuildinfo)$"
        } |
        Sort-Object -Unique)
}

function Test-LikelyVisibleLine {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) { return $false }
    $trimmed = $Line.Trim()
    if ($trimmed -match "^\s*(import|export\s+\{|type|interface|function|class)\b") { return $false }
    if ($trimmed -match "^\s*(const|let|var)\s+[A-Za-z0-9_]+\s*=\s*(\(|\[|\{)\s*$") { return $false }
    if ($trimmed -match "^\s*[A-Za-z0-9_-]+\s*:\s*(true|false|null|\d+),?\s*$") { return $false }
    return ($trimmed -match "['`"]" -or $trimmed -match ">[^<]{8,}<" -or $trimmed -match "^\s*[-#*]?\s*[A-Za-z].{12,}$")
}

$patterns = @(
    @{ severity = "HIGH"; term = "ready for service"; reason = "Usually vague unless it names the page, reader, and concrete action." },
    @{ severity = "HIGH"; term = "manager-ready"; reason = "Sounds polished but unclear; say what details managers receive." },
    @{ severity = "HIGH"; term = "staff-ready"; reason = "Sounds like a claim without a concrete workflow or output." },
    @{ severity = "HIGH"; term = "world-class"; reason = "Overclaim risk in small business/demo copy." },
    @{ severity = "WARN"; term = "artifact"; reason = "Internal/product-builder language; customers usually need a concrete noun." },
    @{ severity = "WARN"; term = "workflow"; reason = "Useful internally, vague as a value prop." },
    @{ severity = "WARN"; term = "polish"; reason = "Can sound stylish but empty without a specific before/after." },
    @{ severity = "WARN"; term = "handoff"; reason = "Can be concrete in restaurants, but often needs who/what/when." },
    @{ severity = "WARN"; term = "bring"; reason = "May sound like instructions to the builder rather than the buyer." },
    @{ severity = "WARN"; term = "start with"; reason = "Often ambiguous; name the buyer action plainly." },
    @{ severity = "WARN"; term = "automation"; reason = "Can be vague; name the system or task being automated." },
    @{ severity = "WARN"; term = "solution"; reason = "Generic SaaS language; prefer the actual tool or page." }
)

$hits = [System.Collections.Generic.List[object]]::new()
$files = @(Get-TrackedPublicFiles)

foreach ($file in $files) {
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $lines = @(Get-Content -LiteralPath $file -ErrorAction SilentlyContinue)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        if (-not (Test-LikelyVisibleLine -Line $line)) { continue }

        foreach ($pattern in $patterns) {
            if ($line -match [regex]::Escape([string]$pattern.term)) {
                $sample = $line.Trim()
                if ($sample.Length -gt 180) {
                    $sample = $sample.Substring(0, 180) + "..."
                }
                $hits.Add([pscustomobject]@{
                    severity = $pattern.severity
                    file = $file
                    line = $i + 1
                    term = $pattern.term
                    reason = $pattern.reason
                    sample = $sample
                }) | Out-Null
            }
        }

        if ($hits.Count -ge $MaxHits) { break }
    }
    if ($hits.Count -ge $MaxHits) { break }
}

$structureHits = [System.Collections.Generic.List[object]]::new()
foreach ($file in $files | Where-Object { $_ -match "\.(tsx|jsx|html|mdx)$" }) {
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $text = Get-Content -LiteralPath $file -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($text)) { continue }

    $hasBar = $text -match "stage__bar|header|app-bar|site-header"
    $hasIntro = $text -match "page-intro|route-intro|section-heading|hero-copy"
    $titleTagCount = ([regex]::Matches($text, "(?is)<(?:h1|h2|strong)[^>]*>\s*\{?title\}?\s*</(?:h1|h2|strong)>")).Count
    $hasRepeatedTitle = $titleTagCount -gt 1

    if (($hasBar -and $hasIntro -and $text -match "RoutePage|Layout|Shell|DemoStage") -or $hasRepeatedTitle) {
        $structureHits.Add([pscustomobject]@{
            severity = "WARN"
            file = $file
            reason = "Possible repeated route/header intro. Check that wrapper chrome is not duplicating the actual page title."
        }) | Out-Null
    }
}

$highCount = @($hits | Where-Object { $_.severity -eq "HIGH" }).Count
$warnCount = @($hits | Where-Object { $_.severity -eq "WARN" }).Count + $structureHits.Count
$verdict = if ($highCount -gt 0) { "RED" } elseif ($warnCount -gt 0) { "YELLOW" } else { "GREEN" }
$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$hitLines = if ($hits.Count -eq 0) {
    "- None found."
} else {
    ($hits | Select-Object -First $MaxHits | ForEach-Object {
        "- {0}: ``{1}`` in ``{2}:{3}`` - {4}`n  ``{5}``" -f $_.severity, $_.term, $_.file, $_.line, $_.reason, $_.sample
    }) -join "`n"
}

$structureLines = if ($structureHits.Count -eq 0) {
    "- None found."
} else {
    ($structureHits | ForEach-Object {
        "- {0}: ``{1}`` - {2}" -f $_.severity, $_.file, $_.reason
    }) -join "`n"
}

$report = @"
# Copy Smoke

Project: $Project
Repo: $repoPath
Generated: $date

## Verdict
$verdict

## Summary
- High-risk wording hits: $highCount
- Warning wording/structure hits: $warnCount
- Files scanned: $($files.Count)

## Wording Hits
$hitLines

## Structure Hits
$structureLines

## How To Use
This is a deterministic smoke check, not a copy editor. Treat HIGH hits as likely review blockers and WARN hits as prompts for Robin/Simon or a focused copy task. Ignore false positives from internal-only strings.
"@

$outPath = Join-Path $repoPath $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
$report | Set-Content -Path $outPath -Encoding UTF8

Write-Host "Copy smoke verdict: $verdict ($highCount high, $warnCount warning)" -ForegroundColor $(if ($verdict -eq "GREEN") { "Green" } elseif ($verdict -eq "YELLOW") { "Yellow" } else { "Red" })
Write-Host "Wrote $OutFile"

if ($FailOnHigh -and $highCount -gt 0) {
    exit 1
}

exit 0
