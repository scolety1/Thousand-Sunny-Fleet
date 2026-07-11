[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$MissionPath,

    [string]$ApprovalLedgerPath = "",

    [string]$OutFile = "",

    [string]$StateRoot = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "tools\codex-fleet-enforcement-kernel.ps1")

$result = Invoke-TsfKernelPreflight -MissionPath $MissionPath -ApprovalLedgerPath $ApprovalLedgerPath -OutFile $OutFile -StateRoot $StateRoot
if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $result | ConvertTo-Json -Depth 30
}

if ([bool]$result.preflight_approved) {
    exit 0
}

exit 1
