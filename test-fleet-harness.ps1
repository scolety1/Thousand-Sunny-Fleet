[CmdletBinding(PositionalBinding = $false)]
param(
    [string[]]$SelectedProjects = @("EasyLife", "RestaurantDemo", "ShiftPlate"),

    [string[]]$ExcludedProjects = @("CursorPets", "NinersWarRoom", "Tree", "Bottlelight", "ShiftLedger", "EventBook", "OrderPilot", "LineupLab"),

    [switch]$SkipProjectValidation
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

$results = [System.Collections.Generic.List[object]]::new()

function ConvertTo-ProjectList {
    param([string[]]$Values = @())

    return @(
        $Values |
            ForEach-Object { [string]$_ } |
            ForEach-Object { $_ -split "," } |
            ForEach-Object { $_.Trim() } |
            Where-Object { ![string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique
    )
}

$SelectedProjects = @(ConvertTo-ProjectList -Values $SelectedProjects)
$ExcludedProjects = @(ConvertTo-ProjectList -Values $ExcludedProjects)

function Test-ProcessActive {
    param([int]$ProcessId)

    if ($ProcessId -le 0) { return $false }
    return ($null -ne (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue))
}

function Acquire-HarnessLock {
    $lockRoot = Join-Path $fleetRoot ".codex-local\locks"
    New-Item -ItemType Directory -Force -Path $lockRoot | Out-Null
    $lockPath = Join-Path $lockRoot "fleet-harness-test.lock.json"

    $lock = [pscustomobject]@{
        pid = $PID
        startedAt = (Get-Date).ToString("o")
        command = $MyInvocation.Line
    }
    $lockJson = $lock | ConvertTo-Json -Depth 4
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($lockJson)

    for ($attempt = 0; $attempt -lt 2; $attempt++) {
        try {
            $stream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            try {
                $stream.Write($bytes, 0, $bytes.Length)
            } finally {
                $stream.Close()
            }
            $script:HarnessLockPath = $lockPath
            return
        } catch [System.IO.IOException] {
            try {
                $existing = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json
                $existingPid = if ($null -ne $existing.pid) { [int]$existing.pid } else { 0 }
                if (Test-ProcessActive -ProcessId $existingPid) {
                    Write-Host "Fleet harness self-test is already running under PID $existingPid." -ForegroundColor Red
                    exit 1
                }
            } catch {}
            Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "Fleet harness self-test could not acquire its lock." -ForegroundColor Red
    exit 1
}

function Release-HarnessLock {
    if (![string]::IsNullOrWhiteSpace([string]$script:HarnessLockPath) -and (Test-Path -LiteralPath $script:HarnessLockPath)) {
        Remove-Item -LiteralPath $script:HarnessLockPath -Force -ErrorAction SilentlyContinue
    }
}

trap {
    Release-HarnessLock
    break
}

Acquire-HarnessLock

function Add-TestResult {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Detail = ""
    )

    $script:results.Add([pscustomobject]@{
        name = $Name
        passed = $Passed
        detail = $Detail
    }) | Out-Null

    $color = if ($Passed) { "Green" } else { "Red" }
    $label = if ($Passed) { "PASS" } else { "FAIL" }
    $suffix = if (![string]::IsNullOrWhiteSpace($Detail)) { ": $Detail" } else { "" }
    Write-Host "[$label] $Name$suffix" -ForegroundColor $color
}

function Test-PowerShellParse {
    param([string]$Path)

    $tokens = $null
    $parseErrors = $null
    $fullPath = Resolve-Path $Path -ErrorAction SilentlyContinue
    if (!$fullPath) {
        Add-TestResult -Name "Parse $Path" -Passed $false -Detail "file missing"
        return
    }

    $null = [System.Management.Automation.Language.Parser]::ParseFile($fullPath.Path, [ref]$tokens, [ref]$parseErrors)
    Add-TestResult -Name "Parse $Path" -Passed ($parseErrors.Count -eq 0) -Detail ($(if ($parseErrors.Count -gt 0) { ($parseErrors | Select-Object -First 1).Message } else { "" }))
}

function Invoke-HarnessCommand {
    param(
        [string]$Name,
        [string[]]$Arguments,
        [int]$ExpectedExitCode = 0
    )

    $output = @(& powershell @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    $passed = ($exitCode -eq $ExpectedExitCode)
    $detail = "exit $exitCode"
    if (!$passed -and $output.Count -gt 0) {
        $detail += "; " + (($output | Select-Object -Last 3) -join " | ")
    }
    Add-TestResult -Name $Name -Passed $passed -Detail $detail
    return [pscustomobject]@{ exitCode = $exitCode; output = $output; passed = $passed }
}

function Invoke-SensitiveIntentHarness {
    param(
        [string]$Name,
        [string]$Summary,
        [string]$ForbiddenPattern = "",
        [string]$RequiredPattern = ""
    )

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $fleetRoot "run-checkpoint-loop.ps1"), [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        Add-TestResult -Name $Name -Passed $false -Detail "checkpoint loop parse failed"
        return
    }

    $functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq "Get-SensitiveIntentText"
    }, $true)
    if ($null -eq $functionAst) {
        Add-TestResult -Name $Name -Passed $false -Detail "function missing"
        return
    }

    $scriptBlock = [scriptblock]::Create($functionAst.Extent.Text)
    . $scriptBlock
    $result = Get-SensitiveIntentText -Summary $Summary
    $passed = $true
    $detail = $result
    if (![string]::IsNullOrWhiteSpace($ForbiddenPattern) -and $result -match $ForbiddenPattern) {
        $passed = $false
        $detail = "forbidden pattern remained: $ForbiddenPattern; result=$result"
    }
    if (![string]::IsNullOrWhiteSpace($RequiredPattern) -and $result -notmatch $RequiredPattern) {
        $passed = $false
        $detail = "required pattern missing: $RequiredPattern; result=$result"
    }

    Add-TestResult -Name $Name -Passed $passed -Detail $detail
}

foreach ($script in @(
    ".\launch-overnight-run.ps1",
    ".\run-checkpoint-loop.ps1",
    ".\scheduled-selected-overnight-run.ps1",
    ".\fleet-runner-watchdog.ps1",
    ".\fleet-remote-control.ps1",
    ".\launch-cellar-fleet.ps1",
    ".\fleet-night-report.ps1",
    ".\fleet-supervisor.ps1",
    ".\fleet-copy-smoke.ps1",
    ".\fleet-website-stages.ps1",
    ".\fleet-completion-contract.ps1",
    ".\fleet-experiment.ps1",
    ".\staging-deploy.ps1",
    ".\harbor-master.ps1",
    ".\tools\codex-fleet-launcher.ps1",
    ".\tools\codex-fleet-runtime.ps1"
)) {
    Test-PowerShellParse -Path $script
}

Invoke-SensitiveIntentHarness `
    -Name "Sensitive intent strips protective preserve clauses" `
    -Summary "Simplify the first screen and preserve fake data, current routes, package files, generated output, backend/auth/payments/APIs/analytics/tracking limits, and no real restaurant data." `
    -ForbiddenPattern "(?i)\bauth\b|\bpayments?\b|\bapis?\b|\banalytics\b|\btracking\b"

Invoke-SensitiveIntentHarness `
    -Name "Sensitive intent keeps real auth work" `
    -Summary "Add auth login with password reset, no backend payment changes." `
    -RequiredPattern "(?i)\bauth\b|\blogin\b"

$malformedAutoRepairTask = "- [ ] User pain: HQ repair is blocked by a bad generated task. Skill: debugging-and-error-recovery. Target: app-vNext/src/features/hq/routes/HQPage.tsx/, docs/codex/NIGHTLY_REPORT.md. Change: fix the HQ blocker. First screen: keep Today dominant. Remove/simplify: one vague label. Guardrails: no backend, auth, payments, dependencies, deployment config, generated output, or unrelated files. Acceptance: npm.cmd run build. Proof: NIGHTLY_REPORT.md records the repair. Stop if: build fails. Check: HQ reads clearly. [class:bugfix risk:low mode:single impact:visible surface:mixed scope:docs/codex/ accept:npm.cmd_run_build]"
[void](Invoke-HarnessCommand -Name "Supervisor rejects malformed auto-repair task" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "fleet-supervisor.ps1"),
    "-ValidateAutoRepairProject", "EasyLife",
    "-ValidateAutoRepairTask", $malformedAutoRepairTask
) -ExpectedExitCode 1)

