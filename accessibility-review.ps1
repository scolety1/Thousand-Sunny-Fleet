[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$Project = "",

    [string]$OutFile = "docs/codex/ACCESSIBILITY_REVIEW.md",

    [int]$MaxHits = 120,

    [switch]$FailOnRed
)

$ErrorActionPreference = "Continue"

function Normalize-Path {
    param([string]$Path)
    return ([string]$Path).Replace("\", "/").TrimStart("./")
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

function Get-UiFiles {
    $tracked = @(git ls-files 2>$null)
    if ($LASTEXITCODE -ne 0 -or $tracked.Count -eq 0) {
        $tracked = @(Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { Resolve-Path -Relative $_.FullName })
    }

    return @($tracked |
        ForEach-Object { Normalize-Path $_ } |
        Where-Object {
            $_ -match "\.(html|tsx|jsx|vue|svelte|astro|css|scss|sass)$" -or
            ($_ -match "^(src|app|web|pages|components|routes|views|public)/" -and $_ -match "\.(ts|js)$")
        } |
        Where-Object {
            $_ -notmatch "^(dist|build|coverage|node_modules|\.git|\.codex-local|out|docs/codex)/" -and
            $_ -notmatch "(package-lock\.json|package\.json|tsbuildinfo)$"
        } |
        Sort-Object -Unique)
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

$hits = [System.Collections.Generic.List[object]]::new()
$files = @(Get-UiFiles)

function Get-ElementWindow {
    param(
        [string[]]$Lines,
        [int]$Index,
        [int]$MaxLines = 12
    )

    $end = [Math]::Min($Lines.Count - 1, $Index + $MaxLines - 1)
    $parts = @()
    for ($j = $Index; $j -le $end; $j++) {
        $parts += [string]$Lines[$j]
        $joined = $parts -join "`n"
        if ($joined -match "/>|</(input|button|select|textarea)>|>") {
            return $joined
        }
    }
    return ($parts -join "`n")
}

function Test-WrappedByLabel {
    param(
        [string[]]$Lines,
        [int]$Index
    )

    $start = [Math]::Max(0, $Index - 16)
    $end = [Math]::Min($Lines.Count - 1, $Index + 16)
    $before = ($Lines[$start..$Index] -join "`n")
    $after = ($Lines[$Index..$end] -join "`n")
    return ($before -match "(?is)<label\b[^>]*>(?:(?!</label>).)*$" -and $after -match "(?is)</label>")
}

foreach ($file in $files) {
    if (!(Test-Path -LiteralPath $file -PathType Leaf)) { continue }
    $text = Get-Content -LiteralPath $file -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($text)) { continue }
    $lines = @($text -split "`r?`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        $lineNumber = $i + 1
        $nearStart = [Math]::Max(0, $i - 4)
        $nearEnd = [Math]::Min($lines.Count - 1, $i + 3)
        $nearText = ($lines[$nearStart..$nearEnd] -join "`n")

        if ($file -match "\.(html|tsx|jsx|vue|svelte|astro)$") {
            if ($line -match "<img\b" -and $line -notmatch "\balt\s*=") {
                Add-Hit -Hits $hits -Severity "RED" -File $file -Line $lineNumber -Issue "Image is missing an alt attribute." -Sample $line
            }
            if ($line -match "<input\b") {
                $inputBlock = Get-ElementWindow -Lines $lines -Index $i
                if ($inputBlock -notmatch "\btype\s*=\s*['`"]?(hidden|submit|button|checkbox|radio)" -and
                    $inputBlock -notmatch "(aria-label|aria-labelledby|id\s*=|title\s*=)" -and
                    $nearText -notmatch "(?is)<label\b[^>]*>.*<input\b.*</label>" -and
                    -not (Test-WrappedByLabel -Lines $lines -Index $i)) {
                    Add-Hit -Hits $hits -Severity "RED" -File $file -Line $lineNumber -Issue "Input may be missing a programmatic label." -Sample $inputBlock
                }
            }
            if ($line -match "<button\b") {
                $buttonBlock = Get-ElementWindow -Lines $lines -Index $i
                $buttonHasName = $buttonBlock -match "(aria-label|aria-labelledby|>\s*[^<{`\s])"
                if ($buttonBlock -match ">\s*</button>") {
                    Add-Hit -Hits $hits -Severity "RED" -File $file -Line $lineNumber -Issue "Button appears to have no accessible name." -Sample $buttonBlock
                } elseif ($buttonBlock -match "\b(onClick|className|class)=" -and -not $buttonHasName -and $buttonBlock -notmatch "icon" ) {
                    Add-Hit -Hits $hits -Severity "YELLOW" -File $file -Line $lineNumber -Issue "Icon-style button may need an accessible label." -Sample $buttonBlock
                }
            }
            if ($line -match "<a\b" -and $line -match "href\s*=\s*['`"]#['`"]") {
                Add-Hit -Hits $hits -Severity "YELLOW" -File $file -Line $lineNumber -Issue "Hash-only link may behave like a button or dead link." -Sample $line
            }
            if ($line -match "(click here|learn more|read more|more info)" ) {
                Add-Hit -Hits $hits -Severity "YELLOW" -File $file -Line $lineNumber -Issue "Link/button text may be too vague without surrounding context." -Sample $line
            }
        }

        if ($file -match "\.(css|scss|sass)$") {
            if ($line -match "outline\s*:\s*(0|none)" -and $nearText -notmatch ":focus-visible|focus-visible") {
                Add-Hit -Hits $hits -Severity "RED" -File $file -Line $lineNumber -Issue "Focus outline is removed without an obvious focus-visible replacement." -Sample $line
            }
            if ($line -match "prefers-reduced-motion" ) {
                Add-Hit -Hits $hits -Severity "INFO" -File $file -Line $lineNumber -Issue "Reduced-motion handling is present." -Sample $line
            }
        }
    }
}

$redCount = @($hits | Where-Object { $_.severity -eq "RED" }).Count
$yellowCount = @($hits | Where-Object { $_.severity -eq "YELLOW" }).Count
$infoCount = @($hits | Where-Object { $_.severity -eq "INFO" }).Count
$verdict = if ($redCount -gt 0) { "RED" } elseif ($yellowCount -gt 0) { "YELLOW" } else { "GREEN" }
$nextStep = if ($verdict -eq "RED") { "stop for human accessibility review" } elseif ($verdict -eq "YELLOW") { "continue but patch accessibility warnings soon" } else { "continue" }

$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$hitLines = if ($hits.Count -eq 0) {
    "- No deterministic accessibility issues found."
} else {
    ($hits | Select-Object -First $MaxHits | ForEach-Object {
        "- [{0}] ``{1}:{2}`` - {3}`n  ``{4}``" -f $_.severity, $_.file, $_.line, $_.issue, $_.sample
    }) -join "`n"
}

$report = @"
# Accessibility Review

Generated: $date
Project: $Project
Repo: $($repoPath.Path)

## Verdict
$verdict

## Accessibility Read
Ada checked deterministic accessibility risks: missing image alt text, unlabeled inputs, empty/icon-only buttons, dead hash links, vague link text, and removed focus outlines.

## Summary
- Files scanned: $($files.Count)
- RED issues: $redCount
- YELLOW issues: $yellowCount
- INFO signals: $infoCount

## Findings
$hitLines

## Stop Or Continue
$nextStep
"@

$outPath = Join-Path $repoPath.Path $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
$report | Set-Content -Path $outPath -Encoding UTF8

Write-Host "Accessibility review: $verdict"
Write-Host "Report: $OutFile"

if ($FailOnRed -and $verdict -eq "RED") { exit 1 }
exit 0
