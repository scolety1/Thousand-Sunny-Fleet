[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-coder-upgrade.ps1")

$written = Write-CoderUpgradeBugJournal -FleetRoot $FleetRoot -OutFile $OutFile
Write-Host "Wrote coding lessons journal: $written"
