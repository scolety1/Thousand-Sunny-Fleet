[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$Json
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $PSCommandPath
$cli = Join-Path $scriptRoot 'reliability-cli.mjs'
. (Join-Path $scriptRoot 'doctor-format.ps1')
$node = Get-Command node -ErrorAction SilentlyContinue
if ($null -eq $node) { throw 'TSF_HQ_DOCTOR_NODE_UNAVAILABLE' }

$raw = & $node.Source $cli doctor | Out-String
$exitCode = $LASTEXITCODE
try {
    $report = $raw | ConvertFrom-Json
} catch {
    throw 'TSF_HQ_DOCTOR_OUTPUT_INVALID'
}

if ($Json) {
    $report | ConvertTo-Json -Depth 30
    exit $exitCode
}

$humanLines = @(ConvertTo-TsfHqDispatchDoctorHumanLinesV1 -Report $report)
Write-Host $humanLines[0] -ForegroundColor $(if ($report.safe_to_start) { 'Green' } elseif ($report.overall_status -eq 'UNSAFE_TO_START') { 'Red' } else { 'Yellow' })
$humanLines | Select-Object -Skip 1 | Write-Output
exit $exitCode
