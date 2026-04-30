[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [string]$ConfigPath = ".\projects.json",

    [ValidateSet("brief", "foundation", "shape", "simplicity", "polish", "proof", "parked", "repair", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof")]
    [string]$Phase = "",

    [string]$ProductPromise = "",

    [string]$Audience = "",

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

    [string]$EvidenceRequired = "",

    [string]$DoneSignal = "",

    [string]$NextPhaseCriteria = "",

    [string]$RepairTrigger = "",

    [ValidateSet("", "brief", "foundation", "shape", "simplicity", "polish", "proof", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof")]
    [string]$RepairReturnPhase = "",

    [switch]$Init,

    [switch]$Status,

    [switch]$Validate
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

if (($Status -or $Validate) -and !(Test-Path -LiteralPath $phasePath)) {
    Write-Host "$Project has no phase state yet: $phasePath" -ForegroundColor Yellow
    exit 0
}

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

if ($Status) {
    Get-Content -LiteralPath $phasePath
    exit 0
}

if ($Validate) {
    $text = Get-Content -LiteralPath $phasePath -Raw
    $errors = @()
    $required = @(
        "Current Phase",
        "Audience",
        "Product Promise",
        "Primary Action",
        "Showable Moment",
        "What Not To Build",
        "Complexity Budget",
        "Before/After Judgment",
        "Evidence Required",
        "Done Signal",
        "Next Phase Criteria",
        "Phase Model Policy",
        "Parking State"
    )
    foreach ($field in $required) {
        $value = Get-ExistingValue -Text $text -Name $field -Default ""
        if ([string]::IsNullOrWhiteSpace($value) -or $value -match '^TODO:') {
            $errors += "$field is missing or still TODO."
        }
    }

    $phaseForValidation = Get-ExistingValue -Text $text -Name "Current Phase" -Default ""
    $websitePhases = @("brief", "foundation", "shape", "simplicity", "polish", "proof", "parked")
    if ($phaseForValidation -in $websitePhases) {
        $stageRulesPath = Join-Path $repoPath.Path "docs\codex\WEBSITE_STAGE_RULES.md"
        $doneContractPath = Join-Path $repoPath.Path "docs\codex\DONE_CONTRACT.md"
        if (!(Test-Path -LiteralPath $stageRulesPath)) {
            $errors += "WEBSITE_STAGE_RULES.md is required for website phase '$phaseForValidation'. Run fleet-website-stages.ps1 -Project $Project -WriteReference from the fleet control room."
        } else {
            $stageRulesText = Get-Content -LiteralPath $stageRulesPath -Raw
            foreach ($stage in $websitePhases) {
                if ($stageRulesText -notmatch "(?m)^## $([regex]::Escape($stage))\s*$") {
                    $errors += "WEBSITE_STAGE_RULES.md is missing the '$stage' stage contract."
                }
            }
            foreach ($requiredPhrase in @("Allowed work:", "Forbidden work:", "Exit criteria:", "Reviewer gates:", "Auto-advance rule:", "Stop rules:")) {
                if ($stageRulesText -notmatch [regex]::Escape($requiredPhrase)) {
                    $errors += "WEBSITE_STAGE_RULES.md is missing '$requiredPhrase'."
                }
            }
        }
        if (!(Test-Path -LiteralPath $doneContractPath)) {
            $errors += "DONE_CONTRACT.md is required for website phase '$phaseForValidation'. Run fleet-completion-contract.ps1 -Project $Project -Write from the fleet control room."
        } else {
            $doneContractText = Get-Content -LiteralPath $doneContractPath -Raw
            foreach ($heading in @("Current Stage", "Product Target", "Done Enough", "Must Not Do", "Evidence Required", "Advance Or Park Rule")) {
                if ($doneContractText -notmatch "(?m)^## $([regex]::Escape($heading))\s*$") {
                    $errors += "DONE_CONTRACT.md is missing the '$heading' section."
                }
            }
            foreach ($requiredPhrase in @("Audience:", "Product promise:", "Primary action:", "Showable moment:", "Build/check command:", "Preview route(s):")) {
                if ($doneContractText -notmatch [regex]::Escape($requiredPhrase)) {
                    $errors += "DONE_CONTRACT.md is missing '$requiredPhrase'."
                }
            }
            if ($doneContractText -match "TODO:") {
                $errors += "DONE_CONTRACT.md still contains TODO."
            }
        }
    }

    $featureLockForValidation = Get-ExistingValue -Text $text -Name "No More Features Lock" -Default ""
    if ($phaseForValidation -in @("simplicity", "polish", "proof", "parked", "repair", "analysis-proof") -and $featureLockForValidation -ne "true") {
        $errors += "No More Features Lock must be true in $phaseForValidation phase."
    }

    $parkingForValidation = Get-ExistingValue -Text $text -Name "Parking State" -Default ""
    if ($phaseForValidation -eq "parked" -and $parkingForValidation -ne "PARKED_REVIEW_READY") {
        $errors += "Parking State must be PARKED_REVIEW_READY when Current Phase is parked."
    }

    if ($phaseForValidation -eq "repair") {
        $repairTriggerForValidation = Get-ExistingValue -Text $text -Name "Repair Trigger" -Default ""
        $repairReturnForValidation = Get-ExistingValue -Text $text -Name "Repair Return Phase" -Default ""
        if ([string]::IsNullOrWhiteSpace($repairTriggerForValidation) -or $repairTriggerForValidation -match '^TODO:') {
            $errors += "Repair Trigger is required when Current Phase is repair."
        }
        if ($repairReturnForValidation -notin @("brief", "foundation", "shape", "simplicity", "polish", "proof", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof")) {
            $errors += "Repair Return Phase must name the prior non-repair phase."
        }
    }

    if ($errors.Count -gt 0) {
        Write-Host "Phase state validation failed for $Project" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
        exit 1
    }

    Write-Host "Phase state validation passed for $Project" -ForegroundColor Green
    exit 0
}

if (!$Init -and [string]::IsNullOrWhiteSpace($Phase) -and [string]::IsNullOrWhiteSpace($ProductPromise) -and [string]::IsNullOrWhiteSpace($Audience) -and [string]::IsNullOrWhiteSpace($PrimaryAction) -and [string]::IsNullOrWhiteSpace($ShowableMoment) -and [string]::IsNullOrWhiteSpace($WhatNotToBuild) -and [string]::IsNullOrWhiteSpace($NoMoreFeaturesLock) -and [string]::IsNullOrWhiteSpace($ComplexityBudget) -and [string]::IsNullOrWhiteSpace($BeforeAfterJudgment) -and [string]::IsNullOrWhiteSpace($HumanTasteNote) -and [string]::IsNullOrWhiteSpace($PhaseModelPolicy) -and [string]::IsNullOrWhiteSpace($ParkingState) -and [string]::IsNullOrWhiteSpace($EvidenceRequired) -and [string]::IsNullOrWhiteSpace($DoneSignal) -and [string]::IsNullOrWhiteSpace($NextPhaseCriteria) -and [string]::IsNullOrWhiteSpace($RepairTrigger) -and [string]::IsNullOrWhiteSpace($RepairReturnPhase)) {
    Write-Host "Nothing to update. Pass -Init, -Phase, or a phase data field." -ForegroundColor Yellow
    exit 0
}

$existing = if (Test-Path -LiteralPath $phasePath) { Get-Content -LiteralPath $phasePath -Raw } else { "" }

$currentPhase = if (![string]::IsNullOrWhiteSpace($Phase)) { $Phase } else { Get-ExistingValue -Text $existing -Name "Current Phase" -Default "brief" }
$currentPromise = if (![string]::IsNullOrWhiteSpace($ProductPromise)) { $ProductPromise } else { Get-ExistingValue -Text $existing -Name "Product Promise" -Default "TODO: This demo helps [person] do [specific job] without [current pain]." }
$currentAudience = if (![string]::IsNullOrWhiteSpace($Audience)) { $Audience } else { Get-ExistingValue -Text $existing -Name "Audience" -Default "TODO: the specific buyer or user this ship is serving." }
$currentPrimaryAction = if (![string]::IsNullOrWhiteSpace($PrimaryAction)) { $PrimaryAction } else { Get-ExistingValue -Text $existing -Name "Primary Action" -Default "TODO: the one thing the visitor should do first." }
$currentShowableMoment = if (![string]::IsNullOrWhiteSpace($ShowableMoment)) { $ShowableMoment } else { Get-ExistingValue -Text $existing -Name "Showable Moment" -Default "TODO: the moment that makes the buyer say 'I get it.'" }
$currentWhatNotToBuild = if (![string]::IsNullOrWhiteSpace($WhatNotToBuild)) { $WhatNotToBuild } else { Get-ExistingValue -Text $existing -Name "What Not To Build" -Default "Do not add broad platform framing, fake enterprise dashboards, pricing, backend, auth, payments, analytics, or extra feature tours unless explicitly requested." }
$currentNoMoreFeaturesLock = if (![string]::IsNullOrWhiteSpace($NoMoreFeaturesLock)) { $NoMoreFeaturesLock } else { Get-ExistingValue -Text $existing -Name "No More Features Lock" -Default $(if ($currentPhase -in @("simplicity", "polish", "proof", "parked", "repair", "analysis-proof")) { "true" } else { "false" }) }
$currentComplexityBudget = if (![string]::IsNullOrWhiteSpace($ComplexityBudget)) { $ComplexityBudget } else { Get-ExistingValue -Text $existing -Name "Complexity Budget" -Default "Above the fold: one primary action, no more than three secondary choices, one short intro sentence, and no competing feature cards." }
$currentBeforeAfterJudgment = if (![string]::IsNullOrWhiteSpace($BeforeAfterJudgment)) { $BeforeAfterJudgment } else { Get-ExistingValue -Text $existing -Name "Before/After Judgment" -Default "Each task must make the product clearer, simpler, more useful, or more beautiful than the previous screenshot/state." }
$currentTasteNote = if (![string]::IsNullOrWhiteSpace($HumanTasteNote)) { $HumanTasteNote } else { Get-ExistingValue -Text $existing -Name "Human Taste Note" -Default "none" }
$currentPhaseModelPolicy = if (![string]::IsNullOrWhiteSpace($PhaseModelPolicy)) { $PhaseModelPolicy } else { Get-ExistingValue -Text $existing -Name "Phase Model Policy" -Default $(if ($currentPhase -in @("shape", "simplicity", "polish", "repair", "problem-brief", "data-contract", "formula-spec", "calibration")) { "judgment-heavy" } elseif ($currentPhase -in @("foundation", "fixture-tests", "engine-build")) { "budget" } else { "balanced" }) }
$currentParkingState = if (![string]::IsNullOrWhiteSpace($ParkingState)) { $ParkingState } elseif ($currentPhase -eq "parked") { "PARKED_REVIEW_READY" } else { Get-ExistingValue -Text $existing -Name "Parking State" -Default "ACTIVE" }
$currentEvidenceRequired = if (![string]::IsNullOrWhiteSpace($EvidenceRequired)) { $EvidenceRequired } else { Get-ExistingValue -Text $existing -Name "Evidence Required" -Default "Visual check or screenshot evidence, acceptance command output, and a short before/after note." }
$currentDoneSignal = if (![string]::IsNullOrWhiteSpace($DoneSignal)) { $DoneSignal } else { Get-ExistingValue -Text $existing -Name "Done Signal" -Default "A human can understand the product in 30 seconds and the primary action works without explanation." }
$currentNextPhaseCriteria = if (![string]::IsNullOrWhiteSpace($NextPhaseCriteria)) { $NextPhaseCriteria } else { Get-ExistingValue -Text $existing -Name "Next Phase Criteria" -Default "Advance only when current phase evidence passes and no higher-priority clarity/usability blocker remains." }
$currentRepairTrigger = if (![string]::IsNullOrWhiteSpace($RepairTrigger)) { $RepairTrigger } elseif ($currentPhase -eq "repair") { Get-ExistingValue -Text $existing -Name "Repair Trigger" -Default "TODO: name the RED gate, failed check, quarantine, stale lock, or visual blocker that interrupted the normal phase." } else { Get-ExistingValue -Text $existing -Name "Repair Trigger" -Default "none" }
$currentRepairReturnPhase = if (![string]::IsNullOrWhiteSpace($RepairReturnPhase)) { $RepairReturnPhase } elseif ($currentPhase -eq "repair") { Get-ExistingValue -Text $existing -Name "Repair Return Phase" -Default "TODO: prior non-repair phase." } else { Get-ExistingValue -Text $existing -Name "Repair Return Phase" -Default "none" }
$updatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$content = @"
# Phase State

Current Phase: $currentPhase
Audience: $currentAudience
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
Evidence Required: $currentEvidenceRequired
Done Signal: $currentDoneSignal
Next Phase Criteria: $currentNextPhaseCriteria
Repair Trigger: $currentRepairTrigger
Repair Return Phase: $currentRepairReturnPhase
Updated At: $updatedAt

## Phase Order

Website loop: brief -> foundation -> shape -> simplicity -> polish -> proof -> parked

Website stage contract source: docs/codex/WEBSITE_STAGE_RULES.md when present. Use `fleet-website-stages.ps1 -Project $Project -WriteReference` from the fleet control room to write or refresh it.

Analytical software loop: problem-brief -> data-contract -> formula-spec -> fixture-tests -> engine-build -> calibration -> dashboard -> scenario-tools -> analysis-proof -> parked

repair is an interrupt lane, not a normal destination. Any phase can enter repair when RED review gates, build/runtime failures, quarantine, stale/idle lock problems, or visual blockers stop safe progress. After the repair passes, return to the previous product phase.

## Phase Locks

- Brief must define audience, promise, primary action, and what not to build.
- Foundation may add missing structure and core behavior.
- Shape may reorganize pages and flows, but should avoid feature sprawl.
- Simplicity should remove, combine, shorten, hide, or demote before adding.
- Polish should refine visual/copy details without changing the core flow.
- Proof should fix blockers only.
- Parked means review-ready; do not generate new work unless a human moves the phase.
- Repair must address only the named blocker, keep No More Features Lock true, and avoid fresh feature work.
- Problem Brief defines the decision, user, outputs, and what not to predict.
- Data Contract defines CSV schemas, database tables, IDs, missing-data behavior, and snapshot/version rules.
- Formula Spec writes deterministic formulas, weights, defaults, confidence rules, and examples before coding.
- Fixture Tests creates tiny known datasets with obvious expected answers before full app work.
- Engine Build implements loaders, validators, scoring, ranking, probabilities, and exports.
- Calibration compares model outputs against history, known sanity checks, and confidence behavior.
- Dashboard builds table-first review UI only after formulas and fixtures are trustworthy.
- Scenario Tools adds what-if controls, weight changes, strategy modes, and comparison workflows.
- Analysis Proof fixes blockers only: tests, import validation, reports, deterministic outputs, and no live-data dependency.

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
