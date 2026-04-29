[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string[]]$ExcludeProject = @("NinersDynastyWarRoom"),

    [string[]]$ExpectedProject = @(),

    [double]$DurationHours = 12,

    [int]$SupervisorIntervalSeconds = 300,

    [ValidateSet("cheap", "balanced", "premium")]
    [string]$BudgetMode = "balanced",

    [ValidateSet("auto", "brief", "foundation", "shape", "simplicity", "polish", "proof", "parked", "repair", "problem-brief", "data-contract", "formula-spec", "fixture-tests", "engine-build", "calibration", "dashboard", "scenario-tools", "analysis-proof")]
    [string]$LoopPhase = "auto",

    [int]$BatchSize = 3,

    [int]$MaxBatches = 20,

    [int]$MaxRuntimeMinutes = 360,

    [int]$MaxCompletedTasks = 6,

    [int]$MaxPlannerBatches = 1,

    [int]$VisualInspectEvery = 0,

    [int]$SimonEvery = 0,

    [int]$RobinEvery = 0,

    [int]$JoeyEvery = 0,

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 8,

    [int]$MaxTaskQuarantines = 5,

    [int]$RepairBatchSize = 1,

    [int]$RepairMaxBatches = 1,

    [int]$MaxRepairAttempts = 2,

    [int]$StepTimeoutSeconds = 300,

    [switch]$LaunchFirst,

    [switch]$RequireMagicPreflight,

    [switch]$RequirePhaseValidation,

    [switch]$UseGlobalRunShape,

    [switch]$AllowSafeStopRequests,

    [switch]$PushCheckpoint,

    [ValidateSet("off", "warn", "enforce")]
    [string]$LaunchGateMode = "warn",

    [ValidateSet("off", "warn", "enforce")]
    [string]$KillSwitchMode = "warn",

    [switch]$Once,

    [switch]$DryRun
)

$ErrorActionPreference = "Continue"

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

if ($DurationHours -le 0) { Stop-WithMessage "-DurationHours must be greater than 0." }
if ($SupervisorIntervalSeconds -lt 30) { Stop-WithMessage "-SupervisorIntervalSeconds must be at least 30." }
if ($BatchSize -lt 1) { Stop-WithMessage "-BatchSize must be at least 1." }
if ($MaxBatches -lt 1) { Stop-WithMessage "-MaxBatches must be at least 1." }
if ($MaxRuntimeMinutes -lt 0) { Stop-WithMessage "-MaxRuntimeMinutes must be 0 or greater." }
if ($MaxCompletedTasks -lt 0) { Stop-WithMessage "-MaxCompletedTasks must be 0 or greater." }
if ($MaxPlannerBatches -lt 0) { Stop-WithMessage "-MaxPlannerBatches must be 0 or greater." }
if ($VisualInspectEvery -lt 0) { Stop-WithMessage "-VisualInspectEvery must be 0 or greater." }
if ($SimonEvery -lt 0) { Stop-WithMessage "-SimonEvery must be 0 or greater." }
if ($RobinEvery -lt 0) { Stop-WithMessage "-RobinEvery must be 0 or greater." }
if ($JoeyEvery -lt 0) { Stop-WithMessage "-JoeyEvery must be 0 or greater." }
if ($MaxTaskQuarantines -lt 0) { Stop-WithMessage "-MaxTaskQuarantines must be 0 or greater." }
if ($RepairBatchSize -lt 1) { Stop-WithMessage "-RepairBatchSize must be at least 1." }
if ($RepairMaxBatches -lt 1) { Stop-WithMessage "-RepairMaxBatches must be at least 1." }
if ($MaxRepairAttempts -lt 0) { Stop-WithMessage "-MaxRepairAttempts must be 0 or greater." }
if ($StepTimeoutSeconds -lt 30) { Stop-WithMessage "-StepTimeoutSeconds must be at least 30." }

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

$startedAt = Get-Date
$deadline = $startedAt.AddHours($DurationHours)
$outPath = Join-Path $fleetRoot "out\overnight-autopilot.md"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $outPath) | Out-Null
$stepLogRoot = Join-Path $fleetRoot "out\autopilot-runs"
New-Item -ItemType Directory -Force -Path $stepLogRoot | Out-Null

