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

    [switch]$ValidateLaunchCommandOnly,

    [switch]$ValidateHeartbeatOnly,

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

function Limit-ToActiveProjects {
    param(
        [object[]]$Projects,
        [object]$RunMode
    )

    $activeNames = @(Get-RunModeProjectNames -RunMode $RunMode)
    if ($activeNames.Count -eq 0) { return @($Projects) }
    return @($Projects | Where-Object { $activeNames -contains [string]$_.name })
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

function ConvertTo-NullableDateTime {
    param([object]$Value)

    if ($null -eq $Value) { return $null }
    try { return [DateTime]::Parse([string]$Value, $null, [Globalization.DateTimeStyles]::RoundtripKind) } catch { return $null }
}

function Get-RunHeartbeatState {
    param([string]$ProjectName)

    $safeName = ConvertTo-FleetLaunchSafeName -Name $ProjectName
    $heartbeatPath = Join-Path $fleetRoot ".codex-local\runs\$safeName\heartbeat.json"
    if (!(Test-Path -LiteralPath $heartbeatPath)) {
        return [pscustomobject]@{ classification = "missing"; active = $false; processActive = $false; status = "missing"; path = $heartbeatPath; pid = 0; lastHeartbeatAt = $null; lastProgressAt = $null; currentTaskSummary = ""; runShape = $null }
    }

    try {
        $heartbeat = Get-Content -LiteralPath $heartbeatPath -Raw | ConvertFrom-Json
        $pidValue = if ($null -ne $heartbeat.pid) { [int]$heartbeat.pid } else { 0 }
        $processActive = Test-RunProcessActive -ProcessId $pidValue
        $status = if ($null -ne $heartbeat.status) { [string]$heartbeat.status } else { "unknown" }
        $lastHeartbeatAt = ConvertTo-NullableDateTime -Value $heartbeat.lastHeartbeatAt
        $lastProgressAt = ConvertTo-NullableDateTime -Value $heartbeat.lastProgressAt
        $ageMinutes = if ($null -ne $lastHeartbeatAt) { ((Get-Date).ToUniversalTime() - $lastHeartbeatAt.ToUniversalTime()).TotalMinutes } else { [double]::PositiveInfinity }
        $progressAgeMinutes = if ($null -ne $lastProgressAt) { ((Get-Date).ToUniversalTime() - $lastProgressAt.ToUniversalTime()).TotalMinutes } else { [double]::PositiveInfinity }

        $classification = "stale"
        $active = $false
        if ($status -in @("completed")) {
            $classification = "completed"
        } elseif ($status -in @("parked", "stopped")) {
            $classification = "parked"
        } elseif (-not $processActive) {
            $classification = "stale"
        } elseif ($ageMinutes -gt 30) {
            $classification = "stalled"
            $active = $true
        } elseif ($progressAgeMinutes -gt 15) {
            $classification = "idle"
            $active = $true
        } else {
            $classification = "active"
            $active = $true
        }

        return [pscustomobject]@{
            classification = $classification
            active = $active
            processActive = $processActive
            status = $status
            path = $heartbeatPath
            pid = $pidValue
            lastHeartbeatAt = $lastHeartbeatAt
            lastProgressAt = $lastProgressAt
            currentTaskSummary = if ($null -ne $heartbeat.currentTaskSummary) { [string]$heartbeat.currentTaskSummary } else { "" }
            runShape = $heartbeat.runShape
        }
    } catch {
        return [pscustomobject]@{ classification = "unreadable"; active = $false; processActive = $false; status = "unreadable"; path = $heartbeatPath; pid = 0; lastHeartbeatAt = $null; lastProgressAt = $null; currentTaskSummary = ""; runShape = $null }
    }
}

function Format-RunHeartbeatState {
    param([object]$State)

    if ($null -eq $State) { return "missing" }
    $parts = @($State.classification, "status=$($State.status)", "pid=$($State.pid)")
    if ($null -ne $State.lastHeartbeatAt) { $parts += "lastHeartbeat=$($State.lastHeartbeatAt.ToString('s'))" }
    if ($null -ne $State.lastProgressAt) { $parts += "lastProgress=$($State.lastProgressAt.ToString('s'))" }
    if (![string]::IsNullOrWhiteSpace([string]$State.currentTaskSummary)) { $parts += "task=$($State.currentTaskSummary)" }
    return ($parts -join "; ")
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

function Get-WatchdogLaunchArgs {
    param([string]$ProjectName)

    if ($ProjectName -eq "EasyLife") {
        return @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "launch-overnight-run.ps1"),
            "-Project", "EasyLife",
            "-ExpectedProject", "EasyLife",
            "-Safe12",
            "-SkipDoctor"
        )
    }

    return @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "scheduled-selected-overnight-run.ps1"),
        "-Project", $ProjectName,
        "-ExpectedProject", $ProjectName,
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
}

