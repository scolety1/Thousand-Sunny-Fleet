[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$MissionPath,

    [Parameter(Mandatory = $true)]
    [string]$WorkerResultPath,

    [string]$OutFile = "",

    [string]$StateRoot = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "tools\codex-fleet-enforcement-kernel.ps1")

$result = Invoke-TsfKernelPostRunVerify -MissionPath $MissionPath -WorkerResultPath $WorkerResultPath -OutFile $OutFile -StateRoot $StateRoot
if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $result | ConvertTo-Json -Depth 30
}

if ([bool]$result.verified) {
    exit 0
}

exit 1
