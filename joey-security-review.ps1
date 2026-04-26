[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$BaseBranch = "main",

    [string]$Project = "",

    [string]$OutFile = "docs/codex/JOEY_SECURITY_REVIEW.md"
)

$ErrorActionPreference = "Continue"

function Normalize-Path {
    param([string]$Path)
    return ($Path -replace "\\", "/")
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

$branch = git branch --show-current
$head = git rev-parse --short HEAD 2>$null
$dirty = @(git status --short)
$changed = @(git diff --name-only "$BaseBranch..HEAD" 2>$null | ForEach-Object { Normalize-Path $_ })
$changedStatus = @(git diff --name-status "$BaseBranch..HEAD" 2>$null)
$diffLines = @(git diff --unified=0 "$BaseBranch..HEAD" 2>$null)

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
    "(^|/)yarn\.lock$",
    "(^|/)CNAME$"
)

$securityPatterns = @(
    "(?i)(api[_ -]?key|secret|private[_ -]?key|bearer token|access token|password|credential)",
    "(?i)(process\.env|import\.meta\.env)",
    "(?i)(stripe|checkout|payment|billing)",
    "(?i)(firebase functions|httpsCallable|cloud function|firestore\.rules|auth provider)",
    "(?i)(google analytics|gtag|meta pixel|hotjar|tracking|analytics)",
    "(?i)(innerHTML\s*=|dangerouslySetInnerHTML|eval\(|new Function\()",
    "(?i)(fetch\(|XMLHttpRequest|axios\.)"
)

$approvalPath = "docs/codex/SECURITY_APPROVAL.md"
$approvalText = if (Test-Path $approvalPath) { Get-Content $approvalPath -Raw } else { "" }
$approvalIsActive = $approvalText -match "(?im)^\s*Status:\s*APPROVED\s*$"

function Get-ApprovalList {
    param(
        [string]$Text,
        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }

    $escapedHeading = [regex]::Escape($Heading)
    $match = [regex]::Match($Text, "(?ims)^##\s+$escapedHeading\s*$\s*(.*?)(?=^##\s+|\z)")
    if (!$match.Success) { return @() }

    return @(
        $match.Groups[1].Value -split "`r?`n" |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -match "^-\s+" } |
            ForEach-Object { Normalize-Path ($_.Substring(1).Trim()) } |
            Where-Object { ![string]::IsNullOrWhiteSpace($_) }
    )
}

$approvedBlockedFiles = if ($approvalIsActive) { @(Get-ApprovalList -Text $approvalText -Heading "Approved Blocked Files") } else { @() }
$approvedSensitiveLines = if ($approvalIsActive) { @(Get-ApprovalList -Text $approvalText -Heading "Approved Sensitive Lines") } else { @() }

function Test-ApprovedBlockedFile {
    param([string]$File)

    if (!$approvalIsActive) { return $false }
    $normalized = Normalize-Path $File
    return ($approvedBlockedFiles -contains $normalized)
}

function Test-ApprovedSensitiveLine {
    param(
        [string]$File,
        [string]$Line
    )

    if (!$approvalIsActive) { return $false }
    $normalized = Normalize-Path $File
    $trimmed = $Line.Trim()
    foreach ($approved in $approvedSensitiveLines) {
        if ($approved -eq "$normalized`: $trimmed") {
            return $true
        }
    }
    return $false
}

$storageSetPattern = "(?i)\b(window\.)?(localStorage|sessionStorage)\.setItem\s*\("
$storageSensitivePattern = "(?i)(api[_ -]?key|secret|private[_ -]?key|bearer|access[_ -]?token|refresh[_ -]?token|password|credential|auth|jwt|stripe|checkout|payment|billing)"

function Test-SensitiveAddedLine {
    param([string]$Line)

    foreach ($pattern in $securityPatterns) {
        if ($Line -match $pattern) {
            return $true
        }
    }

    if ($Line -match $storageSetPattern -and $Line -match $storageSensitivePattern) {
        return $true
    }

    return $false
}

$blockedFiles = @()
foreach ($file in $changed) {
    if (Test-ApprovedBlockedFile -File $file) { continue }
    foreach ($pattern in $blockedPathPatterns) {
        if ($file -match $pattern) {
            $blockedFiles += $file
            break
        }
    }
}
$blockedFiles = @($blockedFiles | Sort-Object -Unique)

