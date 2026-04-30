[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string]$OutFile = "out\staging-deploy.md",

    [string]$JsonOutFile = "out\staging-deploy.json",

    [switch]$Template,

    [switch]$TreatWarningsAsBlockers,

    [switch]$AllowDirty,

    [switch]$PrintCommand
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Get-ConfigPropertyValue {
    param([object]$Object, [string]$Name)
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Add-Reason {
    param([System.Collections.Generic.List[string]]$Reasons, [string]$Message)
    if (![string]::IsNullOrWhiteSpace($Message)) { $Reasons.Add($Message) | Out-Null }
}

function Test-ApprovedStatus {
    param([string]$Path)
    if (!(Test-Path -LiteralPath $Path)) { return $false }
    $text = Get-Content -LiteralPath $Path -Raw
    return ($text -match "(?im)^\s*Status:\s*APPROVED\s*$")
}

function Get-MarkdownSectionValue {
    param([string]$Path, [string]$Heading)
    if (!(Test-Path -LiteralPath $Path)) { return "" }
    $text = Get-Content -LiteralPath $Path -Raw
    $match = [regex]::Match($text, "(?ims)^##\s+$([regex]::Escape($Heading))\s*\r?\n(.*?)(?=^\s*##\s+|\z)")
    if (!$match.Success) { return "" }
    return $match.Groups[1].Value.Trim()
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

function Ensure-StagingTemplates {
    $docsDir = "docs/codex"
    New-Item -ItemType Directory -Force -Path $docsDir | Out-Null
    $templates = @{
        "STAGING_DEPLOY_PLAN.md" = @"
# Staging Deploy Plan

Status: DRAFT

## Staging Target
Describe the staging-only hosting target. This must not be production.

## Staging URL
List the staging URL or preview URL.

## Build Command
List the local build command that produces the staging artifact.

## Deploy Command
List the manual staging deploy command. Do not include secrets. Production deploy commands are forbidden here.

## Environment Variables
List required staging environment variables or state "None".

## Data Safety
State what data is used in staging. Real production customer data is not allowed unless explicitly approved elsewhere.

## Owner
Name the human responsible for approving and running the staging deploy.
"@
        "STAGING_DEPLOY_APPROVAL.md" = @"
# Staging Deploy Approval

Status: DRAFT

## Approval
Set Status: APPROVED only after human review of the staging target, command, data safety, and rollback notes.

## Notes
Capture staging-specific caveats. This approval does not approve production deploy.
"@
        "STAGING_POST_DEPLOY_SMOKE.md" = @"
# Staging Post Deploy Smoke

## Smoke Command
List the command or URL checks to run against staging after deploy.

## Smoke Checklist
List the user flows that must work on staging.

## Success Criteria
Define what a passing staging deploy looks like.

## Failure Escalation
Define what to do if staging smoke checks fail.
"@
        "STAGING_ROLLBACK_PLAN.md" = @"
# Staging Rollback Plan

## Rollback Trigger
Define the staging failures that require rollback.

## Rollback Steps
List the exact staging rollback steps.

## Data Rollback Notes
State whether staging data rollback is needed or "None".

## Owner
Name the human responsible for staging rollback.
"@
    }

    foreach ($entry in $templates.GetEnumerator()) {
        $path = Join-Path $docsDir $entry.Key
        if (!(Test-Path -LiteralPath $path)) {
            Set-Content -LiteralPath $path -Value $entry.Value -Encoding UTF8
        }
    }
}

function Test-ProductionDeployLanguage {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return $false }
    return ($Text -match "(?i)\bproduction\b|\bprod\b|firebase deploy\b|vercel --prod\b|netlify deploy --prod\b")
}

if (!(Test-Path -LiteralPath $ConfigPath)) {
    Write-Host "Config not found: $ConfigPath" -ForegroundColor Red
    exit 1
}

$parsedProjects = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
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
        try {
            Ensure-StagingTemplates
        } finally {
            Pop-Location
        }
        Write-Host "Staging deploy templates ready for $name" -ForegroundColor Green
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
        $results += [pscustomobject]@{ name = $name; status = "DO NOT STAGE"; repo = $repo; reasons = @($reasons); warnings = @($warnings); deployCommand = ""; canPrintCommand = $false }
        continue
    }

    Push-Location $repoPath.Path
    try {
        $dirty = @(git status --short 2>$null)
        if ($dirty.Count -gt 0 -and !$AllowDirty) {
            Add-Reason -Reasons $reasons -Message "Working tree is dirty; staging deploy review requires a clean tree."
        } elseif ($dirty.Count -gt 0) {
            Add-Reason -Reasons $warnings -Message "Working tree is dirty but -AllowDirty was used."
        }

        $riskTier = [string](Get-ConfigPropertyValue -Object $projectConfig -Name "riskTier")
        $capabilities = Get-ConfigPropertyValue -Object $projectConfig -Name "capabilities"
        $canDeploy = [bool](Get-ConfigPropertyValue -Object $capabilities -Name "canDeploy")
        if ($riskTier -eq "production") {
            Add-Reason -Reasons $reasons -Message "Production-risk ships cannot use the staging deploy lane as production approval."
        }
        if (!$canDeploy) {
            Add-Reason -Reasons $warnings -Message "Project config has canDeploy=false; Fleet may validate staging evidence but must not execute deployment."
        }

        Test-RequiredSections -Path "docs/codex/STAGING_DEPLOY_PLAN.md" -Headings @("Staging Target", "Staging URL", "Build Command", "Deploy Command", "Environment Variables", "Data Safety", "Owner") | ForEach-Object { Add-Reason -Reasons $reasons -Message $_ }
        Test-RequiredSections -Path "docs/codex/STAGING_POST_DEPLOY_SMOKE.md" -Headings @("Smoke Command", "Smoke Checklist", "Success Criteria", "Failure Escalation") | ForEach-Object { Add-Reason -Reasons $reasons -Message $_ }
        Test-RequiredSections -Path "docs/codex/STAGING_ROLLBACK_PLAN.md" -Headings @("Rollback Trigger", "Rollback Steps", "Data Rollback Notes", "Owner") | ForEach-Object { Add-Reason -Reasons $reasons -Message $_ }

        $approved = Test-ApprovedStatus -Path "docs/codex/STAGING_DEPLOY_APPROVAL.md"
        if (!$approved) {
            Add-Reason -Reasons $reasons -Message "Staging deploy approval is missing or DRAFT."
        }

        $target = Get-MarkdownSectionValue -Path "docs/codex/STAGING_DEPLOY_PLAN.md" -Heading "Staging Target"
        $url = Get-MarkdownSectionValue -Path "docs/codex/STAGING_DEPLOY_PLAN.md" -Heading "Staging URL"
        $deployCommand = Get-MarkdownSectionValue -Path "docs/codex/STAGING_DEPLOY_PLAN.md" -Heading "Deploy Command"
        $buildCommand = Get-MarkdownSectionValue -Path "docs/codex/STAGING_DEPLOY_PLAN.md" -Heading "Build Command"
        $dataSafety = Get-MarkdownSectionValue -Path "docs/codex/STAGING_DEPLOY_PLAN.md" -Heading "Data Safety"
        if ([string]::IsNullOrWhiteSpace($target) -or $target -match "(?i)describe the") {
            Add-Reason -Reasons $reasons -Message "Staging target is not filled in."
        }
        if ([string]::IsNullOrWhiteSpace($url) -or $url -match "(?i)list the") {
            Add-Reason -Reasons $reasons -Message "Staging URL is not filled in."
        }
        if ([string]::IsNullOrWhiteSpace($deployCommand) -or $deployCommand -match "(?i)list the") {
            Add-Reason -Reasons $reasons -Message "Deploy command is not filled in."
        }
        if ([string]::IsNullOrWhiteSpace($buildCommand) -or $buildCommand -match "(?i)list the") {
            Add-Reason -Reasons $warnings -Message "Build command is not filled in."
        }
        if ([string]::IsNullOrWhiteSpace($dataSafety) -or $dataSafety -match "(?i)state what") {
            Add-Reason -Reasons $reasons -Message "Data safety notes are not filled in."
        }
        if (Test-ProductionDeployLanguage -Text $deployCommand) {
            Add-Reason -Reasons $reasons -Message "Deploy command appears to target production; staging lane forbids production deploy commands."
        }
        if ($url -match "(?i)\bprod\b|production") {
            Add-Reason -Reasons $reasons -Message "Staging URL appears to target production."
        }

        $status = if ($reasons.Count -gt 0) {
            "DO NOT STAGE"
        } elseif ($TreatWarningsAsBlockers -and $warnings.Count -gt 0) {
            "DO NOT STAGE"
        } elseif ($warnings.Count -gt 0) {
            "READY FOR HUMAN STAGING REVIEW"
        } else {
            "READY FOR STAGING COMMAND PRINT"
        }

        $canPrintCommand = ($status -ne "DO NOT STAGE" -and $approved -and ![string]::IsNullOrWhiteSpace($deployCommand))
        $results += [pscustomobject]@{
            name = $name
            status = $status
            repo = $repoPath.Path
            riskTier = $riskTier
            canDeploy = $canDeploy
            reasons = @($reasons)
            warnings = @($warnings)
            stagingTarget = $target
            stagingUrl = $url
            buildCommand = $buildCommand
            deployCommand = $deployCommand
            canPrintCommand = $canPrintCommand
        }
    } finally {
        Pop-Location
    }
}

