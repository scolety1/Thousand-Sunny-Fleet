[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [string]$ConfigPath = ".\projects.json",

    [ValidateSet("brief", "foundation", "shape", "simplicity", "polish", "proof", "parked")]
    [string]$Phase = "",

    [string]$ProductPromise = "",

    [string]$PrimaryAction = "",

    [string]$ShowableMoment = "",

    [string]$WhatNotToBuild = "",

    [ValidateSet("", "true", "false")]
    [string]$NoMoreFeaturesLock = "",

    [string]$ComplexityBudget = "",

    [string]$BeforeAfterJudgment = "",

    [string]$HumanTasteNote = "",

    [ValidateSet("", "budget", "balanced", "judgment-heavy")]
    [string]$PhaseModelPolicy = "",

    [ValidateSet("", "ACTIVE", "PARKED_REVIEW_READY")]
    [string]$ParkingState = "",

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

$projects = @(Get-Content $ConfigPath -Raw | ConvertFrom-Json | ForEach-Object { $_ })
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

if (!$Init -and [string]::IsNullOrWhiteSpace($Phase) -and [string]::IsNullOrWhiteSpace($ProductPromise) -and [string]::IsNullOrWhiteSpace($PrimaryAction) -and [string]::IsNullOrWhiteSpace($ShowableMoment) -and [string]::IsNullOrWhiteSpace($WhatNotToBuild) -and [string]::IsNullOrWhiteSpace($NoMoreFeaturesLock) -and [string]::IsNullOrWhiteSpace($ComplexityBudget) -and [string]::IsNullOrWhiteSpace($BeforeAfterJudgment) -and [string]::IsNullOrWhiteSpace($HumanTasteNote) -and [string]::IsNullOrWhiteSpace($PhaseModelPolicy) -and [string]::IsNullOrWhiteSpace($ParkingState)) {
    Write-Host "Nothing to update. Pass -Init, -Phase, or a phase data field." -ForegroundColor Yellow
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
$currentPrimaryAction = if (![string]::IsNullOrWhiteSpace($PrimaryAction)) { $PrimaryAction } else { Get-ExistingValue -Text $existing -Name "Primary Action" -Default "TODO: the one thing the visitor should do first." }
$currentShowableMoment = if (![string]::IsNullOrWhiteSpace($ShowableMoment)) { $ShowableMoment } else { Get-ExistingValue -Text $existing -Name "Showable Moment" -Default "TODO: the moment that makes the buyer say 'I get it.'" }
$currentWhatNotToBuild = if (![string]::IsNullOrWhiteSpace($WhatNotToBuild)) { $WhatNotToBuild } else { Get-ExistingValue -Text $existing -Name "What Not To Build" -Default "Do not add broad platform framing, fake enterprise dashboards, pricing, backend, auth, payments, analytics, or extra feature tours unless explicitly requested." }
$currentNoMoreFeaturesLock = if (![string]::IsNullOrWhiteSpace($NoMoreFeaturesLock)) { $NoMoreFeaturesLock } else { Get-ExistingValue -Text $existing -Name "No More Features Lock" -Default $(if ($currentPhase -in @("simplicity", "polish", "proof", "parked")) { "true" } else { "false" }) }
$currentComplexityBudget = if (![string]::IsNullOrWhiteSpace($ComplexityBudget)) { $ComplexityBudget } else { Get-ExistingValue -Text $existing -Name "Complexity Budget" -Default "Above the fold: one primary action, no more than three secondary choices, one short intro sentence, and no competing feature cards." }
$currentBeforeAfterJudgment = if (![string]::IsNullOrWhiteSpace($BeforeAfterJudgment)) { $BeforeAfterJudgment } else { Get-ExistingValue -Text $existing -Name "Before/After Judgment" -Default "Each task must make the product clearer, simpler, more useful, or more beautiful than the previous screenshot/state." }
$currentTasteNote = if (![string]::IsNullOrWhiteSpace($HumanTasteNote)) { $HumanTasteNote } else { Get-ExistingValue -Text $existing -Name "Human Taste Note" -Default "none" }
$currentPhaseModelPolicy = if (![string]::IsNullOrWhiteSpace($PhaseModelPolicy)) { $PhaseModelPolicy } else { Get-ExistingValue -Text $existing -Name "Phase Model Policy" -Default $(if ($currentPhase -in @("shape", "simplicity", "polish")) { "judgment-heavy" } elseif ($currentPhase -eq "foundation") { "budget" } else { "balanced" }) }
$currentParkingState = if (![string]::IsNullOrWhiteSpace($ParkingState)) { $ParkingState } elseif ($currentPhase -eq "parked") { "PARKED_REVIEW_READY" } else { Get-ExistingValue -Text $existing -Name "Parking State" -Default "ACTIVE" }
$updatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$content = @"
# Phase State

Current Phase: $currentPhase
Product Promise: $currentPromise
Primary Action: $currentPrimaryAction
Showable Moment: $currentShowableMoment
What Not To Build: $currentWhatNotToBuild
No More Features Lock: $currentNoMoreFeaturesLock
Complexity Budget: $currentComplexityBudget
Before/After Judgment: $currentBeforeAfterJudgment
Human Taste Note: $currentTasteNote
Phase Model Policy: $currentPhaseModelPolicy
Parking State: $currentParkingState
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
- Park review-ready ships instead of continuing to generate improvements.
"@

Set-Content -LiteralPath $phasePath -Value $content
Write-Host "Phase state updated for $Project`: $phasePath" -ForegroundColor Green
Write-Host "Current Phase: $currentPhase"
