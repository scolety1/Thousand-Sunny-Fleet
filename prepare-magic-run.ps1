[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string[]]$ExcludeProject = @(),

    [string]$OutFile = "out\magic-run-preflight.md",

    [int]$MinUncheckedTasks = 1,

    [switch]$Template,

    [switch]$AllowNoTasks,

    [switch]$Strict
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-Projects {
    if (!(Test-Path $ConfigPath)) {
        Stop-WithMessage "Config not found: $ConfigPath"
    }

    $parsed = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsed | ForEach-Object { $_ })
    if (![string]::IsNullOrWhiteSpace($Project)) {
        $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
        if ($projects.Count -ne 1) {
            Stop-WithMessage "Project not found: $Project"
        }
    }

    $exclude = @($ExcludeProject | ForEach-Object { ([string]$_) -split "," } | ForEach-Object { [string]$_.Trim() } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($exclude.Count -gt 0) {
        $projects = @($projects | Where-Object { $exclude -notcontains [string]$_.name })
    }

    return $projects
}

function Get-UncheckedTaskCount {
    param([string]$Repo)

    $queuePath = Join-Path $Repo "docs\codex\TASK_QUEUE.md"
    if (!(Test-Path -LiteralPath $queuePath)) { return 0 }
    return @(Select-String -Path $queuePath -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue).Count
}

function Test-UsefulMarkdown {
    param(
        [string]$Path,
        [string[]]$RequiredHeadings
    )

    if (!(Test-Path -LiteralPath $Path)) { return $false }
    $text = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($text)) { return $false }
    foreach ($heading in $RequiredHeadings) {
        $headingPattern = if ($heading -match "^Pack\s+\d+\s+-") {
            $packPrefix = [regex]::Match($heading, "^(Pack\s+\d+)\s+-").Groups[1].Value
            "(?im)^##\s+$([regex]::Escape($packPrefix))\s+-\s+.+$"
        } else {
            "(?im)^##\s+$([regex]::Escape($heading))\s*$"
        }
        if ($text -notmatch $headingPattern) {
            return $false
        }
    }
    if ($text -match "(?im)^\s*(TBD\.?|TODO|-\s+TBD\.?)\s*$") {
        return $false
    }
    if ($text -match "(?i)Describe the|Name the real user|State the promise|List the observable outcomes") {
        return $false
    }
    return $true
}

function Get-ActiveWorkPack {
    param([string]$Path)

    if (!(Test-Path -LiteralPath $Path)) { return "" }
    $text = Get-Content -LiteralPath $Path -Raw
    $activeLine = [regex]::Match($text, "(?im)^-\s*(Pack\s+\d+\s+-\s+[^:]+):\s*ACTIVE\s*$")
    if ($activeLine.Success) {
        return $activeLine.Groups[1].Value.Trim()
    }

    $activeHeading = [regex]::Match($text, "(?ims)^##\s+Active Work Pack\s*\r?\n\s*(Pack\s+\d+\s+-\s+[^\r\n]+)")
    if ($activeHeading.Success) {
        return $activeHeading.Groups[1].Value.Trim()
    }

    return ""
}

function Test-WorkPackStatus {
    param([string]$Path)

    if (!(Test-Path -LiteralPath $Path)) { return $false }
    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -notmatch "(?im)^##\s+Active Work Pack\s*$") { return $false }
    if ($text -notmatch "(?im)^##\s+Pack Status\s*$") { return $false }
    $activeMatches = [regex]::Matches($text, "(?im)^-\s*Pack\s+\d+\s+-\s+[^:]+:\s*ACTIVE\s*$")
    if ($activeMatches.Count -ne 1) { return $false }
    if ($text -match "(?im)^\s*(TBD\.?|TODO|-\s+TBD\.?)\s*$") { return $false }
    return $true
}

function Get-LockStatus {
    param([string]$ProjectName)

    $safeName = ([string]$ProjectName) -replace "[^a-zA-Z0-9_.-]+", "-"
    $safeName = $safeName.Trim("-")
    $lockPath = Join-Path $fleetRoot ".codex-local\locks\$safeName.lock.json"
    if (!(Test-Path -LiteralPath $lockPath)) {
        return "none"
    }

    try {
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        $pidValue = [int]$lock.pid
        if ($pidValue -gt 0 -and (Get-Process -Id $pidValue -ErrorAction SilentlyContinue)) {
            return "active PID $pidValue"
        }
        return "stale PID $pidValue"
    } catch {
        return "unreadable"
    }
}

