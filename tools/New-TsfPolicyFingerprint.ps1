[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ManifestPath = "",
    [string]$RepositoryRoot = "",
    [string]$GitCommit = "",
    [string]$OutFile = ""
)
$ErrorActionPreference = "Stop"
$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { $RepositoryRoot = $fleetRoot }
if ([string]::IsNullOrWhiteSpace($ManifestPath)) { $ManifestPath = Join-Path $fleetRoot "fleet\control\policy-manifest.v1.json" }
Import-Module (Join-Path $fleetRoot "tools\TsfDurableContract.psm1") -Force
$result = Get-TsfPolicyFingerprint -ManifestPath $ManifestPath -RepositoryRoot $RepositoryRoot -GitCommit $GitCommit
if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $parent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($parent)) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    $result | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}
$result
