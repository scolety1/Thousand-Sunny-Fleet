[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$OutFile,
    [string]$JsonOutFile
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-daily-driver.ps1")

$result = Write-DailyDriverTriageScore -FleetRoot $FleetRoot -OutFile $OutFile -JsonOutFile $JsonOutFile
Write-Host "Wrote return triage score:"
Write-Host $result.markdown
Write-Host $result.json
Write-Host "Top recommendation: $($result.topRecommendation)"
