[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string[]]$Project = @(),

    [string[]]$ExcludeProject = @(),

    [string]$ControlRoot = "fleet\control",

    [string]$StatusRoot = "fleet\status",

    [string]$StateRoot = "fleet\state",

    [string]$TimeZoneId = "Pacific Standard Time",

    [int]$MissionQuietStartHour = 3,

    [int]$MissionQuietEndHour = 7,

    [int]$ReportStartHour = 7,

    [int]$ReportEndHour = 2,

    [int]$ArchiveRetentionDays = 14,

    [int]$SupervisorTimeoutSeconds = 420,

    [int]$IdleShellStaleMinutes = 45,

    [switch]$RunSupervisor,

    [switch]$AllowRepairLaunch,

    [switch]$Publish,

    [switch]$SkipPull,

    [switch]$ForceReport,

    [switch]$RotateOnly,

    [switch]$ValidateHeartbeatOnly,

    [switch]$ValidateStatusSnapshotOnly,

    [switch]$ValidateLockCleanupOnly,

    [switch]$AllProjects,

    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1")

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Ensure-Directory {
    param([string]$Path)
    if (![string]::IsNullOrWhiteSpace($Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Resolve-ControlPath {
    param([string]$Path)
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $fleetRoot $Path)
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

function Get-ControlNow {
    param([string]$WindowsTimeZoneId)
    try {
        $timeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById($WindowsTimeZoneId)
        return [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $timeZone)
    } catch {
        Write-Host "Could not resolve time zone '$WindowsTimeZoneId'; using local time." -ForegroundColor Yellow
        return Get-Date
    }
}

function Test-HourWindow {
    param(
        [int]$Hour,
        [int]$StartHour,
        [int]$EndHour
    )

    if ($StartHour -eq $EndHour) { return $true }
    if ($StartHour -lt $EndHour) {
        return ($Hour -ge $StartHour -and $Hour -lt $EndHour)
    }
    return ($Hour -ge $StartHour -or $Hour -lt $EndHour)
}

function Get-TextSha256 {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace("-", "").ToLowerInvariant()
    } finally {
        $sha.Dispose()
    }
}

function Read-JsonFile {
    param([string]$Path)
    if (!(Test-Path $Path)) { return $null }
    try {
        return (Get-Content $Path -Raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )
    Ensure-Directory -Path (Split-Path -Parent $Path)
    if (!$DryRun) {
        $Value | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
    }
}

function Initialize-RemoteControlFiles {
    param(
        [string]$ControlPath,
        [string]$StatusPath,
        [string]$StatePath
    )

    Ensure-Directory -Path $ControlPath
    Ensure-Directory -Path $StatusPath
    Ensure-Directory -Path (Join-Path $StatusPath "archive")
    Ensure-Directory -Path $StatePath

    $missionPath = Join-Path $ControlPath "mission.md"
    if (!(Test-Path $missionPath) -and !$DryRun) {
        Set-Content -Path $missionPath -Encoding UTF8 -Value @(
            "# Fleet Mission",
            "",
            "## Fleet Mode",
            "PAUSED",
            "",
            "## Active Projects",
            "- EasyLife",
            "- RestaurantDemo",
            "",
            "## Mission",
            "Keep the fleet paused until a current mission is written here.",
            "",
            "## Priority",
            "Do not start new work without an explicit project and phase goal.",
            "",
            "## Do Not Do",
            "- Do not deploy.",
            "- Do not change auth, payments, secrets, legal text, or package dependencies.",
            "- Do not overwrite user-owned work.",
            "",
            "## Next Checkpoint",
            "Report current project state and wait for direction."
        )
    }

    $runModePath = Join-Path $ControlPath "run-mode.json"
    if (!(Test-Path $runModePath) -and !$DryRun) {
        [pscustomobject]@{
            fleetMode = "PAUSED"
            activeProjects = @("EasyLife", "RestaurantDemo")
            quietHours = [pscustomobject]@{
                timeZone = $TimeZoneId
                missionUpdatesPausedFrom = "03:00"
                missionUpdatesResumeAt = "07:00"
            }
            reportCadence = [pscustomobject]@{
                publishWindow = "07:00-02:00"
                noChangeReports = "skip unless ForceReport is used"
            }
            emergency = "Set Emergency: STOP_ALL in fleet/control/emergency.md to request safe stops at any hour."
        } | ConvertTo-Json -Depth 6 | Set-Content -Path $runModePath -Encoding UTF8
    }

    $emergencyPath = Join-Path $ControlPath "emergency.md"
    if (!(Test-Path $emergencyPath) -and !$DryRun) {
        Set-Content -Path $emergencyPath -Encoding UTF8 -Value @(
            "# Fleet Emergency",
            "",
            "Emergency: NONE",
            "",
            "To stop all selected projects at any hour, change the status line to STOP_ALL."
        )
    }
}

function Get-GitValue {
    param([string[]]$Arguments)
    $result = Invoke-FleetProcess -FilePath "git" -Arguments $Arguments -WorkingDirectory $fleetRoot -TimeoutSeconds 30
    if ($result.exitCode -ne 0 -or $result.output.Count -eq 0) { return "" }
    return ([string]$result.output[0]).Trim()
}

function Invoke-GitStep {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [int]$TimeoutSeconds = 120
    )

    if ($DryRun) {
        Write-Host "DRY RUN: git $($Arguments -join ' ')"
        return 0
    }

    $result = Invoke-FleetProcess -FilePath "git" -Arguments $Arguments -WorkingDirectory $fleetRoot -TimeoutSeconds $TimeoutSeconds
    if ($result.exitCode -ne 0) {
        Write-Host "$Name failed." -ForegroundColor Yellow
        if ($result.output.Count -gt 0) { $result.output | Select-Object -First 8 | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow } }
    }
    return $result.exitCode
}

function Acquire-RemoteControlLock {
    $lockRoot = Join-Path $fleetRoot ".codex-local\locks"
    Ensure-Directory -Path $lockRoot
    $lockPath = Join-Path $lockRoot "fleet-remote-control.lock.json"

    if (Test-Path $lockPath) {
        $lock = Read-JsonFile -Path $lockPath
        $pid = if ($null -ne $lock -and $null -ne $lock.pid) { [int]$lock.pid } else { 0 }
        $startedAt = if ($null -ne $lock -and $null -ne $lock.startedAt) { [datetime]$lock.startedAt } else { (Get-Date).AddHours(-3) }
        $alive = $false
        if ($pid -gt 0) {
            $alive = ($null -ne (Get-Process -Id $pid -ErrorAction SilentlyContinue))
        }
        if ($alive -and ((Get-Date) - $startedAt).TotalHours -lt 2) {
            Stop-WithMessage "Remote control lock is active for PID $pid. Refusing overlapping run."
        }
        Write-Host "Clearing stale remote-control lock for PID $pid." -ForegroundColor Yellow
        if (!$DryRun) { Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue }
    }

    $lockValue = [pscustomobject]@{
        pid = $PID
        startedAt = (Get-Date).ToString("o")
        script = "fleet-remote-control.ps1"
    }
    Write-JsonFile -Path $lockPath -Value $lockValue
    return $lockPath
}

function Release-RemoteControlLock {
    param([string]$LockPath)
    if (![string]::IsNullOrWhiteSpace($LockPath) -and (Test-Path $LockPath) -and !$DryRun) {
        Remove-Item -LiteralPath $LockPath -Force -ErrorAction SilentlyContinue
    }
}

function Get-SelectedProjects {
    param(
        [string]$ConfigFile,
        [string[]]$RequestedProjects,
        [string[]]$ExcludedProjects,
        [object]$RunMode,
        [bool]$IncludeAllProjects = $false
    )

    if (!(Test-Path $ConfigFile)) { Stop-WithMessage "Config not found: $ConfigFile" }
    $projects = @(Get-Content $ConfigFile -Raw | ConvertFrom-Json | ForEach-Object { $_ })
    $names = @($RequestedProjects | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if (!$IncludeAllProjects -and $names.Count -eq 0 -and $null -ne $RunMode -and $null -ne $RunMode.activeProjects) {
        $names = @($RunMode.activeProjects | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    }
    if ($names.Count -gt 0) {
        $projects = @($projects | Where-Object { $names -contains [string]$_.name })
    }
    if (!$IncludeAllProjects -and $names.Count -gt 0 -and $null -ne $RunMode -and $null -ne $RunMode.activeProjects) {
        $activeNames = @($RunMode.activeProjects | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
        if ($activeNames.Count -gt 0) {
            $projects = @($projects | Where-Object { $activeNames -contains [string]$_.name })
        }
    }
    if ($ExcludedProjects.Count -gt 0) {
        $projects = @($projects | Where-Object { $ExcludedProjects -notcontains [string]$_.name })
    }
    return $projects
}

function Get-TaskWorkflowSummary {
    param([string]$Task)

    if ([string]::IsNullOrWhiteSpace($Task)) { return "none" }
    $workflowMatch = [regex]::Match($Task, "(?i)\b(?:Skill|Workflow)\s*:\s*([^.;\[\r\n]+)")
    if ($workflowMatch.Success) {
        return $workflowMatch.Groups[1].Value.Trim()
    }

    $metadataMatches = @([regex]::Matches($Task, "\[([^\]]+)\]") | ForEach-Object { $_.Groups[1].Value })
    foreach ($metadata in $metadataMatches) {
        $skillMatch = [regex]::Match($metadata, "(?:^|\s)(?:skill|workflow):([^\s]+)")
        if ($skillMatch.Success) { return $skillMatch.Groups[1].Value.Trim() }
    }

    $class = "feature"
    $impact = "standard"
    foreach ($metadata in $metadataMatches) {
        $classMatch = [regex]::Match($metadata, "(?:^|\s)class:([^\s]+)")
        if ($classMatch.Success) { $class = $classMatch.Groups[1].Value.Trim().ToLowerInvariant() }
        $impactMatch = [regex]::Match($metadata, "(?:^|\s)impact:([^\s]+)")
        if ($impactMatch.Success) { $impact = $impactMatch.Groups[1].Value.Trim().ToLowerInvariant() }
    }

    switch ($class) {
        "design" { return "frontend-ui-engineering (inferred)" }
        "copy" { return "code-review-and-quality (inferred)" }
        "bugfix" { return "debugging-and-error-recovery (inferred)" }
        "planning" { return "planning-and-task-breakdown (inferred)" }
        "proof" { return "code-review-and-quality (inferred)" }
        "test" { return "test-driven-development (inferred)" }
        "docs" { return "documentation-and-adrs (inferred)" }
        "backend" { return "api-and-interface-design (inferred)" }
        "integration" { return "api-and-interface-design (inferred)" }
        "migration" { return "deprecation-and-migration (inferred)" }
        default {
            if ($impact -in @("visible", "showpiece")) { return "frontend-ui-engineering (inferred)" }
            return "incremental-implementation (inferred)"
        }
    }
}

function Request-ProjectSafeStop {
    param([object[]]$Projects)
    foreach ($ship in $Projects) {
        $name = [string]$ship.name
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($DryRun) {
            Write-Host "DRY RUN: request safe stop for $name"
            continue
        }
        $result = Invoke-FleetProcess -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fleetRoot "request-safe-stop.ps1"), "-Project", $name) -WorkingDirectory $fleetRoot -TimeoutSeconds 60
        if ($result.exitCode -ne 0) {
            Write-Host "Safe-stop request failed for $name." -ForegroundColor Yellow
        }
    }
}

function ConvertTo-RunStateSafeName {
    param([string]$Name)

    $safeName = ([string]$Name) -replace "[^a-zA-Z0-9_.-]+", "-"
    $safeName = $safeName.Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeName)) { return "project" }
    return $safeName
}

