[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)][string]$ResultPath,
    [Parameter(Mandatory = $true)][string]$MissionRegistryPath,
    [Parameter(Mandatory = $true)][string]$ActivePolicyManifestPath,
    [Parameter(Mandatory = $true)][string]$ApprovalLedgerPath,
    [Parameter(Mandatory = $true)][string]$PreservationPacketPath,
    [Parameter(Mandatory = $true)][string]$QueueMissionPath,
    [Parameter(Mandatory = $true)][string]$QueueRootPath,
    [switch]$UnsupportedDevelopmentMode,
    [string]$OutFile = "",
    [datetimeoffset]$CurrentTime = [datetimeoffset]::UtcNow
)
$ErrorActionPreference = "Stop"
$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Import-Module (Join-Path $fleetRoot "tools\TsfDurableContract.psm1") -Force
$result = Get-TsfAdmissionDecision -ResultPath $ResultPath -MissionRegistryPath $MissionRegistryPath -ActivePolicyManifestPath $ActivePolicyManifestPath -ApprovalLedgerPath $ApprovalLedgerPath -PreservationPacketPath $PreservationPacketPath -QueueMissionPath $QueueMissionPath -QueueRootPath $QueueRootPath -CurrentTime $CurrentTime -UnsupportedDevelopmentMode:$UnsupportedDevelopmentMode
if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $result | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}
$result
