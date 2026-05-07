[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$LogRoot = "out\remote-control-watchdog",

    [switch]$NoSupervisor,

    [switch]$NoPublish,

    [switch]$EnableRunner,

    [int]$RunnerMaxLaunches = 2,

    [ValidateSet("repair", "proof", "simplicity", "polish")]
    [string]$RunnerLoopPhase = "repair"
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

$resolvedLogRoot = if ([System.IO.Path]::IsPathRooted($LogRoot)) { $LogRoot } else { Join-Path $fleetRoot $LogRoot }
New-Item -ItemType Directory -Force -Path $resolvedLogRoot | Out-Null

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logPath = Join-Path $resolvedLogRoot "remote-control-$stamp.log"
$latestPath = Join-Path $resolvedLogRoot "latest.log"

function Write-WatchdogLog {
    param([string]$Message)
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $logPath -Value $line
    Write-Host $line
}

Write-WatchdogLog "Fleet remote-control watchdog starting."
Write-WatchdogLog "Fleet root: $fleetRoot"

$arguments = @(
    "-NoProfile",
    "-ExecutionPolicy",
    "Bypass",
    "-File",
    (Join-Path $fleetRoot "fleet-remote-control.ps1")
)
if (!$NoSupervisor) { $arguments += "-RunSupervisor" }
if (!$NoPublish) { $arguments += "-Publish" }

$stdoutPath = Join-Path $resolvedLogRoot "remote-control-$stamp.out.log"
$stderrPath = Join-Path $resolvedLogRoot "remote-control-$stamp.err.log"

$process = Start-Process powershell.exe -WorkingDirectory $fleetRoot -ArgumentList $arguments -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru -WindowStyle Hidden
$process.WaitForExit()
$process.Refresh()
$exitCode = $process.ExitCode
if ($null -eq $exitCode) { $exitCode = 0 }

Write-WatchdogLog "Remote-control exit code: $exitCode"
if (Test-Path $stdoutPath) {
    Add-Content -Path $logPath -Value ""
    Add-Content -Path $logPath -Value "----- stdout -----"
    Add-Content -Path $logPath -Value (Get-Content $stdoutPath -ErrorAction SilentlyContinue)
}
if (Test-Path $stderrPath) {
    Add-Content -Path $logPath -Value ""
    Add-Content -Path $logPath -Value "----- stderr -----"
    Add-Content -Path $logPath -Value (Get-Content $stderrPath -ErrorAction SilentlyContinue)
}

$statusPath = Join-Path $fleetRoot "fleet\status\current.md"
if (Test-Path $statusPath) {
    Add-Content -Path $logPath -Value ""
    Add-Content -Path $logPath -Value "----- current status head -----"
    Add-Content -Path $logPath -Value (Get-Content $statusPath -TotalCount 40 -ErrorAction SilentlyContinue)
}

if ($EnableRunner) {
    $runnerPath = Join-Path $fleetRoot "fleet-runner-watchdog.ps1"
    $runnerStdoutPath = Join-Path $resolvedLogRoot "runner-$stamp.out.log"
    $runnerStderrPath = Join-Path $resolvedLogRoot "runner-$stamp.err.log"
    if (Test-Path $runnerPath) {
        Write-WatchdogLog "Starting fleet runner watchdog."
        $runnerArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $runnerPath,
            "-MaxLaunches", ([string]$RunnerMaxLaunches),
            "-LoopPhase", $RunnerLoopPhase
        )
        $runner = Start-Process powershell.exe -WorkingDirectory $fleetRoot -ArgumentList $runnerArgs -RedirectStandardOutput $runnerStdoutPath -RedirectStandardError $runnerStderrPath -PassThru -WindowStyle Hidden
        $runner.WaitForExit()
        $runner.Refresh()
        $runnerExitCode = $runner.ExitCode
        if ($null -eq $runnerExitCode) { $runnerExitCode = 0 }
        Write-WatchdogLog "Runner watchdog exit code: $runnerExitCode"
        if (Test-Path $runnerStdoutPath) {
            Add-Content -Path $logPath -Value ""
            Add-Content -Path $logPath -Value "----- runner stdout -----"
            Add-Content -Path $logPath -Value (Get-Content $runnerStdoutPath -ErrorAction SilentlyContinue)
        }
        if (Test-Path $runnerStderrPath) {
            Add-Content -Path $logPath -Value ""
            Add-Content -Path $logPath -Value "----- runner stderr -----"
            Add-Content -Path $logPath -Value (Get-Content $runnerStderrPath -ErrorAction SilentlyContinue)
        }
        if ($runnerExitCode -ne 0 -and ($null -eq $exitCode -or $exitCode -eq 0)) {
            $exitCode = $runnerExitCode
        }
    } else {
        Write-WatchdogLog "Runner watchdog requested but script is missing: $runnerPath"
        if ($null -eq $exitCode -or $exitCode -eq 0) { $exitCode = 1 }
    }
}

Copy-Item -LiteralPath $logPath -Destination $latestPath -Force -ErrorAction SilentlyContinue
Write-WatchdogLog "Fleet remote-control watchdog complete. Log: $logPath"
exit $exitCode