$validEasyLifeAutoRepairTask = "- [ ] User pain: the EasyLife HQ first screen can still feel like a module dashboard instead of a slick assistant command surface. Skill: debugging-and-error-recovery. Target: app-vNext/src/features/hq/routes/HQPage.tsx, app-vNext/src/styles/globals.css, docs/codex/NIGHTLY_REPORT.md, docs/codex/MAGIC_SCORECARD.md. Change: make one smallest HQ repair that keeps Today/assistant command action dominant and resolves the blocker named by the latest reports. First screen: Today command input, next action, and day plan stay above optional module detail. Remove/simplify: one repeated dashboard label, decorative wrapper, vague helper phrase, or extra stat that competes with Today. Guardrails: no backend, auth, payments, APIs, analytics, dependencies, deployment config, generated output, unrelated files, or new dashboard. Acceptance: npm.cmd run build from app-vNext. Proof: NIGHTLY_REPORT.md and MAGIC_SCORECARD.md record the exact HQ repair and remaining follow-up. Stop if: build fails, the fix needs files outside the exact target list, or the same HQ quality loop repeats. Check: the first viewport reads as a slick personal assistant, not a feature inventory. [class:bugfix risk:low mode:single impact:visible surface:hq scope:app-vNext/src/features/hq/routes/HQPage.tsx,app-vNext/src/styles/globals.css,docs/codex/NIGHTLY_REPORT.md,docs/codex/MAGIC_SCORECARD.md accept:npm.cmd_run_build_from_app-vNext]"
[void](Invoke-HarnessCommand -Name "Supervisor accepts valid EasyLife auto-repair task" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "fleet-supervisor.ps1"),
    "-ValidateAutoRepairProject", "EasyLife",
    "-ValidateAutoRepairTask", $validEasyLifeAutoRepairTask
))

