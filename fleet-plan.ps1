[CmdletBinding(PositionalBinding = $false)]
param(
    [string]$ConfigPath = ".\projects.json",

    [string]$Project = "",

    [string]$Repo = "",

    [string]$OutDir = "docs/codex",

    [string]$Model = "",

    [string[]]$Models = @(),

    [int]$TimeoutSeconds = 900,

    [int]$RateLimitCooldownSeconds = 3600,

    [int]$RateLimitMaxCooldowns = 4,

    [switch]$Template,

    [switch]$ValidateOnly
)

$ErrorActionPreference = "Continue"

$fleetRoot = if (![string]::IsNullOrWhiteSpace($PSScriptRoot)) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$fleetRuntime = Join-Path $fleetRoot "tools\codex-fleet-runtime.ps1"
if (!(Test-Path $fleetRuntime)) {
    Write-Host "Fleet runtime helper not found: $fleetRuntime" -ForegroundColor Red
    exit 1
}
. $fleetRuntime

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

function Get-ProjectList {
    if (!(Test-Path $ConfigPath)) {
        Stop-WithMessage "Config not found: $ConfigPath"
    }

    $parsedProjects = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    if ($parsedProjects -is [array]) {
        return @($parsedProjects)
    }
    if ($null -ne $parsedProjects -and $parsedProjects.PSObject.Properties.Name -contains "value") {
        return @($parsedProjects.value)
    }
    if ($null -ne $parsedProjects) {
        return @($parsedProjects)
    }
    return @()
}

function Resolve-Ship {
    if (![string]::IsNullOrWhiteSpace($Repo)) {
        $repoPath = Resolve-Path -LiteralPath $Repo -ErrorAction SilentlyContinue
        if (!$repoPath) { Stop-WithMessage "Repo not found: $Repo" }
        return [pscustomobject]@{
            name = if (![string]::IsNullOrWhiteSpace($Project)) { $Project } else { Split-Path -Leaf $repoPath.Path }
            repo = $repoPath.Path
            projectType = "unknown"
            riskTier = "unknown"
            profile = ""
            models = $null
            timeouts = $null
        }
    }

    if ([string]::IsNullOrWhiteSpace($Project)) {
        Stop-WithMessage "Provide -Project or -Repo."
    }

    $matches = @(Get-ProjectList | Where-Object { [string]$_.name -ceq [string]$Project })
    if ($matches.Count -ne 1) {
        Stop-WithMessage "Project not found or ambiguous: $Project"
    }

    return $matches[0]
}

function Get-PlanPaths {
    param([string]$Root)

    return [pscustomobject]@{
        architecture = Join-Path $Root "ARCHITECTURE.md"
        engineering = Join-Path $Root "ENGINEERING_PLAN.md"
        risk = Join-Path $Root "RISK_REGISTER.md"
        approval = Join-Path $Root "ARCHITECTURE_APPROVAL.md"
    }
}

function Test-FileHasHeadings {
    param(
        [string]$Path,
        [string[]]$Headings
    )

    if (!(Test-Path -LiteralPath $Path)) {
        return $false
    }

    $text = Get-Content -LiteralPath $Path -Raw
    foreach ($heading in $Headings) {
        if ($text -notmatch "(?im)^##\s+$([regex]::Escape($heading))\s*$") {
            return $false
        }
    }

    return $true
}

function Test-ArchitectureApproval {
    param([string]$Path)

    if (!(Test-Path -LiteralPath $Path)) {
        return $false
    }

    $text = Get-Content -LiteralPath $Path -Raw
    return ($text -match "(?im)^\s*Status:\s*APPROVED\s*$")
}

function Test-ArchitecturePlan {
    param([object]$Paths)

    $issues = [System.Collections.Generic.List[string]]::new()
    if (!(Test-FileHasHeadings -Path $Paths.architecture -Headings @("Product", "Users", "System Boundaries", "Runtime", "Data Model", "API Contracts", "Security Model", "Dependencies", "Deployment Model", "Open Questions"))) {
        $issues.Add("ARCHITECTURE.md is missing or incomplete.") | Out-Null
    }
    if (!(Test-FileHasHeadings -Path $Paths.engineering -Headings @("Milestones", "Task Slices", "Test Strategy", "Acceptance Criteria", "Rollback Plan"))) {
        $issues.Add("ENGINEERING_PLAN.md is missing or incomplete.") | Out-Null
    }
    if (!(Test-FileHasHeadings -Path $Paths.risk -Headings @("Risk Summary", "Approval Gates", "Sensitive Systems", "Mitigations", "Open Risks"))) {
        $issues.Add("RISK_REGISTER.md is missing or incomplete.") | Out-Null
    }
    if (!(Test-ArchitectureApproval -Path $Paths.approval)) {
        $issues.Add("ARCHITECTURE_APPROVAL.md is missing Status: APPROVED.") | Out-Null
    }

    return @($issues)
}

