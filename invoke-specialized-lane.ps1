[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$InputPath = "",
    [string]$Text = "",
    [string]$ShipName = "",
    [string[]]$TouchedPath = @(),
    [string]$RequestedLane = "",
    [string]$ReportPath = "",
    [string]$JsonReportPath = ""
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-lanes.ps1")

function Resolve-Stage11Path {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

$started = Get-Date
$runId = "stage11-lanes-" + $started.ToString("yyyyMMdd-HHmmss-fff") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = "out\stage11-lanes\$runId\lane-report.md" }
if ([string]::IsNullOrWhiteSpace($JsonReportPath)) { $JsonReportPath = "out\stage11-lanes\$runId\lane-result.json" }
$reportFull = Resolve-Stage11Path $ReportPath
$jsonFull = Resolve-Stage11Path $JsonReportPath

$items = @()
if (![string]::IsNullOrWhiteSpace($InputPath)) {
    $inputFull = Resolve-Stage11Path $InputPath
    if (!(Test-Path -LiteralPath $inputFull)) { throw "Input file not found: $inputFull" }
    $parsed = Get-Content -LiteralPath $inputFull -Raw | ConvertFrom-Json
    $items = @($parsed | ForEach-Object { $_ })
} else {
    $items = @([pscustomobject]@{
        name = if ($ShipName) { $ShipName } else { "Task" }
        text = $Text
        shipName = $ShipName
        touchedPaths = @($TouchedPath)
        requestedLane = $RequestedLane
    })
}

$results = @()
foreach ($item in $items) {
    $resolution = Resolve-FleetSpecializedLane -Text ([string]$item.text) -ShipName ([string]$item.shipName) -TouchedPaths @($item.touchedPaths) -RequestedLane ([string]$item.requestedLane)
    $results += [pscustomobject]@{
        name = if ($item.name) { [string]$item.name } elseif ($item.shipName) { [string]$item.shipName } else { "Task" }
        text = [string]$item.text
        resolution = $resolution
    }
}

$ended = Get-Date
$result = [pscustomobject]@{
    schemaVersion = 1
    runId = $runId
    stage = "Golden Gameplan Stage 11"
    status = "GREEN"
    startedAt = $started.ToUniversalTime().ToString("o")
    endedAt = $ended.ToUniversalTime().ToString("o")
    laneCount = @($results).Count
    results = @($results)
    reportPath = $reportFull
    jsonReportPath = $jsonFull
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonFull) | Out-Null
$result | ConvertTo-Json -Depth 14 | Set-Content -Path $jsonFull -Encoding UTF8
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFull) | Out-Null
New-FleetLaneMarkdownReport -Results $results | Set-Content -Path $reportFull -Encoding UTF8

Write-Host "STAGE11_STATUS: GREEN"
Write-Host "STAGE11_REPORT: $reportFull"
Write-Host "STAGE11_JSON: $jsonFull"
exit 0
