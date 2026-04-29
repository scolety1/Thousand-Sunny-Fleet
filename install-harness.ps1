param(
    [Parameter(Mandatory = $true)]
    [string]$Repo,

    [ValidateSet("real-product", "frontend-static-demo", "docs-only", "experimental-prototype")]
    [string]$Profile = "frontend-static-demo",

    [int]$Rounds = 0,

    [switch]$Force,

    [switch]$AddToFleet
)

$ErrorActionPreference = "Continue"

$fleetRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoPath = Resolve-Path $Repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Write-Host "Repo path not found: $Repo" -ForegroundColor Red
    exit 1
}

$repoPath = $repoPath.Path
$profilePath = Join-Path $fleetRoot "profiles\$Profile.json"
if (!(Test-Path $profilePath)) {
    Write-Host "Profile not found: $profilePath" -ForegroundColor Red
    exit 1
}

$profileData = Get-Content $profilePath -Raw | ConvertFrom-Json
$roundCount = if ($Rounds -gt 0) { $Rounds } else { [int]$profileData.defaultRounds }

$copyMap = @(
    @{ Source = "templates\docs\codex\TASK_QUEUE.md"; Target = "docs\codex\TASK_QUEUE.md" },
    @{ Source = "templates\docs\codex\RUN_POLICY.md"; Target = "docs\codex\RUN_POLICY.md" },
    @{ Source = "templates\docs\codex\SITE_MAP.md"; Target = "docs\codex\SITE_MAP.md" },
    @{ Source = "templates\docs\codex\NIGHTLY_REPORT.md"; Target = "docs\codex\NIGHTLY_REPORT.md" },
    @{ Source = "templates\docs\codex\MISSION.md"; Target = "docs\codex\MISSION.md" },
    @{ Source = "templates\docs\codex\SHIP_SCORECARD.md"; Target = "docs\codex\SHIP_SCORECARD.md" },
    @{ Source = "templates\visual-routes.json"; Target = "docs\codex\visual-routes.json" },
    @{ Source = "templates\scripts\codex-brief.ps1"; Target = "scripts\codex-brief.ps1" },
    @{ Source = "templates\scripts\codex-guardrails.ps1"; Target = "scripts\codex-guardrails.ps1" },
    @{ Source = "templates\scripts\codex-night-loop.ps1"; Target = "scripts\codex-night-loop.ps1" }
)

foreach ($item in $copyMap) {
    $source = Join-Path $fleetRoot $item.Source
    $target = Join-Path $repoPath $item.Target
    $targetDir = Split-Path -Parent $target
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null

    if ((Test-Path $target) -and -not $Force) {
        Write-Host "Keeping existing $($item.Target)" -ForegroundColor Yellow
        continue
    }

    Copy-Item -Path $source -Destination $target -Force
    Write-Host "Installed $($item.Target)" -ForegroundColor Green
}

$profileOut = Join-Path $repoPath "docs\codex\PROFILE.json"
Copy-Item -Path $profilePath -Destination $profileOut -Force
Write-Host "Installed docs/codex/PROFILE.json" -ForegroundColor Green

if ($AddToFleet) {
    $configPath = Join-Path $fleetRoot "projects.json"
    $projects = @()
    if (Test-Path $configPath) {
        $projects = @(Get-Content $configPath -Raw | ConvertFrom-Json)
    }

    $name = Split-Path -Leaf $repoPath
    $existing = @($projects | Where-Object { $_.repo -eq $repoPath })
    if ($existing.Count -eq 0) {
        $projects += [pscustomobject]@{
            name = $name
            repo = $repoPath
            rounds = $roundCount
            briefScript = "scripts\codex-brief.ps1"
            loopScript = "scripts\codex-night-loop.ps1"
            buildDirectory = if ($profileData.buildDirectory) { [string]$profileData.buildDirectory } else { "." }
            buildCommand = if ($profileData.buildCommand) { [string]$profileData.buildCommand } else { "" }
            profile = $Profile
        }

        $projects | ConvertTo-Json -Depth 6 | Set-Content $configPath
        Write-Host "Added $name to projects.json" -ForegroundColor Green
    } else {
        Write-Host "Project already exists in projects.json" -ForegroundColor Yellow
    }
}

Write-Host "Harness install complete for $repoPath using profile $Profile."
