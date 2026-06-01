[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$InputPath = "",
    [string]$ReportPath = "",
    [string]$JsonReportPath = "",
    [switch]$UseExampleFixture,
    [switch]$UseControlledUseRehearsal
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-final-readiness.ps1")

function Resolve-Stage14Path {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

$started = Get-Date
$runId = "stage14-final-readiness-" + $started.ToString("yyyyMMdd-HHmmss-fff") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = "out\stage14-final-readiness\$runId\final-readiness.md" }
if ([string]::IsNullOrWhiteSpace($JsonReportPath)) { $JsonReportPath = "out\stage14-final-readiness\$runId\final-readiness.json" }
$reportFull = Resolve-Stage14Path $ReportPath
$jsonFull = Resolve-Stage14Path $JsonReportPath

if (![string]::IsNullOrWhiteSpace($InputPath)) {
    $inputFull = Resolve-Stage14Path $InputPath
    if (!(Test-Path -LiteralPath $inputFull)) { throw "Input file not found: $inputFull" }
    $input = Get-Content -LiteralPath $inputFull -Raw | ConvertFrom-Json
    $checks = @($input.checks | ForEach-Object { $_ })
} elseif ($UseControlledUseRehearsal) {
    $checks = @(New-FleetControlledUseRehearsalChecks)
} elseif ($UseExampleFixture) {
    $checks = @(New-FleetStage14ExampleChecks)
} else {
    throw "InputPath, UseExampleFixture, or UseControlledUseRehearsal is required."
}

$scorecard = New-FleetStage14ReadinessScorecard -Checks $checks -GeneratedAt $started
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonFull) | Out-Null
$scorecard | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $jsonFull -Encoding UTF8
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFull) | Out-Null
New-FleetStage14MarkdownReport -Scorecard $scorecard | Set-Content -LiteralPath $reportFull -Encoding UTF8

Write-Host "STAGE14_STATUS: $($scorecard.status)"
Write-Host "STAGE14_VERDICT: $($scorecard.finalVerdict)"
Write-Host "STAGE14_REPORT: $reportFull"
Write-Host "STAGE14_JSON: $jsonFull"
if ($scorecard.status -eq "FAIL") { exit 2 }
exit 0
