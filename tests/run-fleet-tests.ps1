[CmdletBinding(PositionalBinding = $false)]
param(
    [switch]$KeepFixtures
)

$ErrorActionPreference = "Stop"

$fleetRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$fixtureRoot = Join-Path $fleetRoot ".codex-local\fixtures"
$fixtureConfig = Join-Path $fixtureRoot "projects.fixture.json"
$runtimePath = Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1"

. $runtimePath

$script:Failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $script:Failures.Add($Message) | Out-Null
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        Write-Host "PASS: $Message" -ForegroundColor Green
    } else {
        Add-Failure $Message
    }
}

function Assert-False {
    param(
        [bool]$Condition,
        [string]$Message
    )

    Assert-True -Condition (!$Condition) -Message $Message
}

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )

    if ([string]$Actual -eq [string]$Expected) {
        Write-Host "PASS: $Message" -ForegroundColor Green
    } else {
        Add-Failure "$Message (expected '$Expected', got '$Actual')"
    }
}

function Invoke-Checked {
    param(
        [string]$FilePath,
        [string[]]$Arguments,
        [string]$WorkingDirectory = $fleetRoot,
        [int]$TimeoutSeconds = 60
    )

    return Invoke-FleetProcess -FilePath $FilePath -Arguments $Arguments -WorkingDirectory $WorkingDirectory -TimeoutSeconds $TimeoutSeconds
}

function Get-Project {
    param([string]$Name)

    $parsedProjects = Get-Content $fixtureConfig -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })
    return @($projects | Where-Object { [string]$_.name -eq $Name })[0]
}

function Test-PowerShellParsing {
    $files = @()
    $files += @(Get-ChildItem $fleetRoot -Filter "*.ps1" -File)
    $files += @(Get-ChildItem (Join-Path $fleetRoot "tools") -Filter "*.ps1" -File)
    $files += @(Get-ChildItem (Join-Path $fleetRoot "tests") -Filter "*.ps1" -File)

    foreach ($file in $files) {
        $tokens = $null
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
        Assert-Equal -Actual $parseErrors.Count -Expected 0 -Message "PowerShell parses $($file.Name)"
    }
}

function Test-TaskParsing {
    $lines = @(
        "- [ ] Top task",
        "  - [ ] Indented task",
        "`t- [ ] Tabbed task",
        "- [x] Completed task",
        "   text - [ ] not a task"
    )
    $unchecked = @($lines | Where-Object { $_ -match "^\s*-\s+\[ \]\s+(.+)$" })
    Assert-Equal -Actual $unchecked.Count -Expected 3 -Message "Unchecked markdown task regex allows zero or more leading whitespace"

    $updated = $false
    $completed = foreach ($line in $lines) {
        if (-not $updated -and $line -match "^(\s*-\s+)\[ \](\s+.+)$") {
            $updated = $true
            "$($Matches[1])[x]$($Matches[2])"
        } else {
            $line
        }
    }
    Assert-Equal -Actual $completed[0] -Expected "- [x] Top task" -Message "Task completion regex marks the first unchecked task only"
    Assert-Equal -Actual $completed[1] -Expected "  - [ ] Indented task" -Message "Task completion regex leaves later unchecked tasks alone"
}

function Test-RuntimeHelpers {
    Assert-True -Condition (Test-FleetRateLimitOutput -Output @("usage limit reached, try again in 12 minutes")) -Message "Rate-limit detector catches usage limit text"
    Assert-False -Condition (Test-FleetRateLimitOutput -Output @("regular build failed")) -Message "Rate-limit detector ignores normal failures"
    Assert-Equal -Actual (Get-FleetRateLimitDelaySeconds -Output @("try again in 12 minutes") -DefaultSeconds 3600) -Expected 780 -Message "Rate-limit delay parser adds a small buffer"

    Assert-True -Condition (Test-FleetBlockingReviewOutput -Text "REVIEW_FINDING: P1: bad thing") -Message "Review parser blocks P1 findings"
    Assert-True -Condition (Test-FleetBlockingReviewOutput -Text "::code-comment{priority=2 file='x'}") -Message "Review parser blocks priority 2 inline comments"
    Assert-False -Condition (Test-FleetBlockingReviewOutput -Text "REVIEW_STATUS: PASS") -Message "Review parser allows clean pass"

    $normal = Invoke-FleetProcess -FilePath "powershell" -Arguments @("-NoProfile", "-Command", "Write-Output fixture-ok") -TimeoutSeconds 10
    Assert-Equal -Actual $normal.exitCode -Expected 0 -Message "Invoke-FleetProcess captures successful exit code"
    Assert-True -Condition (($normal.output -join "`n") -match "fixture-ok") -Message "Invoke-FleetProcess captures output"

    $timeout = Invoke-FleetProcess -FilePath "powershell" -Arguments @("-NoProfile", "-Command", "Start-Sleep -Seconds 5") -TimeoutSeconds 1
    Assert-Equal -Actual $timeout.exitCode -Expected 124 -Message "Invoke-FleetProcess returns 124 on timeout"
    Assert-True -Condition $timeout.timedOut -Message "Invoke-FleetProcess marks timed-out process"
}

function Test-FixtureGeneration {
    $generator = Join-Path $fleetRoot "tests\new-fixture-ships.ps1"
    $result = Invoke-Checked -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $generator, "-Force")
    Assert-Equal -Actual $result.exitCode -Expected 0 -Message "Fixture ship generator exits successfully"
    Assert-True -Condition (Test-Path $fixtureConfig) -Message "Fixture project config exists"

    $parsedProjects = Get-Content $fixtureConfig -Raw | ConvertFrom-Json
    $projects = @($parsedProjects | ForEach-Object { $_ })
    Assert-Equal -Actual $projects.Count -Expected 3 -Message "Fixture config contains three ships"
}

