[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$OutDirectory,
    [string[]]$ProjectName
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-daily-driver.ps1")

$written = @(Write-DailyDriverProjectPassports -FleetRoot $FleetRoot -OutDirectory $OutDirectory -ProjectName $ProjectName)
Write-Host "Wrote project passports: $($written.Count)"
foreach ($path in $written) {
    Write-Host $path
}