$overall = if (@($results | Where-Object { $_.status -eq "DO NOT STAGE" }).Count -gt 0) {
    "DO NOT STAGE"
} elseif (@($results | Where-Object { $_.status -eq "READY FOR HUMAN STAGING REVIEW" }).Count -gt 0) {
    "READY FOR HUMAN STAGING REVIEW"
} else {
    "READY FOR STAGING COMMAND PRINT"
}

$lines = @(
    "# Fleet Staging Deploy Readiness",
    "",
    "Generated: $timestamp",
    "Overall: $overall",
    "",
    "This report does not deploy. It validates staging-only deploy evidence and keeps production deploy separate.",
    "",
    "| Ship | Status | Risk | canDeploy | Staging URL |",
    "| --- | --- | --- | --- | --- |"
)
foreach ($result in $results) {
    $lines += "| $($result.name) | $($result.status) | $($result.riskTier) | $($result.canDeploy) | $($result.stagingUrl) |"
}

foreach ($result in $results) {
    $lines += ""
    $lines += "## $($result.name)"
    $lines += ""
    $lines += "- Status: $($result.status)"
    $lines += "- Repo: $($result.repo)"
    $lines += "- Staging target: $($result.stagingTarget)"
    $lines += "- Staging URL: $($result.stagingUrl)"
    $lines += "- Required approval: docs/codex/STAGING_DEPLOY_APPROVAL.md"
    $lines += "- Required plan: docs/codex/STAGING_DEPLOY_PLAN.md"
    $lines += "- Required smoke plan: docs/codex/STAGING_POST_DEPLOY_SMOKE.md"
    $lines += "- Required rollback plan: docs/codex/STAGING_ROLLBACK_PLAN.md"
    $lines += ""
    $lines += "Reasons:"
    if ($result.reasons.Count -eq 0) { $lines += "- None" } else { $result.reasons | ForEach-Object { $lines += "- $_" } }
    $lines += ""
    $lines += "Warnings:"
    if ($result.warnings.Count -eq 0) { $lines += "- None" } else { $result.warnings | ForEach-Object { $lines += "- $_" } }
    if ($PrintCommand -and $result.canPrintCommand) {
        $lines += ""
        $lines += "Staging command for human execution:"
        $lines += '```powershell'
        $lines += $result.deployCommand
        $lines += '```'
    }
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $OutFile) | Out-Null
Set-Content -Path $OutFile -Value $lines -Encoding UTF8
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JsonOutFile) | Out-Null
[pscustomobject]@{
    generated = $timestamp
    overall = $overall
    neverDeploys = $true
    productionDeployAllowed = $false
    projects = $results
} | ConvertTo-Json -Depth 8 | Set-Content -Path $JsonOutFile -Encoding UTF8

Write-Host "Staging deploy report: $OutFile" -ForegroundColor Green
Write-Host "Staging deploy JSON: $JsonOutFile" -ForegroundColor Green
Write-Host "Overall: $overall"
if ($PrintCommand) {
    foreach ($result in $results | Where-Object { $_.canPrintCommand }) {
        Write-Host "Staging command for $($result.name): $($result.deployCommand)" -ForegroundColor Cyan
    }
}

if ($overall -eq "DO NOT STAGE") { exit 1 }
exit 0
