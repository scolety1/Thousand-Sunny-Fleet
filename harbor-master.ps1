[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string[]]$ExcludeProject = @(),

    [string]$OutFile = "out\harbor-master.md",

    [string]$JsonOutFile = "out\harbor-master.json",

    [int]$IdleShellGraceSeconds = 120
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")

function Get-UncheckedTaskCount {
    param([string]$Repo)

    $queue = Join-Path $Repo "docs\codex\TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $queue)) { return 0 }
    return @(Select-String -Path $queue -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue).Count
}

function Get-FirstMarkdownValue {
    param(
        [string]$Path,
        [string]$Heading
    )

    if (!(Test-Path -LiteralPath $Path)) { return "missing" }

    $text = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match($text, "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n\s*([^\r\n#]+)")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return "unknown"
}

function Get-LatestNightlyOutcome {
    param([string]$Repo)

    $path = Join-Path $Repo "docs\codex\NIGHTLY_REPORT.md"
    if (!(Test-Path -LiteralPath $path)) {
        return [pscustomobject]@{ result = "missing"; task = ""; risk = ""; reportTime = "" }
    }

    $text = Get-Content -LiteralPath $path -Raw
    $sections = [regex]::Matches($text, "(?ims)^##\s+(.+?)\r?\n(.+?)(?=^##\s+|\z)")
    if ($sections.Count -eq 0) {
        return [pscustomobject]@{ result = "unknown"; task = ""; risk = ""; reportTime = "" }
    }

    $last = $sections[$sections.Count - 1]
    $body = $last.Groups[2].Value
    $result = [regex]::Match($body, "(?im)^-\s+Build result:\s*(.+)$")
    $task = [regex]::Match($body, "(?im)^-\s+Task attempted:\s*(.+)$")
    $risk = [regex]::Match($body, "(?im)^-\s+Risks or follow-up needed:\s*(.+)$")

    return [pscustomobject]@{
        result = if ($result.Success) { $result.Groups[1].Value.Trim() } else { "unknown" }
        task = if ($task.Success) { $task.Groups[1].Value.Trim() } else { "" }
        risk = if ($risk.Success) { $risk.Groups[1].Value.Trim() } else { "" }
        reportTime = $last.Groups[1].Value.Trim()
    }
}

function Get-RunLockStatus {
    param([string]$ProjectName)

    $safeName = ConvertTo-FleetLaunchSafeName -Name $ProjectName
    $lockPath = Join-Path $fleetRoot ".codex-local\locks\$safeName.lock.json"
    if (!(Test-Path -LiteralPath $lockPath)) {
        return [pscustomobject]@{ text = "none"; active = $false; stale = $false; idleShell = $false; pid = 0; activeChildCount = 0; childSummary = ""; path = "" }
    }

    try {
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        $pidValue = if ($null -ne $lock.pid) { [int]$lock.pid } else { 0 }
        $process = if ($pidValue -gt 0) { Get-Process -Id $pidValue -ErrorAction SilentlyContinue } else { $null }
        if ($null -eq $process) {
            return [pscustomobject]@{ text = "stale PID $pidValue"; active = $false; stale = $true; idleShell = $false; pid = $pidValue; activeChildCount = 0; childSummary = ""; path = $lockPath }
        }

        $isFresh = $false
        try {
            $isFresh = (((Get-Date) - $process.StartTime).TotalSeconds -lt $IdleShellGraceSeconds)
        } catch {
            $isFresh = $true
        }

        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$pidValue" -ErrorAction SilentlyContinue)
        $activeChildren = @($children | Where-Object {
            $name = [string]$_.Name
            ![string]::IsNullOrWhiteSpace($name) -and $name -notin @("conhost.exe")
        })
        $childSummary = (($activeChildren | ForEach-Object { [string]$_.Name } | Sort-Object -Unique) -join ", ")

        if ($isFresh -or $activeChildren.Count -gt 0) {
            return [pscustomobject]@{ text = "active PID $pidValue"; active = $true; stale = $false; idleShell = $false; pid = $pidValue; activeChildCount = $activeChildren.Count; childSummary = $childSummary; path = $lockPath }
        }

        return [pscustomobject]@{ text = "idle shell PID $pidValue"; active = $false; stale = $true; idleShell = $true; pid = $pidValue; activeChildCount = 0; childSummary = ""; path = $lockPath }
    } catch {
        return [pscustomobject]@{ text = "unreadable"; active = $false; stale = $true; idleShell = $false; pid = 0; activeChildCount = 0; childSummary = ""; path = $lockPath }
    }
}

