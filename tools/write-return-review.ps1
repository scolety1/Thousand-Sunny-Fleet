[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$OutFile
)

$ErrorActionPreference = "Stop"

function Resolve-TsfPath {
    param(
        [string]$Root,
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $Root $Path
}

function Get-TsfText {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    }

    return ""
}

function Get-TsfStatusLine {
    param(
        [string]$Text,
        [string]$Label,
        [string]$Default = "unknown"
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $Default
    }

    $pattern = "(?im)^-\s+$([regex]::Escape($Label))\s*:\s*(.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }

    return $Default
}

function Get-TsfProjectSnapshot {
    param([string]$Root)

    $statusPath = Join-Path $Root "fleet\status\projects.json"
    $registryPath = Join-Path $Root "projects.json"

    if (Test-Path -LiteralPath $statusPath) {
        $snapshot = Get-Content -LiteralPath $statusPath -Raw -ErrorAction Stop | ConvertFrom-Json
        return [pscustomobject]@{
            Source = "fleet/status/projects.json"
            Projects = @($snapshot.projects)
            Note = "public-safe project snapshot"
        }
    }

    if (Test-Path -LiteralPath $registryPath) {
        $registryProjects = @(Get-Content -LiteralPath $registryPath -Raw -ErrorAction Stop | ConvertFrom-Json | ForEach-Object {
            $archived = ($null -ne $_.PSObject.Properties["archived"] -and [bool]$_.archived)
            [pscustomobject]@{
                name = [string]$_.name
                statusColor = if ($archived) { "ARCHIVED" } else { "UNKNOWN" }
                archived = $archived
                nextRecommendedAction = if ($archived) { "Leave archived unless Tim reactivates it." } else { "Open from desktop to inspect safely." }
            }
        })

        return [pscustomobject]@{
            Source = "projects.json"
            Projects = $registryProjects
            Note = "registry names and archived flags only"
        }
    }

    return [pscustomobject]@{
        Source = "safe fixture fallback"
        Projects = @()
        Note = "no project snapshot found"
    }
}

function Format-TsfList {
    param(
        [object[]]$Items,
        [string]$Empty = "none"
    )

    $names = @($Items | ForEach-Object { [string]$_.name } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($names.Count -eq 0) {
        return $Empty
    }

    if ($names.Count -le 4) {
        return $names -join ", "
    }

    return "$(($names | Select-Object -First 4) -join ", "), plus $($names.Count - 4) more"
}

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

$fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = Join-Path $fleetRootFull "fleet\status\return-review.md"
} else {
    $OutFile = Resolve-TsfPath -Root $fleetRootFull -Path $OutFile
}

$currentPath = Join-Path $fleetRootFull "fleet\status\current.md"
$todayPath = Join-Path $fleetRootFull "fleet\status\today.md"
$projectsMdPath = Join-Path $fleetRootFull "fleet\status\projects.md"
$consolePath = Join-Path $fleetRootFull "docs\fleet\ui\prototype\fleet-console.html"
$consoleReadmePath = Join-Path $fleetRootFull "docs\fleet\ui\prototype\README.md"
$projectManagementDocPath = Join-Path $fleetRootFull "docs\fleet\TSF_AUTONOMOUS_PROJECT_MANAGEMENT_V1.md"
$artifactIntakeDocPath = Join-Path $fleetRootFull "docs\fleet\TSF_ARTIFACT_INTAKE_FOLDER_SYSTEM.md"
$fixturePath = Join-Path $fleetRootFull "tests\fixtures\fleet\ui-control\fleet-console-state.green-local-harness.json"

$currentText = Get-TsfText -Path $currentPath
$todayText = Get-TsfText -Path $todayPath
$consoleText = Get-TsfText -Path $consolePath
$consoleReadme = Get-TsfText -Path $consoleReadmePath
$snapshot = Get-TsfProjectSnapshot -Root $fleetRootFull
$projects = @($snapshot.Projects)

$archivedProjects = @($projects | Where-Object { $null -ne $_.PSObject.Properties["archived"] -and [bool]$_.archived })
$activeProjects = @($projects | Where-Object { !($null -ne $_.PSObject.Properties["archived"] -and [bool]$_.archived) })
$blockedProjects = @($projects | Where-Object { [string]$_.statusColor -match "^(RED|BLOCKED)$" })
$readyProjects = @($projects | Where-Object { [string]$_.statusColor -match "^(GREEN|READY)$" })

$fleetMode = Get-TsfStatusLine -Text $currentText -Label "Fleet mode" -Default (Get-TsfStatusLine -Text $todayText -Label "Fleet mode" -Default "unknown")
$supervisor = Get-TsfStatusLine -Text $currentText -Label "Supervisor cycle" -Default (Get-TsfStatusLine -Text $todayText -Label "Supervisor" -Default "unknown")
$emergency = Get-TsfStatusLine -Text $currentText -Label "Emergency stop" -Default (Get-TsfStatusLine -Text $todayText -Label "Emergency" -Default "unknown")
$travelPosture = Get-TsfStatusLine -Text $currentText -Label "Travel posture" -Default (Get-TsfStatusLine -Text $todayText -Label "Travel posture" -Default "unknown")