function Test-RunStateProcessActive {
    param([int]$ProcessId)

    if ($ProcessId -le 0) { return $false }
    return ($null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue))
}

function Get-RunStateChildProcesses {
    param([int]$ProcessId)

    if ($ProcessId -le 0) { return @() }
    try {
        return @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    } catch {
        return @()
    }
}

function Test-RunStateActiveChildWork {
    param([int]$ProcessId)

    $children = @(Get-RunStateChildProcesses -ProcessId $ProcessId)
    $activeChildren = @($children | Where-Object {
        $name = [string]$_.Name
        ![string]::IsNullOrWhiteSpace($name) -and $name -notin @("conhost.exe")
    })
    return ($activeChildren.Count -gt 0)
}

function Get-RunLockStartedAt {
    param(
        [object]$Lock,
        [string]$Path
    )

    foreach ($propertyName in @("startedAt", "createdAt", "timestamp", "updatedAt")) {
        if ($null -ne $Lock -and $null -ne $Lock.PSObject.Properties[$propertyName]) {
            try { return [DateTime]::Parse([string]$Lock.$propertyName, $null, [Globalization.DateTimeStyles]::RoundtripKind) } catch {}
        }
    }
    if (Test-Path -LiteralPath $Path) {
        return (Get-Item -LiteralPath $Path).LastWriteTime
    }
    return Get-Date
}

