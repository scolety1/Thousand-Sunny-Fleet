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

$selected = ($SelectedProjects -join ",")
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
    foreach ($ship in $SelectedProjects) {
        Add-TestResult -Name "Proof manifest includes $ship" -Passed ($launchText -match "\|\s*$([regex]::Escape($ship))\s*\|")
    }
    foreach ($ship in $ExcludedProjects) {
        Add-TestResult -Name "Proof manifest excludes $ship" -Passed ($launchText -notmatch "\|\s*$([regex]::Escape($ship))\s*\|")
    }
} else {
    Add-TestResult -Name "Proof manifest exists after selected dry-run" -Passed $false -Detail $latestProofLaunch
}

$tooSmallExpectedProjects = @($SelectedProjects | Select-Object -First ([Math]::Max(0, $SelectedProjects.Count - 1)))
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
        "-ScheduledRunLogRoot", $scheduledLogRoot,
        "-ExcludeProject", (($SelectedProjects + $ExcludedProjects) -join ","),
        "-OutFile", $nightReportHarnessMd,
        "-JsonOutFile", $nightReportHarnessJson
    ))

    if (Test-Path -LiteralPath $nightReportHarnessJson) {
        $nightReportHarness = Get-Content -LiteralPath $nightReportHarnessJson -Raw | ConvertFrom-Json
        $scheduledRunCount = @($nightReportHarness.scheduledRuns).Count
        Add-TestResult -Name "Night report removed harness dry-run log" -Passed ($scheduledRunCount -eq 0) -Detail "scheduledRuns=$scheduledRunCount"
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