$activeRunModePathForHarness = Join-Path $fleetRoot "fleet\control\run-mode.json"
$activeProjectsForHarness = @()
if (Test-Path -LiteralPath $activeRunModePathForHarness) {
    try {
        $activeRunModeForHarness = Get-Content -LiteralPath $activeRunModePathForHarness -Raw | ConvertFrom-Json
        if ($null -ne $activeRunModeForHarness -and $null -ne $activeRunModeForHarness.activeProjects) {
            $activeProjectsForHarness = @(ConvertTo-ProjectList -Values @($activeRunModeForHarness.activeProjects | ForEach-Object { [string]$_ }))
        }
    } catch {}
}
$launchExpectedProjects = @($SelectedProjects)
if ($activeProjectsForHarness.Count -gt 0) {
    $launchExpectedProjects = @($SelectedProjects | Where-Object { $activeProjectsForHarness -contains $_ })
}
if ($launchExpectedProjects.Count -eq 0) {
    $launchExpectedProjects = @("__no_active_selected_project__")
}
$selected = ($launchExpectedProjects -join ",")
$excluded = ($ExcludedProjects -join ",")
$latestLaunch = Join-Path $fleetRoot "out\latest-launch.md"
$latestProofLaunch = Join-Path $fleetRoot "out\latest-proof-launch.md"
$latestLaunchBeforeDryRun = if (Test-Path $latestLaunch) { Get-Content $latestLaunch -Raw } else { $null }

[void](Invoke-HarnessCommand -Name "Selected launch dry-run accepts exact ship set" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "launch-overnight-run.ps1"),
    "-ExcludeProject", $excluded,
    "-ExpectedProject", $selected,
    "-BatchSize", "1",
    "-MaxBatches", "1",
    "-SkipDoctor",
    "-AllowSafeStopRequests",
    "-DryRun"
))

$latestLaunchAfterDryRun = if (Test-Path $latestLaunch) { Get-Content $latestLaunch -Raw } else { $null }
Add-TestResult -Name "Selected launch dry-run does not overwrite latest real launch" -Passed ($latestLaunchBeforeDryRun -eq $latestLaunchAfterDryRun)

if (Test-Path $latestProofLaunch) {
    $launchText = Get-Content $latestProofLaunch -Raw
    foreach ($ship in $launchExpectedProjects) {
        Add-TestResult -Name "Proof manifest includes $ship" -Passed ($launchText -match "\|\s*$([regex]::Escape($ship))\s*\|")
    }
    foreach ($ship in @($ExcludedProjects + @($SelectedProjects | Where-Object { $launchExpectedProjects -notcontains $_ }))) {
        Add-TestResult -Name "Proof manifest excludes $ship" -Passed ($launchText -notmatch "\|\s*$([regex]::Escape($ship))\s*\|")
    }
} else {
    Add-TestResult -Name "Proof manifest exists after selected dry-run" -Passed $false -Detail $latestProofLaunch
}

$tooSmallExpectedProjects = @($launchExpectedProjects | Select-Object -First ([Math]::Max(0, $launchExpectedProjects.Count - 1)))
if ($tooSmallExpectedProjects.Count -eq 0) {
    $tooSmallExpectedProjects = @("__missing_selected_ship__")
}
$tooSmallExpected = $tooSmallExpectedProjects -join ","
[void](Invoke-HarnessCommand -Name "Selected launch rejects unexpected extra ship" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "launch-overnight-run.ps1"),
    "-ExcludeProject", $excluded,
    "-ExpectedProject", $tooSmallExpected,
    "-BatchSize", "1",
    "-MaxBatches", "1",
    "-SkipDoctor",
    "-AllowSafeStopRequests",
    "-DryRun"
) -ExpectedExitCode 1)

