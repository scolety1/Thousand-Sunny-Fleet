[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [string]$OutFile = "docs/codex/MIGRATION_REVIEW.md",

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Test-Heading {
    param(
        [string]$Text,
        [string]$Heading
    )

    return ($Text -match "(?im)^##\s+$([regex]::Escape($Heading))\s*$")
}

function Get-FieldValue {
    param(
        [string]$Text,
        [string]$Field
    )

    $match = [regex]::Match($Text, "(?im)^\s*$([regex]::Escape($Field))\s*:\s*(.+?)\s*$")
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return ""
}

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Stop-WithMessage "Repo not found: $Repo"
}

Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)"
}

$proposalPath = "docs/codex/MIGRATION_PROPOSAL.md"
$approvalPath = "docs/codex/MIGRATION_APPROVAL.md"
$outPath = $OutFile

$issues = [System.Collections.Generic.List[string]]::new()
if (!(Test-Path $proposalPath)) {
    $issues.Add("Missing docs/codex/MIGRATION_PROPOSAL.md.") | Out-Null
} else {
    $proposal = Get-Content $proposalPath -Raw
    foreach ($heading in @("Summary", "Environment", "Reversibility", "Forward Only Justification", "Data Impact", "Data Loss Detection", "Affected Tables Or Collections", "Local Run Evidence", "Rollback Plan")) {
        if (!(Test-Heading -Text $proposal -Heading $heading)) {
            $issues.Add("MIGRATION_PROPOSAL.md missing heading: $heading.") | Out-Null
        }
    }
    if ($proposal -match "(?i)\bTBD\b|\bTODO\b|\bunknown\b") {
        $issues.Add("MIGRATION_PROPOSAL.md still contains TBD/TODO/unknown placeholders.") | Out-Null
    }
    if ($proposal -match "(?i)\bdrop\s+table\b|\btruncate\b|\bdelete\s+from\b|\bdrop\s+column\b|\bdestroy\b|\bpurge\b") {
        if ($proposal -notmatch "(?im)^\s*Data Loss Accepted:\s*YES\s*$") {
            $issues.Add("Potential data-loss operation found without 'Data Loss Accepted: YES'.") | Out-Null
        }
    }
}

if (!(Test-Path $approvalPath)) {
    $issues.Add("Missing docs/codex/MIGRATION_APPROVAL.md.") | Out-Null
} else {
    $approval = Get-Content $approvalPath -Raw
    if ($approval -notmatch "(?im)^\s*Status:\s*APPROVED\s*$") {
        $issues.Add("MIGRATION_APPROVAL.md is not Status: APPROVED.") | Out-Null
    }
    $environment = if ($proposal) { Get-FieldValue -Text $proposal -Field "Environment" } else { "" }
    if ($environment -match "(?i)\bproduction\b") {
        if ($approval -notmatch "(?im)^\s*Human Approval:\s*APPROVED\s*$") {
            $issues.Add("Production migration requires 'Human Approval: APPROVED' in MIGRATION_APPROVAL.md.") | Out-Null
        }
    }
}

$verdict = if ($issues.Count -eq 0) { "GREEN" } else { "RED" }
$lines = @(
    "# Migration Review",
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
    $lines += "- Migration proposal and approval gate are present."
} else {
    $issues | ForEach-Object { $lines += "- $_" }
}
$lines += ""
$lines += "## Required Evidence"
$lines += ""
$lines += "- Reversibility or forward-only justification"
$lines += "- Data-loss detection and explicit acceptance for destructive operations"
$lines += "- Affected tables or collections"
$lines += "- Local run evidence"
$lines += "- Rollback plan"
$lines += "- Human approval for production migrations"

if (!$ValidateOnly -or $issues.Count -gt 0) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
    Set-Content -Path $outPath -Value $lines -Encoding UTF8
}

if ($issues.Count -gt 0) {
    Write-Host "Migration review failed." -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Migration review passed." -ForegroundColor Green
exit 0