function Write-RunLockCleanupLog {
    param(
        [string]$ProjectName,
        [string]$LockPath,
        [int]$ProcessId,
        [string]$Reason,
        [bool]$Removed
    )

    $logPath = Join-Path $fleetRoot "out\fleet-lock-cleanup.md"
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $logPath) | Out-Null
    if (!(Test-Path -LiteralPath $logPath)) {
        "# Fleet Lock Cleanup`n" | Set-Content -LiteralPath $logPath -Encoding UTF8
    }
    Add-Content -LiteralPath $logPath -Encoding UTF8 -Value @(
        "",
        "## $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "",
        "- Project: $ProjectName",
        "- Lock: $LockPath",
        "- PID: $ProcessId",
        "- Reason: $Reason",
        "- Removed: $Removed"
    )
}

function Get-ProjectRunLockState {
    param([string]$ProjectName)

    $safeName = ConvertTo-RunStateSafeName -Name $ProjectName
    $lockPath = Join-Path $fleetRoot ".codex-local\locks\$safeName.lock.json"
    if (!(Test-Path -LiteralPath $lockPath)) {
        return [pscustomobject]@{ state = "missing"; active = $false; pid = 0; path = $lockPath }
    }

    try {
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        $pidValue = if ($null -ne $lock.pid) { [int]$lock.pid } else { 0 }
        $processActive = Test-RunStateProcessActive -ProcessId $pidValue
        if (!$processActive) {
            Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
            Write-RunLockCleanupLog -ProjectName $ProjectName -LockPath $lockPath -ProcessId $pidValue -Reason "dead PID" -Removed (!(Test-Path -LiteralPath $lockPath))
            return [pscustomobject]@{ state = "removed-stale-dead-pid"; active = $false; pid = $pidValue; path = $lockPath }
        }

        if (Test-RunStateActiveChildWork -ProcessId $pidValue) {
            return [pscustomobject]@{ state = "active"; active = $true; pid = $pidValue; path = $lockPath }
        }

        $startedAt = Get-RunLockStartedAt -Lock $lock -Path $lockPath
        $idleMinutes = ((Get-Date) - $startedAt).TotalMinutes
        if ($IdleShellStaleMinutes -ge 0 -and $idleMinutes -ge $IdleShellStaleMinutes) {
            Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
            Write-RunLockCleanupLog -ProjectName $ProjectName -LockPath $lockPath -ProcessId $pidValue -Reason "idle shell stale for $([Math]::Round($idleMinutes, 1)) minutes with no active child work" -Removed (!(Test-Path -LiteralPath $lockPath))
            return [pscustomobject]@{ state = "removed-stale-idle-shell"; active = $false; pid = $pidValue; path = $lockPath }
        }

        return [pscustomobject]@{ state = "idle-shell"; active = $false; pid = $pidValue; path = $lockPath }
    } catch {
        return [pscustomobject]@{ state = "unreadable"; active = $false; pid = 0; path = $lockPath }
    }
}