function Write-MagicTemplates {
    param(
        [string]$Repo,
        [string]$ShipName
    )

    $codexDir = Join-Path $Repo "docs\codex"
    New-Item -ItemType Directory -Force -Path $codexDir | Out-Null

    $missionPath = Join-Path $codexDir "MAGIC_MISSION.md"
    if (!(Test-Path -LiteralPath $missionPath)) {
        Set-Content -LiteralPath $missionPath -Value @"
# Magic Mission

## 12-Hour Outcome

Describe the product state that would feel meaningfully better after one unattended long run.

## Target User

Name the real user and the job this product should help them finish.

## Product Promise

State the promise the interface, copy, and core workflow should keep.

## Visual Direction

Describe the taste, density, interaction style, and examples Simon should preserve.

## Non-Goals

- Do not change secrets, auth, payments, deployment config, backend config, package files, generated build output, or production data without explicit approval.

## Definition Of Magic

List the observable outcomes that would make the next morning feel successful.
"@
    }

    $workPackPath = Join-Path $codexDir "WORK_PACKS.md"
    if (!(Test-Path -LiteralPath $workPackPath)) {
        Set-Content -LiteralPath $workPackPath -Value @"
# Work Packs

## Pack 1 - Product Spine

- Goal: Make the first screen and primary workflow feel intentional, specific, and useful.
- Done when: A user can tell what $ShipName is for, what to do first, and why it is better than a generic demo.

## Pack 2 - Interaction Quality

- Goal: Tighten the main repeated controls, empty states, mobile layout, and feedback states.
- Done when: The app feels usable on desktop and mobile without awkward spacing, vague labels, or fragile tap targets.

## Pack 3 - Voice And Trust

- Goal: Replace generic claims with concrete product language and remove anything that sounds overpromised.
- Done when: Robin would call the copy specific, calm, and credible.

## Pack 4 - Finish Pass

- Goal: Address Simon, visual inspection, Robin, Joey, checkpoint, and runtime findings before inventing more work.
- Done when: Reports are GREEN/YELLOW without repeated repair orders.
"@
    }

    $scorePath = Join-Path $codexDir "MAGIC_SCORECARD.md"
    if (!(Test-Path -LiteralPath $scorePath)) {
        Set-Content -LiteralPath $scorePath -Value @"
# Magic Scorecard

This file is appended by Codex Fleet after successful, blocked, or quarantined checkpoint-loop tasks.
"@
    }

    $statusPath = Join-Path $codexDir "WORK_PACK_STATUS.md"
    if (!(Test-Path -LiteralPath $statusPath)) {
        Set-Content -LiteralPath $statusPath -Value @"
# Work Pack Status

## Active Work Pack

Pack 1 - Product Spine

## Pack Status

- Pack 1 - Product Spine: ACTIVE
- Pack 2 - Interaction Quality: PENDING
- Pack 3 - Voice And Trust: PENDING
- Pack 4 - Finish Pass: PENDING

## Completion Rules

- Mark a pack DONE only when its done-when line in WORK_PACKS.md is satisfied and Simon/checkpoint reports do not repeat the same blocker.
- Move exactly one next pack to ACTIVE before the next long run.
"@
    }
}

if ($MinUncheckedTasks -lt 0) {
    Stop-WithMessage "-MinUncheckedTasks must be 0 or greater."
}

$projects = @(Get-Projects)
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines = @(
    "# Magic Run Preflight",
    "",
    "Generated: $timestamp",
    "",
    "| Ship | Result | Dirty | Tasks | Lock | Mission | Work Packs | Active Pack | Scorecard | Notes |",
    "| --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- |"
)

