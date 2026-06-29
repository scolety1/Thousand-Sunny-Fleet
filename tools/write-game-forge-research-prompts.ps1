[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$IntakePath,
    [string]$OutDirectory
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

. (Join-Path $PSScriptRoot "codex-fleet-game-forge.ps1")

$path = Write-GameForgeResearchPrompts -FleetRoot $FleetRoot -IntakePath $IntakePath -OutDirectory $OutDirectory
Write-Host "Wrote Game Forge research prompts: $path"
