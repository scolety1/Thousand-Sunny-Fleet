[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$OutDirectory,
    [string]$SpecPath,
    [string[]]$ProjectName,
    [switch]$IncludeArchived
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-coder-upgrade.ps1")

$written = @(Write-CoderUpgradeWorkOrderSplits -FleetRoot $FleetRoot -OutDirectory $OutDirectory -SpecPath $SpecPath -ProjectName $ProjectName -IncludeArchived:$IncludeArchived)
Write-Host "Wrote work-order splits: $($written.Count)"
foreach ($path in $written) {
    Write-Host $path
}
