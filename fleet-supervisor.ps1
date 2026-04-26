[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string[]]$ExcludeProject = @(),

    [int]$IntervalSeconds = 300,

    [string]$OutFile = "out\fleet-supervisor.md",

    [string]$DigestOutFile = "out\fleet-overnight-digest.md",

    [int]$IdleMinutes = 45,

    [int]$MaxTaskCommits = 24,

    [int]$MaxQuarantines = 5,

    [int]$MaxQualityStops = 3,

    [switch]$AutoSafeStop,

    [string[]]$AutoSafeStopStates = @("BUDGET_STOP", "LOOPING_QUALITY", "IDLE_RUNNING", "BLOCKED_REVIEW"),

    [switch]$AutoRepair,

    [string[]]$AutoRepairStates = @("BUDGET_STOP", "LOOPING_QUALITY", "IDLE_READY"),

    [switch]$ClearSafeStopAfterRepair,

    [switch]$AutoRelaunchRepair,

    [int]$RepairBatchSize = 1,

    [int]$RepairMaxBatches = 1,

    [switch]$Once
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Get-FirstMarkdownValue {
    param(
        [string]$Path,
        [string]$Heading
    )

    if (!(Test-Path $Path)) {
        return "missing"
    }

    $text = Get-Content $Path -Raw
    $pattern = "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n\s*([^\r\n#]+)"
    $match = [regex]::Match($text, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return "unknown"
}

function Get-UncheckedCount {
    if (!(Test-Path "docs/codex/TASK_QUEUE.md")) {
        return 0
    }

    return @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue).Count
}

function Get-LastReportLine {
    if (!(Test-Path "docs/codex/NIGHTLY_REPORT.md")) {
        return "No nightly report yet."
    }

    $lines = @(Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 60 | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -eq 0) {
        return "Nightly report is empty."
    }

    return ($lines | Select-Object -Last 1)
}

function Get-ActiveWorkPack {
    if (!(Test-Path "docs/codex/WORK_PACK_STATUS.md")) {
        return "missing"
    }

    $text = Get-Content "docs/codex/WORK_PACK_STATUS.md" -Raw
    $activeLine = [regex]::Match($text, "(?im)^-\s*(Pack\s+\d+\s+-\s+[^:]+):\s*ACTIVE\s*$")
    if ($activeLine.Success) {
        return $activeLine.Groups[1].Value.Trim()
    }

    $activeHeading = [regex]::Match($text, "(?ims)^##\s+Active Work Pack\s*\r?\n\s*(Pack\s+\d+\s+-\s+[^\r\n]+)")
    if ($activeHeading.Success) {
        return $activeHeading.Groups[1].Value.Trim()
    }

    return "unknown"
}