function Test-ConfigResolution {
    foreach ($name in @("FixtureStaticDemo", "FixtureDocsOnly", "FixtureRealProduct")) {
        $result = Invoke-Checked -FilePath "powershell" -Arguments @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "run-checkpoint-loop.ps1"),
            "-ConfigPath", $fixtureConfig,
            "-Project", $name,
            "-ValidateOnly"
        )
        $output = $result.output -join "`n"
        Assert-Equal -Actual $result.exitCode -Expected 0 -Message "Checkpoint loop validates $name"
        Assert-True -Condition ($output -match "Implement models: gpt-fixture-primary, gpt-fixture-fallback") -Message "Model chain resolves for $name"
        Assert-True -Condition ($output -match "Rate-limit cooldown: 60s, max cooldowns 1") -Message "Rate-limit config resolves for $name"
        Assert-True -Condition ($output -match "Visual paths:") -Message "Visual path config is reported for $name"
    }
}

function Test-DoctorAndReadiness {
    $doctor = Invoke-Checked -FilePath "powershell" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "fleet-doctor.ps1"),
        "-ConfigPath", $fixtureConfig,
        "-Quiet"
    )
    Assert-Equal -Actual $doctor.exitCode -Expected 0 -Message "Fleet doctor passes fixture ships"

    $readiness = Invoke-Checked -FilePath "powershell" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "merge-readiness.ps1"),
        "-ConfigPath", $fixtureConfig,
        "-SkipBuild"
    )
    Assert-Equal -Actual $readiness.exitCode -Expected 0 -Message "Merge readiness passes fixture ships in skip-build mode"
    Assert-True -Condition (($readiness.output -join "`n") -match "SAFE TO MERGE AFTER HUMAN REVIEW") -Message "Merge readiness can produce a green overall result"
}

function Test-DebugCheckpoint {
    $project = Get-Project -Name "FixtureStaticDemo"
    $debug = Invoke-Checked -FilePath "powershell" -Arguments @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", (Join-Path $fleetRoot "debug-checkpoint.ps1"),
        "-Repo", $project.repo,
        "-BaseBranch", "main",
        "-Json"
    )
    Assert-Equal -Actual $debug.exitCode -Expected 0 -Message "Checkpoint debugger passes clean fixture branch"
    Assert-True -Condition (($debug.output -join "`n") -match '"result"\s*:\s*"PASS"') -Message "Checkpoint debugger JSON reports PASS"
}

function Test-SafeStaging {
    $project = Get-Project -Name "FixtureStaticDemo"
    Push-Location $project.repo
    try {
        Set-Content -Path "file with spaces.txt" -Value "stage me"
        Set-Content -Path "do-not-stage.txt" -Value "leave me"
        $paths = @("file with spaces.txt")
        & git add -- @paths
        $staged = @(git diff --cached --name-only)
        $unstaged = @(git ls-files --others --exclude-standard)
        Assert-True -Condition ($staged -contains "file with spaces.txt") -Message "Safe staging handles paths with spaces"
        Assert-True -Condition ($unstaged -contains "do-not-stage.txt") -Message "Safe staging leaves unrelated untracked files unstaged"
        & git reset -- "file with spaces.txt" | Out-Null
        Remove-Item -LiteralPath "file with spaces.txt", "do-not-stage.txt" -Force
    } finally {
        Pop-Location
    }
}

function Test-ReadOnlyDirtyGuard {
    $project = Get-Project -Name "FixtureStaticDemo"
    Push-Location $project.repo
    try {
        Set-Content -Path "dirty-before-planner.txt" -Value "dirty"
        $planner = Invoke-Checked -FilePath "powershell" -Arguments @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", (Join-Path $fleetRoot "generate-next-five.ps1"),
            "-Repo", $project.repo,
            "-BaseBranch", "main",
            "-Count", "1",
            "-TimeoutSeconds", "5"
        )
        Assert-True -Condition ($planner.exitCode -ne 0) -Message "Nami planner refuses dirty working tree before Codex"
        Assert-True -Condition (($planner.output -join "`n") -match "requires a clean working tree") -Message "Nami planner reports dirty tree reason"
        Remove-Item -LiteralPath "dirty-before-planner.txt" -Force
    } finally {
        Pop-Location
    }
}

Set-Location $fleetRoot
Write-Host "Running Codex Fleet tests..." -ForegroundColor Cyan

Test-PowerShellParsing
Test-TaskParsing
Test-RuntimeHelpers
Test-FixtureGeneration
Test-ConfigResolution
Test-DoctorAndReadiness
Test-DebugCheckpoint
Test-SafeStaging
Test-ReadOnlyDirtyGuard

if (!$KeepFixtures -and (Test-Path $fixtureRoot)) {
    $fixtureFullPath = [System.IO.Path]::GetFullPath($fixtureRoot)
    $allowedRoot = [System.IO.Path]::GetFullPath((Join-Path $fleetRoot ".codex-local\fixtures"))
    if ($fixtureFullPath.StartsWith($allowedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        Remove-Item -LiteralPath $fixtureFullPath -Recurse -Force
    }
}

if ($script:Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Codex Fleet tests failed: $($script:Failures.Count)" -ForegroundColor Red
    foreach ($failure in $script:Failures) {
        Write-Host "- $failure" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""
Write-Host "Codex Fleet tests passed." -ForegroundColor Green
exit 0
