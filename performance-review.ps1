[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$Project = "",

    [string]$OutFile = "docs/codex/PERFORMANCE_REVIEW.md",

    [int]$MaxBundleKb = 350,

    [int]$MaxCssKb = 180,

    [int]$MaxAssetKb = 750,

    [int]$MaxHits = 120,

    [switch]$FailOnRed
)

$ErrorActionPreference = "Continue"

function Normalize-Path {
    param([string]$Path)
    return ([string]$Path).Replace("\", "/").TrimStart("./")
}

function Format-Kb {
    param([long]$Bytes)
    return [Math]::Round($Bytes / 1kb, 1)
}

$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo not found: $Repo" -ForegroundColor Red
    exit 1
}

Set-Location $repoPath.Path

if ([string]::IsNullOrWhiteSpace($Project)) {
    $Project = Split-Path -Leaf $repoPath.Path
}

function Add-Hit {
    param(
        [System.Collections.Generic.List[object]]$Hits,
        [string]$Severity,
        [string]$File,
        [int]$Line,
        [string]$Issue,
        [string]$Sample
    )

    if ($Hits.Count -ge $MaxHits) { return }
    $sampleText = if ([string]::IsNullOrWhiteSpace($Sample)) { "" } else { $Sample.Trim() }
    if ($sampleText.Length -gt 180) {
        $sampleText = $sampleText.Substring(0, 180) + "..."
    }
    $Hits.Add([pscustomobject]@{
        severity = $Severity
        file = $File
        line = $Line
        issue = $Issue
        sample = $sampleText
    }) | Out-Null
}

function Get-TrackedFiles {
    $tracked = @(git ls-files 2>$null)
    if ($LASTEXITCODE -ne 0 -or $tracked.Count -eq 0) {
        $tracked = @(Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { Resolve-Path -Relative $_.FullName })
    }
    return @($tracked | ForEach-Object { Normalize-Path $_ } | Sort-Object -Unique)
}

function Get-SourceFiles {
    $tracked = @(Get-TrackedFiles)
    return @($tracked |
        Where-Object {
            $_ -match "\.(html|tsx|jsx|vue|svelte|astro|css|scss|sass|ts|js)$" -or
            ($_ -match "^(src|app|web|pages|components|routes|views|public)/")
        } |
        Where-Object {
            $_ -notmatch "^(dist|build|coverage|node_modules|\.git|\.codex-local|out|docs/codex)/" -and
            $_ -notmatch "(package-lock\.json|package\.json|tsbuildinfo)$"
        } |
        Sort-Object -Unique)
}

function Get-BuildArtifacts {
    $roots = @()
    foreach ($candidate in @("dist", "build", ".next/static")) {
        if (Test-Path -LiteralPath $candidate -PathType Container) {
            $roots += $candidate
        }
    }

    $files = @()
    foreach ($root in $roots) {
        $files += @(Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue)
    }
    return @($files | Sort-Object Length -Descending)
}

$hits = [System.Collections.Generic.List[object]]::new()
$sourceFiles = @(Get-SourceFiles)
$artifactFiles = @(Get-BuildArtifacts)

foreach ($artifact in $artifactFiles) {
    $relative = Normalize-Path (Resolve-Path -Relative $artifact.FullName)
    $kb = Format-Kb $artifact.Length
    $extension = [System.IO.Path]::GetExtension($artifact.Name).ToLowerInvariant()

    if ($extension -eq ".js" -and $kb -gt $MaxBundleKb) {
        Add-Hit -Hits $hits -Severity "RED" -File $relative -Line 1 -Issue "JavaScript bundle exceeds ${MaxBundleKb}KB budget at ${kb}KB." -Sample $artifact.Name
    } elseif ($extension -eq ".css" -and $kb -gt $MaxCssKb) {
        Add-Hit -Hits $hits -Severity "RED" -File $relative -Line 1 -Issue "CSS bundle exceeds ${MaxCssKb}KB budget at ${kb}KB." -Sample $artifact.Name
    } elseif ($extension -match "\.(png|jpg|jpeg|gif|webp|avif|mp4|mov|webm|woff|woff2)$" -and $kb -gt $MaxAssetKb) {
        Add-Hit -Hits $hits -Severity "YELLOW" -File $relative -Line 1 -Issue "Static asset exceeds ${MaxAssetKb}KB budget at ${kb}KB." -Sample $artifact.Name
    }
}

$packageHasBuild = $false
if (Test-Path -LiteralPath "package.json" -PathType Leaf) {
    $packageText = Get-Content -LiteralPath "package.json" -Raw -ErrorAction SilentlyContinue
    $packageHasBuild = $packageText -match '"build"\s*:'
}
if ($artifactFiles.Count -eq 0 -and $packageHasBuild) {
    Add-Hit -Hits $hits -Severity "YELLOW" -File "package.json" -Line 1 -Issue "No build artifacts were found; run a build before trusting bundle-size performance review." -Sample "Expected dist/, build/, or .next/static."
}

