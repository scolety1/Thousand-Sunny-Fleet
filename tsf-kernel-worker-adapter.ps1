[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$MissionPath,

    [Parameter(Mandatory = $true)]
    [string]$PreflightResultPath,

    [string]$OutFile = "",

    [string]$StateRoot = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "tools\codex-fleet-enforcement-kernel.ps1")

$result = New-TsfKernelWorkerInstruction -MissionPath $MissionPath -PreflightResultPath $PreflightResultPath -OutFile $OutFile -StateRoot $StateRoot
if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $result | ConvertTo-Json -Depth 30
}

if ([string]$result.adapter_status -eq "REFUSED_PREFLIGHT_FAILED") {
    exit 1
}

exit 0
