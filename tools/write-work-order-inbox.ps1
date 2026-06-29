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

. (Join-Path $PSScriptRoot "codex-fleet-daily-driver.ps1")

$written = @(Write-DailyDriverWorkOrderInboxes -FleetRoot $FleetRoot -OutDirectory $OutDirectory -InboxRoot $InboxRoot -ProjectName $ProjectName -IncludeArchived:$IncludeArchived)
Write-Host "Wrote work-order inbox summaries: $($written.Count)"
foreach ($path in $written) {
    Write-Host $path
}