function Start-WatchdogLaunch {
    param(
        [string]$ProjectName,
        [switch]$PreviewOnly
    )

    $args = @(Get-WatchdogLaunchArgs -ProjectName $ProjectName)
    $command = "powershell $($args -join ' ')"

    if ($DryRun -or $PreviewOnly) {
        Write-RunnerLine "DRY RUN: $command"
        if ($ProjectName -eq "EasyLife") {
            & powershell @($args + "-DryRun")
        }
        return
    }

    Start-Process powershell -WorkingDirectory $fleetRoot -WindowStyle Hidden -ArgumentList $args | Out-Null
    if ($ProjectName -eq "EasyLife") {
        Write-RunnerLine "Launched $ProjectName with Safe12 watchdog run."
    } else {
        Write-RunnerLine "Launched $ProjectName with one-batch watchdog run."
    }
}

if ($MaxLaunches -lt 0) {
    Write-RunnerLine "-MaxLaunches must be 0 or greater."
    exit 1
}

if ($ValidateHeartbeatOnly) {
    $names = @(ConvertTo-NameList -Values $Project)
    if ($names.Count -eq 0) { $names = @("HarnessHeartbeat") }
    foreach ($name in $names) {
        $state = Get-RunHeartbeatState -ProjectName $name
        Write-RunnerLine "$name heartbeat: $(Format-RunHeartbeatState -State $state)"
    }
    Write-RunnerLine "Runner watchdog heartbeat validation complete."
    exit 0
}

$controlPath = if ([System.IO.Path]::IsPathRooted($ControlRoot)) { $ControlRoot } else { Join-Path $fleetRoot $ControlRoot }
$runMode = Read-JsonFile -Path (Join-Path $controlPath "run-mode.json")
$fleetMode = if ($null -ne $runMode -and $null -ne $runMode.fleetMode) { [string]($runMode.fleetMode) } else { "PAUSED" }
if (!$ValidateLaunchCommandOnly -and $fleetMode -ne "ACTIVE") {
    Write-RunnerLine "Fleet mode is $fleetMode; runner watchdog will not launch work."
    exit 0
}

$emergencyPath = Join-Path $controlPath "emergency.md"
$emergencyText = if (Test-Path -LiteralPath $emergencyPath) { Get-Content -LiteralPath $emergencyPath -Raw } else { "" }
if (!$ValidateLaunchCommandOnly -and $emergencyText -match "(?im)^\s*Emergency\s*:\s*STOP_ALL\s*$") {
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
$projects = @(Limit-ToActiveProjects -Projects $projects -RunMode $runMode)
if ($excluded.Count -gt 0) {
    $projects = @($projects | Where-Object { $excluded -notcontains "$($_.name)" })
}

if ($ValidateLaunchCommandOnly) {
    foreach ($projectConfig in $projects) {
        $name = "$($projectConfig.name)"
        if (![string]::IsNullOrWhiteSpace($name)) {
            Start-WatchdogLaunch -ProjectName $name -PreviewOnly
        }
    }
    Write-RunnerLine "Runner watchdog launch command validation complete."
    exit 0
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

    $heartbeat = Get-RunHeartbeatState -ProjectName $name
    if ($heartbeat.active) {
        Write-RunnerLine "$name skipped: heartbeat says $($heartbeat.classification) ($(Format-RunHeartbeatState -State $heartbeat))."
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