foreach ($file in $sourceFiles) {
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $text = Get-Content -LiteralPath $file -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($text)) { continue }
    $lines = @($text -split "`r?`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        $lineNumber = $i + 1

        if ($line -match "data:(image|video|font)/[a-zA-Z0-9.+-]+;base64," -and $line.Length -gt 320) {
            Add-Hit -Hits $hits -Severity "YELLOW" -File $file -Line $lineNumber -Issue "Large inline base64 asset can bloat source and initial page weight." -Sample $line
        }
        if ($file -match "\.(css|scss|sass)$" -and $line -match "transition\s*:\s*all\b") {
            Add-Hit -Hits $hits -Severity "YELLOW" -File $file -Line $lineNumber -Issue "Transitioning all properties can create unnecessary layout/paint work." -Sample $line
        }
        if ($file -match "\.(css|scss|sass)$" -and $line -match "(backdrop-filter|filter)\s*:\s*blur\(") {
            Add-Hit -Hits $hits -Severity "INFO" -File $file -Line $lineNumber -Issue "Blur filter found; keep usage limited on large/fixed surfaces." -Sample $line
        }
        if ($line -match "setInterval\s*\([^,]+,\s*([0-9]{1,2})\s*\)") {
            Add-Hit -Hits $hits -Severity "YELLOW" -File $file -Line $lineNumber -Issue "Very short setInterval delay can drain runtime performance." -Sample $line
        }
        if ($file -match "\.(css|scss|sass)$" -and $line -match "will-change\s*:" -and $line -notmatch "auto|transform|opacity") {
            Add-Hit -Hits $hits -Severity "YELLOW" -File $file -Line $lineNumber -Issue "Broad will-change usage can increase memory pressure." -Sample $line
        }
        if ($file -match "\.(html|tsx|jsx|vue|svelte|astro)$" -and $line -match "<video\b" -and $line -match "\bautoplay\b" -and $line -notmatch "\bpreload\s*=\s*['`"]none['`"]") {
            Add-Hit -Hits $hits -Severity "YELLOW" -File $file -Line $lineNumber -Issue "Autoplay video should avoid eager preload unless it is critical above-the-fold media." -Sample $line
        }
    }
}

$largestLines = if ($artifactFiles.Count -eq 0) {
    "- No build artifacts found."
} else {
    ($artifactFiles | Select-Object -First 10 | ForEach-Object {
        "- ``{0}`` - {1}KB" -f (Normalize-Path (Resolve-Path -Relative $_.FullName)), (Format-Kb $_.Length)
    }) -join "`n"
}

$redCount = @($hits | Where-Object { $_.severity -eq "RED" }).Count
$yellowCount = @($hits | Where-Object { $_.severity -eq "YELLOW" }).Count
$infoCount = @($hits | Where-Object { $_.severity -eq "INFO" }).Count
$verdict = if ($redCount -gt 0) { "RED" } elseif ($yellowCount -gt 0) { "YELLOW" } else { "GREEN" }
$nextStep = if ($verdict -eq "RED") { "stop for human performance review" } elseif ($verdict -eq "YELLOW") { "continue but patch performance warnings soon" } else { "continue" }

$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$hitLines = if ($hits.Count -eq 0) {
    "- No deterministic performance issues found."
} else {
    ($hits | Select-Object -First $MaxHits | ForEach-Object {
        "- [{0}] ``{1}:{2}`` - {3}`n  ``{4}``" -f $_.severity, $_.file, $_.line, $_.issue, $_.sample
    }) -join "`n"
}

$report = @"
# Performance Review

Generated: $date
Project: $Project
Repo: $($repoPath.Path)

## Verdict
$verdict

## Performance Read
Percy checked deterministic performance risks: oversized build artifacts, missing build artifacts when a build script exists, large inline base64 assets, transition-all CSS, blur/filter usage, very short polling intervals, broad will-change usage, and eager autoplay video.

## Summary
- Source files scanned: $($sourceFiles.Count)
- Build artifacts scanned: $($artifactFiles.Count)
- JavaScript bundle budget: ${MaxBundleKb}KB
- CSS bundle budget: ${MaxCssKb}KB
- Static asset warning budget: ${MaxAssetKb}KB
- RED issues: $redCount
- YELLOW issues: $yellowCount
- INFO signals: $infoCount

## Largest Artifacts
$largestLines

## Findings
$hitLines

## Stop Or Continue
$nextStep
"@

$outPath = Join-Path $repoPath.Path $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
$report | Set-Content -Path $outPath -Encoding UTF8

Write-Host "Performance review: $verdict"
Write-Host "Report: $OutFile"

if ($FailOnRed -and $verdict -eq "RED") { exit 1 }
exit 0
