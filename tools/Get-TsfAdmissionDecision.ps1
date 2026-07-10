[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)][string]$ResultPath,
    [Parameter(Mandatory = $true)][string]$MissionRegistryPath,
    [string]$ActivePolicyFingerprint = "",
    [string]$ReceiptDirectory = "",
    [string]$OutFile = "",
    [datetimeoffset]$CurrentTime = [datetimeoffset]::UtcNow
)
$ErrorActionPreference = "Stop"
$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Import-Module (Join-Path $fleetRoot "tools\TsfDurableContract.psm1") -Force
$result = Get-TsfAdmissionDecision -ResultPath $ResultPath -MissionRegistryPath $MissionRegistryPath -ActivePolicyFingerprint $ActivePolicyFingerprint -ReceiptDirectory $ReceiptDirectory -CurrentTime $CurrentTime
if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $result | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}
$result