function ConvertTo-RunStateDateTime {
    param([object]$Value)

    if ($null -eq $Value) { return $null }
    try { return [DateTime]::Parse([string]$Value, $null, [Globalization.DateTimeStyles]::RoundtripKind) } catch { return $null }
}

function Get-ProjectRunHeartbeatState {
    param([string]$ProjectName)

    $safeName = ConvertTo-RunStateSafeName -Name $ProjectName
    $heartbeatPath = Join-Path $fleetRoot ".codex-local\runs\$safeName\heartbeat.json"
    if (!(Test-Path -LiteralPath $heartbeatPath)) {
        return [pscustomobject]@{ classification = "missing"; active = $false; pid = 0; status = "missing"; lastHeartbeatAt = $null; lastProgressAt = $null; runShape = "none"; currentTaskSummary = ""; path = $heartbeatPath }
    }

    try {
        $heartbeat = Get-Content -LiteralPath $heartbeatPath -Raw | ConvertFrom-Json
        $pidValue = if ($null -ne $heartbeat.pid) { [int]$heartbeat.pid } else { 0 }
        $processActive = Test-RunStateProcessActive -ProcessId $pidValue
        $status = if ($null -ne $heartbeat.status) { [string]$heartbeat.status } else { "unknown" }
        $lastHeartbeatAt = ConvertTo-RunStateDateTime -Value $heartbeat.lastHeartbeatAt
        $lastProgressAt = ConvertTo-RunStateDateTime -Value $heartbeat.lastProgressAt
        $ageMinutes = if ($null -ne $lastHeartbeatAt) { ((Get-Date).ToUniversalTime() - $lastHeartbeatAt.ToUniversalTime()).TotalMinutes } else { [double]::PositiveInfinity }
        $progressAgeMinutes = if ($null -ne $lastProgressAt) { ((Get-Date).ToUniversalTime() - $lastProgressAt.ToUniversalTime()).TotalMinutes } else { [double]::PositiveInfinity }

        $classification = "stale"
        if ($status -eq "completed") {
            $classification = "completed"
        } elseif ($status -in @("parked", "stopped")) {
            $classification = "parked"
        } elseif (-not $processActive) {
            $classification = "stale"
        } elseif ($ageMinutes -gt 30) {
            $classification = "stalled"
        } elseif ($progressAgeMinutes -gt 15) {
            $classification = "idle"
        } else {
            $classification = "active"
        }

        $shape = "none"
        if ($null -ne $heartbeat.runShape) {
            $shapeBits = @()
            if ($null -ne $heartbeat.runShape.batchSize) { $shapeBits += "batch=$($heartbeat.runShape.batchSize)" }
            if ($null -ne $heartbeat.runShape.maxBatches) { $shapeBits += "maxBatches=$($heartbeat.runShape.maxBatches)" }
            if ($null -ne $heartbeat.runShape.maxRuntimeMinutes) { $shapeBits += "runtime=$($heartbeat.runShape.maxRuntimeMinutes)m" }
            if ($null -ne $heartbeat.runShape.maxCompletedTasks) { $shapeBits += "taskCap=$($heartbeat.runShape.maxCompletedTasks)" }
            if ($null -ne $heartbeat.runShape.loopPhase) { $shapeBits += "phase=$($heartbeat.runShape.loopPhase)" }
            if ($null -ne $heartbeat.runShape.quarantineFailedTasks) { $shapeBits += "quarantine=$($heartbeat.runShape.quarantineFailedTasks)" }
            if ($null -ne $heartbeat.runShape.pushCheckpoint) { $shapeBits += "push=$($heartbeat.runShape.pushCheckpoint)" }
            if ($shapeBits.Count -gt 0) { $shape = $shapeBits -join "," }
        }
        return [pscustomobject]@{
            classification = $classification
            active = ($classification -in @("active", "idle", "stalled"))
            pid = $pidValue
            status = $status
            lastHeartbeatAt = $lastHeartbeatAt
            lastProgressAt = $lastProgressAt
            runShape = $shape
            currentTaskSummary = if ($null -ne $heartbeat.currentTaskSummary) { [string]$heartbeat.currentTaskSummary } else { "" }
            path = $heartbeatPath
        }
    } catch {
        return [pscustomobject]@{ classification = "unreadable"; active = $false; pid = 0; status = "unreadable"; lastHeartbeatAt = $null; lastProgressAt = $null; runShape = "none"; currentTaskSummary = ""; path = $heartbeatPath }
    }
}

function Get-ProjectRunHeartbeatSummary {
    param([string]$ProjectName)

    $heartbeat = Get-ProjectRunHeartbeatState -ProjectName $ProjectName
    if ($heartbeat.classification -eq "missing") { return "no heartbeat" }
    $lastHeartbeatText = if ($null -ne $heartbeat.lastHeartbeatAt) { $heartbeat.lastHeartbeatAt.ToString("s") } else { "unknown" }
    $lastProgressText = if ($null -ne $heartbeat.lastProgressAt) { $heartbeat.lastProgressAt.ToString("s") } else { "unknown" }
    $task = if (![string]::IsNullOrWhiteSpace([string]$heartbeat.currentTaskSummary)) { "; task=$($heartbeat.currentTaskSummary)" } else { "" }
    return "$($heartbeat.classification); status=$($heartbeat.status); pid=$($heartbeat.pid); lastHeartbeat=$lastHeartbeatText; lastProgress=$lastProgressText; shape=$($heartbeat.runShape)$task"
}

