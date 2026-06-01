[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$InputPath = "",
    [string]$ReportPath = "",
    [string]$JsonReportPath = ""
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-control-room.ps1")

function Resolve-Stage12Path {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

$started = Get-Date
$runId = "stage12-control-room-" + $started.ToString("yyyyMMdd-HHmmss-fff") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = "out\stage12-control-room\$runId\control-room.md" }
if ([string]::IsNullOrWhiteSpace($JsonReportPath)) { $JsonReportPath = "out\stage12-control-room\$runId\control-room.json" }
$reportFull = Resolve-Stage12Path $ReportPath
$jsonFull = Resolve-Stage12Path $JsonReportPath

if ([string]::IsNullOrWhiteSpace($InputPath)) {
    throw "InputPath is required for Stage 12 control-room generation. Use a sanitized status fixture or exported fleet status JSON."
}

$inputFull = Resolve-Stage12Path $InputPath
if (!(Test-Path -LiteralPath $inputFull)) { throw "Input file not found: $inputFull" }
$input = Get-Content -LiteralPath $inputFull -Raw | ConvertFrom-Json
$ships = @($input.ships | ForEach-Object { $_ })
if ($ships.Count -eq 0) { throw "Input file contains no ships." }

$snapshot = New-FleetControlRoomSnapshot -Ships $ships -Budget $input.budget -GeneratedAt $started

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonFull) | Out-Null
$snapshot | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $jsonFull -Encoding UTF8

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFull) | Out-Null
New-FleetControlRoomMarkdown -Snapshot $snapshot | Set-Content -LiteralPath $reportFull -Encoding UTF8

Write-Host "STAGE12_STATUS: GREEN"
Write-Host "STAGE12_REPORT: $reportFull"
Write-Host "STAGE12_JSON: $jsonFull"
exit 0