$addedHits = @()
$currentFile = ""
foreach ($line in $diffLines) {
    if ($line -match "^\+\+\+ b/(.+)$") {
        $currentFile = Normalize-Path $Matches[1]
        continue
    }
    if ($line -match "^\+" -and $line -notmatch "^\+\+\+" -and $currentFile -notmatch "^docs/codex/") {
        if (Test-SensitiveAddedLine -Line $line) {
            if (Test-ApprovedSensitiveLine -File $currentFile -Line $line.Substring(1)) {
                continue
            }
            $addedHits += [pscustomobject]@{
                file = $currentFile
                line = $line.Substring(1).Trim()
            }
        }
    }
}

$deletedFiles = @($changedStatus | Where-Object { $_ -match "^D\s+" })
$highIssues = @()
$mediumIssues = @()

if ($dirty.Count -gt 0) {
    $highIssues += "Working tree is dirty: $($dirty -join '; ')"
}
if ($blockedFiles.Count -gt 0) {
    $highIssues += "Blocked or sensitive file changes: $($blockedFiles -join ', ')"
}
if ($addedHits.Count -gt 0) {
    $highIssues += "Security-sensitive added lines found: $($addedHits.Count)"
}
if ($deletedFiles.Count -gt 0) {
    $mediumIssues += "Deleted files present: $($deletedFiles -join '; ')"
}

$verdict = if ($highIssues.Count -gt 0) { "RED" } elseif ($mediumIssues.Count -gt 0) { "YELLOW" } else { "GREEN" }
$nextStep = if ($verdict -eq "RED") { "stop for human security review" } elseif ($verdict -eq "YELLOW") { "patch or inspect before merge" } else { "continue" }

$date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines = @(
    "# Joey Security Review",
    "",
    "Generated: $date",
    "Project: $Project",
    "Branch: $branch",
    "HEAD: $head",
    "Base branch: $BaseBranch",
    "",
    "## Verdict",
    $verdict,
    "",
    "## Joey's Read",
    "Joey checked the doors, windows, config files, dependency locks, secrets, auth/payment surfaces, tracking, and suspicious added code.",
    "",
    "## Security Findings"
)

if ($highIssues.Count -eq 0 -and $mediumIssues.Count -eq 0) {
    $lines += "- No blocking security issues detected by automated review."
} else {
    foreach ($issue in $highIssues) {
        $lines += "- [HIGH] $issue"
    }
    foreach ($issue in $mediumIssues) {
        $lines += "- [MEDIUM] $issue"
    }
}

$lines += ""
$lines += "## Changed Files"
if ($changed.Count -eq 0) {
    $lines += "- None"
} else {
    foreach ($file in $changed) {
        $lines += "- $file"
    }
}

$lines += ""
$lines += "## Sensitive Added Lines"
if ($addedHits.Count -eq 0) {
    $lines += "- None"
} else {
    foreach ($hit in $addedHits | Select-Object -First 30) {
        $safeLine = $hit.line
        if ($safeLine.Length -gt 180) {
            $safeLine = $safeLine.Substring(0, 180) + "..."
        }
        $lines += "- $($hit.file): $safeLine"
    }
}

$lines += ""
$lines += "## Recommended Next Step"
$lines += $nextStep
$lines += ""
$lines += "## Notes"
$lines += "- Joey is a guardrail reviewer, not a full penetration test."
$lines += "- Local storage is allowed for harmless local-only UI state, but still blocked when it appears to store auth, payment, token, credential, or secret data."
$lines += "- Project-specific approvals may allow exact previously reviewed blocked files or exact sensitive lines through docs/codex/SECURITY_APPROVAL.md."
$lines += "- A GREEN result means no obvious unattended security regression was detected."
$lines += "- Human review is still required before merge."

$outPath = Join-Path $repoPath.Path $OutFile
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
Set-Content -Path $outPath -Value $lines

Write-Host "Wrote $OutFile" -ForegroundColor Green

if ($verdict -eq "RED") {
    exit 1
}

exit 0
