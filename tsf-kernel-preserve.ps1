[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [string]$MissionPath,

    [Parameter(Mandatory = $true)]
    [string]$PreflightResultPath,

    [string]$WorkerResultPath = "",

    [string]$VerifierResultPath = "",

    [string]$OutputDirectory = "",

    [string]$ExactNextAction = "Review preservation packet and continue only through a new TSF mission packet.",

    [string]$OutFile = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "tools\codex-fleet-enforcement-kernel.ps1")

$result = Write-TsfKernelPreservationPacket -MissionPath $MissionPath -PreflightResultPath $PreflightResultPath -WorkerResultPath $WorkerResultPath -VerifierResultPath $VerifierResultPath -OutputDirectory $OutputDirectory -ExactNextAction $ExactNextAction
if (![string]::IsNullOrWhiteSpace($OutFile)) {
    Write-TsfKernelJson -Value $result -Path $OutFile
} else {
    $result | ConvertTo-Json -Depth 30
}

exit 0