function Write-TemplatePlan {
    param(
        [object]$Ship,
        [object]$Paths
    )

    if (!(Test-Path -LiteralPath $Paths.architecture)) {
        Set-Content -LiteralPath $Paths.architecture -Value @"
# Architecture

## Product

TBD.

## Users

TBD.

## System Boundaries

TBD.

## Runtime

TBD.

## Data Model

TBD.

## API Contracts

TBD.

## Security Model

TBD.

## Dependencies

TBD.

## Deployment Model

TBD.

## Open Questions

- TBD.
"@
    }

    if (!(Test-Path -LiteralPath $Paths.engineering)) {
        Set-Content -LiteralPath $Paths.engineering -Value @"
# Engineering Plan

## Milestones

- TBD.

## Task Slices

- TBD.

## Test Strategy

TBD.

## Acceptance Criteria

- TBD.

## Rollback Plan

TBD.
"@
    }

    if (!(Test-Path -LiteralPath $Paths.risk)) {
        Set-Content -LiteralPath $Paths.risk -Value @"
# Risk Register

## Risk Summary

TBD.

## Approval Gates

- Package/dependency changes require approval.
- Backend, auth, payment, migration, deployment, and production data changes require approval.

## Sensitive Systems

TBD.

## Mitigations

TBD.

## Open Risks

- TBD.
"@
    }

    if (!(Test-Path -LiteralPath $Paths.approval)) {
        Set-Content -LiteralPath $Paths.approval -Value @"
# Architecture Approval

Project: $($Ship.name)
Status: DRAFT
Approved by:
Approved at:

Notes:
- Change Status to APPROVED only after human review.
"@
    }
}

$ship = Resolve-Ship
$repoPath = Resolve-Path -LiteralPath $ship.repo -ErrorAction SilentlyContinue
if (!$repoPath) {
    Stop-WithMessage "Repo not found: $($ship.repo)"
}

Set-Location $repoPath.Path
git rev-parse --show-toplevel *> $null
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage "Repo is not a git repository: $($repoPath.Path)"
}

$outRoot = Join-Path $repoPath.Path $OutDir
$paths = Get-PlanPaths -Root $outRoot

if ($ValidateOnly) {
    $issues = @(Test-ArchitecturePlan -Paths $paths)
    if ($issues.Count -gt 0) {
        Write-Host "Architecture plan is not approved for $($ship.name)." -ForegroundColor Red
        $issues | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
        exit 1
    }

    Write-Host "Architecture plan is approved for $($ship.name)." -ForegroundColor Green
    exit 0
}

$preStatus = @(git status --porcelain)
if ($preStatus.Count -gt 0) {
    Write-Host "Architecture planning requires a clean working tree." -ForegroundColor Red
    $preStatus | ForEach-Object { Write-Host "  $_" }
    exit 1
}

New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

if ($Template) {
    Write-TemplatePlan -Ship $ship -Paths $paths
    Write-Host "Architecture planning templates written to $OutDir." -ForegroundColor Green
    Write-Host "Review and change ARCHITECTURE_APPROVAL.md Status to APPROVED when ready." -ForegroundColor Yellow
    exit 0
}

