[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [ValidateSet("", "brief", "foundation", "shape", "simplicity", "polish", "proof", "parked")]
    [string]$Phase = "",

    [switch]$List,

    [switch]$WriteReference,

    [switch]$Validate
)

$ErrorActionPreference = "Stop"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $fleetRoot

function Stop-WithMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

function Get-ConfigPropertyValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-WebsiteStageContracts {
    $contracts = [ordered]@{}

    $contracts["brief"] = [pscustomobject]@{
        order = 1
        purpose = "Lock the product direction before coding."
        allowedWork = @("mission docs", "PHASE_STATE.md", "audience and buyer definition", "primary CTA", "required page list", "what-not-to-build")
        forbiddenWork = @("new implementation", "visual polish", "feature expansion", "routing rewrites")
        exitCriteria = @("Audience is specific", "Product Promise is concrete", "Primary Action is one clear action", "Showable Moment is named", "What Not To Build is explicit")
        reviewers = @("human direction", "product-usefulness")
        autoAdvance = "May advance to foundation when all brief fields are non-TODO and the ship has no admission/usefulness blocker."
        stopRules = @("unclear buyer", "unclear CTA", "broad platform framing", "missing what-not-to-build")
    }

    $contracts["foundation"] = [pscustomobject]@{
        order = 2
        purpose = "Create the minimum working site/app structure."
        allowedWork = @("required routes/pages", "navigation", "core demo flow", "local demo data", "basic responsive layout", "SITE_MAP.md", "visual-routes.json")
        forbiddenWork = @("final micro-polish", "new backend/auth/payments", "large copy voice pass", "unapproved dependencies")
        exitCriteria = @("Required pages/routes exist", "Navigation reaches every required page", "Primary CTA works locally", "Build/static check passes", "Mobile and desktop can be previewed")
        reviewers = @("build", "visual smoke", "Joey if sensitive scope appears")
        autoAdvance = "May advance to shape when the promised pages and primary flow exist and load."
        stopRules = @("missing required page", "broken route", "build failure", "sensitive scope request")
    }

    $contracts["shape"] = [pscustomobject]@{
        order = 3
        purpose = "Make the site understandable in 30 seconds."
        allowedWork = @("page order", "section hierarchy", "first viewport", "navigation labels", "CTA placement", "remove confusing sections")
        forbiddenWork = @("extra feature tours", "new routes unless a required page is missing", "generic marketing fluff", "tiny spacing-only churn")
        exitCriteria = @("First viewport says who it is for", "Primary action is obvious", "Core demo/showable moment is visible or one tap away", "No duplicate headers", "No route feels unrelated")
        reviewers = @("Simon", "Robin", "visual QA")
        autoAdvance = "May advance to simplicity when the structure is coherent and Simon/Robin are not RED for direction."
        stopRules = @("confusing first screen", "too many equal CTAs", "duplicate route identity", "unclear page purpose")
    }

    $contracts["simplicity"] = [pscustomobject]@{
        order = 4
        purpose = "Reduce cognitive load before adding anything else."
        allowedWork = @("remove", "combine", "shorten", "hide", "demote", "collapse", "rename", "reduce choices")
        forbiddenWork = @("new sections", "new feature capability", "more cards", "more explanatory text", "larger navigation")
        exitCriteria = @("No obvious wall of text", "Fewer competing choices than before", "Primary action remains dominant", "Mobile first viewport is calmer", "No important action is hidden")
        reviewers = @("Simon", "Robin", "visual QA")
        autoAdvance = "May advance to polish when no major clutter or comprehension issue remains."
        stopRules = @("first screen still overwhelming", "copy still vague", "new complexity added", "primary CTA demoted")
    }

    $contracts["polish"] = [pscustomobject]@{
        order = 5
        purpose = "Make the already-shaped site feel refined."
        allowedWork = @("spacing", "type scale", "color rhythm", "button rhythm", "final microcopy", "mobile fit", "small accessibility repairs")
        forbiddenWork = @("new pages", "new product claims", "new workflows", "backend/auth/payments", "broad redesign")
        exitCriteria = @("No clipped text", "Tap targets are comfortable", "Copy sounds human and concrete", "Visual rhythm is consistent", "Build passes")
        reviewers = @("Simon", "Robin", "visual QA", "copy smoke")
        autoAdvance = "May advance to proof when polish issues are small and no reviewer is RED."
        stopRules = @("visual RED", "copy RED", "repeated vague phrases", "mobile overlap")
    }

    $contracts["proof"] = [pscustomobject]@{
        order = 6
        purpose = "Verify and repair only blockers."
        allowedWork = @("broken links", "broken routes", "build failures", "runtime failures", "clipped text", "bad tap targets", "review blockers", "screenshot evidence")
        forbiddenWork = @("redesign", "new sections", "new features", "tone experiments", "scope expansion")
        exitCriteria = @("Build/check command passes", "Required routes load", "Desktop/mobile screenshots exist", "Simon not RED", "Robin not RED", "Joey GREEN or not applicable", "No high/medium visual bugs")
        reviewers = @("build", "visual QA", "Simon", "Robin", "Joey")
        autoAdvance = "May advance to parked when proof passes and no unchecked tasks remain."
        stopRules = @("failed build", "runtime crash", "security RED", "high visual bug", "blocking review finding")
    }

    $contracts["parked"] = [pscustomobject]@{
        order = 7
        purpose = "Stop spending loops; the ship is ready for human inspection."
        allowedWork = @("docs-only review note", "preview instructions", "human-requested follow-up task")
        forbiddenWork = @("unattended new work", "planner-generated polish", "new feature work", "continued churn")
        exitCriteria = @("Parking State is PARKED_REVIEW_READY", "No unchecked tasks", "Working tree clean", "Latest proof/report explains what to inspect")
        reviewers = @("human")
        autoAdvance = "Do not auto-advance. A human must move it out of parked."
        stopRules = @("any unattended task generation")
    }

    return $contracts
}

