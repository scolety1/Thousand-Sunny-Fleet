[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$TaskName = "CodexFleet_RemoteControl_Hourly",

    [string]$StartTime = "07:00",

    [int]$IntervalHours = 1,

    [switch]$RunNow
)

$ErrorActionPreference = "Stop"

if ($IntervalHours -lt 1) {
    Write-Host "-IntervalHours must be at least 1." -ForegroundColor Red
    exit 1
}

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$watchdogPath = Join-Path $fleetRoot "fleet-remote-control-watchdog.ps1"
if (!(Test-Path $watchdogPath)) {
    Write-Host "Watchdog script not found: $watchdogPath" -ForegroundColor Red
    exit 1
}

$start = [datetime]::Today.Add([TimeSpan]::Parse($StartTime))
if ($start -lt (Get-Date).AddMinutes(-1)) {
    $start = $start.AddDays(1)
}

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$watchdogPath`"" -WorkingDirectory $fleetRoot
$trigger = New-ScheduledTaskTrigger -Once -At $start -RepetitionInterval (New-TimeSpan -Hours $IntervalHours) -RepetitionDuration (New-TimeSpan -Days 3650)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2) -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "Runs the Codex fleet remote-control GitHub status/control cycle hourly." -Force | Out-Null

Write-Host "Installed scheduled task: $TaskName" -ForegroundColor Green
Write-Host "Next run: $((Get-ScheduledTaskInfo -TaskName $TaskName).NextRunTime)"
Write-Host "Action: powershell.exe -NoProfile -ExecutionPolicy Bypass -File $watchdogPath"

if ($RunNow) {
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "Started scheduled task now." -ForegroundColor Green
}