[void](Invoke-HarnessCommand -Name "Selected launch rejects invalid cooldown" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "launch-overnight-run.ps1"),
    "-ExcludeProject", $excluded,
    "-ExpectedProject", $selected,
    "-BatchSize", "1",
    "-MaxBatches", "1",
    "-RateLimitCooldownSeconds", "0",
    "-SkipDoctor",
    "-AllowSafeStopRequests",
    "-DryRun"
) -ExpectedExitCode 1)

$scheduledWrapperDryRun = Invoke-HarnessCommand -Name "Scheduled selected wrapper dry-run passes safety preflight" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "scheduled-selected-overnight-run.ps1"),
    "-RunLabel", "harness-self-test",
    "-Project", $selected,
    "-BatchSize", "1",
    "-MaxBatches", "1",
    "-VisualInspectEvery", "1",
    "-SimonEvery", "1",
    "-RobinEvery", "1",
    "-JoeyEvery", "1",
    "-MaxTaskQuarantines", "2",
    "-LoopPhase", "formula-spec",
    "-SkipHarnessTest",
    "-DryRun"
)

$scheduledWrapperSkippedForActiveWork = (($scheduledWrapperDryRun.output -join "`n") -match "(?i)already active or unsafe|No new fleet windows launched")
if ($scheduledWrapperSkippedForActiveWork) {
    Add-TestResult -Name "Scheduled wrapper dry-run keeps proof BatchSize" -Passed $true -Detail "skipped because selected work is already active"
    Add-TestResult -Name "Scheduled wrapper dry-run keeps proof MaxBatches" -Passed $true -Detail "skipped because selected work is already active"
    Add-TestResult -Name "Scheduled wrapper dry-run keeps proof Joey cadence" -Passed $true -Detail "skipped because selected work is already active"
    Add-TestResult -Name "Scheduled wrapper dry-run keeps proof quarantine budget" -Passed $true -Detail "skipped because selected work is already active"
} elseif (Test-Path $latestProofLaunch) {
    $wrapperLaunchText = Get-Content $latestProofLaunch -Raw
    Add-TestResult -Name "Scheduled wrapper dry-run keeps proof BatchSize" -Passed ($wrapperLaunchText -match "-BatchSize 1\b")
    Add-TestResult -Name "Scheduled wrapper dry-run keeps proof MaxBatches" -Passed ($wrapperLaunchText -match "-MaxBatches 1\b")
    Add-TestResult -Name "Scheduled wrapper dry-run keeps proof Joey cadence" -Passed ($wrapperLaunchText -match "-JoeyEvery 1\b")
    Add-TestResult -Name "Scheduled wrapper dry-run keeps proof quarantine budget" -Passed ($wrapperLaunchText -match "-MaxTaskQuarantines 2\b")
} else {
    Add-TestResult -Name "Scheduled wrapper dry-run proof manifest exists" -Passed $false -Detail $latestProofLaunch
}

$watchdogSafe12DryRun = Invoke-HarnessCommand -Name "Runner watchdog EasyLife Safe12 command dry-run" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "fleet-runner-watchdog.ps1"),
    "-Project", "EasyLife",
    "-ValidateLaunchCommandOnly",
    "-DryRun"
)
$watchdogSafe12Text = ($watchdogSafe12DryRun.output -join "`n")
Add-TestResult -Name "Runner watchdog uses EasyLife Safe12 launcher" -Passed ($watchdogSafe12Text -match "launch-overnight-run\.ps1" -and $watchdogSafe12Text -match "-Project EasyLife\b" -and $watchdogSafe12Text -match "-ExpectedProject EasyLife\b" -and $watchdogSafe12Text -match "-Safe12\b" -and $watchdogSafe12Text -match "-SkipDoctor\b")
Add-TestResult -Name "Runner watchdog EasyLife Safe12 expands BatchSize" -Passed ($watchdogSafe12Text -match "-BatchSize 1\b")
Add-TestResult -Name "Runner watchdog EasyLife Safe12 expands MaxBatches" -Passed ($watchdogSafe12Text -match "-MaxBatches 24\b")
Add-TestResult -Name "Runner watchdog EasyLife Safe12 expands runtime" -Passed ($watchdogSafe12Text -match "-MaxRuntimeMinutes 720\b")
Add-TestResult -Name "Runner watchdog EasyLife Safe12 expands task cap" -Passed ($watchdogSafe12Text -match "-MaxCompletedTasks 14\b")
Add-TestResult -Name "Runner watchdog EasyLife Safe12 keeps quarantine and push" -Passed ($watchdogSafe12Text -match "-QuarantineFailedTasks\b" -and $watchdogSafe12Text -match "-PushCheckpoint\b")

