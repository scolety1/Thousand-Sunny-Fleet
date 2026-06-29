[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$OutDirectory,
    [string]$InboxRoot,
    [string[]]$ProjectName,
    [switch]$IncludeArchived
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-coder-upgrade.ps1")

$written = @(Write-CoderUpgradeContextPacks -FleetRoot $FleetRoot -OutDirectory $OutDirectory -InboxRoot $InboxRoot -ProjectName $ProjectName -IncludeArchived:$IncludeArchived)
Write-Host "Wrote context packs: $($written.Count)"
foreach ($path in $written) {
    Write-Host $path
}
