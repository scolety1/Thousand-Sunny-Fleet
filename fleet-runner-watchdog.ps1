[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string[]]$Project = @(),

    [string[]]$ExcludeProject = @(),

    [string]$ControlRoot = "fleet\control",

    [string]$RunLabel = "watchdog-repair-proof",

    [ValidateSet("repair", "proof", "simplicity", "polish")]
    [string]$LoopPhase = "repair",

    [int]$MaxLaunches = 2,

    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")

function Write-RunnerLine {
    param([string]$Message)
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
}

function Read-JsonFile {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return $null }
    try { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) } catch { return $null }
}

function ConvertTo-NameList {
    param([string[]]$Values = @())
    return @(
        $Values |
            ForEach-Object { [string]$_ } |
            ForEach-Object { $_ -split "," } |
            ForEach-Object { $_.Trim() } |
            Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
}

function Get-RunModeProjectNames {
    param([object]$RunMode)

    if ($null -eq $RunMode -or $null -eq $RunMode.activeProjects) { return @() }
    return @(ConvertTo-NameList -Values @($RunMode.activeProjects | ForEach-Object { [string]$_ }))
}

function Get-RepoDirtyFiles {
    param([string]$Repo)

    Push-Location $Repo
    try {
        return @(git status --short 2>$null | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    } finally {
        Pop-Location
    }
}

function Test-RunProcessActive {
    param([int]$ProcessId)

    if ($ProcessId -le 0) { return $false }
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $false }

    try {
        if (((Get-Date) - $process.StartTime).TotalSeconds -lt 120) { return $true }
    } catch {
        return $true
    }

    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    $activeChildren = @($children | Where-Object {
        $name = [string]$_.Name
        ![string]::IsNullOrWhiteSpace($name) -and $name -notin @("conhost.exe")
    })
    return ($activeChildren.Count -gt 0)
}

function Get-RunLockState {
    param([string]$ProjectName)

    $safeName = ConvertTo-FleetLaunchSafeName -Name $ProjectName
    $lockPath = Join-Path $fleetRoot ".codex-local\locks\$safeName.lock.json"
    if (!(Test-Path -LiteralPath $lockPath)) {
        return [pscustomobject]@{ status = "none"; active = $false; path = $lockPath; pid = 0 }
    }

    try {
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        $pidValue = if ($null -ne $lock.pid) { [int]$lock.pid } else { 0 }
        if (Test-RunProcessActive -ProcessId $pidValue) {
            return [pscustomobject]@{ status = "active PID $pidValue"; active = $true; path = $lockPath; pid = $pidValue }
        }
        if ($null -ne (Get-Process -Id $pidValue -ErrorAction SilentlyContinue)) {
            return [pscustomobject]@{ status = "idle shell PID $pidValue"; active = $false; path = $lockPath; pid = $pidValue }
        }
        return [pscustomobject]@{ status = "stale PID $pidValue"; active = $false; path = $lockPath; pid = $pidValue }
    } catch {
        return [pscustomobject]@{ status = "unreadable"; active = $false; path = $lockPath; pid = 0 }
    }
}

function Test-SafeStopRequested {
    param([string]$ProjectName)

    $safeName = ConvertTo-FleetLaunchSafeName -Name $ProjectName
    $stopPath = Join-Path $fleetRoot ".codex-local\stop-requests\$safeName.stop.json"
    return (Test-Path -LiteralPath $stopPath)
}

function Get-FirstUncheckedTask {
    param([string]$Repo)

    $queue = Join-Path $Repo "docs\codex\TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $queue)) { return "" }
    foreach ($line in Get-Content -LiteralPath $queue) {
        if ($line -match "^\s*-\s+\[ \]\s+(.+)$") { return $matches[1].Trim() }
    }
    return ""
}

function Test-RecentlyQuarantinedSameTask {
    param(
        [string]$Repo,
        [string]$Task
    )

    if ([string]::IsNullOrWhiteSpace($Task)) { return $false }
    $quarantinePath = Join-Path $Repo "docs\codex\QUARANTINED_TASKS.md"
    if (!(Test-Path -LiteralPath $quarantinePath)) { return $false }

    $tail = (Get-Content -LiteralPath $quarantinePath -Tail 80 -ErrorAction SilentlyContinue) -join "`n"
    if ($tail -notmatch "(?i)Next step:.*avoid repeating this exact task") { return $false }

    $taskHead = $Task
    if ($taskHead.Length -gt 180) { $taskHead = $taskHead.Substring(0, 180) }
    return ([regex]::IsMatch($tail, [regex]::Escape($taskHead)))
}

function Invoke-LaunchGate {
    param([string]$ProjectName)

    $output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "fleet-launch-gate.ps1") -Project $ProjectName -LoopPhase $LoopPhase -Mode enforce 2>&1
    $exit = $LASTEXITCODE
    $decisionLine = @($output | Where-Object { [string]$_ -match "Launch gate .+: (READY|WARN|BLOCK)" } | Select-Object -First 1)
    $decision = if ($decisionLine.Count -gt 0 -and [string]$decisionLine[0] -match ": (READY|WARN|BLOCK)") { $matches[1] } else { "UNKNOWN" }
    return [pscustomobject]@{ exitCode = $exit; decision = $decision; output = @($output | ForEach-Object { [string]$_ }) }
}

