[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)][string]$PacketPath,
    [string]$InboxRoot = "C:\TSF_INBOX",
    [string]$ReportPath = "",
    [string]$JsonReportPath = ""
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-project-management.ps1")

function Resolve-ProjectControlPath {
    param(
        [string]$Path,
        [string]$DefaultRelativePath = "",
        [switch]$AllowInbox
    )

    $value = if ([string]::IsNullOrWhiteSpace($Path)) { $DefaultRelativePath } else { $Path }
    if ([string]::IsNullOrWhiteSpace($value)) { throw "Path is required." }

    $fullPath = if ([System.IO.Path]::IsPathRooted($value)) {
        [System.IO.Path]::GetFullPath($value)
    } else {
        [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $value))
    }

    $fleetFull = [System.IO.Path]::GetFullPath($fleetRoot)
    if (!$fleetFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $fleetFull += [System.IO.Path]::DirectorySeparatorChar
    }
    if ($fullPath.StartsWith($fleetFull, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath
    }

    if ($AllowInbox) {
        $inboxFull = [System.IO.Path]::GetFullPath($InboxRoot)
        if (!$inboxFull.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
            $inboxFull += [System.IO.Path]::DirectorySeparatorChar
        }
        if ($fullPath.StartsWith($inboxFull, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $fullPath
        }
    }

    throw "Project-management control paths must stay inside the Fleet repo or explicit inbox root: $value"
}

$started = Get-Date
$runId = "project-management-" + $started.ToString("yyyyMMdd-HHmmss-fff")
$packetFull = Resolve-ProjectControlPath -Path $PacketPath -AllowInbox
if (!(Test-Path -LiteralPath $packetFull -PathType Leaf)) {
    throw "Project-management packet not found: $packetFull"
}
if ($packetFull -notmatch "(?i)\.json$") {
    throw "Project-management packet must be JSON: $packetFull"
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = "out\project-management\$runId\control-report.md"
}
if ([string]::IsNullOrWhiteSpace($JsonReportPath)) {
    $JsonReportPath = "out\project-management\$runId\control-guide.json"
}

$reportFull = Resolve-ProjectControlPath -Path $ReportPath
$jsonFull = Resolve-ProjectControlPath -Path $JsonReportPath

$packet = Get-Content -LiteralPath $packetFull -Raw | ConvertFrom-Json
$guide = New-FleetProjectManagementGuide -Packet $packet -InboxRoot $InboxRoot
$guide | Add-Member -NotePropertyName packetPath -NotePropertyValue $packetFull -Force
$guide | Add-Member -NotePropertyName reportPath -NotePropertyValue $reportFull -Force
$guide | Add-Member -NotePropertyName jsonReportPath -NotePropertyValue $jsonFull -Force
$guide | Add-Member -NotePropertyName entrypoint -NotePropertyValue "invoke-project-management-control.ps1" -Force
$guide | Add-Member -NotePropertyName executesProductActions -NotePropertyValue $false -Force
$guide | Add-Member -NotePropertyName mutatesProductRepos -NotePropertyValue $false -Force
$guide | Add-Member -NotePropertyName nonExecutable -NotePropertyValue $true -Force
$guide | Add-Member -NotePropertyName canApproveFutureRuns -NotePropertyValue $false -Force

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonFull) | Out-Null
$guide | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $jsonFull -Encoding UTF8

$lines = New-FleetProjectManagementReportLines -Guide $guide
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFull) | Out-Null
$lines | Set-Content -LiteralPath $reportFull -Encoding UTF8

Write-Host "PROJECT_MANAGEMENT_STATUS: $($guide.terminalState)"
Write-Host "PROJECT_MANAGEMENT_PROFILE: $($guide.autonomyProfile)"
Write-Host "PROJECT_MANAGEMENT_REPORT: $reportFull"
Write-Host "PROJECT_MANAGEMENT_JSON: $jsonFull"

switch ([string]$guide.terminalState) {
    "GREEN" { exit 0 }
    "YELLOW" { exit 0 }
    "RED" { exit 2 }
    "BLOCKED" { exit 3 }
    default { exit 1 }
}
