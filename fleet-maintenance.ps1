[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string]$OutFile = "out\fleet-maintenance.md",

    [switch]$Template,

    [switch]$ValidateOnly,

    [switch]$IncludeDirty
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-ConfigPropertyValue {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-ProjectList {
    if (!(Test-Path $ConfigPath)) { Stop-WithMessage "Config not found: $ConfigPath" }
    $parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
        if ($projects.Count -ne 1) { Stop-WithMessage "Project not found: $Project" }
    }
    return $projects
}

function Get-MarkdownValue {
    param([string]$Path, [string]$Heading)
    if (!(Test-Path $Path)) { return "missing" }
    $text = Get-Content $Path -Raw
    $match = [regex]::Match($text, "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n\s*([^\r\n#]+)")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return "unknown"
}

function Add-MaintenanceItem {
    param(
        [System.Collections.Generic.List[object]]$Items,
        [string]$Lane,
        [string]$Priority,
        [string]$Source,
        [string]$Summary
    )

    $Items.Add([pscustomobject]@{
        lane = $Lane
        priority = $Priority
        source = $Source
        summary = $Summary
    }) | Out-Null
}

function Get-MaintenanceSignalPriority {
    param([string]$Line)

    if ($Line -match "(?i)\bRED\b|\bP1\b|vulnerab|\bfail(?:ed|ure|s)?\b|\berror\b") {
        return "high"
    }
    if ($Line -match "(?i)\bYELLOW\b|\bP2\b|regression|timeout") {
        return "medium"
    }
    return "low"
}

function Test-InformationalMaintenanceLine {
    param([string]$Line)

    return ($Line -match "(?i)^\s*-\s+A\s+GREEN\s+result\s+means\b" -or
        $Line -match "(?i)^\s*-\s+Human\s+review\s+is\s+still\s+required\b" -or
        $Line -match "(?i)^\s*-\s+Local\s+storage\s+is\s+allowed\b" -or
        $Line -match "(?i)^\s*-\s+Task\s+attempted:")
}

function Add-ReportSignalItems {
    param(
        [System.Collections.Generic.List[object]]$Items,
        [string]$Path,
        [string]$Lane,
        [string]$Source
    )

    if (!(Test-Path $Path)) { return }
    $signalPattern = "\bRED\b|\bYELLOW\b|\bP1\b|\bP2\b|\bTODO\b|\bFIXME\b|flaky|regression|slow|timeout|deprecated|vulnerab|outdated|debt|\berror\b|\bfail(?:ed|ure|s)?\b"
    $matches = @(Select-String -Path $Path -Pattern $signalPattern -CaseSensitive:$false -ErrorAction SilentlyContinue | Select-Object -First 8)
    foreach ($match in $matches) {
        if (Test-InformationalMaintenanceLine -Line $match.Line) { continue }
        $priority = Get-MaintenanceSignalPriority -Line $match.Line
        Add-MaintenanceItem -Items $Items -Lane $Lane -Priority $priority -Source "$Source line $($match.LineNumber)" -Summary $match.Line.Trim()
    }
}