$runModePath = Join-Path $fleetRoot "fleet\control\run-mode.json"
$previousRunModeText = if (Test-Path -LiteralPath $runModePath) { Get-Content -LiteralPath $runModePath -Raw } else { $null }
$restaurantLockPath = Join-Path $fleetRoot ".codex-local\locks\RestaurantDemo.lock.json"
$previousRestaurantLock = if (Test-Path -LiteralPath $restaurantLockPath) { Get-Content -LiteralPath $restaurantLockPath -Raw } else { $null }
try {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $runModePath) | Out-Null
    ([ordered]@{ fleetMode = "ACTIVE"; activeProjects = @("EasyLife") } | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $runModePath -Encoding UTF8
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $restaurantLockPath) | Out-Null
    ([ordered]@{ project = "RestaurantDemo"; pid = 999999; startedAt = (Get-Date).AddHours(-2).ToString("o") } | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $restaurantLockPath -Encoding UTF8

    $easyOnlyScheduled = Invoke-HarnessCommand -Name "Scheduled dry-run respects EasyLife-only active scope" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "scheduled-selected-overnight-run.ps1"),
        "-DryRun",
        "-SkipHarnessTest"
    )
    $easyOnlyScheduledText = ($easyOnlyScheduled.output -join "`n")
    Add-TestResult -Name "Scheduled dry-run only selects EasyLife" -Passed ($easyOnlyScheduledText -match "checking projects: EasyLife" -and $easyOnlyScheduledText -notmatch "checking projects:.*RestaurantDemo|Launching selected fleet:.*RestaurantDemo")
    Add-TestResult -Name "RestaurantDemo stale lock untouched by EasyLife-only scheduled dry-run" -Passed (Test-Path -LiteralPath $restaurantLockPath)

    $restaurantWatchdogDryRun = Invoke-HarnessCommand -Name "Watchdog dry-run filters RestaurantDemo outside active scope" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "fleet-runner-watchdog.ps1"),
        "-Project", "RestaurantDemo",
        "-ValidateLaunchCommandOnly",
        "-DryRun"
    )
    $restaurantWatchdogText = ($restaurantWatchdogDryRun.output -join "`n")
    Add-TestResult -Name "Watchdog does not produce RestaurantDemo launch under EasyLife-only scope" -Passed ($restaurantWatchdogText -notmatch "RestaurantDemo")
} finally {
    if ($null -ne $previousRunModeText) {
        Set-Content -LiteralPath $runModePath -Value $previousRunModeText -Encoding UTF8
    } else {
        Remove-Item -LiteralPath $runModePath -Force -ErrorAction SilentlyContinue
    }
    if ($null -ne $previousRestaurantLock) {
        Set-Content -LiteralPath $restaurantLockPath -Value $previousRestaurantLock -Encoding UTF8
    } else {
        Remove-Item -LiteralPath $restaurantLockPath -Force -ErrorAction SilentlyContinue
    }
}

$heartbeatProject = "HarnessHeartbeat"
$heartbeatRoot = Join-Path $fleetRoot ".codex-local\runs\$heartbeatProject"
$heartbeatPath = Join-Path $heartbeatRoot "heartbeat.json"
Remove-Item -LiteralPath $heartbeatPath -Force -ErrorAction SilentlyContinue
[void](Invoke-HarnessCommand -Name "Watchdog heartbeat reader handles missing file" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "fleet-runner-watchdog.ps1"),
    "-Project", $heartbeatProject,
    "-ValidateHeartbeatOnly"
))

