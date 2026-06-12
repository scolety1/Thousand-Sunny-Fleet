[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",
    [string]$OutputDirectory = ".\fleet\status"
)

$ErrorActionPreference = "Continue"

function Resolve-FleetPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path (Get-Location).Path $Path
}

function ConvertTo-PublicId {
    param([string]$Name)

    $id = ([string]$Name).Trim().ToLowerInvariant() -replace "[^a-z0-9]+", "-"
    return $id.Trim("-")
}

function Invoke-GitText {
    param(
        [string]$RepoPath,
        [string[]]$Arguments
    )

    if (!(Test-Path -LiteralPath $RepoPath)) {
        return $null
    }

    $output = @(& git -C $RepoPath @Arguments 2>$null)
    if ($LASTEXITCODE -ne 0) {
        return $null
    }

    return ($output -join "`n").Trim()
}

function Get-LineValue {
    param(
        [string]$Text,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $match = [regex]::Match($Text, "(?im)^\s*$([regex]::Escape($Label))\s*:\s*(.+?)\s*$")
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return ""
}

function Get-CheckpointVerdict {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\CHECKPOINT_REVIEW.md"
    if (!(Test-Path -LiteralPath $path)) {
        return "UNKNOWN"
    }

    $text = Get-Content -LiteralPath $path -Raw -ErrorAction SilentlyContinue
    $match = [regex]::Match($text, "(?im)^## Verdict\s*\r?\n\s*(GREEN|YELLOW|RED)\s*$")
    if ($match.Success) {
        return $match.Groups[1].Value.Trim().ToUpperInvariant()
    }

    return "UNKNOWN"
}

function Get-BuildResult {
    param([string]$RepoPath)

    $checkpointPath = Join-Path $RepoPath "docs\codex\CHECKPOINT_REVIEW.md"
    if (Test-Path -LiteralPath $checkpointPath) {
        $checkpoint = Get-Content -LiteralPath $checkpointPath -Raw -ErrorAction SilentlyContinue
        $build = Get-LineValue -Text $checkpoint -Label "Build Result"
        if (![string]::IsNullOrWhiteSpace($build)) {
            return $build
        }
    }

    $nightlyPath = Join-Path $RepoPath "docs\codex\NIGHTLY_REPORT.md"
    if (Test-Path -LiteralPath $nightlyPath) {
        $nightly = Get-Content -LiteralPath $nightlyPath -Raw -ErrorAction SilentlyContinue
        $matches = [regex]::Matches($nightly, "(?im)^-\s+Build result:\s*(.+?)\s*$")
        if ($matches.Count -gt 0) {
            return $matches[$matches.Count - 1].Groups[1].Value.Trim()
        }
    }

    return "UNKNOWN"
}

function Get-PendingTaskCount {
    param([string]$RepoPath)

    $path = Join-Path $RepoPath "docs\codex\TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $path)) {
        return $null
    }

    return @(Select-String -LiteralPath $path -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue).Count
}

function Get-NextAction {
    param(
        [string]$StatusColor,
        [string]$CleanState,
        [string]$CheckpointVerdict,
        [string]$BuildResult,
        [object]$PendingTaskCount
    )

    if ($StatusColor -eq "UNKNOWN") {
        return "Open from desktop to inspect safely."
    }

    if ($CleanState -eq "dirty") {
        return "Review local changes before requesting work."
    }

    if ($null -ne $PendingTaskCount -and [int]$PendingTaskCount -gt 0) {
        return "Request one-project proof run for the next queued task."
    }

    if ($CheckpointVerdict -eq "GREEN" -and $BuildResult -match "(?i)passed") {
        return "Human review next; queue one bounded task when ready."
    }

    return "Review evidence before requesting more work."
}

function Get-StatusColor {
    param(
        [bool]$Inspectable,
        [string]$CleanState,
        [string]$CheckpointVerdict,
        [string]$BuildResult,
        [object]$PendingTaskCount
    )

    if (!$Inspectable) {
        return "UNKNOWN"
    }

    if ($CheckpointVerdict -eq "RED" -or $BuildResult -match "(?i)\b(failed|blocked)\b") {
        return "RED"
    }

    if ($CleanState -eq "dirty") {
        return "YELLOW"
    }

    if ($CheckpointVerdict -eq "GREEN" -and $BuildResult -match "(?i)passed" -and ($null -eq $PendingTaskCount -or [int]$PendingTaskCount -eq 0)) {
        return "GREEN"
    }

    if ($CheckpointVerdict -eq "UNKNOWN" -and $BuildResult -eq "UNKNOWN") {
        return "UNKNOWN"
    }

    return "YELLOW"
}

$configFullPath = Resolve-FleetPath -Path $ConfigPath
$outputFullPath = Resolve-FleetPath -Path $OutputDirectory

if (!(Test-Path -LiteralPath $configFullPath)) {
    Write-Host "Project config not found: $configFullPath" -ForegroundColor Red
    exit 1
}

$projects = @(Get-Content -LiteralPath $configFullPath -Raw -ErrorAction Stop | ConvertFrom-Json | ForEach-Object { $_ })
$snapshotProjects = @()

