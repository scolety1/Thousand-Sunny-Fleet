[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$Message = "",
    [string]$InputPath = "",
    [string[]]$KnownShip = @(),
    [string]$Source = "mobile",
    [string]$RequestedBy = "captain",
    [string]$ReportPath = "",
    [string]$JsonReportPath = ""
)

$ErrorActionPreference = "Stop"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-mobile.ps1")
. (Join-Path $fleetRoot "tools\codex-fleet-control-room.ps1")

function Resolve-Stage13Path {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return [System.IO.Path]::GetFullPath($Path) }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

$started = Get-Date
$runId = "stage13-mobile-" + $started.ToString("yyyyMMdd-HHmmss-fff") + "-" + ([guid]::NewGuid().ToString("N").Substring(0, 8))
if ([string]::IsNullOrWhiteSpace($ReportPath)) { $ReportPath = "out\stage13-mobile\$runId\mobile-response.md" }
if ([string]::IsNullOrWhiteSpace($JsonReportPath)) { $JsonReportPath = "out\stage13-mobile\$runId\mobile-response.json" }
$reportFull = Resolve-Stage13Path $ReportPath
$jsonFull = Resolve-Stage13Path $JsonReportPath

if ([string]::IsNullOrWhiteSpace($Message)) { throw "Message is required for Stage 13 mobile console." }

$snapshot = $null
$knownShipsFromInput = @()
if (![string]::IsNullOrWhiteSpace($InputPath)) {
    $inputFull = Resolve-Stage13Path $InputPath
    if (!(Test-Path -LiteralPath $inputFull)) { throw "Input file not found: $inputFull" }
    $input = Get-Content -LiteralPath $inputFull -Raw | ConvertFrom-Json
    if ($input.ships) {
        $snapshot = New-FleetControlRoomSnapshot -Ships @($input.ships | ForEach-Object { $_ }) -Budget $input.budget -GeneratedAt $started
        $knownShipsFromInput = @($input.ships | ForEach-Object { [string]$_.ship })
    } elseif ($input.stage -eq "Golden Gameplan Stage 12") {
        $snapshot = $input
        $knownShipsFromInput = @($input.ships | ForEach-Object { [string]$_.ship })
    }
}

$allKnownShips = @($KnownShip + $knownShipsFromInput | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
$command = New-FleetMobileCommandRecord -Message $Message -Source $Source -RequestedBy $RequestedBy -KnownShips $allKnownShips -ReceivedAt $started -ResponsePath $reportFull
$idea = $null
$alert = $null

$response = ""
if ($command.commandType -eq "STATUS" -and $snapshot) {
    $response = New-FleetMobileStatusMessage -ControlRoomSnapshot $snapshot -FullReportPath $InputPath
} elseif ($command.commandType -eq "WHY" -and $snapshot) {
    $response = New-FleetMobileStatusMessage -ControlRoomSnapshot $snapshot -FullReportPath $InputPath
} elseif ($command.commandType -eq "DIGEST" -and $snapshot) {
    $response = New-FleetMobileDigest -ControlRoomSnapshot $snapshot -FullReportPath $InputPath
} elseif ($command.commandType -eq "CAPTURE_IDEA") {
    $idea = New-FleetMobileIdeaRecord -CommandRecord $command
    $response = "Idea captured only.`nStatus: $($idea.status)`nNext: $($idea.nextStep)`nNo task queue was changed."
} elseif ($command.commandType -in @("APPROVE_PLAN", "REJECT_PLAN")) {
    $response = "Plan response recorded: $($command.commandType).`nValidation: $($command.validationStatus)`nNext: Local PC must revalidate plan id, scope, budget, rollback, expiry, and idempotency before any execution.`nNo command was executed."
} elseif ($command.commandType -eq "RESUME_AFTER_RESET" -and $snapshot) {
    $alert = New-FleetMobileRateAlert -Budget $snapshot.budget -AffectedShips @($command.shipScope) -ReportPath $InputPath
    $response = "Resume request recorded.`nValidation: $($command.validationStatus)`nNext: $($alert.userActionNeeded)`nNo ship was resumed by the mobile layer."
} elseif ($command.commandType -eq "MUTE_NOTIFICATIONS") {
    $response = "Notification request recorded.`nStatus: $($command.status)`nValidation: $($command.validationStatus)`nNext: Local notification settings may apply this later; no fleet action was executed."
} else {
    $response = "Request recorded: $($command.commandType)`nStatus: $($command.status)`nValidation: $($command.validationStatus)`nNext: $((@($command.reasons) | Select-Object -First 1) -join '')`nNo command was executed."
}

$result = [pscustomobject]@{
    schemaVersion = 1
    stage = "Golden Gameplan Stage 13"
    runId = $runId
    status = "GREEN"
    mode = "mobile-request-only"
    startedAt = $started.ToUniversalTime().ToString("o")
    command = $command
    idea = $idea
    alert = $alert
    response = $response
    executes = $false
    forbiddenActions = @("raw-shell-command", "implicit-all-fleet", "merge", "push", "deploy", "delete-locks", "unvalidated-packet-import")
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $jsonFull) | Out-Null
$result | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath $jsonFull -Encoding UTF8
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $reportFull) | Out-Null
@(
    "# Stage 13 Mobile Console Response",
    "",
    "Command: $($command.commandType)",
    "Status: $($command.status)",
    "Validation: $($command.validationStatus)",
    "Executes: false",
    "",
    "## Phone Response",
    "",
    $response
) -join "`n" | Set-Content -LiteralPath $reportFull -Encoding UTF8

Write-Host "STAGE13_STATUS: GREEN"
Write-Host "STAGE13_REPORT: $reportFull"
Write-Host "STAGE13_JSON: $jsonFull"
exit 0