New-Item -ItemType Directory -Force -Path $heartbeatRoot | Out-Null
$heartbeatPayload = [ordered]@{
    project = $heartbeatProject
    pid = $PID
    startedAt = (Get-Date).ToUniversalTime().AddMinutes(-1).ToString("o")
    lastHeartbeatAt = (Get-Date).ToUniversalTime().ToString("o")
    lastProgressAt = (Get-Date).ToUniversalTime().ToString("o")
    runShape = [ordered]@{
        batchSize = 1
        maxBatches = 24
        maxRuntimeMinutes = 720
        maxCompletedTasks = 14
        quarantineFailedTasks = $true
        pushCheckpoint = $true
    }
    currentTaskSummary = "fixture active task"
    lastCommit = "abcdef0"
    status = "active"
}
$heartbeatPayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $heartbeatPath -Encoding UTF8
$readHeartbeat = Get-Content -LiteralPath $heartbeatPath -Raw | ConvertFrom-Json
$requiredHeartbeatFields = @("project", "pid", "startedAt", "lastHeartbeatAt", "lastProgressAt", "runShape", "currentTaskSummary", "lastCommit", "status")
$missingHeartbeatFields = @($requiredHeartbeatFields | Where-Object { $null -eq $readHeartbeat.PSObject.Properties[$_] })
Add-TestResult -Name "Runner heartbeat fixture has required schema" -Passed ($missingHeartbeatFields.Count -eq 0) -Detail ($(if ($missingHeartbeatFields.Count -gt 0) { "missing: $($missingHeartbeatFields -join ', ')" } else { "" }))
$watchdogCurrentHeartbeat = Invoke-HarnessCommand -Name "Watchdog heartbeat reader classifies current heartbeat" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "fleet-runner-watchdog.ps1"),
    "-Project", $heartbeatProject,
    "-ValidateHeartbeatOnly"
)
Add-TestResult -Name "Watchdog current heartbeat is active" -Passed (($watchdogCurrentHeartbeat.output -join "`n") -match "\bactive\b" -and ($watchdogCurrentHeartbeat.output -join "`n") -match "status=active")

$heartbeatPayload.pid = 999999
$heartbeatPayload.lastHeartbeatAt = (Get-Date).ToUniversalTime().AddHours(-2).ToString("o")
$heartbeatPayload.lastProgressAt = (Get-Date).ToUniversalTime().AddHours(-2).ToString("o")
$heartbeatPayload | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $heartbeatPath -Encoding UTF8
$watchdogStaleHeartbeat = Invoke-HarnessCommand -Name "Watchdog heartbeat reader classifies dead PID as stale" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "fleet-runner-watchdog.ps1"),
    "-Project", $heartbeatProject,
    "-ValidateHeartbeatOnly"
)
Add-TestResult -Name "Watchdog stale heartbeat is not active" -Passed (($watchdogStaleHeartbeat.output -join "`n") -match "\bstale\b" -and ($watchdogStaleHeartbeat.output -join "`n") -notmatch "heartbeat: active")

[void](Invoke-HarnessCommand -Name "Remote status heartbeat reader handles stale fixture" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "fleet-remote-control.ps1"),
    "-Project", $heartbeatProject,
    "-ValidateHeartbeatOnly",
    "-DryRun"
))
Remove-Item -LiteralPath $heartbeatPath -Force -ErrorAction SilentlyContinue
[void](Invoke-HarnessCommand -Name "Remote status heartbeat reader handles missing file" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "fleet-remote-control.ps1"),
    "-Project", $heartbeatProject,
    "-ValidateHeartbeatOnly",
    "-DryRun"
))

$lockCleanupRoot = Join-Path $fleetRoot ".codex-local\locks"
New-Item -ItemType Directory -Force -Path $lockCleanupRoot | Out-Null
$deadLockProject = "HarnessDeadLock"
$deadLockPath = Join-Path $lockCleanupRoot "$deadLockProject.lock.json"
([ordered]@{ project = $deadLockProject; pid = 999999; startedAt = (Get-Date).AddHours(-2).ToString("o") } | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $deadLockPath -Encoding UTF8
$deadLockCleanup = Invoke-HarnessCommand -Name "Remote status lock cleanup removes dead PID lock" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "fleet-remote-control.ps1"),
    "-Project", $deadLockProject,
    "-ValidateLockCleanupOnly",
    "-DryRun"
)
Add-TestResult -Name "Dead PID lock file removed" -Passed (!(Test-Path -LiteralPath $deadLockPath) -and (($deadLockCleanup.output -join "`n") -match "removed-stale-dead-pid"))

$activeChildLockProject = "HarnessActiveChildLock"
$activeChildLockPath = Join-Path $lockCleanupRoot "$activeChildLockProject.lock.json"
([ordered]@{ project = $activeChildLockProject; pid = $PID; startedAt = (Get-Date).AddHours(-2).ToString("o") } | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $activeChildLockPath -Encoding UTF8
try {
    $activeChildCleanup = Invoke-HarnessCommand -Name "Remote status lock cleanup preserves active child lock" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "fleet-remote-control.ps1"),
        "-Project", $activeChildLockProject,
        "-ValidateLockCleanupOnly",
        "-DryRun"
    )
    Add-TestResult -Name "Active child lock file preserved" -Passed ((Test-Path -LiteralPath $activeChildLockPath) -and (($activeChildCleanup.output -join "`n") -match "state=active"))
} finally {
    Remove-Item -LiteralPath $activeChildLockPath -Force -ErrorAction SilentlyContinue
}