foreach ($project in $projects) {
    $name = [string]$project.name
    $repo = [string]$project.repo
    $id = ConvertTo-PublicId -Name $name
    $inspectable = $false
    $safeNote = "Evidence missing; request desktop review."
    $branch = "unknown"
    $cleanState = "unknown"
    $checkpointVerdict = "UNKNOWN"
    $buildResult = "UNKNOWN"
    $pendingTaskCount = $null

    if (![string]::IsNullOrWhiteSpace($repo) -and (Test-Path -LiteralPath $repo)) {
        $gitRoot = Invoke-GitText -RepoPath $repo -Arguments @("rev-parse", "--show-toplevel")
        if (![string]::IsNullOrWhiteSpace($gitRoot)) {
            $inspectable = $true
            $safeNote = "Read-only local evidence snapshot."
            $branchValue = Invoke-GitText -RepoPath $repo -Arguments @("branch", "--show-current")
            if (![string]::IsNullOrWhiteSpace($branchValue)) {
                $branch = $branchValue
            }

            $statusText = Invoke-GitText -RepoPath $repo -Arguments @("status", "--porcelain")
            $cleanState = if ([string]::IsNullOrWhiteSpace($statusText)) { "clean" } else { "dirty" }
            $checkpointVerdict = Get-CheckpointVerdict -RepoPath $repo
            $buildResult = Get-BuildResult -RepoPath $repo
            $pendingTaskCount = Get-PendingTaskCount -RepoPath $repo
        } else {
            $safeNote = "Registered path is not a readable git worktree."
        }
    } else {
        $safeNote = "Registered project is not available on this machine."
    }

    $statusColor = Get-StatusColor -Inspectable $inspectable -CleanState $cleanState -CheckpointVerdict $checkpointVerdict -BuildResult $buildResult -PendingTaskCount $pendingTaskCount
    $nextAction = Get-NextAction -StatusColor $statusColor -CleanState $cleanState -CheckpointVerdict $checkpointVerdict -BuildResult $buildResult -PendingTaskCount $pendingTaskCount

    $snapshotProjects += [pscustomobject]@{
        id = $id
        name = $name
        statusColor = $statusColor
        branch = $branch
        cleanState = $cleanState
        lastCheckpointVerdict = $checkpointVerdict
        lastBuildResult = $buildResult
        pendingTaskCount = $pendingTaskCount
        nextRecommendedAction = $nextAction
        note = $safeNote
        controls = [pscustomobject]@{
            requestTask = "https://github.com/scolety1/Thousand-Sunny-Fleet/edit/main/fleet/control/quick-mission.md"
            stopRequest = "https://github.com/scolety1/Thousand-Sunny-Fleet/edit/main/fleet/control/emergency.md"
            logsStatus = "https://github.com/scolety1/Thousand-Sunny-Fleet/blob/main/fleet/status/today.md"
        }
    }
}

$privateLens = @($snapshotProjects | Where-Object { $_.name -eq "PrivateLens" })
$others = @($snapshotProjects | Where-Object { $_.name -ne "PrivateLens" } | Sort-Object name)
$orderedProjects = @($privateLens + $others)

$snapshot = [pscustomobject]@{
    schemaVersion = 1
    statusKind = "public-safe-project-status-snapshot"
    notice = "Phone HQ is request/status only. It does not execute Codex, approve work, merge, push, or deploy."
    projects = $orderedProjects
}

New-Item -ItemType Directory -Force -Path $outputFullPath | Out-Null
$jsonPath = Join-Path $outputFullPath "projects.json"
$markdownPath = Join-Path $outputFullPath "projects.md"

$snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8

$markdown = @()
$markdown += "# Fleet Project Status Snapshot"
$markdown += ""
$markdown += "Phone HQ is request/status only. It does not execute Codex, approve work, merge, push, or deploy."
$markdown += ""
$markdown += "This is a generated public-safe snapshot. It intentionally omits local filesystem paths, secrets, credentials, tokens, private device identifiers, and product/customer data."
$markdown += ""
$markdown += 'Status can be stale until `tools/fleet-project-status.ps1` is regenerated and the snapshot is separately reviewed/published.'
$markdown += ""
$markdown += "| Project | Status | Branch | Clean | Checkpoint | Build | Pending | Next action |"
$markdown += "| --- | --- | --- | --- | --- | --- | ---: | --- |"

foreach ($project in $orderedProjects) {
    $pending = if ($null -eq $project.pendingTaskCount) { "unknown" } else { [string]$project.pendingTaskCount }
    $markdown += "| $($project.name) | $($project.statusColor) | $($project.branch) | $($project.cleanState) | $($project.lastCheckpointVerdict) | $($project.lastBuildResult) | $pending | $($project.nextRecommendedAction) |"
}

$markdown += ""
$markdown += "Controls are request-only links: quick mission request, cooperative stop request, and status/log navigation. They are not command execution or approval."
$markdown | Set-Content -LiteralPath $markdownPath -Encoding UTF8

Write-Host "Wrote $jsonPath"
Write-Host "Wrote $markdownPath"
