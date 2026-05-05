param(
    [Parameter(Mandatory = $true)]
    [string]$Project,

    [string]$ConfigPath = ".\projects.json",

    [string]$PhasePlanPath = "",

    [int]$IntervalSeconds = 600,

    [int]$MaxIterations = 288,

    [int]$BatchSize = 1,

    [int]$MaxBatches = 5,

    [int]$VisualInspectEvery = 1,

    [int]$SimonEvery = 1,

    [int]$RobinEvery = 1,

    [int]$AccessibilityEvery = 1,

    [int]$PerformanceEvery = 2,

    [int]$JoeyEvery = 2,

    [switch]$QuarantineFailedTasks,

    [switch]$DryRun
)

$ErrorActionPreference = "Continue"
$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$logPath = Join-Path $fleetRoot ("out\{0}-phase-autopilot.log" -f $Project)

function Write-Log {
    param([string]$Message)
    $stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$stamp $Message" | Tee-Object -FilePath $logPath -Append
}

function Stop-WithMessage {
    param([string]$Message)
    Write-Log "ERROR $Message"
    throw $Message
}

function Get-ProjectConfig {
    if (!(Test-Path $ConfigPath)) {
        Stop-WithMessage "Config not found: $ConfigPath"
    }

    $parsed = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $projects = @($parsed | ForEach-Object { $_ })
    $match = @($projects | Where-Object { [string]$_.name -ceq $Project })
    if ($match.Count -ne 1) {
        Stop-WithMessage "Project not found or not unique: $Project"
    }
    return $match[0]
}

$projectConfig = Get-ProjectConfig
$repo = [string]$projectConfig.repo
$docs = Join-Path $repo "docs\codex"
$phaseStatePath = Join-Path $docs "PHASE_STATE.md"
$nextTasksPath = Join-Path $docs "NEXT_5_TASKS.md"
$taskQueuePath = Join-Path $docs "TASK_QUEUE.md"

if ([string]::IsNullOrWhiteSpace($PhasePlanPath)) {
    $PhasePlanPath = Join-Path $docs "PHASE_AUTOPILOT_PLAN.json"
}

if (!(Test-Path $PhasePlanPath)) {
    Stop-WithMessage "Phase plan not found: $PhasePlanPath"
}

$phasePlan = Get-Content $PhasePlanPath -Raw | ConvertFrom-Json
$phaseList = @($phasePlan.phases)
if ($phaseList.Count -eq 0) {
    Stop-WithMessage "Phase plan has no phases: $PhasePlanPath"
}

function Get-ProjectStatusBlock {
    $status = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $fleetRoot "fleet-status.ps1") 2>&1
    $lines = @($status)
    $start = -1
    $heading = "^===== {0} =====" -f [regex]::Escape($Project)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $heading) {
            $start = $i
            break
        }
    }
    if ($start -lt 0) { return @() }

    $end = $lines.Count - 1
    for ($j = $start + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match "^=====") {
            $end = $j - 1
            break
        }
    }
    return $lines[$start..$end]
}

function Start-ProjectRun {
    $quarantineArg = if ($QuarantineFailedTasks) { " -QuarantineFailedTasks" } else { "" }
    $cmd = "Set-Location '$fleetRoot'; .\run-checkpoint-loop.ps1 -Project '$Project' -BatchSize $BatchSize -MaxBatches $MaxBatches -VisualInspectEvery $VisualInspectEvery -SimonEvery $SimonEvery -RobinEvery $RobinEvery -AccessibilityEvery $AccessibilityEvery -PerformanceEvery $PerformanceEvery -JoeyEvery $JoeyEvery -ContinueOnYellowCheckpoint -RateLimitCooldownSeconds 3600 -RateLimitMaxCooldowns 2 -MaxTaskQuarantines 2$quarantineArg"

    if ($DryRun) {
        Write-Log "DRY RUN launch: $cmd"
        return
    }

    $process = Start-Process powershell -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd) -WindowStyle Hidden -PassThru
    Write-Log "Launched $Project run PID=$($process.Id) batchSize=$BatchSize maxBatches=$MaxBatches"
}

function Get-CurrentPhaseKey {
    if (!(Test-Path $phaseStatePath)) { return "" }
    $content = Get-Content $phaseStatePath -Raw
    if ($content -match "Current Phase:\s*(\S+)") { return $Matches[1] }
    return ""
}

function Set-PhaseState {
    param($Phase)
    if (!(Test-Path $phaseStatePath)) {
        Stop-WithMessage "PHASE_STATE.md not found: $phaseStatePath"
    }
    $content = Get-Content $phaseStatePath -Raw
    $content = $content -replace "Current Phase:\s*\S+", "Current Phase: $($Phase.key)"
    $content = $content -replace "Showable Moment:.*", "Showable Moment: $($Phase.showable)"
    $content = $content -replace "Done Signal:.*", "Done Signal: $($Phase.doneSignal)"
    $content = $content -replace "Next Phase Criteria:.*", "Next Phase Criteria: $($Phase.nextCriteria)"
    $content = $content -replace "Repair Return Phase:\s*\S+", "Repair Return Phase: $($Phase.key)"
    $content = $content -replace "Updated At:.*", "Updated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Set-Content -Path $phaseStatePath -Value $content -Encoding UTF8
}

function Get-PhaseReviewPath {
    param($Phase)
    return (Join-Path $docs ("PHASE_{0}_REVIEW.md" -f $Phase.number))
}