function Resolve-FailureClass {
    param([object]$Facts)

    if ($Facts.repoMissing) { return "repo-missing" }
    if ($Facts.safeStop) { return "safe-stop-requested" }
    if ($Facts.dirty -and -not $Facts.lockActive) { return "dirty-without-run" }
    if ($Facts.checkpoint -match "RED" -or $Facts.simon -match "RED" -or $Facts.robin -match "RED" -or $Facts.joey -match "RED") { return "review-blocked" }
    if ($Facts.latestResult -match "(?i)quarantined") { return "task-quarantined" }
    if ($Facts.latestResult -match "(?i)failed") { return "build-or-acceptance-failed" }
    if ($Facts.latestResult -match "(?i)blocked") { return "policy-or-scope-blocked" }
    if ($Facts.lockIdleShell) { return "idle-shell-finished" }
    if ($Facts.lockStale) { return "stale-lock" }
    if ($Facts.lockActive -and $Facts.dirty) { return "working" }
    if ($Facts.lockActive) { return "running-clean-stage" }
    if ($Facts.tasks -gt 0) { return "ready-with-tasks" }
    return "no-tasks-clean"
}

function Resolve-HarborState {
    param([object]$Facts)

    switch ($Facts.failureClass) {
        "repo-missing" { return "BLOCKED_MISSING" }
        "safe-stop-requested" { return "STOP_REQUESTED" }
        "dirty-without-run" { return "BLOCKED_DIRTY" }
        "review-blocked" { return "BLOCKED_REVIEW" }
        "task-quarantined" { return "NEEDS_REPAIR_TASK" }
        "build-or-acceptance-failed" { return "NEEDS_REPAIR_TASK" }
        "policy-or-scope-blocked" { return "BLOCKED_POLICY" }
        "idle-shell-finished" {
            if ($Facts.tasks -gt 0) { return "READY_STALE_SHELL" }
            return "FINISHED_CLEAN"
        }
        "stale-lock" {
            if ($Facts.tasks -gt 0) { return "READY_STALE_LOCK" }
            return "FINISHED_CLEAN"
        }
        "working" { return "RUNNING_DIRTY" }
        "running-clean-stage" { return "RUNNING_CLEAN" }
        "ready-with-tasks" { return "READY" }
        default { return "NEEDS_TASK" }
    }
}

function Get-Recommendation {
    param([object]$Facts)

    switch ($Facts.state) {
        "RUNNING_DIRTY" { return "leave it alone; task is mid-flight" }
        "RUNNING_CLEAN" { return "let it run; likely planning, build, review, or fresh start" }
        "READY" { return "eligible for launch" }
        "READY_STALE_SHELL" { return "safe to relaunch; launcher will clear idle lock" }
        "READY_STALE_LOCK" { return "safe to relaunch; launcher will clear stale lock" }
        "FINISHED_CLEAN" { return "parked unless you want more tasks generated" }
        "NEEDS_TASK" { return "planner should generate the next task" }
        "NEEDS_REPAIR_TASK" { return "queue a small repair task, then relaunch one batch" }
        "BLOCKED_POLICY" { return "inspect policy/scope gate before relaunch" }
        "BLOCKED_REVIEW" { return "human review or bounded repair before relaunch" }
        "BLOCKED_DIRTY" { return "do not touch unless rescue is approved" }
        "STOP_REQUESTED" { return "clear safe stop only when you want it moving again" }
        default { return "inspect" }
    }
}