function Convert-StageContractToMarkdown {
    param(
        [string]$StageName,
        [object]$Contract
    )

    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("## $StageName") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Purpose: $($Contract.purpose)") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Allowed work:") | Out-Null
    foreach ($item in @($Contract.allowedWork)) { $lines.Add("- $item") | Out-Null }
    $lines.Add("") | Out-Null
    $lines.Add("Forbidden work:") | Out-Null
    foreach ($item in @($Contract.forbiddenWork)) { $lines.Add("- $item") | Out-Null }
    $lines.Add("") | Out-Null
    $lines.Add("Exit criteria:") | Out-Null
    foreach ($item in @($Contract.exitCriteria)) { $lines.Add("- $item") | Out-Null }
    $lines.Add("") | Out-Null
    $lines.Add("Reviewer gates: $((@($Contract.reviewers)) -join ', ')") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Auto-advance rule: $($Contract.autoAdvance)") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Stop rules:") | Out-Null
    foreach ($item in @($Contract.stopRules)) { $lines.Add("- $item") | Out-Null }
    $lines.Add("") | Out-Null
    return @($lines)
}

function Write-WebsiteStageReference {
    param([string]$Repo)

    $outPath = Join-Path $Repo "docs\codex\WEBSITE_STAGE_RULES.md"
    New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null
    $contracts = Get-WebsiteStageContracts
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add("# Website Stage Rules") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("This file is generated from Codex Fleet Phase 1. It defines how website ships move from direction to proof without waiting for a human after every tiny task.") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("Stage order: brief -> foundation -> shape -> simplicity -> polish -> proof -> parked") | Out-Null
    $lines.Add("") | Out-Null
    $lines.Add("General rule: auto-advance inside the stage system only when the current stage exit criteria pass. Stop for RED gates, sensitive scope, failed builds, unclear direction, or parked review state.") | Out-Null
    $lines.Add("") | Out-Null
    foreach ($stage in @("brief", "foundation", "shape", "simplicity", "polish", "proof", "parked")) {
        foreach ($line in @(Convert-StageContractToMarkdown -StageName $stage -Contract $contracts[$stage])) {
            $lines.Add($line) | Out-Null
        }
    }
    Set-Content -LiteralPath $outPath -Value $lines
    return $outPath
}