function Get-BranchSyncSummary {
    param([string]$Branch)

    if ([string]::IsNullOrWhiteSpace($Branch)) { return "unknown" }
    $upstream = (git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($upstream)) {
        $upstream = "origin/$Branch"
    }
    git rev-parse --verify $upstream 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { return "no upstream ($upstream)" }

    $counts = (git rev-list --left-right --count "$upstream...HEAD" 2>$null)
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($counts)) { return "unknown vs $upstream" }
    $parts = @($counts -split "\s+")
    if ($parts.Count -lt 2) { return "unknown vs $upstream" }
    $behind = [int]$parts[0]
    $ahead = [int]$parts[1]
    return "ahead $ahead / behind $behind vs $upstream"
}

function Resolve-RunnerDisplayState {
    param(
        [object]$Heartbeat,
        [object]$Lock,
        [string]$Dirty,
        [int]$UncheckedCount
    )

    if ($null -ne $Lock -and $Lock.active) { return "RUNNING" }
    if ($null -ne $Heartbeat -and $Heartbeat.classification -in @("active", "idle")) { return "RUNNING" }
    if ($null -ne $Heartbeat -and $Heartbeat.classification -eq "stalled") { return "STALLED" }
    if ($Dirty -like "dirty*") { return "BLOCKED" }
    if ($null -ne $Heartbeat -and $Heartbeat.classification -in @("parked", "completed")) { return "PARKED" }
    if ($UncheckedCount -le 0) { return "PARKED" }
    return "READY"
}

function Get-ProjectSnapshotLines {
    param([object[]]$Projects)

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($ship in $Projects) {
        $name = [string]$ship.name
        $repo = [string]$ship.repo
        $lines.Add("### $name") | Out-Null
        if (!(Test-Path $repo)) {
            $lines.Add("- Repo: missing ($repo)") | Out-Null
            $lines.Add("") | Out-Null
            continue
        }

        Push-Location $repo
        try {
            $branch = (git branch --show-current 2>$null)
            $head = (git rev-parse --short HEAD 2>$null)
            if ($LASTEXITCODE -ne 0) { $head = "none" }
            $sync = Get-BranchSyncSummary -Branch $branch
            $status = @(git status --short 2>$null)
            $unchecked = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue)
            $firstTask = if ($unchecked.Count -gt 0) { ($unchecked[0].Line -replace "^\s*-\s+\[ \]\s+", "").Trim() } else { "" }
            $workflow = Get-TaskWorkflowSummary -Task $firstTask
            $phase = "unknown"
            if (Test-Path "docs/codex/PHASE_STATE.md") {
                $phaseText = Get-Content "docs/codex/PHASE_STATE.md" -Raw
                $phaseMatch = [regex]::Match($phaseText, "(?im)^\s*(?:Current phase|Phase)\s*:\s*(.+?)\s*$")
                if ($phaseMatch.Success) { $phase = $phaseMatch.Groups[1].Value.Trim() }
            }
            $dirty = if ($status.Count -eq 0) { "clean" } else { "dirty ($($status.Count) files)" }
            $heartbeat = Get-ProjectRunHeartbeatState -ProjectName $name
            $lock = Get-ProjectRunLockState -ProjectName $name
            $runnerState = Resolve-RunnerDisplayState -Heartbeat $heartbeat -Lock $lock -Dirty $dirty -UncheckedCount $unchecked.Count
            $runnerPid = if ($runnerState -eq "RUNNING") {
                if ($lock.active) { $lock.pid } elseif ($heartbeat.pid -gt 0) { $heartbeat.pid } else { 0 }
            } else {
                0
            }
            $lastHeartbeatText = if ($null -ne $heartbeat.lastHeartbeatAt) { $heartbeat.lastHeartbeatAt.ToString("s") } else { "none" }
            $lastProgressText = if ($null -ne $heartbeat.lastProgressAt) { $heartbeat.lastProgressAt.ToString("s") } else { "none" }
            $lines.Add("- Branch: $branch") | Out-Null
            $lines.Add("- HEAD: $head") | Out-Null
            $lines.Add("- Branch sync: $sync") | Out-Null
            $lines.Add("- Working tree: $dirty") | Out-Null
            $lines.Add("- Runner state: $runnerState") | Out-Null
            if ($runnerPid -gt 0) {
                $lines.Add("- Runner PID: $runnerPid") | Out-Null
            }
            $lockPidText = if ($lock.pid -gt 0) { " PID $($lock.pid)" } else { "" }
            $lines.Add("- Lock state: $($lock.state)$lockPidText") | Out-Null
            $lines.Add("- Run shape: $($heartbeat.runShape)") | Out-Null
            $lines.Add("- Last heartbeat: $lastHeartbeatText") | Out-Null
            $lines.Add("- Last progress: $lastProgressText") | Out-Null
            $lines.Add("- Unchecked tasks: $($unchecked.Count)") | Out-Null
            $lines.Add("- Phase: $phase") | Out-Null
            $lines.Add("- Next workflow: $workflow") | Out-Null
            if (![string]::IsNullOrWhiteSpace([string]$heartbeat.currentTaskSummary)) {
                $lines.Add("- Current task: $($heartbeat.currentTaskSummary)") | Out-Null
            }
            if ($status.Count -gt 0) {
                $changed = @($status | Select-Object -First 4)
                $lines.Add("- Changed: $($changed -join '; ')") | Out-Null
            }
        } finally {
            Pop-Location
        }
        $lines.Add("") | Out-Null
    }
    return @($lines)
}

