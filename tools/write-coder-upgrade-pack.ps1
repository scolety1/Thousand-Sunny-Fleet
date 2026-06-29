[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$InboxRoot,
    [string[]]$ProjectName
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-coder-upgrade.ps1")

$fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path

$diff = Write-CoderUpgradeDiffRiskReview -FleetRoot $fleetRootFull
$xrays = @(Write-CoderUpgradeRepoXrays -FleetRoot $fleetRootFull -ProjectName $ProjectName)
$contextPacks = @(Write-CoderUpgradeContextPacks -FleetRoot $fleetRootFull -InboxRoot $InboxRoot -ProjectName $ProjectName)
$splits = @(Write-CoderUpgradeWorkOrderSplits -FleetRoot $fleetRootFull -ProjectName $ProjectName)
$playbooks = @(Write-CoderUpgradeStuckPlaybooks -FleetRoot $fleetRootFull -ProjectName $ProjectName)
$lessons = Write-CoderUpgradeBugJournal -FleetRoot $fleetRootFull

Write-Host "TSF Coder Upgrade Pack V1 generated."
Write-Host "Diff risk: $($diff.riskLevel) at $($diff.path)"
Write-Host "Repo X-Rays: $($xrays.Count)"
Write-Host "Context packs: $($contextPacks.Count)"
Write-Host "Work-order splits: $($splits.Count)"
Write-Host "Stuck playbooks: $($playbooks.Count)"
Write-Host "Bug journal: $lessons"