$blocked = 0
$warnings = 0
foreach ($ship in $projects) {
    $repo = [string]$ship.repo
    if (!(Test-Path -LiteralPath $repo)) {
        $lines += "| $($ship.name) | BLOCKED | n/a | 0 | n/a | missing | missing | missing | missing | Repo not found: $repo |"
        $blocked++
        continue
    }

    if ($Template) {
        Write-MagicTemplates -Repo $repo -ShipName ([string]$ship.name)
    }

    Push-Location $repo
    $dirty = @(git status --short 2>$null)
    Pop-Location

    $dirtyText = if ($dirty.Count -eq 0) { "clean" } else { "dirty $($dirty.Count)" }
    $taskCount = Get-UncheckedTaskCount -Repo $repo
    $lockStatus = Get-LockStatus -ProjectName ([string]$ship.name)
    $missionPath = Join-Path $repo "docs\codex\MAGIC_MISSION.md"
    $workPackPath = Join-Path $repo "docs\codex\WORK_PACKS.md"
    $workPackStatusPath = Join-Path $repo "docs\codex\WORK_PACK_STATUS.md"
    $scorePath = Join-Path $repo "docs\codex\MAGIC_SCORECARD.md"
    $missionOk = Test-UsefulMarkdown -Path $missionPath -RequiredHeadings @("12-Hour Outcome", "Target User", "Product Promise", "Visual Direction", "Non-Goals", "Definition Of Magic")
    $workPackOk = Test-UsefulMarkdown -Path $workPackPath -RequiredHeadings @("Pack 1 - Product Spine", "Pack 2 - Interaction Quality", "Pack 3 - Voice And Trust", "Pack 4 - Finish Pass")
    $workPackStatusOk = Test-WorkPackStatus -Path $workPackStatusPath
    $activePack = Get-ActiveWorkPack -Path $workPackStatusPath
    $scoreOk = Test-Path -LiteralPath $scorePath

    $notes = [System.Collections.Generic.List[string]]::new()
    $result = "READY"
    if ($dirty.Count -gt 0) {
        $result = "BLOCKED"
        $notes.Add("working tree dirty") | Out-Null
    }
    if ($lockStatus -match "^active") {
        $result = "BLOCKED"
        $notes.Add("active run lock") | Out-Null
    }
    if (-not $missionOk) {
        if ($result -ne "BLOCKED") { $result = "WARN" }
        $notes.Add("needs MAGIC_MISSION.md") | Out-Null
    }
    if (-not $workPackOk) {
        if ($result -ne "BLOCKED") { $result = "WARN" }
        $notes.Add("needs WORK_PACKS.md") | Out-Null
    }
    if (-not $workPackStatusOk) {
        if ($result -ne "BLOCKED") { $result = "WARN" }
        $notes.Add("needs WORK_PACK_STATUS.md with one ACTIVE pack") | Out-Null
    }
    if (-not $scoreOk) {
        if ($result -ne "BLOCKED") { $result = "WARN" }
        $notes.Add("needs scorecard seed") | Out-Null
    }
    if (!$AllowNoTasks -and $taskCount -lt $MinUncheckedTasks) {
        if ($result -ne "BLOCKED") { $result = "WARN" }
        $notes.Add("planner must generate tasks at launch") | Out-Null
    }

    if ($result -eq "BLOCKED") { $blocked++ }
    elseif ($result -eq "WARN") { $warnings++ }

    $missionText = if ($missionOk) { "ready" } else { "missing/incomplete" }
    $workPackText = if ($workPackOk) { "ready" } else { "missing/incomplete" }
    $activePackText = if ($workPackStatusOk) { $activePack } else { "missing/incomplete" }
    $scoreText = if ($scoreOk) { "ready" } else { "missing" }
    $noteText = if ($notes.Count -gt 0) { ($notes -join "; ") } else { "ok" }
    $lines += "| $($ship.name) | $result | $dirtyText | $taskCount | $lockStatus | $missionText | $workPackText | $activePackText | $scoreText | $noteText |"
}

$lines += ""
$strictNote = if ($Strict) { " Strict mode treats warnings as launch blockers." } else { "" }
$lines += "Summary: $($projects.Count) checked, $blocked blocked, $warnings warnings.$strictNote"
$lines += ""
$lines += "Use `-Template` to install starter MAGIC_MISSION.md, WORK_PACKS.md, and MAGIC_SCORECARD.md files. Fill the templates before expecting a true 12-hour magic run."

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
Set-Content -Path $OutFile -Value $lines

Write-Host "Magic run preflight: $OutFile" -ForegroundColor Cyan
Write-Host "Checked $($projects.Count) ships: $blocked blocked, $warnings warnings."
if ($blocked -gt 0 -or ($Strict -and $warnings -gt 0)) {
    exit 1
}
exit 0