function Get-SupervisorSummaryLines {
    param([object[]]$Projects)

    $reportPath = Join-Path $fleetRoot "out\fleet-supervisor.md"
    if (!(Test-Path $reportPath)) { return @() }
    $selectedNames = @($Projects | ForEach-Object { [string]$_.name })
    $lines = [System.Collections.Generic.List[string]]::new()
    $rows = @(Get-Content $reportPath | Where-Object { $_ -match "^\|\s*[^-]" })
    foreach ($row in $rows) {
        if ($row -match "^\|\s*Ship\s*\|") { continue }
        $cells = @($row.Trim("|").Split("|") | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 15) { continue }
        $ship = $cells[0]
        if ($selectedNames.Count -gt 0 -and $selectedNames -notcontains $ship) { continue }
        $lines.Add("- ${ship}: $($cells[1]); $($cells[5]); $($cells[6]); tasks $($cells[7]); lock $($cells[9]); $($cells[13])") | Out-Null
    }
    return @($lines)
}

function Rotate-StatusLog {
    param(
        [string]$StatusPath,
        [datetime]$Now,
        [int]$RetentionDays
    )

    $todayPath = Join-Path $StatusPath "today.md"
    $statePath = Join-Path (Resolve-ControlPath $StateRoot) "heartbeat.json"
    $heartbeat = Read-JsonFile -Path $statePath
    $currentDate = $Now.ToString("yyyy-MM-dd")
    $lastDate = if ($null -ne $heartbeat -and $null -ne $heartbeat.reportDate) { [string]$heartbeat.reportDate } else { "" }

    if ($lastDate -ne "" -and $lastDate -ne $currentDate -and (Test-Path $todayPath)) {
        $archivePath = Join-Path (Join-Path $StatusPath "archive") "$lastDate.md"
        if (!$DryRun) {
            Copy-Item -LiteralPath $todayPath -Destination $archivePath -Force
            Set-Content -Path $todayPath -Encoding UTF8 -Value @("# Fleet Today", "", "Date: $currentDate", "")
        }
    } elseif (!(Test-Path $todayPath) -and !$DryRun) {
        Set-Content -Path $todayPath -Encoding UTF8 -Value @("# Fleet Today", "", "Date: $currentDate", "")
    }

    $archiveRoot = Join-Path $StatusPath "archive"
    if (Test-Path $archiveRoot) {
        $cutoff = $Now.Date.AddDays(-1 * $RetentionDays)
        Get-ChildItem -Path $archiveRoot -Filter "*.md" -File -ErrorAction SilentlyContinue | Where-Object {
            $_.BaseName -match "^\d{4}-\d{2}-\d{2}$" -and ([datetime]::ParseExact($_.BaseName, "yyyy-MM-dd", $null) -lt $cutoff)
        } | ForEach-Object {
            if ($DryRun) {
                Write-Host "DRY RUN: prune archive $($_.FullName)"
            } else {
                Remove-Item -LiteralPath $_.FullName -Force
            }
        }
    }
}

