[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$IntakePath
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-game-forge.ps1")

$result = Write-GameForgePack -FleetRoot $FleetRoot -IntakePath $IntakePath
Write-Host "TSF Game Forge V1 generated."
Write-Host "Blueprint: $($result.blueprint)"
Write-Host "Systems map: $($result.systemsMap)"
Write-Host "Prototype slices: $($result.prototypeSlices)"
Write-Host "Research prompts: $($result.researchPrompts)"
Write-Host "Risk review: $($result.riskReview)"
Write-Host "Work orders: $($result.workOrders)"