if (!(Test-Path -LiteralPath $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$parsedProjects = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
$projects = @($parsedProjects | ForEach-Object { $_ })
if (![string]::IsNullOrWhiteSpace($Project)) {
    $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
}

$exclude = @($ExcludeProject | ForEach-Object { ([string]$_) -split "," } | ForEach-Object { [string]$_.Trim() } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
if ($exclude.Count -gt 0) {
    $projects = @($projects | Where-Object { $exclude -notcontains [string]$_.name })
}

$stopRequests = @(Get-FleetSafeStopRequests -FleetRoot $fleetRoot)
$rows = @()

foreach ($projectConfig in $projects) {
    $name = [string]$projectConfig.name
    $repo = [string]$projectConfig.repo
    $safeName = ConvertTo-FleetLaunchSafeName -Name $name
    $safeStop = @($stopRequests | Where-Object { $_.safeTarget -eq "ALL" -or $_.safeTarget -eq $safeName }).Count -gt 0

    if (!(Test-Path -LiteralPath $repo)) {
        $facts = [pscustomobject]@{
            ship = $name; repo = $repo; repoMissing = $true; branch = "missing"; head = "n/a"; dirty = $false; dirtyCount = 0; tasks = 0
            lock = "n/a"; lockActive = $false; lockStale = $false; lockIdleShell = $false; childSummary = ""; safeStop = $safeStop
            checkpoint = "missing"; simon = "missing"; robin = "missing"; joey = "missing"; latestResult = "missing"; latestTask = ""; latestRisk = ""
        }
    } else {
        Push-Location $repo
        $branch = git branch --show-current 2>$null
        $head = git rev-parse --short HEAD 2>$null
        if ([string]::IsNullOrWhiteSpace($head)) { $head = "none" }
        $status = @(git status --short 2>$null)
        $lock = Get-RunLockStatus -ProjectName $name
        $outcome = Get-LatestNightlyOutcome -Repo $repo
        $facts = [pscustomobject]@{
            ship = $name
            repo = $repo
            repoMissing = $false
            branch = $branch
            head = $head
            dirty = ($status.Count -gt 0)
            dirtyCount = $status.Count
            tasks = (Get-UncheckedTaskCount -Repo $repo)
            lock = $lock.text
            lockActive = $lock.active
            lockStale = $lock.stale
            lockIdleShell = $lock.idleShell
            childSummary = $lock.childSummary
            safeStop = $safeStop
            checkpoint = Get-FirstMarkdownValue -Path (Join-Path $repo "docs\codex\CHECKPOINT_REVIEW.md") -Heading "Verdict"
            simon = Get-FirstMarkdownValue -Path (Join-Path $repo "docs\codex\SIMON_DESIGN_REVIEW.md") -Heading "Verdict"
            robin = Get-FirstMarkdownValue -Path (Join-Path $repo "docs\codex\ROBIN_COPY_REVIEW.md") -Heading "Verdict"
            joey = Get-FirstMarkdownValue -Path (Join-Path $repo "docs\codex\JOEY_SECURITY_REVIEW.md") -Heading "Verdict"
            latestResult = $outcome.result
            latestTask = $outcome.task
            latestRisk = $outcome.risk
            latestReportTime = $outcome.reportTime
        }
        Pop-Location
    }

    $facts | Add-Member -NotePropertyName failureClass -NotePropertyValue (Resolve-FailureClass -Facts $facts)
    $facts | Add-Member -NotePropertyName state -NotePropertyValue (Resolve-HarborState -Facts $facts)
    $facts | Add-Member -NotePropertyName recommendation -NotePropertyValue (Get-Recommendation -Facts $facts)
    $rows += $facts
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOutFile) | Out-Null

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines = @(
    "# Codex Fleet Harbor Master",
    "",
    "Generated: $timestamp",
    "",
    "Harbor Master separates real running work from idle terminal shells, stale locks, review blocks, and repairable failures.",
    "",
    "| Ship | State | Failure Class | Dirty | Tasks | Lock | Child Work | HEAD | Recommendation |",
    "| --- | --- | --- | ---: | ---: | --- | --- | --- | --- |"
)

foreach ($row in $rows) {
    $child = if ([string]::IsNullOrWhiteSpace([string]$row.childSummary)) { "-" } else { [string]$row.childSummary }
    $lines += "| $($row.ship) | $($row.state) | $($row.failureClass) | $($row.dirtyCount) | $($row.tasks) | $($row.lock) | $child | $($row.head) | $($row.recommendation) |"
}

$lines += ""
$lines += "## Failure Class Meanings"
$lines += ""
$lines += '- `working`: active process with dirty repo; leave it alone.'
$lines += '- `running-clean-stage`: active process in planning, build, review, or just-launched state.'
$lines += '- `idle-shell-finished`: visible terminal remains, but no active child work exists.'
$lines += '- `stale-lock`: lock points at a dead process.'
$lines += '- `build-or-acceptance-failed`: latest report says a build or acceptance gate failed.'
$lines += '- `task-quarantined`: latest task was quarantined and needs a smaller repair.'
$lines += '- `policy-or-scope-blocked`: guardrail, sensitive-system, scope, or approval gate blocked the run.'
$lines += '- `review-blocked`: checkpoint, Simon, Robin, or Joey reported RED.'
$lines += '- `dirty-without-run`: repo has uncommitted work and no active owner.'
$lines += ""
$lines += "## Still Queued After This Phase"
$lines += ""
$lines += "- Auto-relaunch finished ships."
$lines += "- Ship cleaner for safe inspection and cleanup recommendations."
$lines += "- Task quality gate to reject vague or overbroad tasks before launch."
$lines += "- Overnight autopilot report with a readable progress story."

Set-Content -Path $OutFile -Value $lines -Encoding UTF8
$rows | ConvertTo-Json -Depth 6 | Set-Content -Path $JsonOutFile -Encoding UTF8

$rows | Sort-Object ship | Format-Table ship,state,failureClass,dirtyCount,tasks,lock,recommendation -AutoSize
Write-Host ""
Write-Host "Harbor report: $OutFile" -ForegroundColor Green
Write-Host "Harbor JSON: $JsonOutFile" -ForegroundColor DarkCyan
