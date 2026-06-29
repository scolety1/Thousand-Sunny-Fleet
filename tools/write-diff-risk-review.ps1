[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$OutFile,
    [string]$FixtureCase
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-coder-upgrade.ps1")

$result = Write-CoderUpgradeDiffRiskReview -FleetRoot $FleetRoot -OutFile $OutFile -FixtureCase $FixtureCase
Write-Host "Wrote diff risk review: $($result.path)"
Write-Host "Risk level: $($result.riskLevel)"
Write-Host "Human approval needed: $($result.humanApprovalNeeded)"
