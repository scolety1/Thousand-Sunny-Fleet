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

. (Join-Path $PSScriptRoot "codex-fleet-daily-driver.ps1")

$written = @(Write-DailyDriverNextSessionCards -FleetRoot $FleetRoot -OutDirectory $OutDirectory -ProjectName $ProjectName -IncludeArchived:$IncludeArchived)
Write-Host "Wrote next-session cards: $($written.Count)"
foreach ($path in $written) {
    Write-Host $path
}