$easyLifeSafe = "EasyLife"
$easyLifeHeartbeatRoot = Join-Path $fleetRoot ".codex-local\runs\$easyLifeSafe"
$easyLifeHeartbeatPath = Join-Path $easyLifeHeartbeatRoot "heartbeat.json"
$easyLifeLockRoot = Join-Path $fleetRoot ".codex-local\locks"
$easyLifeLockPath = Join-Path $easyLifeLockRoot "$easyLifeSafe.lock.json"
$previousEasyLifeHeartbeat = if (Test-Path -LiteralPath $easyLifeHeartbeatPath) { Get-Content -LiteralPath $easyLifeHeartbeatPath -Raw } else { $null }
$previousEasyLifeLock = if (Test-Path -LiteralPath $easyLifeLockPath) { Get-Content -LiteralPath $easyLifeLockPath -Raw } else { $null }
try {
    New-Item -ItemType Directory -Force -Path $easyLifeHeartbeatRoot | Out-Null
    New-Item -ItemType Directory -Force -Path $easyLifeLockRoot | Out-Null
    $activeEasyLifeHeartbeat = [ordered]@{
        project = "EasyLife"
        pid = $PID
        startedAt = (Get-Date).ToUniversalTime().AddMinutes(-1).ToString("o")
        lastHeartbeatAt = (Get-Date).ToUniversalTime().ToString("o")
        lastProgressAt = (Get-Date).ToUniversalTime().ToString("o")
        runShape = [ordered]@{
            batchSize = 1
            maxBatches = 24
            maxRuntimeMinutes = 720
            maxCompletedTasks = 14
            loopPhase = "simplicity"
            quarantineFailedTasks = $true
            pushCheckpoint = $true
        }
        currentTaskSummary = "fixture EasyLife active run"
        lastCommit = "abcdef0"
        status = "active"
    }
    $activeEasyLifeHeartbeat | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $easyLifeHeartbeatPath -Encoding UTF8
    ([ordered]@{ project = "EasyLife"; pid = $PID; createdAt = (Get-Date).ToUniversalTime().ToString("o") } | ConvertTo-Json -Depth 4) | Set-Content -LiteralPath $easyLifeLockPath -Encoding UTF8
    $activeEasyLifeSnapshot = Invoke-HarnessCommand -Name "Remote status snapshot shows active EasyLife runner" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "fleet-remote-control.ps1"),
        "-Project", "EasyLife",
        "-ValidateStatusSnapshotOnly",
        "-DryRun"
    )
    $activeEasyLifeText = ($activeEasyLifeSnapshot.output -join "`n")
    Add-TestResult -Name "Remote status active EasyLife shows RUNNING and PID" -Passed ($activeEasyLifeText -match "Runner state: RUNNING" -and $activeEasyLifeText -match "Runner PID: $PID" -and $activeEasyLifeText -match "Run shape: .*batch=1.*maxBatches=24.*runtime=720m")

    Remove-Item -LiteralPath $easyLifeHeartbeatPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $easyLifeLockPath -Force -ErrorAction SilentlyContinue
    $missingRunnerSnapshot = Invoke-HarnessCommand -Name "Remote status snapshot handles missing heartbeat" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "fleet-remote-control.ps1"),
        "-Project", "EasyLife",
        "-ValidateStatusSnapshotOnly",
        "-DryRun"
    )
    $missingRunnerText = ($missingRunnerSnapshot.output -join "`n")
    Add-TestResult -Name "Remote status missing heartbeat reports clean state" -Passed ($missingRunnerText -match "Runner state: (READY|PARKED|BLOCKED)" -and $missingRunnerText -match "Last heartbeat: none")
} finally {
    if ($null -ne $previousEasyLifeHeartbeat) {
        Set-Content -LiteralPath $easyLifeHeartbeatPath -Value $previousEasyLifeHeartbeat -Encoding UTF8
    } else {
        Remove-Item -LiteralPath $easyLifeHeartbeatPath -Force -ErrorAction SilentlyContinue
    }
    if ($null -ne $previousEasyLifeLock) {
        Set-Content -LiteralPath $easyLifeLockPath -Value $previousEasyLifeLock -Encoding UTF8
    } else {
        Remove-Item -LiteralPath $easyLifeLockPath -Force -ErrorAction SilentlyContinue
    }
}

