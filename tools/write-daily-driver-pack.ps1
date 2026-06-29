[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$InboxRoot
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-daily-driver.ps1")

$fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path
$passportDir = Join-Path $fleetRootFull "fleet\status\project-passports"
$nextSessionDir = Join-Path $fleetRootFull "fleet\status\next-session"
$workOrderDir = Join-Path $fleetRootFull "fleet\status\work-orders"

$passports = @(Write-DailyDriverProjectPassports -FleetRoot $fleetRootFull -OutDirectory $passportDir)
$cards = @(Write-DailyDriverNextSessionCards -FleetRoot $fleetRootFull -OutDirectory $nextSessionDir)
$workOrders = @(Write-DailyDriverWorkOrderInboxes -FleetRoot $fleetRootFull -OutDirectory $workOrderDir -InboxRoot $InboxRoot)
$triage = Write-DailyDriverTriageScore -FleetRoot $fleetRootFull

Write-Host "TSF Daily Driver Pack V1 generated."
Write-Host "Project passports: $($passports.Count)"
Write-Host "Next-session cards: $($cards.Count)"
Write-Host "Work-order inbox summaries: $($workOrders.Count)"
Write-Host "Triage score: $($triage.markdown)"
Write-Host "Top recommendation: $($triage.topRecommendation)"