function Write-MaintenanceTemplates {
    foreach ($ship in Get-ProjectList) {
        $repo = [string](Get-ConfigPropertyValue -Object $ship -Name "repo")
        $repoPath = Resolve-Path -LiteralPath $repo -ErrorAction SilentlyContinue
        if (!$repoPath) {
            Write-Host "Skipping missing repo: $repo" -ForegroundColor Yellow
            continue
        }
        Push-Location $repoPath.Path
        try {
            New-Item -ItemType Directory -Force -Path "docs/codex" | Out-Null
            $windows = "docs/codex/MAINTENANCE_WINDOWS.md"
            $queue = "docs/codex/MAINTENANCE_QUEUE.md"
            $debt = "docs/codex/TECH_DEBT.md"
            if (!(Test-Path $windows)) {
                Set-Content -Path $windows -Value @"
# Maintenance Windows

Define when Fleet may perform low-risk maintenance.

- Window:
- Allowed lanes: bugs, tests, docs, performance, debt, dependency-review
- Disallowed without human approval: production deploys, auth, payment, secrets, migrations, package changes
"@
            }
            if (!(Test-Path $queue)) {
                Set-Content -Path $queue -Value @"
# Maintenance Queue

Fleet-managed intake for bug triage, flaky tests, performance regressions, dependency review, and technical debt.

- [ ] Review latest Fleet maintenance report and choose one low-risk maintenance task. [class:bugfix risk:low scope:docs/codex/]
"@
            }
            if (!(Test-Path $debt)) {
                Set-Content -Path $debt -Value @"
# Technical Debt

Track maintainability work that should not interrupt product sprints.

- Item:
- Impact:
- Evidence:
- Suggested task class:
"@
            }
        } finally {
            Pop-Location
        }
        Write-Host "Maintenance templates ready: $repo" -ForegroundColor Green
    }
}

function Test-MaintenanceReady {
    param([string]$Repo)
    Push-Location $Repo
    try {
        $hasQueue = Test-Path "docs/codex/MAINTENANCE_QUEUE.md"
        $hasWindows = Test-Path "docs/codex/MAINTENANCE_WINDOWS.md"
    } finally {
        Pop-Location
    }
    return ($hasQueue -and $hasWindows)
}

if ($Template) {
    Write-MaintenanceTemplates
    exit 0
}