$excludeArgs = @($ExcludeProject | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })
$expectedArgs = @($ExpectedProject | Where-Object { ![string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ })

function Add-ArrayArgument {
    param(
        [string[]]$Arguments,
        [string]$Name,
        [string[]]$Values
    )

    if ($Values.Count -gt 0) {
        return @($Arguments + @($Name, ($Values -join ",")))
    }
    return $Arguments
}

function Write-AutopilotReport {
    param([string]$Status)

    $lines = @(
        "# Codex Fleet Overnight Autopilot",
        "",
        "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "Started: $($startedAt.ToString('yyyy-MM-dd HH:mm:ss'))",
        "Deadline: $($deadline.ToString('yyyy-MM-dd HH:mm:ss'))",
        "Status: $Status",
        "Project: $(if ([string]::IsNullOrWhiteSpace($Project)) { 'all configured ships' } else { $Project })",
        "Excluded: $(if ($excludeArgs.Count -gt 0) { $excludeArgs -join ', ' } else { 'none' })",
        "Expected ships: $(if ($expectedArgs.Count -gt 0) { $expectedArgs -join ', ' } else { 'not enforced' })",
        "",
        "## Loop",
        "",
        "- Supervisor interval seconds: $SupervisorIntervalSeconds",
        "- Budget mode: $BudgetMode",
        "- Loop phase: $LoopPhase",
        "- Launch gate mode: $LaunchGateMode",
        "- Kill switch mode: $KillSwitchMode",
        "- Max completed tasks per ship: $MaxCompletedTasks",
        "- Max planner batches per ship: $MaxPlannerBatches",
        "- Auto safe-stop: enabled",
        "- Auto repair queue: enabled",
        "- Auto repair relaunch: enabled",
        "- Repair batch size: $RepairBatchSize",
        "- Repair max batches: $RepairMaxBatches",
        "- Max repair attempts per 12h: $MaxRepairAttempts",
        "- Step timeout seconds: $StepTimeoutSeconds",
        "",
        "## Latest Reports",
        "",
        "- Supervisor: out/fleet-supervisor.md",
        "- Digest: out/fleet-overnight-digest.md",
        "- Fleet status: run .\fleet-status.ps1"
    )
    Set-Content -Path $outPath -Value $lines
}

function Invoke-Step {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    Write-Host ""
    Write-Host "===== $Name =====" -ForegroundColor Cyan
    Write-Host ("powershell " + ($Arguments -join " ")) -ForegroundColor DarkCyan
    if ($DryRun) { return 0 }

    $safeName = $Name -replace "[^a-zA-Z0-9_.-]+", "-"
    $safeName = $safeName.Trim("-")
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $stdoutPath = Join-Path $stepLogRoot "$safeName-$stamp.out.log"
    $stderrPath = Join-Path $stepLogRoot "$safeName-$stamp.err.log"
    $process = Start-Process powershell -WorkingDirectory $fleetRoot -ArgumentList $Arguments -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath -PassThru
    if (!$process.WaitForExit($StepTimeoutSeconds * 1000)) {
        try { $process.Kill() } catch {}
        Write-Host "Step timed out after $StepTimeoutSeconds seconds." -ForegroundColor Red
        Write-Host "stdout: $stdoutPath" -ForegroundColor Yellow
        Write-Host "stderr: $stderrPath" -ForegroundColor Yellow
        return 124
    }

    $process.Refresh()
    $exitCode = if ($null -eq $process.ExitCode) { 0 } else { [int]$process.ExitCode }
    if ($exitCode -ne 0) {
        Write-Host "Step failed with exit code $exitCode." -ForegroundColor Red
        Write-Host "stdout: $stdoutPath" -ForegroundColor Yellow
        Write-Host "stderr: $stderrPath" -ForegroundColor Yellow
    }
    return $exitCode
}

Write-AutopilotReport -Status "starting"

if ($LaunchFirst) {
    $launchArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "launch-overnight-run.ps1"),
        "-ConfigPath", $ConfigPath,
        "-BudgetMode", $BudgetMode,
        "-LoopPhase", $LoopPhase,
        "-BatchSize", ([string]$BatchSize),
        "-MaxBatches", ([string]$MaxBatches),
        "-MaxRuntimeMinutes", ([string]$MaxRuntimeMinutes),
        "-MaxCompletedTasks", ([string]$MaxCompletedTasks),
        "-MaxPlannerBatches", ([string]$MaxPlannerBatches),
        "-VisualInspectEvery", ([string]$VisualInspectEvery),
        "-SimonEvery", ([string]$SimonEvery),
        "-RobinEvery", ([string]$RobinEvery),
        "-JoeyEvery", ([string]$JoeyEvery),
        "-RateLimitCooldownSeconds", ([string]$RateLimitCooldownSeconds),
        "-RateLimitMaxCooldowns", ([string]$RateLimitMaxCooldowns),
        "-MaxTaskQuarantines", ([string]$MaxTaskQuarantines),
        "-QuarantineFailedTasks",
        "-LaunchGateMode", $LaunchGateMode,
        "-KillSwitchMode", $KillSwitchMode
    )
    if (![string]::IsNullOrWhiteSpace($Project)) { $launchArgs += @("-Project", $Project) }
    $launchArgs = Add-ArrayArgument -Arguments $launchArgs -Name "-ExcludeProject" -Values $excludeArgs
    $launchArgs = Add-ArrayArgument -Arguments $launchArgs -Name "-ExpectedProject" -Values $expectedArgs
    if ($RequireMagicPreflight) { $launchArgs += "-RequireMagicPreflight" }
    if ($RequirePhaseValidation) { $launchArgs += "-RequirePhaseValidation" }
    if ($UseGlobalRunShape) { $launchArgs += "-UseGlobalRunShape" }
    if ($AllowSafeStopRequests) { $launchArgs += "-AllowSafeStopRequests" }
    if ($PushCheckpoint) { $launchArgs += "-PushCheckpoint" }
    if ($DryRun) { $launchArgs += "-DryRun" }

    $launchExit = Invoke-Step -Name "Initial Overnight Launch" -Arguments $launchArgs
    if ($launchExit -ne 0) {
        Write-AutopilotReport -Status "initial launch failed"
        Stop-WithMessage "Overnight autopilot stopped because initial launch failed."
    }
}

