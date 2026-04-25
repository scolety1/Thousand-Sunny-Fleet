[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [int]$IntervalSeconds = 300,

    [string]$OutFile = "out\fleet-supervisor.md",

    [switch]$Once
)

$ErrorActionPreference = "Continue"

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

    $lines = @(Get-Content "docs/codex/NIGHTLY_REPORT.md" -Tail 40 | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($lines.Count -eq 0) {
        return "Nightly report is empty."
    }

    return ($lines | Select-Object -Last 1)
}

function Write-SupervisorReport {
    if (!(Test-Path $ConfigPath)) {
        Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
        exit 1
    }

    $parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $rows = @()
    $lines = @(
        "# Codex Fleet Supervisor",
        "",
        "Generated: $timestamp",
        "",
        "| Ship | Branch | HEAD | Dirty | Tasks | Checkpoint | Simon | Joey | Last Report |",
        "| --- | --- | --- | --- | ---: | --- | --- | --- | --- |"
    )

    foreach ($project in $projects) {
        if (!(Test-Path $project.repo)) {
            $lines += "| $($project.name) | missing repo | n/a | n/a | 0 | n/a | n/a | n/a | $($project.repo) |"
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
        $joey = Get-FirstMarkdownValue -Path "docs/codex/JOEY_SECURITY_REVIEW.md" -Heading "Verdict"
        $lastReport = (Get-LastReportLine).Replace("|", "/")
        Pop-Location

        $rows += [pscustomobject]@{
            ship = $project.name
            branch = $branch
            head = $head
            dirty = $dirtyText
            tasks = $tasks
            checkpoint = $checkpoint
            simon = $simon
            joey = $joey
            report = $lastReport
        }

        $lines += "| $($project.name) | $branch | $head | $dirtyText | $tasks | $checkpoint | $simon | $joey | $lastReport |"
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
    Set-Content -Path $OutFile -Value $lines

    Clear-Host
    Write-Host "Codex Fleet Supervisor - $timestamp" -ForegroundColor Cyan
    Write-Host "Report: $OutFile"
    foreach ($row in $rows) {
        $color = if ($row.dirty -eq "clean" -and $row.checkpoint -notmatch "RED" -and $row.joey -notmatch "RED") { "Green" } else { "Yellow" }
        Write-Host ("{0}: {1} {2} | {3} | tasks {4} | checkpoint {5} | Simon {6} | Joey {7}" -f $row.ship, $row.branch, $row.head, $row.dirty, $row.tasks, $row.checkpoint, $row.simon, $row.joey) -ForegroundColor $color
    }
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
