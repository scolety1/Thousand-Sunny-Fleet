[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$OutFile = "docs/codex/SENSITIVE_SYSTEMS_REVIEW.md",

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Test-ApprovedFile {
    param([string]$Path)
    if (!(Test-Path $Path)) { return $false }
    $text = Get-Content $Path -Raw
    return ($text -match "(?im)^\s*Status:\s*APPROVED\s*$")
}

function Test-Heading {
    param([string]$Text, [string]$Heading)
    return ($Text -match "(?im)^##\s+$([regex]::Escape($Heading))\s*$")
}

function Remove-NegativeSensitiveClauses {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $cleaned = [string]$Text
    $cleaned = [regex]::Replace($cleaned, "(?i)(^|[\r\n]+|[.!?;]\s+)\s*(?:[-*+]\s*)?(?:\[[^\]]+\]\s*)?(do\s+not|don't|without|no)\s+[^.!?;\r\n]*(auth|login|oauth|permission|payment|stripe|checkout|billing|fetch\s*\(|axios|openai|anthropic|gemini|supabase|firebase|https?://|backend|api|secret|data\s+fetching)[^.!?;\r\n]*[.!?]?", " ")
    $cleaned = [regex]::Replace($cleaned, "(?i)(^|[\r\n]+|[.!?;]\s+)\s*(?:[-*+]\s*)?(?:\[[^\]]+\]\s*)?(?:while\s+)?leav(?:e|ing)\s+[^.!?;\r\n]*(auth|login|oauth|permission|payment|stripe|checkout|billing|fetch\s*\(|axios|openai|anthropic|gemini|supabase|firebase|https?://|backend|api|secret|data\s+fetching)[^.!?;\r\n]*(untouched|unchanged|alone)[^.!?;\r\n]*[.!?]?", " ")
    $cleaned = [regex]::Replace($cleaned, "(?i)[^.!?;\r\n]*(auth|login|oauth|permission|payment|stripe|checkout|billing|fetch\s*\(|axios|openai|anthropic|gemini|supabase|firebase|https?://|backend|api|secret|data\s+fetching)[^.!?;\r\n]*(untouched|unchanged|alone)[^.!?;\r\n]*[.!?]?", " ")
    return $cleaned
}

function Test-GeneratedSensitiveReportPath {
    param([string]$Path)

    $normalized = ([string]$Path).Replace("\", "/")
    return $normalized -match "^docs/codex/(CHECKPOINT_REVIEW|JOEY_SECURITY_REVIEW|ROBIN_COPY_REVIEW|SENSITIVE_SYSTEMS_REVIEW|SIMON_DESIGN_REVIEW|VISUAL_BUGS|NIGHTLY_REPORT|NEXT_5_TASKS|TASK_QUEUE|MAGIC_SCORECARD|WORK_PACK_STATUS|QUARANTINED_TASKS)\.md$"
}

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }
Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) { Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)" }

$issues = [System.Collections.Generic.List[string]]::new()

$diff = @(git diff --cached --unified=0 2>$null)
$addedLines = @($diff | Where-Object { ([string]$_).StartsWith("+") -and !([string]$_).StartsWith("+++") })
$registryAddedLines = [System.Collections.Generic.List[string]]::new()
$currentDiffPath = ""
foreach ($line in @($diff)) {
    $text = [string]$line
    if ($text.StartsWith("+++ b/")) {
        $currentDiffPath = $text.Substring(6)
        continue
    }
    if (!$text.StartsWith("+") -or $text.StartsWith("+++")) { continue }
    if (Test-GeneratedSensitiveReportPath -Path $currentDiffPath) { continue }
    $registryAddedLines.Add($text.Substring(1)) | Out-Null
}

$sensitiveIntentText = Remove-NegativeSensitiveClauses -Text ($registryAddedLines -join "`n")
$needsRegistry = ($sensitiveIntentText -match "(?i)\bfetch\s*\(|\baxios\b|\bopenai\b|\banthropic\b|\bgemini\b|\bstripe\b|\bsupabase\b|\bfirebase\b|\bhttps?://")

$registryPath = "docs/codex/EXTERNAL_SERVICES.md"
if (Test-Path $registryPath) {
    $registry = Get-Content $registryPath -Raw
    foreach ($heading in @("Services", "Environment Variables", "Scopes", "Cost Risk", "Data Sent", "Approval Status")) {
        if (!(Test-Heading -Text $registry -Heading $heading)) {
            $issues.Add("EXTERNAL_SERVICES.md missing heading: $heading.") | Out-Null
        }
    }
} elseif ($needsRegistry) {
    $issues.Add("Missing docs/codex/EXTERNAL_SERVICES.md for external service work.") | Out-Null
}

if ((Test-Path "docs/codex/AUTH_POLICY.md") -and !(Test-ApprovedFile -Path "docs/codex/AUTH_APPROVAL.md")) {
    $issues.Add("AUTH_POLICY.md exists but AUTH_APPROVAL.md is not Status: APPROVED.") | Out-Null
}

if ((Test-Path "docs/codex/PAYMENT_RISK.md") -and !(Test-ApprovedFile -Path "docs/codex/PAYMENT_APPROVAL.md")) {
    $issues.Add("PAYMENT_RISK.md exists but PAYMENT_APPROVAL.md is not Status: APPROVED.") | Out-Null
}

$secretPatterns = @(
    "sk-[A-Za-z0-9_-]{20,}",
    "AIza[0-9A-Za-z_-]{20,}",
    "xox[baprs]-[A-Za-z0-9-]{10,}",
    "(?i)api[_-]?key\s*[:=]\s*['""][^'""]{12,}['""]",
    "(?i)secret\s*[:=]\s*['""][^'""]{12,}['""]",
    "(?i)bearer\s+[A-Za-z0-9._-]{20,}"
)
foreach ($line in @($diff)) {
    $text = [string]$line
    if (!$text.StartsWith("+") -or $text.StartsWith("+++")) { continue }
    foreach ($pattern in $secretPatterns) {
        if ($text -match $pattern) {
            $issues.Add("Possible secret in staged diff: $($text.Substring(0, [Math]::Min(120, $text.Length)))") | Out-Null
            break
        }
    }
}

$verdict = if ($issues.Count -eq 0) { "GREEN" } else { "RED" }
$lines = @(
    "# Sensitive Systems Review",
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
    $lines += "- No staged secret patterns or unapproved sensitive-system docs found."
} else {
    $issues | ForEach-Object { $lines += "- $_" }
}
$lines += ""
$lines += "## Required Gates"
$lines += ""
$lines += "- Auth changes require AUTH_POLICY.md and AUTH_APPROVAL.md."
$lines += "- Payment changes require PAYMENT_RISK.md and PAYMENT_APPROVAL.md."
$lines += "- External services require EXTERNAL_SERVICES.md."
$lines += "- Production credentials and payment activation remain human-controlled."

if (!$ValidateOnly -or $issues.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -Path $OutFile -Value $lines
}

if ($issues.Count -gt 0) {
    Write-Host "Sensitive systems review failed." -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Sensitive systems review passed." -ForegroundColor Green
exit 0
