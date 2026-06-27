[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$FleetRoot,
    [string]$TemplatePath,
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

function ConvertTo-TsfHtml {
    param([object]$Value)

    if ($null -eq $Value) {
        return ""
    }

    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
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
            SafeNote = "Generated public-safe project snapshot is available and preferred over raw mock data."
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
            SafeNote = "Raw TSF registry was used only for project names and archived flags; product repos were not inspected."
        }
    }

    return [pscustomobject]@{
        Source = "safe fixture fallback"
        Projects = @()
        SafeNote = "No project snapshot or registry was found; console keeps safe fixture wording."
    }
}

if ([string]::IsNullOrWhiteSpace($FleetRoot)) {
    $FleetRoot = Split-Path -Parent $PSScriptRoot
}

$fleetRootFull = (Resolve-Path -LiteralPath $FleetRoot).Path

if ([string]::IsNullOrWhiteSpace($TemplatePath)) {
    $TemplatePath = Join-Path $fleetRootFull "docs\fleet\ui\prototype\fleet-console.html"
} else {
    $TemplatePath = Resolve-TsfPath -Root $fleetRootFull -Path $TemplatePath
}

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = $TemplatePath
} else {
    $OutFile = Resolve-TsfPath -Root $fleetRootFull -Path $OutFile
}

$currentPath = Join-Path $fleetRootFull "fleet\status\current.md"
$todayPath = Join-Path $fleetRootFull "fleet\status\today.md"
$projectsMdPath = Join-Path $fleetRootFull "fleet\status\projects.md"
$projectManagementDocPath = Join-Path $fleetRootFull "docs\fleet\TSF_AUTONOMOUS_PROJECT_MANAGEMENT_V1.md"
$artifactIntakeDocPath = Join-Path $fleetRootFull "docs\fleet\TSF_ARTIFACT_INTAKE_FOLDER_SYSTEM.md"
$fixturePath = Join-Path $fleetRootFull "tests\fixtures\fleet\ui-control\fleet-console-state.green-local-harness.json"

$currentText = Get-TsfText -Path $currentPath
$todayText = Get-TsfText -Path $todayPath
$snapshot = Get-TsfProjectSnapshot -Root $fleetRootFull
$projects = @($snapshot.Projects)

$totalProjects = $projects.Count
$archivedProjects = @($projects | Where-Object { $null -ne $_.PSObject.Properties["archived"] -and [bool]$_.archived }).Count
$activeProjects = [Math]::Max(0, $totalProjects - $archivedProjects)
$unknownProjects = @($projects | Where-Object { [string]$_.statusColor -eq "UNKNOWN" }).Count
$archivedSummary = if ($totalProjects -gt 0) { "$totalProjects projects / $archivedProjects archived locked" } else { "fixture fallback / archived locked" }
$activeSummary = if ($activeProjects -eq 1) { "1 unarchived project" } else { "$activeProjects unarchived projects" }
$fleetMode = Get-TsfStatusLine -Text $currentText -Label "Fleet mode" -Default "unknown"
$supervisor = Get-TsfStatusLine -Text $currentText -Label "Supervisor cycle" -Default (Get-TsfStatusLine -Text $todayText -Label "Supervisor" -Default "unknown")
$emergency = Get-TsfStatusLine -Text $currentText -Label "Emergency stop" -Default (Get-TsfStatusLine -Text $todayText -Label "Emergency" -Default "unknown")

$latestReports = @()
if (Test-Path -LiteralPath $currentPath) { $latestReports += "fleet/status/current.md" }
if (Test-Path -LiteralPath $todayPath) { $latestReports += "fleet/status/today.md" }
if (Test-Path -LiteralPath $projectsMdPath) { $latestReports += "fleet/status/projects.md" }
$latestReportSummary = if ($latestReports.Count -gt 0) { $latestReports -join ", " } else { "safe fixture data only" }

$contractSources = @()
if (Test-Path -LiteralPath $projectManagementDocPath) { $contractSources += "TSF_AUTONOMOUS_PROJECT_MANAGEMENT_V1.md" }
if (Test-Path -LiteralPath $artifactIntakeDocPath) { $contractSources += "TSF_ARTIFACT_INTAKE_FOLDER_SYSTEM.md" }
$contractSummary = if ($contractSources.Count -gt 0) { $contractSources -join ", " } else { "fixture-backed guidance" }
$fallbackSummary = if (Test-Path -LiteralPath $fixturePath) { "safe fixture data available for missing real state" } else { "safe fixture fallback missing" }

$stateHtml = @"
        <div class="state-source-grid" aria-label="Read-only generated state summary">
          <article>
            <span>State source</span>
            <strong>$(ConvertTo-TsfHtml $snapshot.Source)</strong>
            <p>$(ConvertTo-TsfHtml $snapshot.SafeNote)</p>
          </article>
          <article>
            <span>Fleet mode</span>
            <strong>$(ConvertTo-TsfHtml $fleetMode)</strong>
            <p>Supervisor: $(ConvertTo-TsfHtml $supervisor). Emergency: $(ConvertTo-TsfHtml $emergency). Evidence only, not command authority.</p>
          </article>
          <article>
            <span>Project registry</span>
            <strong>$(ConvertTo-TsfHtml $archivedSummary)</strong>
            <p>$(ConvertTo-TsfHtml $activeSummary). Unknown status count: $(ConvertTo-TsfHtml $unknownProjects). Archived projects remain visibly locked.</p>
          </article>
          <article>
            <span>Latest local reports</span>
            <strong>$(ConvertTo-TsfHtml $latestReportSummary)</strong>
            <p>Contracts: $(ConvertTo-TsfHtml $contractSummary). Fallback: $(ConvertTo-TsfHtml $fallbackSummary).</p>
          </article>
        </div>
"@

$html = Get-Content -LiteralPath $TemplatePath -Raw -ErrorAction Stop
$pattern = "(?s)<!-- TSF_RENDER_STATE_START -->.*?<!-- TSF_RENDER_STATE_END -->"
if ($html -notmatch $pattern) {
    throw "Fleet Console render markers were not found in $TemplatePath"
}

$replacement = "<!-- TSF_RENDER_STATE_START -->`r`n$stateHtml        <!-- TSF_RENDER_STATE_END -->"
$rendered = [regex]::Replace($html, $pattern, $replacement, 1)
$rendered = $rendered.TrimEnd("`r", "`n")

$outDirectory = Split-Path -Parent $OutFile
if (![string]::IsNullOrWhiteSpace($outDirectory)) {
    New-Item -ItemType Directory -Force -Path $outDirectory | Out-Null
}

$rendered | Set-Content -LiteralPath $OutFile -Encoding UTF8
Write-Host "Rendered static Fleet Console to $OutFile"
Write-Host "Read-only sources: $($snapshot.Source), fleet/status/current.md, fleet/status/today.md, fleet/status/projects.md, TSF docs, safe fixtures"