function Resolve-Ship {
    if ([string]::IsNullOrWhiteSpace($Project)) {
        Stop-WithMessage "Pass -Project when using -WriteReference or -Validate."
    }
    if (!(Test-Path -LiteralPath $ConfigPath)) {
        Stop-WithMessage "Config not found: $ConfigPath"
    }

    $projects = @(Get-Content $ConfigPath -Raw | ConvertFrom-Json | ForEach-Object { $_ })
    $ship = @($projects | Where-Object { [string]$_.name -ceq $Project }) | Select-Object -First 1
    if ($null -eq $ship) { Stop-WithMessage "Project not found: $Project" }

    $repo = [string](Get-ConfigPropertyValue -Object $ship -Name "repo")
    if (!(Test-Path -LiteralPath $repo)) { Stop-WithMessage "Repo not found: $repo" }
    return [pscustomobject]@{ name = [string]$ship.name; repo = (Resolve-Path -LiteralPath $repo).Path }
}

function Get-PhaseValue {
    param(
        [string]$Text,
        [string]$Name
    )

    $match = [regex]::Match($Text, "(?im)^$([regex]::Escape($Name)):\s*(.+?)\s*$")
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
    return ""
}

function Test-WebsiteStageState {
    param([string]$Repo)

    $phasePath = Join-Path $Repo "docs\codex\PHASE_STATE.md"
    $stageRulesPath = Join-Path $Repo "docs\codex\WEBSITE_STAGE_RULES.md"
    $issues = New-Object System.Collections.Generic.List[string]
    if (!(Test-Path -LiteralPath $phasePath)) {
        $issues.Add("PHASE_STATE.md missing") | Out-Null
    } else {
        $text = Get-Content -LiteralPath $phasePath -Raw
        $phase = Get-PhaseValue -Text $text -Name "Current Phase"
        $contracts = Get-WebsiteStageContracts
        if (!$contracts.Contains($phase)) {
            $issues.Add("Current Phase is not a website stage: $phase") | Out-Null
        }
        foreach ($field in @("Audience", "Product Promise", "Primary Action", "Showable Moment", "What Not To Build", "Evidence Required", "Done Signal", "Next Phase Criteria")) {
            $value = Get-PhaseValue -Text $text -Name $field
            if ([string]::IsNullOrWhiteSpace($value) -or $value -match "^TODO:") {
                $issues.Add("$field missing/TODO") | Out-Null
            }
        }
    }

    if (!(Test-Path -LiteralPath $stageRulesPath)) {
        $issues.Add("WEBSITE_STAGE_RULES.md missing; run -WriteReference") | Out-Null
    }

    return @($issues)
}

$contracts = Get-WebsiteStageContracts

if ($List -or (![string]::IsNullOrWhiteSpace($Phase) -and !$WriteReference -and !$Validate)) {
    $stages = if (![string]::IsNullOrWhiteSpace($Phase)) { @($Phase) } else { @("brief", "foundation", "shape", "simplicity", "polish", "proof", "parked") }
    foreach ($stage in $stages) {
        foreach ($line in @(Convert-StageContractToMarkdown -StageName $stage -Contract $contracts[$stage])) {
            Write-Output $line
        }
    }
}

if ($WriteReference) {
    $ship = Resolve-Ship
    $path = Write-WebsiteStageReference -Repo $ship.repo
    Write-Host "Website stage rules written for $($ship.name): $path" -ForegroundColor Green
}

if ($Validate) {
    $ship = Resolve-Ship
    $issues = @(Test-WebsiteStageState -Repo $ship.repo)
    if ($issues.Count -gt 0) {
        Write-Host "Website stage validation failed for $($ship.name)" -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "- $_" -ForegroundColor Red }
        exit 1
    }
    Write-Host "Website stage validation passed for $($ship.name)" -ForegroundColor Green
}
