[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [int]$MaxChangedFiles = 60,

    [int]$MaxCssDeltaKb = 80,

    [switch]$AllowMain,

    [switch]$AllowYellowCheckpoint,

    [switch]$Json
)

$ErrorActionPreference = "Continue"

function Add-Issue {
    param(
        [ValidateSet("FAIL", "WARN")]
        [string]$Level,
        [string]$Message
    )

    $script:Issues += [pscustomobject]@{
        level = $Level
        message = $Message
    }
}

function Normalize-Path {
    param([string]$Path)
    return ($Path -replace "\\", "/")
}

function Get-LatestMarkdownSection {
    param([string]$Path)

    if (!(Test-Path $Path)) {
        return ""
    }

    $content = Get-Content $Path -Raw
    $matches = [regex]::Matches($content, "(?m)^##\s+.+$")
    if ($matches.Count -eq 0) {
        return $content
    }

    $start = $matches[$matches.Count - 1].Index
    return $content.Substring($start)
}

$script:Issues = @()
$repoMatches = @(Resolve-Path $Repo -ErrorAction SilentlyContinue)
if ($repoMatches.Count -ne 1) {
    Write-Host "Repo not found or ambiguous: $Repo" -ForegroundColor Red
    exit 1
}

$repoPath = $repoMatches[0].Path
Push-Location $repoPath

$branch = git branch --show-current
$head = git rev-parse --short HEAD 2>$null
$dirty = @(git status --short)
$changed = @(git diff --name-only "$BaseBranch..HEAD" 2>$null | ForEach-Object { Normalize-Path $_ })
$changedStatus = @(git diff --name-status "$BaseBranch..HEAD" 2>$null)
$addedLines = @(git diff --unified=0 "$BaseBranch..HEAD" 2>$null | Where-Object { $_ -match "^\+" -and $_ -notmatch "^\+\+\+" })
$addedAppLines = @()
$currentDiffFile = ""
foreach ($line in @(git diff --unified=0 "$BaseBranch..HEAD" 2>$null)) {
    if ($line -match "^\+\+\+ b/(.+)$") {
        $currentDiffFile = Normalize-Path $Matches[1]
        continue
    }
    if ($line -match "^\+" -and $line -notmatch "^\+\+\+" -and $currentDiffFile -notmatch "^docs/codex/") {
        $addedAppLines += $line
    }
}

if ([string]::IsNullOrWhiteSpace($branch)) {
    Add-Issue "FAIL" "Could not determine current branch."
} elseif ($branch -eq $BaseBranch -and !$AllowMain) {
    Add-Issue "FAIL" "Debugger is running on $BaseBranch. Checkpoint branches should not be main."
}

if ($dirty.Count -gt 0) {
    Add-Issue "FAIL" "Working tree is dirty: $($dirty -join '; ')"
}

if ($changed.Count -eq 0) {
    Add-Issue "WARN" "No files changed compared with $BaseBranch."
}

if ($changed.Count -gt $MaxChangedFiles) {
    Add-Issue "FAIL" "Too many files changed compared with ${BaseBranch}: $($changed.Count), max $MaxChangedFiles."
}

$blockedPathPatterns = @(
    "^\.firebaserc$",
    "^firebase\.json$",
    "^firestore\.rules$",
    "^functions/",
    "^old-site/",
    "^dist/",
    "^build/",
    "^app-vNext/dist/",
    "^app-vNext/build/",
    "^coverage/",
    "^app-vNext/coverage/",
    "^\.env($|\.)",
    "(^|/)\.env($|\.)",
    "\.(pem|key|p12|pfx)$",
    "(^|/)package\.json$",
    "(^|/)package-lock\.json$",
    "(^|/)npm-shrinkwrap\.json$",
    "(^|/)pnpm-lock\.yaml$",
    "(^|/)yarn\.lock$"
)

$blockedFiles = @()
foreach ($file in $changed) {
    foreach ($pattern in $blockedPathPatterns) {
        if ($file -match $pattern) {
            $blockedFiles += $file
            break
        }
    }
}
if ($blockedFiles.Count -gt 0) {
    Add-Issue "FAIL" "Blocked file changes detected: $(($blockedFiles | Sort-Object -Unique) -join ', ')"
}

$suspiciousLinePatterns = @(
    "\bconsole\.(log|debug|trace)\b",
    "\bdebugger\b",
    "(?i)\b(TODO|FIXME|HACK)\b",
    "(?i)(api key|api-key|secret|bearer token|private key|password)",
    "(?i)(stripe|checkout|payment)",
    "(?i)(google analytics|gtag|meta pixel|hotjar|tracking|analytics)",
    "(?i)(firebase functions|httpsCallable|cloud function)",
    "(?i)(process\.env|import\.meta\.env)"
)

$suspiciousHits = @()
foreach ($line in $addedAppLines) {
    foreach ($pattern in $suspiciousLinePatterns) {
        if ($line -match $pattern) {
            $suspiciousHits += $line
            break
        }
    }
}
if ($suspiciousHits.Count -gt 0) {
    Add-Issue "FAIL" "Suspicious added lines found: $($suspiciousHits.Count)."
}

