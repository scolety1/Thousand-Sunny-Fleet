[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$OutDirectory,
    [string[]]$ProjectName,
    [switch]$IncludeArchived
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-coder-upgrade.ps1")

$written = @(Write-CoderUpgradeRepoXrays -FleetRoot $FleetRoot -OutDirectory $OutDirectory -ProjectName $ProjectName -IncludeArchived:$IncludeArchived)
Write-Host "Wrote repo x-rays: $($written.Count)"
foreach ($path in $written) {
    Write-Host $path
}
