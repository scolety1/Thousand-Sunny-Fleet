[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [switch]$Write,

    [switch]$Validate,

    [switch]$Status
)

$ErrorActionPreference = "Stop"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-ConfigPropertyValue {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Default = ""
    )

    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Get-PhaseValue {
    param(
        [string]$Text,
        [string]$Name,
        [string]$Default = ""
    )

    $match = [regex]::Match($Text, "(?im)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return $Default
}

function Get-SectionText {
    param(
        [string]$Text,
        [string]$Heading
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $pattern = "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n(?<body>.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups["body"].Value.Trim() }
    return ""
}

function Resolve-Ship {
    if ([string]::IsNullOrWhiteSpace($Project)) {
        Stop-WithMessage "Pass -Project."
    }
    if (!(Test-Path -LiteralPath $ConfigPath)) {
        Stop-WithMessage "Config not found: $ConfigPath"
    }

    $projects = @(Get-Content $ConfigPath -Raw | ConvertFrom-Json | ForEach-Object { $_ })
    $ship = @($projects | Where-Object { [string]$_.name -ceq $Project }) | Select-Object -First 1
    if ($null -eq $ship) { Stop-WithMessage "Project not found: $Project" }

    $repo = [string](Get-ConfigPropertyValue -Object $ship -Name "repo")
    if (!(Test-Path -LiteralPath $repo)) { Stop-WithMessage "Repo not found: $repo" }
    return [pscustomobject]@{ name = [string]$ship.name; repo = (Resolve-Path -LiteralPath $repo).Path; config = $ship }
}

function Get-ShipText {
    param(
        [string]$Repo,
        [string]$RelativePath,
        [string]$Fallback = ""
    )

    $path = Join-Path $Repo $RelativePath
    if (Test-Path -LiteralPath $path) { return Get-Content -LiteralPath $path -Raw }
    return $Fallback
}

function New-CompletionContract {
    param([object]$Ship)

    $repo = $Ship.repo
    $phaseText = Get-ShipText -Repo $repo -RelativePath "docs\codex\PHASE_STATE.md"
    $usefulnessText = Get-ShipText -Repo $repo -RelativePath "docs\codex\PRODUCT_USEFULNESS.md"
    $evaluatorsText = Get-ShipText -Repo $repo -RelativePath "docs\codex\EVALUATORS.md"
    $siteMapText = Get-ShipText -Repo $repo -RelativePath "docs\codex\SITE_MAP.md"
    $stageText = Get-ShipText -Repo $repo -RelativePath "docs\codex\WEBSITE_STAGE_RULES.md"
    $visualRoutes = @(Get-ConfigPropertyValue -Object $Ship.config -Name "visualPaths" -Default @())
    $buildCommand = [string](Get-ConfigPropertyValue -Object $Ship.config -Name "buildCommand" -Default "")
    if ([string]::IsNullOrWhiteSpace($buildCommand)) { $buildCommand = "TODO: documented local build/static check" }

    $phase = Get-PhaseValue -Text $phaseText -Name "Current Phase" -Default "brief"
    $audience = Get-PhaseValue -Text $phaseText -Name "Audience" -Default "TODO: specific audience"
    $promise = Get-PhaseValue -Text $phaseText -Name "Product Promise" -Default "TODO: concrete promise"
    $primaryAction = Get-PhaseValue -Text $phaseText -Name "Primary Action" -Default "TODO: primary action"
    $showableMoment = Get-PhaseValue -Text $phaseText -Name "Showable Moment" -Default "TODO: showable moment"
    $whatNot = Get-PhaseValue -Text $phaseText -Name "What Not To Build" -Default "No broad platform expansion."
    $complexityBudget = Get-PhaseValue -Text $phaseText -Name "Complexity Budget" -Default "One clear primary action and no overloaded first screen."
    $doneSignal = Get-PhaseValue -Text $phaseText -Name "Done Signal" -Default "A user understands the product and the primary action works locally."
    $nextPhaseCriteria = Get-PhaseValue -Text $phaseText -Name "Next Phase Criteria" -Default "Advance only when evidence passes."
    $currentUseful = Get-SectionText -Text $usefulnessText -Heading "Current Useful State"
    $mainFriction = Get-SectionText -Text $usefulnessText -Heading "Main Friction"
    $nextUseful = Get-SectionText -Text $usefulnessText -Heading "Next Useful Improvement"

    if ([string]::IsNullOrWhiteSpace($currentUseful)) { $currentUseful = $doneSignal }
    if ([string]::IsNullOrWhiteSpace($mainFriction)) { $mainFriction = "Use the latest reviews, visual checks, and user feedback to name one concrete blocker." }
    if ([string]::IsNullOrWhiteSpace($nextUseful)) { $nextUseful = $nextPhaseCriteria }

    $routesLine = if ($visualRoutes.Count -gt 0) { ($visualRoutes -join ", ") } else { "TODO: configured preview route(s)" }
    $hasStageRules = if ([string]::IsNullOrWhiteSpace($stageText)) { "missing" } else { "present" }
    $hasSiteMap = if ([string]::IsNullOrWhiteSpace($siteMapText)) { "missing" } else { "present" }
    $hasEvaluators = if ([string]::IsNullOrWhiteSpace($evaluatorsText)) { "missing" } else { "present" }

    return @"
# Done Contract

This is the ship-specific completion contract. It tells the fleet what "done enough" means before generating more work, advancing phase, or parking the ship.

## Current Stage

Stage: $phase

Stage rules: $hasStageRules

Site map: $hasSiteMap

Evaluators: $hasEvaluators

## Product Target

Audience: $audience

Product promise: $promise

Primary action: $primaryAction

Showable moment: $showableMoment

Current useful state: $currentUseful

Main friction: $mainFriction

Next useful improvement: $nextUseful

## Done Enough

The ship can stop or advance when all of these are true:

- The primary action is visible or reachable in one obvious step.
- The showable moment is visible or reachable from the first screen.
- The current stage exit criteria in WEBSITE_STAGE_RULES.md are satisfied.
- The Done Signal in PHASE_STATE.md is true in the local preview.
- The next useful improvement in PRODUCT_USEFULNESS.md is either completed or no longer needed.
- No Simon, Robin, Joey, visual, runtime, or checkpoint report has a RED blocker.
- No unchecked product-shaped task remains that is required for the current stage.

## Must Not Do

- $whatNot
- Do not add new features when No More Features Lock is true.
- Do not add sections, pages, claims, or controls just to keep the loop busy.
- Do not move to polish or proof if shape/simplicity blockers are still obvious.
- Do not keep running once proof passes and the ship is review-ready.

## Evidence Required

- Build/check command: $buildCommand
- Preview route(s): $routesLine
- Latest visual evidence covers the first screen and the highest-impact route.
- Robin copy review is not RED for visible wording.
- Simon design review is not RED for layout, hierarchy, or first impression.
- Joey security review is GREEN or not applicable for the touched scope.

## Advance Or Park Rule

- If Done Enough is true and current stage is not proof, advance to the next stage instead of inventing more same-stage tasks.
- If Done Enough is true in proof, set phase to parked and Parking State to PARKED_REVIEW_READY.
- If Done Enough is false, generate only tasks that close a specific failed bullet above.
"@
}

function Test-CompletionContract {
    param([string]$Repo)

    $issues = New-Object System.Collections.Generic.List[string]
    $path = Join-Path $Repo "docs\codex\DONE_CONTRACT.md"
    if (!(Test-Path -LiteralPath $path)) {
        $issues.Add("DONE_CONTRACT.md missing; run fleet-completion-contract.ps1 -Project $Project -Write") | Out-Null
        return @($issues)
    }

    $text = Get-Content -LiteralPath $path -Raw
    foreach ($heading in @("Current Stage", "Product Target", "Done Enough", "Must Not Do", "Evidence Required", "Advance Or Park Rule")) {
        if ($text -notmatch "(?m)^## $([regex]::Escape($heading))\s*$") {
            $issues.Add("DONE_CONTRACT.md missing '$heading' section") | Out-Null
        }
    }
    foreach ($phrase in @("Audience:", "Product promise:", "Primary action:", "Showable moment:", "Build/check command:", "Preview route(s):")) {
        if ($text -notmatch [regex]::Escape($phrase)) {
            $issues.Add("DONE_CONTRACT.md missing '$phrase'") | Out-Null
        }
    }
    if ($text -match "TODO:") {
        $issues.Add("DONE_CONTRACT.md still contains TODO") | Out-Null
    }
    return @($issues)
}

$ship = Resolve-Ship
$contractPath = Join-Path $ship.repo "docs\codex\DONE_CONTRACT.md"

if ($Write) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $contractPath) | Out-Null
    Set-Content -LiteralPath $contractPath -Value (New-CompletionContract -Ship $ship)
    Write-Host "Done contract written for $($ship.name): $contractPath" -ForegroundColor Green
}

if ($Status) {
    if (Test-Path -LiteralPath $contractPath) {
        Get-Content -LiteralPath $contractPath
    } else {
        Write-Host "No done contract found for $($ship.name): $contractPath" -ForegroundColor Yellow
    }
}

if ($Validate) {
    $issues = @(Test-CompletionContract -Repo $ship.repo)
    if ($issues.Count -gt 0) {
        Write-Host "Done contract validation failed for $($ship.name)" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
        exit 1
    }
    Write-Host "Done contract validation passed for $($ship.name)" -ForegroundColor Green
}
