[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string[]]$ExcludeProject = @(),

    [int]$SinceHours = 18,

    [switch]$IgnoreDryRuns,

    [string]$OutFile = "out\fleet-night-report.md",

    [string]$JsonOutFile = "out\fleet-night-report.json"
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")

function ConvertTo-ProjectList {
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

function Get-UncheckedTaskCount {
    param([string]$Repo)

    $queue = Join-Path $Repo "docs\codex\TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $queue)) { return 0 }
    return @(Select-String -Path $queue -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue).Count
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
        return [pscustomobject]@{ text = "none"; active = $false; stale = $false; pid = 0 }
    }

    try {
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        $pidValue = if ($null -ne $lock.pid) { [int]$lock.pid } else { 0 }
        $process = if ($pidValue -gt 0) { Get-Process -Id $pidValue -ErrorAction SilentlyContinue } else { $null }
        if ($null -eq $process) {
            return [pscustomobject]@{ text = "stale PID $pidValue"; active = $false; stale = $true; pid = $pidValue }
        }

        $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$pidValue" -ErrorAction SilentlyContinue)
        $activeChildren = @($children | Where-Object {
            $name = [string]$_.Name
            ![string]::IsNullOrWhiteSpace($name) -and $name -notin @("conhost.exe")
        })
        if ($activeChildren.Count -gt 0) {
            return [pscustomobject]@{ text = "active PID $pidValue"; active = $true; stale = $false; pid = $pidValue }
        }

        return [pscustomobject]@{ text = "idle shell PID $pidValue"; active = $false; stale = $true; pid = $pidValue }
    } catch {
        return [pscustomobject]@{ text = "unreadable"; active = $false; stale = $true; pid = 0 }
    }
}

function Resolve-ShipStatus {
    param(
        [bool]$Dirty,
        [bool]$LockActive,
        [string]$LatestResult,
        [int]$Tasks
    )

    if ($LockActive -and $Dirty) { return "RUNNING" }
    if ($LockActive) { return "RUNNING_CLEAN" }
    if ($Dirty) { return "NEEDS_REVIEW" }
    if ($LatestResult -match "(?i)quarantined|failed|blocked") { return "NEEDS_REPAIR" }
    if ($Tasks -gt 0) { return "READY" }
    return "FINISHED_OR_PARKED"
}

function Get-Recommendation {
    param([string]$Status)

    switch ($Status) {
        "RUNNING" { return "leave it alone; active work owns dirty files" }
        "RUNNING_CLEAN" { return "let it run or inspect terminal if idle too long" }
        "NEEDS_REVIEW" { return "inspect dirty files before relaunch" }
        "NEEDS_REPAIR" { return "run one repair batch or let auto-recovery generate a smaller task" }
        "READY" { return "eligible for selected launch" }
        default { return "park unless you want more tasks" }
    }
}

function Get-ScheduledRunRows {
    param([datetime]$Since)

    $logRoot = Join-Path $fleetRoot "out\scheduled-runs"
    if (!(Test-Path -LiteralPath $logRoot)) { return @() }

    return @(Get-ChildItem -Path $logRoot -File -Filter "*.log" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $Since } |
        Sort-Object LastWriteTime |
        ForEach-Object {
            $text = Get-Content -LiteralPath $_.FullName -Raw
            $status = if ($text -match "(?i)Fleet harness self-test failed|Launch command exited with code [1-9]|Dry-run launch validation exited with code [1-9]") {
                "failed"
            } elseif ($text -match "(?i)No new fleet windows launched|Skipping") {
                "skipped"
            } elseif ($text -match "(?i)Launch command exited with code 0") {
                "launched"
            } elseif ($text -match "(?i)Dry run passed|Dry-run launch validation exited with code 0") {
                "dry-run"
            } else {
                "unknown"
            }
            $why = ""
            $skipLine = [regex]::Match($text, "(?im)^\d{4}-\d{2}-\d{2} .*(Skipping|Fleet harness self-test failed|No new fleet windows launched|Dry-run launch validation exited with code [0-9]+).*$")
            if ($skipLine.Success) { $why = $skipLine.Value.Trim() }
            [pscustomobject]@{
                name = $_.Name
                path = $_.FullName
                lastWriteTime = $_.LastWriteTime
                status = $status
                detail = $why
            }
        })
}

