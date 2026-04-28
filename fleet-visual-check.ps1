[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string[]]$Project = @(),

    [string[]]$ExcludeProject = @(),

    [switch]$NoFailOnFindings,

    [switch]$WriteShipReports,

    [switch]$VerboseRunner,

    [switch]$RefreshGallery
)

$ErrorActionPreference = "Continue"

function Get-ConfigPropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-FreeTcpPort {
    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), 0)
    $listener.Start()
    $port = $listener.LocalEndpoint.Port
    $listener.Stop()
    return $port
}

function Add-ArrayArgument {
    param(
        [string[]]$Arguments,
        [string]$Name,
        [object[]]$Values
    )

    $items = @($Values | ForEach-Object { [string]$_ } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    if ($items.Count -eq 0) { return $Arguments }
    return @($Arguments + @($Name, ($items -join ",")))
}

function Get-LatestVisualSummary {
    param(
        [string]$RepoPath,
        [datetime]$Since = [datetime]::MinValue
    )

    $logRoot = Join-Path $RepoPath ".codex-logs"
    $latest = @(Get-ChildItem $logRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^visual-inspect-" } |
        Where-Object { $_.LastWriteTime -ge $Since } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1)
    if ($latest.Count -eq 0) { return $null }

    $summaryPath = Join-Path $latest[0].FullName "visual-inspect-summary.json"
    if (!(Test-Path $summaryPath)) { return $null }

    try {
        $summary = Get-Content $summaryPath -Raw | ConvertFrom-Json
        return [pscustomobject]@{
            runPath = $latest[0].FullName
            summary = $summary
        }
    } catch {
        return $null
    }
}

function Write-FleetVisualReport {
    param([object[]]$Results)

    New-Item -ItemType Directory -Force -Path "out" | Out-Null
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $jsonPath = "out\fleet-visual-check.json"
    $mdPath = "out\fleet-visual-check.md"

    $Results | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath

    $lines = @(
        "# Fleet Visual Check",
        "",
        "Generated: $timestamp",
        "",
        "This is the direct screenshot QA lane. It launches each selected ship, captures configured routes at desktop and mobile sizes, checks for console warnings/errors, horizontal overflow, clipped text, covered headings, and small tap targets, then writes ship-local artifacts.",
        "",
        "## Results",
        ""
    )

    foreach ($result in $Results) {
        $status = if ($result.status) { $result.status } elseif ($result.exitCode -eq 0) { "PASS" } elseif ($result.exitCode -eq 2) { "SKIP" } else { "FAIL" }
        $lines += "### $($result.project) - $status"
        $lines += ""
        $lines += "- Repo: $($result.repo)"
        $lines += "- Exit code: $($result.exitCode)"
        if (![string]::IsNullOrWhiteSpace([string]$result.message)) {
            $lines += "- Note: $($result.message)"
        }
        if ($result.summaryPath) {
            $lines += "- Summary: $($result.summaryPath)"
        }
        if ($result.reportPath) {
            $lines += "- Report: $($result.reportPath)"
        }
        if ($result.artifactPath) {
            $lines += "- Screenshots: $($result.artifactPath)"
        }
        $lines += "- Findings: high $($result.highFindings), medium $($result.mediumFindings), low $($result.lowFindings)"
        if ($result.topFindings -and @($result.topFindings).Count -gt 0) {
            $lines += ""
            $lines += "Top finding groups:"
            foreach ($finding in @($result.topFindings)) {
                $lines += ("- {0}x [{1}] {2} on {3} ({4}): {5}" -f $finding.count, ([string]$finding.severity).ToUpperInvariant(), $finding.type, $finding.route, $finding.viewport, $finding.message)
                if (![string]::IsNullOrWhiteSpace([string]$finding.evidence)) {
                    $lines += "  Evidence: $($finding.evidence)"
                }
                if (![string]::IsNullOrWhiteSpace([string]$finding.screenshotPath)) {
                    $lines += "  Screenshot: $($finding.screenshotPath)"
                }
            }
        }
        $lines += ""
    }

    Set-Content -Path $mdPath -Value $lines
}

function Get-TopVisualFindings {
    param(
        [object[]]$Findings,
        [int]$Limit = 6
    )

    if ($Findings.Count -eq 0) { return @() }

    return @($Findings |
        Group-Object -Property severity, type, route, viewport |
        Sort-Object Count -Descending |
        Select-Object -First $Limit |
        ForEach-Object {
            $sample = @($_.Group | Select-Object -First 1)[0]
            [pscustomobject]@{
                count = $_.Count
                severity = $sample.severity
                type = $sample.type
                route = $sample.route
                viewport = $sample.viewport
                message = $sample.message
                evidence = $sample.evidence
                screenshotPath = $sample.screenshotPath
            }
        })
}

if (!(Test-Path $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$fleetRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$projects = @($parsedProjects | ForEach-Object { $_ })

if ($Project.Count -gt 0) {
    $projectSet = @{}
    foreach ($name in $Project) { $projectSet[$name] = $true }
    $projects = @($projects | Where-Object { $projectSet.ContainsKey([string]$_.name) })
}

if ($ExcludeProject.Count -gt 0) {
    $excludeSet = @{}
    foreach ($name in $ExcludeProject) { $excludeSet[$name] = $true }
    $projects = @($projects | Where-Object { !$excludeSet.ContainsKey([string]$_.name) })
}

if ($projects.Count -eq 0) {
    Write-Host "No projects selected for visual QA." -ForegroundColor Red
    Write-FleetVisualReport -Results @([pscustomobject]@{
        project = "(none)"
        repo = ""
        exitCode = 2
        rawExitCode = 2
        status = "SKIP"
        message = "No projects matched the requested filter."
        artifactPath = ""
        summaryPath = ""
        reportPath = ""
        highFindings = 0
        mediumFindings = 0
        lowFindings = 0
    })
    exit 2
}

$results = @()
foreach ($projectConfig in $projects) {
    $repoMatches = @(Resolve-Path $projectConfig.repo -ErrorAction SilentlyContinue)
    if ($repoMatches.Count -ne 1) {
        $results += [pscustomobject]@{
            project = $projectConfig.name
            repo = $projectConfig.repo
            exitCode = 2
            message = "Repo missing or ambiguous."
            highFindings = 0
            mediumFindings = 0
            lowFindings = 0
        }
        continue
    }

    $repoPath = $repoMatches[0].Path
    $serveDir = [string](Get-ConfigPropertyValue -Object $projectConfig -Name "buildDirectory")
    if ([string]::IsNullOrWhiteSpace($serveDir)) { $serveDir = "." }
    $visualServeDir = [string](Get-ConfigPropertyValue -Object $projectConfig -Name "visualServeDirectory")
    if (![string]::IsNullOrWhiteSpace($visualServeDir)) { $serveDir = $visualServeDir }
    $visualPaths = @(Get-ConfigPropertyValue -Object $projectConfig -Name "visualPaths")
    if ($visualPaths.Count -eq 0) { $visualPaths = @("/") }

    $args = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "visual-inspect.ps1"),
        "-Repo", $repoPath,
        "-Project", $projectConfig.name,
        "-ServeDirectory", $serveDir,
        "-Port", (Get-FreeTcpPort),
        "-ChromePort", (Get-FreeTcpPort)
    )
    $args = Add-ArrayArgument -Arguments $args -Name "-Paths" -Values $visualPaths
    if ($NoFailOnFindings) {
        $args += "-NoFailOnFindings"
    }
    if (!$WriteShipReports) {
        $args += "-SkipShipReport"
    }
    if (!$VerboseRunner) {
        $args += "-Quiet"
    }

    Write-Host "Running visual QA for $($projectConfig.name)..." -ForegroundColor Cyan
    $startedAt = Get-Date
    & powershell -NoProfile -ExecutionPolicy Bypass @args
    $rawExitCode = if ($null -eq $LASTEXITCODE) { 1 } else { [int]$LASTEXITCODE }

    $latest = Get-LatestVisualSummary -RepoPath $repoPath -Since $startedAt
    $summary = if ($latest) { $latest.summary } else { $null }
    $findings = if ($summary -and $summary.findings) { @($summary.findings) } else { @() }
    $highFindings = @($findings | Where-Object { $_.severity -eq "high" }).Count
    $mediumFindings = @($findings | Where-Object { $_.severity -eq "medium" }).Count
    $lowFindings = @($findings | Where-Object { $_.severity -eq "low" }).Count
    $topFindings = @(Get-TopVisualFindings -Findings $findings)
    $status = "PASS"
    $message = "Visual QA completed."
    $exitCode = $rawExitCode

    if (!$latest) {
        $status = "INFRA_FAIL"
        $message = "Visual QA did not produce a fresh summary. Treat this as a harness/server/browser failure, not a visual finding."
        $exitCode = 1
    } elseif ($rawExitCode -ne 0) {
        $status = "FAIL"
        $message = "Visual QA returned exit code $rawExitCode."
    } elseif ($highFindings -gt 0) {
        $status = "FINDINGS"
        $message = if ($NoFailOnFindings) { "Blocking visual findings were recorded but tolerated for this run." } else { "Blocking visual findings were recorded." }
        if (!$NoFailOnFindings) {
            $exitCode = 1
        }
    } elseif (($mediumFindings + $lowFindings) -gt 0) {
        $status = "WARN"
        $message = "Visual QA completed with non-blocking findings."
    }

    $results += [pscustomobject]@{
        project = $projectConfig.name
        repo = $repoPath
        exitCode = $exitCode
        rawExitCode = $rawExitCode
        status = $status
        message = $message
        artifactPath = if ($latest) { $latest.runPath } else { "" }
        summaryPath = if ($latest) { Join-Path $latest.runPath "visual-inspect-summary.json" } else { "" }
        reportPath = if ($latest) {
            if ($WriteShipReports) { Join-Path $repoPath "docs\codex\VISUAL_BUGS.md" } else { Join-Path $latest.runPath "VISUAL_BUGS.md" }
        } else {
            ""
        }
        highFindings = $highFindings
        mediumFindings = $mediumFindings
        lowFindings = $lowFindings
        topFindings = $topFindings
    }
}

Write-FleetVisualReport -Results $results

if ($RefreshGallery) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "visual-gallery.ps1")
}

$failed = @($results | Where-Object { $_.exitCode -ne 0 -and $_.exitCode -ne 2 })
if ($failed.Count -gt 0) {
    Write-Host "Fleet visual check found blocking visual issues. Report: out\fleet-visual-check.md" -ForegroundColor Red
    exit 1
}

Write-Host "Fleet visual check complete. Report: out\fleet-visual-check.md" -ForegroundColor Green
exit 0
