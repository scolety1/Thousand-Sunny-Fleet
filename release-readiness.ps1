[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string]$BaseBranch = "main",

    [string]$OutFile = "out\release-readiness.md",

    [switch]$SkipBuild
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$fleetRuntime = Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1"
if (!(Test-Path $fleetRuntime)) {
    Write-Host "Fleet runtime helper not found: $fleetRuntime" -ForegroundColor Red
    exit 1
}
. $fleetRuntime

function Get-ConfigPropertyValue {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-MarkdownValue {
    param([string]$Path, [string]$Heading)
    if (!(Test-Path $Path)) { return "missing" }
    $text = Get-Content $Path -Raw
    $match = [regex]::Match($text, "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n\s*([^\r\n#]+)")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return "unknown"
}

function Test-ApprovedStatus {
    param([string]$Path)
    if (!(Test-Path $Path)) { return $false }
    $text = Get-Content $Path -Raw
    return ($text -match "(?im)^\s*Status:\s*APPROVED\s*$")
}

function Add-Reason {
    param([System.Collections.Generic.List[string]]$Reasons, [string]$Message)
    if (![string]::IsNullOrWhiteSpace($Message)) { $Reasons.Add($Message) | Out-Null }
}

function Invoke-ProjectBuild {
    param([object]$ProjectConfig)
    if ($SkipBuild) { return "skipped" }
    $buildCommand = [string](Get-ConfigPropertyValue -Object $ProjectConfig -Name "buildCommand")
    if ([string]::IsNullOrWhiteSpace($buildCommand)) { return "not configured" }
    $buildDirectory = [string](Get-ConfigPropertyValue -Object $ProjectConfig -Name "buildDirectory")
    if ([string]::IsNullOrWhiteSpace($buildDirectory)) { $buildDirectory = "." }
    $buildPath = Resolve-Path $buildDirectory -ErrorAction SilentlyContinue
    if (!$buildPath) { return "failed" }
    $timeouts = Get-ConfigPropertyValue -Object $ProjectConfig -Name "timeouts"
    $timeout = 600
    $configuredTimeout = Get-ConfigPropertyValue -Object $timeouts -Name "build"
    if ($null -ne $configuredTimeout -and [int]$configuredTimeout -gt 0) { $timeout = [int]$configuredTimeout }
    $logPath = Join-Path ".codex-logs" ("release-build-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss"))
    $result = Invoke-FleetProcess -FilePath "powershell" -Arguments @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $buildCommand) -WorkingDirectory $buildPath.Path -LogPath $logPath -TimeoutSeconds $timeout
    if ($result.exitCode -eq 0) { return "passed" }
    if ($result.timedOut) { return "timed out" }
    return "failed"
}

function Get-UncheckedTaskCount {
    if (!(Test-Path "docs/codex/TASK_QUEUE.md")) { return 0 }
    return @(Select-String -Path "docs/codex/TASK_QUEUE.md" -Pattern "^\s*-\s+\[ \]" -ErrorAction SilentlyContinue).Count
}

