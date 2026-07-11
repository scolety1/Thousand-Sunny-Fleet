[CmdletBinding(PositionalBinding = $false)]
param([Parameter(Mandatory = $true)][string]$ResultPath, [string]$OutFile = "")
$ErrorActionPreference = "Stop"
$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
Import-Module (Join-Path $fleetRoot "tools\TsfDurableContract.psm1") -Force
$returned = Get-Content -LiteralPath $ResultPath -Raw | ConvertFrom-Json
$result = Test-TsfResultEnvelope -Result $returned
if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $result | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}
$result
if (!$result.valid) { exit 1 }
