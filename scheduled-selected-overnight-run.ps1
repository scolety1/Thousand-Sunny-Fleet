[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$RunLabel = "scheduled",

    [string[]]$Project = @("RestaurantDemo", "ShiftPlate", "EasyLife"),

    [switch]$SkipHarnessTest,

    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot
. (Join-Path $fleetRoot "tools\codex-fleet-launcher.ps1")

$logRoot = Join-Path $fleetRoot "out\scheduled-runs"
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$logPath = Join-Path $logRoot ("selected-{0}-{1}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"), $RunLabel)

function Write-ScheduledLog {
    param([string]$Message)

    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $logPath -Value $line
    Write-Host $line
}

function Test-RunProcessActive {
    param([int]$ProcessId)

    if ($ProcessId -le 0) { return $false }
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($null -eq $process) { return $false }

    try {
        if (((Get-Date) - $process.StartTime).TotalSeconds -lt 120) { return $true }
    } catch {
        return $true
    }

    $children = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$ProcessId" -ErrorAction SilentlyContinue)
    $activeChildren = @($children | Where-Object {
        $name = [string]$_.Name
        ![string]::IsNullOrWhiteSpace($name) -and $name -notin @("conhost.exe")
    })
    return ($activeChildren.Count -gt 0)
}

function Get-RunLockState {
    param([string]$ProjectName)

    $safeName = ConvertTo-FleetLaunchSafeName -Name $ProjectName
    $lockPath = Join-Path $fleetRoot ".codex-local\locks\$safeName.lock.json"
    if (!(Test-Path -LiteralPath $lockPath)) { return "none" }

    try {
        $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
        $pidValue = if ($null -ne $lock.pid) { [int]$lock.pid } else { 0 }
        if (Test-RunProcessActive -ProcessId $pidValue) { return "active PID $pidValue" }
        if ($null -ne (Get-Process -Id $pidValue -ErrorAction SilentlyContinue)) { return "idle shell PID $pidValue" }
        return "stale PID $pidValue"
    } catch {
        return "unreadable"
    }
}

function Get-RepoDirtyFiles {
    param([string]$Repo)

    Push-Location $Repo
    try {
        return @(git status --short 2>$null | ForEach-Object {
            $line = [string]$_
            if ($line.Length -le 3) { return }
            $line.Substring(3).Trim().Replace("\", "/")
        } | Where-Object { ![string]::IsNullOrWhiteSpace($_) })
    } finally {
        Pop-Location
    }
}

function Test-ReportOnlyDirtyFiles {
    param([string[]]$Files)

    if ($Files.Count -eq 0) { return $false }
    foreach ($file in $Files) {
        if ($file -notmatch "^docs/codex/(NIGHTLY_REPORT|MAGIC_SCORECARD|RUNTIME_VERIFICATION|SENSITIVE_SYSTEMS_REVIEW|CHECKPOINT_REVIEW|VISUAL_BUGS|SIMON_DESIGN_REVIEW|ROBIN_COPY_REVIEW|JOEY_SECURITY_REVIEW|QUARANTINED_TASKS|QUALITY_QUARANTINE)\.md$") {
            return $false
        }
    }
    return $true
}

function Save-ReportOnlyDirtyFiles {
    param(
        [string]$ProjectName,
        [string]$Repo,
        [string[]]$Files
    )

    if (!(Test-ReportOnlyDirtyFiles -Files $Files)) { return $false }

    Push-Location $Repo
    try {
        git add -- @Files
        if ($LASTEXITCODE -ne 0) { return $false }
        $pending = @(git diff --cached --name-only)
        if ($pending.Count -eq 0) { return $true }
        git commit -m "Codex save report-only overnight state for $ProjectName"
        return ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
}

Write-ScheduledLog "Selected overnight run '$RunLabel' checking projects: $($Project -join ', ')"

$projectsJson = @(Get-Content ".\projects.json" -Raw | ConvertFrom-Json | ForEach-Object { $_ })
$blocking = @()
foreach ($projectName in $Project) {
    $projectConfig = @($projectsJson | Where-Object { [string]$_.name -ceq $projectName }) | Select-Object -First 1
    if ($null -eq $projectConfig) {
        $blocking += "$projectName missing from projects.json"
        continue
    }
    if (!(Test-Path -LiteralPath ([string]$projectConfig.repo))) {
        $blocking += "$projectName repo missing"
        continue
    }

    $dirtyFiles = @(Get-RepoDirtyFiles -Repo ([string]$projectConfig.repo))
    $lock = Get-RunLockState -ProjectName $projectName
    if ($dirtyFiles.Count -gt 0) {
        if (Test-ReportOnlyDirtyFiles -Files $dirtyFiles) {
            Write-ScheduledLog "$projectName has report-only dirty files; saving them before launch."
            if (-not (Save-ReportOnlyDirtyFiles -ProjectName $projectName -Repo ([string]$projectConfig.repo) -Files $dirtyFiles)) {
                $blocking += "$projectName report-only dirty files could not be saved"
            }
        } else {
            $blocking += "$projectName dirty ($($dirtyFiles.Count) files)"
        }
    }
    if ($lock -match "^active") {
        $blocking += "$projectName already running ($lock)"
    }
}

if ($blocking.Count -gt 0) {
    Write-ScheduledLog "Skipping '$RunLabel' because selected work is already active or unsafe:"
    foreach ($item in $blocking) { Write-ScheduledLog "  - $item" }
    Write-ScheduledLog "No new fleet windows launched."
    exit 0
}

if ($DryRun) {
    Write-ScheduledLog "Dry run passed; selected fleet would launch now."
    exit 0
}

if (!$SkipHarnessTest) {
    Write-ScheduledLog "Running fleet harness self-test before launch."
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "test-fleet-harness.ps1") -SelectedProjects ($Project -join ",") -ExcludedProjects ($exclude -join ",") *>> $logPath
    if ($LASTEXITCODE -ne 0) {
        Write-ScheduledLog "Fleet harness self-test failed. No fleet windows launched."
        exit 1
    }
}

Write-ScheduledLog "Clearing global safe-stop so selected ships can depart."
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "request-safe-stop.ps1") -All -Clear *>> $logPath

$exclude = @("CursorPets", "NinersWarRoom", "Tree")
$launchArgs = @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "launch-overnight-run.ps1"),
    "-ExcludeProject", ($exclude -join ","),
    "-ExpectedProject", ($Project -join ","),
    "-BatchSize", "1",
    "-MaxBatches", "6",
    "-VisualInspectEvery", "1",
    "-SimonEvery", "1",
    "-RobinEvery", "1",
    "-JoeyEvery", "3",
    "-RateLimitCooldownSeconds", "3600",
    "-RateLimitMaxCooldowns", "8",
    "-MaxTaskQuarantines", "5",
    "-QuarantineFailedTasks"
)

Write-ScheduledLog "Launching selected fleet: RestaurantDemo, ShiftPlate, EasyLife."
& powershell @launchArgs *>> $logPath
$exitCode = $LASTEXITCODE
Write-ScheduledLog "Launch command exited with code $exitCode."
exit $exitCode
