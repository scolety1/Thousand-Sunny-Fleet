[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [string]$ConfigPath = ".\projects.json",

    [ValidateSet("brief", "foundation", "shape", "simplicity", "polish", "proof", "parked")]
    [string]$Phase = "",

    [string]$ProductPromise = "",

    [string]$HumanTasteNote = "",

    [switch]$Init,

    [switch]$Status
)

$ErrorActionPreference = "Stop"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Get-ConfigPropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

if (!(Test-Path -LiteralPath $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$projects = @(Get-Content $ConfigPath -Raw | ConvertFrom-Json)
$ship = $projects | Where-Object { [string]$_.name -ceq $Project } | Select-Object -First 1
if ($null -eq $ship) {
    Write-Host "Project not found: $Project" -ForegroundColor Red
    exit 1
}

$repoPath = Resolve-Path -LiteralPath ([string]$ship.repo) -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo not found: $($ship.repo)" -ForegroundColor Red
    exit 1
}

$phasePath = Join-Path $repoPath.Path "docs\codex\PHASE_STATE.md"
New-Item -ItemType Directory -Force -Path (Split-Path $phasePath) | Out-Null

if ($Status -and !(Test-Path -LiteralPath $phasePath)) {
    Write-Host "$Project has no phase state yet: $phasePath" -ForegroundColor Yellow
    exit 0
}

if ($Status) {
    Get-Content -LiteralPath $phasePath
    exit 0
}

if (!$Init -and [string]::IsNullOrWhiteSpace($Phase) -and [string]::IsNullOrWhiteSpace($ProductPromise) -and [string]::IsNullOrWhiteSpace($HumanTasteNote)) {
    Write-Host "Nothing to update. Pass -Init, -Phase, -ProductPromise, or -HumanTasteNote." -ForegroundColor Yellow
    exit 0
}

$existing = if (Test-Path -LiteralPath $phasePath) { Get-Content -LiteralPath $phasePath -Raw } else { "" }

function Get-ExistingValue {
    param(
        [string]$Text,
        [string]$Name,
        [string]$Default
    )

    $match = [regex]::Match($Text, "(?im)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return $Default
}

$currentPhase = if (![string]::IsNullOrWhiteSpace($Phase)) { $Phase } else { Get-ExistingValue -Text $existing -Name "Current Phase" -Default "brief" }
$currentPromise = if (![string]::IsNullOrWhiteSpace($ProductPromise)) { $ProductPromise } else { Get-ExistingValue -Text $existing -Name "Product Promise" -Default "TODO: This demo helps [person] do [specific job] without [current pain]." }
$currentTasteNote = if (![string]::IsNullOrWhiteSpace($HumanTasteNote)) { $HumanTasteNote } else { Get-ExistingValue -Text $existing -Name "Human Taste Note" -Default "none" }
$updatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$content = @"
# Phase State

Current Phase: $currentPhase
Product Promise: $currentPromise
Human Taste Note: $currentTasteNote
Updated At: $updatedAt

## Phase Order

brief -> foundation -> shape -> simplicity -> polish -> proof -> parked

## Phase Locks

- Brief must define audience, promise, primary action, and what not to build.
- Foundation may add missing structure and core behavior.
- Shape may reorganize pages and flows, but should avoid feature sprawl.
- Simplicity should remove, combine, shorten, hide, or demote before adding.
- Polish should refine visual/copy details without changing the core flow.
- Proof should fix blockers only.
- Parked means review-ready; do not generate new work unless a human moves the phase.

## Upgrade Rules

- One primary action above the fold.
- No more features after Foundation unless a human moves the phase backward.
- Track whether each task makes the product clearer, simpler, more useful, or more beautiful.
- Keep one sentence product promise visible to the planner.
- Respect complexity budgets for sections, CTAs, choices, and visible copy.
- Protect the showable moment.
- Honor human taste notes.
- Use stronger judgment for Shape, Simplicity, and Polish.
"@

Set-Content -LiteralPath $phasePath -Value $content
Write-Host "Phase state updated for $Project`: $phasePath" -ForegroundColor Green
Write-Host "Current Phase: $currentPhase"
