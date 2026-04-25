[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [switch]$Template,

    [switch]$IncludeDependencyChange,

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

    if (!(Test-Path -LiteralPath $Path)) { return $false }
    $text = Get-Content -LiteralPath $Path -Raw
    return ($text -match "(?im)^\s*Status:\s*APPROVED\s*$")
}

function Test-Headings {
    param(
        [string]$Path,
        [string[]]$Headings
    )

    if (!(Test-Path -LiteralPath $Path)) { return $false }
    $text = Get-Content -LiteralPath $Path -Raw
    foreach ($heading in $Headings) {
        if ($text -notmatch "(?im)^##\s+$([regex]::Escape($heading))\s*$") {
            return $false
        }
    }
    if ($text -match "(?im)^\s*(TBD\.?|TODO|-\s+TBD\.?)\s*$") {
        return $false
    }
    return $true
}

function Write-TemplateFile {
    param(
        [string]$Path,
        [string]$Value
    )

    if (Test-Path -LiteralPath $Path) { return }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
    Set-Content -LiteralPath $Path -Value $Value
}

$repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Stop-WithMessage "Repo not found: $Repo"
}

$codexDir = Join-Path $repoPath.Path "docs\codex"
if ($Template) {
    Write-TemplateFile -Path (Join-Path $codexDir "SOFTWARE_FEATURE_PLAN.md") -Value @"
# Software Feature Plan

## Active Work Pack

Name the active work pack this feature pack advances.

## User Workflow

Describe the end-to-end workflow the feature pack must make better.

## Files And Modules

- List the expected file and module boundaries.

## Runtime Scenarios

- List the workflow scenarios that must be verified in RUNTIME_CHECKS.md.

## Rollback Plan

Describe how to back out the feature pack safely.

## Acceptance Commands

- List the exact commands that must appear in task accept: metadata.
"@

    Write-TemplateFile -Path (Join-Path $codexDir "SOFTWARE_FEATURE_APPROVAL.md") -Value @"
# Software Feature Approval

Status: DRAFT
Approved by:
Approved at:

Notes:
- Change Status to APPROVED only after reviewing the feature plan, scopes, runtime scenarios, rollback plan, and acceptance commands.
"@

    Write-TemplateFile -Path (Join-Path $codexDir "RUNTIME_CHECKS.md") -Value @"
# Runtime Checks

- command: npm.cmd run build
"@

    if ($IncludeDependencyChange) {
        Write-TemplateFile -Path (Join-Path $codexDir "DEPENDENCY_PROPOSAL.md") -Value @"
# Dependency Proposal

Status: DRAFT

## Proposed Dependencies

- Name: TBD
  Purpose: TBD
  License: TBD
  Maintenance status: TBD
  Known risks: TBD
  Alternatives: TBD
"@

        Write-TemplateFile -Path (Join-Path $codexDir "DEPENDENCY_APPROVAL.md") -Value @"
# Dependency Approval

Status: DRAFT
Approved by:
Approved at:

Notes:
- Change Status to APPROVED only after dependency review.
"@
    }
}

$issues = [System.Collections.Generic.List[string]]::new()
if (!(Test-ApprovedFile -Path (Join-Path $codexDir "ARCHITECTURE_APPROVAL.md"))) {
    $issues.Add("ARCHITECTURE_APPROVAL.md must say Status: APPROVED.") | Out-Null
}
if (!(Test-Headings -Path (Join-Path $codexDir "SOFTWARE_FEATURE_PLAN.md") -Headings @("Active Work Pack", "User Workflow", "Files And Modules", "Runtime Scenarios", "Rollback Plan", "Acceptance Commands"))) {
    $issues.Add("SOFTWARE_FEATURE_PLAN.md is missing required headings or still contains placeholders.") | Out-Null
}
if (!(Test-ApprovedFile -Path (Join-Path $codexDir "SOFTWARE_FEATURE_APPROVAL.md"))) {
    $issues.Add("SOFTWARE_FEATURE_APPROVAL.md must say Status: APPROVED.") | Out-Null
}
if (!(Test-Path -LiteralPath (Join-Path $codexDir "RUNTIME_CHECKS.md"))) {
    $issues.Add("RUNTIME_CHECKS.md is required for feature-pack mode.") | Out-Null
}
if ($IncludeDependencyChange -and !(Test-ApprovedFile -Path (Join-Path $codexDir "DEPENDENCY_APPROVAL.md"))) {
    $issues.Add("DEPENDENCY_APPROVAL.md must say Status: APPROVED for package/dependency changes.") | Out-Null
}

if ($issues.Count -gt 0) {
    Write-Host "Software feature mode is not ready:" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Software feature mode gate passed for $($repoPath.Path)." -ForegroundColor Green
exit 0