$mission = if (Test-Path "docs/codex/MISSION.md") { Get-Content "docs/codex/MISSION.md" -Raw } else { "No mission file found." }
$policy = if (Test-Path "docs/codex/RUN_POLICY.md") { Get-Content "docs/codex/RUN_POLICY.md" -Raw } else { "No run policy found." }
$packageFiles = @(Get-ChildItem -Recurse -File -Include package.json,pyproject.toml,Cargo.toml,go.mod,*.csproj -ErrorAction SilentlyContinue | Select-Object -First 30 | ForEach-Object { $_.FullName.Replace($repoPath.Path, "").TrimStart("\") })
$topFiles = @(Get-ChildItem -Force -File -ErrorAction SilentlyContinue | Select-Object -First 40 | ForEach-Object { $_.Name })

$modelChain = @(ConvertTo-FleetStringArray -Value $Models)
if ($modelChain.Count -eq 0) {
    $modelChain = @(ConvertTo-FleetStringArray -Value $Model)
}
$shipModels = Get-ConfigPropertyValue -Object (Get-ConfigPropertyValue -Object $ship -Name "models") -Name "architect"
if ($modelChain.Count -eq 0 -and $null -ne $shipModels) {
    $modelChain = @(ConvertTo-FleetStringArray -Value $shipModels)
}
$plannerModels = Get-ConfigPropertyValue -Object (Get-ConfigPropertyValue -Object $ship -Name "models") -Name "planner"
if ($modelChain.Count -eq 0 -and $null -ne $plannerModels) {
    $modelChain = @(ConvertTo-FleetStringArray -Value $plannerModels)
}

$prompt = @"
You are the Codex Fleet Architect.

Create a Phase 1 architecture planning pack for this ship. Output four markdown documents separated by these exact markers:

---FILE: ARCHITECTURE.md---
---FILE: ENGINEERING_PLAN.md---
---FILE: RISK_REGISTER.md---
---FILE: ARCHITECTURE_APPROVAL.md---

Rules:
- Be concrete and engineering-oriented.
- Do not propose production deployment without explicit approval.
- Treat package/dependency changes, backend, migrations, auth, payments, secrets, external APIs, and deployment as approval-gated work.
- Keep ARCHITECTURE_APPROVAL.md in DRAFT status. Humans approve it later.
- Include every required heading exactly as written.

Required headings for ARCHITECTURE.md:
## Product
## Users
## System Boundaries
## Runtime
## Data Model
## API Contracts
## Security Model
## Dependencies
## Deployment Model
## Open Questions

Required headings for ENGINEERING_PLAN.md:
## Milestones
## Task Slices
## Test Strategy
## Acceptance Criteria
## Rollback Plan

Required headings for RISK_REGISTER.md:
## Risk Summary
## Approval Gates
## Sensitive Systems
## Mitigations
## Open Risks

Required line for ARCHITECTURE_APPROVAL.md:
Status: DRAFT

Ship:
- Name: $($ship.name)
- Repo: $($repoPath.Path)
- Profile: $($ship.profile)
- Project type: $($ship.projectType)
- Risk tier: $($ship.riskTier)

Mission:
$mission

Run policy:
$policy

Top-level files:
$(if ($topFiles.Count -eq 0) { "- None" } else { ($topFiles | ForEach-Object { "- $_" }) -join "`n" })

Detected package/project files:
$(if ($packageFiles.Count -eq 0) { "- None" } else { ($packageFiles | ForEach-Object { "- $_" }) -join "`n" })
"@

$tmp = New-TemporaryFile
$logPath = Join-Path $repoPath.Path (Join-Path ".codex-logs" ("architect-plan-{0}.log" -f (Get-Date -Format "yyyyMMdd-HHmmss")))
$result = Invoke-FleetCodexReadOnly -Prompt $prompt -Models $modelChain -OutputPath $tmp.FullName -WorkingDirectory $repoPath.Path -LogPath $logPath -TimeoutSeconds $TimeoutSeconds -RateLimitCooldownSeconds $RateLimitCooldownSeconds -RateLimitMaxCooldowns $RateLimitMaxCooldowns
if ($null -eq $result -or !(Test-Path $tmp.FullName) -or ((Get-Item $tmp.FullName).Length -eq 0)) {
    Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue
    Stop-WithMessage "Architect produced no output."
}

$output = Get-Content $tmp.FullName -Raw
Remove-Item $tmp.FullName -Force -ErrorAction SilentlyContinue

$targets = @{
    "ARCHITECTURE.md" = $paths.architecture
    "ENGINEERING_PLAN.md" = $paths.engineering
    "RISK_REGISTER.md" = $paths.risk
    "ARCHITECTURE_APPROVAL.md" = $paths.approval
}

foreach ($name in $targets.Keys) {
    $pattern = "(?s)---FILE:\s*$([regex]::Escape($name))---\s*(.*?)(?=---FILE:|\z)"
    $match = [regex]::Match($output, $pattern)
    if (!$match.Success) {
        Stop-WithMessage "Architect output missing marker for $name."
    }
    Set-Content -LiteralPath $targets[$name] -Value $match.Groups[1].Value.Trim()
}

$dirtyAfter = @(git status --porcelain)
$allowed = @(
    ($OutDir.Replace("\", "/") + "/ARCHITECTURE.md"),
    ($OutDir.Replace("\", "/") + "/ENGINEERING_PLAN.md"),
    ($OutDir.Replace("\", "/") + "/RISK_REGISTER.md"),
    ($OutDir.Replace("\", "/") + "/ARCHITECTURE_APPROVAL.md")
)
$unexpected = @($dirtyAfter | Where-Object {
    $line = [string]$_
    $path = $line.Substring([Math]::Min(3, $line.Length)).Replace("\", "/")
    $allowed -notcontains $path
})
if ($unexpected.Count -gt 0) {
    Write-Host "Architect planning changed unexpected files. Stop for human review." -ForegroundColor Red
    $unexpected | ForEach-Object { Write-Host "  $_" }
    exit 1
}

$issues = @(Test-ArchitecturePlan -Paths $paths | Where-Object { $_ -notmatch "ARCHITECTURE_APPROVAL" })
if ($issues.Count -gt 0) {
    Write-Host "Architect plan was written but is incomplete." -ForegroundColor Red
    $issues | ForEach-Object { Write-Host "  - $_" }
    exit 1
}

Write-Host "Architecture planning pack written to $OutDir." -ForegroundColor Green
Write-Host "Approval remains DRAFT until a human changes ARCHITECTURE_APPROVAL.md to Status: APPROVED." -ForegroundColor Yellow
exit 0