function Write-PhaseReview {
    param($Phase, $NextPhase)
    $path = Get-PhaseReviewPath -Phase $Phase
    if (Test-Path $path) { return }

    $recent = (& git -C $repo log -8 --oneline) -join "`n"
    $nextText = if ($NextPhase) { "Ready for Phase $($NextPhase.number): $($NextPhase.name)." } else { "Final phase complete. Ready to park." }
    $body = @"
# Phase $($Phase.number) Review - $($Phase.name)

## Status

Phase $($Phase.number) reached zero unchecked tasks with a clean working tree.

## Recent Commits

````text
$recent
````

## Evidence

- Fleet status reported $Project unchecked tasks: `0`
- Run lock: none
- Working tree: clean
- Phase task packet consumed.

## Outcome

$($Phase.reviewOutcome)

## Next Step

$nextText
"@
    Set-Content -Path $path -Value $body -Encoding UTF8
}

function Write-TaskFiles {
    param($Phase)
    $tasks = @($Phase.tasks)
    Set-Content -Path $nextTasksPath -Value (($tasks -join "`r`n") + "`r`n") -Encoding UTF8

    $queue = if (Test-Path $taskQueuePath) { Get-Content $taskQueuePath -Raw } else { "" }
    $header = "## $Project Phase $($Phase.number) - $($Phase.name) $(Get-Date -Format 'yyyy-MM-dd')"
    if ($queue -notmatch [regex]::Escape($header)) {
        Add-Content -Path $taskQueuePath -Value ("`r`n$header`r`n`r`n" + ($tasks -join "`r`n") + "`r`n") -Encoding UTF8
    }
}

function Invoke-BuildCheck {
    $buildDirectory = [string]$projectConfig.buildDirectory
    $buildCommand = [string]$projectConfig.buildCommand
    if ([string]::IsNullOrWhiteSpace($buildDirectory)) { $buildDirectory = "." }
    if ([string]::IsNullOrWhiteSpace($buildCommand)) {
        Write-Log "No build command configured; treating build check as pass."
        return $true
    }

    $buildPath = Join-Path $repo $buildDirectory
    Push-Location $buildPath
    try {
        & powershell -NoProfile -ExecutionPolicy Bypass -Command $buildCommand
        return ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }
}

function Commit-Transition {
    param($NextPhase)
    & git -C $repo add docs/codex
    & git -C $repo commit -m ("Advance {0} to phase {1} {2}" -f $Project, $NextPhase.number, ([string]$NextPhase.name).ToLowerInvariant().Replace(" ", "-"))
}

function Complete-FinalPark {
    if (Test-Path $phaseStatePath) {
        $content = Get-Content $phaseStatePath -Raw
        $content = $content -replace "Parking State:.*", "Parking State: PARKED_REVIEW_READY"
        $content = $content -replace "Updated At:.*", "Updated At: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        Set-Content -Path $phaseStatePath -Value $content -Encoding UTF8
    }
    Set-Content -Path $nextTasksPath -Value "- [x] $Project phase autopilot complete: final phase finished and parked. [class:proof risk:low mode:single]`r`n" -Encoding UTF8
    & git -C $repo add docs/codex
    & git -C $repo commit -m "Park $Project phase autopilot review ready"
}

Write-Log "Starting generic phase autopilot project=$Project plan=$PhasePlanPath interval=${IntervalSeconds}s maxIterations=$MaxIterations"

for ($iteration = 1; $iteration -le $MaxIterations; $iteration++) {
    $block = @(Get-ProjectStatusBlock)
    $text = $block -join "`n"
    $unchecked = if ($text -match "Unchecked tasks:\s+(\d+)") { [int]$Matches[1] } else { -1 }
    $hasRunLock = $text -match "Run lock:\s+active"
    $isDirty = $text -match "Working tree:\s+dirty"
    $phaseKey = Get-CurrentPhaseKey

    Write-Log "Iteration $iteration phase=$phaseKey unchecked=$unchecked runLock=$hasRunLock dirty=$isDirty"

    if ($isDirty) {
        Write-Log "DIRTY state detected. Leaving for Codex/user repair."
    } elseif ($unchecked -gt 0 -and -not $hasRunLock) {
        Start-ProjectRun
    } elseif ($unchecked -eq 0 -and -not $hasRunLock) {
        $current = $phaseList | Where-Object { $_.key -eq $phaseKey } | Select-Object -First 1
        if (!$current) {
            Write-Log "No phase map entry for '$phaseKey'. Not transitioning."
        } else {
            $next = $phaseList | Where-Object { [int]$_.number -eq ([int]$current.number + 1) } | Select-Object -First 1
            Write-Log "Phase $($current.number) appears complete. Running transition."
            $buildOk = Invoke-BuildCheck
            if (!$buildOk) {
                Write-Log "Build failed during transition check. Leaving for Codex/user repair."
            } else {
                Write-PhaseReview -Phase $current -NextPhase $next
                if ($next) {
                    Set-PhaseState -Phase $next
                    Write-TaskFiles -Phase $next
                    Commit-Transition -NextPhase $next
                    Start-ProjectRun
                } else {
                    Complete-FinalPark
                    Write-Log "Final phase complete and parked. Stopping watchdog."
                    break
                }
            }
        }
    }

    Start-Sleep -Seconds $IntervalSeconds
}

Write-Log "Generic phase autopilot finished."