function Get-SimonImprovementScore {
    if (!(Test-Path "docs/codex/SIMON_DESIGN_REVIEW.md")) {
        return "missing"
    }

    $text = Get-Content "docs/codex/SIMON_DESIGN_REVIEW.md" -Raw
    $section = [regex]::Match($text, "(?ims)^##\s+Magic Improvement Score\s*\r?\n(.+?)(?=^##\s+|\z)")
    if ($section.Success) {
        $line = (($section.Groups[1].Value -split "\r?\n") | Where-Object { ![string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
        if (![string]::IsNullOrWhiteSpace($line)) {
            return $line.Trim().Replace("|", "/")
        }
    }

    return "not-scored"
}

function Get-LatestQualityQuarantine {
    if (!(Test-Path "docs/codex/QUALITY_QUARANTINE.md")) {
        return ""
    }

    $text = Get-Content "docs/codex/QUALITY_QUARANTINE.md" -Raw
    $sections = [regex]::Matches($text, "(?ims)^##\s+(.+?)\r?\n(.+?)(?=^##\s+|\z)")
    if ($sections.Count -eq 0) {
        return "quality quarantine present"
    }

    $last = $sections[$sections.Count - 1]
    $reason = [regex]::Match($last.Groups[2].Value, "(?im)^-\s+Reason:\s*(.+)$")
    if ($reason.Success) {
        return $reason.Groups[1].Value.Trim().Replace("|", "/")
    }

    return "quality quarantine present"
}

function Get-CountSince {
    param(
        [string]$Path,
        [string]$Pattern,
        [datetime]$Since
    )

    if (!(Test-Path $Path)) {
        return 0
    }

    $text = Get-Content $Path -Raw
    $sections = [regex]::Matches($text, "(?ims)^##\s+([0-9]{4}-[0-9]{2}-[0-9]{2}\s+[0-9]{2}:[0-9]{2}:[0-9]{2}).*?(?=^##\s+|\z)")
    $count = 0
    foreach ($section in $sections) {
        $date = [datetime]::MinValue
        if ([datetime]::TryParse($section.Groups[1].Value, [ref]$date) -and $date -ge $Since -and $section.Value -match $Pattern) {
            $count++
        }
    }
    return $count
}

function Get-RunLockStatus {
    param([string]$ProjectName)

    $safeName = ([string]$ProjectName) -replace "[^a-zA-Z0-9_.-]+", "-"
    $safeName = $safeName.Trim("-")
    $lockPath = Join-Path $fleetRoot ".codex-local\locks\$safeName.lock.json"
    if (!(Test-Path -LiteralPath $lockPath)) {
        return [pscustomobject]@{ text = "none"; active = $false; stale = $false; path = "" }
    }

    try {
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        $pidValue = [int]$lock.pid
        if ($pidValue -gt 0 -and (Get-Process -Id $pidValue -ErrorAction SilentlyContinue)) {
            return [pscustomobject]@{ text = "active PID $pidValue"; active = $true; stale = $false; path = $lockPath }
        }
        return [pscustomobject]@{ text = "stale PID $pidValue"; active = $false; stale = $true; path = $lockPath }
    } catch {
        return [pscustomobject]@{ text = "unreadable"; active = $false; stale = $true; path = $lockPath }
    }
}

function ConvertTo-FleetSafeStopName {
    param([string]$Name)

    $safeName = if ([string]::IsNullOrWhiteSpace($Name)) { "ALL" } else { ([string]$Name) -replace "[^a-zA-Z0-9_-]+", "-" }
    $safeName = $safeName.Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeName)) { return "ALL" }
    return $safeName
}

function Request-FleetSafeStop {
    param(
        [string]$ProjectName,
        [string]$Reason
    )

    $stopRoot = Join-Path $fleetRoot ".codex-local\stop-requests"
    New-Item -ItemType Directory -Force -Path $stopRoot | Out-Null
    $safeName = ConvertTo-FleetSafeStopName -Name $ProjectName
    $stopPath = Join-Path $stopRoot "$safeName.stop.json"
    if (Test-Path -LiteralPath $stopPath) {
        return $stopPath
    }

    $request = [pscustomobject]@{
        target = $ProjectName
        requestedAt = (Get-Date).ToString("o")
        user = $env:USERNAME
        machine = $env:COMPUTERNAME
        behavior = "Stop before the next task/batch boundary. Do not kill in-progress Codex/build/review work."
        reason = $Reason
        source = "fleet-supervisor"
    }
    $request | ConvertTo-Json -Depth 4 | Set-Content -Path $stopPath -Encoding UTF8
    return $stopPath
}

function Get-FleetSafeStopPath {
    param([string]$ProjectName)

    $stopRoot = Join-Path $fleetRoot ".codex-local\stop-requests"
    $safeName = ConvertTo-FleetSafeStopName -Name $ProjectName
    return Join-Path $stopRoot "$safeName.stop.json"
}

function Clear-FleetSafeStop {
    param([string]$ProjectName)

    $stopPath = Get-FleetSafeStopPath -ProjectName $ProjectName
    if (Test-Path -LiteralPath $stopPath) {
        Remove-Item -LiteralPath $stopPath -Force
    }
}

function New-AutoRepairTaskLine {
    param([object]$Row)

    $pack = if ([string]::IsNullOrWhiteSpace([string]$Row.activePack) -or [string]$Row.activePack -eq "missing") { "the active work pack" } else { [string]$Row.activePack }
    $reason = ([string]$Row.recommendation).Trim()
    if ([string]::IsNullOrWhiteSpace($reason)) { $reason = "repair the current supervisor finding" }
    return "- [ ] Auto repair for $($Row.state) in ${pack}: inspect the latest MAGIC_SCORECARD, QUALITY_QUARANTINE, Simon, Robin, Visual, and nightly report notes, then make exactly one smallest user-visible repair that addresses '$reason'; prefer reducing churn over adding features; preserve existing behavior and avoid backend, secrets, package/dependency files, deployment config, generated output, broad rewrites, and unrelated files. [class:design risk:low mode:single scope:src/,app-vNext/src/,css/,js/,wine.html,index.html]"
}

function Add-SupervisorAutoRepairTask {
    param([object]$Row)

    if ($Row.dirty -ne "clean" -or $Row.lockActive) {
        return [pscustomobject]@{ added = $false; reason = "ship is active or dirty"; task = "" }
    }
    if (!($AutoRepairStates -contains [string]$Row.state)) {
        return [pscustomobject]@{ added = $false; reason = "state is not auto-repairable"; task = "" }
    }

    $taskQueue = "docs/codex/TASK_QUEUE.md"
    New-Item -ItemType Directory -Force -Path "docs/codex" | Out-Null
    if (!(Test-Path $taskQueue)) {
        "# Codex Task Queue`n" | Set-Content -Path $taskQueue
    }

    $queueText = Get-Content $taskQueue -Raw
    if ($queueText -match "(?im)^\s*-\s+\[ \]\s+Auto repair for ") {
        return [pscustomobject]@{ added = $false; reason = "unchecked auto-repair task already exists"; task = "" }
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $taskLine = New-AutoRepairTaskLine -Row $Row
    $sectionText = @(
        "## Supervisor Auto Repair $timestamp",
        "",
        $taskLine,
        ""
    ) -join "`r`n"
    $queueText = Get-Content $taskQueue -Raw
    $newQueueText = "$sectionText`r`n$queueText"
    Set-Content -Path $taskQueue -Value $newQueueText -NoNewline

    $repairLog = "docs/codex/AUTO_REPAIR.md"
    $repairLines = @(
        "",
        "## $timestamp",
        "",
        "- State: $($Row.state)",
        "- Budget: $($Row.budget)",
        "- Recommendation: $($Row.recommendation)",
        "- Task: $taskLine"
    )
    if (!(Test-Path $repairLog)) {
        "# Fleet Auto Repair`n" | Set-Content -Path $repairLog
    }
    Add-Content -Path $repairLog -Value $repairLines

    git add docs/codex/TASK_QUEUE.md docs/codex/AUTO_REPAIR.md | Out-Null
    git commit -m "Codex supervisor auto repair task" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        return [pscustomobject]@{ added = $false; reason = "auto-repair commit failed"; task = $taskLine }
    }

    if ($ClearSafeStopAfterRepair) {
        Clear-FleetSafeStop -ProjectName ([string]$Row.ship)
    }

    return [pscustomobject]@{ added = $true; reason = "repair task committed"; task = $taskLine }
}

function Test-UncheckedAutoRepairTask {
    $taskQueue = "docs/codex/TASK_QUEUE.md"
    if (!(Test-Path $taskQueue)) { return $false }
    return [bool](Select-String -Path $taskQueue -Pattern "^\s*-\s+\[ \]\s+Auto repair for " -Quiet)
}

function Start-SupervisorRepairRun {
    param([object]$Row)

    if ($Row.dirty -ne "clean" -or $Row.lockActive) {
        return [pscustomobject]@{ launched = $false; reason = "ship is active or dirty"; pid = 0; command = "" }
    }
    if (-not (Test-UncheckedAutoRepairTask)) {
        return [pscustomobject]@{ launched = $false; reason = "no unchecked auto-repair task"; pid = 0; command = "" }
    }

    Clear-FleetSafeStop -ProjectName ([string]$Row.ship)
    $scriptPath = Join-Path $fleetRoot "run-checkpoint-loop.ps1"
    $repairLogRoot = Join-Path $fleetRoot "out\repair-runs"
    New-Item -ItemType Directory -Force -Path $repairLogRoot | Out-Null
    $safeShip = ([string]$Row.ship) -replace "[^a-zA-Z0-9_.-]+", "-"
    $safeShip = $safeShip.Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeShip)) { $safeShip = "ship" }
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $stdoutPath = Join-Path $repairLogRoot "$safeShip-$stamp.out.log"
    $stderrPath = Join-Path $repairLogRoot "$safeShip-$stamp.err.log"
    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $scriptPath,
        "-Project", ([string]$Row.ship),
        "-BatchSize", ([string]$RepairBatchSize),
        "-MaxBatches", ([string]$RepairMaxBatches),
        "-VisualInspectEvery", "1",
        "-SimonEvery", "1",
        "-RobinEvery", "1",
        "-JoeyEvery", "1",
        "-ContinueOnYellowCheckpoint",
        "-MaxTaskQuarantines", "1",
        "-QuarantineFailedTasks"
    )
    $command = "powershell $($args -join ' ')"
    $process = Start-Process powershell -WorkingDirectory $fleetRoot -WindowStyle Hidden -ArgumentList $args -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru

    $deadline = (Get-Date).AddSeconds(12)
    do {
        Start-Sleep -Seconds 1
        $lockStatus = Get-RunLockStatus -ProjectName ([string]$Row.ship)
        if ($lockStatus.active) {
            return [pscustomobject]@{ launched = $true; reason = "repair run launched"; pid = $process.Id; command = $command; stdout = $stdoutPath; stderr = $stderrPath }
        }
        $process.Refresh()
    } while ((Get-Date) -lt $deadline -and !$process.HasExited)

    return [pscustomobject]@{ launched = $false; reason = "repair run did not acquire an active lock; inspect $stdoutPath and $stderrPath"; pid = $process.Id; command = $command; stdout = $stdoutPath; stderr = $stderrPath }
}