if (Test-Path "docs/codex/CHECKPOINT_REVIEW.md") {
    $review = Get-Content "docs/codex/CHECKPOINT_REVIEW.md" -Raw
    $verdictMatch = [regex]::Match($review, "(?im)^## Verdict\s*\r?\n\s*(GREEN|YELLOW|RED)\s*$")
    $verdict = if ($verdictMatch.Success) { $verdictMatch.Groups[1].Value.ToUpperInvariant() } else { "" }
    if ($verdict -eq "YELLOW" -and $AllowYellowCheckpoint) {
        Add-Issue "WARN" "Checkpoint verdict is YELLOW; allowed to continue after follow-up gates."
    } elseif ($verdict -ne "GREEN") {
        Add-Issue "FAIL" "Checkpoint verdict is not GREEN."
    }
    if ($review -match "(?im)^## Recommended Next Step\s*\r?\n\s*stop for human review\s*$") {
        Add-Issue "FAIL" "Checkpoint review requested human stop."
    }
} else {
    Add-Issue "WARN" "Missing docs/codex/CHECKPOINT_REVIEW.md."
}

if (Test-Path "docs/codex/NIGHTLY_REPORT.md") {
    $latestReport = Get-LatestMarkdownSection "docs/codex/NIGHTLY_REPORT.md"
    $failedReports = @($latestReport -split "\r?\n" | Where-Object { $_ -match "(?i)Build result:\s*(Failed|Skipped)" })
    if ($failedReports.Count -gt 0) {
        Add-Issue "WARN" "Latest report contains Failed/Skipped entries."
    }
} else {
    Add-Issue "WARN" "Missing docs/codex/NIGHTLY_REPORT.md."
}

if (Test-Path "docs/codex/NEXT_5_TASKS.md") {
    $generatedTasks = @(Select-String -Path "docs/codex/NEXT_5_TASKS.md" -Pattern "^\s*-\s+\[ \]\s+.+" | ForEach-Object { $_.Line.Trim() })
    if ($generatedTasks.Count -eq 0) {
        Add-Issue "WARN" "NEXT_5_TASKS.md exists but has no unchecked tasks."
    }
    $vagueTasks = @($generatedTasks | Where-Object { $_ -notmatch "(?i)do not|without|avoid|forbidden" })
    if ($vagueTasks.Count -gt 0) {
        Add-Issue "FAIL" "Generated task(s) missing explicit forbidden scope: $($vagueTasks.Count)."
    }
}

$cssFiles = @($changed | Where-Object { $_ -match "\.css$" })
foreach ($cssFile in $cssFiles) {
    $delta = git diff --numstat "$BaseBranch..HEAD" -- $cssFile
    if ($delta -match "^(\d+)\s+(\d+)\s+") {
        $added = [int]$Matches[1]
        $removed = [int]$Matches[2]
        $roughKb = [Math]::Round((($added - $removed) * 60) / 1024, 1)
        if ($roughKb -gt $MaxCssDeltaKb) {
            Add-Issue "WARN" "Large CSS growth estimate in ${cssFile}: about ${roughKb}KB."
        }
    }
}

$deletedFiles = @($changedStatus | Where-Object { $_ -match "^D\s+" })
if ($deletedFiles.Count -gt 0) {
    Add-Issue "WARN" "Deleted files detected: $($deletedFiles -join '; ')"
}

$failCount = @($script:Issues | Where-Object { $_.level -eq "FAIL" }).Count
$warnCount = @($script:Issues | Where-Object { $_.level -eq "WARN" }).Count
$result = if ($failCount -gt 0) { "FAIL" } elseif ($warnCount -gt 0) { "WARN" } else { "PASS" }

$summary = [pscustomobject]@{
    result = $result
    repo = $repoPath
    branch = $branch
    head = $head
    baseBranch = $BaseBranch
    changedFileCount = $changed.Count
    changedFiles = $changed
    issues = $script:Issues
}

if ($Json) {
    $summary | ConvertTo-Json -Depth 6
} else {
    Write-Host "Checkpoint debugger: $result" -ForegroundColor $(if ($result -eq "PASS") { "Green" } elseif ($result -eq "WARN") { "Yellow" } else { "Red" })
    Write-Host "Repo: $repoPath"
    Write-Host "Branch: $branch"
    Write-Host "HEAD: $head"
    Write-Host "Changed files vs ${BaseBranch}: $($changed.Count)"
    if ($script:Issues.Count -gt 0) {
        Write-Host ""
        Write-Host "Issues:"
        foreach ($issue in $script:Issues) {
            $color = if ($issue.level -eq "FAIL") { "Red" } else { "Yellow" }
            Write-Host "- [$($issue.level)] $($issue.message)" -ForegroundColor $color
        }
    }
}

Pop-Location

if ($failCount -gt 0) {
    exit 1
}
exit 0
