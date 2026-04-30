[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string]$BaseBranch = "main",

    [string]$OutFile = "out\release-readiness.md",

    [string]$JsonOutFile = "out\release-readiness.json",

    [switch]$SkipBuild,

    [switch]$Template,

    [switch]$TreatWarningsAsBlockers
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

function Ensure-ReleaseTemplates {
    $docsDir = "docs/codex"
    New-Item -ItemType Directory -Force -Path $docsDir | Out-Null
    $templates = @{
        "DEPLOYMENT_PLAN.md" = @"
# Deployment Plan

## Deployment Target
Describe the exact hosting target, environment, and URL.

## Build Artifact
Describe what artifact is released and where it comes from.

## Environment Variables
List required environment variables or state "None".

## Release Steps
List the manual release steps. Do not include secrets.

## Owner
Name the human responsible for approving and performing the release.
"@
        "POST_DEPLOY_SMOKE.md" = @"
# Post Deploy Smoke

## Smoke Command
List the command or URL checks to run after release.

## Smoke Checklist
List the user flows that must work after release.

## Success Criteria
Define what a passing release looks like.

## Failure Escalation
Define what to do if the smoke check fails.
"@
        "ROLLBACK_PLAN.md" = @"
# Rollback Plan

## Rollback Trigger
Define the concrete failures that require rollback.

## Rollback Steps
List the exact steps to restore the previous release.

## Data Rollback Notes
State whether data rollback is needed or "None".

## Owner
Name the human responsible for rollback.
"@
        "RELEASE_APPROVAL.md" = @"
# Release Approval

Status: DRAFT

## Approval
Set Status: APPROVED only after human review.

## Notes
Capture release-specific notes and caveats.
"@
    }

    foreach ($entry in $templates.GetEnumerator()) {
        $path = Join-Path $docsDir $entry.Key
        if (!(Test-Path -LiteralPath $path)) {
            Set-Content -LiteralPath $path -Value $entry.Value
        }
    }
}

