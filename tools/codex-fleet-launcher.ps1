function ConvertTo-FleetLaunchSafeName {
    param([string]$Name)

    $safeName = if ([string]::IsNullOrWhiteSpace($Name)) { "ALL" } else { ([string]$Name) -replace "[^a-zA-Z0-9_.-]+", "-" }
    $safeName = $safeName.Trim("-")
    if ([string]::IsNullOrWhiteSpace($safeName)) { return "ALL" }
    return $safeName
}

function Get-FleetSafeStopRequests {
    param([string]$FleetRoot)

    $stopRoot = Join-Path $FleetRoot ".codex-local\stop-requests"
    if (!(Test-Path $stopRoot)) {
        return @()
    }

    return @(Get-ChildItem -Path $stopRoot -Filter "*.stop.json" -File -ErrorAction SilentlyContinue | ForEach-Object {
        $target = ($_.Name -replace "\.stop\.json$", "")
        try {
            $parsed = Get-Content $_.FullName -Raw | ConvertFrom-Json
            if (![string]::IsNullOrWhiteSpace([string]$parsed.target)) {
                $target = [string]$parsed.target
            }
        } catch {
            $target = ($_.Name -replace "\.stop\.json$", "")
        }

        [pscustomobject]@{
            target = $target
            safeTarget = ConvertTo-FleetLaunchSafeName -Name $target
            path = $_.FullName
            lastWriteTime = $_.LastWriteTime
        }
    })
}

function Assert-NoFleetSafeStopRequests {
    param(
        [string]$FleetRoot,
        [string]$ProjectFilter = "",
        [string[]]$ProjectScope = @(),
        [string[]]$ExcludeProject = @(),
        [switch]$AllowSafeStopRequests
    )

    $requests = @(Get-FleetSafeStopRequests -FleetRoot $FleetRoot)
    if ($requests.Count -eq 0 -or $AllowSafeStopRequests) {
        return
    }

    $safeProject = ConvertTo-FleetLaunchSafeName -Name $ProjectFilter
    $safeScope = @($ProjectScope | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object {
        ConvertTo-FleetLaunchSafeName -Name ([string]$_)
    } | Sort-Object -Unique)
    $safeExclusions = @($ExcludeProject | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object {
        ConvertTo-FleetLaunchSafeName -Name ([string]$_)
    })
    $blocking = @($requests | Where-Object {
        if ($safeExclusions -contains $_.safeTarget) {
            return $false
        }
        if ($safeScope.Count -gt 0) {
            return (
                $_.safeTarget -eq "ALL" -or
                $safeScope -contains $_.safeTarget
            )
        }
        return (
            [string]::IsNullOrWhiteSpace($ProjectFilter) -or
            $_.safeTarget -eq "ALL" -or
            $_.safeTarget -eq $safeProject
        )
    })

    if ($blocking.Count -eq 0) {
        return
    }

    Write-Host "Launch refused because safe stop request(s) are active." -ForegroundColor Red
    foreach ($request in $blocking) {
        Write-Host "- $($request.target): $($request.path)" -ForegroundColor Yellow
    }
    Write-Host "Clear them first, for example:" -ForegroundColor Cyan
    Write-Host "  .\request-safe-stop.ps1 -List" -ForegroundColor Cyan
    Write-Host "  .\request-safe-stop.ps1 -All -Clear" -ForegroundColor Cyan
    if (![string]::IsNullOrWhiteSpace($ProjectFilter)) {
        Write-Host "  .\request-safe-stop.ps1 -Project $ProjectFilter -Clear" -ForegroundColor Cyan
    }
    Write-Host "Or rerun with -AllowSafeStopRequests if you intentionally want the new loop to exit immediately." -ForegroundColor Cyan
    exit 1
}

function New-FleetLaunchManifest {
    param(
        [string]$FleetRoot,
        [string]$Mode,
        [string]$ConfigPath,
        [string]$ProjectFilter = "",
        [string]$LatestFileName = "latest-launch.md"
    )

    $launchId = "{0}-{1}" -f (Get-Date -Format "yyyyMMdd-HHmmss-fff"), ([guid]::NewGuid().ToString("N").Substring(0, 6))
    $launchRoot = Join-Path $FleetRoot ".codex-local\launches"
    New-Item -ItemType Directory -Force -Path $launchRoot | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $FleetRoot "out") | Out-Null

    return [pscustomobject]@{
        id = $launchId
        mode = $Mode
        configPath = $ConfigPath
        projectFilter = $ProjectFilter
        startedAt = (Get-Date).ToString("o")
        jsonPath = (Join-Path $launchRoot "$launchId-$Mode.json")
        markdownPath = (Join-Path $FleetRoot "out\$LatestFileName")
        entries = [System.Collections.ArrayList]::new()
    }
}

function Add-FleetLaunchManifestEntry {
    param(
        [object]$Manifest,
        [string]$Ship,
        [string]$Command,
        [int]$ProcessId = 0,
        [switch]$DryRun
    )

    [void]$Manifest.entries.Add([pscustomobject]@{
        ship = $Ship
        processId = $ProcessId
        dryRun = [bool]$DryRun
        launchedAt = (Get-Date).ToString("o")
        command = $Command
    })
}

function Write-FleetLaunchManifest {
    param([object]$Manifest)

    $entries = @($Manifest.entries | ForEach-Object { $_ })
    $json = [pscustomobject]@{
        id = $Manifest.id
        mode = $Manifest.mode
        configPath = $Manifest.configPath
        projectFilter = $Manifest.projectFilter
        startedAt = $Manifest.startedAt
        writtenAt = (Get-Date).ToString("o")
        entries = $entries
    }

    $json | ConvertTo-Json -Depth 6 | Set-Content -Path $Manifest.jsonPath -Encoding UTF8

    $projectFilterText = if ([string]::IsNullOrWhiteSpace($Manifest.projectFilter)) { "all ships" } else { $Manifest.projectFilter }
    $lines = @(
        "# Codex Fleet Latest Launch",
        "",
        "- Launch: $($Manifest.id)",
        "- Mode: $($Manifest.mode)",
        "- Started: $($Manifest.startedAt)",
        "- Config: $($Manifest.configPath)",
        "- Project filter: $projectFilterText",
        "",
        "| Ship | PID | Dry Run |",
        "| --- | ---: | --- |"
    )

    foreach ($entry in $entries) {
        $lines += "| $($entry.ship) | $($entry.processId) | $($entry.dryRun) |"
    }

    $lines += @(
        "",
        "## Commands",
        ""
    )

    foreach ($entry in $entries) {
        $lines += @(
            "### $($entry.ship)",
            "",
            '```powershell',
            $entry.command,
            '```',
            ""
        )
    }

    Set-Content -Path $Manifest.markdownPath -Value $lines -Encoding UTF8
    Write-Host "Launch manifest: $($Manifest.markdownPath)" -ForegroundColor Green
    Write-Host "Raw launch data: $($Manifest.jsonPath)" -ForegroundColor DarkCyan
}