function Get-LastProgressTime {
    $candidates = @()
    foreach ($path in @("docs/codex/NIGHTLY_REPORT.md", "docs/codex/MAGIC_SCORECARD.md", "docs/codex/QUALITY_QUARANTINE.md", "docs/codex/QUARANTINED_TASKS.md")) {
        if (Test-Path $path) {
            $candidates += (Get-Item $path).LastWriteTime
        }
    }

    $latestCommitTime = git log -1 --format=%cI 2>$null
    if (![string]::IsNullOrWhiteSpace($latestCommitTime)) {
        try { $candidates += [datetime]::Parse($latestCommitTime) } catch {}
    }

    if ($candidates.Count -eq 0) {
        return [datetime]::MinValue
    }

    return ($candidates | Sort-Object -Descending | Select-Object -First 1)
}

function Resolve-SupervisorState {
    param([object]$Row)

    if ($Row.dirty -ne "clean") {
        if (!$Row.lockActive) { return "BLOCKED_DIRTY" }
    }
    if ($Row.budget -match "^OVER") {
        return "BUDGET_STOP"
    }
    if (![string]::IsNullOrWhiteSpace($Row.qualityQuarantine)) {
        return "LOOPING_QUALITY"
    }
    if ($Row.dirty -ne "clean") {
        if ($Row.lockActive) { return "PROGRESSING" }
        return "BLOCKED_DIRTY"
    }
    if ($Row.checkpoint -match "RED" -or $Row.robin -match "RED" -or $Row.joey -match "RED") {
        return "BLOCKED_REVIEW"
    }
    if ($Row.lockActive) {
        if ($Row.minutesSinceProgress -ge $IdleMinutes) { return "IDLE_RUNNING" }
        return "PROGRESSING"
    }
    if ($Row.tasks -gt 0) {
        return "READY"
    }
    return "IDLE_READY"
}