function Start-WatchdogLaunch {
    param([string]$ProjectName)

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "scheduled-selected-overnight-run.ps1"),
        "-Project", $ProjectName,
        "-RunLabel", "$RunLabel-$ProjectName",
        "-BudgetMode", "balanced",
        "-LoopPhase", $LoopPhase,
        "-BatchSize", "1",
        "-MaxBatches", "1",
        "-MaxRuntimeMinutes", "180",
        "-MaxCompletedTasks", "1",
        "-MaxPlannerBatches", "0",
        "-MaxTaskQuarantines", "1",
        "-LaunchGateMode", "enforce",
        "-KillSwitchMode", "warn",
        "-SkipHarnessTest"
    )

    if ($DryRun) {
        Write-RunnerLine "DRY RUN: powershell $($args -join ' ')"
        return
    }

    Start-Process powershell -WorkingDirectory $fleetRoot -WindowStyle Hidden -ArgumentList $args | Out-Null
    Write-RunnerLine "Launched $ProjectName with one-batch watchdog run."
}

if ($MaxLaunches -lt 0) {
    Write-RunnerLine "-MaxLaunches must be 0 or greater."
    exit 1
}

$controlPath = if ([System.IO.Path]::IsPathRooted($ControlRoot)) { $ControlRoot } else { Join-Path $fleetRoot $ControlRoot }
$runMode = Read-JsonFile -Path (Join-Path $controlPath "run-mode.json")
$fleetMode = if ($null -ne $runMode -and $null -ne $runMode.fleetMode) { [string]($runMode.fleetMode) } else { "PAUSED" }
if ($fleetMode -ne "ACTIVE") {
    Write-RunnerLine "Fleet mode is $fleetMode; runner watchdog will not launch work."
    exit 0
}

$emergencyPath = Join-Path $controlPath "emergency.md"
$emergencyText = if (Test-Path -LiteralPath $emergencyPath) { Get-Content -LiteralPath $emergencyPath -Raw } else { "" }
if ($emergencyText -match "(?im)^\s*Emergency\s*:\s*STOP_ALL\s*$") {
    Write-RunnerLine "Emergency STOP_ALL is active; runner watchdog will not launch work."
    exit 0
}

if (!(Test-Path -LiteralPath $ConfigPath)) {
    Write-RunnerLine "Config not found: $ConfigPath"
    exit 1
}

$loadedProjects = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$projectsList = [System.Collections.Generic.List[object]]::new()
foreach ($loadedProject in @($loadedProjects)) {
    if ($loadedProject -is [array]) {
        foreach ($nestedProject in $loadedProject) {
            $projectsList.Add($nestedProject) | Out-Null
        }
    } else {
        $projectsList.Add($loadedProject) | Out-Null
    }
}
$projects = @($projectsList.ToArray())
$requested = @(ConvertTo-NameList -Values $Project)
if ($requested.Count -eq 0) { $requested = @(Get-RunModeProjectNames -RunMode $runMode) }
$excluded = @(ConvertTo-NameList -Values $ExcludeProject)

if ($requested.Count -gt 0) {
    $projects = @($projects | Where-Object { $requested -contains "$($_.name)" })
}
if ($excluded.Count -gt 0) {
    $projects = @($projects | Where-Object { $excluded -notcontains "$($_.name)" })
}

$launched = 0
foreach ($projectConfig in $projects) {
    $name = "$($projectConfig.name)"
    $repo = "$($projectConfig.repo)"
    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($repo)) {
        Write-RunnerLine "Skipping malformed project row with missing name or repo (type=$($projectConfig.GetType().FullName), value=$projectConfig)."
        continue
    }
    if ($launched -ge $MaxLaunches) {
        Write-RunnerLine "Launch budget reached ($launched/$MaxLaunches)."
        break
    }
    if (!(Test-Path -LiteralPath $repo)) {
        Write-RunnerLine "$name skipped: repo missing."
        continue
    }
    if (Test-SafeStopRequested -ProjectName $name) {
        Write-RunnerLine "$name skipped: safe-stop request exists."
        continue
    }

    $lock = Get-RunLockState -ProjectName $name
    if ($lock.active) {
        Write-RunnerLine "$name skipped: already running ($($lock.status))."
        continue
    }

    $dirty = @(Get-RepoDirtyFiles -Repo $repo)
    if ($dirty.Count -gt 0) {
        Write-RunnerLine "$name skipped: repo is dirty ($($dirty.Count) files)."
        continue
    }

    $task = Get-FirstUncheckedTask -Repo $repo
    if ([string]::IsNullOrWhiteSpace($task)) {
        Write-RunnerLine "$name skipped: no unchecked task."
        continue
    }
    if (Test-RecentlyQuarantinedSameTask -Repo $repo -Task $task) {
        Write-RunnerLine "$name skipped: first task was just quarantined and marked do-not-repeat."
        continue
    }

    $gate = Invoke-LaunchGate -ProjectName $name
    if ($gate.exitCode -ne 0 -or $gate.decision -eq "BLOCK") {
        Write-RunnerLine "$name skipped: launch gate $($gate.decision)."
        continue
    }

    Start-WatchdogLaunch -ProjectName $name
    $launched++
}

Write-RunnerLine "Runner watchdog complete. Launches: $launched."
exit 0