$remoteStatusDryRun = Invoke-HarnessCommand -Name "Remote status supervisor dry-run is observation-only" -Arguments @(
    "-NoProfile",
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $fleetRoot "fleet-remote-control.ps1"),
    "-Project", "EasyLife",
    "-RunSupervisor",
    "-Publish",
    "-ForceReport",
    "-SkipPull",
    "-DryRun"
)
$remoteStatusText = ($remoteStatusDryRun.output -join "`n")
Add-TestResult -Name "Remote status passes supervisor ObservationOnly" -Passed ($remoteStatusText -match "fleet-supervisor\.ps1" -and $remoteStatusText -match "-ObservationOnly\b")
Add-TestResult -Name "Remote status dry-run does not request repair launch" -Passed ($remoteStatusText -notmatch "-AutoRelaunchRepair\b|run-checkpoint-loop\.ps1|launch-overnight-run\.ps1|scheduled-selected-overnight-run\.ps1")

$scheduledLogRoot = Join-Path $fleetRoot "out\harness-scheduled-runs"
New-Item -ItemType Directory -Force -Path $scheduledLogRoot | Out-Null
$nightReportHarnessLog = Join-Path $scheduledLogRoot "harness-proof-dryrun-$PID.log"
$nightReportHarnessMd = Join-Path $fleetRoot "out\fleet-night-report-harness.md"
$nightReportHarnessJson = Join-Path $fleetRoot "out\fleet-night-report-harness.json"
try {
    @(
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Dry-run launch validation exited with code 0",
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Dry run passed. No windows launched."
    ) | Set-Content -Path $nightReportHarnessLog -Encoding UTF8

    [void](Invoke-HarnessCommand -Name "Night report ignores proof dry-runs" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "fleet-night-report.ps1"),
        "-SinceHours", "1",
        "-IgnoreDryRuns",
        "-ScheduleOnly",
        "-ScheduledRunLogRoot", $scheduledLogRoot,
        "-ExcludeProject", (($SelectedProjects + $ExcludedProjects) -join ","),
        "-OutFile", $nightReportHarnessMd,
        "-JsonOutFile", $nightReportHarnessJson
    ))

    if (Test-Path -LiteralPath $nightReportHarnessJson) {
        $nightReportHarness = Get-Content -LiteralPath $nightReportHarnessJson -Raw | ConvertFrom-Json
        $scheduledRunCount = @($nightReportHarness.scheduledRuns).Count
        $shipCount = @($nightReportHarness.ships).Count
        Add-TestResult -Name "Night report removed harness dry-run log" -Passed ($scheduledRunCount -eq 0) -Detail "scheduledRuns=$scheduledRunCount"
        Add-TestResult -Name "Night report schedule-only skips ship attention" -Passed ($shipCount -eq 0 -and $nightReportHarness.scheduleOnly) -Detail "ships=$shipCount scheduleOnly=$($nightReportHarness.scheduleOnly)"
    } else {
        Add-TestResult -Name "Night report harness JSON exists" -Passed $false -Detail $nightReportHarnessJson
    }
} finally {
    Remove-Item -LiteralPath $nightReportHarnessLog -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $nightReportHarnessMd -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $nightReportHarnessJson -Force -ErrorAction SilentlyContinue
}

if (!$SkipProjectValidation) {
    foreach ($ship in $SelectedProjects) {
        [void](Invoke-HarnessCommand -Name "Checkpoint loop validates $ship" -Arguments @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "run-checkpoint-loop.ps1"),
            "-Project", $ship,
            "-ValidateOnly"
        ))
    }
}

$outRoot = Join-Path $fleetRoot "out"
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$reportPath = Join-Path $outRoot "fleet-harness-test.md"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$lines = @(
    "# Fleet Harness Test",
    "",
    "- Ran: $timestamp",
    "- Selected projects: $($SelectedProjects -join ', ')",
    "- Excluded projects: $($ExcludedProjects -join ', ')",
    "",
    "| Check | Result | Detail |",
    "| --- | --- | --- |"
)
foreach ($result in $results) {
    $lines += "| $($result.name) | $(if ($result.passed) { 'PASS' } else { 'FAIL' }) | $($result.detail -replace '\|', '/') |"
}
Set-Content -Path $reportPath -Value $lines -Encoding UTF8
Write-Host "Harness report: $reportPath" -ForegroundColor Cyan

$failed = @($results | Where-Object { !$_.passed })
if ($failed.Count -gt 0) {
    Write-Host "$($failed.Count) harness check(s) failed." -ForegroundColor Red
    Release-HarnessLock
    exit 1
}

Release-HarnessLock
Write-Host "Fleet harness self-test passed." -ForegroundColor Green