function Get-Recommendation {
    param([object]$Row)

    switch -Regex ($Row.state) {
        "PROGRESSING" { return "let it run" }
        "IDLE_RUNNING" { return "check latest log, then request safe stop if unchanged" }
        "IDLE_READY" { return "planner will need to generate tasks" }
        "^READY$" { return "eligible for launch" }
        "BLOCKED_DIRTY" { return "do not touch unless rescue is approved" }
        "BLOCKED_REVIEW" { return "human review before more tasks" }
        "LOOPING_QUALITY" { return "repair active pack before fresh work" }
        "BUDGET_STOP" { return "pause ship and inspect results" }
        default { return "inspect" }
    }
}

function Write-SupervisorReport {
    if (!(Test-Path $ConfigPath)) {
        Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
        exit 1
    }

    $parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
    }
    $exclude = @($ExcludeProject | ForEach-Object { ([string]$_) -split "," } | ForEach-Object { [string]$_.Trim() } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($exclude.Count -gt 0) {
        $projects = @($projects | Where-Object { $exclude -notcontains [string]$_.name })
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $since = (Get-Date).AddHours(-12)
    $rows = @()
    $safeStopsRequested = @()
    $repairsQueued = @()
    $repairLaunches = @()
    $repairLaunchFailures = @()
    $lines = @(
        "# Codex Fleet Supervisor",
        "",
        "Generated: $timestamp",
        "Window: last 12 hours",
        "Budgets: task commits <= $MaxTaskCommits, task quarantines <= $MaxQuarantines, quality stops <= $MaxQualityStops",
        "",
        "| Ship | State | Branch | HEAD | Dirty | Tasks | Lock | Active Pack | Simon Score | Budget | Recommendation | Last Report |",
        "| --- | --- | --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- |"
    )

    foreach ($project in $projects) {
        if (!(Test-Path $project.repo)) {
            $rows += [pscustomobject]@{
                ship = $project.name; state = "BLOCKED_MISSING"; branch = "missing repo"; head = "n/a"; dirty = "n/a"; tasks = 0; lock = "n/a"; activePack = "missing"; simonScore = "missing"; budget = "n/a"; recommendation = "repo not found"; report = $project.repo
            }
            continue
        }

        Push-Location $project.repo
        $branch = (git branch --show-current 2>$null)
        $head = (git rev-parse --short HEAD 2>$null)
        if ([string]::IsNullOrWhiteSpace($head)) { $head = "none" }
        $dirty = @(git status --short 2>$null)
        $dirtyText = if ($dirty.Count -eq 0) { "clean" } else { "dirty $($dirty.Count)" }
        $tasks = Get-UncheckedCount
        $checkpoint = Get-FirstMarkdownValue -Path "docs/codex/CHECKPOINT_REVIEW.md" -Heading "Verdict"
        $simon = Get-FirstMarkdownValue -Path "docs/codex/SIMON_DESIGN_REVIEW.md" -Heading "Verdict"
        $robin = Get-FirstMarkdownValue -Path "docs/codex/ROBIN_COPY_REVIEW.md" -Heading "Verdict"
        $joey = Get-FirstMarkdownValue -Path "docs/codex/JOEY_SECURITY_REVIEW.md" -Heading "Verdict"
        $activePack = Get-ActiveWorkPack
        $simonScore = Get-SimonImprovementScore
        $qualityQuarantine = Get-LatestQualityQuarantine
        $taskCommits = @(git log --since="$($since.ToString("o"))" --oneline --grep="Codex checkpoint batch" 2>$null).Count
        $taskQuarantines = Get-CountSince -Path "docs/codex/QUARANTINED_TASKS.md" -Pattern "Reason:" -Since $since
        $qualityStops = Get-CountSince -Path "docs/codex/QUALITY_QUARANTINE.md" -Pattern "Reason:" -Since $since
        $budgetProblems = @()
        if ($taskCommits -gt $MaxTaskCommits) { $budgetProblems += "commits $taskCommits/$MaxTaskCommits" }
        if ($taskQuarantines -gt $MaxQuarantines) { $budgetProblems += "quarantines $taskQuarantines/$MaxQuarantines" }
        if ($qualityStops -gt $MaxQualityStops) { $budgetProblems += "quality $qualityStops/$MaxQualityStops" }
        $budget = if ($budgetProblems.Count -gt 0) { "OVER: $($budgetProblems -join ', ')" } else { "OK: commits $taskCommits, quarantines $taskQuarantines, quality $qualityStops" }
        $lastProgress = Get-LastProgressTime
        $minutesSinceProgress = if ($lastProgress -eq [datetime]::MinValue) { 999999 } else { [int]((Get-Date) - $lastProgress).TotalMinutes }
        $lastReport = (Get-LastReportLine).Replace("|", "/")
        Pop-Location

        $lockStatus = Get-RunLockStatus -ProjectName ([string]$project.name)
        $row = [pscustomobject]@{
            ship = $project.name
            branch = $branch
            head = $head
            dirty = $dirtyText
            tasks = $tasks
            lock = $lockStatus.text
            lockActive = $lockStatus.active
            activePack = $activePack
            simonScore = $simonScore
            qualityQuarantine = $qualityQuarantine
            checkpoint = $checkpoint
            simon = $simon
            robin = $robin
            joey = $joey
            budget = $budget
            minutesSinceProgress = $minutesSinceProgress
            report = $lastReport
        }
        $row | Add-Member -NotePropertyName state -NotePropertyValue (Resolve-SupervisorState -Row $row)
        $row | Add-Member -NotePropertyName recommendation -NotePropertyValue (Get-Recommendation -Row $row)
        if ($AutoSafeStop -and $row.lockActive -and ($AutoSafeStopStates -contains [string]$row.state)) {
            $reason = "$($row.state): $($row.recommendation)"
            $stopPath = Request-FleetSafeStop -ProjectName ([string]$row.ship) -Reason $reason
            $safeStopsRequested += [pscustomobject]@{ ship = $row.ship; state = $row.state; path = $stopPath; reason = $reason }
            $row.recommendation = "safe stop requested; inspect before relaunch"
        }
        if ($AutoRepair) {
            Push-Location $project.repo
            $repairResult = Add-SupervisorAutoRepairTask -Row $row
            Pop-Location
            if ($repairResult.added) {
                $repairsQueued += [pscustomobject]@{ ship = $row.ship; state = $row.state; task = $repairResult.task }
                $row.tasks = $row.tasks + 1
                $row.recommendation = "auto-repair task queued"
            }
        }
        if ($AutoRelaunchRepair) {
            Push-Location $project.repo
            $repairLaunch = Start-SupervisorRepairRun -Row $row
            Pop-Location
            if ($repairLaunch.launched) {
                $repairLaunches += [pscustomobject]@{ ship = $row.ship; state = $row.state; pid = $repairLaunch.pid; command = $repairLaunch.command; stdout = $repairLaunch.stdout; stderr = $repairLaunch.stderr }
                $row.lock = "launched PID $($repairLaunch.pid)"
                $row.lockActive = $true
                $row.recommendation = "repair batch relaunched"
            } elseif (![string]::IsNullOrWhiteSpace([string]$repairLaunch.reason) -and [string]$repairLaunch.reason -ne "ship is active or dirty" -and [string]$repairLaunch.reason -ne "no unchecked auto-repair task") {
                $repairLaunchFailures += [pscustomobject]@{ ship = $row.ship; state = $row.state; reason = $repairLaunch.reason; pid = $repairLaunch.pid; stdout = $repairLaunch.stdout; stderr = $repairLaunch.stderr }
                $row.recommendation = "repair relaunch failed; inspect repair run logs"
            }
        }
        $rows += $row
    }

    foreach ($row in $rows) {
        $lines += "| $($row.ship) | $($row.state) | $($row.branch) | $($row.head) | $($row.dirty) | $($row.tasks) | $($row.lock) | $($row.activePack) | $($row.simonScore) | $($row.budget) | $($row.recommendation) | $($row.report) |"
    }

    $lines += ""
    $lines += "## Safe Restart Guidance"
    $lines += ""
    $lines += '- Use `request-safe-stop.ps1` before intervening in active ships.'
    $lines += "- Do not manually delete locks or kill processes unless a ship is clearly stuck and rescue is approved."
    $lines += '- For `IDLE_RUNNING`, inspect the latest `.codex-logs` output first; if no progress continues, request a safe stop.'
    $lines += '- For `LOOPING_QUALITY`, let Nami plan a smaller active-pack repair before fresh feature work.'
    $lines += '- For `BUDGET_STOP`, pause that ship and inspect commits, screenshots, and scorecard before continuing.'
    if ($AutoSafeStop) {
        $lines += "- Auto safe-stop is enabled for states: $($AutoSafeStopStates -join ', ')."
    }
    if ($safeStopsRequested.Count -gt 0) {
        $lines += ""
        $lines += "## Safe Stops Requested"
        $lines += ""
        foreach ($request in $safeStopsRequested) {
            $lines += "- $($request.ship): $($request.state) - $($request.path)"
        }
    }
    if ($repairsQueued.Count -gt 0) {
        $lines += ""
        $lines += "## Auto Repairs Queued"
        $lines += ""
        foreach ($repair in $repairsQueued) {
            $lines += "- $($repair.ship): $($repair.state) - $($repair.task)"
        }
    }
    if ($repairLaunches.Count -gt 0) {
        $lines += ""
        $lines += "## Repair Runs Launched"
        $lines += ""
        foreach ($launch in $repairLaunches) {
            $lines += "- $($launch.ship): PID $($launch.pid)"
            $lines += "  - stdout: $($launch.stdout)"
            $lines += "  - stderr: $($launch.stderr)"
            $lines += '```powershell'
            $lines += $launch.command
            $lines += '```'
        }
    }
    if ($repairLaunchFailures.Count -gt 0) {
        $lines += ""
        $lines += "## Repair Relaunch Failures"
        $lines += ""
        foreach ($failure in $repairLaunchFailures) {
            $lines += "- $($failure.ship): $($failure.reason)"
            $lines += "  - PID: $($failure.pid)"
            $lines += "  - stdout: $($failure.stdout)"
            $lines += "  - stderr: $($failure.stderr)"
        }
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -Path $OutFile -Value $lines
    Write-OvernightDigest -Rows $rows -Timestamp $timestamp -Since $since -SafeStopsRequested $safeStopsRequested -RepairsQueued $repairsQueued -RepairLaunches $repairLaunches -RepairLaunchFailures $repairLaunchFailures

    if (-not [Console]::IsOutputRedirected) {
        Clear-Host
    }
    Write-Host "Codex Fleet Supervisor - $timestamp" -ForegroundColor Cyan
    Write-Host "Report: $OutFile"
    Write-Host "Digest: $DigestOutFile"
    foreach ($row in $rows) {
        $color = if ($row.state -match "BLOCKED|LOOPING|BUDGET|IDLE_RUNNING") { "Yellow" } else { "Green" }
        Write-Host ("{0}: {1} | {2} | tasks {3} | {4} | {5}" -f $row.ship, $row.state, $row.dirty, $row.tasks, $row.activePack, $row.recommendation) -ForegroundColor $color
    }
}

function Write-OvernightDigest {
    param(
        [object[]]$Rows,
        [string]$Timestamp,
        [datetime]$Since,
        [object[]]$SafeStopsRequested = @(),
        [object[]]$RepairsQueued = @(),
        [object[]]$RepairLaunches = @(),
        [object[]]$RepairLaunchFailures = @()
    )

    $digest = @(
        "# Codex Fleet Overnight Digest",
        "",
        "Generated: $Timestamp",
        "Window start: $($Since.ToString("yyyy-MM-dd HH:mm:ss"))",
        "",
        "## Progressing Or Ready",
        ""
    )
    $activeRows = @($Rows | Where-Object { $_.state -in @("PROGRESSING", "READY", "IDLE_READY") })
    if ($activeRows.Count -eq 0) { $digest += "- None." }
    else { $activeRows | ForEach-Object { $digest += "- $($_.ship): $($_.state), $($_.activePack), $($_.simonScore)" } }

    $digest += ""
    $digest += "## Needs Human Attention"
    $digest += ""
    $attentionRows = @($Rows | Where-Object { $_.state -match "BLOCKED|LOOPING|BUDGET|IDLE_RUNNING" })
    if ($attentionRows.Count -eq 0) { $digest += "- None." }
    else { $attentionRows | ForEach-Object { $digest += "- $($_.ship): $($_.state), $($_.recommendation)" } }

    $digest += ""
    $digest += "## Work Packs"
    $digest += ""
    $Rows | ForEach-Object { $digest += "- $($_.ship): $($_.activePack)" }
    if ($SafeStopsRequested.Count -gt 0) {
        $digest += ""
        $digest += "## Safe Stops Requested"
        $digest += ""
        $SafeStopsRequested | ForEach-Object { $digest += "- $($_.ship): $($_.state), $($_.reason)" }
    }
    if ($RepairsQueued.Count -gt 0) {
        $digest += ""
        $digest += "## Auto Repairs Queued"
        $digest += ""
        $RepairsQueued | ForEach-Object { $digest += "- $($_.ship): $($_.state)" }
    }
    if ($RepairLaunches.Count -gt 0) {
        $digest += ""
        $digest += "## Repair Runs Launched"
        $digest += ""
        $RepairLaunches | ForEach-Object { $digest += "- $($_.ship): PID $($_.pid)" }
    }
    if ($RepairLaunchFailures.Count -gt 0) {
        $digest += ""
        $digest += "## Repair Relaunch Failures"
        $digest += ""
        $RepairLaunchFailures | ForEach-Object { $digest += "- $($_.ship): $($_.reason)" }
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $DigestOutFile) | Out-Null
    Set-Content -Path $DigestOutFile -Value $digest
}

if ($IntervalSeconds -lt 30) {
    $IntervalSeconds = 30
}

do {
    Write-SupervisorReport
    if ($Once) {
        break
    }
    Start-Sleep -Seconds $IntervalSeconds
} while ($true)
