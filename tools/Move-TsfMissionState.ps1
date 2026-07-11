param(
    [Parameter(Mandatory = $true)]
    [string]$MissionPath,

    [Parameter(Mandatory = $true)]
    [string]$FromState,

    [Parameter(Mandatory = $true)]
    [string]$ToState,

    [string]$QueueRoot = "fleet/missions",
    [string]$PolicyPath = "fleet/control/mission-queue-state-policy.v1.json",
    [string]$OutFile = "",
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)

function Get-QueueFullPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }
    return [System.IO.Path]::GetFullPath((Join-Path $fleetRoot $Path))
}

function Test-QueuePathInside {
    param([string]$ChildPath, [string]$ParentPath)
    $child = [System.IO.Path]::GetFullPath($ChildPath).TrimEnd('\', '/')
    $parent = [System.IO.Path]::GetFullPath($ParentPath).TrimEnd('\', '/')
    return [string]::Equals($child, $parent, [System.StringComparison]::OrdinalIgnoreCase) -or
        $child.StartsWith($parent + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Read-QueueJson {
    param([string]$Path)
    Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

$policy = Read-QueueJson -Path (Get-QueueFullPath -Path $PolicyPath)
$queueRootFull = Get-QueueFullPath -Path $QueueRoot
$missionFull = Get-QueueFullPath -Path $MissionPath
$from = $FromState.Trim()
$to = $ToState.Trim()
$blocked = New-Object System.Collections.ArrayList

if (@($policy.states | Where-Object { [string]$_ -eq $from }).Count -eq 0) {
    $blocked.Add("Unknown from state: $from") | Out-Null
}
if (@($policy.states | Where-Object { [string]$_ -eq $to }).Count -eq 0) {
    $blocked.Add("Unknown to state: $to") | Out-Null
}
if (!(Test-Path -LiteralPath $missionFull)) {
    $blocked.Add("Mission file not found: $missionFull") | Out-Null
}

$allowed = @($policy.allowed_transitions | Where-Object { [string]$_.from -eq $from -and [string]$_.to -eq $to }).Count -gt 0
if (!$allowed) {
    $blocked.Add("Transition is not allowed: $from -> $to") | Out-Null
}

$expectedFromRoot = Join-Path $queueRootFull $from
if (!(Test-QueuePathInside -ChildPath $missionFull -ParentPath $expectedFromRoot)) {
    $blocked.Add("Mission path is not inside from-state folder.") | Out-Null
}

$destinationDir = Join-Path $queueRootFull $to
$destinationPath = Join-Path $destinationDir ([System.IO.Path]::GetFileName($missionFull))
if (Test-Path -LiteralPath $destinationPath) {
    $blocked.Add("Destination mission already exists: $destinationPath") | Out-Null
}

$verdict = if ($blocked.Count -eq 0) { "GREEN" } else { "RED" }
if ($verdict -eq "GREEN" -and !$DryRun) {
    New-Item -ItemType Directory -Force -Path $destinationDir | Out-Null
    Move-Item -LiteralPath $missionFull -Destination $destinationPath
}

$result = [pscustomobject]@{
    schema_version = "mission_queue_transition_result_v1"
    verdict = $verdict
    from_state = $from
    to_state = $to
    mission_path = $missionFull
    destination_path = $destinationPath
    dry_run = [bool]$DryRun
    moved = ($verdict -eq "GREEN" -and !$DryRun)
    blocked_reasons = @($blocked)
    background_runner_started = $false
    push_performed = $false
    merge_performed = $false
}

if (![string]::IsNullOrWhiteSpace($OutFile)) {
    $outParent = Split-Path -Parent $OutFile
    if (![string]::IsNullOrWhiteSpace($outParent)) {
        New-Item -ItemType Directory -Force -Path $outParent | Out-Null
    }
    $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutFile -Encoding UTF8
}

$result