if (!(Test-Path -LiteralPath $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$since = (Get-Date).AddHours(-1 * $SinceHours)
$projects = @(Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json | ForEach-Object { $_ })
if (![string]::IsNullOrWhiteSpace($Project)) {
    $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
}
$excluded = @(ConvertTo-ProjectList -Values $ExcludeProject)
if ($excluded.Count -gt 0) {
    $projects = @($projects | Where-Object { $excluded -notcontains [string]$_.name })
}

$scheduledRows = @(Get-ScheduledRunRows -Since $since)
if ($IgnoreDryRuns) {
    $scheduledRows = @($scheduledRows | Where-Object {
        $_.status -ne "dry-run" -and
        $_.name -notmatch "(?i)(dryrun|dry-run|proof|test|check|harness|preflight)"
    })
}
$shipRows = @()
foreach ($projectConfig in $projects) {
    $name = [string]$projectConfig.name
    $repo = [string]$projectConfig.repo
    if (!(Test-Path -LiteralPath $repo)) {
        $shipRows += [pscustomobject]@{
            ship = $name; repo = $repo; status = "MISSING"; branch = ""; head = ""; dirtyCount = 0; lock = "missing"
            tasks = 0; latestResult = "missing"; latestTask = ""; latestRisk = ""; recommendation = "fix repo path"
        }
        continue
    }

    Push-Location $repo
    $branch = (git branch --show-current 2>$null)
    $head = (git rev-parse --short HEAD 2>$null)
    $dirty = @(git status --short 2>$null)
    Pop-Location

    $lock = Get-RunLockStatus -ProjectName $name
    $outcome = Get-LatestNightlyOutcome -Repo $repo
    $tasks = Get-UncheckedTaskCount -Repo $repo
    $status = Resolve-ShipStatus -Dirty ($dirty.Count -gt 0) -LockActive $lock.active -LatestResult $outcome.result -Tasks $tasks
    $shipRows += [pscustomobject]@{
        ship = $name
        repo = $repo
        status = $status
        branch = $branch
        head = $head
        dirtyCount = $dirty.Count
        lock = $lock.text
        tasks = $tasks
        latestResult = $outcome.result
        latestTask = $outcome.task
        latestRisk = $outcome.risk
        latestReportTime = $outcome.reportTime
        recommendation = Get-Recommendation -Status $status
    }
}

$summary = [pscustomobject]@{
    generatedAt = (Get-Date).ToString("o")
    since = $since.ToString("o")
    scheduledRuns = $scheduledRows
    ships = $shipRows
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOutFile) | Out-Null
$summary | ConvertTo-Json -Depth 6 | Set-Content -Path $JsonOutFile -Encoding UTF8

$launched = @($scheduledRows | Where-Object { $_.status -eq "launched" }).Count
$skipped = @($scheduledRows | Where-Object { $_.status -eq "skipped" }).Count
$failed = @($scheduledRows | Where-Object { $_.status -eq "failed" }).Count
$shipNeedsAttention = @($shipRows | Where-Object { $_.status -in @("NEEDS_REVIEW", "NEEDS_REPAIR", "MISSING") })

$lines = @(
    "# Fleet Night Report",
    "",
    "- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "- Window: last $SinceHours hour(s)",
    "- Ignore dry-runs: $([bool]$IgnoreDryRuns)",
    "- Scheduled attempts: $($scheduledRows.Count)",
    "- Launched: $launched",
    "- Skipped: $skipped",
    "- Failed scheduler attempts: $failed",
    "- Ships needing attention: $($shipNeedsAttention.Count)",
    "",
    "## Scheduled Attempts",
    "",
    "| Log | Time | Status | Detail |",
    "| --- | --- | --- | --- |"
)

if ($scheduledRows.Count -eq 0) {
    $lines += "| None |  |  | No scheduled run logs in window. |"
} else {
    foreach ($row in $scheduledRows) {
        $lines += "| $($row.name) | $($row.lastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')) | $($row.status) | $($row.detail -replace '\|', '/') |"
    }
}

$lines += @(
    "",
    "## Ship Outcomes",
    "",
    "| Ship | Status | Dirty | Lock | Tasks | Latest Result | Recommendation |",
    "| --- | --- | ---: | --- | ---: | --- | --- |"
)
foreach ($row in $shipRows) {
    $lines += "| $($row.ship) | $($row.status) | $($row.dirtyCount) | $($row.lock) | $($row.tasks) | $($row.latestResult) | $($row.recommendation) |"
}

$lines += @(
    "",
    "## Latest Tasks",
    "",
    "| Ship | Latest Task | Follow-up |",
    "| --- | --- | --- |"
)
foreach ($row in $shipRows) {
    $task = if ([string]::IsNullOrWhiteSpace([string]$row.latestTask)) { "" } else { [string]$row.latestTask }
    if ($task.Length -gt 180) { $task = $task.Substring(0, 180).Trim() + "..." }
    $risk = if ([string]::IsNullOrWhiteSpace([string]$row.latestRisk)) { "" } else { [string]$row.latestRisk }
    if ($risk.Length -gt 160) { $risk = $risk.Substring(0, 160).Trim() + "..." }
    $lines += "| $($row.ship) | $($task -replace '\|', '/') | $($risk -replace '\|', '/') |"
}

Set-Content -Path $OutFile -Value $lines -Encoding UTF8
Write-Host "Fleet night report: $OutFile" -ForegroundColor Cyan
Write-Host "Fleet night JSON: $JsonOutFile" -ForegroundColor DarkCyan

if ($failed -gt 0 -or $shipNeedsAttention.Count -gt 0) {
    Write-Host "Night report found items needing attention." -ForegroundColor Yellow
    exit 1
}

Write-Host "Night report found no blocking issues." -ForegroundColor Green