function Invoke-SupervisorOnce {
    param(
        [string[]]$RequestedProjects,
        [string[]]$ExcludedProjects,
        [bool]$AllowMutation = $false
    )

    $args = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", (Join-Path $fleetRoot "fleet-supervisor.ps1"), "-Once")
    if (!$AllowMutation) {
        $args += "-ObservationOnly"
    }
    $requested = @($RequestedProjects | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($requested.Count -gt 0) {
        $args += @("-Project", ($requested -join ","))
    }
    $excluded = @($ExcludedProjects | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($excluded.Count -gt 0) {
        $args += @("-ExcludeProject", ($excluded -join ","))
    }

    if ($DryRun) {
        Write-Host "DRY RUN: powershell $($args -join ' ')"
        return [pscustomobject]@{ exitCode = 0; output = @("dry run") }
    }

    return Invoke-FleetProcess -FilePath "powershell" -Arguments $args -WorkingDirectory $fleetRoot -TimeoutSeconds $SupervisorTimeoutSeconds
}

function Write-RemoteStatus {
    param(
        [string]$StatusPath,
        [string]$StatePath,
        [datetime]$Now,
        [object[]]$Projects,
        [string]$FleetMode,
        [string]$MissionHash,
        [bool]$MissionAccepted,
        [bool]$MissionQuiet,
        [bool]$EmergencyStop,
        [object]$SupervisorResult
    )

    $currentPath = Join-Path $StatusPath "current.md"
    $todayPath = Join-Path $StatusPath "today.md"
    $branch = Get-GitValue -Arguments @("branch", "--show-current")
    $head = Get-GitValue -Arguments @("rev-parse", "--short", "HEAD")
    $missionShort = if ($MissionHash.Length -gt 12) { $MissionHash.Substring(0, 12) } else { $MissionHash }
    $supervisorExit = if ($null -ne $SupervisorResult) { [string]$SupervisorResult.exitCode } else { "not run" }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# Fleet Remote Status") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("- Updated: $($Now.ToString("yyyy-MM-dd HH:mm:ss")) $TimeZoneId") | Out-Null
    $lines.Add("- Fleet mode: $FleetMode") | Out-Null
    $lines.Add("- Mission hash: $missionShort") | Out-Null
    $lines.Add("- Mission update: $(if ($MissionAccepted) { "accepted" } elseif ($MissionQuiet) { "quiet-hours deferred" } else { "unchanged" })") | Out-Null
    $lines.Add("- Emergency stop: $(if ($EmergencyStop) { "requested" } else { "none" })") | Out-Null
    $lines.Add("- Supervisor cycle: $supervisorExit") | Out-Null
    $lines.Add("- Fleet branch: $branch") | Out-Null
    $lines.Add("- Fleet HEAD: $head") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("## Projects") | Out-Null
    foreach ($projectLine in @(Get-ProjectSnapshotLines -Projects $Projects)) {
        $lines.Add([string]$projectLine) | Out-Null
    }
    $supervisorLines = @(Get-SupervisorSummaryLines -Projects $Projects)
    if ($supervisorLines.Count -gt 0 -and $supervisorExit -ne "not run") {
        $lines.Add("## Supervisor Summary") | Out-Null
        foreach ($supervisorLine in $supervisorLines) {
            $lines.Add([string]$supervisorLine) | Out-Null
        }
        $lines.Add("") | Out-Null
    }
    $lines.Add("## Controls") | Out-Null
    $lines.Add('- Edit `fleet/control/mission.md` to change mission goals.') | Out-Null
    $lines.Add('- Edit `fleet/control/run-mode.json` to pause, resume, or change active projects.') | Out-Null
    $lines.Add('- Set `Emergency: STOP_ALL` in `fleet/control/emergency.md` for an all-hours cooperative stop.') | Out-Null

    if (!$DryRun) {
        Set-Content -Path $currentPath -Encoding UTF8 -Value $lines
        Add-Content -Path $todayPath -Encoding UTF8 -Value @(
            "",
            "## $($Now.ToString("HH:mm"))",
            "",
            "- Fleet mode: $FleetMode",
            "- Mission: $missionShort ($(if ($MissionAccepted) { "accepted" } elseif ($MissionQuiet) { "deferred" } else { "unchanged" }))",
            "- Emergency: $(if ($EmergencyStop) { "STOP_ALL" } else { "none" })",
            "- Supervisor: $supervisorExit",
            "- Projects: $((@($Projects | ForEach-Object { [string]$_.name })) -join ', ')"
        )
    }

    Write-JsonFile -Path (Join-Path $StatePath "heartbeat.json") -Value ([pscustomobject]@{
        updatedAt = $Now.ToString("o")
        reportDate = $Now.ToString("yyyy-MM-dd")
        fleetMode = $FleetMode
        missionHash = $MissionHash
        emergencyStop = $EmergencyStop
        supervisorExitCode = $supervisorExit
        branch = $branch
        head = $head
    })
}

function Publish-RemoteStatus {
    param(
        [string]$StatusPath,
        [string]$StatePath
    )

    $remote = Get-GitValue -Arguments @("remote")
    if ([string]::IsNullOrWhiteSpace($remote)) {
        Write-Host "No git remote configured; skipping publish." -ForegroundColor Yellow
        return
    }

    $paths = @(
        (Join-Path $StatusPath "current.md"),
        (Join-Path $StatusPath "today.md"),
        (Join-Path $StatusPath "archive"),
        (Join-Path $StatePath "heartbeat.json"),
        (Join-Path $StatePath "last-applied-mission.json")
    )
    Invoke-GitStep -Name "git add" -Arguments (@("add", "--") + $paths) | Out-Null
    $staged = Get-GitValue -Arguments @("diff", "--cached", "--name-only")
    if ([string]::IsNullOrWhiteSpace($staged)) {
        Write-Host "No status changes to publish."
        return
    }

    $stamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
    $commitExit = Invoke-GitStep -Name "git commit" -Arguments @("commit", "-m", "Fleet remote status $stamp") -TimeoutSeconds 120
    if ($commitExit -ne 0) { return }
    $branch = Get-GitValue -Arguments @("branch", "--show-current")
    Invoke-GitStep -Name "git push" -Arguments @("push", "origin", $branch) -TimeoutSeconds 180 | Out-Null
}

$controlPath = Resolve-ControlPath $ControlRoot
$statusPath = Resolve-ControlPath $StatusRoot
$statePath = Resolve-ControlPath $StateRoot
$lockPath = ""

if ($ValidateHeartbeatOnly) {
    $names = @(ConvertTo-NameList -Values $Project)
    if ($names.Count -eq 0) { $names = @("HarnessHeartbeat") }
    foreach ($name in $names) {
        Write-Host "$name runner: $(Get-ProjectRunHeartbeatSummary -ProjectName $name)"
    }
    Write-Host "Remote status heartbeat validation complete."
    exit 0
}

if ($ValidateStatusSnapshotOnly) {
    if (!(Test-Path -LiteralPath $ConfigPath)) {
        Stop-WithMessage "Config not found: $ConfigPath"
    }
    $runModeForSnapshot = if (Test-Path (Join-Path $controlPath "run-mode.json")) { Get-Content (Join-Path $controlPath "run-mode.json") -Raw | ConvertFrom-Json } else { $null }
    $selectedForSnapshot = @(Get-SelectedProjects -ConfigFile $ConfigPath -RequestedProjects $Project -ExcludedProjects $ExcludeProject -RunMode $runModeForSnapshot -IncludeAllProjects ([bool]$AllProjects))
    foreach ($line in @(Get-ProjectSnapshotLines -Projects $selectedForSnapshot)) {
        Write-Host $line
    }
    Write-Host "Remote status snapshot validation complete."
    exit 0
}

if ($ValidateLockCleanupOnly) {
    $names = @(ConvertTo-NameList -Values $Project)
    if ($names.Count -eq 0) { $names = @("HarnessDeadLock") }
    foreach ($name in $names) {
        $state = Get-ProjectRunLockState -ProjectName $name
        Write-Host "$name lock: state=$($state.state); active=$($state.active); pid=$($state.pid); path=$($state.path)"
    }
    Write-Host "Remote status lock cleanup validation complete."
    exit 0
}

try {
    Initialize-RemoteControlFiles -ControlPath $controlPath -StatusPath $statusPath -StatePath $statePath
    $lockPath = Acquire-RemoteControlLock

    if ($Publish -and !$SkipPull) {
        Invoke-GitStep -Name "git pull" -Arguments @("pull", "--ff-only") -TimeoutSeconds 180 | Out-Null
    }

    $now = Get-ControlNow -WindowsTimeZoneId $TimeZoneId
    Rotate-StatusLog -StatusPath $statusPath -Now $now -RetentionDays $ArchiveRetentionDays

    $runMode = Read-JsonFile -Path (Join-Path $controlPath "run-mode.json")
    $fleetMode = if ($null -ne $runMode -and $null -ne $runMode.fleetMode) { [string]$runMode.fleetMode } else { "PAUSED" }
    $selectedProjects = @(Get-SelectedProjects -ConfigFile $ConfigPath -RequestedProjects $Project -ExcludedProjects $ExcludeProject -RunMode $runMode -IncludeAllProjects ([bool]$AllProjects))

    $missionPath = Join-Path $controlPath "mission.md"
    $missionText = if (Test-Path $missionPath) { Get-Content $missionPath -Raw } else { "" }
    $missionHash = Get-TextSha256 -Text $missionText
    $lastMissionPath = Join-Path $statePath "last-applied-mission.json"
    $lastMission = Read-JsonFile -Path $lastMissionPath
    $lastMissionHash = if ($null -ne $lastMission -and $null -ne $lastMission.hash) { [string]$lastMission.hash } else { "" }
    $missionQuiet = Test-HourWindow -Hour $now.Hour -StartHour $MissionQuietStartHour -EndHour $MissionQuietEndHour
    $missionAccepted = $false

    $emergencyPath = Join-Path $controlPath "emergency.md"
    $emergencyText = if (Test-Path $emergencyPath) { Get-Content $emergencyPath -Raw } else { "" }
    $emergencyStop = ($emergencyText -match "(?im)^\s*Emergency\s*:\s*STOP_ALL\s*$")

    if ($emergencyStop) {
        Request-ProjectSafeStop -Projects $selectedProjects
    }

    if ($missionHash -ne $lastMissionHash -and !$missionQuiet) {
        $missionAccepted = $true
        Write-JsonFile -Path $lastMissionPath -Value ([pscustomobject]@{
            hash = $missionHash
            appliedAt = $now.ToString("o")
            appliedFromHead = Get-GitValue -Arguments @("rev-parse", "--short", "HEAD")
            fleetMode = $fleetMode
        })
    }

    $reportAllowed = Test-HourWindow -Hour $now.Hour -StartHour $ReportStartHour -EndHour $ReportEndHour
    $shouldReport = $ForceReport -or $reportAllowed -or $RotateOnly
    $supervisorResult = $null
    if (!$RotateOnly -and $RunSupervisor -and !$DryRun) {
        $supervisorProjectNames = @($selectedProjects | ForEach-Object { [string]$_.name })
        $supervisorResult = Invoke-SupervisorOnce -RequestedProjects $supervisorProjectNames -ExcludedProjects $ExcludeProject -AllowMutation ([bool]$AllowRepairLaunch)
    } elseif ($RunSupervisor -and $DryRun) {
        $supervisorProjectNames = @($selectedProjects | ForEach-Object { [string]$_.name })
        $supervisorResult = Invoke-SupervisorOnce -RequestedProjects $supervisorProjectNames -ExcludedProjects $ExcludeProject -AllowMutation ([bool]$AllowRepairLaunch)
    }

    if ($shouldReport) {
        Write-RemoteStatus -StatusPath $statusPath -StatePath $statePath -Now $now -Projects $selectedProjects -FleetMode $fleetMode -MissionHash $missionHash -MissionAccepted $missionAccepted -MissionQuiet $missionQuiet -EmergencyStop $emergencyStop -SupervisorResult $supervisorResult
    } else {
        Write-Host "Outside report window; rotated/pruned state only."
    }

    if ($Publish -and $shouldReport) {
        Publish-RemoteStatus -StatusPath $statusPath -StatePath $statePath
    }

    Write-Host "Remote control cycle complete." -ForegroundColor Green
} finally {
    Release-RemoteControlLock -LockPath $lockPath
}