if (!(Test-Path $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$projects = @($parsedProjects | ForEach-Object { $_ })
if (![string]::IsNullOrWhiteSpace($Project)) {
    $projects = @($projects | Where-Object { [string]$_.name -ceq $Project })
    if ($projects.Count -ne 1) {
        Write-Host "Project not found: $Project" -ForegroundColor Red
        exit 1
    }
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$results = @()

foreach ($projectConfig in $projects) {
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $repo = [string](Get-ConfigPropertyValue -Object $projectConfig -Name "repo")
    $name = [string](Get-ConfigPropertyValue -Object $projectConfig -Name "name")
    $repoPath = Resolve-Path -LiteralPath $repo -ErrorAction SilentlyContinue
    if (!$repoPath) {
        Add-Reason -Reasons $reasons -Message "Repo missing: $repo"
        $results += [pscustomobject]@{ name = $name; status = "DO NOT RELEASE"; repo = $repo; reasons = @($reasons); warnings = @($warnings); build = "missing"; commits = 0; changed = @() }
        continue
    }

    Push-Location $repoPath.Path
    $dirty = @(git status --short 2>$null)
    if ($dirty.Count -gt 0) { Add-Reason -Reasons $reasons -Message "Working tree is dirty." }
    $commits = @(git log --oneline "$BaseBranch..HEAD" 2>$null)
    $changed = @(git diff --name-status "$BaseBranch..HEAD" 2>$null)
    $build = Invoke-ProjectBuild -ProjectConfig $projectConfig
    if ($build -notin @("passed", "skipped", "not configured")) { Add-Reason -Reasons $reasons -Message "Build is $build." }

    $checkpoint = Get-MarkdownValue -Path "docs/codex/CHECKPOINT_REVIEW.md" -Heading "Verdict"
    $joey = Get-MarkdownValue -Path "docs/codex/JOEY_SECURITY_REVIEW.md" -Heading "Verdict"
    $runtime = Get-MarkdownValue -Path "docs/codex/RUNTIME_VERIFICATION.md" -Heading "Verdict"
    $migration = Get-MarkdownValue -Path "docs/codex/MIGRATION_REVIEW.md" -Heading "Verdict"
    $apiContract = Get-MarkdownValue -Path "docs/codex/API_CONTRACT_REVIEW.md" -Heading "Verdict"
    $seedFixture = Get-MarkdownValue -Path "docs/codex/SEED_FIXTURE_REVIEW.md" -Heading "Verdict"
    $sensitive = Get-MarkdownValue -Path "docs/codex/SENSITIVE_SYSTEMS_REVIEW.md" -Heading "Verdict"

    foreach ($gate in @(
        @{ name = "checkpoint"; value = $checkpoint },
        @{ name = "Joey"; value = $joey },
        @{ name = "runtime"; value = $runtime },
        @{ name = "migration"; value = $migration },
        @{ name = "API contract"; value = $apiContract },
        @{ name = "seed fixture"; value = $seedFixture },
        @{ name = "sensitive systems"; value = $sensitive }
    )) {
        if ([string]$gate.value -match "^RED\b") { Add-Reason -Reasons $reasons -Message "$($gate.name) gate is RED." }
        elseif ([string]$gate.value -match "^YELLOW\b") { Add-Reason -Reasons $warnings -Message "$($gate.name) gate is YELLOW." }
        elseif ([string]$gate.value -eq "missing" -and $gate.name -in @("runtime", "migration", "sensitive systems")) { Add-Reason -Reasons $warnings -Message "$($gate.name) report is missing." }
    }

    if (Get-UncheckedTaskCount -gt 0) { Add-Reason -Reasons $warnings -Message "Unchecked tasks remain." }
    if (!(Test-Path "docs/codex/DEPLOYMENT_PLAN.md")) { Add-Reason -Reasons $warnings -Message "Missing DEPLOYMENT_PLAN.md." }
    if (!(Test-Path "docs/codex/POST_DEPLOY_SMOKE.md")) { Add-Reason -Reasons $warnings -Message "Missing POST_DEPLOY_SMOKE.md." }
    if (!(Test-Path "docs/codex/ROLLBACK_PLAN.md")) { Add-Reason -Reasons $warnings -Message "Missing ROLLBACK_PLAN.md." }

    $deployApproved = Test-ApprovedStatus -Path "docs/codex/RELEASE_APPROVAL.md"
    if (!$deployApproved) { Add-Reason -Reasons $warnings -Message "Release approval is missing or DRAFT." }

    $status = if ($reasons.Count -gt 0) {
        "DO NOT RELEASE"
    } elseif ($warnings.Count -gt 0) {
        "READY FOR HUMAN RELEASE REVIEW"
    } else {
        "READY TO RELEASE AFTER HUMAN APPROVAL"
    }

    $results += [pscustomobject]@{
        name = $name
        status = $status
        repo = $repoPath.Path
        reasons = @($reasons)
        warnings = @($warnings)
        build = $build
        commits = $commits.Count
        changed = @($changed)
        checkpoint = $checkpoint
        joey = $joey
        runtime = $runtime
        migration = $migration
        apiContract = $apiContract
        seedFixture = $seedFixture
        sensitive = $sensitive
    }
    Pop-Location
}

$overall = if (@($results | Where-Object { $_.status -eq "DO NOT RELEASE" }).Count -gt 0) {
    "DO NOT RELEASE"
} elseif (@($results | Where-Object { $_.status -eq "READY FOR HUMAN RELEASE REVIEW" }).Count -gt 0) {
    "READY FOR HUMAN RELEASE REVIEW"
} else {
    "READY TO RELEASE AFTER HUMAN APPROVAL"
}

$lines = @(
    "# Fleet Release Readiness",
    "",
    "Generated: $timestamp",
    "Base branch: $BaseBranch",
    "Overall: $overall",
    "",
    "This report never deploys. It packages release evidence for human review.",
    "",
    "| Ship | Status | Build | Commits | Checkpoint | Joey | Runtime | Migration | API Contract | Seed Fixture | Sensitive |",
    "| --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- |"
)
foreach ($result in $results) {
    $lines += "| $($result.name) | $($result.status) | $($result.build) | $($result.commits) | $($result.checkpoint) | $($result.joey) | $($result.runtime) | $($result.migration) | $($result.apiContract) | $($result.seedFixture) | $($result.sensitive) |"
}

foreach ($result in $results) {
    $lines += ""
    $lines += "## $($result.name)"
    $lines += ""
    $lines += "- Status: $($result.status)"
    $lines += "- Repo: $($result.repo)"
    $lines += "- Build: $($result.build)"
    $lines += "- Commits since base: $($result.commits)"
    $lines += "- Required human release approval: docs/codex/RELEASE_APPROVAL.md"
    $lines += "- Required deployment plan: docs/codex/DEPLOYMENT_PLAN.md"
    $lines += "- Required post-deploy smoke plan: docs/codex/POST_DEPLOY_SMOKE.md"
    $lines += "- Required rollback plan: docs/codex/ROLLBACK_PLAN.md"
    $lines += ""
    $lines += "Reasons:"
    if ($result.reasons.Count -eq 0) { $lines += "- None" } else { $result.reasons | ForEach-Object { $lines += "- $_" } }
    $lines += ""
    $lines += "Warnings:"
    if ($result.warnings.Count -eq 0) { $lines += "- None" } else { $result.warnings | ForEach-Object { $lines += "- $_" } }
    $lines += ""
    $lines += "Changed files:"
    if ($result.changed.Count -eq 0) { $lines += "- None" } else { $result.changed | ForEach-Object { $lines += "- $_" } }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
Set-Content -Path $OutFile -Value $lines
Write-Host "Release readiness report: $OutFile" -ForegroundColor Green
Write-Host "Overall: $overall"

if ($overall -eq "DO NOT RELEASE") { exit 1 }
exit 0