do {
    $supervisorArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "fleet-supervisor.ps1"),
        "-ConfigPath", $ConfigPath,
        "-IntervalSeconds", ([string]$SupervisorIntervalSeconds),
        "-AutoSafeStop",
        "-AutoRepair",
        "-ClearSafeStopAfterRepair",
        "-AutoRelaunchRepair",
        "-RepairBatchSize", ([string]$RepairBatchSize),
        "-RepairMaxBatches", ([string]$RepairMaxBatches),
        "-MaxRepairAttempts", ([string]$MaxRepairAttempts),
        "-Once"
    )
    if (![string]::IsNullOrWhiteSpace($Project)) { $supervisorArgs += @("-Project", $Project) }
    $supervisorArgs = Add-ArrayArgument -Arguments $supervisorArgs -Name "-ExcludeProject" -Values $excludeArgs

    $supervisorExit = Invoke-Step -Name "Supervisor Autopilot Cycle" -Arguments $supervisorArgs
    if ($supervisorExit -ne 0) {
        Write-AutopilotReport -Status "supervisor cycle failed"
        Stop-WithMessage "Overnight autopilot stopped because the supervisor failed."
    }

    Write-AutopilotReport -Status "running"
    if ($Once -or $DryRun) { break }

    $remainingSeconds = [int][Math]::Max(0, ($deadline - (Get-Date)).TotalSeconds)
    if ($remainingSeconds -le 0) { break }
    Start-Sleep -Seconds ([Math]::Min($SupervisorIntervalSeconds, $remainingSeconds))
} while ((Get-Date) -lt $deadline)

Write-AutopilotReport -Status "complete"
Write-Host ""
Write-Host "Overnight autopilot complete. Report: $outPath" -ForegroundColor Green