if ($ValidateOnly) {
    $missing = @()
    foreach ($ship in Get-ProjectList) {
        $repo = [string](Get-ConfigPropertyValue -Object $ship -Name "repo")
        $repoPath = Resolve-Path -LiteralPath $repo -ErrorAction SilentlyContinue
        if (!$repoPath) {
            $missing += "$($ship.name): repo missing"
        } elseif (!(Test-MaintenanceReady -Repo $repoPath.Path)) {
            $missing += "$($ship.name): maintenance queue/window missing"
        }
    }
    if ($missing.Count -gt 0) {
        $missing | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        exit 1
    }
    Write-Host "Maintenance lane is configured." -ForegroundColor Green
    exit 0
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$results = @()
foreach ($ship in Get-ProjectList) {
    $repo = [string](Get-ConfigPropertyValue -Object $ship -Name "repo")
    $name = [string](Get-ConfigPropertyValue -Object $ship -Name "name")
    $repoPath = Resolve-Path -LiteralPath $repo -ErrorAction SilentlyContinue
    $items = [System.Collections.Generic.List[object]]::new()
    if (!$repoPath) {
        Add-MaintenanceItem -Items $items -Lane "bug-triage" -Priority "high" -Source "fleet config" -Summary "Repo missing: $repo"
        $results += [pscustomobject]@{ name = $name; repo = $repo; status = "BLOCKED"; items = @($items); queue = "missing"; windows = "missing"; dirty = "n/a" }
        continue
    }

    Push-Location $repoPath.Path
    try {
        $dirty = @(git status --short 2>$null)
        if ($dirty.Count -gt 0 -and !$IncludeDirty) {
            Add-MaintenanceItem -Items $items -Lane "active-work" -Priority "medium" -Source "git status" -Summary "Skipped maintenance scan because the working tree is dirty. Use -IncludeDirty only for an approved rescue or review."
            $results += [pscustomobject]@{
                name = $name
                repo = $repoPath.Path
                status = "SKIPPED DIRTY"
                items = @($items)
                queue = "skipped"
                windows = "skipped"
                dirty = "dirty $($dirty.Count)"
                checkpoint = "skipped"
                runtime = "skipped"
            }
            continue
        }
        $queue = if (Test-Path "docs/codex/MAINTENANCE_QUEUE.md") { "configured" } else { "missing" }
        $windows = if (Test-Path "docs/codex/MAINTENANCE_WINDOWS.md") { "configured" } else { "missing" }
        if ($queue -eq "missing") { Add-MaintenanceItem -Items $items -Lane "intake" -Priority "medium" -Source "docs/codex/MAINTENANCE_QUEUE.md" -Summary "Maintenance queue is missing." }
        if ($windows -eq "missing") { Add-MaintenanceItem -Items $items -Lane "recurring-maintenance" -Priority "medium" -Source "docs/codex/MAINTENANCE_WINDOWS.md" -Summary "Maintenance windows are missing." }

        foreach ($gate in @(
            @{ path = "docs/codex/CHECKPOINT_REVIEW.md"; lane = "bug-triage"; source = "checkpoint" },
            @{ path = "docs/codex/NIGHTLY_REPORT.md"; lane = "issue-intake"; source = "nightly report" },
            @{ path = "docs/codex/RUNTIME_VERIFICATION.md"; lane = "performance-regression"; source = "runtime verification" },
            @{ path = "docs/codex/JOEY_SECURITY_REVIEW.md"; lane = "security-maintenance"; source = "Joey security" },
            @{ path = "docs/codex/MIGRATION_REVIEW.md"; lane = "data-maintenance"; source = "migration review" },
            @{ path = "docs/codex/DEPENDENCY_PROPOSAL.md"; lane = "dependency-review"; source = "dependency proposal" },
            @{ path = "docs/codex/TECH_DEBT.md"; lane = "technical-debt"; source = "technical debt" }
        )) {
            Add-ReportSignalItems -Items $items -Path $gate.path -Lane $gate.lane -Source $gate.source
        }

        $checkpoint = Get-MarkdownValue -Path "docs/codex/CHECKPOINT_REVIEW.md" -Heading "Verdict"
        $runtime = Get-MarkdownValue -Path "docs/codex/RUNTIME_VERIFICATION.md" -Heading "Verdict"
        $status = if (@($items | Where-Object { $_.priority -eq "high" }).Count -gt 0) {
            "NEEDS TRIAGE"
        } elseif ($items.Count -gt 0) {
            "MAINTENANCE QUEUED"
        } else {
            "QUIET"
        }
        $results += [pscustomobject]@{
            name = $name
            repo = $repoPath.Path
            status = $status
            items = @($items)
            queue = $queue
            windows = $windows
            dirty = if ($dirty.Count -eq 0) { "clean" } else { "dirty $($dirty.Count)" }
            checkpoint = $checkpoint
            runtime = $runtime
        }
    } finally {
        Pop-Location
    }
}

$lines = @(
    "# Fleet Maintenance Report",
    "",
    "Generated: $timestamp",
    "",
    "Phase 8 autonomous maintenance intake. This report does not edit ships, update dependencies, deploy, or spend money.",
    "",
    "| Ship | Status | Queue | Windows | Dirty | Checkpoint | Runtime | Items |",
    "| --- | --- | --- | --- | --- | --- | --- | ---: |"
)
foreach ($result in $results) {
    $lines += "| $($result.name) | $($result.status) | $($result.queue) | $($result.windows) | $($result.dirty) | $($result.checkpoint) | $($result.runtime) | $($result.items.Count) |"
}

foreach ($result in $results) {
    $lines += ""
    $lines += "## $($result.name)"
    $lines += ""
    $lines += "- Repo: $($result.repo)"
    $lines += "- Status: $($result.status)"
    $lines += "- Maintenance queue: $($result.queue)"
    $lines += "- Maintenance windows: $($result.windows)"
    $lines += ""
    $lines += "Items:"
    if ($result.items.Count -eq 0) {
        $lines += "- None"
    } else {
        foreach ($item in $result.items) {
            $lines += "- [$($item.priority)] $($item.lane): $($item.summary) ($($item.source))"
        }
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
Set-Content -Path $OutFile -Value $lines
Write-Host "Maintenance report: $OutFile" -ForegroundColor Green
exit 0
