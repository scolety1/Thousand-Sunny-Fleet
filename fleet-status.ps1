param(
    [string]$ConfigPath = ".\projects.json"
)

$ErrorActionPreference = "Continue"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")

function Test-FleetStatusProcessAlive {
    param([int]$ProcessId)

    if ($ProcessId -le 0) { return $false }
    return ($null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue))
}

function Get-FleetStatusActiveChildren {
    param(
        [int]$ProcessId
    )

    if ($ProcessId -le 0) { return @() }

    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    return @($children | Where-Object {
        $name = [string]$_.Name
        ![string]::IsNullOrWhiteSpace($name) -and $name -notin @("conhost.exe")
    })
}

function Test-FleetStatusRunActive {
    param(
        [int]$ProcessId,
        [int]$IdleShellGraceSeconds = 120
    )

    if ($ProcessId -le 0) { return $false }

    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $false }

    try {
        if (((Get-Date) - $process.StartTime).TotalSeconds -lt $IdleShellGraceSeconds) {
            return $true
        }
    } catch {
        return $true
    }

    $activeChildren = @(Get-FleetStatusActiveChildren -ProcessId $ProcessId)
    return ($activeChildren.Count -gt 0)
}

function Get-FleetStatusChildSummary {
    param([int]$ProcessId)

    $activeChildren = @(Get-FleetStatusActiveChildren -ProcessId $ProcessId)
    if ($activeChildren.Count -eq 0) {
        return ""
    }

    $names = @($activeChildren | ForEach-Object { [string]$_.Name } | Sort-Object -Unique)
    return ($names -join ", ")
}

function Get-FleetStatusLock {
    param([string]$ProjectName)

    $lockRoot = Join-Path $fleetRoot ".codex-local\locks"
    $safeName = ConvertTo-FleetLaunchSafeName -Name $ProjectName
    $lockPath = Join-Path $lockRoot "$safeName.lock.json"
    if (!(Test-Path $lockPath)) {
        return "none"
    }

    try {
        $lock = Get-Content $lockPath -Raw | ConvertFrom-Json
        $lockPid = if ($null -ne $lock.pid) { [int]$lock.pid } else { 0 }
        if (Test-FleetStatusRunActive -ProcessId $lockPid) {
            $childSummary = Get-FleetStatusChildSummary -ProcessId $lockPid
            if (![string]::IsNullOrWhiteSpace($childSummary)) {
                return "active PID $lockPid ($childSummary)"
            }
            return "active PID $lockPid"
        }
        if (Test-FleetStatusProcessAlive -ProcessId $lockPid) {
            return "idle shell PID $lockPid"
        }
        return "stale PID $lockPid"
    } catch {
        return "unreadable"
    }
}

if (!(Test-Path $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$projects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$stopRequests = @(Get-FleetSafeStopRequests -FleetRoot $fleetRoot)

Write-Host "===== Fleet Controls =====" -ForegroundColor Cyan
if ($stopRequests.Count -eq 0) {
    Write-Host "Safe stop requests: none" -ForegroundColor Green
} else {
    Write-Host "Safe stop requests: active" -ForegroundColor Yellow
    foreach ($request in $stopRequests) {
        Write-Host "  - $($request.target): $($request.path)" -ForegroundColor Yellow
    }
}

$latestLaunch = Join-Path $fleetRoot "out\latest-launch.md"
if (Test-Path $latestLaunch) {
    Write-Host "Latest launch: $latestLaunch"
}

foreach ($project in $projects) {
    Write-Host ""
    Write-Host "===== $($project.name) =====" -ForegroundColor Cyan

    if (!(Test-Path $project.repo)) {
        Write-Host "Repo missing: $($project.repo)" -ForegroundColor Red
        continue
    }

    Push-Location $project.repo
    $branch = git branch --show-current
    $status = @(git status --short 2>$null)
    $unchecked = @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue)
    $head = git rev-parse --short HEAD 2>$null
    if ($LASTEXITCODE -ne 0) {
        $head = "none"
    }

    Write-Host "Path: $($project.repo)"
    Write-Host "Branch: $branch"
    Write-Host "HEAD: $head"
    Write-Host "Unchecked tasks: $($unchecked.Count)"
    Write-Host "Run lock: $(Get-FleetStatusLock -ProjectName $project.name)"

    if ($status.Count -eq 0) {
        Write-Host "Working tree: clean" -ForegroundColor Green
    } else {
        Write-Host "Working tree: dirty" -ForegroundColor Yellow
        $status | ForEach-Object { Write-Host "  $_" }
    }

    Pop-Location
}