$hasConsoleTriage = ($consoleText -match "What do I do now\?") -and ($consoleText -match "Work Order Library")
$hasReturnReviewDocs = ($consoleReadme -match "return-review.md") -or ($consoleReadme -match "Return Review")
$hasContracts = (Test-Path -LiteralPath $projectManagementDocPath) -and (Test-Path -LiteralPath $artifactIntakeDocPath)
$hasFixtureFallback = Test-Path -LiteralPath $fixturePath
$hasProjectsMd = Test-Path -LiteralPath $projectsMdPath

$topRecommendation = "Open Fleet Console, read What do I do now?, then choose one project and availability: here, busy, or away."
if ($blockedProjects.Count -gt 0) {
    $topRecommendation = "Resolve the blocked project note before starting another batch."
} elseif ($emergency -notmatch "none|unknown") {
    $topRecommendation = "Review the emergency stop note before starting any work."
}

$changedLine = "Fleet mode is $fleetMode; supervisor is $supervisor; emergency is $emergency."
if ($hasConsoleTriage) {
    $changedLine += " The desktop console has Return Triage and Work Order Library copy/paste prompts."
}

$readyLine = "No push, release, deploy, install, migration, secrets, remote access, archived reactivation, or product-repo mutation is ready from this file."
if ($readyProjects.Count -gt 0) {
    $readyLine = "Ready project snapshots: $(Format-TsfList -Items $readyProjects). Still require exact human approval for publication or product-repo mutation."
}

$doneLine = "Routine GREEN work and archived project noise can stay collapsed unless Tim wants details."
if ($archivedProjects.Count -gt 0) {
    $doneLine += " $($archivedProjects.Count) archived projects remain locked."
}

$blockedLine = "Unsafe work remains blocked: product repos without selection, archived projects without reactivation, push/release/deploy, installs, migrations, secrets, remote access, all-fleet runners, proof runs, and command-running browser controls."
if ($blockedProjects.Count -gt 0) {
    $blockedLine = "Blocked projects: $(Format-TsfList -Items $blockedProjects). Pause for Tim before continuing those."
}

$sourceLine = "Sources: $($snapshot.Source)"
foreach ($source in @(
    @{ Path = $currentPath; Label = "fleet/status/current.md" },
    @{ Path = $todayPath; Label = "fleet/status/today.md" },
    @{ Path = $projectsMdPath; Label = "fleet/status/projects.md" },
    @{ Path = $consolePath; Label = "docs/fleet/ui/prototype/fleet-console.html" },
    @{ Path = $consoleReadmePath; Label = "docs/fleet/ui/prototype/README.md" },
    @{ Path = $projectManagementDocPath; Label = "TSF project-management contract" },
    @{ Path = $artifactIntakeDocPath; Label = "TSF artifact-intake contract" }
)) {
    if (Test-Path -LiteralPath $source.Path) {
        $sourceLine += ", $($source.Label)"
    }
}
if ($hasFixtureFallback) {
    $sourceLine += ", safe fixture fallback"
}

$reviewDocState = if ($hasReturnReviewDocs) { "documented" } else { "new in this pass" }
$projectsMdState = if ($hasProjectsMd) { "available" } else { "missing" }
$contractsState = if ($hasContracts) { "available" } else { "missing" }

$markdown = @"
# Return Review

Generated for Tim from TSF-local, read-only state. Keep this short.

## Top recommendation

$topRecommendation

## Needs Tim

- Choose the next project.
- Choose availability: here, busy, or away.
- Decide any product direction, conflicting source truth, release/push/deploy approval, secrets/accounts/API keys, migration, archived reactivation, or off-limits file expansion.

## Ready to approve

- $readyLine
- TSF-local console or handoff docs can be reviewed after tests pass, but this file does not approve anything by itself.

## Done while away

- $doneLine
- Status source: $($snapshot.Note). Active/unarchived projects: $(Format-TsfList -Items $activeProjects -Empty "none shown").

## Blocked / unsafe

- $blockedLine

## Next best work session

Quick review, 5-10 minutes. Read Fleet Console first, skim this file if needed, then send one bounded work order.

## Suggested next Codex prompt

~~~text
Project: <project name>
Repo path: <repo path>
Goal: <plain English goal>
Files/artifacts: <files, folders, or C:\TSF_INBOX\<project_name>\ artifacts>
Off-limits: product repos unless selected, archived projects unless reactivated, push/release/deploy, installs, migrations, secrets, remote access, all-fleet runners, proof runs, command-running browser controls.
Autonomy/availability mode: here | busy | away
Stop conditions: conflicting source truth, missing approval, unsafe file scope, failed validation that cannot be safely repaired, or any forbidden action.
Validation expectations: run the smallest relevant checks and summarize exact results.
Final report format: verdict, files changed, what changed, tests run, blockers, next safe action, safe-to-commit status.
~~~

## Source notes

- $changedLine
- Travel posture: $travelPosture.
- Projects markdown: $projectsMdState. Contracts: $contractsState. Return review docs: $reviewDocState.
- $sourceLine.
- Evidence only. No product repo inspection, no archived project reactivation, no proof run, no push, no deploy, no install, no migration, no secrets, no remote access, no hosted UI, and no command-running browser control.
"@

$outDirectory = Split-Path -Parent $OutFile
if (![string]::IsNullOrWhiteSpace($outDirectory)) {
    New-Item -ItemType Directory -Force -Path $outDirectory | Out-Null
}

$markdown.TrimEnd("`r", "`n") | Set-Content -LiteralPath $OutFile -Encoding UTF8
Write-Host "Wrote TSF return review to $OutFile"
Write-Host $sourceLine
