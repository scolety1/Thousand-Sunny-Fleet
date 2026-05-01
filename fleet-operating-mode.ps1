[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Project = "",
    [string]$FleetGroup = "",
    [string]$ConfigPath = ".\projects.json",
    [switch]$All,
    [switch]$Write,
    [string]$OutPath = "out\operating-mode.md"
)

$ErrorActionPreference = "Continue"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-Projects {
    param([string]$Path)
    $resolved = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (!$resolved) { Stop-WithMessage "Config not found: $Path" }
    $loaded = Get-Content -LiteralPath $resolved.Path -Raw | ConvertFrom-Json
    if ($loaded -is [array]) { return @($loaded) }
    if ($null -ne $loaded -and $loaded.PSObject.Properties.Name -contains "value") { return @($loaded.value) }
    if ($null -ne $loaded) { return @($loaded) }
    return @()
}

function Get-ConfigValue {
    param([object]$Object, [string]$Name, [object]$Default = "")
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Resolve-OperatingMode {
    param([object]$Ship)
    $explicit = [string](Get-ConfigValue -Object $Ship -Name "operatingMode" -Default "")
    if (![string]::IsNullOrWhiteSpace($explicit)) { return $explicit }
    $name = [string](Get-ConfigValue -Object $Ship -Name "name" -Default "")
    $group = [string](Get-ConfigValue -Object $Ship -Name "fleetGroup" -Default "")
    $demoName = [string](Get-ConfigValue -Object $Ship -Name "demoName" -Default "")
    $projectType = [string](Get-ConfigValue -Object $Ship -Name "projectType" -Default "")
    if ($name -eq "NinersWarRoom" -or $demoName -match "(?i)(formula|model|score|market|keeper|analytics)") { return "formula-lab" }
    if ($group -match "(?i)Cellar|Restaurant" -or $name -in @("RestaurantDemo", "ShiftPlate") -or $demoName -match "(?i)(wine|beverage|restaurant|manager|event|order|training|kitchen|menu)") { return "hospitality-studio" }
    if ($projectType -in @("sandbox-prototype", "marketing-site") -or $name -match "(?i)(Fixture|Demo|Pets)") { return "demo-forge" }
    return "software-engineering"
}

function Get-ModeProfile {
    param([string]$Mode)
    switch ($Mode) {
        "hospitality-studio" { return [ordered]@{ Label = "Hospitality Studio"; Lead = "Simon and Robin"; Done = "Feels like a real restaurant or restaurant tool: atmospheric, restrained, useful in 30 seconds, and not feature-dumped."; Planning = "Start with reference-quality composition, surface type, first-screen contract, progressive disclosure, and exact user path before coding."; FirstScreen = "Brand/place feeling, one clear promise, one primary action, and one beautiful preview. Secondary details must be behind navigation, buttons, tabs, accordions, drawers, or detail pages."; Forbidden = "No dashboard dump, no all-in-one claims, no internal staff notes on guest pages, no generic SaaS hero, no walls of explanatory copy."; Gates = "Simon visual/taste review, Robin concrete hospitality copy review, visual screenshot check, product truth gate, information staging gate." } }
        "formula-lab" { return [ordered]@{ Label = "Formula Lab"; Lead = "Franky"; Done = "Deterministic formulas, fixture expectations, tests, provenance, confidence labels, and no fake certainty."; Planning = "Define problem, data contract, formula spec, golden fixtures, engine changes, calibration, dashboard, and proof in that order."; FirstScreen = "Tables and source-visible outputs beat persuasive cards. The first screen should show what was computed, from what inputs, and why it can be trusted."; Forbidden = "No prediction theater, no untested formulas, no vague model insight, no visual polish before math proof."; Gates = "Franky formula review, fixture tests, number provenance, runtime verification, checkpoint review." } }
        "software-engineering" { return [ordered]@{ Label = "Software Engineering"; Lead = "Chopper and Joey"; Done = "A narrow, tested, maintainable change with clear scope, local verification, and no unsafe system edits."; Planning = "Prefer architecture plan, API/data contract, implementation slice, tests, runtime verification, and release-readiness."; FirstScreen = "For apps, the working user flow comes before marketing explanation. For libraries/tools, the CLI/API path and tests come first."; Forbidden = "No package/dependency/auth/payment/deployment/config churn unless explicitly approved; no broad rewrites without a slice plan."; Gates = "Build/test checks, security review, runtime verification, launch gate, kill switch." } }
        "demo-forge" { return [ordered]@{ Label = "Demo Forge"; Lead = "Nami"; Done = "A fast, visible, screenshot-proven prototype that makes the idea understandable without pretending to be production."; Planning = "Keep the first useful moment small; build one compelling path, capture screenshots, and park before scope creep."; FirstScreen = "The demo promise and one interaction should be obvious immediately."; Forbidden = "No deep backend, no fake production claims, no endless polish loops, no hidden broken state."; Gates = "Static/build check, screenshot check, product truth, short morning-review style report." } }
        default { return [ordered]@{ Label = "Unknown"; Lead = "Nami"; Done = "Mode must be clarified before long runs."; Planning = "Choose hospitality-studio, formula-lab, software-engineering, or demo-forge."; FirstScreen = "Undefined."; Forbidden = "Do not run overnight without mode clarity."; Gates = "Launch gate should warn." } }
    }
}

function New-ModeDoc {
    param([object]$Ship)
    $name = [string](Get-ConfigValue -Object $Ship -Name "name" -Default "Ship")
    $mode = Resolve-OperatingMode -Ship $Ship
    $profile = Get-ModeProfile -Mode $mode
    return @"
# Operating Mode

Project: $name

Mode: $mode

Label: $($profile.Label)

Lead reviewer: $($profile.Lead)

## Done Standard

$($profile.Done)

## Planning Rules

$($profile.Planning)

## First Screen Contract

$($profile.FirstScreen)

## Forbidden Patterns

$($profile.Forbidden)

## Required Gates

$($profile.Gates)

## Mode Reminder

The phase system still applies. This mode tells the fleet what kind of judgment to use inside each phase. Do not replace build checks, product truth, information staging, repair, security, formula, or accessibility gates with taste alone.
"@
}

$ships = @(Get-Projects -Path $ConfigPath)
if ($All) {
    $selected = $ships
} elseif (![string]::IsNullOrWhiteSpace($FleetGroup)) {
    $selected = @($ships | Where-Object { [string](Get-ConfigValue -Object $_ -Name "fleetGroup" -Default "") -eq $FleetGroup })
} elseif (![string]::IsNullOrWhiteSpace($Project)) {
    $selected = @($ships | Where-Object { [string](Get-ConfigValue -Object $_ -Name "name" -Default "") -eq $Project })
} else {
    Stop-WithMessage "Pass -Project, -FleetGroup, or -All."
}
if ($selected.Count -eq 0) { Stop-WithMessage "No ships matched." }

$rows = [System.Collections.Generic.List[string]]::new()
$rows.Add("# Fleet Operating Mode Report") | Out-Null
$rows.Add("") | Out-Null
$rows.Add("Generated: $(Get-Date -Format o)") | Out-Null
$rows.Add("") | Out-Null
$rows.Add("| Ship | Mode | Label | Wrote |") | Out-Null
$rows.Add("| --- | --- | --- | --- |") | Out-Null

foreach ($ship in $selected) {
    $name = [string](Get-ConfigValue -Object $ship -Name "name" -Default "Ship")
    $repo = Resolve-Path -LiteralPath ([string](Get-ConfigValue -Object $ship -Name "repo" -Default "")) -ErrorAction SilentlyContinue
    $mode = Resolve-OperatingMode -Ship $ship
    $profile = Get-ModeProfile -Mode $mode
    $wrote = "no"
    if ($Write -and $repo) {
        $outFile = Join-Path $repo.Path "docs\codex\OPERATING_MODE.md"
        New-Item -ItemType Directory -Force -Path (Split-Path $outFile) | Out-Null
        Set-Content -LiteralPath $outFile -Value (New-ModeDoc -Ship $ship) -Encoding UTF8
        $wrote = "yes"
    }
    $rows.Add("| $name | $mode | $($profile.Label) | $wrote |") | Out-Null
}

$outFull = Join-Path $fleetRoot $OutPath
New-Item -ItemType Directory -Force -Path (Split-Path $outFull) | Out-Null
Set-Content -LiteralPath $outFull -Value $rows -Encoding UTF8
$rows | ForEach-Object { Write-Host $_ }
