[CmdletBinding(PositionalBinding = $false)]
param(
    [string[]]$SelectedProjects = @("EasyLife", "RestaurantDemo", "ShiftPlate"),

    [string[]]$ExcludedProjects = @("CursorPets", "NinersWarRoom", "Tree"),

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

foreach ($script in @(
    ".\launch-overnight-run.ps1",
    ".\run-checkpoint-loop.ps1",
    ".\scheduled-selected-overnight-run.ps1",
    ".\fleet-night-report.ps1",
    ".\fleet-supervisor.ps1",
    ".\harbor-master.ps1",
    ".\tools\codex-fleet-launcher.ps1",
    ".\tools\codex-fleet-runtime.ps1"
)) {
    Test-PowerShellParse -Path $script
}

$selected = ($SelectedProjects -join ",")
$excluded = ($ExcludedProjects -join ",")

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

$latestLaunch = Join-Path $fleetRoot "out\latest-launch.md"
if (Test-Path $latestLaunch) {
    $launchText = Get-Content $latestLaunch -Raw
    foreach ($ship in $SelectedProjects) {
        Add-TestResult -Name "Manifest includes $ship" -Passed ($launchText -match "\|\s*$([regex]::Escape($ship))\s*\|")
    }
    foreach ($ship in $ExcludedProjects) {
        Add-TestResult -Name "Manifest excludes $ship" -Passed ($launchText -notmatch "\|\s*$([regex]::Escape($ship))\s*\|")
    }
} else {
    Add-TestResult -Name "Manifest exists after selected dry-run" -Passed $false -Detail $latestLaunch
}

$tooSmallExpected = @($SelectedProjects | Select-Object -First ([Math]::Max(1, $SelectedProjects.Count - 1))) -join ","
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

[void](Invoke-HarnessCommand -Name "Scheduled selected wrapper dry-run passes safety preflight" -Arguments @(
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
    "-SkipHarnessTest",
    "-DryRun"
))

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
    exit 1
}

Write-Host "Fleet harness self-test passed." -ForegroundColor Green