function Test-RequiredSections {
    param([string]$Path, [string[]]$Headings)
    if (!(Test-Path -LiteralPath $Path)) {
        return @("Missing $Path.")
    }
    $text = Get-Content -LiteralPath $Path -Raw
    $missing = @()
    foreach ($heading in $Headings) {
        if ($text -notmatch "(?im)^##\s+$([regex]::Escape($heading))\s*$") {
            $missing += "$Path missing section: $heading."
        }
    }
    return $missing
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

if ($Template) {
    foreach ($projectConfig in $projects) {
        $repo = [string](Get-ConfigPropertyValue -Object $projectConfig -Name "repo")
        $name = [string](Get-ConfigPropertyValue -Object $projectConfig -Name "name")
        $repoPath = Resolve-Path -LiteralPath $repo -ErrorAction SilentlyContinue
        if (!$repoPath) {
            Write-Host "Repo missing for ${name}: $repo" -ForegroundColor Red
            exit 1
        }
        Push-Location $repoPath.Path
        Ensure-ReleaseTemplates
        Pop-Location
        Write-Host "Release templates ready for $name" -ForegroundColor Green
    }
    exit 0
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
        $results += [pscustomobject]@{ name = $name; status = "DO NOT RELEASE"; repo = $repo; reasons = @($reasons); warnings = @($warnings); build = "missing"; commits = 0; changed = @(); visual = "missing" }
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
    $visual = Get-MarkdownValue -Path "docs/codex/VISUAL_BUGS.md" -Heading "Verdict"
    $migration = Get-MarkdownValue -Path "docs/codex/MIGRATION_REVIEW.md" -Heading "Verdict"
    $apiContract = Get-MarkdownValue -Path "docs/codex/API_CONTRACT_REVIEW.md" -Heading "Verdict"
    $seedFixture = Get-MarkdownValue -Path "docs/codex/SEED_FIXTURE_REVIEW.md" -Heading "Verdict"
    $sensitive = Get-MarkdownValue -Path "docs/codex/SENSITIVE_SYSTEMS_REVIEW.md" -Heading "Verdict"

    foreach ($gate in @(
        @{ name = "checkpoint"; value = $checkpoint },
        @{ name = "Joey"; value = $joey },
        @{ name = "runtime"; value = $runtime },
        @{ name = "visual"; value = $visual },
        @{ name = "migration"; value = $migration },
        @{ name = "API contract"; value = $apiContract },
        @{ name = "seed fixture"; value = $seedFixture },
        @{ name = "sensitive systems"; value = $sensitive }
    )) {
        if ([string]$gate.value -match "^RED\b") { Add-Reason -Reasons $reasons -Message "$($gate.name) gate is RED." }
        elseif ([string]$gate.value -match "^YELLOW\b") { Add-Reason -Reasons $warnings -Message "$($gate.name) gate is YELLOW." }
        elseif ([string]$gate.value -eq "missing" -and $gate.name -in @("runtime", "visual", "migration", "sensitive systems")) { Add-Reason -Reasons $warnings -Message "$($gate.name) report is missing." }
    }

    if (Get-UncheckedTaskCount -gt 0) { Add-Reason -Reasons $warnings -Message "Unchecked tasks remain." }
    Test-RequiredSections -Path "docs/codex/DEPLOYMENT_PLAN.md" -Headings @("Deployment Target", "Build Artifact", "Environment Variables", "Release Steps", "Owner") | ForEach-Object { Add-Reason -Reasons $warnings -Message $_ }
    Test-RequiredSections -Path "docs/codex/POST_DEPLOY_SMOKE.md" -Headings @("Smoke Command", "Smoke Checklist", "Success Criteria", "Failure Escalation") | ForEach-Object { Add-Reason -Reasons $warnings -Message $_ }
    Test-RequiredSections -Path "docs/codex/ROLLBACK_PLAN.md" -Headings @("Rollback Trigger", "Rollback Steps", "Data Rollback Notes", "Owner") | ForEach-Object { Add-Reason -Reasons $warnings -Message $_ }

    $deployApproved = Test-ApprovedStatus -Path "docs/codex/RELEASE_APPROVAL.md"
    if (!$deployApproved) { Add-Reason -Reasons $warnings -Message "Release approval is missing or DRAFT." }

    $status = if ($reasons.Count -gt 0) {
        "DO NOT RELEASE"
    } elseif ($TreatWarningsAsBlockers -and $warnings.Count -gt 0) {
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
        visual = $visual
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
    "| Ship | Status | Build | Commits | Checkpoint | Joey | Runtime | Visual | Migration | API Contract | Seed Fixture | Sensitive |",
    "| --- | --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- |"
)
foreach ($result in $results) {
    $lines += "| $($result.name) | $($result.status) | $($result.build) | $($result.commits) | $($result.checkpoint) | $($result.joey) | $($result.runtime) | $($result.visual) | $($result.migration) | $($result.apiContract) | $($result.seedFixture) | $($result.sensitive) |"
}

foreach ($result in $results) {
    $lines += ""
    $lines += "## $($result.name)"
    $lines += ""
    $lines += "- Status: $($result.status)"
    $lines += "- Repo: $($result.repo)"
    $lines += "- Build: $($result.build)"
    $lines += "- Commits since base: $($result.commits)"
    $lines += "- Visual evidence: $($result.visual)"
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
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOutFile) | Out-Null
[pscustomobject]@{
    generated = $timestamp
    baseBranch = $BaseBranch
    overall = $overall
    neverDeploys = $true
    projects = $results
} | ConvertTo-Json -Depth 8 | Set-Content -Path $JsonOutFile
Write-Host "Release readiness report: $OutFile" -ForegroundColor Green
Write-Host "Release readiness JSON: $JsonOutFile" -ForegroundColor Green
Write-Host "Overall: $overall"

if ($overall -eq "DO NOT RELEASE") { exit 1 }
exit 0
